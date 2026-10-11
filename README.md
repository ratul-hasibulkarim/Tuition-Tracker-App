# Tuition Tracker

A simple Android & iOS app (Flutter) for private tutors and coaching centres in
Bangladesh. You can track classes taught, payments, homework, travel and your
weekly routine. It's in English and বাংলা (with Bangla digits) and has light
and dark themes.

## Features

**Tuitions**
- Current tuitions in a list or grid, with search, batch filters and a "past tuitions" archive.
- **Add tuition** form: name, class/subjects, batch, address with a map pin
  and **address search**, student/WhatsApp/father/mother numbers, which number
  the call button dials, monthly fee, classes per month and weekly schedule.
- **Student card**: classes since last payment, plus buttons to **call**,
  see **directions + bike fare**, and **+** to add a class (with undo).
- **Student page**: details (all editable), total classes, total received,
  last payment and an estimate of what is due. Payments can be **added,
  edited or deleted**.
- **Calendar**: taught days are highlighted for any month you pick. Tapping a
  day lets you add or remove a class and add or **edit notes/homework with
  photos**. The previous homework is shown under it.
- **Trip sheet**: distance, travel time (live traffic when the server is set
  up) and estimated bike fare. Buttons open Google Maps, Uber or Pathao.

**Coaching centres**
- Give students a **batch** name (e.g. "HSC 26"), then filter by batch.
- **Add class for all** in a batch with one tap (with undo).
- **Record payments** for many students at once.
- **Add several students** at once: type a list of names, and they share the batch, class, place and fee.

**Income summary** (menu ⋮ → Income summary)
- Money received each month across all students, classes taught, expected
  monthly fees and the all-time total.
- A 6-month bar chart and a per-student breakdown.

**Routine** (tab)
- Works out your **probable weekly routine** from saved schedules, or learns
  it from past classes (days taught at least twice in the last 8 weeks).
- For each day, finds the **visiting order with the least travel**, letting
  classes move by ±0/15/30/60 minutes. It shows the time, distance and fare
  for each leg.
- Warns about **clashes** (not enough time to travel) and shows how many
  minutes the new order saves.
- Opens the whole day's route in Google Maps.
- **AI plan & tips**: a free AI writes the weekly plan, tips to cut travel
  and free time slots for new tuitions, in English or Bangla. Only first
  names, areas and times are sent.

**Google Drive backup** (Settings)
- Data lives on the phone. After signing in with Google, a copy (data + homework photos) is saved to a
  hidden app folder on your Drive. It survives uninstalling.
- Backs up automatically when you leave the app (and at least daily).
- After reinstalling or on a new phone, sign in and tap **Restore**. The app offers this itself if it finds a backup.

## Running

```bash
flutter pub get
flutter run
flutter test                 # app tests
cd server && npm test        # server tests
```

Everything below is optional. The app works without it, with rough travel
estimates and no AI or backup.

## Setup

### 1. Google Cloud project
Create a project at https://console.cloud.google.com and enable **Maps SDK for
Android**, **Maps SDK for iOS**, **Routes API** and **Google Drive API**.

### 2. Map keys (the in-app map)
The map shown inside the app on Android and iOS has no per-load charge. Make
one key per platform and restrict it to the app:
- Android: restrict to package `com.tuitiontracker.tuition_tracker` + your SHA-1,
  then put `MAPS_API_KEY=...` in `android/local.properties`.
- iOS: restrict to the bundle ID, then copy `ios/Flutter/Secrets.xcconfig.example`
  to `ios/Flutter/Secrets.xcconfig` and fill in `MAPS_API_KEY`.

### 3. Server (keeps paid keys out of the app)
`server/` is a small Cloudflare Worker (free plan is enough). It holds the
Routes API key and the AI key, so nobody can pull them out of the Play Store
app. It checks an app token and limits each IP to 60 requests a minute.

```bash
cd server
npx wrangler login
npx wrangler secret put APP_TOKEN      # any long random string
npx wrangler secret put MAPS_API_KEY   # key with Routes API enabled (server-only, no app restriction)
npx wrangler secret put AI_API_KEY     # free Gemini key from https://aistudio.google.com
npx wrangler deploy
```

To use another AI (e.g. free DeepSeek via OpenRouter), set `AI_BASE_URL` and
`AI_MODEL` in `wrangler.toml`. Then build the app with:

```bash
flutter build apk --dart-define=API_BASE_URL=https://tuition-tracker-api.<you>.workers.dev \
                  --dart-define=APP_TOKEN=<same token> \
                  --dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>
```

Also set a **daily quota** on the Routes API and a **budget alert** in Google Cloud.

### 4. Google sign-in (Drive backup)
In Google Cloud → APIs & Services → Credentials:
1. Set up the **OAuth consent screen** and add the scope `.../auth/drive.appdata`.
2. Create an **Android** OAuth client (package name + SHA-1).
3. Create an **iOS** OAuth client (bundle ID). Put its ID and reversed ID in
   `ios/Flutter/Secrets.xcconfig`.
4. Create a **Web application** client. Pass its ID as `GOOGLE_SERVER_CLIENT_ID`
   (Android needs this) and also put it in `Secrets.xcconfig`.

### 5. AI without the server
Teachers can also paste their own free key in **Settings → AI**. Supported
providers are Gemini, OpenRouter (free DeepSeek models), Groq and DeepSeek.
The key is stored in the phone's secure storage.

## Roadmap
1. ✅ Tuitions, cards, calendar, homework, payments, trip and fare, themes, Bangla
2. ✅ Drive backup, AI routine, server proxy, coaching batches, income summary,
   editing, Bangla digits, address search
3. Payment reminders (+ WhatsApp message to guardians)
4. Student/guardian companion app
