# Tripory

Tripory is an iOS travel journal built with SwiftUI and SwiftData. The Xcode project is generated from `project.yml`:

```sh
xcodegen generate
```

## Advertising and in-app purchase

Debug builds use only Google's official test AdMob IDs. Release IDs are centralized in the Release build settings in `project.yml` (`ADMOB_APP_ID`, `ADMOB_BANNER_AD_UNIT_ID`, and `ADMOB_INTERSTITIAL_AD_UNIT_ID`). An unset ad unit safely disables that format; a Release archive fails validation unless every production ID is present and none is a Google test ID.

The one-time, non-consumable StoreKit product is:

```text
io.tmkch.tripory.removeads
```

Create the App Store Connect product with exactly that ID. Local development uses `Tripory/Resources/Products.storekit`; prices shown in the app always come from `Product.displayPrice` and are never hard-coded.

See `RELEASE_CHECKLIST.md` before publishing.
