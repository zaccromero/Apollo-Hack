import XCTest

/// Prepared only; Integration owns target import and exclusive device execution.
/// No orders, watchlist, real-account writes or owner namespace changes.
final class ApolloChartFocusedPhoneJourney: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func testBlueChartAndOptionControls() {
        let app = XCUIApplication()
        app.launchArguments = ["--apollo-test-storage=chart-controls-" + UUID().uuidString,"--apollo-owner-comparison"]
        app.launch()
        func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
        func capture(_ name: String) {
            let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
            let tree = XCTAttachment(string: app.debugDescription); tree.name = name + " accessibility"; tree.lifetime = .keepAlways; add(tree)
        }
        func reveal(_ target: XCUIElement, limit: Int = 12) {
            for _ in 0..<limit {
                if target.exists && target.isHittable { return }
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.78)).press(forDuration: 0.02, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.30)))
            }
        }
        func top() {
            for _ in 0..<7 {
                if app.buttons["asset-filters"].isHittable || element("asset-type-menu").isHittable || app.scrollViews["asset-filters"].isHittable { return }
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.25)).press(forDuration: 0.02, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.80)))
            }
        }
        let close=app.buttons["compare-close"];XCTAssertTrue(close.waitForExistence(timeout:15));close.tap();app.tabBars.buttons["Discover"].tap()
        let next = app.buttons["onboarding-continue"]
        if next.waitForExistence(timeout: 4) {
            next.tap()
            let risk = element("onboarding-risk-adventurous")
            XCTAssertTrue(risk.waitForExistence(timeout: 5)); reveal(risk); risk.tap()
            reveal(next); next.tap(); reveal(next); XCTAssertTrue(next.isEnabled); next.tap()
        }
        let card = element("asset-card")
        XCTAssertTrue(card.waitForExistence(timeout: 15), app.debugDescription)
        card.tap()
        XCTAssertTrue(app.staticTexts["asset-detail-title"].waitForExistence(timeout: 5))
        let all = app.buttons["All chart range"], week = app.buttons["1W chart range"], month = app.buttons["1M chart range"]
        capture("01 actual chart accessibility before controls");reveal(all); XCTAssertTrue(all.exists, "Expected actual bundled AAPL dated history, not demo-only controls")
        all.tap(); capture("02 AAPL cached history all sessions blue light")
        let sessions = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "observed sessions")).firstMatch
        let allSessions = sessions.label
        week.tap(); XCTAssertNotEqual(sessions.label, allSessions); capture("03 AAPL 1W range changed observed sessions")
        month.tap(); capture("04 AAPL 1M observed sessions")
        all.tap()
        let style = app.buttons.matching(NSPredicate(format:"label == %@ OR label == %@","Close line","Candles")).firstMatch; reveal(style); style.tap()
        let candles = app.buttons["Candles"]; XCTAssertTrue(candles.waitForExistence(timeout: 3)); candles.tap()
        capture("05 AAPL supplied candles and volume")
        style.tap(); let closeLine = app.buttons["Close line"]; XCTAssertTrue(closeLine.waitForExistence(timeout: 3)); closeLine.tap()
        for indicator in ["SMA 20", "SMA 50", "EMA 20"] {
            let control = app.buttons[indicator+" indicator"]; reveal(control); XCTAssertTrue(control.exists)
            control.tap(); XCTAssertEqual(control.value as? String, "On")
            capture("06 AAPL " + indicator + " toggled on")
            control.tap(); XCTAssertEqual(control.value as? String, "Off")
        }
        // Put the entire plot inside the screen before a gesture; do not drag an offscreen coordinate.
        let plotForFrame = app.descendants(matching:.any).matching(NSPredicate(format:"label == %@","AAPL historical price chart")).firstMatch
        for _ in 0..<8 {
            let frame = plotForFrame.frame, screen = app.frame
            if frame.minY >= screen.minY + 100 && frame.maxY < screen.maxY - 100 { break }
            let below = frame.midY > screen.midY
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: below ? 0.75 : 0.25)).press(forDuration: 0.02, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: below ? 0.40 : 0.60)))
        }
        // Preserve raw tree/video evidence for crosshair: native selection may clear after release.
        // Do not infer crosshair PASS from this gesture alone; inspect actual returned recording/state.
        let plot = app.descendants(matching:.any).matching(NSPredicate(format:"label == %@","AAPL historical price chart")).firstMatch; reveal(plot); XCTAssertTrue(plot.exists)
        capture("07 AAPL before crosshair gesture")
        plot.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.45)).press(forDuration: 0.7, thenDragTo: plot.coordinate(withNormalizedOffset: CGVector(dx: 0.70, dy: 0.45)))
        capture("08 AAPL after crosshair gesture inspect recording for selection")
        app.buttons["detail-done"].tap(); top()
        let filter = app.buttons["filter-option"], filters = app.scrollViews["asset-filters"]
        let typeMenu = app.buttons["asset-filters"]
        if typeMenu.exists {
            XCTAssertTrue(typeMenu.isHittable); typeMenu.tap()
            XCTAssertTrue(filter.waitForExistence(timeout: 3)); filter.tap()
        } else {
            // Legacy Game06 fallback only; current Game07+ uses the explicit menu above.
            for _ in 0..<10 where !filter.isHittable {
                let right = filter.frame.midX < filters.frame.midX
                filters.coordinate(withNormalizedOffset: CGVector(dx: right ? 0.3 : 0.7, dy: 0.5)).press(forDuration: 0.02, thenDragTo: filters.coordinate(withNormalizedOffset: CGVector(dx: right ? 0.7 : 0.3, dy: 0.5)))
            }
            XCTAssertTrue(filter.isHittable); filter.tap()
        }
        XCTAssertTrue(card.waitForExistence(timeout: 5)); card.tap()
        let payoff = app.staticTexts.matching(NSPredicate(format:"label BEGINSWITH %@","Expiry sensitivity")).firstMatch; reveal(payoff); XCTAssertTrue(payoff.exists)
        capture("09 fictional long call expiry terms max loss break even")
        let slider = app.sliders["Assumed underlying price at expiry"]; reveal(slider); XCTAssertTrue(slider.isHittable)
        let pnl = app.staticTexts.matching(NSPredicate(format:"label BEGINSWITH %@","Scenario P/L:")).firstMatch; XCTAssertTrue(pnl.exists)
        let before = pnl.label; capture("10 option initial assumed underlying and P L")
        slider.adjust(toNormalizedSliderPosition: 1.0)
        let after = pnl.label; XCTAssertNotEqual(before, after)
        capture("11 option upper endpoint assumed underlying and changed P L")
        slider.adjust(toNormalizedSliderPosition: 0.0); XCTAssertNotEqual(pnl.label, after)
        capture("12 option lower endpoint max premium loss")
        app.buttons["detail-done"].tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        // Integration separately performs normal-owner-storage handback under its lease.
    }
}
