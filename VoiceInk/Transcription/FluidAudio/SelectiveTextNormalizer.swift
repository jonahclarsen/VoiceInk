import FluidAudio
import Foundation

/// Applies FluidAudio's inverse text normalization while preserving the model's
/// choice to spell ordinary numbers as words or digits.
struct SelectiveTextNormalizer {
    private struct Token {
        let range: Range<String.Index>
        let text: String

        var lowercase: String {
            text.lowercased()
        }
    }

    private struct NumberSpan {
        let tokenRange: ClosedRange<Int>
        let stringRange: Range<String.Index>
        let containsOrdinal: Bool
    }

    private let normalize: (String) -> String

    init(normalize: @escaping (String) -> String = { TextNormalizer.shared.normalizeSentence($0) }) {
        self.normalize = normalize
    }

    func normalizeSentence(_ input: String) -> String {
        let tokens = Self.tokens(in: input)
        let protectedSpans = Self.numberSpans(in: input, tokens: tokens).filter {
            !Self.isStructured($0, in: input, tokens: tokens)
        }

        guard !protectedSpans.isEmpty else {
            return Self.cleanPunctuationSpacing(normalize(input))
        }

        let (masked, replacements) = Self.mask(protectedSpans, in: input)
        var result = normalize(masked)
        for (sentinel, original) in replacements {
            result = result.replacingOccurrences(of: sentinel, with: original)
        }
        return Self.cleanPunctuationSpacing(result)
    }

    private static func tokens(in input: String) -> [Token] {
        let pattern = #"[\p{L}\p{N}]+(?:[’'-][\p{L}\p{N}]+)*"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let fullRange = NSRange(input.startIndex..<input.endIndex, in: input)
        return expression.matches(in: input, range: fullRange).compactMap { match in
            guard let range = Range(match.range, in: input) else {
                return nil
            }
            return Token(range: range, text: String(input[range]))
        }
    }

    private static func numberSpans(in input: String, tokens: [Token]) -> [NumberSpan] {
        var spans: [NumberSpan] = []
        var index = 0

        while index < tokens.count {
            guard isNumberToken(tokens[index].lowercase) else {
                index += 1
                continue
            }

            let start = index
            var end = index
            var containsOrdinal = isOrdinalToken(tokens[index].lowercase)

            while end + 1 < tokens.count {
                let next = tokens[end + 1].lowercase
                if isNumberToken(next), tokensHaveWhitespaceBetween(end, end + 1, tokens: tokens, input: input) {
                    end += 1
                    containsOrdinal = containsOrdinal || isOrdinalToken(next)
                    continue
                }

                if numberConnectors.contains(next),
                    end + 2 < tokens.count,
                    isNumberToken(tokens[end + 2].lowercase),
                    tokensHaveWhitespaceBetween(end, end + 1, tokens: tokens, input: input),
                    tokensHaveWhitespaceBetween(end + 1, end + 2, tokens: tokens, input: input)
                {
                    end += 2
                    containsOrdinal = containsOrdinal || isOrdinalToken(tokens[end].lowercase)
                    continue
                }

                break
            }

            spans.append(
                NumberSpan(
                    tokenRange: start...end,
                    stringRange: tokens[start].range.lowerBound..<tokens[end].range.upperBound,
                    containsOrdinal: containsOrdinal
                )
            )
            index = end + 1
        }

        return spans
    }

    private static func tokensHaveWhitespaceBetween(
        _ first: Int,
        _ second: Int,
        tokens: [Token],
        input: String
    ) -> Bool {
        let separator = input[tokens[first].range.upperBound..<tokens[second].range.lowerBound]
        return !separator.isEmpty && separator.allSatisfy(\.isWhitespace)
    }

    private static func isStructured(_ span: NumberSpan, in input: String, tokens: [Token]) -> Bool {
        let start = span.tokenRange.lowerBound
        let end = span.tokenRange.upperBound
        let previous = token(at: start - 1, in: tokens)
        let previousTwo = token(at: start - 2, in: tokens)
        let next = token(at: end + 1, in: tokens)
        let nextTwo = token(at: end + 2, in: tokens)

        if let next, structuredSuffixes.contains(next) {
            return true
        }

        if let previous, structuredPrefixes.contains(previous) {
            return true
        }

        if next == "per", nextTwo == "cent" {
            return true
        }

        if (next == "a" || next == "p"), nextTwo == "m" {
            return true
        }

        if let previous, months.contains(previous),
            (previous != "may" && previous != "march" || span.containsOrdinal)
        {
            return true
        }

        if previous == "the", let previousTwo, months.contains(previousTwo),
            (previousTwo != "may" && previousTwo != "march" || span.containsOrdinal)
        {
            return true
        }

        if span.containsOrdinal {
            if let next, months.contains(next) {
                return true
            }
            if next == "of", let nextTwo, months.contains(nextTwo) {
                return true
            }
        }

        let prefixStart = start > 0 ? tokens[start - 1].range.upperBound : input.startIndex
        let prefix = input[prefixStart..<span.stringRange.lowerBound]
        if prefix.contains(where: currencySymbols.contains) {
            return true
        }

        let suffixEnd = end + 1 < tokens.count ? tokens[end + 1].range.lowerBound : input.endIndex
        let suffix = input[span.stringRange.upperBound..<suffixEnd]
        return suffix.contains("%")
    }

    private static func token(at index: Int, in tokens: [Token]) -> String? {
        guard tokens.indices.contains(index) else {
            return nil
        }
        return tokens[index].lowercase
    }

    private static func isNumberToken(_ token: String) -> Bool {
        let components = token.split(whereSeparator: { "-'’".contains($0) }).map(String.init)
        guard !components.isEmpty else {
            return false
        }

        return components.allSatisfy { component in
            numberWords.contains(component) || isDigitToken(component)
        }
    }

    private static func isOrdinalToken(_ token: String) -> Bool {
        let components = token.split(whereSeparator: { "-'’".contains($0) }).map(String.init)
        return components.contains(where: ordinalWords.contains) || components.contains { component in
            let suffixes = ["st", "nd", "rd", "th"]
            guard let suffix = suffixes.first(where: component.hasSuffix) else {
                return false
            }
            return component.dropLast(suffix.count).allSatisfy(\.isNumber)
        }
    }

    private static func isDigitToken(_ token: String) -> Bool {
        if token.allSatisfy(\.isNumber) {
            return true
        }

        for suffix in ["st", "nd", "rd", "th"] where token.hasSuffix(suffix) {
            let digits = token.dropLast(suffix.count)
            return !digits.isEmpty && digits.allSatisfy(\.isNumber)
        }
        return false
    }

    private static func mask(_ spans: [NumberSpan], in input: String) -> (String, [String: String]) {
        var output = ""
        var replacements: [String: String] = [:]
        var cursor = input.startIndex

        for (offset, span) in spans.enumerated() {
            output += input[cursor..<span.stringRange.lowerBound]
            guard let scalar = UnicodeScalar(0xF000 + offset) else {
                output += input[span.stringRange]
                cursor = span.stringRange.upperBound
                continue
            }

            let sentinel = String(Character(scalar))
            output += sentinel
            replacements[sentinel] = String(input[span.stringRange])
            cursor = span.stringRange.upperBound
        }

        output += input[cursor...]
        return (output, replacements)
    }

    private static func cleanPunctuationSpacing(_ input: String) -> String {
        input.replacingOccurrences(
            of: #"\s+([,.;:!?])"#,
            with: "$1",
            options: .regularExpression
        )
    }

    private static let numberConnectors: Set<String> = [
        "and", "over", "point", "through", "to",
    ]

    private static let numberWords: Set<String> = [
        "zero", "oh", "nought", "nil",
        "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
        "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen",
        "eighteen", "nineteen", "twenty", "thirty", "forty", "fifty", "sixty", "seventy",
        "eighty", "ninety",
        "hundred", "thousand", "million", "billion", "trillion",
        "hundreds", "thousands", "millions", "billions", "trillions",
        "first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth",
        "tenth", "eleventh", "twelfth", "thirteenth", "fourteenth", "fifteenth", "sixteenth",
        "seventeenth", "eighteenth", "nineteenth", "twentieth", "thirtieth", "fortieth",
        "fiftieth", "sixtieth", "seventieth", "eightieth", "ninetieth", "hundredth",
        "thousandth", "millionth", "billionth",
        "half", "halves", "quarter", "quarters", "thirds", "fourths", "fifths", "sixths",
        "sevenths", "eighths", "ninths", "tenths",
    ]

    private static let ordinalWords: Set<String> = [
        "first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth",
        "tenth", "eleventh", "twelfth", "thirteenth", "fourteenth", "fifteenth", "sixteenth",
        "seventeenth", "eighteenth", "nineteenth", "twentieth", "thirtieth", "fortieth",
        "fiftieth", "sixtieth", "seventieth", "eightieth", "ninetieth", "hundredth",
        "thousandth", "millionth", "billionth",
    ]

    private static let months: Set<String> = [
        "january", "february", "march", "april", "may", "june",
        "july", "august", "september", "october", "november", "december",
    ]

    private static let structuredPrefixes: Set<String> = [
        "year", "years",
    ]

    private static let structuredSuffixes: Set<String> = [
        "am", "pm", "oclock",
        "percent", "percentage",
        "cent", "cents", "dollar", "dollars", "buck", "bucks", "euro", "euros", "pound", "pounds",
        "franc", "francs", "peso", "pesos", "rupee", "rupees", "yen", "yuan", "won",
        "millimeter", "millimeters", "centimeter", "centimeters", "meter", "meters", "kilometer",
        "kilometers", "inch", "inches", "foot", "feet", "yard", "yards", "mile", "miles",
        "milligram", "milligrams", "gram", "grams", "kilogram", "kilograms", "ounce", "ounces",
        "ton", "tons", "liter", "liters", "milliliter", "milliliters", "gallon", "gallons",
        "degree", "degrees", "celsius", "fahrenheit",
        "bit", "bits", "byte", "bytes", "kilobyte", "kilobytes", "megabyte", "megabytes",
        "gigabyte", "gigabytes", "terabyte", "terabytes",
        "millisecond", "milliseconds", "second", "seconds", "minute", "minutes", "hour", "hours",
        "day", "days", "week", "weeks", "month", "months", "year", "years",
    ]

    private static let currencySymbols: Set<Character> = ["$", "€", "£", "¥", "₹", "₩"]
}
