import Testing
@testable import VoiceInk

struct SingleLineFormatterTests {
    @Test func joinsParagraphsAndLinesWithSingleSpaces() {
        #expect(SingleLineFormatter.format("First idea.\n\nSecond idea.") == "First idea. Second idea.")
        #expect(SingleLineFormatter.format("One \n  \r\n two\u{2028}three") == "One two three")
    }

    @Test func keepsListMarkersReadableOnOneLine() {
        #expect(SingleLineFormatter.format("Steps:\n1. Build\n2. Test") == "Steps: 1. Build 2. Test")
    }

    @Test func leavesSingleLineTextUnchanged() {
        #expect(SingleLineFormatter.format("Already  one line ") == "Already  one line ")
    }
}
