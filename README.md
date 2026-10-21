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
   <queries>
     <intent>
       <action android:name="android.intent.action.VIEW"/>
       <data android:scheme="upi" android:host="pay"/>
     </intent>
     <package android:name="com.google.android.apps.nbu.paisa.user"/>
     <package android:name="com.phonepe.app"/>
     <package android:name="net.one97.paytm"/>
     <package android:name="in.org.npci.upiapp"/>
     <package android:name="com.dreamplug.androidapp"/>
     <package android:name="in.amazon.mShop.android.shopping"/>
     <package android:name="com.whatsapp"/>
   </queries>
5. Plug in phone (USB debugging on) and run: flutter run
   Or build the APK: flutter build apk --release
   -> build/app/outputs/flutter-apk/app-release.apk

## Customising UPI apps
Edit the `upiApps` list at the top of lib/main.dart (name + Android package).
PayLane must open a specific app with the original UPI URL. A generic
system chooser is what made GPay/PhonePe fail the same QR.

## How the QR payload is handed to the UPI app
NPCI wants the scanned payload forwarded untouched, so PayLane does not
re-encode it:

* A merchant QR's `sign` is a base64 signature over the literal query
  string. Rewriting it (turning `+` into `%2B`, for example) stops the
  payer's PSP from decoding it and the bank rejects the debit as a
  tampered request. PayLane now sends the payload byte for byte.
* Text wrapped around the link (Bharat QR, WhatsApp shares) is cut off
  after the `sign`, and spaces inside a parameter value are kept.
* `mode` and `orgid` are added only to unsigned payloads, and `mode` stays
  `01` (QR Code). NPCI's risk engine declines intent initiated
  transactions (`04`/`05`) against merchant QR payees and person to person
  payments, which is what a bank reports as a rejected request.
* The exact payload that is sent is printed to logcat as
  `PayLane -> <package>: <payload>`.
