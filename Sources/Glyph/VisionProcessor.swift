import Vision
import CoreGraphics

/// What Vision found in a captured region, and where it came from.
enum RecognitionResult: Sendable {
    case barcode(String)
    case text(String)

    var value: String {
        switch self {
        case .barcode(let value), .text(let value):
            return value
        }
    }

    var isBarcode: Bool {
        if case .barcode = self { return true }
        return false
    }
}

/// Runs barcode/QR detection and OCR concurrently over a captured image and
/// resolves a single best-effort result.
enum VisionProcessor {
    /// Vision lazily loads its on-device text recognition model on first
    /// use, which can take a long time (tens of seconds). Fire a throwaway
    /// request at launch so that cost lands during app startup instead of
    /// during the user's first real capture.
    static func warmUp() {
        DispatchQueue.global(qos: .utility).async {
            guard let blank = CGContext(
                data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )?.makeImage() else { return }

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            try? VNImageRequestHandler(cgImage: blank, options: [:]).perform([request])
        }
    }

    /// `languageCode`: a BCP-47 recognition language (e.g. "en-US"), or `nil`
    /// to let Vision auto-detect the language.
    ///
    /// Priority 1: barcode/QR payload, if any is found.
    /// Priority 2: recognized text lines, sorted into reading order and
    /// joined per `keepLineBreaks`.
    static func process(
        cgImage: CGImage,
        keepLineBreaks: Bool,
        languageCode: String?,
        completion: @escaping @MainActor @Sendable (RecognitionResult?) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Created inside the async closure (rather than captured from
            // outside) since VNRequest types aren't Sendable.
            let barcodeRequest = VNDetectBarcodesRequest()

            let textRequest = VNRecognizeTextRequest()
            textRequest.recognitionLevel = .accurate
            textRequest.usesLanguageCorrection = true
            // Default minimum text height skips small glyphs like formula
            // exponents/subscripts relative to the rest of the line; letting
            // Vision look at smaller text helps (though Vision still isn't a
            // math-formula OCR engine — it reads glyphs, not notation).
            textRequest.minimumTextHeight = 0.01
            if let languageCode {
                textRequest.recognitionLanguages = [languageCode]
                if #available(macOS 13, *) {
                    textRequest.automaticallyDetectsLanguage = false
                }
            } else if #available(macOS 13, *) {
                textRequest.automaticallyDetectsLanguage = true
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([barcodeRequest, textRequest])
            } catch {
                Task { @MainActor in completion(nil) }
                return
            }

            if let payload = barcodeRequest.results?.compactMap({ $0.payloadStringValue }).first {
                Task { @MainActor in completion(.barcode(payload)) }
                return
            }

            if let joined = joinedText(from: textRequest.results, keepLineBreaks: keepLineBreaks) {
                Task { @MainActor in completion(.text(joined)) }
                return
            }

            // `.accurate` + language correction can discard an isolated
            // glyph/symbol it can't validate against a dictionary (a single
            // letter, a lone punctuation mark). Retry once without language
            // correction before giving up.
            let fallbackRequest = VNRecognizeTextRequest()
            fallbackRequest.recognitionLevel = .accurate
            fallbackRequest.usesLanguageCorrection = false
            fallbackRequest.minimumTextHeight = 0.01
            if let languageCode {
                fallbackRequest.recognitionLanguages = [languageCode]
            }

            try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([fallbackRequest])

            if let joined = joinedText(from: fallbackRequest.results, keepLineBreaks: keepLineBreaks) {
                Task { @MainActor in completion(.text(joined)) }
            } else {
                Task { @MainActor in completion(nil) }
            }
        }
    }

    /// Vision does not guarantee reading order — sort top-to-bottom, then
    /// left-to-right (bounding boxes are normalized, origin at bottom-left),
    /// or joined text comes out scrambled.
    private static func joinedText(
        from observations: [VNRecognizedTextObservation]?,
        keepLineBreaks: Bool
    ) -> String? {
        let sorted = (observations ?? []).sorted { lhs, rhs in
            let lhsBox = lhs.boundingBox
            let rhsBox = rhs.boundingBox
            if abs(lhsBox.origin.y - rhsBox.origin.y) > 0.005 {
                return lhsBox.origin.y > rhsBox.origin.y
            }
            return lhsBox.origin.x < rhsBox.origin.x
        }

        let lines = sorted.compactMap { $0.topCandidates(1).first?.string }
        guard !lines.isEmpty else { return nil }

        let separator = keepLineBreaks ? "\n" : " "
        return lines.joined(separator: separator)
    }
}
