import XCTest

final class ApolloHackUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func testCapturedProviderJourneyAndEvidence() {
        let app = XCUIApplication()
        app.launchArguments = ["--provider-diagnostics"]
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

    func testFirstPlayableGameAndResearch() {
        let app=XCUIApplication()
        app.launchArguments=["--apollo-test-storage=" + UUID().uuidString]
        app.launch()
        let card=app.descendants(matching:.any).matching(identifier:"asset-card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout:15))
        let overview=XCTAttachment(screenshot:app.screenshot());overview.name="Apollo game overview";overview.lifetime = .keepAlways;add(overview)
        card.tap()
        XCTAssertTrue(app.staticTexts["asset-detail-title"].waitForExistence(timeout:5))
        let detail=XCTAttachment(screenshot:app.screenshot());detail.name="Apollo game research";detail.lifetime = .keepAlways;add(detail)
        app.buttons["detail-done"].tap()
        XCTAssertTrue(app.buttons["asset-card"].waitForExistence(timeout:5))
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, limit: Int = 8) {
        for _ in 0..<limit {
            if element.exists && element.isHittable { return }
            app.coordinate(withNormalizedOffset: CGVector(dx:0.98,dy:0.78)).press(forDuration:0.02,thenDragTo:app.coordinate(withNormalizedOffset:CGVector(dx:0.98,dy:0.25)))
        }
    }
    private func enter(_ text: String, fieldID: String, app: XCUIApplication) {
        let field=app.descendants(matching:.any).matching(identifier:fieldID).firstMatch
        reveal(field,in:app)
        XCTAssertTrue(field.exists,"Missing field \(fieldID)")
        field.tap(); field.typeText(text)
        if app.toolbars.buttons["Done"].exists { app.toolbars.buttons["Done"].tap() }
    }
    func testConnectedGamePaperOrderAndPersistence() {
        let app=XCUIApplication()
        app.launchArguments=["--apollo-backend-url=http://127.0.0.1:8769"]
        app.launch()
        let card=app.descendants(matching:.any).matching(identifier:"asset-card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout:20),app.debugDescription)
        let invest=app.buttons["invest-button"];reveal(invest,in:app);invest.tap()
        if app.buttons["risk-profile-adventurous"].waitForExistence(timeout:2) {
            app.buttons["risk-profile-adventurous"].tap()
            let save=app.buttons["risk-profile-confirm"];reveal(save,in:app);save.tap()
        }
        XCTAssertTrue(app.textFields["order-quantity"].waitForExistence(timeout:5),app.debugDescription)
        // Quantity is an explicit input; placeholder text is not a value.
        enter("1",fieldID:"order-quantity",app:app)
        enter("Practice from dated sources",fieldID:"thesis-reason",app:app)
        enter("The business can disappoint",fieldID:"thesis-risk",app:app)
        enter("New evidence contradicts the thesis",fieldID:"thesis-invalidation",app:app)
        let preview=app.buttons["order-preview"];reveal(preview,in:app);XCTAssertTrue(preview.isEnabled);preview.tap()
        let total=app.descendants(matching:.any).matching(identifier:"order-total").firstMatch
        XCTAssertTrue(total.waitForExistence(timeout:8),app.debugDescription)
        let confirm=app.buttons["order-confirm"];reveal(confirm,in:app)
        XCTAssertFalse(confirm.isEnabled)
        let acknowledge=app.switches["order-acknowledge"];reveal(acknowledge,in:app);acknowledge.tap()
        reveal(confirm,in:app);XCTAssertTrue(confirm.isEnabled);confirm.tap()
        XCTAssertTrue(app.staticTexts["paper-order-success"].waitForExistence(timeout:8),app.debugDescription)
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Connected paper order filled";shot.lifetime = .keepAlways;add(shot)
        app.buttons["order-close"].tap()
        app.tabBars.buttons["Portfolio"].tap()
        XCTAssertTrue(app.staticTexts["portfolio-cash"].waitForExistence(timeout:5))
        let before=app.staticTexts["portfolio-cash"].label
        app.terminate();app.launch();app.tabBars.buttons["Portfolio"].tap()
        XCTAssertTrue(app.staticTexts["portfolio-cash"].waitForExistence(timeout:8))
        XCTAssertEqual(app.staticTexts["portfolio-cash"].label,before)
    }
    func testPhoneRiskPreviewAndConfirmedPersistence() {
        let app = XCUIApplication()
        app.launchArguments = ["--apollo-test-storage=" + UUID().uuidString]
        app.launch()
        let card = app.descendants(matching:.any).matching(identifier:"asset-card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout:15))
        let start = card.coordinate(withNormalizedOffset:CGVector(dx:0.25,dy:0.3))
        let end = card.coordinate(withNormalizedOffset:CGVector(dx:0.85,dy:0.3))
        start.press(forDuration:0.05,thenDragTo:end)
        let profile = app.buttons["risk-profile-adventurous"]
        XCTAssertTrue(profile.waitForExistence(timeout:5),app.debugDescription)
        reveal(profile,in:app);profile.tap()
        let save = app.buttons["risk-profile-confirm"];reveal(save,in:app);save.tap()
        XCTAssertTrue(app.textFields["order-quantity"].waitForExistence(timeout:5))
        enter("1",fieldID:"order-quantity",app:app)
        enter("Practice using source evidence",fieldID:"thesis-reason",app:app)
        enter("The business can disappoint",fieldID:"thesis-risk",app:app)
        enter("New evidence contradicts my thesis",fieldID:"thesis-invalidation",app:app)
        let preview = app.buttons["order-preview"];reveal(preview,in:app);XCTAssertTrue(preview.isEnabled);preview.tap()
        let projection = app.descendants(matching:.any).matching(identifier:"order-portfolio-projection").firstMatch
        XCTAssertTrue(projection.waitForExistence(timeout:5),app.debugDescription);reveal(projection,in:app)
        let before = XCTAttachment(screenshot:app.screenshot());before.name="Apollo before-confirmation risk and sentiment estimate";before.lifetime = .keepAlways;add(before)
        let confirm=app.buttons["order-confirm"];reveal(confirm,in:app);XCTAssertFalse(confirm.isEnabled)
        let acknowledge=app.switches["order-acknowledge"];reveal(acknowledge,in:app);acknowledge.tap()
        reveal(confirm,in:app);XCTAssertTrue(confirm.isEnabled);confirm.tap()
        XCTAssertTrue(app.staticTexts["paper-order-success"].waitForExistence(timeout:8),app.debugDescription)
        let receipt = XCTAttachment(screenshot:app.screenshot());receipt.name="Apollo confirmed paper receipt";receipt.lifetime = .keepAlways;add(receipt)
        app.buttons["order-close"].tap();app.tabBars.buttons["Portfolio"].tap()
        XCTAssertTrue(app.staticTexts["portfolio-cash"].waitForExistence(timeout:5))
        let cash=app.staticTexts["portfolio-cash"].label
        app.terminate();app.launch();app.tabBars.buttons["Portfolio"].tap()
        XCTAssertTrue(app.staticTexts["portfolio-cash"].waitForExistence(timeout:5));XCTAssertEqual(app.staticTexts["portfolio-cash"].label,cash)
    }

    func testSevenTypesConnectedResearchAndPaperOrders() { sevenTypes(useBackend:true) }
    func testSevenTypesPhoneStandalone() { sevenTypes(useBackend:false) }
    func testRemainingFourTypesPhoneRecovery() { sevenTypes(useBackend:false,kinds:[("crypto","0.001"),("real_estate","1"),("option","1"),("strategy","250")]) }
    private func sevenTypes(useBackend:Bool,kinds:[(String,String)] = [("stock","1"),("etf","0.1"),("commodity","0.1"),("crypto","0.001"),("real_estate","1"),("option","1"),("strategy","250")]) {
        let app=XCUIApplication();app.launchArguments=useBackend ? ["--apollo-backend-url=http://127.0.0.1:8769"] : ["--apollo-test-storage="+UUID().uuidString];app.launch()
        let card=app.descendants(matching:.any).matching(identifier:"asset-card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout:20),app.debugDescription)
        for (kind,amount) in kinds {
            let filter=app.buttons["filter-"+kind]
            let filters=app.scrollViews["asset-filters"]
            for _ in 0..<8 where !filters.isHittable {
                app.coordinate(withNormalizedOffset:CGVector(dx:0.98,dy:0.25)).press(forDuration:0.02,thenDragTo:app.coordinate(withNormalizedOffset:CGVector(dx:0.98,dy:0.80)))
            }
            for _ in 0..<10 where !filter.isHittable {
                // Move toward the target's CURRENT frame; a full-width left swipe can overshoot it.
                let viewport=filters.frame,target=filter.frame
                let moveRight=target.midX < viewport.midX
                let from=filters.coordinate(withNormalizedOffset:CGVector(dx:moveRight ? 0.3 : 0.7,dy:0.5))
                let to=filters.coordinate(withNormalizedOffset:CGVector(dx:moveRight ? 0.7 : 0.3,dy:0.5))
                from.press(forDuration:0.02,thenDragTo:to)
            }
            XCTAssertTrue(filter.isHittable,"Missing category " + kind);filter.tap()
            XCTAssertTrue(card.waitForExistence(timeout:5));card.tap()
            XCTAssertTrue(app.staticTexts["asset-detail-title"].waitForExistence(timeout:5))
            let evidence=app.buttons["Evidence"];reveal(evidence,in:app);evidence.tap()
            for title in ["Leadership","Promises vs results","Public sentiment"] {
                let track=app.staticTexts[title];reveal(track,in:app);XCTAssertTrue(track.exists,kind+" missing "+title)
            }
            // SwiftUI Link exposes as a button on this OS; generic link-count is not valid.
            let sourceTitle: String? = useBackend ? (["stock":"CEO succession announced; effective September 1","etf":"Issuer exposure description","commodity":"Issuer exposure description","real_estate":"Issuer exposure description"][kind]) : (["stock":"SEC · Research company filings","etf":"Investor.gov · Exchange-traded funds","commodity":"Investor.gov · Commodities","crypto":"Investor.gov · Crypto assets","real_estate":"Investor.gov · REITs","option":"Investor.gov · Options","strategy":"Investor.gov · Diversification"][kind])
            if let title=sourceTitle { let source=app.buttons[title];reveal(source,in:app);XCTAssertTrue(source.exists,kind+" missing source action") }
            else { XCTAssertTrue(app.staticTexts["No linked source is available for this asset."].exists,kind+" missing honest source unavailability") }
            let detail=XCTAttachment(screenshot:app.screenshot());detail.name=kind+" current research evidence";detail.lifetime = .keepAlways;add(detail)
            app.buttons["detail-done"].tap();app.buttons["invest-button"].tap()
            if app.buttons["risk-profile-adventurous"].waitForExistence(timeout:1) {
                app.buttons["risk-profile-adventurous"].tap();let save=app.buttons["risk-profile-confirm"];reveal(save,in:app);save.tap()
            }
            XCTAssertTrue(app.textFields["order-quantity"].waitForExistence(timeout:5))
            enter(amount,fieldID:"order-quantity",app:app)
            enter("Review dated sources for "+kind,fieldID:"thesis-reason",app:app)
            enter("Value and evidence can disappoint",fieldID:"thesis-risk",app:app)
            enter("Changed source evidence",fieldID:"thesis-invalidation",app:app)
            let preview=app.buttons["order-preview"];reveal(preview,in:app);XCTAssertTrue(preview.isEnabled);preview.tap()
            let projection=app.descendants(matching:.any).matching(identifier:"order-portfolio-projection").firstMatch
            XCTAssertTrue(projection.waitForExistence(timeout:8),app.debugDescription)
            let confirm=app.buttons["order-confirm"];reveal(confirm,in:app);XCTAssertFalse(confirm.isEnabled)
            let acknowledge=app.switches["order-acknowledge"];reveal(acknowledge,in:app);acknowledge.tap()
            reveal(confirm,in:app);XCTAssertTrue(confirm.isEnabled);confirm.tap()
            XCTAssertTrue(app.staticTexts["paper-order-success"].waitForExistence(timeout:8),app.debugDescription)
            let receipt=XCTAttachment(screenshot:app.screenshot());receipt.name=kind+" paper order receipt";receipt.lifetime = .keepAlways;add(receipt)
            app.buttons["order-close"].tap()
        }
        app.tabBars.buttons["Portfolio"].tap();XCTAssertTrue(app.staticTexts["portfolio-cash"].waitForExistence(timeout:5))
        let cash=app.staticTexts["portfolio-cash"].label;app.terminate();app.launch();app.tabBars.buttons["Portfolio"].tap()
        XCTAssertTrue(app.staticTexts["portfolio-cash"].waitForExistence(timeout:5));XCTAssertEqual(app.staticTexts["portfolio-cash"].label,cash)
    }

    func testBlueReadOnlyComparisonPhoneSmoke() {
        let app=XCUIApplication();app.launchArguments=["--apollo-owner-comparison"];app.launch()
        let results=app.descendants(matching:.any).matching(identifier:"paper-comparison-results").firstMatch
        XCTAssertTrue(results.waitForExistence(timeout:15),app.debugDescription)
        let initial=XCTAttachment(screenshot:app.screenshot());initial.name="Blue Apollo read-only comparison foreground";initial.lifetime = .keepAlways;add(initial)
        for profile in ["conservative","balanced","adventurous"] {
            let panel=app.staticTexts[profile.capitalized]
            reveal(panel,in:app,limit:16);XCTAssertTrue(panel.exists,"Missing comparison profile "+profile)
            let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Blue comparison "+profile;shot.lifetime = .keepAlways;add(shot)
        }
        let outcomes=app.staticTexts["What if held marks moved together?"]
        reveal(outcomes,in:app,limit:16);XCTAssertTrue(outcomes.exists)
        let scenario=XCTAttachment(screenshot:app.screenshot());scenario.name="Blue hypothetical outcomes no order";scenario.lifetime = .keepAlways;add(scenario)
        app.activate()
    }

    private func revealContent(_ element:XCUIElement,in app:XCUIApplication,limit:Int=20) {
        for _ in 0..<limit {
            if element.exists && element.isHittable {return}
            app.coordinate(withNormalizedOffset:CGVector(dx:0.90,dy:0.78)).press(forDuration:0.02,thenDragTo:app.coordinate(withNormalizedOffset:CGVector(dx:0.90,dy:0.25)))
        }
    }
    func testBlueOnboardingReopenAndSettingsPreservePaperPortfolio() {
        continueAfterFailure=false
        let app=XCUIApplication();let storage="onboarding-blue-"+UUID().uuidString
        app.launchArguments=["--apollo-test-storage="+storage];app.launch()
        let next=app.buttons["onboarding-continue"]
        XCTAssertTrue(next.waitForExistence(timeout:10),app.debugDescription)
        let intro=XCTAttachment(screenshot:app.screenshot());intro.name="Blue onboarding explicit first run";intro.lifetime = .keepAlways;add(intro)
        revealContent(next,in:app);next.tap()
        let adventurous=app.descendants(matching:.any).matching(identifier:"onboarding-risk-adventurous").firstMatch;XCTAssertTrue(adventurous.waitForExistence(timeout:5));revealContent(adventurous,in:app);adventurous.tap()
        revealContent(next,in:app);next.tap();revealContent(next,in:app);XCTAssertTrue(next.isEnabled);next.tap()
        let card=app.descendants(matching:.any).matching(identifier:"asset-card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout:10),app.debugDescription)
        app.terminate();app.launch();XCTAssertTrue(card.waitForExistence(timeout:10));XCTAssertFalse(next.exists,"Completed quiz must stay skipped")
        app.buttons["invest-button"].tap()
        XCTAssertTrue(app.textFields["order-quantity"].waitForExistence(timeout:5))
        enter("1",fieldID:"order-quantity",app:app)
        enter("Preservation practice",fieldID:"thesis-reason",app:app)
        enter("Paper price can fall",fieldID:"thesis-risk",app:app)
        enter("Changed source evidence",fieldID:"thesis-invalidation",app:app)
        let preview=app.buttons["order-preview"];revealContent(preview,in:app);preview.tap()
        let acknowledge=app.switches["order-acknowledge"];XCTAssertTrue(acknowledge.waitForExistence(timeout:5));revealContent(acknowledge,in:app);acknowledge.tap()
        let confirm=app.buttons["order-confirm"];revealContent(confirm,in:app);XCTAssertTrue(confirm.isEnabled);confirm.tap()
        XCTAssertTrue(app.staticTexts["paper-order-success"].waitForExistence(timeout:5))
        let portfolio=app.buttons["order-view-portfolio"];revealContent(portfolio,in:app);portfolio.tap()
        let cash=app.staticTexts["portfolio-cash"];XCTAssertTrue(cash.waitForExistence(timeout:5));let cashBefore=cash.label
        let quantity=app.staticTexts["1 units"];revealContent(quantity,in:app);XCTAssertTrue(quantity.exists)
        let cost=app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","Cost $230.00")).firstMatch;revealContent(cost,in:app);XCTAssertTrue(cost.exists);let costBefore=cost.label
        let thesis=app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","Preservation practice")).firstMatch;revealContent(thesis,in:app);XCTAssertTrue(thesis.exists);let thesisBefore=thesis.label
        revealContent(app.staticTexts["Simulated fill"],in:app)
        let fillCount=app.staticTexts.matching(NSPredicate(format:"label == %@","Simulated fill")).count;XCTAssertEqual(fillCount,1)
        app.tabBars.buttons["Discover"].tap();app.buttons["watch-button"].tap();app.tabBars.buttons["Watchlist"].tap();XCTAssertTrue(app.staticTexts["SPY"].waitForExistence(timeout:5))
        app.tabBars.buttons["Discover"].tap();app.buttons["game-settings"].tap()
        let profile=app.descendants(matching:.any).matching(identifier:"settings-saved-profile").firstMatch
        XCTAssertTrue(profile.waitForExistence(timeout:5));XCTAssertTrue(profile.label.contains("Adventurous"),profile.label)
        app.buttons["settings-edit-profile"].tap();let conservative=app.descendants(matching:.any).matching(identifier:"onboarding-risk-conservative").firstMatch;XCTAssertTrue(conservative.waitForExistence(timeout:5));conservative.tap()
        let save=app.buttons["settings-profile-confirm"];revealContent(save,in:app);save.tap();XCTAssertTrue(app.staticTexts["Confirm your change."].waitForExistence(timeout:5));revealContent(save,in:app);save.tap()
        XCTAssertTrue(app.buttons["settings-edit-profile"].waitForExistence(timeout:5));XCTAssertTrue(profile.label.contains("Conservative"),profile.label)
        let saved=XCTAttachment(screenshot:app.screenshot());saved.name="Blue Settings profile changed without portfolio reset";saved.lifetime = .keepAlways;add(saved)
        app.buttons["settings-edit-profile"].tap();let balanced=app.descendants(matching:.any).matching(identifier:"onboarding-risk-balanced").firstMatch;XCTAssertTrue(balanced.waitForExistence(timeout:5));balanced.tap();app.navigationBars["Risk profile"].buttons["Cancel"].tap();XCTAssertTrue(profile.label.contains("Conservative"))
        app.terminate();app.launch();XCTAssertTrue(card.waitForExistence(timeout:10));XCTAssertFalse(next.exists)
        app.buttons["game-settings"].tap();XCTAssertTrue(profile.waitForExistence(timeout:5));XCTAssertTrue(profile.label.contains("Conservative"))
        app.tabBars.buttons["Watchlist"].tap();XCTAssertTrue(app.staticTexts["SPY"].waitForExistence(timeout:5))
        app.tabBars.buttons["Portfolio"].tap();XCTAssertTrue(cash.waitForExistence(timeout:5));XCTAssertEqual(cash.label,cashBefore)
        revealContent(quantity,in:app);XCTAssertTrue(quantity.exists);revealContent(cost,in:app);XCTAssertEqual(cost.label,costBefore)
        revealContent(thesis,in:app);XCTAssertEqual(thesis.label,thesisBefore);XCTAssertEqual(app.staticTexts.matching(NSPredicate(format:"label == %@","Simulated fill")).count,fillCount)
        let preserved=XCTAttachment(screenshot:app.screenshot());preserved.name="Blue portfolio holding and thesis survive Settings and relaunch";preserved.lifetime = .keepAlways;add(preserved)
    }

}
