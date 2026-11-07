import 'package:flutter/foundation.dart';

/// In a release build, makes [debugPrint] write nothing.
///
/// [debugPrint] still writes to the Android system log in release builds,
/// where a connected computer can read it. The app's log lines carry error
/// text from Supabase and the speech services, which can include what the
/// user said or typed, so a build people install logs nothing.
void silenceLogsInRelease() {
  if (kReleaseMode) debugPrint = (String? message, {int? wrapWidth}) {};
}
