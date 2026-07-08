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
    private var soundVolumeSlider: NSSlider?
    private var soundTriggerCheckboxes: [PetState: NSButton] = [:]

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
        soundVolumeSlider?.doubleValue = Preferences.shared.soundVolume
        let triggers = Preferences.shared.soundTriggers
        for (state, checkbox) in soundTriggerCheckboxes {
            checkbox.state = triggers.contains(state) ? .on : .off
        }
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeTabView() -> NSTabView {
        let tabView = NSTabView(frame: NSRect(x: 0, y: 0, width: 440, height: 320))
        tabView.addTabViewItem(tab("Mouvement", placeholder("Vitesse de déplacement (lent / normal / rapide) — à venir.")))
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

        let volumeLabel = NSTextField(labelWithString: "Volume")
        volumeLabel.frame = NSRect(x: 20, y: 210, width: 100, height: 20)
        container.addSubview(volumeLabel)

        let slider = NSSlider(
            value: Preferences.shared.soundVolume,
            minValue: 0,
            maxValue: 1,
            target: self,
            action: #selector(changeSoundVolume(_:))
        )
        slider.frame = NSRect(x: 20, y: 190, width: 300, height: 20)
        container.addSubview(slider)
        soundVolumeSlider = slider

        let triggersLabel = NSTextField(labelWithString: "Jouer un son sur :")
        triggersLabel.frame = NSRect(x: 20, y: 150, width: 250, height: 20)
        container.addSubview(triggersLabel)

        let triggerOptions: [(PetState, String)] = [
            (.waiting, "En attente (waiting)"),
            (.review, "Revue (review)"),
            (.running, "En cours (running)"),
        ]

        for (index, option) in triggerOptions.enumerated() {
            let (state, title) = option
            let triggerCheckbox = NSButton(
                checkboxWithTitle: title,
                target: self,
                action: #selector(toggleSoundTrigger(_:))
            )
            triggerCheckbox.frame = NSRect(x: 20, y: 125 - (index * 25), width: 300, height: 24)
            triggerCheckbox.state = Preferences.shared.soundTriggers.contains(state) ? .on : .off
            container.addSubview(triggerCheckbox)
            soundTriggerCheckboxes[state] = triggerCheckbox
        }

        return container
    }

    @objc private func toggleSoundEnabled(_ sender: NSButton) {
        Preferences.shared.soundEnabled = sender.state == .on
    }

    @objc private func changeSoundVolume(_ sender: NSSlider) {
        Preferences.shared.soundVolume = sender.doubleValue
    }

    @objc private func toggleSoundTrigger(_ sender: NSButton) {
        guard let state = soundTriggerCheckboxes.first(where: { $0.value === sender })?.key else { return }
        var triggers = Preferences.shared.soundTriggers
        if sender.state == .on {
            triggers.insert(state)
        } else {
            triggers.remove(state)
        }
        Preferences.shared.soundTriggers = triggers
    }
}
