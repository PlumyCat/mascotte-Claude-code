import Foundation

/// Surveille le dossier de fichiers d'état écrits par `hooks/mascotte-hook.sh`
/// et notifie l'agrégat (waiting > running > review > idle) à chaque changement.
final class SessionStore {
    private let directoryURL: URL
    private let maxAge: TimeInterval
    private let onAggregateChange: (PetState) -> Void

    private var source: DispatchSourceFileSystemObject?
    private var directoryFileDescriptor: CInt = -1
    // Baseline = idle : au lancement, l'absence de session ne doit pas
    // interrompre l'animation de bienvenue (`.waving`) déjà en cours.
    private var lastAggregate: PetState = .idle

    static var defaultDirectoryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/state/claude-mascotte/sessions", isDirectory: true)
    }

    init(
        directoryURL: URL = SessionStore.defaultDirectoryURL,
        maxAge: TimeInterval = 2 * 60 * 60,
        onAggregateChange: @escaping (PetState) -> Void
    ) {
        self.directoryURL = directoryURL
        self.maxAge = maxAge
        self.onAggregateChange = onAggregateChange
    }

    func start() {
        createDirectoryIfNeeded()
        reload()
        watchDirectory()
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    private func createDirectoryIfNeeded() {
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private func watchDirectory() {
        let fd = open(directoryURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        directoryFileDescriptor = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.reload()
        }
        source.setCancelHandler { [weak self] in
            guard let self, self.directoryFileDescriptor >= 0 else { return }
            close(self.directoryFileDescriptor)
            self.directoryFileDescriptor = -1
        }
        source.resume()
        self.source = source
    }

    /// Relit tous les fichiers de session, purge ceux périmés, et notifie
    /// l'agrégat uniquement s'il a changé (laisse la StateMachine gérer ses
    /// propres transitions automatiques, ex. review -> idle après 10s).
    private func reload() {
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )) ?? []

        let now = Date().timeIntervalSince1970
        var liveStates: [PetState] = []

        for url in entries where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let session = try? JSONDecoder().decode(SessionFile.self, from: data) else {
                continue
            }

            if now - session.ts > maxAge {
                try? FileManager.default.removeItem(at: url)
                continue
            }

            if let state = PetState(rawValue: session.state) {
                liveStates.append(state)
            }
        }

        let aggregate = Self.aggregate(liveStates)
        guard aggregate != lastAggregate else { return }
        lastAggregate = aggregate
        onAggregateChange(aggregate)
    }

    private static func aggregate(_ states: [PetState]) -> PetState {
        if states.contains(.waiting) { return .waiting }
        if states.contains(.running) { return .running }
        if states.contains(.review) { return .review }
        return .idle
    }
}

private struct SessionFile: Decodable {
    let state: String
    let ts: TimeInterval
}
