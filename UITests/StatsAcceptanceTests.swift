import XCTest

final class StatsAcceptanceTests:XCTestCase {
    @MainActor private func launch(_ route:String,appearance:String="Light",size:String="UICTContentSizeCategoryL",selected:Bool=false,yearSelected:Bool=false) -> XCUIApplication {
        let app=XCUIApplication(); app.launchArguments=["-phase6-fixture","-phase0-appearance",appearance,"-UIPreferredContentSizeCategoryName",size]
        if route != "shell" { app.launchArguments += ["-phase6-screen",route] }
        if selected { app.launchArguments += ["-phase6-selected"] }; if yearSelected { app.launchArguments += ["-phase6-year-selected"] }
        app.launch(); XCUIDevice.shared.orientation = .portrait
        if route=="shell" {
            let tab=app.buttons["foundationTab.Stats"]; XCTAssertTrue(tab.waitForExistence(timeout:10)); tab.tap()
        }
        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout:10)); return app
    }
    @MainActor private func capture(_ app:XCUIApplication,_ name:String) {
        let a=XCTAttachment(screenshot:app.screenshot()); a.name="Phase6-"+name; a.lifetime = .keepAlways; add(a)
    }
    @MainActor private func reveal(_ app:XCUIApplication,_ e:XCUIElement) {
        let viewport=app.scrollViews.firstMatch.frame.intersection(app.frame).insetBy(dx:0,dy:12)
        for _ in 0..<40 {
            if e.exists && e.isHittable && (viewport.contains(e.frame) || (e.frame.height>viewport.height && e.frame.minY>=viewport.minY && e.frame.minY<viewport.midY)) { return }
            let down=e.exists && e.frame.minY<viewport.minY
            app.coordinate(withNormalizedOffset:.init(dx:0.9,dy:down ? 0.4 : 0.7)).press(forDuration:0.05,thenDragTo:app.coordinate(withNormalizedOffset:.init(dx:0.9,dy:down ? 0.7 : 0.4)))
        }
        XCTAssertTrue(e.exists && e.isHittable,"Required Stats element must remain reachable: \(e.identifier) \(e.label) \(e.frame)")
    }
    @MainActor private func tap(_ app:XCUIApplication,_ e:XCUIElement) {
        reveal(app,e); XCTAssertTrue(e.isHittable); XCTAssertGreaterThanOrEqual(e.frame.width,44); XCTAssertGreaterThanOrEqual(e.frame.height,44)
        if e.isHittable { e.tap() }
    }
    @MainActor func testMonthIncompleteDataRatingAndManualYearChoice() {
        let app=launch("month")
        XCTAssertEqual(app.staticTexts["stats.books.value"].label,"3")
        XCTAssertEqual(app.staticTexts["stats.pages.value"].label,"220 recorded")
        XCTAssertEqual(app.staticTexts["stats.days.value"].label,"2 recorded")
        XCTAssertEqual(app.staticTexts["stats.rating.value"].label,"4.0 / 5")
        reveal(app,app.staticTexts["stats.best.empty"]); XCTAssertEqual(app.staticTexts["stats.best.empty"].label,"Not selected")
        tap(app,app.buttons["stats.best.choose"])
        let choice=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","stats.candidate.")).firstMatch
        tap(app,choice); capture(app,"Flow-E-month-explicit-choice")
        app.navigationBars.buttons.firstMatch.tap()
        reveal(app,app.staticTexts["stats.best.title"]); XCTAssertTrue(app.staticTexts["stats.best.title"].exists)
        tap(app,app.buttons["stats.scope.Year"])
        reveal(app,app.staticTexts["stats.best.empty"]); XCTAssertEqual(app.staticTexts["stats.best.empty"].label,"Not selected")
        tap(app,app.buttons["stats.best.choose"])
        XCTAssertEqual(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","stats.candidate.")).count,1)
        tap(app,app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","stats.candidate.")).firstMatch)
        capture(app,"Flow-E-year-explicit-choice")
        app.navigationBars.buttons.firstMatch.tap()
        reveal(app,app.staticTexts["stats.best.title"]); XCTAssertTrue(app.staticTexts["stats.best.title"].exists)
        app.terminate()
    }
    @MainActor func testRereadLifetimeUnknownAndJournalReuse() {
        var app=launch("lifetime")
        XCTAssertEqual(app.staticTexts["stats.books.value"].label,"6")
        XCTAssertEqual(app.staticTexts["stats.pages.value"].label,"300 recorded")
        capture(app,"Flow-B-lifetime-reread")
        app.terminate(); app=launch("unknown")
        XCTAssertEqual(app.staticTexts["stats.books.value"].label,"1")
        XCTAssertEqual(app.staticTexts["stats.pages.value"].label,"Unknown")
        XCTAssertEqual(app.staticTexts["stats.days.value"].label,"Unknown")
        capture(app,"Flow-C-unknown-not-zero")
        app.terminate(); app=launch("month",selected:true)
        tap(app,app.buttons["stats.mode"])
        XCTAssertEqual(app.staticTexts["stats.journal.title"].label,"Journal View · Month")
        XCTAssertEqual(app.staticTexts["stats.books.value"].label,"3")
        reveal(app,app.staticTexts["stats.best.title"]); XCTAssertTrue(app.staticTexts["stats.best.title"].exists)
        capture(app,"Flow-F-Journal-shared-month-choice")
        app.terminate()
    }
    @MainActor func testStatsTabShellModes() {
        for (appearance,size) in [("Light","UICTContentSizeCategoryL"),("Dark","UICTContentSizeCategoryL"),("Light","UICTContentSizeCategoryAccessibilityXXXL")] {
            let app=launch("shell",appearance:appearance,size:size)
            XCTAssertTrue(app.staticTexts["stats.books.value"].waitForExistence(timeout:10))
            for name in ["Home","Journal","Challenges","Series","Stats"] {
                let tab=app.buttons["foundationTab."+name]; XCTAssertTrue(tab.exists); XCTAssertGreaterThanOrEqual(tab.frame.width,44); XCTAssertGreaterThanOrEqual(tab.frame.height,44)
            }
            XCTAssertTrue(app.buttons["foundationTab.Stats"].isSelected)
            capture(app,"\(appearance)-\(size)-shell-overview")
            app.terminate()
        }
    }
    @MainActor func testStatsPrimaryNumbersModes() {
        for (appearance,size) in [("Light","UICTContentSizeCategoryL"),("Dark","UICTContentSizeCategoryL"),("Light","UICTContentSizeCategoryAccessibilityXXXL")] {
            for (route,value) in [("month","3"),("year","3"),("lifetime","6")] {
                let app=launch(route,appearance:appearance,size:size)
                let number=app.staticTexts["stats.books.value"]; reveal(app,number)
                XCTAssertEqual(number.label,value); XCTAssertTrue(number.isHittable)
                capture(app,"\(appearance)-\(size)-\(route)-books-number")
                app.terminate()
            }
        }
    }
    @MainActor func testStatsVisualMatrix() {
        let cases=[("Light","UICTContentSizeCategoryL"),("Dark","UICTContentSizeCategoryL"),("Light","UICTContentSizeCategoryAccessibilityXXXL")]
        for (appearance,size) in cases {
            let prefix="\(appearance)-\(size)"
            for route in ["month","year","lifetime","unknown","journal-month","journal-year","journal-lifetime","readings","year-candidates"] {
                let app=launch(route,appearance:appearance,size:size,selected:route=="year-candidates")
                capture(app,"\(prefix)-\(route)-top")
                if route=="readings" || route=="year-candidates" {
                    app.swipeUp(); capture(app,"\(prefix)-\(route)-lower")
                } else {
                    for id in ["stats.pages.value","stats.days.value","stats.rating.value"] {
                        let e=app.staticTexts[id]; reveal(app,e); XCTAssertTrue(e.isHittable); capture(app,"\(prefix)-\(route)-\(id)")
                    }
                    for title in ["Primary Genres","Formats"] {
                        reveal(app,app.staticTexts[title].firstMatch); capture(app,"\(prefix)-\(route)-\(title)")
                        app.swipeUp(); capture(app,"\(prefix)-\(route)-\(title)-lower")
                    }
                    if !route.hasPrefix("journal") {
                        reveal(app,app.staticTexts["Reading over time"]); capture(app,"\(prefix)-\(route)-chart")
                        app.swipeUp(); capture(app,"\(prefix)-\(route)-chart-lower")
                    }
                    if route=="journal-lifetime" {
                        for y in [2026,2030] {
                            reveal(app,app.staticTexts["stats.journal.year.\(y)"]); capture(app,"\(prefix)-journal-lifetime-year-\(y)")
                            app.swipeUp(); capture(app,"\(prefix)-journal-lifetime-year-\(y)-lower")
                        }
                    }
                    if !route.contains("lifetime") {
                        reveal(app,app.staticTexts["stats.best.empty"]); capture(app,"\(prefix)-\(route)-best-unselected")
                    }
                }
                app.terminate()
            }
            for route in ["month","year"] {
                let app=launch(route,appearance:appearance,size:size,selected:true,yearSelected:route=="year")
                reveal(app,app.staticTexts[route=="month" ? "Best Book of the Month" : "Book of Year"])
                capture(app,"\(prefix)-\(route)-best-selected-cover")
                reveal(app,app.staticTexts["stats.best.title"])
                capture(app,"\(prefix)-\(route)-best-selected")
                tap(app,app.buttons["stats.best.choose"])
                let button=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","stats.candidate.")).firstMatch
                reveal(app,button); XCTAssertGreaterThanOrEqual(button.frame.width,44); XCTAssertGreaterThanOrEqual(button.frame.height,44)
                capture(app,"\(prefix)-\(route)-selected-candidate")
                app.terminate()
            }
        }
    }
}
