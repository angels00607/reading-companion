import XCTest

final class StoryGraphImportAcceptanceTests:XCTestCase {
    @MainActor private func launch(_ style:String="Light",size:String="UICTContentSizeCategoryL") -> XCUIApplication {
        let app=XCUIApplication();app.launchArguments=["-phase8-fixture","-phase0-appearance",style,"-UIPreferredContentSizeCategoryName",size]
        app.launch();XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.buttons["import.fixture.menu"].waitForExistence(timeout:15));return app
    }
    @MainActor private func capture(_ app:XCUIApplication,_ name:String) {
        let a=XCTAttachment(screenshot:app.screenshot());a.name="Phase8-"+name;a.lifetime = .keepAlways;add(a)
    }
    @MainActor private func reveal(_ app:XCUIApplication,_ element:XCUIElement) {
        let viewport=app.scrollViews.firstMatch.frame.intersection(app.frame).insetBy(dx:0,dy:12)
        for _ in 0..<45 {
            if element.exists && element.isHittable && (viewport.contains(element.frame) || (element.frame.height>viewport.height && element.frame.minY>=viewport.minY && element.frame.minY<viewport.midY)) { return }
            let down=element.exists && element.frame.minY<viewport.minY
            app.coordinate(withNormalizedOffset:.init(dx:0.94,dy:down ? 0.4:0.72)).press(forDuration:0.05,thenDragTo:app.coordinate(withNormalizedOffset:.init(dx:0.94,dy:down ? 0.72:0.4)))
        }
        XCTAssertTrue(element.exists && element.isHittable,"Required import element remains reachable: \(element.identifier) \(element.label) \(element.frame)")
    }
    @MainActor private func tap(_ app:XCUIApplication,_ element:XCUIElement) {
        reveal(app,element);XCTAssertGreaterThanOrEqual(element.frame.width,44);XCTAssertGreaterThanOrEqual(element.frame.height,44);XCTAssertTrue(element.isHittable)
        if element.isHittable { element.tap() }
    }
    @MainActor private func confirm(_ app:XCUIApplication) {
        tap(app,app.buttons["import.confirm"])
        let confirmation=app.buttons["Import supported history"];XCTAssertTrue(confirmation.waitForExistence(timeout:5));confirmation.tap()
        XCTAssertTrue(app.staticTexts["import.result"].waitForExistence(timeout:10))
    }
    @MainActor private func fixture(_ app:XCUIApplication,_ id:String) {
        let menu=app.buttons["import.fixture.menu"]
        XCTAssertTrue(menu.exists);XCTAssertTrue(app.frame.contains(menu.frame))
        // CoreGraphics may report a nominal 44-point SwiftUI frame as
        // 43.999999999999986; round to the rendered point without lowering 44.
        XCTAssertGreaterThanOrEqual(menu.frame.width.rounded(),44);XCTAssertGreaterThanOrEqual(menu.frame.height.rounded(),44)
        // XCTest's nested SwiftUI Menu proxy requests an unsupported AX scroll action
        // despite its visible navigation-bar frame. Tap the same live frame directly.
        menu.coordinate(withNormalizedOffset:.init(dx:0.5,dy:0.5)).tap()
        let action=app.buttons[id];XCTAssertTrue(action.waitForExistence(timeout:5));action.tap()
    }
    @MainActor private func verifyImportedLibrary(_ app:XCUIApplication,capturePrefix:String?=nil) {
        tap(app,app.buttons["import.library"])
        let reread=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@ AND label CONTAINS %@","books.row.","The Lantern Archive")).firstMatch
        reveal(app,reread);XCTAssertTrue(reread.label.contains("Read 2×"),"Two completions share one canonical Book row")
        if let prefix=capturePrefix { capture(app,prefix+"-Imported-Library") }
        let unknown=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@ AND label CONTAINS %@","books.row.","The Unknown Shore")).firstMatch
        tap(app,unknown);tap(app,app.buttons["books.history"])
        let unknownFormat=app.staticTexts["Format: Unknown"];reveal(app,unknownFormat);XCTAssertTrue(unknownFormat.exists)
        XCTAssertTrue(app.staticTexts["Finished: Unknown"].exists)
        if let prefix=capturePrefix { capture(app,prefix+"-Imported-Unknown-History") }
        app.navigationBars.buttons.firstMatch.tap();app.navigationBars.buttons.firstMatch.tap();app.navigationBars.buttons.firstMatch.tap()
    }
    @MainActor func testHistoricalImportAndExplicitReconciliation() {
        let app=launch();fixture(app,"import.fixture.initial")
        let preview=app.descendants(matching:.any)["import.preview"]
        let newBooks=app.descendants(matching:.any)["import.group.New Books"]
        XCTAssertTrue(preview.waitForExistence(timeout:10));reveal(app,newBooks);XCTAssertEqual(newBooks.label,"New Books · 3")
        confirm(app);reveal(app,app.staticTexts["import.fixture.safety"])
        XCTAssertEqual(app.staticTexts["import.fixture.safety"].label,"3 readings · 0 XP · 0 Quest progress · 0 Achievements · 0 Challenges · 0 Inbox")
        verifyImportedLibrary(app)
        fixture(app,"import.fixture.protect");fixture(app,"import.fixture.reconcile")
        XCTAssertTrue(app.staticTexts["import.preview"].waitForExistence(timeout:10));reveal(app,app.staticTexts["import.group.Possible Updates"]);XCTAssertEqual(app.staticTexts["import.group.Possible Updates"].label,"Possible Updates · 1")
        reveal(app,app.staticTexts["import.group.Already Up to Date"]);XCTAssertEqual(app.staticTexts["import.group.Already Up to Date"].label,"Already Up to Date · 1")
        reveal(app,app.staticTexts["import.group.Needs Review"]);XCTAssertEqual(app.staticTexts["import.group.Needs Review"].label,"Needs Review · 2")
        confirm(app);tap(app,app.buttons["import.needsReview"])
        let title=app.otherElements["import.review.title"];reveal(app,title)
        XCTAssertTrue(app.descendants(matching:.any)["import.protected"].exists)
        XCTAssertTrue(app.staticTexts["The Lantern Archive · My corrected title"].exists)
        tap(app,title.buttons["Keep"])
        let finish=app.otherElements["import.review.finish_date"];reveal(app,finish);XCTAssertTrue(finish.staticTexts["2025-02-10"].exists)
        tap(app,finish.buttons["Accept"])
        XCTAssertFalse(app.otherElements["import.review.finish_date"].exists)
        app.navigationBars.buttons.firstMatch.tap();tap(app,app.buttons["import.history"])
        XCTAssertEqual(app.otherElements.matching(identifier:"import.history.row").count,2)
        XCTAssertFalse(app.staticTexts["Import not applied"].exists)
    }
    @MainActor func testImportPreviewCancelDoesNotCommit() {
        let app=launch();fixture(app,"import.fixture.initial");XCTAssertTrue(app.staticTexts["import.preview"].waitForExistence(timeout:10));tap(app,app.buttons["import.cancel"])
        tap(app,app.buttons["import.history"]);XCTAssertTrue(app.staticTexts["No confirmed imports yet."].exists)
    }
    @MainActor func testImportVisualMatrix() {
        for (style,size,label) in [("Light","UICTContentSizeCategoryL","Light-Standard"),("Dark","UICTContentSizeCategoryL","Dark-Standard"),("Light","UICTContentSizeCategoryAccessibilityXXXL","Accessibility-XXXL")] {
            let app=launch(style,size:size);capture(app,label+"-Entry")
            fixture(app,"import.fixture.initial");XCTAssertTrue(app.staticTexts["import.preview"].waitForExistence(timeout:10))
            reveal(app,app.staticTexts["import.group.New Books"]);capture(app,label+"-New-Books")
            reveal(app,app.staticTexts["import.group.Already Up to Date"]);capture(app,label+"-Preview-Categories")
            confirm(app);reveal(app,app.staticTexts["import.result"]);capture(app,label+"-Committed")
            verifyImportedLibrary(app,capturePrefix:label)
            fixture(app,"import.fixture.protect");fixture(app,"import.fixture.reconcile");XCTAssertTrue(app.staticTexts["import.preview"].waitForExistence(timeout:10))
            reveal(app,app.staticTexts["import.group.Possible Updates"]);capture(app,label+"-Possible-Updates")
            reveal(app,app.staticTexts["import.group.Needs Review"]);capture(app,label+"-Needs-Review")
            tap(app,app.buttons["import.confirm"]);capture(app,label+"-Explicit-Confirmation")
            app.buttons["Import supported history"].tap();XCTAssertTrue(app.staticTexts["import.result"].waitForExistence(timeout:10))
            tap(app,app.buttons["import.needsReview"])
            let title=app.otherElements["import.review.title"];reveal(app,title);capture(app,label+"-Protected-Title")
            let currentTitle=title.staticTexts["The Lantern Archive · My corrected title"]
            reveal(app,currentTitle);capture(app,label+"-Current-Title")
            reveal(app,title.buttons["Keep"]);capture(app,label+"-Title-Actions")
            tap(app,title.buttons["Keep"])
            let finish=app.otherElements["import.review.finish_date"];reveal(app,finish);capture(app,label+"-Current-Imported-Date")
            reveal(app,finish.buttons["Accept"]);capture(app,label+"-Date-Actions")
            tap(app,finish.buttons["Accept"])
            let rating=app.otherElements["import.review.rating"];reveal(app,rating);capture(app,label+"-Rating")
            tap(app,rating.buttons["Keep"])
            tap(app,app.buttons["import.candidate.4"]);capture(app,label+"-Ambiguous-Identity")
            reveal(app,app.buttons["import.identity.existing"]);capture(app,label+"-Identity-Choice")
            app.navigationBars.buttons.firstMatch.tap()
            tap(app,app.buttons["import.candidate.5"]);capture(app,label+"-Unsupported-Date-Rating")
            reveal(app,app.buttons["import.identity.skip"]);capture(app,label+"-Keep-Unapplied")
            app.navigationBars.buttons.firstMatch.tap();app.navigationBars.buttons.firstMatch.tap()
            tap(app,app.buttons["import.history"]);capture(app,label+"-History")
            app.swipeUp();capture(app,label+"-History-Lower")
            app.terminate()
        }
    }
}
