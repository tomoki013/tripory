# Tripory Release Checklist

Code is prepared to run without production advertising IDs, but an archive intentionally fails until all production IDs are configured.

## AdMob

- Register the app with bundle ID `io.tmkch.tripory`.
- Obtain the AdMob App ID.
- Create an anchored adaptive banner ad unit.
- Create an interstitial ad unit.
- Create the UMP GDPR message.
- Create a US state privacy message when applicable.
- Configure an IDFA explanation message when applicable.
- Put all three production IDs into the Release configuration: `ADMOB_APP_ID`, `ADMOB_BANNER_AD_UNIT_ID`, and `ADMOB_INTERSTITIAL_AD_UNIT_ID`.
- Verify the current Google Mobile Ads SDK privacy disclosures and SKAdNetwork list again immediately before submission.

## App Store Connect

- Create a non-consumable product with Product ID `io.tmkch.tripory.removeads`.
- Set its localized display name, description, price, and review metadata.
- Complete Sandbox purchase and restore testing.
- Update App Privacy answers for Google Mobile Ads, UMP, ATT, and StoreKit.
- Declare tracking/advertising data use as required for the final AdMob configuration.
- After the real App Store ID is assigned, set `TRIPORY_APP_STORE_ID`; the review link remains hidden while it is empty.
- Test an archive after every Release configuration change.

## Website

- Publish an advertising-compatible privacy policy at <https://tripory.tmkch.io/privacy>.
- Review the terms at <https://tripory.tmkch.io/terms>.
- Confirm <https://tripory.tmkch.io> is public.
- Confirm <https://tmkch.io/support> is available.
- Keep the web privacy policy aligned with the in-app legal text and the final App Store Privacy answers.

## Device verification

- Exercise UMP in a debug-forced EEA region and reopen privacy choices.
- Test both ATT allow and deny; denial must not block the app or contextual ads.
- Verify banner/interstitial failure and offline behavior.
- Test successful purchase, cancellation, pending approval, restore, relaunch, refund, and entitlement revocation with StoreKit Test/Sandbox.
- Check small iPhone, landscape, largest Dynamic Type, VoiceOver, Reduce Motion, light mode, and dark mode.
