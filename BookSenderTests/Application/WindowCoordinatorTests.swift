import AppKit
import Testing
@testable import BookSender

@MainActor
struct WindowCoordinatorTests {
    @Test
    func deduplicatesReopenRequestsUntilMainWindowIsCaptured() {
        var activationCount = 0
        var reopenCount = 0
        let coordinator = WindowCoordinator {
            activationCount += 1
        }
        coordinator.registerOpenMainWindow {
            reopenCount += 1
        }

        coordinator.reveal()
        coordinator.reveal()

        #expect(activationCount == 2)
        #expect(reopenCount == 1)

        let window = RecordingWindow()
        coordinator.captureMainWindow(window)
        coordinator.reveal()

        #expect(window.frontCount == 1)
        #expect(reopenCount == 1)
    }
}

@MainActor
private final class RecordingWindow: NSWindow {
    private(set) var frontCount = 0

    override func makeKeyAndOrderFront(_ sender: Any?) {
        frontCount += 1
    }
}
