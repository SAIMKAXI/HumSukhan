/// Public entry point for Wellbeing: optional mood check-ins kept on the
/// phone, the user's own pattern, and pre-written support.
library;

export '../../screens/wellbeing_screen.dart' show WellbeingScreen;
export '../../screens/wellbeing_help_screen.dart' show HelpNowScreen, SupportScreen, openWellbeingHelp;
export '../../providers/wellbeing_provider.dart';
export 'models/mood_entry.dart';
export 'services/mood_patterns.dart' show MoodState, MoodPattern, MoodPatterns;
