import XCTest
/// Integration-only isolated native four-direction acceptance. Never run against the owner's namespace.
final class ApolloFourSwipeTests: XCTestCase {
 func testFourDirectionsTenDollarReviewEditAndPersistedActions() {
  continueAfterFailure=false
  let app=XCUIApplication();app.launchArguments=["--apollo-test-storage=four-swipe-"+UUID().uuidString];app.launch()
  let next=app.buttons["onboarding-continue"]
  if next.waitForExistence(timeout:8) { reveal(next,app);next.tap();let risk=app.descendants(matching:.any).matching(identifier:"onboarding-risk-adventurous").firstMatch;XCTAssertTrue(risk.waitForExistence(timeout:5));reveal(risk,app);risk.tap();reveal(next,app);next.tap();reveal(next,app);next.tap() }
  app.tabBars.buttons["Discover"].tap();select("Stocks",app)
  XCTAssertTrue(app.staticTexts["company-ticker"].waitForExistence(timeout:5))
  for id in ["pass-button","watch-button","invest-button","edit-pitch-button"] { XCTAssertTrue(app.buttons[id].exists) }
  capture("Four direction action icons visible",app)
  let zone=app.buttons["company-header-tap-right"];reveal(zone,app);zone.tap();XCTAssertEqual(app.staticTexts["company-panel-progress"].label,"2 / 6")
  swipe(0,110,zone,app,"DOWN edit")
  let amount=app.textFields["order-quantity"];XCTAssertTrue(amount.waitForExistence(timeout:5));XCTAssertEqual(amount.value as? String,"10")
  amount.tap();amount.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:8)+"20");XCTAssertEqual(amount.value as? String,"20")
  let reason=app.descendants(matching:.any).matching(identifier:"thesis-reason").firstMatch;reveal(reason,app);XCTAssertTrue(reason.exists);reason.tap();reason.typeText(" Edited practice note.");if app.toolbars.buttons["Done"].exists {app.toolbars.buttons["Done"].tap()}
  capture("DOWN editable cash budget and pitch note",app)
  app.buttons["order-close"].tap()
  app.tabBars.buttons["Portfolio"].tap();XCTAssertEqual(app.staticTexts["portfolio-cash"].label,"$10,000.00");XCTAssertFalse(app.staticTexts["Simulated fill"].exists)
  app.tabBars.buttons["Discover"].tap();swipe(110,0,app.buttons["company-header-tap-right"],app,"RIGHT review10")
  let total=app.staticTexts.matching(NSPredicate(format:"identifier == %@ AND label == %@","order-total","$10.00")).firstMatch;XCTAssertTrue(total.waitForExistence(timeout:8));XCTAssertTrue(total.label.contains("10.00"),total.label)
  reveal(total,app);XCTAssertFalse(app.staticTexts["paper-order-success"].exists)
  let confirm=app.buttons["order-confirm"];reveal(confirm,app);XCTAssertFalse(confirm.isEnabled)
  capture("RIGHT exact10 review explicit confirmation required",app)
  let ack=app.switches["order-acknowledge"];reveal(ack,app);ack.tap();reveal(confirm,app);confirm.tap()
  XCTAssertTrue(app.staticTexts["paper-order-success"].waitForExistence(timeout:8));let portfolio=app.buttons["order-view-portfolio"];reveal(portfolio,app);portfolio.tap();XCTAssertEqual(app.staticTexts["portfolio-cash"].label,"$9,990.00")
  app.tabBars.buttons["Discover"].tap();XCTAssertEqual(app.staticTexts["company-ticker"].label,"WINA");swipe(-110,0,app.buttons["company-header-tap-right"],app,"LEFT pass")
  let passed=app.staticTexts.matching(NSPredicate(format:"label BEGINSWITH %@","Passed WINA.")).firstMatch;XCTAssertTrue(passed.waitForExistence(timeout:5))
  select("ETFs",app);let card=app.descendants(matching:.any).matching(identifier:"asset-card").firstMatch;reveal(card,app)
  swipe(0,-110,card,app,"UP nonstock watch")
  let saved=app.staticTexts.matching(NSPredicate(format:"label BEGINSWITH %@","Saved SPY.")).firstMatch;XCTAssertTrue(saved.waitForExistence(timeout:5))
  app.tabBars.buttons["Watchlist"].tap();let row=app.scrollViews["watchlist-screen"].descendants(matching:.any).matching(NSPredicate(format:"label CONTAINS %@","SPY")).firstMatch;XCTAssertTrue(row.waitForExistence(timeout:5));capture("UP nonstock actual saved watch",app)
  app.terminate();app.launch();app.tabBars.buttons["Watchlist"].tap();XCTAssertTrue(row.waitForExistence(timeout:8));app.tabBars.buttons["Portfolio"].tap();XCTAssertEqual(app.staticTexts["portfolio-cash"].label,"$9,990.00");capture("Persisted watch and exact10 portfolio after reopening",app)
 }
 private func select(_ title:String,_ app:XCUIApplication){let menu=app.buttons["asset-type-menu"];reveal(menu,app);menu.tap();app.buttons.matching(NSPredicate(format:"label == %@",title)).firstMatch.tap()}
 private func swipe(_ dx:CGFloat,_ dy:CGFloat,_ target:XCUIElement,_ app:XCUIApplication,_ name:String){reveal(target,app);let start=target.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.35));let note=XCTAttachment(string:name+" "+String(describing:start.screenPoint));note.lifetime = .keepAlways;add(note);start.press(forDuration:0.05,thenDragTo:start.withOffset(CGVector(dx:dx,dy:dy)),withVelocity:.slow,thenHoldForDuration:0.6)}
 private func reveal(_ element:XCUIElement,_ app:XCUIApplication){for _ in 0..<12 {if element.exists && element.isHittable{return};let above=element.exists && element.frame.midY<130;app.coordinate(withNormalizedOffset:CGVector(dx:0.98,dy:above ? 0.25:0.75)).press(forDuration:0.02,thenDragTo:app.coordinate(withNormalizedOffset:CGVector(dx:0.98,dy:above ? 0.65:0.3)))}}
 private func capture(_ name:String,_ app:XCUIApplication){let a=XCTAttachment(screenshot:app.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
}
