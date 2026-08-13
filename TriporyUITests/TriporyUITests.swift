import XCTest

final class TriporyUITests: XCTestCase {
    private func launch(additionalArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        // このテストスイートは全体を通して日本語のラベル("マイページ"、"広告を削除"等)で
        // 要素を検索している。CIのシミュレータは言語設定がローカル環境と異なることがあり、
        // 一部の文字列(英語訳が存在するもの)だけが翻訳されて表示され、検索に失敗する
        // (未翻訳の文字列はベースの日本語のまま表示されるため、この不整合は一部のassertでしか
        // 顕在化しない)。テストの前提を環境に依存させないよう、言語を明示的に固定する。
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"] + additionalArguments
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
        XCTAssertTrue(app.buttons["キャンセル"].waitForExistence(timeout: 8))
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
