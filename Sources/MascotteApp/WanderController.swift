import AppKit

private extension MovementSpeed {
    /// Wander speed for each setting. `.normal` matches the original hardcoded 60 px/s.
    var pixelsPerSecond: CGFloat {
        switch self {
        case .slow: return 30.0
        case .normal: return 60.0
        case .brisk: return 120.0
        }
    }
}

/// Makes the pet occasionally wander a short distance while idle.
///
/// Only ever acts while the state machine is idle, and any outside activity
/// (a drag, or the state machine moving to any other state) cancels the
/// pending/ongoing walk immediately.
final class WanderController {
    private let window: PetWindow
    private let stateMachine: StateMachine
    private let minDelay: TimeInterval
    private let maxDelay: TimeInterval

    private var scheduleTimer: Timer?
    private var moveTimer: Timer?
    private var isWandering = false
    /// Set while this controller itself calls stateMachine.setState, so the
    /// onStateChange echo isn't mistaken for an external interruption.
    private var isApplyingOwnState = false

    private var pixelsPerSecond: CGFloat
    private let tickInterval: TimeInterval = 1.0 / 60.0
    private var preferencesObserver: NSObjectProtocol?

    init(
        window: PetWindow,
        stateMachine: StateMachine,
        fastMode: Bool = false
    ) {
        self.window = window
        self.stateMachine = stateMachine
        self.pixelsPerSecond = Preferences.shared.movementSpeed.pixelsPerSecond
        if fastMode {
            self.minDelay = 3
            self.maxDelay = 6
        } else {
            self.minDelay = 30
            self.maxDelay = 120
        }

        stateMachine.onStateChange = { [weak self] state in
            self?.handleStateChange(state)
        }

        preferencesObserver = NotificationCenter.default.addObserver(
            forName: .mascottePreferencesChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.pixelsPerSecond = Preferences.shared.movementSpeed.pixelsPerSecond
        }

        if stateMachine.currentState == .idle {
            scheduleNextWander()
        }
    }

    deinit {
        if let preferencesObserver {
            NotificationCenter.default.removeObserver(preferencesObserver)
        }
    }

    /// Cancels any pending or in-flight wander immediately (used when a drag begins).
    func stop() {
        scheduleTimer?.invalidate()
        scheduleTimer = nil
        stopMovement()
    }

    private func handleStateChange(_ state: PetState) {
        guard !isApplyingOwnState else { return }
        if state == .idle {
            scheduleNextWander()
        } else {
            scheduleTimer?.invalidate()
            scheduleTimer = nil
            stopMovement()
        }
    }

    private func scheduleNextWander() {
        scheduleTimer?.invalidate()
        let delay = TimeInterval.random(in: minDelay...maxDelay)
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.startWander()
        }
        RunLoop.main.add(timer, forMode: .common)
        scheduleTimer = timer
    }

    private func startWander() {
        guard !isWandering, stateMachine.currentState == .idle else { return }

        let screen = window.screen ?? NSScreen.main
        guard let visible = screen?.visibleFrame else {
            scheduleNextWander()
            return
        }

        let requestedDistance = CGFloat.random(in: 50...300)
        let goingRight = Bool.random()
        let startX = window.frame.origin.x
        let minX = visible.minX
        let maxX = visible.maxX - window.frame.width

        guard maxX > minX else {
            scheduleNextWander()
            return
        }

        let rawTargetX = goingRight ? startX + requestedDistance : startX - requestedDistance
        let targetX = min(max(rawTargetX, minX), maxX)
        let distance = abs(targetX - startX)

        guard distance > 1 else {
            scheduleNextWander()
            return
        }

        let direction: CGFloat = targetX > startX ? 1 : -1
        let originY = window.frame.origin.y

        isWandering = true
        setState(direction > 0 ? .runningRight : .runningLeft)

        var traveled: CGFloat = 0

        let timer = Timer(timeInterval: tickInterval, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            // Re-read pixelsPerSecond every tick so a preference change applies
            // to the walk already in flight, not just the next one.
            let stepDistance = self.pixelsPerSecond * CGFloat(self.tickInterval)
            traveled += stepDistance
            let reachedTarget = traveled >= distance
            let newX = reachedTarget ? targetX : startX + direction * traveled
            self.window.setFrameOrigin(NSPoint(x: newX, y: originY))

            if reachedTarget {
                timer.invalidate()
                self.finishWander()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        moveTimer = timer
    }

    private func finishWander() {
        moveTimer = nil
        isWandering = false
        setState(.idle)
        PositionStore.save(window.frame.origin)
        scheduleNextWander()
    }

    private func stopMovement() {
        moveTimer?.invalidate()
        moveTimer = nil
        if isWandering {
            isWandering = false
            PositionStore.save(window.frame.origin)
        }
    }

    private func setState(_ state: PetState) {
        isApplyingOwnState = true
        stateMachine.setState(state)
        isApplyingOwnState = false
    }
}
