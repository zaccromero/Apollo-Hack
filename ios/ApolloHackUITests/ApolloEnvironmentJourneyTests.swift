import XCTest

final class ApolloEnvironmentJourneyTests: XCTestCase {
    private let key = "environment-native-20261017-v1"
    func test01SeedIsolatedDevelopment() {
        let app = launch(dev: true)
        complete(app, profile: "conservative")
        app.buttons["watch-button"].tap()
        app.tabBars.buttons["Watchlist"].tap()
        XCTAssertTrue(app.staticTexts["AAPL"].waitForExistence(timeout: 5))
        profile(app, expected: "Conservative")
        capture("DEV synthetic Conservative and AAPL watch saved", app)
    }
    func test02StagingIsSeparateAndPersists() {
        let app = launch(dev: false)
        XCTAssertTrue(app.staticTexts["TestFlight practice · separate saved portfolio"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["onboarding-continue"].exists, "Fresh stage must not inherit DEV quiz")
        complete(app, profile: "adventurous")
        app.tabBars.buttons["Watchlist"].tap()
        XCTAssertFalse(app.staticTexts["AAPL"].exists, "STAGE must not inherit DEV watchlist")
        profile(app, expected: "Adventurous")
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["Discover"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["onboarding-continue"].exists)
        profile(app, expected: "Adventurous")
        capture("STAGE separate account persists after reopen", app)
    }
    func test03DevelopmentSurvivesStaging() {
        let app = launch(dev: true)
        XCTAssertTrue(app.tabBars.buttons["Discover"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["onboarding-continue"].exists)
        app.tabBars.buttons["Watchlist"].tap()
        XCTAssertTrue(app.staticTexts["AAPL"].waitForExistence(timeout: 5))
        profile(app, expected: "Conservative")
        app.tabBars.buttons["Portfolio"].tap()
        XCTAssertTrue(app.staticTexts["portfolio-cash"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["portfolio-cash"].label, "$10,000.00")
        capture("DEV restored quiz profile watch and cash unchanged", app)
    }
    private func launch(dev: Bool) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = dev ? ["--apollo-test-storage=" + key] : []; app.launch(); return app
    }
    private func complete(_ app: XCUIApplication, profile: String) {
        let next = app.buttons["onboarding-continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 8)); reveal(next, app); next.tap()
        let choice = app.descendants(matching: .any).matching(identifier: "onboarding-risk-" + profile).firstMatch
        XCTAssertTrue(choice.waitForExistence(timeout: 5)); reveal(choice, app); choice.tap()
        reveal(next, app); next.tap(); reveal(next, app); next.tap()
        XCTAssertTrue(app.buttons["watch-button"].waitForExistence(timeout: 8))
    }
    private func profile(_ app: XCUIApplication, expected: String) {
        app.tabBars.buttons["Discover"].tap(); app.buttons["game-settings"].tap()
        let saved = app.descendants(matching: .any).matching(identifier: "settings-saved-profile").firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5)); XCTAssertTrue(saved.label.contains(expected), saved.label)
        app.tabBars.buttons["Portfolio"].tap()
    }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<8 { if element.exists && element.isHittable { return }; app.swipeUp() }
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
}
