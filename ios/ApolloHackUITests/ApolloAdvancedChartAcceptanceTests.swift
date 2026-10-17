import XCTest

/// Workspace-only driver. Integration owns import, exclusive runtime, recording and outcome.
/// One focused changed-feature operation. No orders/watchlist/reset/owner namespace use.
final class ApolloAdvancedChartAcceptanceTests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false; executionTimeAllowance = 420 }
    func testAdvancedChartsAndCategoryViews() {
        app = XCUIApplication()
        app.launchArguments = ["--apollo-test-storage=advanced-v4-" + UUID().uuidString]
        app.launch()
        let next = app.buttons["onboarding-continue"]
        if next.waitForExistence(timeout: 6) {
            tap(next)
            let risk = element("onboarding-risk-adventurous")
            XCTAssertTrue(risk.waitForExistence(timeout: 5)); tap(risk)
            tap(next); tap(next)
        }
        XCTAssertTrue(element("asset-card").waitForExistence(timeout: 15), app.debugDescription)
        // Learn opens exact asset identity without making a discovery decision or trade.
        app.tabBars.buttons["Learn"].tap()
        open("AAPL", title: "Apple")
        let interval = app.segmentedControls["chart-interval"]
        reveal(interval); XCTAssertTrue(interval.exists, app.debugDescription)
        capture("V4 01 AAPL daily real history and advanced controls")
        let dailyReadout = textContaining("observed").label
        let weekly = interval.buttons["1W"]
        XCTAssertTrue(weekly.exists); weekly.tap()
        XCTAssertTrue(weekly.isSelected, app.debugDescription)
        capture("V4 02 AAPL weekly observed aggregation")
        XCTAssertNotEqual(textContaining("observed").label, dailyReadout, "Weekly must change observed aggregation/readout")
        interval.buttons["1D"].tap(); XCTAssertTrue(interval.buttons["1D"].isSelected)
        let mode = app.buttons["chart-interaction-mode"]
        reveal(mode); XCTAssertTrue((mode.value as? String ?? "").contains("Inspect"))
        mode.tap(); XCTAssertTrue((mode.value as? String ?? "").contains("Pan"))
        let zoomIn = app.buttons["chart-zoom-in"], zoomOut = app.buttons["chart-zoom-out"]
        XCTAssertFalse(zoomOut.isEnabled)
        capture("V4 02b before actual zoom in tap")
        tap(zoomIn)
        let zoomChanged = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: zoomOut)
        XCTAssertEqual(XCTWaiter.wait(for: [zoomChanged], timeout: 5), .completed, app.debugDescription)
        XCTAssertTrue(zoomOut.isEnabled, app.debugDescription)
        capture("V4 02c zoom in enabled reciprocal zoom out")
        let plot = element("chart-price-plot")
        reveal(plot); XCTAssertTrue(plot.exists)
        plot.coordinate(withNormalizedOffset: .init(dx: 0.25, dy: 0.45)).press(forDuration: 0.1, thenDragTo: plot.coordinate(withNormalizedOffset: .init(dx: 0.70, dy: 0.45)))
        capture("V4 03 AAPL zoom and pan inspect actual recording for viewport motion")
        tap(mode); XCTAssertTrue((mode.value as? String ?? "").contains("Inspect"))
        reveal(plot)
        plot.coordinate(withNormalizedOffset: .init(dx: 0.30, dy: 0.45)).press(forDuration: 0.6, thenDragTo: plot.coordinate(withNormalizedOffset: .init(dx: 0.72, dy: 0.45)))
        capture("V4 04 AAPL inspect gesture recording required for transient selection")
        let rsi = app.buttons["chart-indicator-RSI 14"]
        tap(rsi); XCTAssertEqual(rsi.value as? String, "On")
        reveal(element("chart-rsi-plot")); XCTAssertTrue(element("chart-rsi-plot").exists)
        capture("V4 05 RSI fourteen native pane")
        tap(app.buttons["chart-expand"])
        XCTAssertTrue(app.navigationBars["AAPL chart"].waitForExistence(timeout: 4), app.debugDescription)
        capture("V4 06 expanded AAPL chart")
        app.navigationBars["AAPL chart"].buttons["Done"].tap()
        let events = element("chart-events")
        tapDisclosure(events, label: "Earnings and source events")
        let earnings = app.switches["chart-events-earnings"]
        reveal(earnings); XCTAssertTrue(earnings.exists)
        let value = earnings.value as? String; earnings.tap(); XCTAssertNotEqual(earnings.value as? String, value); earnings.tap()
        let event = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "chart-event-")).firstMatch
        tap(event)
        XCTAssertTrue(app.links["Open original source"].exists || app.buttons["Open original source"].exists, app.debugDescription)
        capture("V4 07 actual AAPL event source detail no causal inference")
        tapDisclosure(events, label: "Earnings and source events")
        let table = element("chart-exact-table")
        tapDisclosure(table, label: "Exact OHLCV · latest 20 observed bars")
        XCTAssertTrue(textContaining("Saved daily observations; not live.").exists)
        capture("V4 08 exact saved daily OHLCV")
        closeDetail()
        open("WINA", title: nil)
        let metric = app.buttons["financial-metric"]
        reveal(metric); XCTAssertTrue(metric.exists, app.debugDescription)
        XCTAssertTrue(element("financial-comparison-plot").exists)
        capture("V4 09 WINA sourced revenue bars")
        metric.tap(); XCTAssertTrue(app.buttons["Royalties"].waitForExistence(timeout: 3)); app.buttons["Royalties"].tap()
        XCTAssertTrue(textContaining("Royalties · USD").exists, app.debugDescription)
        capture("V4 10 WINA royalties metric and source qualifications")
        closeDetail()
        open("USDC-USD_DEMO", title: nil)
        let deviation = element("stablecoin-deviation-plot")
        reveal(deviation); XCTAssertTrue(deviation.exists, app.debugDescription)
        capture("V4 11 USDC reference deviation distinct from demo token")
        let slider = app.sliders["stablecoin-scenario"]
        reveal(slider); XCTAssertTrue(slider.isHittable)
        capture("V4 12 peg sensitivity before")
        slider.adjust(toNormalizedSliderPosition: 0)
        XCTAssertTrue(textContaining("$50.00").exists, app.debugDescription)
        capture("V4 13 peg sensitivity after illustrative fifty dollars")
        closeDetail()
        open("DEMO_USD_BOND_20281115", title: nil)
        reveal(element("bond-cashflow-plot")); XCTAssertTrue(element("bond-cashflow-plot").exists, app.debugDescription)
        capture("V4 14 fictional bond coupon principal schedule")
        reveal(element("bond-sensitivity-plot")); XCTAssertTrue(element("bond-sensitivity-plot").exists)
        capture("V4 15 bond hypothetical rate sensitivity")
        closeDetail()
        open("DEMO_PATIENT_BUILDER", title: nil)
        reveal(element("category-allocation-plot")); XCTAssertTrue(element("category-allocation-plot").exists, app.debugDescription)
        capture("V4 16 fictional strategy allocation no track record")
        closeDetail()
        app.tabBars.buttons["Portfolio"].tap()
        XCTAssertTrue(app.staticTexts["portfolio-cash"].waitForExistence(timeout: 4))
        XCTAssertEqual(app.staticTexts["portfolio-cash"].label, "$10,000.00", "Isolated paper cash unchanged; no orders performed")
        capture("V4 17 isolated paper cash unchanged")
    }
    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func textContaining(_ value: String) -> XCUIElement { app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", value)).firstMatch }
    private func tap(_ target: XCUIElement) {
        reveal(target); XCTAssertTrue(target.exists && target.isHittable && target.isEnabled, app.debugDescription); target.tap()
    }
    private func open(_ id: String, title: String?) {
        tap(app.buttons["learn-asset-" + id])
        XCTAssertTrue(app.staticTexts["asset-detail-title"].waitForExistence(timeout: 5), app.debugDescription)
        if let title { XCTAssertEqual(app.staticTexts["asset-detail-title"].label, title) }
    }
    private func closeDetail() { app.buttons["detail-done"].tap(); XCTAssertTrue(element("learn-screen").waitForExistence(timeout: 4)) }
    private func tapDisclosure(_ target: XCUIElement, label: String) {
        let button = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
        if button.exists { tap(button) }
        else { tap(target) }
    }
    private func reveal(_ target: XCUIElement) {
        for _ in 0..<14 {
            let exists = target.exists
            let frame = exists ? target.frame : .zero
            if exists && target.isHittable && frame.midY > 110 && frame.midY < app.frame.height - 95 { return }
            let moveDown = target.exists && frame.midY < 130
            // Edge-only scroll avoids chart/card gestures and order controls.
            let a = app.coordinate(withNormalizedOffset: .init(dx: 0.98, dy: moveDown ? 0.28 : 0.78))
            let b = app.coordinate(withNormalizedOffset: .init(dx: 0.98, dy: moveDown ? 0.76 : 0.32))
            a.press(forDuration: 0.02, thenDragTo: b)
        }
    }
    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
        let tree = XCTAttachment(string: app.debugDescription); tree.name = name + " accessibility"; tree.lifetime = .keepAlways; add(tree)
    }
}
