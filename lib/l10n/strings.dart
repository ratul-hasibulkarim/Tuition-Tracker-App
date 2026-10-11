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
      _t('$n ${n == 1 ? 'day' : 'days'} since payment', 'পেমেন্টের পর $n দিন');
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
  String classesThisMonth(int n) => _t('$n classes this month', 'এই মাসে $n টি ক্লাস');
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
  String get openWhatsapp => _t('Open WhatsApp', 'হোয়াটসঅ্যাপ খুলুন');

  // Day sheet
  String classesOnDay(int n) => _t('$n ${n == 1 ? 'class' : 'classes'} taught', '$n টি ক্লাস নেওয়া হয়েছে');
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
  String get routineComingTitle => _t('Smart routine is coming soon', 'স্মার্ট রুটিন শীঘ্রই আসছে');
  String get routineComingBody => _t(
      'Add weekly days & times to each student. The routine tab will plan your week and the best travel order.',
      'প্রতিটি ছাত্র/ছাত্রীর সাপ্তাহিক দিন ও সময় যোগ করুন। রুটিন ট্যাব আপনার সপ্তাহ ও যাতায়াতের সেরা ক্রম সাজিয়ে দেবে।');

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
  String get backup => _t('Backup', 'ব্যাকআপ');
  String get backupComing => _t(
      'Google Drive backup is coming in the next update.',
      'গুগল ড্রাইভ ব্যাকআপ পরের আপডেটে আসছে।');
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
