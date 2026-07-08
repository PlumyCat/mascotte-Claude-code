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
    /// Fired on mouseUp when the total mouse movement since mouseDown stayed
    /// under `clickDistanceThreshold` — a simple click, as opposed to a drag.
    var onClick: (() -> Void)?

    /// Below this many points of total mouse movement between mouseDown and
    /// mouseUp, the gesture counts as a click rather than a drag.
    private let clickDistanceThreshold: CGFloat = 4.0

    private var dragStartMouseLocation: NSPoint?
    private var dragStartWindowOrigin: NSPoint?
    private var stateBeforeDrag: PetState?
    private var isDragging = false

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
        // Dragging is handled manually below (mouseDown/mouseDragged/mouseUp) so we can
        // track direction and know exactly when a drag starts/ends. isMovable is disabled
        // so nothing but our own code (drag + wander) ever repositions the window.
        isMovableByWindowBackground = false
        isMovable = false

        contentView = view

        setFrameOrigin(PositionStore.loadOrigin(windowSize: rect.size))
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

        let startMouseLocation = dragStartMouseLocation
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

        if let startMouseLocation {
            let current = NSEvent.mouseLocation
            let distance = hypot(current.x - startMouseLocation.x, current.y - startMouseLocation.y)
            if distance < clickDistanceThreshold {
                onClick?()
            }
        }
    }
}
