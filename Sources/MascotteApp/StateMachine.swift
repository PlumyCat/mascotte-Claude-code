import Foundation

final class StateMachine {
    private let engine: SpriteEngine
    private(set) var currentState: PetState
    private var pendingTransition: DispatchWorkItem?

    /// Fired whenever the current state changes, including auto-transitions
    /// back to idle. Lets observers (e.g. WanderController) know when to
    /// start/stop without polling `currentState`. Kept as a single slot for
    /// the primary observer; use `addObserver` for any additional one so
    /// nobody accidentally overwrites another's closure.
    var onStateChange: ((PetState) -> Void)?
    private var additionalObservers: [(PetState) -> Void] = []

    init(engine: SpriteEngine, initialState: PetState = .waving) {
        self.engine = engine
        self.currentState = initialState
        applyState(initialState)
    }

    func setState(_ state: PetState) {
        applyState(state)
    }

    /// Registers an extra observer without disturbing `onStateChange`. Only
    /// future transitions are delivered — never the state the machine is
    /// already in at registration time.
    func addObserver(_ observer: @escaping (PetState) -> Void) {
        additionalObservers.append(observer)
    }

    private func applyState(_ state: PetState) {
        pendingTransition?.cancel()
        pendingTransition = nil

        currentState = state
        engine.setRow(state.row, frameCount: state.frameCount)
        scheduleAutoTransition(for: state)
        onStateChange?(state)
        for observer in additionalObservers {
            observer(state)
        }
    }

    private func scheduleAutoTransition(for state: PetState) {
        switch state {
        case .waving:
            let twoLoops = engine.frameInterval * Double(state.frameCount) * 2
            scheduleTransitionToIdle(after: twoLoops)
        case .review:
            scheduleTransitionToIdle(after: 10.0)
        default:
            break
        }
    }

    private func scheduleTransitionToIdle(after delay: TimeInterval) {
        let workItem = DispatchWorkItem { [weak self] in
            self?.setState(.idle)
        }
        pendingTransition = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
}
