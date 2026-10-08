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
