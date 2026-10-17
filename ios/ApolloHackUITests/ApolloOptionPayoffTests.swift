import XCTest
final class ApolloOptionPayoffTests:XCTestCase {
    func testFinalAffectedOptionPayoffAndSliderOnly() {
        continueAfterFailure=false
        let app=XCUIApplication();app.launchArguments=["--apollo-test-storage=option-only-"+UUID().uuidString,"--apollo-owner-comparison"];app.launch()
        XCTAssertTrue(app.buttons["compare-close"].waitForExistence(timeout:15));app.buttons["compare-close"].tap();app.tabBars.buttons["Discover"].tap()
        let menu=app.buttons["All selected types"];XCTAssertTrue(menu.waitForExistence(timeout:5),app.debugDescription);menu.tap()
        let option=app.buttons["Options"];XCTAssertTrue(option.waitForExistence(timeout:5),app.debugDescription);option.tap()
        let card=app.descendants(matching:.any).matching(identifier:"asset-card").firstMatch;XCTAssertTrue(card.waitForExistence(timeout:5));XCTAssertTrue(card.label.contains("Options"),card.label);card.tap()
        XCTAssertTrue(app.staticTexts["asset-detail-title"].waitForExistence(timeout:5))
        let loss=app.staticTexts.matching(NSPredicate(format:"label BEGINSWITH %@","Maximum premium loss")).firstMatch;reveal(loss,app);XCTAssertTrue(loss.exists,app.debugDescription);capture("Fictional option terms max premium loss and break even",app)
        let slider=app.sliders["Assumed underlying price at expiry"];reveal(slider,app);XCTAssertTrue(slider.isHittable,app.debugDescription)
        let pnl=app.staticTexts.matching(NSPredicate(format:"label BEGINSWITH %@","Scenario P/L:")).firstMatch;XCTAssertTrue(pnl.exists);let before=pnl.label;capture("Option initial underlying assumption and P L",app)
        slider.adjust(toNormalizedSliderPosition:1);XCTAssertNotEqual(pnl.label,before);let upper=pnl.label;XCTAssertFalse(upper.contains("-$"));capture("Option higher assumed underlying changes profit",app)
        slider.adjust(toNormalizedSliderPosition:0);XCTAssertNotEqual(pnl.label,upper);XCTAssertTrue(pnl.label.contains("-$"),pnl.label);capture("Option zero assumed underlying max premium loss",app)
        let notice=app.staticTexts.matching(NSPredicate(format:"label BEGINSWITH %@","Expiry sensitivity")).firstMatch;reveal(notice,app);XCTAssertTrue(notice.exists);capture("Option expiry sensitivity no forecast no order",app)
    }
    private func reveal(_ e:XCUIElement,_ app:XCUIApplication){for _ in 0..<22 {if e.exists && e.isHittable{return};let down=e.exists && e.frame.midY<130;app.coordinate(withNormalizedOffset:CGVector(dx:0.95,dy:down ? 0.28 : 0.75)).press(forDuration:0.02,thenDragTo:app.coordinate(withNormalizedOffset:CGVector(dx:0.95,dy:down ? 0.65 : 0.35)))}}
    private func capture(_ name:String,_ app:XCUIApplication){let a=XCTAttachment(screenshot:app.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
}
