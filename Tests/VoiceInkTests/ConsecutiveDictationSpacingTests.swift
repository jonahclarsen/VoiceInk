import AppKit
import Testing
@testable import VoiceInk

@MainActor
struct ConsecutiveDictationSpacingTests {
    private func tracker() -> ConsecutiveDictationSpacing {
        let tracker = ConsecutiveDictationSpacing(observeApplicationChanges: false)
        tracker.register(ObjectIdentifier(tracker), shortcuts: [.key(keyCode: 49, modifierFlags: [.option])])
        return tracker
    }

    private func paste(_ text: String, into tracker: ConsecutiveDictationSpacing, processID: pid_t = 42) -> String {
        let prepared = tracker.prepare(text, processID: processID)
        tracker.didPost(prepared.text, processID: processID, revision: prepared.revision)
        return prepared.text
    }

    @Test func separatesConsecutiveDictationsWithoutDuplicatingWhitespace() {
        let tracker = tracker()
        #expect(paste("Hello.", into: tracker) == "Hello.")
        #expect(paste("Next.", into: tracker) == " Next.")
        #expect(paste(" Already spaced.\n", into: tracker) == " Already spaced.\n")
        #expect(paste("New paragraph.", into: tracker) == "New paragraph.")
        #expect(paste("Different app.", into: tracker, processID: 99) == "Different app.")
    }

    @Test func typingAndMouseClicksBreakContinuity() {
        for type in [CGEventType.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown] {
            let tracker = tracker()
            _ = paste("First", into: tracker)
            let event = CGEvent(source: nil)!
            event.setIntegerValueField(.keyboardEventKeycode, value: 0)
            tracker.observe(type, event: event)
            #expect(paste("Next", into: tracker) == "Next")
        }
    }

    @Test func recordingShortcutAndOwnPastePreserveContinuity() {
        let tracker = tracker()
        _ = paste("First", into: tracker)
        let shortcut = CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: true)!
        shortcut.flags = .maskAlternate
        tracker.observe(.keyDown, event: shortcut)
        let pasteEvent = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true)!
        pasteEvent.setIntegerValueField(.eventSourceUserData, value: ConsecutiveDictationSpacing.pasteEventMarker)
        tracker.observe(.keyDown, event: pasteEvent)
        #expect(paste("Next", into: tracker) == " Next")
    }

    @Test func failedPasteAndInputDuringPasteDoNotArmSpacing() {
        let tracker = tracker()
        _ = paste("First", into: tracker)
        _ = tracker.prepare("Failed", processID: 42)
        #expect(paste("Next", into: tracker) == "Next")
        let pending = tracker.prepare("Pending", processID: 42)
        tracker.invalidate()
        tracker.didPost(pending.text, processID: 42, revision: pending.revision)
        #expect(paste("After input", into: tracker) == "After input")
        tracker.unregister(ObjectIdentifier(tracker))
        #expect(paste("Without monitoring", into: tracker) == "Without monitoring")
    }
}
