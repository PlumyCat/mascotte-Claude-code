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
    private var petScaleSlider: NSSlider?
    private var petScaleValueLabel: NSTextField?

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
        let scale = Preferences.shared.petScale
        petScaleSlider?.doubleValue = scale
        petScaleValueLabel?.stringValue = Self.formatScale(scale)
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeTabView() -> NSTabView {
        let tabView = NSTabView(frame: NSRect(x: 0, y: 0, width: 440, height: 320))
        tabView.addTabViewItem(tab("Mouvement", placeholder("Vitesse de déplacement (lent / normal / rapide) — à venir.")))
        tabView.addTabViewItem(tab("Apparence", appearanceTab()))
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

    private func appearanceTab() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 290))

        let title = NSTextField(labelWithString: "Taille de la mascotte")
        title.frame = NSRect(x: 20, y: 250, width: 300, height: 20)
        container.addSubview(title)

        let scale = Preferences.shared.petScale

        let slider = NSSlider(
            value: scale,
            minValue: Preferences.petScaleRange.lowerBound,
            maxValue: Preferences.petScaleRange.upperBound,
            target: self,
            action: #selector(petScaleChanged(_:))
        )
        slider.frame = NSRect(x: 20, y: 220, width: 300, height: 24)
        slider.isContinuous = true
        container.addSubview(slider)
        petScaleSlider = slider

        let valueLabel = NSTextField(labelWithString: Self.formatScale(scale))
        valueLabel.frame = NSRect(x: 330, y: 220, width: 60, height: 24)
        valueLabel.textColor = .secondaryLabelColor
        container.addSubview(valueLabel)
        petScaleValueLabel = valueLabel

        return container
    }

    @objc private func petScaleChanged(_ sender: NSSlider) {
        Preferences.shared.petScale = sender.doubleValue
        petScaleValueLabel?.stringValue = Self.formatScale(sender.doubleValue)
    }

    private static func formatScale(_ scale: Double) -> String {
        String(format: "%.1fx", scale)
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
