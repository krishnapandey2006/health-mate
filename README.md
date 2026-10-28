# HealthMate (Arogya Vani)

Local-first health information, vaccination records and nearby care — in multiple
Indian languages, with an on-device profile and no account required.

## 📱 Download HealthMate

**Android users:** [**Download HealthMate APK**](https://github.com/krishnapandey2006/health-mate/releases/download/v1.0.0/HealthMate-v1.0.0.apk)

Download the APK, open it on your Android phone, and follow the installation
instructions. Android may ask you to allow installation from this source.

- Size: ~56 MB · Version 1.0.0 · Works on arm64, armv7 and x86_64 devices
- Release page with full notes: [HealthMate Latest Release](https://github.com/krishnapandey2006/health-mate/releases/tag/v1.0.0)

### What works on your phone right away

Everything personal is stored only on your device — no sign-up, no upload:

- Profile setup (name, date of birth, gender, state, voice guidance)
- Vaccination records against India's National Immunization Schedule
- Health reports and report history
- Verified health campaigns (bundled with the app)
- Emergency help / SOS numbers
- Text-to-speech read-aloud of health updates

### What needs the backend

Two screens — **News** and **Nearby** care facilities — fetch public data through
a small proxy server, and the app currently points at `http://localhost:8787`.
That address only exists on the developer's machine, so **on a phone these two
screens will report "could not be reached"**. They are not broken; they simply
have no server to talk to yet.

To make them work for phone users, deploy `healthmate_mb/tools/healthmate_server.js`
to a public HTTPS host and rebuild:

```
flutter build apk --release --dart-define=HEALTHMATE_PROXY_URL=https://your-host
```

### About this build

This APK is signed with Android's **debug** key, not a production release key. It
installs and runs normally, but treat it as a preview: it is not a Play Store
artifact, and a future production-signed build will not update it in place — you
would uninstall and reinstall instead.

## Running from source

Requires Flutter 3.x with the Android toolchain.

```
cd healthmate_mb
flutter pub get
flutter run -d chrome        # or: flutter run -d <your-android-device>
```

In a second terminal, start the public-data proxy (needed for News and Nearby):

```
cd healthmate_mb
npm install
npm run proxy                # listens on http://localhost:8787
```

Build an installable APK:

```
cd healthmate_mb
flutter build apk --release  # -> build/app/outputs/flutter-apk/app-release.apk
```

## Repository layout

- `healthmate_mb/` — the Flutter application (`lib/` holds screens and services)
- `healthmate_mb/tools/healthmate_server.js` — local proxy for news, campaigns,
  geocoding and OpenStreetMap facilities
- `healthmate_mb/README.md` — older developer notes

HealthMate provides general health information and is not a substitute for
professional medical advice, diagnosis or treatment.
