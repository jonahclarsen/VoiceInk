import Testing
@testable import VoiceInk

struct ParagraphBreakFormatterTests {
    @Test func collapsesBlankLinesToSingleLineBreaks() {
        #expect(ParagraphBreakFormatter.format("First idea.\n\nSecond idea.") == "First idea.\nSecond idea.")
        #expect(ParagraphBreakFormatter.format("One\r\n  \r\n\n\ntwo") == "One\ntwo")
    }

    @Test func keepsSingleLineBreaksAndIndentation() {
        #expect(ParagraphBreakFormatter.format("Steps:\n  1. Build\n  2. Test") == "Steps:\n  1. Build\n  2. Test")
    }
}
