import AppKit

final class SpriteView: NSView {
    // Flipped so contentsRect's (0,0) is the sheet's top-left, matching row-major sheet layout.
    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class PetWindow: NSPanel {
    let spriteView: SpriteView

    init(cellSize: CGSize) {
        let rect = NSRect(origin: .zero, size: cellSize)
        let view = SpriteView(frame: rect)
        self.spriteView = view

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

        contentView = view

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
