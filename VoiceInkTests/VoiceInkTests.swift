//
//  VoiceInkTests.swift
//  VoiceInkTests
//
//  Created by Prakash Joshi on 15/10/2024.
//

import AppKit
import Foundation
import Testing
@testable import VoiceInk

struct SelectiveTextNormalizerTests {
    private let normalizer = SelectiveTextNormalizer { input in
        input
            .replacingOccurrences(of: "one", with: "1")
            .replacingOccurrences(of: "Two", with: "2")
            .replacingOccurrences(of: "three", with: "3")
            .replacingOccurrences(of: "fifth", with: "5th")
            .replacingOccurrences(of: "twenty", with: "20")
            .replacingOccurrences(of: "fifty", with: "50")
            .replacingOccurrences(of: " period", with: ".")
            .replacingOccurrences(of: " comma", with: ",")
            .replacingOccurrences(of: " question mark", with: "?")
    }

    @Test func preservesOrdinaryNumberWordsWhileNormalizingPunctuation() {
        #expect(normalizer.normalizeSentence("one way or the other period") == "one way or the other.")
        #expect(normalizer.normalizeSentence("one could ask question mark") == "one could ask?")
        #expect(normalizer.normalizeSentence("I have twenty five ideas period") == "I have twenty five ideas.")
    }

    @Test func preservesDigitsChosenByTheModel() {
        let digitChangingNormalizer = SelectiveTextNormalizer { input in
            input.replacingOccurrences(of: "1", with: "one")
                .replacingOccurrences(of: " period", with: ".")
        }

        #expect(digitChangingNormalizer.normalizeSentence("I chose 1 option period") == "I chose 1 option.")
    }

    @Test func normalizesStructuredNumberExpressions() {
        #expect(normalizer.normalizeSentence("January fifth period") == "January 5th.")
        #expect(normalizer.normalizeSentence("It cost twenty dollars period") == "It cost 20 dollars.")
        #expect(normalizer.normalizeSentence("Battery is fifty percent period") == "Battery is 50 percent.")
        #expect(normalizer.normalizeSentence("The board is three meters wide period") == "The board is 3 meters wide.")
        #expect(normalizer.normalizeSentence("Meet me at three p m period") == "Meet me at 3 p m.")
    }

    @Test func doesNotMistakeModalMayForAMonth() {
        #expect(normalizer.normalizeSentence("May one ask question mark") == "May one ask?")
        #expect(normalizer.normalizeSentence("May fifth period") == "May 5th.")
    }

    @Test func preservesNumberRangesWithoutBlockingPunctuation() {
        #expect(
            normalizer.normalizeSentence("Choose one to three comma then stop period")
                == "Choose one to three, then stop."
        )
    }

    @Test func doesNotMergeNumberSpansAcrossSentences() {
        #expect(normalizer.normalizeSentence("one. Two dollars period") == "one. 2 dollars.")
    }

    @Test func integratesWithFluidAudioNormalizer() {
        let fluidAudioNormalizer = SelectiveTextNormalizer()

        #expect(fluidAudioNormalizer.normalizeSentence("one way or the other") == "one way or the other")
        #expect(fluidAudioNormalizer.normalizeSentence("five dollars and fifty cents") == "$5.50")
        #expect(
            fluidAudioNormalizer.normalizeSentence("January fifth twenty twenty five")
                == "January 5 2025"
        )
        #expect(fluidAudioNormalizer.normalizeSentence("hello comma world") == "hello, world")
    }
}

@MainActor
struct RecorderPanelFocusTests {
    @Test func miniPanelOnlyBecomesKeyForKeyboardInput() {
        let panel = MiniRecorderPanel(contentRect: .zero)

        #expect(panel.canBecomeKey)
        #expect(!panel.canBecomeMain)
        #expect(panel.becomesKeyOnlyIfNeeded)
    }

    @Test func notchPanelOnlyBecomesKeyForKeyboardInput() {
        let panel = NotchRecorderPanel(contentRect: .zero)

        #expect(panel.canBecomeKey)
        #expect(!panel.canBecomeMain)
        #expect(panel.becomesKeyOnlyIfNeeded)
    }
}
