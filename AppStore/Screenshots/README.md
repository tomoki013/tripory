# App Store screenshots

`TriporyUITests/AppStoreScreenshotTests` generates five screens (home / My
World, the 3D world globe, the trip timeline, a trip's detail page, and the
"record a trip" form) for each of the two shipped localizations (`ja`, `en`)
on iPhone 17 Pro Max, at the real 1320x2868 submission size.

Each screen is captured by its own fresh app launch, driven entirely by
existing DEBUG-only launch arguments rather than by tapping through
translated UI:

- `-uiTesting` – skips onboarding (home country defaults to Japan) and
  disables the consent/ads flow so no ATT-style dialog or test ad reaches a
  screenshot.
- `-seedDemo` – seeds a small fixture of trips and visited/wishlist
  countries the first time the app's data store is empty (see
  `seedDemoDataIfRequested()` in `Tripory/TriporyApp.swift`). Later launches
  in the same run reuse that data, so all five screens (and both locales)
  show consistent content.
- `-uiTestingRemovedAds` – marks ads as removed for the run.
- `-qaWorld` / `-qaTrips` – select the World / Trips tab on launch
  (`applyDebugLaunchDestinationIfRequested()` in `TriporyApp.swift`).
- `-qaTripDetail` – pushes the most recently-dated trip's detail screen
  (`HomeView.swift`'s debug `.task`).
- `-qaTripForm` – opens the "record a trip" sheet pre-filled with France
  after a short delay (`applyDebugLaunchDestinationIfRequested()`).

Each screen's root view carries an accessibility identifier
(`homeScreen`, `worldGlobeScreen`, `tripTimelineScreen`, `tripDetailScreen`,
`tripFormScreen`) that the test waits on, so the run never depends on
translated labels. The four tab bar buttons also carry `tab-home`,
`tab-trips`, `tab-world`, `tab-me` identifiers for the same reason, even
though the current test drives screens via launch arguments rather than
tapping tabs.

**Known limitations of the current fixture / app:**

- The seed data's trip titles and notes (e.g. "パリ再訪") are hardcoded in
  Japanese in `seedDemoDataIfRequested()` and are not localized, so they
  appear in Japanese even in the `en` captures. This mirrors real user data
  mixing with UI chrome and was judged acceptable for a first pass; a fully
  English fixture would need its own seed path.
- A few UI strings (for example the trip form's save button, and the
  `visitHistory` day-count label's pluralization) are not yet localized for
  English — this is a pre-existing gap in the app's localization, not
  something introduced by this screenshot pipeline.

**Before you start**, uninstall any stale build of the app from the
simulator. `-seedDemo` only seeds when the data store is completely empty,
so a simulator with leftover data from manual testing will skip seeding and
produce an empty-looking capture:

```sh
xcrun simctl uninstall "iPhone 17 Pro Max" io.tmkch.tripory
```

Pin the status bar next, or captures carry the host clock and battery:

```sh
xcrun simctl boot "iPhone 17 Pro Max"
xcrun simctl status_bar "iPhone 17 Pro Max" override \
  --time "9:41" --batteryState discharging --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3
```

```sh
xcodegen generate
xcodebuild -project Tripory.xcodeproj -scheme Tripory \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -resultBundlePath /tmp/TriporyShots.xcresult \
  -only-testing:TriporyUITests/AppStoreScreenshotTests test

xcrun xcresulttool export attachments \
  --path /tmp/TriporyShots.xcresult \
  --output-path AppStore/Screenshots/generated
```

`xcresulttool` writes UUID filenames; the readable name is in its
`manifest.json` under `suggestedHumanReadableName`, as
`<lang>-<nn>-<screen>_<index>_<uuid>.png`. Strip the `_<index>_<uuid>` suffix
to land on the final `<lang>-<nn>-<screen>.png` name the brand site's
`scripts/import-app-screenshots.mjs` expects.

Widgets are not covered: a Home Screen or Lock Screen widget cannot be
captured from inside the app, so those remain illustrations.

The brand site imports a bilingual subset of the same files via
`scripts/import-app-screenshots.mjs` in the app-studio monorepo.

## A note on XCUITest reliability

An earlier attempt at a similar screenshot suite on a sibling app (Colorvia)
hung indefinitely under `xcodebuild test` even though the app worked fine
launched normally — suspected Swift Concurrency/XCTest interaction. That did
not reproduce here: the five-screen, two-locale suite (10 captures) runs in
under two minutes with no hangs, using a fresh `XCUIApplication().launch()`
per screen rather than one long-lived app instance navigated by taps. If a
future addition to this suite hangs, prefer more/smaller launches (one
screen per launch, as done here) over a single long-running session with
many in-process taps.
