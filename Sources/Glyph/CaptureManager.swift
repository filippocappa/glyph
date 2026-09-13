import AppKit

/// Drives the native `screencapture` crosshair selection tool and hands back
/// the captured region as a `CGImage`.
final class CaptureManager {
    /// Starts an interactive screen selection. Calls `completion` with `nil`
    /// if the user cancels (Esc) or the capture otherwise fails.
    func capture(completion: @escaping @MainActor @Sendable (CGImage?) -> Void) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).png")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        // -i: interactive selection, -x: suppress the capture sound (we play our own feedback).
        process.arguments = ["-i", "-x", tempURL.path]

        process.terminationHandler = { _ in
            let image = Self.loadAndCleanUp(at: tempURL)
            Task { @MainActor in
                completion(image)
            }
        }

        do {
            try process.run()
        } catch {
            Task { @MainActor in
                completion(nil)
            }
        }
    }

    /// If the user pressed Esc or cancelled the selection, screencapture
    /// exits without ever writing the file — treat that as a clean no-op.
    private static func loadAndCleanUp(at url: URL) -> CGImage? {
        let fileManager = FileManager.default
        defer { try? fileManager.removeItem(at: url) }

        guard fileManager.fileExists(atPath: url.path),
              let dataProvider = CGDataProvider(url: url as CFURL),
              let cgImage = CGImage(
                pngDataProviderSource: dataProvider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              )
        else {
            return nil
        }

        return cgImage
    }
}
