import XCTest
final class ApolloCarryoverJourneyTests: XCTestCase {
    func test01SeedDevelopmentPortfolio() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = []; app.launch()
        completeIsolatedOnboarding(app)
        app.buttons["invest-button"].tap()
        enter("1", id: "order-quantity", app: app)
        enter("Carryover synthetic practice receipt", id: "thesis-reason", app: app)
        enter("Demo loss is possible", id: "thesis-risk", app: app)
        enter("Changed evidence", id: "thesis-invalidation", app: app)
        let preview = app.buttons["order-preview"]; reveal(preview,in:app); preview.tap()
        let total = app.staticTexts.matching(NSPredicate(format:"identifier == %@ AND label == %@","order-total","$250.00")).firstMatch
        XCTAssertTrue(total.waitForExistence(timeout:5))
        let ack=app.switches["order-acknowledge"];reveal(ack,in:app);ack.tap()
        let confirm=app.buttons["order-confirm"];reveal(confirm,in:app);waitEnabled(confirm);confirm.tap()
        XCTAssertTrue(app.staticTexts["paper-order-success"].waitForExistence(timeout:5));app.buttons["order-close"].tap()
        app.tabBars.buttons["Discover"].tap();app.buttons["watch-button"].tap()
        verify(app, label:"DEV populated synthetic account before carryover")
    }
    func test02ReleaseCarriesPortfolioAndReopens() {
        continueAfterFailure=false
        let app=XCUIApplication();app.launchArguments=[];app.launch()
        XCTAssertTrue(app.tabBars.buttons["Portfolio"].waitForExistence(timeout:10),app.debugDescription)
        XCTAssertFalse(app.buttons["onboarding-continue"].exists,"Completed quiz must carry over")
        verify(app,label:"Release existing portfolio carried forward")
        app.terminate();app.launch()
        verify(app,label:"Release reopen no duplicate fill and same saved portfolio")
    }
    func test03OriginalDevelopmentRemainsIntact() {
        continueAfterFailure=false
        let app=XCUIApplication();app.launchArguments=[];app.launch()
        XCTAssertTrue(app.tabBars.buttons["Portfolio"].waitForExistence(timeout:8));XCTAssertFalse(app.buttons["onboarding-continue"].exists)
        verify(app,label:"Original DEV remains intact after release carryover")
    }
    private func verify(_ app:XCUIApplication,label:String) {
        app.tabBars.buttons["Portfolio"].tap()
        let cash=app.staticTexts["portfolio-cash"];XCTAssertTrue(cash.waitForExistence(timeout:8));XCTAssertEqual(cash.label,"$9,750.00")
        let cost=app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","Cost $250.00")).firstMatch;reveal(cost,in:app);XCTAssertTrue(cost.exists,app.debugDescription)
        let thesis=app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","Carryover synthetic practice receipt")).firstMatch;reveal(thesis,in:app);XCTAssertTrue(thesis.exists)
        let fill=app.staticTexts.matching(NSPredicate(format:"label == %@","Simulated fill"));reveal(fill.firstMatch,in:app);XCTAssertEqual(fill.count,1)
        capture(label,app)
        app.tabBars.buttons["Watchlist"].tap();XCTAssertTrue(app.staticTexts["WINA"].waitForExistence(timeout:5))
        app.tabBars.buttons["Discover"].tap();app.buttons["game-settings"].tap()
        let profile=app.descendants(matching:.any).matching(identifier:"settings-saved-profile").firstMatch;XCTAssertTrue(profile.waitForExistence(timeout:5));XCTAssertTrue(profile.label.contains("Adventurous"),profile.label)
        app.tabBars.buttons["Portfolio"].tap()
    }
    private func completeIsolatedOnboarding(_ app: XCUIApplication) {
        let next = app.buttons["onboarding-continue"]
        guard next.waitForExistence(timeout: 8) else { return }
        reveal(next, in: app); waitEnabled(next); next.tap()
        let adventurous = app.descendants(matching: .any).matching(identifier: "onboarding-risk-adventurous").firstMatch
        XCTAssertTrue(adventurous.waitForExistence(timeout: 5)); reveal(adventurous, in: app); adventurous.tap()
        reveal(next, in: app); waitEnabled(next); next.tap()
        reveal(next, in: app); waitEnabled(next); next.tap()
    }
    private func enter(_ text: String, id: String, app: XCUIApplication) {
        // Actual vertical-axis fields may be TextFields or TextViews; don't assume Button/TextField type.
        let field = app.descendants(matching: .any).matching(identifier: id).firstMatch
        reveal(field, in: app); XCTAssertTrue(field.exists, "Missing editable " + id)
        field.tap(); field.typeText(text)
        if app.toolbars.buttons["Done"].exists { app.toolbars.buttons["Done"].tap() }
    }
    private func waitEnabled(_ element: XCUIElement) {
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 8), .completed)
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, upward: Bool = true) {
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            let above = element.exists && element.frame.maxY > 0 && element.frame.maxY < 120
            let scrollUp = above ? false : upward
            // Use the observed safe right edge, outside the swipe-card gesture area.
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: scrollUp ? 0.78 : 0.25))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: scrollUp ? 0.25 : 0.78))
            start.press(forDuration: 0.02, thenDragTo: end)
        }
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
        let tree = XCTAttachment(string: app.debugDescription); tree.name = name + " accessibility"; tree.lifetime = .keepAlways; add(tree)
    }
}
