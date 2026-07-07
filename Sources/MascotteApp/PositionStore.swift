import AppKit

/// Persists and restores the pet window's on-screen origin across launches.
enum PositionStore {
    private static let defaultsKey = "MascotteApp.WindowOrigin"

    static func save(_ origin: NSPoint) {
        UserDefaults.standard.set(["x": origin.x, "y": origin.y], forKey: defaultsKey)
    }

    /// Returns the saved origin if it still lands on a connected screen,
    /// otherwise the bottom-right corner of the primary screen.
    static func loadOrigin(windowSize: NSSize) -> NSPoint {
        if let saved = savedOrigin(), isOnAnyScreen(origin: saved, windowSize: windowSize) {
            return saved
        }
        return fallbackOrigin(windowSize: windowSize)
    }

    private static func savedOrigin() -> NSPoint? {
        guard let dict = UserDefaults.standard.dictionary(forKey: defaultsKey),
              let x = dict["x"] as? Double,
              let y = dict["y"] as? Double else {
            return nil
        }
        return NSPoint(x: x, y: y)
    }

    private static func isOnAnyScreen(origin: NSPoint, windowSize: NSSize) -> Bool {
        let rect = NSRect(origin: origin, size: windowSize)
        return NSScreen.screens.contains { $0.visibleFrame.intersects(rect) }
    }

    private static func fallbackOrigin(windowSize: NSSize) -> NSPoint {
        let primaryScreen = NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.main
        guard let screen = primaryScreen else { return .zero }
        let visible = screen.visibleFrame
        let x = visible.maxX - windowSize.width
        let y = visible.minY
        return NSPoint(x: x, y: y)
    }
}
