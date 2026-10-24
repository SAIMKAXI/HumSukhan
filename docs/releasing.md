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
3. The release workflow must pass these to the build as the environment variables `ANDROID_KEYSTORE_PATH` (the decoded file), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD`, which `android/app/build.gradle.kts` reads. Without them the build falls back to a debug key, which cannot update the previous release.

For a local release build, put the same four values in `humsukhan/android/key.properties` (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`); the file is git-ignored.

## Each release

1. Set the version in `humsukhan/pubspec.yaml`, for example `version: 2.5.0+40`. The part after `+` is the Android version code and must be higher than the previous release's.
2. Start the release in one of three ways: push a commit to `main` whose message starts with `release:`, push a matching tag such as `v2.5.0`, or run **HumSukhan Android Release** by hand and enter the version.
3. Wait for **Build release APK**, **Verify APK exists**, **Upload APK artifact**, and **Create GitHub release** to complete successfully.
4. Open the GitHub Release and check that `HumSukhan-2.5.0.apk` is listed under Assets.
5. Install the APK over the previous release on an Android device before announcing it. If it installs over the old version, the signing key is right.

The workflow runs analysis and the full test suite first. It checks that the tag matches the app version, and that the APK exists, before publishing.
