# Trainee UI — Design System & Implementation

> Status: **built, `flutter analyze` clean** (web build not yet run).
> The trainee-facing mobile UI for Nahdi Academy — Home / Courses / Schedule /
> Profile — built against the design kit in
> [assets/design/](../../assets/design/) and the brand theme in
> [lib/theme/app_theme.dart](../../lib/theme/app_theme.dart).
>
> Sibling docs: product vision [academyBrainstorm.md](../academyBrainstorm.md) ·
> foundation/admin [foundationAdminImplementation.md](../foundationAdminImplementation.md).

## 1. What this delivers

The trainee experience that a plain employee (no `admins` doc) sees after
sign-in. It is **presentation + a single cubit** — there is no trainee/course
backend yet, so screens render design-system demo data, shaped so a Firestore
repository can be dropped in later.

1. **A reusable widget library** (`lib/ui/widgets/`) built strictly on theme tokens.
2. **Four screens** (`lib/ui/screens/`) + a bottom-nav shell.
3. **Responsive layout** for phone / tablet / Windows (desktop).
4. **`HomeCubit`** driving the Home screen state.

The entry point is [lib/user/user_home.dart](../../lib/user/user_home.dart),
reached from [AuthGate](../../lib/auth/ui/auth_gate.dart) when `state.isTrainee`.

## 2. Source of truth

| Artifact | Purpose |
| --- | --- |
| [assets/design/DESIGN_SYSTEM.md](../../assets/design/DESIGN_SYSTEM.md) | The spec — colour, type, tokens, component list. |
| [assets/design/ui-kit.html](../../assets/design/ui-kit.html) | Rendered component board (open in a browser). |
| [assets/design/ui-kit-reference.png](../../assets/design/ui-kit-reference.png) | Static reference image. |
| [lib/theme/app_theme.dart](../../lib/theme/app_theme.dart) | `AppColors` + `StatusColors` + `AppTheme.light()`. |

**Rule:** build widgets against the theme tokens — never hardcode hex in screens.

## 3. Design tokens

All tokens live in [lib/theme/app_theme.dart](../../lib/theme/app_theme.dart).

### Colour (`AppColors`)
| Role | Token | Hex |
| --- | --- | --- |
| Primary — header, app bar, primary button | `teal` | `#00444F` |
| Dark / featured card | `tealDark` | `#00333B` |
| Lighter teal accent | `tealLight` | `#0A6A74` |
| Screen background (warm paper) | `canvas` | `#FBFAF7` |
| Body text | `ink` | `#111E20` |
| Meta / caption text | `muted` | `#9AA39F` |
| 1px card border | `hairline` | `#ECE7DE` |
| Progress track | `track` | `#EDEAE3` |
| Neutral chip / inactive tab | `chipBg` | `#F3F1EB` |
| Pale teal tile fill | `tealMist` | `#E3EFEC` |
| Caption on dark teal | `tealCaption` | `#7FC9C2` |

**Mosaic accents** (`AppColors.accents`, max two per screen): red `#E02234` ·
orange `#F0612F` · amber `#F4A81E` · lime `#C9D634` · green `#6FB840` ·
sky `#2FA8D8` · blue `#1A7CC0` · purple `#9C3690`.
`AppColors.accentFor(key)` returns a deterministic accent per string.

### Status colours (`StatusColors` — `fg` / `bg` pairs)
| Status | fg | bg |
| --- | --- | --- |
| `enrolled` | `#2FA84F` | `#E2F0E5` |
| `inProgress` | `teal` | `tealMist` |
| `dueSoon` | `#F0612F` | `#FCEBDD` |
| `overdue` | `#E02234` | `#FBE9EC` |
| `completed` | `#6A746F` | `#F3F1EB` |
| `certificate` | `lime` | `teal` |

### Typography (`AppTheme._textTheme`, via `google_fonts`)
- **Bricolage Grotesque** — greeting/H1 `25/w800` (tracking −0.5), card title `17–18/w700`, section header `15/w700`.
- **Manrope** — list title `13/w700`, caption/meta `10–11/w400–600`.

### Shape & spacing
- **Radius** — cards 16, panels/featured 18, pills/buttons 14, chips 20, status badges full.
- **Spacing scale** — 4 / 8 / 12 / 16 / 20 / 24.
- **Cards** — white fill, 1px `hairline` border, no heavy shadow. Featured = `tealDark` fill, white text.
- **Hit targets** — ≥ 44px (`kMinHit = 48` in [buttons.dart](../../lib/ui/widgets/buttons.dart)).

## 4. Layout rhythm

Every screen follows the same vertical rhythm:

```
┌─────────────────────────────┐
│  TealHeader  (deep-teal)     │  brand lockup row + greeting/title
│  ▸ full-bleed teal           │
├─────────────────────────────┤
│  Body  (warm paper #FBFAF7)  │  cards / lists, scrollable
│  ▸ capped + centred column   │
├─────────────────────────────┤
│  BottomNavBar (white)        │  Home / Courses / Schedule / Profile
└─────────────────────────────┘
```

The teal banner spans the full width; its **content** and the body share the
same capped, centred column so wide windows keep the mobile rhythm.

## 5. Responsive system

[lib/ui/responsive.dart](../../lib/ui/responsive.dart)

| Form factor | Width | `contentMaxWidth` | "My courses" cols | Catalog grid cols |
| --- | --- | --- | --- | --- |
| `phone` | `< 600` | full | 1 | 2 |
| `tablet` | `600–1023` | 680 | 2 | 3 |
| `desktop` | `≥ 1024` | 860 | 2 | 4 |

- `formFactorFor(width)` / `context.formFactor` — resolve the bucket.
- `ContentColumn(maxWidth)` — aligns top-centre and caps width, so desktop
  windows don't stretch edge-to-edge.
- `TealHeader.maxContentWidth` — caps the banner's inner content to match.
- `itemWidthFor(available, count, gap)` — computes wrapped grid item widths.

Screens read width from a `LayoutBuilder` (so they react to the actual pane,
not just the window) and pass `maxW` to both the header and `ContentColumn`.

## 6. Component library

[lib/ui/widgets/](../../lib/ui/widgets/) — all stateless, theme-driven.

| File | Widgets |
| --- | --- |
| [buttons.dart](../../lib/ui/widgets/buttons.dart) | `PrimaryButton` (teal fill), `SecondaryButton` (outlined), `GhostButton` (text + chevron), `AppFab` |
| [badges.dart](../../lib/ui/widgets/badges.dart) | `StatusBadge` (+ `.forStatus`), `CategoryChip`, `IconTile` (+ `.forStatus`) |
| [progress.dart](../../lib/ui/widgets/progress.dart) | `LinearProgress`, `CircularProgress`, `SegmentedStepBar` |
| [inputs.dart](../../lib/ui/widgets/inputs.dart) | `SearchField`, `AppTextField` (teal focus border), `SegmentedTabs` |
| [brand.dart](../../lib/ui/widgets/brand.dart) | `BrandWordmark`, `BrandLockup`, `BrandAppBar`, `SectionHeader`, `Eyebrow` |
| [cards.dart](../../lib/ui/widgets/cards.dart) | `AppCard`, `FeaturedCard` (dark), `CourseCard` (thumbnail), `CourseListItem` |
| [teal_header.dart](../../lib/ui/widgets/teal_header.dart) | `TealHeader`, `HeaderIconButton` |
| [bottom_nav_bar.dart](../../lib/ui/widgets/bottom_nav_bar.dart) | `BottomNavBar`, `NavDestination`, `kUserNavDestinations` |

### Notable behaviours
- **`CourseListItem` trailing** is status-driven: `completed` → grey `%`,
  `enrolled` → plain green label (matches the home reference, not a pill),
  `inProgress` → chevron, otherwise → `StatusBadge` pill.
- **`CourseListItem` icon tile** is tinted from the course **accent**
  (`accent.withValues(alpha: .14)` fill), and shows a check for completed items.
- **Wordmark** — "nahdi" w800 + "academy" w500; the "academy" half uses
  `tealCaption` on dark, `teal` on light.

## 7. Screens

[lib/ui/screens/](../../lib/ui/screens/)

| Screen | File | Contents |
| --- | --- | --- |
| Home | [home_screen.dart](../../lib/ui/screens/home_screen.dart) | Greeting header, "Continue learning" `FeaturedCard`, "My courses" list (1/2-col). Reads `HomeCubit`. |
| Courses | [courses_screen.dart](../../lib/ui/screens/courses_screen.dart) | `SearchField` + `SegmentedTabs` (All/Courses/Webinars) + adaptive `CourseCard` grid. Local filter state. |
| Course detail | [course_detail_screen.dart](../../lib/ui/screens/course_detail_screen.dart) | Header (back + title + status), `CircularProgress` + `SegmentedStepBar` panel, module list, sticky CTA. Pushed route. |
| Schedule | [schedule_screen.dart](../../lib/ui/screens/schedule_screen.dart) | Upcoming sessions / webinars / due assessments as `CourseListItem`s. |
| Profile | [profile_screen.dart](../../lib/ui/screens/profile_screen.dart) | Avatar + region/role, stat cards, certificates, sign-out. |
| Shell | [user_shell.dart](../../lib/ui/screens/user_shell.dart) | `IndexedStack` of the four tabs behind `BottomNavBar` (state preserved per tab). |

## 8. State & data flow

State management is **Cubit (`flutter_bloc`)**, per project convention. Only Home
needs shared state today; the other screens hold trivial local UI state
(`StatefulWidget`).

```
UserHome  (lib/user/user_home.dart)
  ├─ reads AuthCubit.state.user  → first name, email
  ├─ BlocProvider(create: HomeCubit(name, region, role))
  └─ UserShell
       └─ HomeScreen → context.watch<HomeCubit>().state
```

- [home_cubit.dart](../../lib/user/cubit/home_cubit.dart) /
  [home_state.dart](../../lib/user/cubit/home_state.dart) — holds `name`,
  `region`, `role`, the `featured` course and `myCourses`. `load()` emits demo
  content synchronously; it is async-shaped for a future repository stream.
- [lib/ui/models/learning.dart](../../lib/ui/models/learning.dart) — the view
  models: `Course`, `Module`, `CourseStatus` (carries its `StatusColors`),
  `CourseKind`, and `DemoData` (the sample catalogue mirroring the design kit).

> **When the backend lands:** add a `CourseRepository` (Firestore) and have
> `HomeCubit` subscribe to its stream instead of calling `DemoData`; the screens
> need no changes.

## 9. Code layout added

```
lib/
  theme/app_theme.dart              # + muted/hairline/track/chipBg/tealMist/tealCaption, StatusColors
  user/
    user_home.dart                  # provides HomeCubit, hosts UserShell
    cubit/home_cubit.dart           # (+ home_state.dart)
  ui/
    responsive.dart                 # FormFactor, Breakpoints, ContentColumn, itemWidthFor
    models/learning.dart            # Course / Module / CourseStatus / CourseKind / DemoData
    widgets/                        # buttons, badges, progress, inputs, brand,
                                    #   cards, teal_header, bottom_nav_bar
    screens/                        # home, courses, course_detail, schedule,
                                    #   profile, user_shell
```

## 10. Conventions for extending

- **One widget per concept**, stateless, parameterised by theme tokens — never
  raw hex. New colours go into `AppColors` / `StatusColors` first.
- **Read state via `BlocBuilder` / `context.watch`**; keep screens free of logic.
- **Reuse the rhythm:** new screens = `TealHeader(maxContentWidth: maxW)` +
  `ContentColumn(maxWidth: maxW)` body, sized from a `LayoutBuilder`.
- **Icons** — `flutter_tabler_icons`. **Fonts** — `google_fonts` via the theme.
- Keep `flutter analyze` clean.

## 11. Running & preview

```bash
flutter pub get
flutter analyze            # expected: No issues found
flutter run -d chrome      # primary target (web); resize to see breakpoints
```

### Dev preview switch
[lib/main.dart](../../lib/main.dart) — `const bool kPreviewUserHome`:

- `true`  → skip login, open the trainee `UserHome` directly (eyeball the layout).
- `false` → normal login → role-gated flow. (Takes precedence over
  `kSkipAuthForPreview`, which opens the admin shell.)

A real trainee account still lands here automatically via `AuthGate`.

## 12. Known limits / not yet done

- **Demo data only** — `DemoData` stands in for a trainee/course backend; no
  enrollment, attendance or persistence yet.
- **Placeholder identity** — region/role are hardcoded in `UserHome`
  (`Eastern Region · Pharmacist`); they aren't in the auth token yet.
- **CTAs are inert** — "Start/Resume course", certificate rows, etc. have no
  navigation into real content (the SCORM player is a separate Windows-only tab).
- **Profile stats** are static sample numbers.
- Cubit/repository wiring for Courses, Schedule and Profile is intentionally
  deferred until the data model exists.
