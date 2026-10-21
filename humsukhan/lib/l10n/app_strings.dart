import 'package:flutter/widgets.dart';

/// Localized strings for HumSukhan (English & Urdu).
class AppStrings {
  final Locale locale;
  AppStrings(this.locale);

  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings)!;
  }

  static const LocalizationsDelegate<AppStrings> delegate = _AppStringsDelegate();

  bool get _isUrdu => locale.languageCode == 'ur';
  bool get isUrdu => _isUrdu;

  // ── General ──
  String get appName => 'HumSukhan';
  String get appTagline => _isUrdu ? 'قابلِ رسائی AI معاون' : 'Accessibility-first AI Companion';

  // ── Navigation ──
  String get navHome => _isUrdu ? 'گھر' : 'Home';
  String get navEveryday => _isUrdu ? 'ہر روز' : 'Everyday';
  String get navProfessional => _isUrdu ? 'پیشہ ورانہ' : 'Professional';
  String get navAlerts => _isUrdu ? 'الرٹس' : 'Alerts';
  String get navSettings => _isUrdu ? 'ترتیبات' : 'Settings';

  // ── Home ──
  String get goodMorning => _isUrdu ? 'صبح بخیر' : 'morning';
  String get goodAfternoon => _isUrdu ? 'دوپہر بخیر' : 'afternoon';
  String get goodEvening => _isUrdu ? 'شام بخیر' : 'evening';
  String get yourCompanion => _isUrdu ? 'آپ کا قابلِ رسائی ساتھی' : 'Your accessibility companion';
  String get quickActions => _isUrdu ? 'فوری اعمال' : 'QUICK ACTIONS';
  String get everydayMode => _isUrdu ? 'ہر روز کا موڈ' : 'Everyday Mode';
  String get startConversation => _isUrdu ? 'گفتگو شروع کریں' : 'Start a Conversation';
  String get professionalMode => _isUrdu ? 'پیشہ ورانہ موڈ' : 'Professional Mode';
  String get startMeetingLecture => _isUrdu ? 'میٹنگ / لیکچر شروع کریں' : 'Start a Meeting / Lecture';
  String get environmentalAlerts => _isUrdu ? 'ماحولیاتی الرٹس' : 'Environmental Alerts';
  String get monitoringActive => _isUrdu ? 'نگرانی فعال' : 'Monitoring active';
  String get monitoringOff => _isUrdu ? 'نگرانی بند' : 'Monitoring off';
  String get recentSessions => _isUrdu ? 'حالیہ اجلاس' : 'RECENT SESSIONS';
  String get viewAll => _isUrdu ? 'سب دیکھیں' : 'View all';
  String get noRecentSessions => _isUrdu ? 'کوئی حالیہ اجلاس نہیں۔ جب آپ تیار ہوں تو پیشہ ورانہ اجلاس شروع کریں۔' : 'No recent sessions. Start a Professional session when you are ready.';
  String get privacyNote => _isUrdu ? 'سننے کا عمل صرف آپ شروع کرنے پر شروع ہوتا ہے۔ آڈیو عارضی طور پر پروسیس ہوتا ہے اور ریلیز ہو جاتا ہے۔' : 'Listening begins only when you start. Audio is processed temporarily and released.';

  // ── Onboarding ──
  String get skip => _isUrdu ? 'چھوڑیں' : 'Skip';
  String get next => _isUrdu ? 'اگلا' : 'Next';
  String get getStarted => _isUrdu ? 'شروع کریں' : 'Get Started';
  String get onboardingWelcome => _isUrdu ? 'HumSukhan میں خوش آمدید' : 'Welcome to HumSukhan';
  String get onboardingWelcomeDesc => _isUrdu ? 'گفتگو، کیپشنز، اور پیشہ ورانہ سننے کے لیے ایک پرسکون، جامع ساتھی۔' : 'A calm, inclusive companion for conversations, captions, and professional listening.';
  String get onboardingEveryday => _isUrdu ? 'ہر روز کی گفتگو' : 'Everyday Conversations';
  String get onboardingEverydayDesc => _isUrdu ? 'گفتگو کے دوران لائیو کیپشنز حاصل کریں۔ ٹیکسٹ، فوری جوابات، یا ٹیکسٹ ٹو اسپیچ کے ذریعے جواب دیں۔' : 'Get live captions during conversations. Respond with text, quick replies, or text-to-speech.';
  String get onboardingProfessional => _isUrdu ? 'پیشہ ورانہ سننا' : 'Professional Listening';
  String get onboardingProfessionalDesc => _isUrdu ? 'لیکچرز اور میٹنگز کیپچر کریں۔ AI سے چلائی جانے والی خلاصے، اعمال کے اقدامات، اور بصیرت حاصل کریں۔' : 'Capture lectures and meetings. Get AI-powered summaries, action items, and insights.';
  String get onboardingEnvironmental => _isUrdu ? 'ماحولیاتی آگاہی' : 'Environmental Awareness';
  String get onboardingEnvironmentalDesc => _isUrdu ? 'اپنے آس پاس اہم آوازوں کے بارے میں جانیں — سائرن، دروازے کی گھنٹی، دستک، اور بچے کے رونے کی آوازیں۔' : 'Know about important sounds around you — sirens, doorbells, knocks, and baby cries.';
  String get onboardingPrivacy => _isUrdu ? 'رازداری پہلے' : 'Privacy First';
  String get onboardingPrivacyDesc => _isUrdu ? 'آڈیو عارضی طور پر پروسیس ہوتا ہے اور ریلیز ہو جاتا ہے۔ خام آڈیو کبھی محفوظ نہیں کیا جاتا۔' : 'Audio is processed temporarily and released. No raw audio is ever stored.';

  // ── Everyday ──
  String get everydayTitle => _isUrdu ? 'ہر روز' : 'Everyday';
  String get startListening => _isUrdu ? 'سننا شروع کریں' : 'Start Listening';
  String get stopConversation => _isUrdu ? 'گفتگو بند کریں' : 'Stop Conversation';
  String get saveConversation => _isUrdu ? 'گفتگو محفوظ کریں؟' : 'Save Conversation?';
  String get saveConversationDesc => _isUrdu ? 'کیا آپ ان کیپشنز کو حوالے کے لیے محفوظ کرنا چاہیں گے؟' : 'Would you like to save these captions for reference?';
  String get save => _isUrdu ? 'محفوظ کریں' : 'Save';
  String get delete => _isUrdu ? 'حذف کریں' : 'Delete';
  String get continueListening => _isUrdu ? 'سننا جاری رکھیں' : 'Continue Listening';

  // ── Professional ──
  String get professionalTitle => _isUrdu ? 'پیشہ ورانہ' : 'Professional';
  String get newSession => _isUrdu ? 'نیا اجلاس' : 'New Session';
  String get generalFolder => _isUrdu ? 'عمومی' : 'General';
  String get sessionsCount => _isUrdu ? 'اجلاس' : 'sessions';
  String get noSavedSessions => _isUrdu ? 'ابھی تک کوئی محفوظ شدہ اجلاس نہیں' : 'No saved sessions yet';
  String get noSavedSessionsDesc => _isUrdu ? 'جب آپ تیار ہوں تو لیکچر یا میٹنگ کیپچر کرنے کے لیے پیشہ ورانہ اجلاس شروع کریں۔' : 'Start a Professional session when you are ready to capture a lecture or meeting.';
  String get startSession => _isUrdu ? 'اجلاس شروع کریں' : 'Start Session';
  String get noFoldersYet => _isUrdu ? 'ابھی تک کوئی فولڈر نہیں' : 'No folders yet';
  String get noFoldersDesc => _isUrdu ? 'اپنے اجلاس کو ترتیب دینے کے لیے فولڈر بنائیں۔' : 'Create a folder to organize your sessions.';
  String get createFolder => _isUrdu ? 'فولڈر بنائیں' : 'Create Folder';
  String get sessionTitle => _isUrdu ? 'اجلاس کا عنوان' : 'Session Title';
  String get sessionTitleHint => _isUrdu ? 'جیسے پروڈکٹ لانچ منصوبہ' : 'e.g., Product Launch Planning';
  String get sessionType => _isUrdu ? 'اجلاس کی قسم' : 'Session Type';
  String get retentionPeriod => _isUrdu ? 'رٹینشن مدت' : 'Retention Period';
  String get folderName => _isUrdu ? 'فولڈر کا نام' : 'Folder name';
  String get deleteSessionConfirm => _isUrdu ? 'اجلاس حذف کریں؟' : 'Delete Session?';
  String get deleteSessionDesc => _isUrdu ? 'یہ محفوظ شدہ ٹرانسکرپٹ اور بصیرت کو مستقل طور پر ہٹا دے گا۔ یہ واپس نہیں کیا جا سکتا۔' : 'This will permanently remove the saved transcript and insights. This cannot be undone.';
  String get create => _isUrdu ? 'بنائیں' : 'Create';

  // ── Session Live ──
  String get addCaptionManually => _isUrdu ? 'دستی طور پر کیپشن شامل کریں...' : 'Add a caption manually...';
  String get stopSession => _isUrdu ? 'اجلاس بند کریں' : 'Stop Session';

  // ── Session Detail ──
  String get overviewTab => _isUrdu ? 'جائزہ' : 'Overview';
  String get transcriptTab => _isUrdu ? 'ٹرانسکرپٹ' : 'Transcript';
  String get summaryTab => _isUrdu ? 'خلاصہ' : 'Summary';
  String get actionsTab => _isUrdu ? 'اقدامات' : 'Actions';
  String get exportAction => _isUrdu ? 'برآمد' : 'Export';
  String get deleteAction => _isUrdu ? 'حذف' : 'Delete';
  String get moveToFolderAction => _isUrdu ? 'فولڈر میں منتقل کریں' : 'Move to folder';
  String movedToFolder(String folder) => _isUrdu ? '$folder میں منتقل کر دیا گیا' : 'Moved to $folder';
  String get aiInsights => _isUrdu ? 'AI بصیرت' : 'AI INSIGHTS';
  String get aiSummary => _isUrdu ? 'AI خلاصہ' : 'AI Summary';
  String get actionItems => _isUrdu ? 'عمل کے اقدامات' : 'Action Items';
  String get deadlines => _isUrdu ? 'ڈیڈ لائنز' : 'Deadlines';
  String get peopleMentioned => _isUrdu ? 'ذکر کردہ لوگ' : 'People Mentioned';
  String get noTranscriptAvailable => _isUrdu ? 'کوئی ٹرانسکرپٹ دستیاب نہیں' : 'No transcript available';
  String get noTranscriptDesc => _isUrdu ? 'کوئی ٹرانسکرپٹ کیپچر نہیں کیا گیا۔ ٹرانسکرپٹ کیپچر کرنے کے لیے نیا اجلاس شروع کریں۔' : 'No transcript was captured. You can start a new session to capture a transcript.';
  String get insightsUnavailable => _isUrdu ? 'بصیرت دستیاب نہیں' : 'Insights unavailable';
  String get insightsUnavailableDesc => _isUrdu ? 'ہم اس اجلاس کے لیے AI بصیرت تیار نہیں کر سکے۔ آپ کا اصل ٹرانسکرپٹ ابھی بھی دستیاب ہے۔' : 'We couldn\'t generate AI insights for this session. Your original transcript is still available.';
  String get retryAiSummary => _isUrdu ? 'AI خلاصہ دوبارہ بنائیں' : 'Retry AI summary';
  String get summaryNotProvided => _isUrdu ? 'AI نے کچھ بصیرتیں تیار کیں، لیکن خلاصے کے نکات نہیں دیے۔ دستیاب کاموں کے لیے اقدامات کا ٹیب دیکھیں۔' : 'The AI returned other insights but no summary bullets. Check Actions and any available deadlines below.';
  String get noActionItems => _isUrdu ? 'کوئی عمل کے اقدامات نہیں' : 'No action items';
  String get noActionItemsDesc => _isUrdu ? 'AI تجزیے کے بعد عمل کے اقدامات یہاں ظاہر ہوں گے۔' : 'Action items will appear here after AI analysis.';
  String get noItemsAvailable => _isUrdu ? 'کوئی اشیاء دستیاب نہیں' : 'No items available';
  String get exportTxt => _isUrdu ? 'TXT کے طور پر برآمد کریں' : 'Export as TXT';
  String get copyClipboard => _isUrdu ? 'کلپ بورڈ پر کاپی کریں' : 'Copy to Clipboard';
  String get savedRecordsNote => _isUrdu ? 'محفوظ شدہ ریکارڈز کیپشنز اور میٹا ڈیٹا رکھتے ہیں۔ خام آڈیو نہیں رکھا جاتا۔' : 'Saved records contain captions and metadata. Raw audio is not stored.';
  String get exportPrivacyNote => _isUrdu ? 'برآمد شدہ فائلیں HumSukhan کے باہر رکھی جاتی ہیں اور خودکار طور پر حذف نہیں ہوں گی۔' : 'Exported files are stored outside HumSukhan and won\'t be automatically deleted.';

  // ── Environmental ──
  String get environmentalTitle => _isUrdu ? 'ماحولیاتی الرٹس' : 'Environmental Alerts';
  String get monitoringOffTitle => _isUrdu ? 'نگرانی بند' : 'Monitoring Off';
  String get startMonitoring => _isUrdu ? 'نگرانی شروع کریں' : 'Start Monitoring';
  String get stopMonitoring => _isUrdu ? 'نگرانی بند کریں' : 'Stop Monitoring';
  String get alertHistory => _isUrdu ? 'الرٹ کی تاریخ' : 'ALERT HISTORY';
  String get clearAll => _isUrdu ? 'سب صاف کریں' : 'Clear All';
  String get noAlertsYet => _isUrdu ? 'ابھی تک کوئی الرٹس نہیں' : 'No alerts yet';
  String get startingMonitoring => _isUrdu ? 'نگرانی شروع ہو رہی ہے…' : 'Starting monitoring…';
  String get monitoringListeningLocally => _isUrdu
      ? 'HumSukhan آپ کے فون پر ہی معاون ماحولیاتی آوازیں سن رہا ہے۔'
      : 'HumSukhan is listening locally for supported environmental sounds.';
  String get monitoringIsOff => _isUrdu ? 'ماحولیاتی نگرانی بند ہے۔' : 'Environmental monitoring is off.';
  String get monitoringFixAndRetry => _isUrdu
      ? 'اجازت یا سروس کا مسئلہ حل کریں، پھر دوبارہ کوشش کریں۔'
      : 'Fix the permission or service issue, then try again.';
  String get monitoringUnavailable => _isUrdu ? 'ماحولیاتی نگرانی شروع نہیں ہو سکی۔' : 'Unable to start environmental monitoring.';
  String get openMicrophoneSettings => _isUrdu ? 'مائیکروفون کی ترتیبات کھولیں' : 'Open microphone settings';
  String get soundDetected => _isUrdu ? 'ایک آواز کا پتہ چلا۔' : 'A sound was detected.';
  String get noAlertsDesc => _isUrdu ? 'آوازوں کا پتہ لگنے پر الرٹ کی تاریخ یہاں ظاہر ہوگی۔' : 'Alert history will appear here when sounds are detected.';
  String get detected => _isUrdu ? 'پتہ لگا' : 'DETECTED';
  String get confidence => _isUrdu ? 'اعتماد' : 'confidence';
  String get dismiss => _isUrdu ? 'بند کریں' : 'Dismiss';

  // ── Settings ──
  String get settingsTitle => _isUrdu ? 'ترتیبات' : 'Settings';
  String get profile => _isUrdu ? 'پروفائل' : 'Profile';
  String get setupProfile => _isUrdu ? 'پروفائل سیٹ اپ کریں' : 'Set up profile';
  String get tapToEdit => _isUrdu ? 'ترمیم کے لیے ٹیپ کریں' : 'Tap to edit';
  String get editProfile => _isUrdu ? 'پروفائل میں ترمیم کریں' : 'Edit Profile';
  String get nameLabel => _isUrdu ? 'نام' : 'Name';
  String get accessibility => _isUrdu ? 'رسائی پذیری' : 'Accessibility';
  String get darkMode => _isUrdu ? 'ڈارک موڈ' : 'Dark Mode';
  String get darkModeDesc => _isUrdu ? 'کم روشنی میں آنکھوں پر دباؤ کم کریں' : 'Reduce eye strain in low light';
  String get highContrast => _isUrdu ? 'اعلیٰ کنٹراسٹ' : 'High Contrast';
  String get highContrastDesc => _isUrdu ? 'بہتر نظارے کے لیے کنٹراسٹ بڑھائیں' : 'Increase contrast for better visibility';
  String get largeText => _isUrdu ? 'بڑا متن' : 'Large Text';
  String get largeTextDesc => _isUrdu ? 'مجموعی متن کا سائز بڑھائیں' : 'Increase overall text size';
  String get captionTextSize => _isUrdu ? 'کیپشن متن کا سائز' : 'Caption Text Size';
  String get alertPreferences => _isUrdu ? 'الرٹ ترجیحات' : 'Alert Preferences';
  String get hapticAlerts => _isUrdu ? 'ہیپٹک الرٹس' : 'Haptic Alerts';
  String get hapticAlertsDesc => _isUrdu ? 'الرٹس کے لیے وائبریشن' : 'Vibrate for alerts';
  String get visualAlerts => _isUrdu ? 'بصری الرٹس' : 'Visual Alerts';
  String get visualAlertsDesc => _isUrdu ? 'بصری الرٹ اشارے دکھائیں' : 'Show visual alert indicators';
  String get screenFlashAlerts => _isUrdu ? 'اسکرین فلیش الرٹس' : 'Screen Flash Alerts';
  String get screenFlashAlertsDesc => _isUrdu ? 'الرٹس کے لیے اسکرین فلیش کریں' : 'Flash the screen for alerts';
  String get flashlightAlerts => _isUrdu ? 'فلیش لائٹ الرٹس' : 'Flashlight Alerts';
  String get flashlightAlertsDesc => _isUrdu ? 'الرٹس کے لیے فلیش لائٹ استعمال کریں' : 'Use flashlight for alerts';
  String get speechRecognition => _isUrdu ? 'بولی کی پہچان' : 'Speech Recognition';
  String get currentMode => _isUrdu ? 'موجودہ موڈ' : 'Current Mode';
  String get englishLabel => _isUrdu ? 'انگریزی' : 'English';
  String get urduLabel => _isUrdu ? 'اردو' : 'Urdu';
  String get downloadLabel => _isUrdu ? 'ڈاؤن لوڈ' : 'Download';
  String get defaultRetention => _isUrdu ? 'ڈیفالٹ رٹینشن' : 'Default Retention';
  String get defaultRetentionPeriod => _isUrdu ? 'ڈیفالٹ رٹینشن مدت' : 'Default Retention Period';
  String get privacySection => _isUrdu ? 'رازداری' : 'Privacy';
  String get privacyNoticeText => _isUrdu ? 'HumSukhan آڈیو کو عارضی طور پر پروسیس کرتا ہے اور ریلیز کرتا ہے۔ خام آڈیو کبھی محفوظ نہیں کیا جاتا۔ محفوظ شدہ ریکارڈز صرف کیپشنز اور میٹا ڈیٹا رکھتے ہیں۔ برآمد شدہ فائلیں HumSukhan کے باہر رکھی جاتی ہیں۔' : 'HumSukhan processes audio temporarily and releases it. No raw audio is ever stored. Saved records contain captions and metadata only. Exported files are stored outside HumSukhan.';
  String get aboutSection => _isUrdu ? 'ہمارے بارے میں' : 'About';
  String get cancel => _isUrdu ? 'منسوخ' : 'Cancel';
  String get resetSettings => _isUrdu ? 'ترتیبات ابتدائی حالت پر لائیں' : 'Reset settings';
  String get resetSettingsDesc => _isUrdu
      ? 'ڈسپلے، الرٹ اور رازداری کی ترتیبات کو ابتدائی حالت پر واپس لائیں۔'
      : 'Restore display, alert and privacy settings to their defaults.';
  String get resetSettingsConfirm => _isUrdu
      ? 'تمام ترتیبات ابتدائی حالت پر واپس کریں؟ آپ کی ایپ کی زبان، اکاؤنٹ اور محفوظ اجلاس برقرار رہیں گے۔'
      : 'Reset all settings to their defaults? Your app language, account and saved sessions are kept.';
  String get resetAction => _isUrdu ? 'واپس لائیں' : 'Reset';
  String get settingsWereReset => _isUrdu ? 'ترتیبات ابتدائی حالت پر واپس آ گئیں' : 'Settings restored to defaults';
  String get quickRepliesSection => _isUrdu ? 'فوری جوابات' : 'Quick replies';
  String get manageQuickReplies => _isUrdu ? 'فوری جوابات کا انتظام' : 'Manage quick replies';
  String get manageQuickRepliesDesc => _isUrdu
      ? 'جوابات شامل کریں، پسندیدہ بنائیں یا حذف کریں۔ پسندیدہ جوابات پہلے دکھائے جاتے ہیں۔'
      : 'Add, favourite or delete replies. Favourites are shown first.';
  String get addQuickReplyHint => _isUrdu ? 'نیا فوری جواب لکھیں' : 'Type a new quick reply';
  String get addAction => _isUrdu ? 'شامل کریں' : 'Add';
  String get addToFavourites => _isUrdu ? 'پسندیدہ میں شامل کریں' : 'Add to favourites';
  String get removeFromFavourites => _isUrdu ? 'پسندیدہ سے ہٹائیں' : 'Remove from favourites';
  String get noQuickReplies => _isUrdu ? 'ابھی کوئی فوری جواب نہیں' : 'No quick replies yet';
  String get appLanguage => _isUrdu ? 'ایپ کی زبان' : 'App Language';
  String get syncedWithSupabase => _isUrdu ? 'Supabase کے ساتھ ہم آہنگ' : 'Synced with Supabase';
  String get notSignedIn => _isUrdu ? 'سائن اِن نہیں کیا گیا' : 'Not signed in';
  String get signedInAccount => _isUrdu ? 'سائن اِن اکاؤنٹ' : 'Signed-in account';
  String get signInToSync => _isUrdu ? 'ڈیوائسز کے درمیان ڈیٹا ہم آہنگ کرنے کے لیے سائن اِن کریں' : 'Sign in to sync your data across devices';
  String get signOut => _isUrdu ? 'سائن آؤٹ' : 'Sign Out';
  String get signIn => _isUrdu ? 'سائن اِن' : 'Sign In';
  String get days => _isUrdu ? 'دن' : 'days';
  String get ready => _isUrdu ? 'تیار' : 'Ready';
  String get notDownloadedStatus => _isUrdu ? 'ڈاؤن لوڈ نہیں کیا گیا' : 'Not downloaded';
  String downloadingPercent(int percent) => _isUrdu ? 'ڈاؤن لوڈ ہو رہا ہے $percent%' : 'Downloading $percent%';
  String get modelReadyNotice => _isUrdu ? 'آف لائن ماڈل تیار ہے۔ انٹرنیٹ نہ ہونے پر کیپشنز اسی سے بنیں گے۔' : 'Offline model ready. Captions will use it when there is no internet.';
  String get modelDownloadFailed => _isUrdu ? 'ماڈل ڈاؤن لوڈ نہیں ہو سکا۔ انٹرنیٹ کنکشن چیک کر کے دوبارہ کوشش کریں۔' : 'The model could not be downloaded. Check your internet connection and try again.';
  String get removeDownload => _isUrdu ? 'ڈاؤن لوڈ ہٹائیں' : 'Remove download';
  String get offlineModelsInfo => _isUrdu ? 'آف لائن ماڈلز انٹرنیٹ کے بغیر رازداری اور دستیابی بہتر بناتے ہیں۔ جہاں دستیاب ہو، آن لائن اسپیچ ریکگنیشن بھی استعمال کی جا سکتی ہے۔' : 'Offline models improve privacy and availability when you do not have internet access. You can also use online speech recognition when available.';
  String get englishModelTitle => _isUrdu ? 'انگریزی تقریر کی پہچان' : 'English speech recognition';
  String get englishModelDesc => _isUrdu ? 'انٹرنیٹ کنکشن کے بغیر ریئل ٹائم انگریزی کیپشنز کے لیے اختیاری آف لائن ماڈل۔' : 'Optional offline model for real-time English captions without an internet connection.';
  String get urduModelTitle => _isUrdu ? 'اردو تقریر کی پہچان' : 'Urdu speech recognition';
  String get urduModelDesc => _isUrdu ? 'انٹرنیٹ کے بغیر اردو کیپشنز کے لیے اختیاری آف لائن ماڈل۔ ہر جملہ بولنے والے کے رکنے کے بعد ظاہر ہوتا ہے۔' : 'Optional offline model for Urdu-script captions without an internet connection. Each sentence appears after the speaker pauses.';

  // ── Listening ──
  String get captionsLabel => _isUrdu ? 'کیپشنز' : 'captions';

  // ── AI Disclaimer ──
  String get aiDisclaimer => _isUrdu ? 'AI سے تیار کردہ — غلطیاں ممکن ہیں' : 'AI-generated — may contain errors';

  // ── Retention ──
  String get daysLeft => _isUrdu ? 'دن باقی' : 'days left';
  String get retention1Day => _isUrdu ? '1 دن' : '1 day';
  String get retention7Days => _isUrdu ? '7 دن' : '7 days';
  String get retention15Days => _isUrdu ? '15 دن (زیادہ سے زیادہ)' : '15 days (maximum)';

  // ── App Language Selection ──
  String get languageEnglish => 'English';
  String get languageUrdu => 'اردو';

  // ── Quick Replies ──
  static const quickRepliesEn = [
    ('Hello', 'Conversation'),
    ('Thank you', 'Conversation'),
    ('Please wait', 'Conversation'),
    ('Please repeat that', 'Conversation'),
    ('Please type it', 'Conversation'),
    ('I did not understand', 'Conversation'),
    ('Yes', 'Response'),
    ('No', 'Response'),
    ('One moment, please', 'Response'),
    ('I need help', 'Response'),
  ];

  static const quickRepliesUr = [
    ('سلام', 'Conversation'),
    ('شکریہ', 'Conversation'),
    ('براہ کرم انتظار کریں', 'Conversation'),
    ('براہ کرم دہرائیں', 'Conversation'),
    ('براہ کرم ٹائپ کریں', 'Conversation'),
    ('مجھے سمجھ نہیں آیا', 'Conversation'),
    ('ہاں', 'Response'),
    ('نہیں', 'Response'),
    ('ایک لمحہ، براہ کرم', 'Response'),
    ('مجھے مدد چاہیے', 'Response'),
  ];

}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ur'].contains(locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) async => AppStrings(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppStrings> old) => false;
}
