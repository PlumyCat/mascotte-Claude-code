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
    weak var stateMachine: StateMachine?

    var willBeginDrag: (() -> Void)?
    var didEndDrag: ((NSPoint) -> Void)?

    /// The sprite's unscaled cell size (one spritesheet frame); the window
    /// size at any given `petScale` is always this times the scale.
    private let baseCellSize: CGSize

    private var dragStartMouseLocation: NSPoint?
    private var dragStartWindowOrigin: NSPoint?
    private var stateBeforeDrag: PetState?
    private var isDragging = false

    init(cellSize: CGSize) {
        self.baseCellSize = cellSize
        let rect = NSRect(origin: .zero, size: Self.scaledSize(baseCellSize: cellSize, scale: Preferences.shared.petScale))
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
        // Dragging is handled manually below (mouseDown/mouseDragged/mouseUp) so we can
        // track direction and know exactly when a drag starts/ends. isMovable is disabled
        // so nothing but our own code (drag + wander) ever repositions the window.
        isMovableByWindowBackground = false
        isMovable = false

        contentView = view

        setFrameOrigin(PositionStore.loadOrigin(windowSize: rect.size))
    }

    private static func scaledSize(baseCellSize: CGSize, scale: Double) -> CGSize {
        CGSize(width: baseCellSize.width * scale, height: baseCellSize.height * scale)
    }

    /// Resizes the window to the given `petScale`, keeping the pet's on-screen
    /// center point fixed (so it doesn't appear to jump), then reclamps the
    /// origin into the current screen's `visibleFrame` so a size increase
    /// never pushes it partially or fully off-screen.
    func applyScale(_ scale: Double) {
        let newSize = Self.scaledSize(baseCellSize: baseCellSize, scale: scale)
        guard newSize != frame.size else { return }

        let center = NSPoint(x: frame.midX, y: frame.midY)
        var origin = NSPoint(x: center.x - newSize.width / 2, y: center.y - newSize.height / 2)

        if let visible = (screen ?? NSScreen.main)?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX), max(visible.minX, visible.maxX - newSize.width))
            origin.y = min(max(origin.y, visible.minY), max(visible.minY, visible.maxY - newSize.height))
        }

        setFrame(NSRect(origin: origin, size: newSize), display: true)
    }

    override func mouseDown(with event: NSEvent) {
        isDragging = true
        dragStartMouseLocation = NSEvent.mouseLocation
        dragStartWindowOrigin = frame.origin
        stateBeforeDrag = stateMachine?.currentState
        willBeginDrag?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging,
              let startMouse = dragStartMouseLocation,
              let startOrigin = dragStartWindowOrigin else {
            return
        }

        let current = NSEvent.mouseLocation
        let dx = current.x - startMouse.x
        let dy = current.y - startMouse.y
        setFrameOrigin(NSPoint(x: startOrigin.x + dx, y: startOrigin.y + dy))

        if event.deltaX > 0.5 {
            stateMachine?.setState(.runningRight)
        } else if event.deltaX < -0.5 {
            stateMachine?.setState(.runningLeft)
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        isDragging = false
        dragStartMouseLocation = nil
        dragStartWindowOrigin = nil

        // runningLeft/runningRight are transient motion states driven by drag/wander;
        // if that's what we had before this drag started (e.g. a drag grabbed mid-wander),
        // settle back to idle rather than freezing on a running pose.
        let restoredState: PetState
        if let previous = stateBeforeDrag, previous != .runningLeft, previous != .runningRight {
            restoredState = previous
        } else {
            restoredState = .idle
        }
        stateBeforeDrag = nil
        stateMachine?.setState(restoredState)

        didEndDrag?(frame.origin)
    }
}
