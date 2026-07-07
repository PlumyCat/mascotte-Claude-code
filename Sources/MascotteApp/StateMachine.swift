import Foundation

final class StateMachine {
    private let engine: SpriteEngine
    private(set) var currentState: PetState
    private var pendingTransition: DispatchWorkItem?

    init(engine: SpriteEngine, initialState: PetState = .waving) {
        self.engine = engine
        self.currentState = initialState
        applyState(initialState)
    }

    func setState(_ state: PetState) {
        applyState(state)
    }

    private func applyState(_ state: PetState) {
        pendingTransition?.cancel()
        pendingTransition = nil

        currentState = state
        engine.setRow(state.row, frameCount: state.frameCount)
        scheduleAutoTransition(for: state)
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
