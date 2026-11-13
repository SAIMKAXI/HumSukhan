/// Which part of the app the account gate shows, after the splash screen.
///
/// The stage is not stored: it follows from the auth session and the
/// settings each time either changes, in the priority [appStageFor] gives.
enum AppStage {
  /// The account opened a password-reset link: set a new password first.
  settingNewPassword,

  /// Settings are still being read from the phone.
  loadingSettings,

  /// No one is signed in.
  signedOut,

  /// Signed in, but onboarding has not been finished.
  onboarding,

  /// The app itself.
  ready,
}

/// The stage for the given auth session and settings.
AppStage appStageFor({
  required bool recoveringPassword,
  required bool settingsLoaded,
  required bool signedIn,
  required bool onboardingComplete,
}) {
  // A recovery link signs the account in, so it comes before everything
  // else: otherwise a half-recovered account would land in the app.
  if (recoveringPassword) return AppStage.settingNewPassword;
  if (!settingsLoaded) return AppStage.loadingSettings;
  if (!signedIn) return AppStage.signedOut;
  if (!onboardingComplete) return AppStage.onboarding;
  return AppStage.ready;
}
