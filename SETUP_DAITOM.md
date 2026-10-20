# DAITOM MOTORLINK LTD - setup (com.daitom.flutter)

## A. App + Firebase (project: `daitom`)
Run in the project root (the folder with pubspec.yaml). Do NOT re-run the `rename` commands.

    flutter clean
    flutter pub get
    flutter run

If an older build of com.daitom.flutter is on the phone/emulator, uninstall it first.

Firebase console -> project `daitom` (one-time):
1. Authentication -> Sign-in method -> enable the method the app uses (Email/Password).
2. Firestore Database -> Create database (the new project starts EMPTY - old Ultracem data does not move over).
3. Firestore -> Rules: paste your rules from the old project.
4. Create the first admin user + profile document the same way the old project had it.
5. Only if you use Google / phone sign-in: add your SHA-1 and SHA-256
   (cd android && gradlew signingReport  [Windows]  /  ./gradlew signingReport  [Mac/Linux]),
   then re-download android/app/google-services.json.

## B. M-Pesa (Paybill + Account Number)
Full walkthrough: see MPESA_SETUP.md (fresh DAITOM-only setup; nothing shared with any other app).

## C. Things only you can supply
- Cloudinary: lib/store/add_section.dart still uses the old account ("dpxcjlg2b" / "billk_images").
- Support WhatsApp number in lib/pages/settings/help_and_faq.dart (254717405109) - confirm it is yours.
- assets/primary_signature.png (used on contracts/PDFs) - replace with the right DAITOM signatory.
- assets/kra.png is the KRA logo - leave unless it should change.
