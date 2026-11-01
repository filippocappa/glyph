import AppKit
import SwiftUI

/// A guaranteed, permission-free capture confirmation: a small floating
/// panel near the top of the screen. Unlike `UNUserNotificationCenter`,
/// nothing about this depends on Notification Center settings or the user
/// having granted (and kept) notification permission. Clicking it expands
/// to show more of the captured text.
///
/// The panel is a single fixed size for its whole lifetime, positioned once
/// when shown. Expand/collapse only swaps the SwiftUI content inside it —
/// nothing ever calls `setFrame` after the initial position, since doing
/// that on every tap (based on a measured "ideal" size) was the source of a
/// bad bug where the toast would drift/teleport across taps.
@MainActor
final class ToastController {
    static let shared = ToastController()

    private static let panelSize = CGSize(width: 360, height: 220)

    private var panel: NSPanel?
    private var hostingView: NSHostingView<ToastView>?
    private var dismissWorkItem: DispatchWorkItem?
    private var isExpanded = false
    private var currentImage = "text.viewfinder"
    private var currentText = ""

    private init() {}

    func show(systemImage: String, text: String) {
        dismissWorkItem?.cancel()
        isExpanded = false
        currentImage = systemImage
        currentText = text

        let panel = self.panel ?? makePanel()
        self.panel = panel

        position(panel)
        updateContent(animated: false)

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 1
        }

        scheduleDismiss(delay: 2.2)
    }

    private func toggleExpanded() {
        isExpanded.toggle()
        updateContent(animated: true)
        scheduleDismiss(delay: isExpanded ? nil : 1.6)
    }

    private func updateContent(animated: Bool) {
        guard let panel else { return }

        let rootView = ToastView(
            systemImage: currentImage,
            text: currentText,
            isExpanded: isExpanded,
            onTap: { [weak self] in self?.toggleExpanded() }
        )

        if let hostingView {
            if animated {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    hostingView.rootView = rootView
                }
            } else {
                hostingView.rootView = rootView
            }
        } else {
            let hosting = NSHostingView(rootView: rootView)
            hosting.frame = CGRect(origin: .zero, size: Self.panelSize)
            hosting.autoresizingMask = [.width, .height]
            panel.contentView = hosting
            hostingView = hosting
        }
    }

    private func scheduleDismiss(delay: TimeInterval?) {
        dismissWorkItem?.cancel()
        guard let delay else { return }
        let workItem = DispatchWorkItem { [weak self] in
            self?.dismiss()
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func dismiss() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup {
            $0.duration = 0.25
            panel.animator().alphaValue = 0
        } completionHandler: {
            Task { @MainActor in
                panel.orderOut(nil)
            }
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: Self.panelSize),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        return panel
    }

    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let size = Self.panelSize
        let origin = CGPoint(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height - 16
        )
        panel.setFrame(CGRect(origin: origin, size: size), display: false)
    }
}
