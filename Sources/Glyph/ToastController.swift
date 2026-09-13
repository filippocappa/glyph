import AppKit
import SwiftUI

/// A guaranteed, permission-free capture confirmation: a small floating
/// panel near the top of the screen. Unlike `UNUserNotificationCenter`,
/// nothing about this depends on Notification Center settings or the user
/// having granted (and kept) notification permission. Clicking it expands
/// to show the full captured text.
@MainActor
final class ToastController {
    static let shared = ToastController()

    private var panel: NSPanel?
    private var hostingView: NSHostingView<ToastView>?
    private var dismissWorkItem: DispatchWorkItem?
    private var isExpanded = false
    private var currentImage = "text.viewfinder"
    private var currentText = ""

    /// Top-center anchor point in screen coordinates. Every resize is
    /// computed fresh from this single fixed point, rather than from the
    /// panel's current (possibly still-animating) frame — that's what
    /// caused the toast to drift/teleport when expanding repeatedly.
    private var topAnchor: CGPoint = .zero

    private init() {}

    func show(systemImage: String, text: String) {
        dismissWorkItem?.cancel()
        isExpanded = false
        currentImage = systemImage
        currentText = text

        let panel = self.panel ?? makePanel()
        self.panel = panel

        updateAnchor()
        render(in: panel, animated: false)

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 1
        }

        scheduleDismiss(delay: 2.2)
    }

    private func toggleExpanded() {
        guard let panel else { return }
        isExpanded.toggle()
        render(in: panel, animated: true)
        scheduleDismiss(delay: isExpanded ? nil : 1.6)
    }

    private func render(in panel: NSPanel, animated: Bool) {
        let rootView = ToastView(
            systemImage: currentImage,
            text: currentText,
            isExpanded: isExpanded,
            onTap: { [weak self] in self?.toggleExpanded() }
        )

        let hosting: NSHostingView<ToastView>
        if let existing = hostingView {
            existing.rootView = rootView
            hosting = existing
        } else {
            hosting = NSHostingView(rootView: rootView)
            hostingView = hosting
            panel.contentView = hosting
        }

        let fitting = hosting.fittingSize
        let size = CGSize(width: max(fitting.width, 160), height: max(fitting.height, 40))
        hosting.frame = CGRect(origin: .zero, size: size)

        let newFrame = CGRect(
            x: topAnchor.x - size.width / 2,
            y: topAnchor.y - size.height,
            width: size.width,
            height: size.height
        )

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.allowsImplicitAnimation = true
                panel.animator().setFrame(newFrame, display: true)
            }
        } else {
            panel.setFrame(newFrame, display: true)
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
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 56),
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

    private func updateAnchor() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        topAnchor = CGPoint(x: screenFrame.midX, y: screenFrame.maxY - 16)
    }
}
