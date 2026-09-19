import XCTest

/// Headless App Store screenshots. The simulator has no rotate command, but a UI test can set the
/// device orientation, so this launches each demo scenario (see Sources/MurdlIOS/App/Demo.swift)
/// and attaches a full-resolution capture. Drive it with environment variables through xcodebuild:
///
///   TEST_RUNNER_MURDL_SHOTS=eight,sixteen TEST_RUNNER_MURDL_LANDSCAPE=1 xcodebuild test ...
///
/// then export the attachments from the result bundle with `xcresulttool`.
final class ScreenshotTests: XCTestCase {
    func testCaptureScenarios() throws {
        let environment = ProcessInfo.processInfo.environment
        let scenarios = (environment["MURDL_SHOTS"] ?? "eight").split(separator: ",").map(String.init)
        let landscape = environment["MURDL_LANDSCAPE"] == "1"
        XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
        sleep(1)

        for scenario in scenarios {
            let app = XCUIApplication()
            app.launchEnvironment["MURDL_DEMO"] = scenario
            app.launch()
            sleep(scenario == "scores" ? 55 : (scenario == "solve" ? 3 : 4))
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = scenario
            attachment.lifetime = .keepAlways
            add(attachment)
            app.terminate()
        }
    }
}
