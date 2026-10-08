# MORI Daily Market

Flutter storefront and point-of-sale app using Firebase Authentication and Cloud
Firestore.

## Run locally

```powershell
flutter pub get
flutter run
```

## Deploy the web app to Firebase Hosting

The Flutter web target is configured for the Firebase project
`newflutterapp-pos-20261005`.

```powershell
flutter build web --release
firebase deploy --only hosting
```

The hosted site is available at
`https://newflutterapp-pos-20261005.web.app`.

To deploy Firestore security rules separately:

```powershell
firebase deploy --only firestore:rules
```

## Features

- Guest browsing, cart, checkout, favorites, product comments, reorder
- Product discounts (admin sets % per product or in bulk; sale section on home)
- Admin: order accept/reject/ship workflow with live popups, products, categories,
  stock, customers, sales dashboard and CSV export
- Customer order-status popups, profile with rank and stats
- Japanese / English / Burmese

## Production checklist

- **Admin accounts:** a user's `role` can only be changed by an existing admin
  (or manually in the Firestore console). Self-registration always creates `user`.
- **Android release signing:** create a keystore and `android/key.properties`
  (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`). Without it the release
  build falls back to debug keys. Both are git-ignored.
- **Application ID:** `com.example.newflutterapp` should be replaced by your own ID
  and re-registered in Firebase (new `google-services.json`) before a store release.
- **Security rules:** deploy `firestore.rules` after every change.
- **Not included:** push notifications (popups only show while the app is open),
  image upload, App Check.

## Tests

```powershell
flutter analyze
flutter test
```
