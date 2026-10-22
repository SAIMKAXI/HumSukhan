# Android Release Checklist

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

1. Confirm `humsukhan/pubspec.yaml` contains the intended version, for example `version: 2.3.5+24`.
2. Push/create the matching Git tag, for example `v2.3.5`, on the release commit, or run **HumSukhan Android Release** manually and enter that exact tag in the `tag` input.
3. Wait for **Build release APK**, **Verify APK exists**, **Upload APK artifact**, and **Create GitHub release** to complete successfully.
4. Open the GitHub Release for the tag and verify `HumSukhan-2.3.5.apk` is listed under Assets.
5. Download and install the APK on an Android device before distributing it.

The workflow validates that the release tag matches the app version and that the APK file exists before attempting publication.
