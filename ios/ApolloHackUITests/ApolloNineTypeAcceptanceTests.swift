import XCTest

/// Prepared for Integration's single bounded acceptance operation. Never uses normal owner keys.
/// Execution, resource lease, attempt accounting and final result export belong to Integration.
final class ApolloNineTypeAcceptanceTests: XCTestCase {
    private struct Example {
        let kind: String
        let menuTitle: String
        let expectedName: String
        let amount: String
        let expectedCost: String
    }
    // Canonical Paper snapshot SHA256 5c9b82296626ef4b8d696b4a120089f60b7889353ffd344fc339e2fb237adfe5
    private let examples: [Example] = [
        .init(kind: "stock", menuTitle: "Stocks", expectedName: "Apple", amount: "1", expectedCost: "$250.00"),
        .init(kind: "etf", menuTitle: "ETFs", expectedName: "SPDR S&P 500 ETF Trust", amount: "0.1", expectedCost: "$60.00"),
        .init(kind: "commodity", menuTitle: "Commodities", expectedName: "SPDR Gold Shares — gold trust exposure", amount: "0.1", expectedCost: "$30.00"),
        .init(kind: "crypto", menuTitle: "Crypto", expectedName: "Bitcoin — simulated USD spot exposure", amount: "0.001", expectedCost: "$100.00"),
        .init(kind: "real_estate", menuTitle: "Real estate", expectedName: "Vanguard Real Estate ETF — fund exposure", amount: "1", expectedCost: "$90.00"),
        .init(kind: "option", menuTitle: "Options", expectedName: "DEMO long Apple call option", amount: "1", expectedCost: "$500.00"),
        .init(kind: "stablecoin", menuTitle: "Stablecoins", expectedName: "USD Coin — DEMO stablecoin exposure", amount: "2.5", expectedCost: "$2.50"),
        .init(kind: "bond", menuTitle: "Bonds", expectedName: "Fictional USD direct bond — DEMO", amount: "1", expectedCost: "$980.00"),
        .init(kind: "strategy", menuTitle: "People & strategies", expectedName: "Maya · patient builder", amount: "250", expectedCost: "$250.00")
    ]

    private let expectedFinalCash = "$7,737.50"

    func testNineTypesResearchPreviewConfirmAndReopen() {
        continueAfterFailure = false
        let app = XCUIApplication()
        let namespace = "nine-acceptance-" + UUID().uuidString
        app.launchArguments = ["--apollo-test-storage=" + namespace]
        app.launch()
        completeIsolatedOnboarding(app)
        let card = app.descendants(matching: .any).matching(identifier: "asset-card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15), app.debugDescription)
        app.tabBars.buttons["Portfolio"].tap()
        let initialCash = app.staticTexts["portfolio-cash"]
        XCTAssertTrue(initialCash.waitForExistence(timeout: 5)); XCTAssertEqual(initialCash.label, "$10,000.00")
        app.tabBars.buttons["Discover"].tap()
        var currentMenu = "All selected types"
        for item in examples {
            XCTContext.runActivity(named: "Nine-type acceptance: " + item.kind) { _ in
                app.tabBars.buttons["Discover"].tap()
                let menu = app.buttons.matching(NSPredicate(format: "label == %@", currentMenu)).firstMatch
                reveal(menu, in: app, upward: false)
                XCTAssertTrue(menu.isHittable, "Missing native category menu " + currentMenu)
                menu.tap()
                let choice = app.buttons.matching(NSPredicate(format: "label == %@", item.menuTitle)).firstMatch
                XCTAssertTrue(choice.waitForExistence(timeout: 4), "Menu lacks " + item.kind)
                choice.tap(); currentMenu = item.menuTitle
                XCTAssertTrue(card.waitForExistence(timeout: 5), "No card for " + item.kind)
                card.tap()
                let title = app.staticTexts["asset-detail-title"]
                XCTAssertTrue(title.waitForExistence(timeout: 5), app.debugDescription)
                XCTAssertEqual(title.label, item.expectedName, "Wrong instrument identity for " + item.kind)
                let evidence = app.buttons["Evidence"]
                reveal(evidence, in: app); XCTAssertTrue(evidence.isHittable); evidence.tap()
                for channel in ["Leadership", "Promises vs results", "Public sentiment"] {
                    let heading = app.staticTexts.matching(NSPredicate(format: "label == %@", channel)).firstMatch
                    reveal(heading, in: app); XCTAssertTrue(heading.exists, item.kind + " missing canonical track " + channel)
                }
                capture(item.kind + " 01 exact identity and three evidence tracks", app)
                app.buttons["detail-done"].tap()
                let invest = app.buttons["invest-button"]
                XCTAssertTrue(invest.waitForExistence(timeout: 5)); invest.tap()
                let risk = app.descendants(matching: .any).matching(identifier: "risk-profile-adventurous").firstMatch
                if risk.waitForExistence(timeout: 1) {
                    reveal(risk, in: app); risk.tap()
                    let confirm = app.buttons["risk-profile-confirm"]; reveal(confirm, in: app); confirm.tap()
                }
                enter(item.amount, id: "order-quantity", app: app)
                enter("Review dated sources for " + item.kind, id: "thesis-reason", app: app)
                enter("Demo marks and evidence can disappoint", id: "thesis-risk", app: app)
                enter("New source evidence contradicts my thesis", id: "thesis-invalidation", app: app)
                let preview = app.buttons["order-preview"]
                reveal(preview, in: app); XCTAssertTrue(preview.isEnabled); preview.tap()
                let total = app.staticTexts.matching(NSPredicate(format: "identifier == %@ AND label == %@", "order-total", item.expectedCost)).firstMatch
                XCTAssertTrue(total.waitForExistence(timeout: 6), item.kind + " expected canonical demo cost " + item.expectedCost + "\n" + app.debugDescription)
                let impact = app.descendants(matching: .any).matching(identifier: "order-portfolio-projection").firstMatch
                reveal(impact, in: app); XCTAssertTrue(impact.exists)
                capture(item.kind + " 02 canonical cost and before-confirmation impact", app)
                let confirm = app.buttons["order-confirm"]
                reveal(confirm, in: app); XCTAssertFalse(confirm.isEnabled, "Confirmation must require acknowledgment")
                let acknowledge = app.switches["order-acknowledge"]
                reveal(acknowledge, in: app); XCTAssertTrue(acknowledge.exists); acknowledge.tap()
                reveal(confirm, in: app); waitEnabled(confirm); XCTAssertTrue(confirm.isEnabled); confirm.tap()
                XCTAssertTrue(app.staticTexts["paper-order-success"].waitForExistence(timeout: 6), app.debugDescription)
                capture(item.kind + " 03 explicit paper confirmation receipt", app)
                app.buttons["order-close"].tap()
            }
        }
        app.tabBars.buttons["Portfolio"].tap()
        let cash = app.staticTexts["portfolio-cash"]
        XCTAssertTrue(cash.waitForExistence(timeout: 5)); XCTAssertEqual(cash.label, expectedFinalCash); let before = cash.label
        capture("Nine types complete isolated portfolio before reopening", app)
        // Same exact isolated financial/onboarding/discovery namespace; no reset or normal launch here.
        app.terminate(); app.launch(); app.tabBars.buttons["Portfolio"].tap()
        XCTAssertTrue(cash.waitForExistence(timeout: 8)); XCTAssertEqual(cash.label, before)
        let count = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "holdings · 8")).firstMatch
        reveal(count, in: app); XCTAssertTrue(count.exists, "Eight direct holdings expected; strategy adds underlying holdings, not a person security")
        capture("Nine types isolated cash and holdings survive reopening", app)
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
