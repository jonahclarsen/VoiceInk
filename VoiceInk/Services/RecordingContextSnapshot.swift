import AppKit
import Foundation

struct RecordingContextSnapshot {
    var capturedAt = Date()
    var selectedText: String?
    var clipboardText: String?
    var screenText: String?
}

struct RecordingContextCaptureOptions: Equatable {
    let capturesSelectedText: Bool
    let capturesClipboard: Bool
    let capturesScreen: Bool

    init(enhancementConfiguration: EnhancementRuntimeConfiguration?) {
        guard let enhancementConfiguration, enhancementConfiguration.isEnabled else {
            capturesSelectedText = false
            capturesClipboard = false
            capturesScreen = false
            return
        }

        capturesSelectedText = enhancementConfiguration.useSelectedTextContext
        capturesClipboard = enhancementConfiguration.useClipboardContext
        capturesScreen = enhancementConfiguration.useScreenCaptureContext
    }

    var capturesAnyContext: Bool {
        capturesSelectedText || capturesClipboard || capturesScreen
    }
}

@MainActor
final class RecordingContextSnapshotStore {
    private(set) var snapshot = RecordingContextSnapshot()

    func updateSelectedText(_ text: String?) {
        snapshot.selectedText = Self.normalized(text)
    }

    func updateClipboardText(_ text: String?) {
        snapshot.clipboardText = Self.normalized(text)
    }

    func updateScreenText(_ text: String?) {
        snapshot.screenText = Self.normalized(text)
    }

    private static func normalized(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

@MainActor
enum RecordingContextCaptureService {
    static func startCapture(
        into store: RecordingContextSnapshotStore,
        options: RecordingContextCaptureOptions
    ) -> [Task<Void, Never>] {
        var tasks: [Task<Void, Never>] = []

        if options.capturesClipboard {
            tasks.append(Task { @MainActor in
                store.updateClipboardText(NSPasteboard.general.string(forType: .string))
            })
        }

        if options.capturesSelectedText {
            tasks.append(Task { @MainActor in
                guard !Task.isCancelled else { return }
                let selectedText = await SelectedTextService.fetchSelectedText()
                guard !Task.isCancelled else { return }
                store.updateSelectedText(selectedText)
            })
        }

        if options.capturesScreen {
            tasks.append(Task { @MainActor in
                guard CGPreflightScreenCaptureAccess(), !Task.isCancelled else { return }
                let screenCaptureService = ScreenCaptureService()
                let screenText = await screenCaptureService.captureAndExtractText()
                guard !Task.isCancelled else { return }
                store.updateScreenText(screenText)
            })
        }

        return tasks
    }
}
