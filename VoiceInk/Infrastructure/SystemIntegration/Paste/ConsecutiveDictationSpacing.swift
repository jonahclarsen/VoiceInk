import AppKit

/// Main-run-loop state only: no polling and no storage of typed characters.
@MainActor
final class ConsecutiveDictationSpacing {
    static let shared = ConsecutiveDictationSpacing()
    static let pasteEventMarker: Int64 = 0x56494E4B

    private var monitors: [ObjectIdentifier: [Shortcut]] = [:]
    private var previousProcessID: pid_t?
    private var needsSeparator = false
    private var endedSentence = true
    private(set) var revision: UInt64 = 0
    private var activationObserver: NSObjectProtocol?

    init(observeApplicationChanges: Bool = true) {
        if observeApplicationChanges {
            activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.invalidate() }
            }
        }
    }

    deinit {
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
    }

    func register(_ monitor: ObjectIdentifier, shortcuts: [Shortcut]) {
        monitors[monitor] = shortcuts
    }

    func unregister(_ monitor: ObjectIdentifier) {
        monitors.removeValue(forKey: monitor)
        if monitors.isEmpty { invalidate() }
    }

    func invalidate() {
        revision &+= 1
        previousProcessID = nil
        needsSeparator = false
        endedSentence = true
    }

    func observe(_ type: CGEventType, event: CGEvent) {
        guard type == .keyDown || type == .leftMouseDown || type == .rightMouseDown || type == .otherMouseDown else {
            return
        }
        if event.getIntegerValueField(.eventSourceUserData) == Self.pasteEventMarker { return }
        let flags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
        let isKey = type == .keyDown
        let code = UInt16(clamping: event.getIntegerValueField(isKey ? .keyboardEventKeycode : .mouseEventButtonNumber))

        // System Events posts the alternate AppleScript paste on our behalf.
        if isKey, code == 9, flags.contains(.command),
            NSRunningApplication(processIdentifier: pid_t(event.getIntegerValueField(.eventSourceUnixProcessID)))?
                .bundleIdentifier == "com.apple.systemevents"
        { return }

        let isRecordingShortcut = monitors.values.joined().contains { shortcut in
            isKey ? shortcut.matchesKeyEvent(keyCode: code, modifierFlags: flags)
                : shortcut.matchesMouseEvent(buttonNumber: code, modifierFlags: flags)
        }
        if !isRecordingShortcut { invalidate() }
    }

    func prepare(_ text: String, processID: pid_t?) -> (text: String, revision: UInt64) {
        let addSpace = !monitors.isEmpty && processID != nil && previousProcessID == processID
            && needsSeparator && text.first.map { !$0.isWhitespace } == true
        let continuesSentence = addSpace && !endedSentence
        invalidate()
        let body = continuesSentence ? Self.lowercasingFirstWord(text) : text
        return (addSpace ? " " + body : body, revision)
    }

    /// Lowercases the leading capital of a mid-sentence continuation, keeping "I" words and acronyms.
    static func lowercasingFirstWord(_ text: String) -> String {
        let word = text.prefix { $0.isLetter || $0 == "'" || $0 == "\u{2019}" }
        guard let first = word.first, first.isUppercase else { return text }
        let pronounI: Set<String> = ["I", "I'm", "I've", "I'll", "I'd"]
        if pronounI.contains(word.replacingOccurrences(of: "\u{2019}", with: "'")) { return text }
        if word.dropFirst().first?.isUppercase == true { return text }
        return first.lowercased() + text.dropFirst()
    }

    func didPost(_ text: String, processID: pid_t?, revision expectedRevision: UInt64) {
        guard revision == expectedRevision, !monitors.isEmpty else { return }
        previousProcessID = processID
        needsSeparator = text.last.map { !$0.isWhitespace } ?? false
        endedSentence = text.last { !$0.isWhitespace }.map { ".!?:".contains($0) } ?? true
    }
}
