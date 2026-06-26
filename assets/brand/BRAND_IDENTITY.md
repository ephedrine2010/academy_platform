# Nahdi Academy — Brand Identity

The corporate learning & training platform of **Nahdi**. The mark is a **mosaic graduation cap** —
a deep-teal mortarboard whose top is built from the same colourful tiles as the Nahdi heart, tying
the Academy directly to the parent brand while standing for growth, mastery and care.

---

## 1. Logo files (`logo/`)

```
logo.png                  Primary mark, full colour, transparent bg (480²)
logo-transparent.png      Same as logo.png (explicit name)
logo-white.png            White knockout cap — for deep-teal / dark / photo backgrounds
logo-teal.png             Single-colour deep-teal cap — for light mono usage
appicon-ios-1024.png      iOS icon · light (paper bg, colour cap)
appicon-ios-teal-1024.png iOS icon · PRIMARY (deep-teal bg, white cap)
appicon-android-1024.png  Android adaptive icon (deep-teal circle, white cap)
appicon-mono-teal-1024.png Mono icon (paper bg, teal cap)
```

**Usage by background**
- On **white / paper / light teal-tint** → use `logo.png` (full colour).
- On **deep teal, dark, photos, accent colours** → use `logo-white.png` (white knockout).
- Never place the full-colour mark on accent colours or busy imagery.
- Never crop the tassel, recolour the cap, rotate, add shadows, or stretch.

---

## 2. Colour — sampled from the mark

| Token | Hex | Use |
|---|---|---|
| Deep Teal | `#00444F` | Primary brand colour — headers, app bar, buttons, icon bg |
| Teal Ink | `#00333B` | Dark surfaces, cards on teal, shadows |
| Teal Light | `#0A6A74` | Hover / lighter accents |
| Paper | `#FBFAF7` | App background (warm off-white) |
| Ink | `#111E20` | Body text |

**Mosaic accents** (sampled from the cap) — category tags, status, progress. Max **two** per composition:

`#E02234` · `#F0612F` · `#F4A81E` · `#C9D634` · `#6FB840` · `#2FA8D8` · `#1A7CC0` · `#9C3690`

---

## 3. Typography

- **Display & headings — Bricolage Grotesque** (500–800)
- **UI & body — Manrope** (400–700)

Wordmark: `nahdi` in Bricolage Grotesque 800 lowercase (tracking -2.5); `ACADEMY` in Manrope 600
uppercase (+12 tracking). Both fonts are free on Google Fonts.

---

## 4. Clear space & minimum size

- **Clear space** = the height of the cap's tassel on every side; keep it free of other graphics/type.
- **Minimum size** — cap mark: 28 px digital / 9 mm print. Full lockup: never below 110 px wide.

---

## 5. Using it in the Flutter app

```yaml
flutter:
  assets:
    - assets/brand/logo/
```

**Theme** — update `lib/theme/app_theme.dart` `AppColors`:

```dart
static const Color teal      = Color(0xFF00444F); // was 0xFF0E5257
static const Color tealDark  = Color(0xFF00333B);
static const Color tealLight = Color(0xFF0A6A74);
static const Color canvas    = Color(0xFFFBFAF7);
static const Color ink       = Color(0xFF111E20);
// mosaic accents — red/orange/amber/lime/green/sky/blue/purple as above
```

**Logo in UI** (flutter_svg not needed — these are PNGs):

```dart
Image.asset('assets/brand/logo/logo-white.png', height: 32) // on the teal app bar
Image.asset('assets/brand/logo/logo.png', height: 64)       // on the light login screen
```

**App launcher icon** — `flutter_launcher_icons`:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/brand/logo/appicon-ios-teal-1024.png"
  adaptive_icon_background: "#00444F"
  adaptive_icon_foreground: "assets/brand/logo/appicon-android-1024.png"
```

Run `flutter pub run flutter_launcher_icons`.

---

*The full interactive brand board lives in `Nahdi Academy Brand.dc.html`.*
