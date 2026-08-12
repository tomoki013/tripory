import XCTest

final class TriporyUITests: XCTestCase {
    private func launch(additionalArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + additionalArguments
        app.launch()
        return app
    }

    func testRootHasFourTabsAndFloatingAddButton() {
        let app = launch()
        XCTAssertTrue(app.buttons["rootAddTripButton"].waitForExistence(timeout: 8))

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 3))
        XCTAssertEqual(tabBar.buttons.count, 4)
        XCTAssertFalse(tabBar.buttons["plus"].exists)
    }

    func testFloatingAddButtonIsAvailableFromEveryRootTabAndHiddenInForm() {
        let app = launch()
        let add = app.buttons["rootAddTripButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 8))

        for tab in app.tabBars.firstMatch.buttons.allElementsBoundByIndex {
            tab.tap()
            XCTAssertTrue(add.exists)
        }

        add.tap()
        XCTAssertTrue(app.buttons["キャンセル"].waitForExistence(timeout: 20))
        XCTAssertFalse(add.isHittable)
    }

    func testSettingsContainsRemoveAdsAndRestore() {
        let app = launch(additionalArguments: ["-qaMe"])
        XCTAssertTrue(app.tabBars.firstMatch.buttons["マイページ"].waitForExistence(timeout: 8))
        let restore = app.buttons["購入を復元"]
        for _ in 0..<6 where !restore.exists { app.swipeUp() }
        XCTAssertTrue(restore.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["広告を削除"].exists || app.staticTexts["広告削除済み"].exists)
    }

    func testFreeStateHasBannerContainer() {
        let app = launch(additionalArguments: ["-uiTestingFreeAds"])
        XCTAssertTrue(app.descendants(matching: .any)["bannerAdContainer"].waitForExistence(timeout: 8))
    }

    func testRemovedAdsStateHasNoBannerContainer() {
        let app = launch(additionalArguments: ["-uiTestingRemovedAds"])
        XCTAssertTrue(app.buttons["rootAddTripButton"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.descendants(matching: .any)["bannerAdContainer"].exists)
    }

    func testSettingsHasNoBannerContainer() {
        let app = launch(additionalArguments: ["-uiTestingFreeAds", "-qaMe"])
        XCTAssertTrue(app.tabBars.firstMatch.buttons["マイページ"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.descendants(matching: .any)["bannerAdContainer"].exists)
    }
}
