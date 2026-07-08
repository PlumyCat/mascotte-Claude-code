import AppKit
import Foundation

/// Brings the terminal app behind the most relevant Claude Code session to
/// the front when the user clicks the pet (S-10). Best-effort only: an
/// unknown/missing `term_program`, or no matching running app, is a silent
/// no-op — this must never surface an error or crash from a mouse click.
enum TerminalFocusService {
    private static let bundleIDByTermProgram: [String: String] = [
        "Apple_Terminal": "com.apple.Terminal",
        "iTerm.app": "com.googlecode.iterm2",
        "vscode": "com.microsoft.VSCode",
    ]

    static func focusMostRelevantTerminal() {
        guard Preferences.shared.clickToFocusTerminal else { return }
        guard let session = mostRelevantSession(SessionStore.loadSessions()) else { return }
        guard let termProgram = session.termProgram,
              let bundleID = bundleIDByTermProgram[termProgram],
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
            return
        }
        app.activate(options: [])
    }

    /// Priority: the most recent `waiting` session (a worker asking for
    /// input is the one you want to jump to), falling back to whichever
    /// live session was most recently active.
    private static func mostRelevantSession(_ sessions: [SessionStore.SessionInfo]) -> SessionStore.SessionInfo? {
        if let waiting = sessions.filter({ $0.state == "waiting" }).max(by: { $0.ts < $1.ts }) {
            return waiting
        }
        return sessions.max(by: { $0.ts < $1.ts })
    }
}
