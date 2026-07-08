import AppKit
import AVFoundation

/// Plays a short notification sound when the pet enters a state the user has
/// opted into (`Preferences.shared.soundTriggers`, `.waiting` by default).
///
/// Attaches as an *additional* `StateMachine` observer (see
/// `StateMachine.addObserver`) so it never disturbs `WanderController`'s own
/// `onStateChange` closure. Because observers only receive states entered
/// *after* they register, the app's initial `.waving` welcome pose — and any
/// state the machine was already in at launch — is never replayed as sound.
final class SoundPlayer {
    private var player: AVAudioPlayer?
    private var lastHandledState: PetState?

    func attach(to stateMachine: StateMachine) {
        stateMachine.addObserver { [weak self] state in
            self?.handleStateChange(state)
        }
    }

    private func handleStateChange(_ state: PetState) {
        guard state != lastHandledState else { return }
        lastHandledState = state

        guard Preferences.shared.soundEnabled else { return }
        guard Preferences.shared.soundTriggers.contains(state) else { return }

        play()
    }

    private func play() {
        guard let url = Self.resolveSoundURL() else { return }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = Float(Preferences.shared.soundVolume)
            player.prepareToPlay()
            player.play()
            self.player = player
        } catch {
            FileHandle.standardError.write(
                "SoundPlayer: failed to play \(url.lastPathComponent): \(error)\n".data(using: .utf8)!
            )
        }
    }

    /// Resolves the bundled notification sound: inside
    /// `Mascotte.app/Contents/Resources` when running as a bundled app,
    /// falling back to the repo's `Resources/sounds/` tree for `swift run` in
    /// development. Returns nil (silent fallback, never crashes) if missing.
    private static func resolveSoundURL() -> URL? {
        let filename = "\(Preferences.shared.soundPack)-notify.aiff"
        let fallbackFilename = "notify.aiff"

        if let resourceURL = Bundle.main.resourceURL {
            for candidate in [filename, fallbackFilename] {
                let bundled = resourceURL.appendingPathComponent(candidate)
                if FileManager.default.fileExists(atPath: bundled.path) {
                    return bundled
                }
            }
        }

        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // MascotteApp
            .deletingLastPathComponent() // Sources
            .deletingLastPathComponent() // repo root
        let soundsDir = repoRoot.appendingPathComponent("Sources/MascotteApp/Resources/sounds")

        for candidate in [filename, fallbackFilename] {
            let devURL = soundsDir.appendingPathComponent(candidate)
            if FileManager.default.fileExists(atPath: devURL.path) {
                return devURL
            }
        }

        return nil
    }
}
