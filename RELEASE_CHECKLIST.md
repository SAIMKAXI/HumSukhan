# Android Release Checklist

1. Confirm `humsukhan/pubspec.yaml` contains the intended version, for example `version: 2.3.5+24`.
2. Push/create the matching Git tag, for example `v2.3.5`, on the release commit, or run **HumSukhan Android Release** manually and enter that exact tag in the `tag` input.
3. Wait for **Build release APK**, **Verify APK exists**, **Upload APK artifact**, and **Create GitHub release** to complete successfully.
4. Open the GitHub Release for the tag and verify `HumSukhan-2.3.5.apk` is listed under Assets.
5. Download and install the APK on an Android device before distributing it.

The workflow validates that the release tag matches the app version and that the APK file exists before attempting publication.
