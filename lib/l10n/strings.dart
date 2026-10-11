import 'package:flutter/widgets.dart';

/// All user-visible text in English and Bangla.
///
/// Usage: `final s = S.of(context); Text(s.addTuition)`.
class S {
  const S(this.bn);

  final bool bn;

  /// Reads the app locale (set from Settings), so it works both in build
  /// methods and in button callbacks.
  static S of(BuildContext context) =>
      S(Localizations.localeOf(context).languageCode == 'bn');

  String _t(String en, String bangla) => bn ? bangla : en;

  static const _bnDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

  /// Shows any number (or text containing digits) with Bangla digits
  /// (১২৩) when the app is in Bangla.
  String n(Object value) {
    final text = value is double
        ? (value == value.roundToDouble() ? value.round().toString() : value.toStringAsFixed(1))
        : value.toString();
    if (!bn) return text;
    return text.replaceAllMapped(RegExp('[0-9]'), (m) => _bnDigits[int.parse(m[0]!)]);
  }

  /// Taka amount with thousands separators, e.g. ৳12,500 / ৳১২,৫০০.
  String money(num amount) {
    final whole = amount.round().abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
      buf.write(whole[i]);
    }
    return '${amount < 0 ? '-' : ''}৳${n(buf.toString())}';
  }

  // Navigation
  String get tuitions => _t('Tuitions', 'টিউশন');
  String get routine => _t('Routine', 'রুটিন');
  String get settings => _t('Settings', 'সেটিংস');
  String get appTitle => _t('Tuition Tracker', 'টিউশন ট্র্যাকার');

  // Home / list
  String get currentTuitions => _t('Current tuitions', 'চলমান টিউশন');
  String get addTuition => _t('Add tuition', 'টিউশন যোগ করুন');
  String get noTuitionsTitle => _t('No tuitions yet', 'এখনো কোনো টিউশন নেই');
  String get noTuitionsBody => _t(
      'Tap "Add tuition" to add your first student.',
      'প্রথম ছাত্র/ছাত্রী যোগ করতে "টিউশন যোগ করুন" চাপুন।');
  String get searchHint => _t('Search by name or area', 'নাম বা এলাকা দিয়ে খুঁজুন');
  String get listView => _t('List view', 'তালিকা');
  String get gridView => _t('Grid view', 'গ্রিড');
  String get pastTuitions => _t('Past tuitions', 'পুরনো টিউশন');
  String daysSincePayment(int n) =>
      _t('$n ${n == 1 ? 'day' : 'days'} since payment', 'পেমেন্টের পর ${this.n(n)} দিন');
  String get daysShort => _t('days', 'দিন');
  String get sincePaymentShort => _t('since payment', 'পেমেন্টের পর');
  String classAdded(String name) => _t('Class added for $name', '$name-এর একটি ক্লাস যোগ হয়েছে');
  String get undo => _t('Undo', 'ফিরিয়ে নিন');
  String get noLocation => _t('No location set', 'লোকেশন দেওয়া নেই');
  String get noPhone => _t('No phone number saved', 'কোনো ফোন নম্বর নেই');
  String get call => _t('Call', 'কল');
  String get directions => _t('Directions', 'রাস্তা');
  String get addClass => _t('Add a class taught', 'একটি ক্লাস যোগ করুন');
  String get more => _t('More', 'আরও');

  // Form
  String get editTuition => _t('Edit tuition', 'টিউশন এডিট করুন');
  String get studentName => _t('Student name', 'ছাত্র/ছাত্রীর নাম');
  String get nameRequired => _t('Please enter a name', 'নাম লিখুন');
  String get classLabel => _t('Class', 'শ্রেণি');
  String get subjectsLabel => _t('Subjects', 'বিষয়');
  String get address => _t('Address', 'ঠিকানা');
  String get pickOnMap => _t('Pick on map', 'ম্যাপে বেছে নিন');
  String get locationPicked => _t('Location saved on map', 'ম্যাপে লোকেশন সেভ হয়েছে');
  String get contacts => _t('Contacts', 'যোগাযোগ');
  String get studentPhone => _t('Student phone', 'ছাত্র/ছাত্রীর ফোন');
  String get whatsapp => _t('WhatsApp', 'হোয়াটসঅ্যাপ');
  String get fatherPhone => _t('Father\'s phone', 'বাবার ফোন');
  String get motherPhone => _t('Mother\'s phone', 'মায়ের ফোন');
  String get defaultCallNumber => _t('Call button dials', 'কল বাটনে যে নম্বরে কল যাবে');
  String get feeSection => _t('Fee', 'বেতন');
  String get monthlyFee => _t('Fee per month (৳)', 'মাসিক বেতন (৳)');
  String get daysPerCycle => _t('Classes per month', 'মাসে ক্লাস সংখ্যা');
  String get optional => _t('Optional', 'ঐচ্ছিক');
  String get save => _t('Save', 'সেভ করুন');
  String get cancel => _t('Cancel', 'বাতিল');
  String get delete => _t('Delete', 'মুছে ফেলুন');
  String get invalidNumber => _t('Enter a valid number', 'সঠিক সংখ্যা লিখুন');
  String get weeklySchedule => _t('Weekly schedule', 'সাপ্তাহিক সময়সূচি');
  String get addSlot => _t('Add a day & time', 'দিন ও সময় যোগ করুন');
  String get scheduleHelp => _t(
      'Days and times you usually teach. Used to plan your routine.',
      'যেসব দিনে ও সময়ে সাধারণত পড়ান। রুটিন বানাতে কাজে লাগবে।');

  // Map picker
  String get chooseLocation => _t('Choose location', 'লোকেশন বেছে নিন');
  String get searchAddress => _t('Search address or area', 'ঠিকানা বা এলাকা খুঁজুন');
  String get noResults => _t('No places found', 'কোনো জায়গা পাওয়া যায়নি');
  String get moveMapHint => _t('Move the map to put the pin on the house', 'ম্যাপ সরিয়ে পিনটি বাসার উপর রাখুন');
  String get useThisLocation => _t('Use this location', 'এই লোকেশন নিন');
  String get myLocation => _t('My location', 'আমার লোকেশন');
  String get locationDenied => _t('Location permission is off', 'লোকেশনের অনুমতি বন্ধ আছে');

  // Detail
  String get details => _t('Details', 'বিস্তারিত');
  String get showDetails => _t('More details', 'আরও বিস্তারিত');
  String get hideDetails => _t('Hide details', 'বিস্তারিত লুকান');
  String get edit => _t('Edit', 'এডিট');
  String get calendar => _t('Classes calendar', 'ক্লাসের ক্যালেন্ডার');
  String classesThisMonth(int n) => _t('$n classes this month', 'এই মাসে ${this.n(n)} টি ক্লাস');
  String get payments => _t('Payments', 'পেমেন্ট');
  String get recordPayment => _t('Record payment', 'পেমেন্ট যোগ করুন');
  String get amount => _t('Amount (৳)', 'টাকার পরিমাণ (৳)');
  String get date => _t('Date', 'তারিখ');
  String get note => _t('Note', 'নোট');
  String get noPayments => _t('No payments yet', 'এখনো কোনো পেমেন্ট নেই');
  String get totalClasses => _t('Total classes', 'মোট ক্লাস');
  String get totalReceived => _t('Total received', 'মোট পেয়েছেন');
  String get sinceLastPayment => _t('Since last payment', 'শেষ পেমেন্টের পর');
  String get lastPayment => _t('Last payment', 'শেষ পেমেন্ট');
  String get never => _t('Never', 'কখনো না');
  String get dueEstimate => _t('Due (estimate)', 'বাকি (আনুমানিক)');
  String get archive => _t('Move to past tuitions', 'পুরনো টিউশনে সরান');
  String get unarchive => _t('Move back to current', 'আবার চলমানে আনুন');
  String get deleteConfirmTitle => _t('Delete this tuition?', 'এই টিউশন মুছে ফেলবেন?');
  String get deleteConfirmBody => _t(
      'All classes, payments and notes for this student will be deleted.',
      'এই ছাত্র/ছাত্রীর সব ক্লাস, পেমেন্ট ও নোট মুছে যাবে।');
  String get editPayment => _t('Edit payment', 'পেমেন্ট এডিট করুন');
  String get editNote => _t('Edit note', 'নোট এডিট করুন');
  String get batch => _t('Batch / group', 'ব্যাচ / গ্রুপ');
  String get batchHelp => _t('For coaching: students with the same batch are grouped', 'কোচিংয়ের জন্য: একই ব্যাচের ছাত্র/ছাত্রীরা একসাথে থাকবে');
  String get all => _t('All', 'সব');
  String batchStudents(int c) => _t('$c students', '${n(c)} জন');
  String get classForAll => _t('Add class for all', 'সবার ক্লাস যোগ');
  String classAddedForBatch(int c) => _t('Class added for $c students', '${n(c)} জনের ক্লাস যোগ হয়েছে');
  String get batchPayments => _t('Record payments', 'পেমেন্ট যোগ করুন');
  String paymentsSaved(int c) => _t('$c payments saved', '${n(c)} টি পেমেন্ট সেভ হয়েছে');
  String get addSeveral => _t('Add several students', 'একসাথে কয়েকজন যোগ');
  String get namesOnePerLine => _t('Names (one per line)', 'নাম (প্রতি লাইনে একটি)');
  String get sharedDetails => _t('Shared by all of them', 'সবার জন্য একই');
  String studentsAdded(int c) => _t('$c students added', '${n(c)} জন যোগ হয়েছে');
  String get incomeSummary => _t('Income summary', 'আয়ের হিসাব');
  String get receivedThisMonth => _t('Received this month', 'এই মাসে পেয়েছেন');
  String get classesTaught => _t('Classes taught', 'ক্লাস নেওয়া হয়েছে');
  String get expectedMonthly => _t('Monthly fees (all tuitions)', 'মাসিক বেতন (সব টিউশন)');
  String get byStudent => _t('By student', 'ছাত্র/ছাত্রী অনুযায়ী');
  String get lastSixMonths => _t('Last 6 months', 'গত ৬ মাস');
  String get noIncome => _t('No payments this month', 'এই মাসে কোনো পেমেন্ট নেই');
  String get allTime => _t('All time', 'সব সময়');
  String get openWhatsapp => _t('Open WhatsApp', 'হোয়াটসঅ্যাপ খুলুন');

  // Day sheet
  String classesOnDay(int n) => _t('$n ${n == 1 ? 'class' : 'classes'} taught', '${this.n(n)} টি ক্লাস নেওয়া হয়েছে');
  String get notTaught => _t('No class this day', 'এই দিনে ক্লাস হয়নি');
  String get markTaught => _t('Add class', 'ক্লাস যোগ');
  String get removeClass => _t('Remove class', 'ক্লাস বাদ');
  String get homework => _t('Notes & homework', 'নোট ও হোমওয়ার্ক');
  String get addNote => _t('Add note / homework', 'নোট / হোমওয়ার্ক যোগ করুন');
  String get noNotes => _t('No notes for this day', 'এই দিনের কোনো নোট নেই');
  String previousHomework(String date) => _t('Previous homework ($date)', 'আগের হোমওয়ার্ক ($date)');
  String get writeNote => _t('Write a note or homework', 'নোট বা হোমওয়ার্ক লিখুন');
  String get camera => _t('Camera', 'ক্যামেরা');
  String get gallery => _t('Gallery', 'গ্যালারি');

  // Trip sheet
  String get tripTitle => _t('Trip to student', 'ছাত্র/ছাত্রীর বাসায় যাওয়া');
  String get distance => _t('Distance', 'দূরত্ব');
  String get travelTime => _t('Travel time', 'যেতে সময়');
  String get bikeFare => _t('Bike fare (estimate)', 'বাইক ভাড়া (আনুমানিক)');
  String get liveTraffic => _t('Based on live traffic', 'লাইভ ট্রাফিক অনুযায়ী');
  String get roughEstimate => _t(
      'Rough estimate from straight-line distance',
      'সরল দূরত্ব থেকে মোটামুটি হিসাব');
  String get openMaps => _t('Directions in Google Maps', 'গুগল ম্যাপে রাস্তা দেখুন');
  String get openPathao => _t('Open Pathao', 'পাঠাও খুলুন');
  String get openUber => _t('Open Uber', 'উবার খুলুন');
  String get fareNote => _t(
      'Real price is shown in the ride app. Adjust estimate rates in Settings.',
      'আসল ভাড়া রাইড অ্যাপে দেখাবে। আনুমানিক হিসাবের রেট সেটিংসে বদলাতে পারবেন।');
  String get findingLocation => _t('Finding your location…', 'আপনার লোকেশন খোঁজা হচ্ছে…');

  // Routine
  String get routineEmptyTitle => _t('No routine yet', 'এখনো কোনো রুটিন নেই');
  String get routineEmptyBody => _t(
      'Add weekly days & times to your students (Edit → Weekly schedule), or keep pressing "+" after classes and the app will learn your routine.',
      'ছাত্র/ছাত্রীদের সাপ্তাহিক দিন ও সময় যোগ করুন (এডিট → সাপ্তাহিক সময়সূচি), অথবা ক্লাসের পর "+" চাপতে থাকুন — অ্যাপ নিজেই রুটিন শিখে নেবে।');
  String get startLocation => _t('Start from', 'যেখান থেকে শুরু');
  String get setHome => _t('Set home location', 'বাসার লোকেশন দিন');
  String get changeHome => _t('Change', 'বদলান');
  String get homeHelp => _t(
      'Set where you start (home) to include the first and last trip.',
      'প্রথম ও শেষ যাত্রা হিসাবে আনতে কোথা থেকে শুরু করেন (বাসা) তা দিন।');
  String get flexibility => _t('Classes can move by', 'ক্লাসের সময় সরানো যাবে');
  String minutesShort(int m) => _t('±$m min', '±${n(m)} মিনিট');
  String get fixedTimes => _t('Fixed', 'নির্দিষ্ট');
  String get weekTotal => _t('This week', 'এই সপ্তাহে');
  String classesCount(int c) => _t('$c classes', '${n(c)} টি ক্লাস');
  String travelTotal(double mins) => _t('${mins.round()} min travel', '${n(mins.round())} মিনিট যাতায়াত');
  String minutes(double m) => _t('${m.round()} min', '${n(m.round())} মিনিট');
  String km(double k) => '${n(k.toStringAsFixed(1))} ${_t('km', 'কিমি')}';
  String savesMinutes(double m) => _t(
      'Saves ${m.round()} min vs your usual order',
      'সাধারণ ক্রমের চেয়ে ${n(m.round())} মিনিট বাঁচবে');
  String get clashWarning => _t(
      'Not enough time to travel here — class starts late',
      'এখানে যাওয়ার মতো সময় নেই — ক্লাস দেরিতে শুরু হবে');
  String movedFrom(String time) => _t('usually $time', 'সাধারণত $time');
  String get learnedFromHistory => _t('learned from past classes', 'আগের ক্লাস থেকে শেখা');
  String get backHome => _t('Back home', 'বাসায় ফেরা');
  String get openRoute => _t('Open day\'s route in Maps', 'দিনের পুরো রাস্তা ম্যাপে দেখুন');
  String get planning => _t('Planning your week…', 'আপনার সপ্তাহ সাজানো হচ্ছে…');
  String get liveTimes => _t('Travel times from live traffic', 'যাতায়াতের সময় লাইভ ট্রাফিক থেকে');
  String get roughTimes => _t('Travel times are rough estimates', 'যাতায়াতের সময় আনুমানিক');
  String get aiPlan => _t('AI weekly plan & tips', 'এআই সাপ্তাহিক পরিকল্পনা ও পরামর্শ');
  String get askAi => _t('Ask AI', 'এআই-কে জিজ্ঞেস করুন');
  String get askAiAgain => _t('Ask again', 'আবার জিজ্ঞেস করুন');
  String get aiThinking => _t('AI is thinking…', 'এআই ভাবছে…');
  String get aiNotSetUp => _t(
      'AI is not set up. Add a free AI key in Settings → AI.',
      'এআই চালু নেই। সেটিংস → এআই-তে একটি ফ্রি এআই কি দিন।');
  String get aiFailed => _t('AI could not answer. Check your internet or key.', 'এআই উত্তর দিতে পারেনি। ইন্টারনেট বা কি চেক করুন।');
  String get aiPrivacy => _t(
      'Sends first names, areas and times (no phone numbers) to the AI service.',
      'এআই সার্ভিসে প্রথম নাম, এলাকা ও সময় পাঠানো হয় (ফোন নম্বর নয়)।');

  // Settings
  String get appearance => _t('Appearance', 'চেহারা');
  String get theme => _t('Theme', 'থিম');
  String get themeSystem => _t('System', 'সিস্টেম');
  String get themeLight => _t('Light', 'লাইট');
  String get themeDark => _t('Dark', 'ডার্ক');
  String get language => _t('Language', 'ভাষা');
  String get fareRates => _t('Bike fare estimate', 'বাইক ভাড়ার হিসাব');
  String get baseFare => _t('Base fare (৳)', 'বেস ভাড়া (৳)');
  String get perKm => _t('Per km (৳)', 'প্রতি কিমি (৳)');
  String get perMinute => _t('Per minute (৳)', 'প্রতি মিনিট (৳)');
  String get minimumFare => _t('Minimum fare (৳)', 'সর্বনিম্ন ভাড়া (৳)');
  String get backup => _t('Google Drive backup', 'গুগল ড্রাইভ ব্যাকআপ');
  String get backupHelp => _t(
      'Your data stays on this phone. A copy is saved in a hidden folder on your Google Drive, so you can get it back after reinstalling or on a new phone.',
      'আপনার ডেটা এই ফোনেই থাকে। একটি কপি আপনার গুগল ড্রাইভের গোপন ফোল্ডারে সেভ হয়, তাই অ্যাপ আবার ইনস্টল করলে বা নতুন ফোনে ফিরে পাবেন।');
  String get signInGoogle => _t('Sign in with Google', 'গুগল দিয়ে সাইন ইন');
  String get signOut => _t('Sign out', 'সাইন আউট');
  String get backupNow => _t('Back up now', 'এখনই ব্যাকআপ');
  String get restoreBackup => _t('Restore from Drive', 'ড্রাইভ থেকে ফিরিয়ে আনুন');
  String lastBackupAt(String when) => _t('Last backup: $when', 'শেষ ব্যাকআপ: $when');
  String get noBackupYet => _t('Not backed up yet', 'এখনো ব্যাকআপ হয়নি');
  String get autoBackupNote => _t('Backs up automatically when you leave the app.', 'অ্যাপ থেকে বের হলে নিজে থেকেই ব্যাকআপ হয়।');
  String get backupDone => _t('Backup saved to Google Drive', 'গুগল ড্রাইভে ব্যাকআপ সেভ হয়েছে');
  String get restoreDone => _t('Data restored', 'ডেটা ফিরিয়ে আনা হয়েছে');
  String get backupFailed => _t('Backup failed', 'ব্যাকআপ ব্যর্থ হয়েছে');
  String get noBackupFound => _t('No backup found on Drive', 'ড্রাইভে কোনো ব্যাকআপ পাওয়া যায়নি');
  String get restoreConfirmTitle => _t('Restore from Drive?', 'ড্রাইভ থেকে ফিরিয়ে আনবেন?');
  String get restoreConfirmBody => _t(
      'Data on this phone will be replaced with your Drive backup.',
      'এই ফোনের ডেটা ড্রাইভের ব্যাকআপ দিয়ে বদলে যাবে।');
  String get backupFoundTitle => _t('Backup found', 'ব্যাকআপ পাওয়া গেছে');
  String get backupFoundBody => _t(
      'A backup is on your Google Drive. Restore it to this phone?',
      'আপনার গুগল ড্রাইভে একটি ব্যাকআপ আছে। এই ফোনে ফিরিয়ে আনবেন?');
  String get restore => _t('Restore', 'ফিরিয়ে আনুন');
  String get notNow => _t('Not now', 'এখন না');
  String get ai => _t('AI', 'এআই');
  String get aiHelp => _t(
      'Optional: use your own free AI key (e.g. from aistudio.google.com or openrouter.ai).',
      'ঐচ্ছিক: নিজের ফ্রি এআই কি ব্যবহার করুন (যেমন aistudio.google.com বা openrouter.ai থেকে)।');
  String get aiProvider => _t('Provider', 'প্রোভাইডার');
  String get aiModel => _t('Model', 'মডেল');
  String get aiKey => _t('API key', 'এপিআই কি');
  String get saved => _t('Saved', 'সেভ হয়েছে');

  List<String> get weekdaysShort => bn
      ? const ['সোম', 'মঙ্গল', 'বুধ', 'বৃহঃ', 'শুক্র', 'শনি', 'রবি']
      : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String weekday(int dartWeekday) => weekdaysShort[dartWeekday - 1];

  String contactLabel(String kind) => switch (kind) {
        'student' => studentPhone,
        'whatsapp' => whatsapp,
        'father' => fatherPhone,
        _ => motherPhone,
      };
}
