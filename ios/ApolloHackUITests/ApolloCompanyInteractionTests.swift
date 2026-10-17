import XCTest
/// Prepared only. Integration owns execution, isolated namespace, rig, round accounting and export.
final class ApolloCompanyInteractionTests: XCTestCase {
    func testSixSectionsTapZonesAndIntentionalStockSwipes() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["--apollo-test-storage=company-" + UUID().uuidString]; app.launch()
        let next = app.buttons["onboarding-continue"]
        if next.waitForExistence(timeout: 8) {
            reveal(next, app); next.tap()
            let risk = app.descendants(matching: .any).matching(identifier: "onboarding-risk-adventurous").firstMatch
            XCTAssertTrue(risk.waitForExistence(timeout: 5)); reveal(risk, app); risk.tap()
            reveal(next, app); next.tap(); reveal(next, app); next.tap()
        }
        app.tabBars.buttons["Portfolio"].tap()
        let cash = app.staticTexts["portfolio-cash"]; XCTAssertTrue(cash.waitForExistence(timeout: 8)); let before = cash.label
        XCTAssertEqual(before, "$10,000.00")
        app.tabBars.buttons["Discover"].tap()
        let menu = app.buttons["asset-type-menu"]; reveal(menu, app); menu.tap()
        app.buttons.matching(NSPredicate(format: "label == %@", "Stocks")).firstMatch.tap()
        verifyCompany("AAPL", app)
        let card = app.descendants(matching: .any).matching(identifier: "asset-card").firstMatch
        // Deliberate right swipe opens a review, never a fill.
        reveal(card, app)
        let start = app.buttons["company-header-tap-right"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 90, dy: 0)))
        let close = app.buttons["order-close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.staticTexts["paper-order-success"].exists)
        XCTAssertFalse(app.buttons["order-confirm"].exists)
        close.tap()
        XCTAssertEqual(app.staticTexts["company-ticker"].label, "AAPL")
        swipeCard(.left, app)
        let ticker = app.staticTexts["company-ticker"]
        XCTAssertTrue(NSPredicate(format: "label == %@", "WINA").evaluate(with: ticker) || waitLabel(ticker, "WINA"))
        verifyCompany("WINA", app)
        swipeCard(.up, app)
        // Require the actual gesture to remove the last stock BEFORE any helper scrolling.
        let removed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.staticTexts["company-ticker"])
        XCTAssertEqual(XCTWaiter.wait(for: [removed], timeout: 5), .completed, "Intentional UP must watch the stock, not scroll the page")
        let receipt = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Saved WINA.")).firstMatch
        reveal(receipt, app); XCTAssertTrue(receipt.waitForExistence(timeout: 5), "Successful persisted watch receipt required")
        capture("Intentional UP saved WINA before opening watchlist", app)
        app.tabBars.buttons["Watchlist"].tap()
        let list = app.scrollViews["watchlist-screen"]; XCTAssertTrue(list.waitForExistence(timeout: 5))
        let savedWina = list.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", "WINA")).firstMatch
        XCTAssertTrue(savedWina.waitForExistence(timeout: 5), "Actual saved WINA row must exist in the active watchlist")
        capture("Intentional UP creates actual WINA watchlist entry", app)
        app.tabBars.buttons["Portfolio"].tap()
        XCTAssertEqual(cash.label, before)
        XCTAssertFalse(app.staticTexts["Simulated fill"].exists)
        capture("Only intentional Pass Watch Review; no paper fill", app)
    }
    // New HUMAN-APPROVED watch-only recovery; never reruns the 12 passing panels.
    func testWatchOnlyRecoveryPersistsAndKeepsCash() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["--apollo-test-storage=watch-only-" + UUID().uuidString]; app.launch()
        let next = app.buttons["onboarding-continue"]
        if next.waitForExistence(timeout: 8) {
            reveal(next, app); next.tap()
            let risk = app.descendants(matching: .any).matching(identifier: "onboarding-risk-adventurous").firstMatch
            XCTAssertTrue(risk.waitForExistence(timeout: 5)); reveal(risk, app); risk.tap()
            reveal(next, app); next.tap(); reveal(next, app); next.tap()
        }
        app.tabBars.buttons["Portfolio"].tap()
        let cash = app.staticTexts["portfolio-cash"]; XCTAssertTrue(cash.waitForExistence(timeout: 5)); let before = cash.label
        app.tabBars.buttons["Discover"].tap()
        let menu = app.buttons["asset-type-menu"]; reveal(menu, app); menu.tap(); app.buttons.matching(NSPredicate(format: "label == %@", "Stocks")).firstMatch.tap()
        let ticker = app.staticTexts["company-ticker"]; XCTAssertTrue(ticker.waitForExistence(timeout: 5)); let symbol = ticker.label
        // One negative control: a stationary tap still browses and keeps this card.
        let zone = app.buttons["company-header-tap-right"]; reveal(zone, app); zone.tap()
        XCTAssertEqual(ticker.label, symbol); XCTAssertEqual(app.staticTexts["company-panel-progress"].label, "2 / 6")
        let start = zone.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -110)))
        let receipt = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Saved " + symbol + ".")).firstMatch
        XCTAssertTrue(receipt.waitForExistence(timeout: 5), "The deliberate swipe must save before helper scrolling")
        app.tabBars.buttons["Watchlist"].tap()
        func savedRow() -> XCUIElement { app.scrollViews["watchlist-screen"].descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", symbol)).firstMatch }
        XCTAssertTrue(savedRow().waitForExistence(timeout: 5)); capture("Watch-only actual saved row before reopen", app)
        app.tabBars.buttons["Portfolio"].tap(); XCTAssertEqual(cash.label, before); XCTAssertFalse(app.staticTexts["Simulated fill"].exists)
        app.terminate(); app.launch(); app.tabBars.buttons["Watchlist"].tap()
        XCTAssertTrue(savedRow().waitForExistence(timeout: 8)); capture("Watch-only saved row persists after reopen", app)
        app.tabBars.buttons["Portfolio"].tap(); XCTAssertEqual(cash.label, before); XCTAssertFalse(app.staticTexts["Simulated fill"].exists)
        capture("Watch-only unchanged cash no fills after reopen", app)
    }
    private func verifyCompany(_ id: String, _ app: XCUIApplication) {
        let ticker = app.staticTexts["company-ticker"], progress = app.staticTexts["company-panel-progress"]
        XCTAssertTrue(ticker.waitForExistence(timeout: 5)); XCTAssertEqual(ticker.label, id)
        let names = ["overview", "news", "chart", "business", "people", "other_side"]
        for (index, name) in names.enumerated() {
            let segment = app.buttons["company-panel-" + name]; reveal(segment, app); segment.tap()
            XCTAssertEqual(ticker.label, id); XCTAssertEqual(progress.label, "\(index + 1) / 6")
            let content = app.descendants(matching: .any).matching(identifier: "company-content-" + name).firstMatch
            XCTAssertTrue(content.exists)
            capture(id + " section " + String(index + 1) + " " + name, app)
            if name == "chart" {
                let inspect = app.buttons["company-inspect-chart"]; reveal(inspect, app); inspect.tap()
                let done = app.buttons["company-chart-done"]; XCTAssertTrue(done.waitForExistence(timeout: 5))
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.4)).press(forDuration: 0.3, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.4)))
                done.tap()
            } else {
                let more = app.buttons["company-read-more"]; reveal(more, app); more.tap()
                let done = app.buttons["company-details-done"]; XCTAssertTrue(done.waitForExistence(timeout: 5))
                let expectedHash = id == "AAPL" ? "4dfb1b37d85cf937352a5fad8802e760bba3540cfb811b4ddd0d9de5c31c2e44" : "f4ac7c6b2702cf94b1176750ed262cc213a22418936d1060e01667885a1fc020"
                let binding = app.staticTexts["Reviewed company profile: " + expectedHash]
                reveal(binding, app); XCTAssertTrue(binding.exists, "Current asset/profile corpus must match; no missing/historical fallback")
                done.tap()
            }
            XCTAssertEqual(ticker.label, id); XCTAssertEqual(progress.label, "\(index + 1) / 6")
        }
        // Header zones are actual transparent Button hit targets; both ends clamp on this stock.
        let overview = app.buttons["company-panel-overview"]; reveal(overview, app); overview.tap()
        let left = app.buttons["company-header-tap-left"], right = app.buttons["company-header-tap-right"]
        reveal(left, app); left.tap(); XCTAssertEqual(progress.label, "1 / 6")
        for index in 2...6 { right.tap(); XCTAssertEqual(progress.label, "\(index) / 6"); XCTAssertEqual(ticker.label, id) }
        right.tap(); XCTAssertEqual(progress.label, "6 / 6")
        for index in stride(from: 5, through: 1, by: -1) { left.tap(); XCTAssertEqual(progress.label, "\(index) / 6"); XCTAssertEqual(ticker.label, id) }
        let bodyRight = app.buttons["company-tap-right"], bodyLeft = app.buttons["company-tap-left"]
        tapUnobscuredBody(bodyRight, app); XCTAssertEqual(progress.label, "2 / 6"); XCTAssertEqual(ticker.label, id)
        tapUnobscuredBody(bodyLeft, app); XCTAssertEqual(progress.label, "1 / 6"); XCTAssertEqual(ticker.label, id)
        capture(id + " actual header and body left right zones same stock", app)
    }
    private enum Direction { case left, up }
    private func swipeCard(_ direction: Direction, _ app: XCUIApplication) {
        let zone = app.buttons["company-header-tap-right"]; reveal(zone, app)
        let start = zone.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = direction == .left ? start.withOffset(CGVector(dx: -160, dy: 0)) : start.withOffset(CGVector(dx: 0, dy: -110))
        start.press(forDuration: 0.05, thenDragTo: end)
    }
    private func waitLabel(_ element: XCUIElement, _ text: String) -> Bool { XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", text), object: element)], timeout: 5) == .completed }
    private func tapUnobscuredBody(_ zone: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<12 {
            guard zone.exists else { XCTFail("Missing body tap zone " + zone.identifier); return }
            let frame = zone.frame
            let pass = app.buttons["pass-button"]
            let footerTop = pass.exists && pass.isHittable ? pass.frame.minY : app.frame.maxY - 40
            let top = max(frame.minY + 12, 130)
            let bottom = min(frame.maxY - 12, footerTop - 16)
            if frame.width > 0 && bottom > top + 8 {
                let point = CGPoint(x: frame.midX, y: top + min(12, (bottom - top) / 2))
                XCTAssertTrue(frame.contains(point)); XCTAssertLessThan(point.y, footerTop - 12)
                let note = XCTAttachment(string: "Body tap " + zone.identifier + " frame=" + String(describing: frame) + " point=" + String(describing: point) + " footerTop=" + String(describing: footerTop))
                note.name = "Measured unobscured body tap"; note.lifetime = .keepAlways; add(note)
                app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: point.x, dy: point.y)).tap()
                return
            }
            let above = frame.maxY < 150
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: above ? 0.25 : 0.75)).press(forDuration: 0.02, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: above ? 0.65 : 0.3)))
        }
        XCTFail("No unobscured body point above decision bar; refusing an unintended Pass/Watch/Review tap")
    }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<14 { if element.exists && element.isHittable { return }; let above = element.exists && element.frame.midY < 130
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: above ? 0.25 : 0.75)).press(forDuration: 0.02, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: above ? 0.65 : 0.3)))
        }
    }
    private func capture(_ name: String, _ app: XCUIApplication) { let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a) }
}
