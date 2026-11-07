# Releasing for Android

Releases are published as GitHub Releases with the APK attached, by the **HumSukhan Android Release** workflow.

## Release signing key (once)

Android installs an update only if it is signed with the same key as the installed app. Every release must therefore be signed with one permanent key, kept safe: if it is lost, no later release can update the installed app.

1. Create the key on your own computer (Java's `keytool`, included with Android Studio):

   ```
   keytool -genkeypair -v -keystore humsukhan-release.jks -storetype PKCS12 -alias humsukhan -keyalg RSA -keysize 4096 -validity 10950
   ```

   Choose a strong password. Back up `humsukhan-release.jks` and the password somewhere safe and private. Never commit them.
2. In GitHub, open **Settings > Secrets and variables > Actions** and add:
   - `ANDROID_KEYSTORE_BASE64`: the keystore file in base64 (`base64 -w0 humsukhan-release.jks` on Linux, `base64 -i humsukhan-release.jks` on macOS, `[Convert]::ToBase64String([IO.File]::ReadAllBytes("humsukhan-release.jks"))` in PowerShell).
   - `ANDROID_KEYSTORE_PASSWORD`: the keystore password.
   - `ANDROID_KEY_ALIAS`: `humsukhan`.
   - `ANDROID_KEY_PASSWORD`: the key password (the same as the keystore password for a PKCS12 keystore).
3. That is all: the release workflow decodes the keystore into the runner's temporary folder, passes the four values to the build as `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD` (which `android/app/build.gradle.kts` reads), and deletes the file when the job ends. Without the secrets the build falls back to the runner's temporary debug key, which cannot update the previous release; the workflow then publishes with a warning. With the keystore set but a password or alias wrong, it refuses to publish.

For a local release build, put the same four values in `humsukhan/android/key.properties` (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`); the file is git-ignored.

## Each release

1. Set the version in `humsukhan/pubspec.yaml`, for example `version: 2.5.0+40`. The part after `+` is the Android version code and must be higher than the previous release's.
2. Start the release in one of three ways: push a commit to `main` whose message starts with `release:`, push a matching tag such as `v2.5.0`, or run **HumSukhan Android Release** by hand and enter the version.
3. Wait for **Build release APK**, **Verify APK exists**, **Upload APK artifact**, and **Create GitHub release** to complete successfully.
4. Open the GitHub Release and check that `HumSukhan-2.5.0.apk` is listed under Assets.
5. Install the APK over the previous release on an Android device before announcing it. If it installs over the old version, the signing key is right.

The workflow runs analysis and the full test suite first. It checks that the tag matches the app version, and that the APK exists, before publishing.

## What the APK carries

`tool/check_apk.py` checks every release APK, and the QA workflow builds and checks the same APK on every pull request. It fails when the APK:

- asks for a permission outside its list (microphone, internet, network state, vibration, the microphone foreground service, notifications, and restarting reminders after a reboot);
- is debuggable, allows unencrypted traffic, or allows Android backup or transfer to a new phone;
- lets other apps start a component that is not the main screen and is not guarded by a permission;
- contains a file outside the expected set: keys, env files, source code, unexpected assets, or build metadata such as library version files;
- contains anything shaped like an API key or private key, or a Supabase key other than the public anon key.

When a change needs a new permission, exposed component or asset, add it to the lists in `tool/check_apk.py` so it is reviewed. Run the check on a local build with `python3 tool/check_apk.py build/app/outputs/flutter-apk/app-release.apk`.

The Supabase URL and anon key are built into every APK on purpose: they are public, and the database's row-level security and the Edge Functions' sign-in checks protect the data. Provider keys (Deepgram, Soniox, Gemini) live only in Supabase Edge Function secrets and never in the app.

Release builds log nothing to the Android system log (`lib/utils/release_logging.dart`). Dart code is not obfuscated: the class names it would hide are not secret, and the background sound-alert service finds its Dart entry point by name.

The APK contains code for ARM phones only (`arm64-v8a` and `armeabi-v7a`); the build uses `--target-platform android-arm,android-arm64`, and `android/app/build.gradle.kts` packages the plugins' native libraries for the same platforms. Leaving out x86_64, which only emulators and Chromebooks use, keeps the download about 19 MB smaller. The workflow refuses to publish an APK with any other platform in it.
