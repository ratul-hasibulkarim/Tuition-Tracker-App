# Tuition Tracker

A simple Android & iOS app (Flutter) for private tutors and coaching centres in
Bangladesh. You can track classes taught, payments, homework and travel to each
student. It's in English and বাংলা and has light and dark themes.

## Features (milestone 1)

- **Current tuitions** in list or grid view, with search and a "past tuitions" archive.
- **Add tuition** form: name, class/subjects, address with a Google Maps pin,
  student/WhatsApp/father/mother numbers, which number the call button dials,
  monthly fee, classes per month and the weekly schedule.
- **Student card**: name, area, classes since last payment, plus buttons to
  **call**, see **directions + bike fare**, and **+** to add a class (with undo).
- **Student page**: everything is editable. It shows total classes, total
  received, last payment and an estimate of what is due. The payment history
  lives here.
- **Calendar**: taught days are highlighted for any month you pick. Tapping a
  day lets you add or remove a class and add **notes/homework with photos**.
  The previous homework is shown under it.
- **Trip sheet**: distance, travel time and estimated bike fare. Buttons open
  Google Maps (motorbike directions), Uber (drop-off filled in) or Pathao.
- **Routine tab**: a weekly view built from each student's schedule. AI
  planning comes later.
- **Settings**: theme (system/light/dark), language (English/বাংলা) and the
  rates used for the fare estimate.

All data is stored on the phone in one file (`students.json`, plus an
`images/` folder), so a full backup is easy.

## Running

```bash
flutter pub get
flutter run
flutter test
```

### Google Maps key

The map picker needs a Google Maps key. Without one the app still works, but
the picker map shows blank. Live-traffic travel times are optional.

- **Android**: add `MAPS_API_KEY=...` to `android/local.properties`.
- **iOS**: copy `ios/Flutter/Secrets.xcconfig.example` to `Secrets.xcconfig`
  and set the key.
- **Live traffic times** (Routes API, optional): build with
  `--dart-define=MAPS_API_KEY=...`. Without it, times come from distance.

In Google Cloud Console, restrict the Android key to the package
`com.tuitiontracker.tuition_tracker` and your SHA-1 fingerprint, and the iOS
key to the bundle ID. Also set a daily quota and a budget alert.

## Roadmap

1. ✅ Tuitions, cards, calendar, homework, payments, trip and fare, themes, Bangla
2. Google sign-in and Drive backup/restore (hidden app folder, survives uninstall)
3. Server proxy for Maps routing and AI, so no paid keys ship inside the app
4. AI routine tab: weekly plan and the best visiting order by travel time and cost
5. Student/guardian companion app
