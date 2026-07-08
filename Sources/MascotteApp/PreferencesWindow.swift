import AppKit

/// The "Réglages Mascotte" window: a single shared instance with one tab per
/// settings theme (Mouvement / Apparence / Sons / Interaction). Most tabs are
/// placeholders for now — only the "Sons" tab has a real control, proving the
/// window applies changes through `Preferences` end to end.
///
/// `isReleasedWhenClosed = false` keeps this instance alive after the user
/// closes it, so reopening from the menu reactivates the same window instead
/// of creating a new one, and closing it never affects the app's lifecycle
/// (it runs as a `.accessory` menu-bar agent regardless of open windows).
final class PreferencesWindow: NSWindow {
    static let shared = PreferencesWindow()

    private var soundEnabledCheckbox: NSButton?
    private var movementSpeedControl: NSSegmentedControl?

    private init() {
        let contentRect = NSRect(x: 0, y: 0, width: 440, height: 320)
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        title = "Réglages Mascotte"
        level = .normal
        isReleasedWhenClosed = false
        center()
        contentView = makeTabView()
    }

    /// Brings the window to front, refreshing controls from `Preferences`
    /// first in case they changed elsewhere since it was last shown.
    func show() {
        soundEnabledCheckbox?.state = Preferences.shared.soundEnabled ? .on : .off
        movementSpeedControl?.selectedSegment = Self.segmentIndex(for: Preferences.shared.movementSpeed)
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeTabView() -> NSTabView {
        let tabView = NSTabView(frame: NSRect(x: 0, y: 0, width: 440, height: 320))
        tabView.addTabViewItem(tab("Mouvement", movementTab()))
        tabView.addTabViewItem(tab("Apparence", placeholder("Taille de la mascotte — à venir.")))
        tabView.addTabViewItem(tab("Sons", soundsTab()))
        tabView.addTabViewItem(tab("Interaction", placeholder("Clic pour focus terminal — à venir.")))
        tabView.selectTabViewItem(at: 0)
        return tabView
    }

    private func tab(_ title: String, _ view: NSView) -> NSTabViewItem {
        let item = NSTabViewItem(identifier: title)
        item.label = title
        item.view = view
        return item
    }

    private func placeholder(_ text: String) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 290))
        let label = NSTextField(wrappingLabelWithString: text)
        label.frame = NSRect(x: 20, y: 220, width: 400, height: 60)
        label.textColor = .secondaryLabelColor
        container.addSubview(label)
        return container
    }

    private func movementTab() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 290))

        let label = NSTextField(labelWithString: "Vitesse de déplacement")
        label.frame = NSRect(x: 20, y: 250, width: 250, height: 24)
        container.addSubview(label)

        let control = NSSegmentedControl(
            labels: ["Lent", "Normal", "Vif"],
            trackingMode: .selectOne,
            target: self,
            action: #selector(movementSpeedChanged(_:))
        )
        control.frame = NSRect(x: 20, y: 220, width: 240, height: 24)
        control.selectedSegment = Self.segmentIndex(for: Preferences.shared.movementSpeed)
        container.addSubview(control)
        movementSpeedControl = control

        return container
    }

    /// Segment order is Lent/Normal/Vif, matching `MovementSpeed`'s declaration order.
    private static func segmentIndex(for speed: MovementSpeed) -> Int {
        switch speed {
        case .slow: return 0
        case .normal: return 1
        case .brisk: return 2
        }
    }

    @objc private func movementSpeedChanged(_ sender: NSSegmentedControl) {
        let speed: MovementSpeed
        switch sender.selectedSegment {
        case 0: speed = .slow
        case 2: speed = .brisk
        default: speed = .normal
        }
        Preferences.shared.movementSpeed = speed
    }

    private func soundsTab() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 290))

        let checkbox = NSButton(
            checkboxWithTitle: "Activer les sons",
            target: self,
            action: #selector(toggleSoundEnabled(_:))
        )
        checkbox.frame = NSRect(x: 20, y: 250, width: 250, height: 24)
        checkbox.state = Preferences.shared.soundEnabled ? .on : .off
        container.addSubview(checkbox)
        soundEnabledCheckbox = checkbox

        return container
    }

    @objc private func toggleSoundEnabled(_ sender: NSButton) {
        Preferences.shared.soundEnabled = sender.state == .on
    }
}
