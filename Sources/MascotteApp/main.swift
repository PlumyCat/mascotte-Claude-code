import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var petWindow: PetWindow?
    private var toggleMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)

        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // MascotteApp
            .deletingLastPathComponent() // Sources
            .deletingLastPathComponent() // repo root
        let spriteURL = repoRoot.appendingPathComponent("pets/casquette/spritesheet.webp")

        guard let sheet = SpriteSheet(url: spriteURL, columns: 8, rows: 9),
              let idleFrame = sheet.cellImage(row: 0, column: 0) else {
            fatalError("Impossible de charger le spritesheet: \(spriteURL.path)")
        }

        let window = PetWindow(image: idleFrame)
        window.orderFrontRegardless()
        petWindow = window

        setupStatusItem()
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
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
