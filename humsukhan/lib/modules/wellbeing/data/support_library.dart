import 'package:flutter/foundation.dart';

import '../services/mood_patterns.dart';

/// Text in both of HumSukhan's languages, so a screen can show either or
/// both at once whatever the app language is.
@immutable
class BilingualText {
  const BilingualText(this.en, this.ur);
  final String en;
  final String ur;

  String of(bool urdu) => urdu ? ur : en;
}

/// One pre-written support item. Fixed text, reviewed before release; no
/// part of it is generated at run time.
@immutable
class SupportItem {
  const SupportItem({required this.id, required this.title, required this.body, required this.steps});

  final String id;
  final BilingualText title;
  final BilingualText body;
  final List<BilingualText> steps;
}

/// The support library and which items each mood state gets.
///
/// The wording is plain and non-clinical: it offers ideas, never a
/// diagnosis or treatment. The urgent state is deliberately absent from
/// [forState]; it gets [SupportLibrary.helpNow] instead.
class SupportLibrary {
  SupportLibrary._();

  static const breathing = SupportItem(
    id: 'breathing',
    title: BilingualText('Slow breathing', 'آہستہ سانس'),
    body: BilingualText(
      'Slow breathing calms the body. It takes about one minute.',
      'آہستہ سانس لینے سے جسم پرسکون ہوتا ہے۔ اس میں تقریباً ایک منٹ لگتا ہے۔',
    ),
    steps: [
      BilingualText('Breathe in through your nose while counting to 4.', 'ناک سے سانس اندر لیں اور 4 تک گنیں۔'),
      BilingualText('Hold for a moment.', 'ایک لمحہ رکیں۔'),
      BilingualText('Breathe out slowly through your mouth while counting to 6.', 'منہ سے آہستہ سانس باہر نکالیں اور 6 تک گنیں۔'),
      BilingualText('Repeat 5 times. You can follow the circle on screen.', 'یہ 5 بار دہرائیں۔ آپ اسکرین پر دائرے کے ساتھ سانس لے سکتے ہیں۔'),
    ],
  );

  /// The 5-4-3-2-1 exercise, with the usual "things you can hear" step
  /// replaced by something every user can do.
  static const grounding = SupportItem(
    id: 'grounding',
    title: BilingualText('Come back to the present', 'اس لمحے میں واپس آئیں'),
    body: BilingualText(
      'When thoughts are racing, noticing what is around you can slow them down.',
      'جب خیالات تیزی سے دوڑ رہے ہوں تو اپنے اردگرد کی چیزوں پر دھیان دینے سے وہ دھیمے ہو جاتے ہیں۔',
    ),
    steps: [
      BilingualText('Look for 5 things you can see.', '5 ایسی چیزیں دیکھیں جو آپ کو نظر آ رہی ہیں۔'),
      BilingualText('Touch 4 things near you.', 'اپنے قریب 4 چیزوں کو چھوئیں۔'),
      BilingualText('Notice 3 things you feel in your body, like your feet on the floor.', 'اپنے جسم میں 3 احساسات محسوس کریں، جیسے فرش پر اپنے پاؤں۔'),
      BilingualText('Notice 2 things you can smell.', '2 چیزیں سونگھیں۔'),
      BilingualText('Notice 1 thing you can taste.', 'کسی 1 چیز کا ذائقہ محسوس کریں۔'),
    ],
  );

  static const communicationBreak = SupportItem(
    id: 'communication_break',
    title: BilingualText('It is okay to take a break', 'وقفہ لینا ٹھیک ہے'),
    body: BilingualText(
      'Lip-reading and following conversations all day is tiring. Feeling worn out is normal, not a weakness.',
      'سارا دن ہونٹ پڑھنا اور گفتگو سمجھنا تھکا دیتا ہے۔ تھکن محسوس کرنا عام بات ہے، کمزوری نہیں۔',
    ),
    steps: [
      BilingualText('Spend 10 minutes somewhere quiet, away from conversations.', '10 منٹ کسی پرسکون جگہ پر، گفتگو سے دور گزاریں۔'),
      BilingualText('Ask people to type or write, or use HumSukhan\'s quick replies.', 'لوگوں سے کہیں کہ وہ لکھ کر بات کریں، یا HumSukhan کے فوری جوابات استعمال کریں۔'),
      BilingualText('Tell one person what makes talking easier for you.', 'کسی ایک شخص کو بتائیں کہ آپ کے لیے بات چیت کیسے آسان ہوتی ہے۔'),
    ],
  );

  static const writeItOut = SupportItem(
    id: 'write_it_out',
    title: BilingualText('Write it down', 'لکھ کر دیکھیں'),
    body: BilingualText(
      'Putting a feeling into words can make it lighter. Your notes stay on this phone.',
      'احساس کو الفاظ میں لکھنے سے دل ہلکا ہو سکتا ہے۔ آپ کے نوٹ صرف اسی فون پر رہتے ہیں۔',
    ),
    steps: [
      BilingualText('Add a note to your next check-in.', 'اپنے اگلے چیک اِن میں نوٹ لکھیں۔'),
      BilingualText('Write what happened and how it felt.', 'لکھیں کہ کیا ہوا اور کیسا محسوس ہوا۔'),
      BilingualText('Write one thing that would help, even a small one.', 'ایک چیز لکھیں جو مدد کر سکتی ہے، چاہے چھوٹی ہی ہو۔'),
    ],
  );

  static const smallStep = SupportItem(
    id: 'small_step',
    title: BilingualText('One small step', 'ایک چھوٹا قدم'),
    body: BilingualText(
      'When everything feels heavy, one small step is enough for now.',
      'جب سب کچھ بھاری لگے تو ابھی کے لیے ایک چھوٹا قدم کافی ہے۔',
    ),
    steps: [
      BilingualText('Drink a glass of water.', 'ایک گلاس پانی پئیں۔'),
      BilingualText('Step outside or open a window for a few minutes.', 'چند منٹ باہر جائیں یا کھڑکی کھولیں۔'),
      BilingualText('Do one small task, like washing your face or tidying one thing.', 'کوئی ایک چھوٹا کام کریں، جیسے منہ دھونا یا ایک چیز ترتیب سے رکھنا۔'),
    ],
  );

  static const talkToSomeone = SupportItem(
    id: 'talk_to_someone',
    title: BilingualText('Share it with someone you trust', 'کسی بھروسے والے سے بات کریں'),
    body: BilingualText(
      'You do not have to carry this alone. A family member, friend, teacher or someone from the Deaf community can help just by being with you.',
      'آپ کو یہ بوجھ اکیلے نہیں اٹھانا۔ گھر کا کوئی فرد، دوست، استاد یا سماعت سے محروم افراد کی برادری میں سے کوئی، صرف آپ کے ساتھ ہو کر بھی مدد کر سکتا ہے۔',
    ),
    steps: [
      BilingualText('Choose one person you feel safe with.', 'کسی ایک ایسے شخص کو چنیں جس کے ساتھ آپ محفوظ محسوس کرتے ہیں۔'),
      BilingualText('Meet them, or reach them in the way that is easiest for you.', 'ان سے ملیں، یا اس طریقے سے رابطہ کریں جو آپ کے لیے سب سے آسان ہو۔'),
      BilingualText('You can say: "I have not been feeling well for a few days. Can we talk?"', 'آپ کہہ سکتے ہیں: "میں کچھ دنوں سے ٹھیک محسوس نہیں کر رہا/رہی۔ کیا ہم بات کر سکتے ہیں؟"'),
    ],
  );

  static const seeAProfessional = SupportItem(
    id: 'see_a_professional',
    title: BilingualText('Consider seeing a doctor', 'ڈاکٹر سے ملنے پر غور کریں'),
    body: BilingualText(
      'If hard days keep coming for two weeks or more, a doctor or counsellor can help. Asking for help is a strong step.',
      'اگر دو ہفتے یا اس سے زیادہ مشکل دن آتے رہیں تو ڈاکٹر یا کونسلر مدد کر سکتے ہیں۔ مدد مانگنا ہمت کی بات ہے۔',
    ),
    steps: [
      BilingualText('Visit a doctor or hospital you trust.', 'کسی ایسے ڈاکٹر یا ہسپتال جائیں جس پر آپ کو بھروسہ ہو۔'),
      BilingualText('Take someone with you, or ask for a sign language interpreter or for things to be written down.', 'کسی کو ساتھ لے جائیں، یا اشاروں کی زبان کے ترجمان یا لکھ کر بات کرنے کی درخواست کریں۔'),
      BilingualText('If you want, show them your check-ins in HumSukhan.', 'اگر آپ چاہیں تو انہیں HumSukhan میں اپنے چیک اِن دکھائیں۔'),
    ],
  );

  static const sleep = SupportItem(
    id: 'sleep',
    title: BilingualText('Rest well tonight', 'آج رات اچھی نیند لیں'),
    body: BilingualText(
      'Sleep has a big effect on mood.',
      'نیند کا موڈ پر بہت اثر ہوتا ہے۔',
    ),
    steps: [
      BilingualText('Put your phone away 30 minutes before sleep.', 'سونے سے 30 منٹ پہلے فون رکھ دیں۔'),
      BilingualText('Go to bed and wake up at the same time each day.', 'ہر روز ایک ہی وقت پر سوئیں اور جاگیں۔'),
      BilingualText('Avoid tea or coffee late in the day.', 'شام کے بعد چائے یا کافی سے پرہیز کریں۔'),
    ],
  );

  static const move = SupportItem(
    id: 'move',
    title: BilingualText('Move a little', 'تھوڑی حرکت کریں'),
    body: BilingualText(
      'A short walk or stretch can lift your energy and mood.',
      'تھوڑی سی چہل قدمی یا جسم کو کھینچنے سے توانائی اور موڈ بہتر ہو سکتا ہے۔',
    ),
    steps: [
      BilingualText('Walk for 10 minutes, inside or outside.', '10 منٹ چلیں، گھر کے اندر یا باہر۔'),
      BilingualText('Slowly stretch your arms, neck and shoulders.', 'آہستہ آہستہ اپنے بازو، گردن اور کندھے کھینچیں۔'),
    ],
  );

  static const noticeWhatHelped = SupportItem(
    id: 'notice_what_helped',
    title: BilingualText('Notice what helped', 'جو اچھا لگا اسے یاد رکھیں'),
    body: BilingualText(
      'You are feeling good. Knowing what helps makes it easier to come back to on harder days.',
      'آپ اچھا محسوس کر رہے ہیں۔ جو چیز مدد کرتی ہے اسے پہچان لینے سے مشکل دنوں میں اس کی طرف لوٹنا آسان ہوتا ہے۔',
    ),
    steps: [
      BilingualText('Think of one thing that made today good.', 'ایک چیز سوچیں جس نے آج کا دن اچھا بنایا۔'),
      BilingualText('Add it as a note to your check-in.', 'اسے اپنے چیک اِن میں نوٹ کے طور پر لکھیں۔'),
      BilingualText('Thank someone who helped you, if you like.', 'اگر چاہیں تو کسی ایسے شخص کا شکریہ ادا کریں جس نے آپ کی مدد کی۔'),
    ],
  );

  static const List<SupportItem> all = [
    breathing,
    grounding,
    communicationBreak,
    writeItOut,
    smallStep,
    talkToSomeone,
    seeAProfessional,
    sleep,
    move,
    noticeWhatHelped,
  ];

  /// The items for [state], most relevant first. Empty for
  /// [MoodState.urgent], which is answered by [helpNow] only.
  static List<SupportItem> forState(MoodState state) => switch (state) {
        MoodState.noData => const [breathing, communicationBreak, move],
        MoodState.doingWell => const [noticeWhatHelped, move],
        MoodState.steady => const [move, communicationBreak, sleep],
        MoodState.lowDay => const [breathing, grounding, communicationBreak, writeItOut],
        MoodState.severalLowDays => const [talkToSomeone, breathing, smallStep, sleep, seeAProfessional],
        MoodState.urgent => const [],
      };

  // ── The fixed help screen ──

  static const helpNowTitle = BilingualText('You are not alone', 'آپ اکیلے نہیں ہیں');
  static const helpNowBody = BilingualText(
    'It sounds like things are very hard right now. You matter, and help can be close.',
    'لگتا ہے اس وقت حالات بہت مشکل ہیں۔ آپ اہم ہیں، اور مدد قریب ہو سکتی ہے۔',
  );
  static const helpNowSteps = [
    BilingualText(
      'If you might hurt yourself, stay near other people and move away from anything you could hurt yourself with.',
      'اگر آپ کو لگتا ہے کہ آپ خود کو نقصان پہنچا سکتے ہیں تو دوسرے لوگوں کے قریب رہیں اور ہر اس چیز سے دور ہو جائیں جس سے نقصان ہو سکتا ہے۔',
    ),
    BilingualText('Show the message below to someone near you.', 'نیچے والا پیغام اپنے قریب کسی شخص کو دکھائیں۔'),
    BilingualText('Breathe slowly with the circle.', 'دائرے کے ساتھ آہستہ سانس لیں۔'),
  ];

  /// Shown full screen, in both languages, for the user to show a person
  /// nearby who may not know sign language.
  static const showSomeone = BilingualText(
    'I am not feeling safe and I need help. Please stay with me. If I am in danger, please call 1122.',
    'میں محفوظ محسوس نہیں کر رہا/رہی اور مجھے مدد چاہیے۔ براہ کرم میرے ساتھ رہیں۔ اگر میں خطرے میں ہوں تو براہ کرم 1122 پر کال کریں۔',
  );
}
