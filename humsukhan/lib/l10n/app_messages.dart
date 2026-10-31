/// Urdu for the messages written outside the widget tree: statuses from
/// providers and errors from services and Supabase. They are produced in
/// English; the screen that shows one asks [AppStrings.message] for it in the
/// app language.
///
/// test/urdu/runtime_messages_test.dart fails when a new message is added
/// without an Urdu entry here.
library;

/// Exact messages.
const urduMessages = <String, String>{
  // Everyday conversation status.
  'Ready — tap the microphone to speak': 'تیار — بولنے کے لیے مائیکروفون دبائیں',
  'Starting microphone…': 'مائیکروفون شروع ہو رہا ہے…',
  'Listening — waiting for speech': 'سن رہا ہے — آواز کا انتظار ہے',
  'Listening — speaker talking': 'سن رہا ہے — بولنے والا بات کر رہا ہے',
  'Pause detected — speak again to continue': 'وقفہ محسوس ہوا — جاری رکھنے کے لیے دوبارہ بولیں',
  'Finishing the sentence…': 'جملہ مکمل ہو رہا ہے…',
  'Speaking…': 'بولا جا رہا ہے…',
  'Speech error': 'آواز کی پہچان میں خرابی',
  'Live speech recognition could not be started.': 'براہِ راست آواز کی پہچان شروع نہیں ہو سکی۔',
  'Live speech recognition stopped.': 'براہِ راست آواز کی پہچان رک گئی۔',
  'Speech turn could not be finalized.': 'یہ بات مکمل کیپشن نہیں بن سکی۔',
  'Speech control failed.': 'مائیکروفون قابو میں نہیں آ سکا۔ دوبارہ کوشش کریں۔',
  'Not listening': 'نہیں سن رہا',
  'Tap the microphone to speak': 'بولنے کے لیے مائیکروفون دبائیں',
  'Stopping...': 'روکا جا رہا ہے…',
  'Stopped': 'رک گیا',
  'Listening…': 'سن رہا ہے…',
  'Your turn — respond below': 'آپ کی باری — نیچے جواب دیں',
  'Tap the microphone to speak again': 'دوبارہ بولنے کے لیے مائیکروفون دبائیں',

  // Professional live session status.
  'Preparing microphone…': 'مائیکروفون تیار ہو رہا ہے…',
  'This session could not be opened because it no longer exists.': 'یہ اجلاس نہیں کھل سکا کیونکہ یہ اب موجود نہیں۔',
  'Session unavailable': 'اجلاس دستیاب نہیں',
  'Ready — tap microphone to listen': 'تیار — سننے کے لیے مائیکروفون دبائیں',
  'Microphone unavailable': 'مائیکروفون دستیاب نہیں',
  'Listening… tap microphone to stop': 'سن رہا ہے… روکنے کے لیے مائیکروفون دبائیں',
  'Microphone could not be started': 'مائیکروفون شروع نہیں ہو سکا',
  'Speech recognition did not start. The selected language may be unavailable on this device, or microphone access may be blocked.':
      'آواز کی پہچان شروع نہیں ہوئی۔ ممکن ہے منتخب زبان اس فون پر دستیاب نہ ہو، یا مائیکروفون کی اجازت بند ہو۔',
  'Could not start listening': 'سننا شروع نہیں ہو سکا',
  'Finalizing this caption…': 'یہ کیپشن مکمل ہو رہا ہے…',
  'Microphone off — session still active': 'مائیکروفون بند — اجلاس جاری ہے',

  // Connection.
  'Online': 'آن لائن',
  'Offline': 'آف لائن',
  'Checking...': 'جانچ ہو رہی ہے…',

  // How speech is being recognized.
  'Offline (Streaming)': 'آف لائن (براہِ راست)',
  'Offline (Batch)': 'آف لائن (جملہ وار)',
  'Device recognizer': 'فون کی اپنی آواز پہچان',
  'Cloud (backup)': 'کلاؤڈ (متبادل)',
  'Unavailable': 'دستیاب نہیں',
  'Real-time offline speech recognition using Sherpa-ONNX. No internet required.':
      'فون پر ہی براہِ راست آواز کی پہچان۔ انٹرنیٹ کی ضرورت نہیں۔',
  'Offline speech recognition using Sherpa-ONNX. Short processing delay.':
      'فون پر ہی آواز کی پہچان۔ ہر جملے کے بعد تھوڑی دیر لگتی ہے۔',
  'Using cloud or offline fallback because Urdu is not installed in the device speech recognizer.':
      'فون کی آواز پہچان میں اردو انسٹال نہیں، اس لیے کلاؤڈ یا آف لائن متبادل استعمال ہو رہا ہے۔',
  'Using the speech recognizer installed on this device.': 'اس فون میں انسٹال آواز پہچان استعمال ہو رہی ہے۔',
  'Online bilingual speech recognition.': 'آن لائن دو لسانی آواز کی پہچان۔',
  'This device has no speech recognizer for the language, so speech is recognized in the cloud after each pause.':
      'اس فون میں اس زبان کی آواز پہچان نہیں، اس لیے ہر وقفے کے بعد آواز کلاؤڈ میں پہچانی جاتی ہے۔',
  'Speech recognition unavailable.': 'آواز کی پہچان دستیاب نہیں۔',

  // Why listening could not start.
  'Environmental monitoring could not release the microphone for speech recognition.':
      'ماحولیاتی نگرانی نے آواز کی پہچان کے لیے مائیکروفون نہیں چھوڑا۔ دوبارہ کوشش کریں۔',
  'Authenticated Supabase session is unavailable.': 'سائن اِن ختم ہو گیا ہے۔ دوبارہ سائن اِن کریں۔',
  'Authenticated Supabase session is unavailable': 'سائن اِن ختم ہو گیا ہے۔ دوبارہ سائن اِن کریں۔',
  'Deepgram token service returned an invalid response.': 'آواز کی پہچان کی سروس سے درست جواب نہیں ملا۔ دوبارہ کوشش کریں۔',
  'Deepgram token service returned no access token.': 'آواز کی پہچان کی سروس سے درست جواب نہیں ملا۔ دوبارہ کوشش کریں۔',
  'Microphone permission is blocked in Android settings.': 'اینڈرائیڈ کی ترتیبات میں مائیکروفون کی اجازت بند ہے۔',
  'Microphone permission was not granted.': 'مائیکروفون کی اجازت نہیں دی گئی۔',
  'The microphone is not available to the speech recorder.': 'مائیکروفون ریکارڈنگ کے لیے دستیاب نہیں۔',
  'The microphone is sending silence, so nothing can be captioned. Another app or feature may be using it.':
      'مائیکروفون سے کوئی آواز نہیں آ رہی، اس لیے کیپشن نہیں بن سکتے۔ ممکن ہے کوئی دوسری ایپ یا فیچر اسے استعمال کر رہا ہو۔',
  'The cloud recognizer is not returning captions.': 'کلاؤڈ آواز پہچان سے کیپشن نہیں آ رہے۔',
  'Live speech recognition could not start.': 'براہِ راست آواز کی پہچان شروع نہیں ہو سکی۔',
  'Sign in to use cloud speech recognition.': 'کلاؤڈ آواز پہچان کے لیے سائن اِن کریں۔',
  'Urdu is not installed for the device speech recognizer.': 'فون کی آواز پہچان میں اردو انسٹال نہیں۔',
  'English is not installed for the device speech recognizer.': 'فون کی آواز پہچان میں انگریزی انسٹال نہیں۔',
  'The device speech recognizer did not start.': 'فون کی آواز پہچان شروع نہیں ہوئی۔',

  // AI summaries.
  'This session has no transcript yet, so there is nothing to summarize.':
      'اس اجلاس کا ابھی کوئی ٹرانسکرپٹ نہیں، اس لیے خلاصہ بنانے کو کچھ نہیں۔',
  'AI summaries need a signed-in connection to the HumSukhan service. Reconnect, then try again.':
      'AI خلاصے کے لیے HumSukhan سروس سے سائن اِن کنکشن ضروری ہے۔ دوبارہ جڑیں، پھر کوشش کریں۔',
  'The AI summary could not be generated for this session. Check your connection and try again.':
      'اس اجلاس کا AI خلاصہ نہیں بن سکا۔ کنکشن چیک کر کے دوبارہ کوشش کریں۔',
  'The AI returned no usable summary for this session.': 'AI سے اس اجلاس کا قابلِ استعمال خلاصہ نہیں ملا۔',

  // Accounts: checks in the app.
  'Please enter your email address.': 'براہِ کرم اپنا ای میل لکھیں۔',
  'Please enter a valid email address.': 'براہِ کرم درست ای میل لکھیں۔',
  'Password must contain uppercase, lowercase, number, and special character.':
      'پاس ورڈ میں بڑا اور چھوٹا حرف، نمبر اور خاص علامت ہونا ضروری ہے۔',
  'Please enter your password.': 'براہِ کرم پاس ورڈ لکھیں۔',
  'Please enter your name.': 'براہِ کرم اپنا نام لکھیں۔',
  'Passwords do not match.': 'دونوں پاس ورڈ ایک جیسے نہیں۔',
  'Account creation failed. Please try again.': 'اکاؤنٹ نہیں بن سکا۔ دوبارہ کوشش کریں۔',
  'Account creation failed. Check your connection and try again.': 'اکاؤنٹ نہیں بن سکا۔ کنکشن چیک کر کے دوبارہ کوشش کریں۔',
  'Account was created, but sign in could not be completed. Please try again.':
      'اکاؤنٹ بن گیا، لیکن سائن اِن مکمل نہیں ہو سکا۔ دوبارہ سائن اِن کریں۔',
  'Authentication unavailable. Please check your connection and try again.':
      'سائن اِن کی سروس دستیاب نہیں۔ کنکشن چیک کر کے دوبارہ کوشش کریں۔',
  'Authentication failed. Please try again.': 'سائن اِن نہیں ہو سکا۔ دوبارہ کوشش کریں۔',
  'Sign in failed: no active session was returned.': 'سائن اِن نہیں ہو سکا۔ دوبارہ کوشش کریں۔',
  'Sign in failed. Check your connection and try again.': 'سائن اِن نہیں ہو سکا۔ کنکشن چیک کر کے دوبارہ کوشش کریں۔',
  'Unable to send the reset email. Check your connection and try again.':
      'ری سیٹ کا ای میل نہیں بھیجا جا سکا۔ کنکشن چیک کر کے دوبارہ کوشش کریں۔',
  'Password updated, but your session is unavailable.': 'پاس ورڈ بدل گیا، لیکن آپ کا سائن اِن برقرار نہیں رہا۔ دوبارہ سائن اِن کریں۔',
  'Unable to update your password. Check your connection and try again.':
      'پاس ورڈ نہیں بدلا جا سکا۔ کنکشن چیک کر کے دوبارہ کوشش کریں۔',
  'Unable to update your password.': 'پاس ورڈ نہیں بدلا جا سکا۔',

  // Accounts: answers from the account service.
  'Email and password are required.': 'ای میل اور پاس ورڈ دونوں ضروری ہیں۔',
  'Password must be 8 to 72 characters and contain uppercase, lowercase, number, and special character.':
      'پاس ورڈ 8 سے 72 حروف کا ہو اور اس میں بڑا اور چھوٹا حرف، نمبر اور خاص علامت ہو۔',
  'Please choose a stronger password.': 'براہِ کرم زیادہ مضبوط پاس ورڈ چنیں۔',
  'An account with this email already exists. Please sign in or reset your password.':
      'اس ای میل سے اکاؤنٹ پہلے سے موجود ہے۔ سائن اِن کریں یا پاس ورڈ ری سیٹ کریں۔',
  'Too many new accounts right now. Please try again later.': 'اس وقت بہت سے نئے اکاؤنٹ بن رہے ہیں۔ کچھ دیر بعد دوبارہ کوشش کریں۔',
  'Account service is busy. Please try again shortly.': 'اکاؤنٹ سروس مصروف ہے۔ تھوڑی دیر بعد دوبارہ کوشش کریں۔',
  'Account service is not configured.': 'اکاؤنٹ سروس دستیاب نہیں۔',
  'Account creation failed.': 'اکاؤنٹ نہیں بن سکا۔',

  // Accounts: Supabase Auth.
  'Invalid login credentials': 'ای میل یا پاس ورڈ درست نہیں۔',
  'Email not confirmed': 'آپ کے ای میل کی تصدیق نہیں ہوئی۔',
  'User already registered': 'اس ای میل سے اکاؤنٹ پہلے سے موجود ہے۔',
  'New password should be different from the old password.': 'نیا پاس ورڈ پرانے پاس ورڈ سے مختلف ہونا چاہیے۔',
  'Email rate limit exceeded': 'بہت زیادہ ای میل بھیجے گئے۔ کچھ دیر بعد دوبارہ کوشش کریں۔',
  'Token has expired or is invalid': 'یہ لنک پرانا یا غلط ہے۔ نیا لنک منگوائیں۔',
};

/// Messages that carry a value, such as a language or a number of seconds.
final urduMessagePatterns = <(RegExp, String Function(Match))>[
  (
    RegExp(r'^Password must be (\d+) to (\d+) characters\.$'),
    (m) => 'پاس ورڈ ${m[1]} سے ${m[2]} حروف کا ہونا چاہیے۔',
  ),
  (
    RegExp(r'^No internet connection, and no offline speech model is downloaded for (.+?)\.'),
    (m) => 'انٹرنیٹ کنکشن نہیں اور ${urduLanguageName(m[1]!)} کا آف لائن ماڈل ڈاؤن لوڈ نہیں۔ کنکشن کے بغیر کیپشن کے لیے ترتیبات سے ماڈل ڈاؤن لوڈ کریں۔',
  ),
  (
    RegExp(r'^No offline speech model is downloaded for (.+?)\.$'),
    (m) => '${urduLanguageName(m[1]!)} کا آف لائن ماڈل ڈاؤن لوڈ نہیں۔',
  ),
  (
    RegExp(r'^The offline (.+?) model could not be started\.$'),
    (m) => '${urduLanguageName(m[1]!)} کا آف لائن ماڈل شروع نہیں ہو سکا۔',
  ),
  (
    RegExp(r'^No installed device recognizer locale for (.+?)\.$'),
    (m) => 'فون کی آواز پہچان میں ${urduLanguageName(m[1]!)} انسٹال نہیں۔',
  ),
  (
    RegExp(r'^Name must be at most (\d+) characters\.$'),
    (m) => 'نام زیادہ سے زیادہ ${m[1]} حروف کا ہو سکتا ہے۔',
  ),
  (
    RegExp(r'^Speech recognition lost its .+ connection'),
    (_) => 'آواز کی پہچان کا کنکشن ٹوٹ گیا اور دوبارہ نہیں جڑ سکا۔ انٹرنیٹ چیک کریں، پھر دوبارہ سننا شروع کریں۔',
  ),
  (
    RegExp(
      r'^(Speech services could not initialize|Unable to initialize speech recognition|Speech recognition could not start|'
      r'Speech recognition connection failed|Android microphone stream failed|Failed to start microphone stream)\b',
    ),
    (_) => 'آواز کی پہچان شروع نہیں ہو سکی۔ دوبارہ کوشش کریں۔',
  ),
  (
    RegExp(r'^(Speech setup failed|Speech recognition failed|Stopping speech recognition failed|Speech recognition stopped):'),
    (_) => 'آواز کی پہچان میں خرابی آئی۔ دوبارہ کوشش کریں۔',
  ),
  (
    RegExp(r'^Could not save this caption:'),
    (_) => 'یہ کیپشن محفوظ نہیں ہو سکا۔ دوبارہ کوشش کریں۔',
  ),
  (
    RegExp(r'^For security purposes, you can only request this after (\d+) seconds'),
    (m) => 'حفاظت کی خاطر ${m[1]} سیکنڈ بعد دوبارہ کوشش کریں۔',
  ),
  (
    RegExp(r'^Password should be at least (\d+) characters'),
    (m) => 'پاس ورڈ کم از کم ${m[1]} حروف کا ہونا چاہیے۔',
  ),
];

/// A language as the app names it internally ('English', 'Urdu', 'Auto'),
/// in Urdu.
String urduLanguageName(String language) => switch (language.trim().toLowerCase()) {
      'english' => 'انگریزی',
      'urdu' => 'اردو',
      'roman urdu' => 'رومن اردو',
      'auto' => 'خودکار',
      _ => language,
    };

/// Shown in Urdu for a message that has no translation, so English never
/// appears in the Urdu interface.
const urduGeneralError = 'کچھ غلط ہو گیا۔ دوبارہ کوشش کریں۔';

/// [message] in Urdu, or null when there is no translation for it.
String? urduMessage(String message) {
  final text = message.trim();
  final exact = urduMessages[text];
  if (exact != null) return exact;
  for (final (pattern, urdu) in urduMessagePatterns) {
    final match = pattern.firstMatch(text);
    if (match != null) return urdu(match);
  }
  return null;
}
