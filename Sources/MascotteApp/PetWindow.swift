import AppKit

final class PetWindow: NSPanel {
    init(image: CGImage) {
        let size = CGSize(width: image.width, height: image.height)
        let rect = NSRect(origin: .zero, size: size)

        super.init(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .fullScreenAuxiliary]
        isMovableByWindowBackground = true

        let imageView = NSImageView(frame: NSRect(origin: .zero, size: size))
        imageView.image = NSImage(cgImage: image, size: size)
        imageView.imageScaling = .scaleNone
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = .clear

        contentView = imageView

        centerOnActiveScreen()
    }

    private func centerOnActiveScreen() {
        let primaryScreen = NSScreen.screens.first { $0.frame.origin == .zero }
        guard let screen = primaryScreen ?? NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - frame.width / 2
        let y = screenFrame.midY - frame.height / 2
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}
