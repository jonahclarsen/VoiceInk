import Foundation

/// Collapses blank lines between paragraphs so each paragraph break is a single line break.
enum ParagraphBreakFormatter {
    static func format(_ text: String) -> String {
        text.replacingOccurrences(of: "\\R(?:[ \\t]*\\R)+", with: "\n", options: .regularExpression)
    }
}
