import Foundation

enum PetState: String, CaseIterable {
    case idle
    case runningRight = "running-right"
    case runningLeft = "running-left"
    case waving
    case jumping
    case failed
    case waiting
    case running
    case review

    var row: Int {
        switch self {
        case .idle: return 0
        case .runningRight: return 1
        case .runningLeft: return 2
        case .waving: return 3
        case .jumping: return 4
        case .failed: return 5
        case .waiting: return 6
        case .running: return 7
        case .review: return 8
        }
    }

    var frameCount: Int {
        switch self {
        case .idle: return 6
        case .runningRight: return 8
        case .runningLeft: return 8
        case .waving: return 4
        case .jumping: return 5
        case .failed: return 8
        case .waiting: return 6
        case .running: return 6
        case .review: return 6
        }
    }
}
