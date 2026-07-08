import Foundation

extension Notification.Name {
    /// Posted whenever any `Preferences` property changes, so live UI (menu
    /// items, the settings window, future sound/animation code) can react
    /// immediately instead of polling UserDefaults.
    static let mascottePreferencesChanged = Notification.Name("MascotteApp.mascottePreferencesChanged")
}

enum MovementSpeed: String, CaseIterable {
    case slow
    case normal
    case brisk
}

/// Single source of truth for user-configurable settings, persisted in
/// UserDefaults. Every property is readable/writable independently; writing
/// one persists it and posts `.mascottePreferencesChanged`.
///
/// Most keys below aren't wired into behavior yet (movement speed, pet scale,
/// sound triggers/volume/pack, click-to-focus) — they're declared now with
/// their future defaults so later stories only add the consuming code, not
/// more persistence plumbing.
final class Preferences {
    static let shared = Preferences()

    /// Valid range for `petScale`; enforced on both read and write so a
    /// stray/out-of-range stored value (e.g. from a future format change)
    /// can never size the pet window outside what the UI/drag logic expects.
    static let petScaleRange: ClosedRange<Double> = 0.5...2.0

    private init() {}

    private let defaults = UserDefaults.standard

    private enum Key {
        static let movementSpeed = "MascotteApp.Preferences.movementSpeed"
        static let petScale = "MascotteApp.Preferences.petScale"
        static let soundEnabled = "MascotteApp.Preferences.soundEnabled"
        static let soundTriggers = "MascotteApp.Preferences.soundTriggers"
        static let soundVolume = "MascotteApp.Preferences.soundVolume"
        static let soundPack = "MascotteApp.Preferences.soundPack"
        static let clickToFocusTerminal = "MascotteApp.Preferences.clickToFocusTerminal"
    }

    var movementSpeed: MovementSpeed {
        get { defaults.string(forKey: Key.movementSpeed).flatMap(MovementSpeed.init) ?? .normal }
        set {
            defaults.set(newValue.rawValue, forKey: Key.movementSpeed)
            notifyChanged()
        }
    }

    var petScale: Double {
        get { Self.clampScale(defaults.object(forKey: Key.petScale) as? Double ?? 1.0) }
        set {
            defaults.set(Self.clampScale(newValue), forKey: Key.petScale)
            notifyChanged()
        }
    }

    private static func clampScale(_ value: Double) -> Double {
        min(max(value, petScaleRange.lowerBound), petScaleRange.upperBound)
    }

    var soundEnabled: Bool {
        get { defaults.object(forKey: Key.soundEnabled) as? Bool ?? true }
        set {
            defaults.set(newValue, forKey: Key.soundEnabled)
            notifyChanged()
        }
    }

    var soundTriggers: Set<PetState> {
        get {
            guard let raw = defaults.array(forKey: Key.soundTriggers) as? [String] else {
                return [.waiting]
            }
            return Set(raw.compactMap(PetState.init(rawValue:)))
        }
        set {
            defaults.set(newValue.map(\.rawValue), forKey: Key.soundTriggers)
            notifyChanged()
        }
    }

    var soundVolume: Double {
        get { defaults.object(forKey: Key.soundVolume) as? Double ?? 0.7 }
        set {
            defaults.set(newValue, forKey: Key.soundVolume)
            notifyChanged()
        }
    }

    var soundPack: String {
        get { defaults.string(forKey: Key.soundPack) ?? "default" }
        set {
            defaults.set(newValue, forKey: Key.soundPack)
            notifyChanged()
        }
    }

    var clickToFocusTerminal: Bool {
        get { defaults.object(forKey: Key.clickToFocusTerminal) as? Bool ?? true }
        set {
            defaults.set(newValue, forKey: Key.clickToFocusTerminal)
            notifyChanged()
        }
    }

    private func notifyChanged() {
        NotificationCenter.default.post(name: .mascottePreferencesChanged, object: self)
    }
}
