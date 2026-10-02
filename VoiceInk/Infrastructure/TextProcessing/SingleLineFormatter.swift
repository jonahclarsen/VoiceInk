import Foundation

/// Joins line and paragraph breaks into spaces so apps that send on Return receive the whole dictation.
enum SingleLineFormatter {
    static func format(_ text: String) -> String {
        text.replacingOccurrences(of: "[ \\t]*(?:\\R[ \\t]*)+", with: " ", options: .regularExpression)
    }
}
