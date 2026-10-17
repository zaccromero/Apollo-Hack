import XCTest

final class ApolloHackUITests: XCTestCase {
    func testCapturedProviderJourneyAndEvidence() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["All four connected"].waitForExistence(timeout: 10))
        let overview = XCTAttachment(screenshot: app.screenshot())
        overview.name = "Apollo overview"
        overview.lifetime = .keepAlways
        add(overview)
        for name in ["Anchor", "Daytona", "SurrealDB", "Arize AX"] {
            let provider = app.staticTexts[name]
            for _ in 0..<5 where !provider.isHittable { app.swipeUp() }
            XCTAssertTrue(provider.exists, "Missing provider \(name)")
        }
        let evidence = app.buttons["view-evidence"]
        for _ in 0..<5 where !evidence.isHittable { app.swipeUp() }
        XCTAssertTrue(evidence.waitForExistence(timeout: 3))
        evidence.tap()
        XCTAssertTrue(app.navigationBars["Run evidence"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.scrollViews["evidence-content"].exists)
        let details = XCTAttachment(screenshot: app.screenshot())
        details.name = "Apollo evidence"
        details.lifetime = .keepAlways
        add(details)
    }
}
