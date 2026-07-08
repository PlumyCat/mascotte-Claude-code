import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var petWindow: PetWindow?
    private var toggleMenuItem: NSMenuItem?
    private var launchAtLoginMenuItem: NSMenuItem?
    private var spriteEngine: SpriteEngine?
    private var stateMachine: StateMachine?
    private var wanderController: WanderController?
    private var sessionStore: SessionStore?
    private var soundPlayer: SoundPlayer?
    private var cycleTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)

        let spriteURL = Self.resolveSpritesheetURL()

        guard let sheet = SpriteSheet(url: spriteURL, columns: 8, rows: 9) else {
            Self.presentFatalErrorAndExit("Impossible de charger le spritesheet:\n\(spriteURL.path)")
        }

        let cellSize = CGSize(width: sheet.cellWidth, height: sheet.cellHeight)
        let window = PetWindow(cellSize: cellSize)
        window.orderFrontRegardless()
        petWindow = window

        let engine = SpriteEngine(
            layer: window.spriteView.layer!,
            sheetImage: sheet.image,
            columns: sheet.columns,
            rows: sheet.rows,
            initialRow: PetState.waving.row,
            initialFrameCount: PetState.waving.frameCount
        )
        spriteEngine = engine

        let machine = StateMachine(engine: engine, initialState: .waving)
        stateMachine = machine
        window.stateMachine = machine

        let wander = WanderController(
            window: window,
            stateMachine: machine,
            fastMode: CommandLine.arguments.contains("--wander-fast")
        )
        wanderController = wander

        window.willBeginDrag = { [weak wander] in
            wander?.stop()
        }
        window.didEndDrag = { origin in
            PositionStore.save(origin)
        }

        setupStatusItem()

        NotificationCenter.default.addObserver(
            forName: .mascottePreferencesChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.petWindow?.applyScale(Preferences.shared.petScale)
        }

        let sound = SoundPlayer()
        sound.attach(to: machine)
        soundPlayer = sound

        if CommandLine.arguments.contains("--cycle") {
            startCycleMode(machine: machine)
        } else {
            let store = SessionStore { [weak machine] aggregate in
                machine?.setState(aggregate)
            }
            store.start()
            sessionStore = store
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let origin = petWindow?.frame.origin {
            PositionStore.save(origin)
        }
    }

    private func startCycleMode(machine: StateMachine) {
        let states = PetState.allCases
        var index = 0

        logCycleState(states[index])
        machine.setState(states[index])

        let timer = Timer(timeInterval: 3.5, repeats: true) { [weak self] _ in
            index = (index + 1) % states.count
            self?.logCycleState(states[index])
            machine.setState(states[index])
        }
        RunLoop.main.add(timer, forMode: .common)
        cycleTimer = timer
    }

    private func logCycleState(_ state: PetState) {
        FileHandle.standardError.write("cycle: \(state.rawValue)\n".data(using: .utf8)!)
    }

    /// Resolves the spritesheet location: inside `Mascotte.app/Contents/Resources`
    /// when running as a bundled app, falling back to the repo's `pets/` tree
    /// for `swift run` in development (where `Bundle.main` has no real bundle).
    private static func resolveSpritesheetURL() -> URL {
        if let resourceURL = Bundle.main.resourceURL {
            let bundled = resourceURL.appendingPathComponent("spritesheet.webp")
            if FileManager.default.fileExists(atPath: bundled.path) {
                return bundled
            }
        }

        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // MascotteApp
            .deletingLastPathComponent() // Sources
            .deletingLastPathComponent() // repo root
        return repoRoot.appendingPathComponent("pets/casquette/spritesheet.webp")
    }

    /// Shows a blocking alert then terminates the process cleanly, used in place
    /// of `fatalError` for recoverable-looking-but-fatal startup failures.
    private static func presentFatalErrorAndExit(_ message: String) -> Never {
        let alert = NSAlert()
        alert.messageText = "Mascotte ne peut pas démarrer"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Quitter")
        alert.runModal()
        exit(1)
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = "MascotteAppStatusItem"
        if let button = item.button {
            let image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Mascotte")
            image?.isTemplate = true
            button.image = image
        }
        item.isVisible = true

        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: "Masquer", action: #selector(toggleWindow), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        toggleMenuItem = toggleItem

        menu.addItem(.separator())

        let launchAtLoginItem = NSMenuItem(
            title: "Lancer au login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        launchAtLoginItem.state = Self.launchAtLoginService.status == .enabled ? .on : .off
        menu.addItem(launchAtLoginItem)
        launchAtLoginMenuItem = launchAtLoginItem

        menu.addItem(.separator())

        let preferencesItem = NSMenuItem(title: "Réglages…", action: #selector(openPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        menu.addItem(preferencesItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quitter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    @objc private func toggleWindow() {
        guard let window = petWindow else { return }
        if window.isVisible {
            window.orderOut(nil)
            toggleMenuItem?.title = "Afficher"
        } else {
            window.orderFrontRegardless()
            toggleMenuItem?.title = "Masquer"
        }
    }

    private static var launchAtLoginService: SMAppService { .mainApp }

    @objc private func openPreferences() {
        PreferencesWindow.shared.show()
    }

    @objc private func toggleLaunchAtLogin() {
        let service = Self.launchAtLoginService
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            FileHandle.standardError.write("launch-at-login toggle failed: \(error)\n".data(using: .utf8)!)
        }
        launchAtLoginMenuItem?.state = service.status == .enabled ? .on : .off
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
