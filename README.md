# UPI Router

## Option A: Get the APK with no installs (GitHub Actions)
1. Create a free GitHub account, make a new repo, upload everything in this folder (keep the .github folder).
2. Open the repo's Actions tab -> "Build APK" -> Run workflow.
3. After ~5 min, open the finished run and download the "upi-router-apk" artifact (a zip containing app-release.apk).
4. Copy the APK to your Android phone and install (allow "install unknown apps").

## Option B: Build locally
1. Install Flutter: https://docs.flutter.dev/get-started/install (with Android Studio / SDK)
2. flutter create --platforms=android --project-name upi_router .
3. Replace pubspec.yaml and lib/main.dart with the ones here.
4. In android/app/src/main/AndroidManifest.xml add, just above <application:
   <uses-permission android:name="android.permission.CAMERA"/>
   <queries><intent><action android:name="android.intent.action.VIEW"/><data android:scheme="upi"/></intent></queries>
5. Plug in phone (USB debugging on) and run: flutter run
   Or build the APK: flutter build apk --release
   -> build/app/outputs/flutter-apk/app-release.apk

## Customising offers
Edit the `upiApps` list at the top of lib/main.dart.
