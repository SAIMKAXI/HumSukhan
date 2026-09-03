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

  // ── General ──
  String get appName => 'HumSukhan';
  String get appTagline => _isUrdu ? 'قابلِ رسائی AI معاون' : 'Accessibility-first AI Companion';
  String get versionLabel => _isUrdu ? 'نسخہ 2.3.6 — قابلِ رسائی AI معاون' : 'Version 2.3.6 — Accessibility-first AI companion';

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
  String get onboardingEnvironmentalDesc => _isUrdu ? 'اپنے آس پاس اہم آوازوں کے بارے میں جانیں — فائر الارم، دروازے کی گھنٹی، فون کالز، اور بہت کچھ۔' : 'Know about important sounds around you — fire alarms, doorbells, phone calls, and more.';
  String get onboardingPrivacy => _isUrdu ? 'رازداری پہلے' : 'Privacy First';
  String get onboardingPrivacyDesc => _isUrdu ? 'آڈیو عارضی طور پر پروسیس ہوتا ہے اور ریلیز ہو جاتا ہے۔ خام آڈیو کبھی محفوظ نہیں کیا جاتا۔' : 'Audio is processed temporarily and released. No raw audio is ever stored.';

  // ── Everyday ──
  String get everydayTitle => _isUrdu ? 'ہر روز' : 'Everyday';
  String get listeningStatus => _isUrdu ? 'سن رہا ہے — آڈیو عارضی طور پر پروسیس ہوتا ہے' : 'Listening — audio is processed temporarily';
  String get typeResponse => _isUrdu ? 'جواب ٹائپ کریں...' : 'Type a response...';
  String get startListening => _isUrdu ? 'سننا شروع کریں' : 'Start Listening';
  String get stopConversation => _isUrdu ? 'گفتگو بند کریں' : 'Stop Conversation';
  String get saveConversation => _isUrdu ? 'گفتگو محفوظ کریں؟' : 'Save Conversation?';
  String get saveConversationDesc => _isUrdu ? 'کیا آپ ان کیپشنز کو حوالے کے لیے محفوظ کرنا چاہیں گے؟' : 'Would you like to save these captions for reference?';
  String get save => _isUrdu ? 'محفوظ کریں' : 'Save';
  String get delete => _isUrdu ? 'حذف کریں' : 'Delete';
  String get continueListening => _isUrdu ? 'سننا جاری رکھیں' : 'Continue Listening';
  String get deleteConversation => _isUrdu ? 'گفتگو حذف کریں؟' : 'Delete Conversation?';
  String get deleteConversationDesc => _isUrdu ? 'یہ اس گفتگو کے تمام کیپشنز کو مستقل طور پر ہٹا دے گا۔' : 'This will permanently remove all captions from this conversation.';

  // ── Professional ──
  String get professionalTitle => _isUrdu ? 'پیشہ ورانہ' : 'Professional';
  String get newSession => _isUrdu ? 'نیا اجلاس' : 'New Session';
  String get sessionsTab => _isUrdu ? 'اجلاس' : 'Sessions';
  String get foldersTab => _isUrdu ? 'فولڈرز' : 'Folders';
  String get classesTab => _isUrdu ? 'کلاسز' : 'Classes';
  String get meetingsTab => _isUrdu ? 'میٹنگز' : 'Meetings';
  String get lecturesTab => _isUrdu ? 'لیکچرز' : 'Lectures';
  String get generalFolder => _isUrdu ? 'عمومی' : 'General';
  String get sessionsCount => _isUrdu ? 'اجلاس' : 'sessions';
  String get noSavedSessions => _isUrdu ? 'ابھی تک کوئی محفوظ شدہ اجلاس نہیں' : 'No saved sessions yet';
  String get noSavedSessionsDesc => _isUrdu ? 'جب آپ تیار ہوں تو لیکچر یا میٹنگ کیپچر کرنے کے لیے پیشہ ورانہ اجلاس شروع کریں۔' : 'Start a Professional session when you are ready to capture a lecture or meeting.';
  String get startSession => _isUrdu ? 'اجلاس شروع کریں' : 'Start Session';
  String get noFoldersYet => _isUrdu ? 'ابھی تک کوئی فولڈر نہیں' : 'No folders yet';
  String get noFoldersDesc => _isUrdu ? 'اپنے اجلاس کو ترتیب دینے کے لیے فولڈر بنائیں۔' : 'Create a folder to organize your sessions.';
  String get createFolder => _isUrdu ? 'فولڈر بنائیں' : 'Create Folder';
  String get noClassSessions => _isUrdu ? 'کوئی کلاس اجلاس نہیں' : 'No class sessions';
  String get noClassSessionsDesc => _isUrdu ? 'اجلاس شروع کریں اور انہیں یہاں دیکھنے کے لیے "کلاس" کی قسم منتخب کریں۔' : 'Start a session and select "Class" as the type to see them here.';
  String get noMeetingSessions => _isUrdu ? 'کوئی میٹنگ اجلاس نہیں' : 'No meeting sessions';
  String get noMeetingSessionsDesc => _isUrdu ? 'اجلاس شروع کریں اور انہیں یہاں دیکھنے کے لیے "میٹنگ" کی قسم منتخب کریں۔' : 'Start a session and select "Meeting" as the type to see them here.';
  String get noLectureSessions => _isUrdu ? 'کوئی لیکچر اجلاس نہیں' : 'No lecture sessions';
  String get noLectureSessionsDesc => _isUrdu ? 'لیکچر کیپچر کرنے کے لیے نیا اجلاس شروع کریں۔' : 'Start a new session to capture a lecture.';
  String get recentLabel => _isUrdu ? 'حالیہ' : 'RECENT';
  String get allSessionsLabel => _isUrdu ? 'تمام اجلاس' : 'ALL SESSIONS';
  String get sessionTitle => _isUrdu ? 'اجلاس کا عنوان' : 'Session Title';
  String get sessionTitleHint => _isUrdu ? 'جیسے پروڈکٹ لانچ منصوبہ' : 'e.g., Product Launch Planning';
  String get sessionType => _isUrdu ? 'اجلاس کی قسم' : 'Session Type';
  String get meetingType => _isUrdu ? 'میٹنگ' : 'Meeting';
  String get lectureType => _isUrdu ? 'لیکچر' : 'Lecture';
  String get classType => _isUrdu ? 'کلاس' : 'Class';
  String get retentionPeriod => _isUrdu ? 'رٹینشن مدت' : 'Retention Period';
  String get folderName => _isUrdu ? 'فولڈر کا نام' : 'Folder name';
  String get deleteSessionConfirm => _isUrdu ? 'اجلاس حذف کریں؟' : 'Delete Session?';
  String get deleteSessionDesc => _isUrdu ? 'یہ محفوظ شدہ ٹرانسکرپٹ اور بصیرت کو مستقل طور پر ہٹا دے گا۔ یہ واپس نہیں کیا جا سکتا۔' : 'This will permanently remove the saved transcript and insights. This cannot be undone.';
  String get deleteFolderConfirm => _isUrdu ? 'فولڈر حذف کریں؟' : 'Delete Folder?';
  String get deleteFolderDesc => _isUrdu ? 'موجودہ اجلاس کو عمومی فولڈر میں منتقل کیا جائے گا۔ یہ واپس نہیں کیا جا سکتا۔' : 'Existing sessions will be moved to the General folder. This cannot be undone.';
  String get create => _isUrdu ? 'بنائیں' : 'Create';

  // ── Session Live ──
  String get liveSession => _isUrdu ? 'لائیو اجلاس' : 'Live Session';
  String get addCaptionManually => _isUrdu ? 'دستی طور پر کیپشن شامل کریں...' : 'Add a caption manually...';
  String get stopSession => _isUrdu ? 'اجلاس بند کریں' : 'Stop Session';

  // ── Session Detail ──
  String get overviewTab => _isUrdu ? 'جائزہ' : 'Overview';
  String get transcriptTab => _isUrdu ? 'ٹرانسکرپٹ' : 'Transcript';
  String get summaryTab => _isUrdu ? 'خلاصہ' : 'Summary';
  String get actionsTab => _isUrdu ? 'اقدامات' : 'Actions';
  String get exportAction => _isUrdu ? 'برآمد' : 'Export';
  String get deleteAction => _isUrdu ? 'حذف' : 'Delete';
  String get aiInsights => _isUrdu ? 'AI بصیرت' : 'AI INSIGHTS';
  String get aiSummary => _isUrdu ? 'AI خلاصہ' : 'AI Summary';
  String get summaryTitle => _isUrdu ? 'خلاصہ' : 'Summary';
  String get actionItems => _isUrdu ? 'عمل کے اقدامات' : 'Action Items';
  String get deadlines => _isUrdu ? 'ڈیڈ لائنز' : 'Deadlines';
  String get peopleMentioned => _isUrdu ? 'ذکر کردہ لوگ' : 'People Mentioned';
  String get noTranscriptAvailable => _isUrdu ? 'کوئی ٹرانسکرپٹ دستیاب نہیں' : 'No transcript available';
  String get noTranscriptDesc => _isUrdu ? 'کوئی ٹرانسکرپٹ کیپچر نہیں کیا گیا۔ ٹرانسکرپٹ کیپچر کرنے کے لیے نیا اجلاس شروع کریں۔' : 'No transcript was captured. You can start a new session to capture a transcript.';
  String get insightsUnavailable => _isUrdu ? 'بصیرت دستیاب نہیں' : 'Insights unavailable';
  String get insightsUnavailableDesc => _isUrdu ? 'ہم اس اجلاس کے لیے AI بصیرت تیار نہیں کر سکے۔ آپ کا اصل ٹرانسکرپٹ ابھی بھی دستیاب ہے۔' : 'We couldn\'t generate AI insights for this session. Your original transcript is still available.';
  String get viewTranscript => _isUrdu ? 'ٹرانسکرپٹ دیکھیں' : 'View Transcript';
  String get noActionItems => _isUrdu ? 'کوئی عمل کے اقدامات نہیں' : 'No action items';
  String get noActionItemsDesc => _isUrdu ? 'AI تجزیے کے بعد عمل کے اقدامات یہاں ظاہر ہوں گے۔' : 'Action items will appear here after AI analysis.';
  String get noItemsAvailable => _isUrdu ? 'کوئی اشیاء دستیاب نہیں' : 'No items available';
  String get exportTxt => _isUrdu ? 'TXT کے طور پر برآمد کریں' : 'Export as TXT';
  String get exportPdf => _isUrdu ? 'PDF کے طور پر برآمد کریں' : 'Export as PDF';
  String get copyClipboard => _isUrdu ? 'کلپ بورڈ پر کاپی کریں' : 'Copy to Clipboard';
  String get txtExportReady => _isUrdu ? 'TXT برآمد تیار ہے' : 'TXT export ready';
  String get pdfExportReady => _isUrdu ? 'PDF برآمد تیار ہے' : 'PDF export ready';
  String get copiedToClipboard => _isUrdu ? 'کلپ بورڈ پر کاپی ہو گیا' : 'Copied to clipboard';
  String get savedRecordsNote => _isUrdu ? 'محفوظ شدہ ریکارڈز کیپشنز اور میٹا ڈیٹا رکھتے ہیں۔ خام آڈیو نہیں رکھا جاتا۔' : 'Saved records contain captions and metadata. Raw audio is not stored.';
  String get exportPrivacyNote => _isUrdu ? 'برآمد شدہ فائلیں HumSukhan کے باہر رکھی جاتی ہیں اور خودکار طور پر حذف نہیں ہوں گی۔' : 'Exported files are stored outside HumSukhan and won\'t be automatically deleted.';

  // ── Environmental ──
  String get environmentalTitle => _isUrdu ? 'ماحولیاتی الرٹس' : 'Environmental Alerts';
  String get monitoringActiveTitle => _isUrdu ? 'نگرانی فعال' : 'Monitoring Active';
  String get monitoringOffTitle => _isUrdu ? 'نگرانی بند' : 'Monitoring Off';
  String get startMonitoring => _isUrdu ? 'نگرانی شروع کریں' : 'Start Monitoring';
  String get stopMonitoring => _isUrdu ? 'نگرانی بند کریں' : 'Stop Monitoring';
  String get demoAlerts => _isUrdu ? 'ڈیمو الرٹس' : 'DEMO ALERTS';
  String get alertHistory => _isUrdu ? 'الرٹ کی تاریخ' : 'ALERT HISTORY';
  String get clearAll => _isUrdu ? 'سب صاف کریں' : 'Clear All';
  String get noAlertsYet => _isUrdu ? 'ابھی تک کوئی الرٹس نہیں' : 'No alerts yet';
  String get noAlertsDesc => _isUrdu ? 'آوازوں کا پتہ لگنے پر الرٹ کی تاریخ یہاں ظاہر ہوگی۔' : 'Alert history will appear here when sounds are detected.';
  String get fireAlarm => _isUrdu ? 'آگ کی الرٹ' : 'Fire Alarm';
  String get smokeAlarm => _isUrdu ? 'دھوئیں کی الرٹ' : 'Smoke Alarm';
  String get siren => _isUrdu ? 'سائرن' : 'Siren';
  String get doorbell => _isUrdu ? 'دروازے کی گھنٹی' : 'Doorbell';
  String get knock => _isUrdu ? 'دستک' : 'Knock';
  String get phone => _isUrdu ? 'فون' : 'Phone';
  String get alarmClock => _isUrdu ? 'الارم گھڑی' : 'Alarm Clock';
  String get babyCry => _isUrdu ? 'بچے کی رو' : 'Baby Cry';
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
  String get languageSection => _isUrdu ? 'زبان' : 'Language';
  String get captionLanguage => _isUrdu ? 'کیپشن کی زبان' : 'Caption Language';
  String get speechRecognition => _isUrdu ? 'بولی کی پہچان' : 'Speech Recognition';
  String get currentMode => _isUrdu ? 'موجودہ موڈ' : 'Current Mode';
  String get englishLabel => _isUrdu ? 'انگریزی' : 'English';
  String get urduLabel => _isUrdu ? 'اردو' : 'Urdu';
  String get downloadLabel => _isUrdu ? 'ڈاؤن لوڈ' : 'Download';
  String get readyLabel => _isUrdu ? 'تیار' : 'Ready';
  String get notDownloaded => _isUrdu ? 'ڈاؤن لوڈ نہیں کیا گیا' : 'Not downloaded';
  String get offlineSttDesc => _isUrdu ? 'آف لائن بولی کی پہچان کے لیے زبان ماڈلز ڈاؤن لوڈ کریں۔ انگریزی ریئل ٹائم اسٹریمنگ کی اجازت دیتی ہے۔ اردو مختصر تاخیر کے ساتھ بیچ پروسیسنگ استعمال کرتی ہے۔' : 'Download language models for offline speech recognition. English supports real-time streaming. Urdu uses batch processing with a short delay.';
  String deleteModelDesc(int sizeMB) => _isUrdu ? 'یہ ${sizeMB}MB اسٹوریج خالی کرے گا۔ آپ اسے بعد میں دوبارہ ڈاؤن لوڈ کر سکتے ہیں۔' : 'This will free up ${sizeMB}MB of storage. You can download it again later.';
  String get defaultRetention => _isUrdu ? 'ڈیفالٹ رٹینشن' : 'Default Retention';
  String get defaultRetentionPeriod => _isUrdu ? 'ڈیفالٹ رٹینشن مدت' : 'Default Retention Period';
  String get privacySection => _isUrdu ? 'رازداری' : 'Privacy';
  String get privacyNoticeText => _isUrdu ? 'HumSukhan آڈیو کو عارضی طور پر پروسیس کرتا ہے اور ریلیز کرتا ہے۔ خام آڈیو کبھی محفوظ نہیں کیا جاتا۔ محفوظ شدہ ریکارڈز صرف کیپشنز اور میٹا ڈیٹا رکھتے ہیں۔ برآمد شدہ فائلیں HumSukhan کے باہر رکھی جاتی ہیں۔' : 'HumSukhan processes audio temporarily and releases it. No raw audio is ever stored. Saved records contain captions and metadata only. Exported files are stored outside HumSukhan.';
  String get aboutSection => _isUrdu ? 'ہمارے بارے میں' : 'About';
  String get fontLabel => _isUrdu ? 'فونٹ' : 'Font';
  String get fontDesc => _isUrdu ? 'ایٹکنسن ہائپرلیجیبل — زیادہ سے زیادہ وضاحت کے لیے ڈیزائن کیا گیا' : 'Atkinson Hyperlegible — Designed for maximum legibility';
  String get maximumAllowed => _isUrdu ? 'زیادہ سے زیادہ اجازت' : 'Maximum allowed';
  String get cancel => _isUrdu ? 'منسوخ' : 'Cancel';
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
  String get removeDownload => _isUrdu ? 'ڈاؤن لوڈ ہٹائیں' : 'Remove download';
  String get offlineModelsInfo => _isUrdu ? 'آف لائن ماڈلز انٹرنیٹ کے بغیر رازداری اور دستیابی بہتر بناتے ہیں۔ جہاں دستیاب ہو، آن لائن اسپیچ ریکگنیشن بھی استعمال کی جا سکتی ہے۔' : 'Offline models improve privacy and availability when you do not have internet access. You can also use online speech recognition when available.';
  String get englishModelTitle => _isUrdu ? 'انگریزی تقریر کی پہچان' : 'English speech recognition';
  String get englishModelDesc => _isUrdu ? 'انٹرنیٹ کنکشن کے بغیر ریئل ٹائم انگریزی کیپشنز کے لیے اختیاری آف لائن ماڈل۔' : 'Optional offline model for real-time English captions without an internet connection.';
  String get urduModelTitle => _isUrdu ? 'اردو تقریر کی پہچان' : 'Urdu speech recognition';
  String get urduModelDesc => _isUrdu ? 'اردو تقریر کی پہچان اور اردو-اسکرپٹ کیپشنز کے لیے اختیاری آف لائن ماڈل۔' : 'Optional offline model for Urdu speech recognition and Urdu-script captions.';

  // ── Listening ──
  String get listeningDots => _isUrdu ? 'سن رہا ہے...\nکیپشنز یہاں ظاہر ہوں گے۔' : 'Listening...\nCaptions will appear here.';
  String get onlineLabel => _isUrdu ? 'آن لائن' : 'Online';
  String get offlineLabel => _isUrdu ? 'آف لائن' : 'Offline';
  String get captionsLabel => _isUrdu ? 'کیپشنز' : 'captions';
  String get durationLabel => _isUrdu ? 'مدت' : 'Duration';
  String get speakerLabel => _isUrdu ? 'بولنے والا' : 'Speaker 1';

  // ── AI Disclaimer ──
  String get aiDisclaimer => _isUrdu ? 'AI سے تیار کردہ — غلطیاں ممکن ہیں' : 'AI-generated — may contain errors';

  // ── Retention ──
  String get daysLeft => _isUrdu ? 'دن باقی' : 'days left';
  String get retention1Day => _isUrdu ? '1 دن' : '1 day';
  String get retention7Days => _isUrdu ? '7 دن' : '7 days';
  String get retention15Days => _isUrdu ? '15 دن (زیادہ سے زیادہ)' : '15 days (maximum)';
  String get retention30Days => _isUrdu ? '30 دن (زیادہ سے زیادہ)' : '30 days (maximum)';

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

  List<(String, String)> get quickReplies => _isUrdu ? quickRepliesUr : quickRepliesEn;
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
