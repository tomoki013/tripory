import XCTest

/// Generates App Store and brand-site screenshots for every screen worth
/// showing, in both shipped localizations, on iPhone 17 Pro Max at the real
/// 1320x2868 submission size.
///
/// Each screen is captured by a fresh launch driven by one of the app's
/// existing debug launch arguments (`-qaWorld`, `-qaTrips`, `-qaTripDetail`,
/// `-qaTripForm`; see `TriporyApp.swift`'s `applyDebugLaunchDestinationIfRequested()`
/// and `HomeView.swift`'s `-qaTripDetail`/`-qaCountryDetail` handling) rather
/// than by tapping through the UI, so navigation never depends on translated
/// button labels. `-seedDemo` seeds a small fixture of trips/countries the
/// first time the app data is empty; later launches in the same run reuse it,
/// so both locales show identical content (the seeded trip titles/notes are
/// authored in Japanese and are not localized — a known limitation of the
/// existing demo fixture, see AppStore/Screenshots/README.md).
///
/// Every screen waits on an accessibility identifier set on that screen's
/// root view (`homeScreen`, `worldGlobeScreen`, `tripTimelineScreen`,
/// `tripDetailScreen`, `tripFormScreen`), so the run is language-independent.
final class AppStoreScreenshotTests: XCTestCase {
    private static let localizations: [(language: String, locale: String)] = [
        ("en", "en_US"),
        // Leave the shared simulator in the developer's default language.
        // The fixture contains hardcoded Japanese trip titles, so ending on
        // Japanese makes the next manual run look consistent.
        ("ja", "ja_JP"),
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLocalizedScreenshots() throws {
        // The very first launch of the run can carry a "back to <previous
        // app>" status-bar breadcrumb left over from whatever app the
        // simulator had foregrounded before this test started. Warm up with
        // a throwaway launch/terminate so that breadcrumb (tied to the prior
        // foreground app, not to Tripory) is gone before any real capture.
        let warmUp = launch(Self.localizations[0], extraArguments: [])
        _ = screen("homeScreen", in: warmUp).waitForExistence(timeout: 20)
        warmUp.terminate()

        for localization in Self.localizations {
            captureHome(localization)
            captureWorldGlobe(localization)
            captureTrips(localization)
            captureTripDetail(localization)
            captureTripForm(localization)
        }
    }

    // MARK: - Screens

    private func captureHome(_ localization: (language: String, locale: String)) {
        let app = launch(localization, extraArguments: [])
        defer { app.terminate() }

        XCTAssertTrue(screen("homeScreen", in: app).waitForExistence(timeout: 20), "no home screen in \(localization.language)")
        // iOS briefly shows a "back to previous app" status-bar breadcrumb
        // immediately after launch, and the hero photo/launch animation need
        // a moment to settle. Let both clear so the capture contains only
        // steady-state Tripory UI.
        sleep(4)
        addScreenshot("\(localization.language)-01-home", app: app)
    }

    private func captureWorldGlobe(_ localization: (language: String, locale: String)) {
        let app = launch(localization, extraArguments: ["-qaWorld"])
        defer { app.terminate() }

        XCTAssertTrue(screen("worldGlobeScreen", in: app).waitForExistence(timeout: 20), "no world globe screen in \(localization.language)")
        // MKImageryMapConfiguration streams satellite imagery tiles over the
        // network on first use; give it time to finish before capturing.
        sleep(6)
        addScreenshot("\(localization.language)-02-world-globe", app: app)
    }

    private func captureTrips(_ localization: (language: String, locale: String)) {
        let app = launch(localization, extraArguments: ["-qaTrips"])
        defer { app.terminate() }

        XCTAssertTrue(screen("tripTimelineScreen", in: app).waitForExistence(timeout: 20), "no trip timeline screen in \(localization.language)")
        sleep(3)
        addScreenshot("\(localization.language)-03-trips", app: app)
    }

    private func captureTripDetail(_ localization: (language: String, locale: String)) {
        let app = launch(localization, extraArguments: ["-qaTripDetail"])
        defer { app.terminate() }

        // HomeView delays the debug push by 2s to let seed data land first.
        XCTAssertTrue(screen("tripDetailScreen", in: app).waitForExistence(timeout: 20), "no trip detail screen in \(localization.language): \(app.debugDescription)")
        // The push transition (and the dark-navy color-scheme override that
        // comes with it) can still be mid-flight the instant the identifier
        // appears; give it longer to settle than the other screens so the
        // capture never lands on a transitional blank frame.
        sleep(5)
        addScreenshot("\(localization.language)-04-trip-detail", app: app)
    }

    private func captureTripForm(_ localization: (language: String, locale: String)) {
        let app = launch(localization, extraArguments: ["-qaTripForm"])
        defer { app.terminate() }

        // RootView delays presenting the trip form sheet by 3s.
        XCTAssertTrue(screen("tripFormScreen", in: app).waitForExistence(timeout: 20), "no trip form screen in \(localization.language)")
        sleep(3)
        addScreenshot("\(localization.language)-05-trip-form", app: app)
    }

    // MARK: - Helpers

    /// Screen-root accessibility identifiers are set via `.accessibilityIdentifier`
    /// on container views (`ZStack`/`ScrollView`/etc.), which XCUITest surfaces
    /// as `.other` elements, not `.button` or a specific control type.
    private func screen(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func launch(_ localization: (language: String, locale: String), extraArguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-seedDemo",
            "-uiTestingRemovedAds",
            "-AppleLanguages", "(\(localization.language))",
            "-AppleLocale", localization.locale,
        ] + extraArguments
        app.launch()
        return app
    }

    private func addScreenshot(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
