# Nahdi Academy — Mobile Design System

Spec for building the Nahdi Academy Flutter UI. Pair this file with `ui-kit-reference.png`
(the full component board) and the assets in `assets/brand/logo/`.

The theme is already implemented in `lib/theme/app_theme.dart` (`AppColors` + `AppTheme.light()`).
Build widgets against those tokens — don't hardcode hex values in screens.

---

## Brand
- **Logo** — mosaic graduation cap. `logo-white.png` on teal/dark, `logo.png` on light.
- **Wordmark** — "nahdi" Bricolage Grotesque w800 lowercase + "academy" w500, in the app bar.

## Colour (→ `AppColors`)
| Role | Token | Hex |
|---|---|---|
| Primary (header, app bar, primary button) | `teal` | `#00444F` |
| Dark / featured card | `tealDark` | `#00333B` |
| Hover / lighter accent | `tealLight` | `#0A6A74` |
| Screen background | `canvas` | `#FBFAF7` |
| Body text | `ink` | `#111E20` |
| Muted / meta text | — | `#9AA39F` |

**Mosaic accents** (`AppColors.accents`, max two per screen):
red `#E02234` · orange `#F0612F` · amber `#F4A81E` · lime `#C9D634` · green `#6FB840` ·
sky `#2FA8D8` · blue `#1A7CC0` · purple `#9C3690`

**Status colours**
- Enrolled / success → `#2FA84F` on `#E2F0E5`
- In progress → `#00444F` on `#E3EFEC`
- Due soon → `#F0612F` on `#FCEBDD`
- Overdue → `#E02234` on `#FBE9EC`
- Completed → grey `#6A746F` on `#F3F1EB`
- Certificate → lime `#C9D634` on `#00444F`

## Typography (google_fonts — already in text theme)
| Style | Font | Size / weight |
|---|---|---|
| Greeting / H1 | Bricolage Grotesque | 25 / w800, tracking -0.5 |
| Card title / H2 | Bricolage Grotesque | 17–18 / w700 |
| Section header | Bricolage Grotesque | 15 / w700 |
| List title | Manrope | 13 / w700 |
| Caption / meta | Manrope | 10–11 / w400–600 |

## Tokens
- **Radius** — cards 16, panels/featured 18, pills/buttons 14, chips 20–22, status badges full.
- **Spacing scale** — 4 / 8 / 12 / 16 / 20 / 24.
- **Cards** — white fill, 1px border `#ECE7DE`, no heavy shadow. Featured = `#00333B` fill, white text.
- **Hit targets** — ≥ 44px.

## Layout rhythm (every screen)
Deep-teal header zone (logo row + greeting/title) flowing into warm-paper content, with a
bottom nav: **Home / Courses / Schedule / Profile** — active item in `#00444F`.

---

## Components to build (`lib/ui/widgets/`)
- **Buttons** — `PrimaryButton` (teal fill), `SecondaryButton` (outlined teal), `GhostButton`, `Fab`
- **Indicators** — `StatusBadge(text, color)`, `CategoryChip`
- **Cards** — `FeaturedCard` (dark; label + title + progress), `CourseCard` (thumbnail + due badge),
  `CourseListItem` (icon tile + title + meta + trailing badge/percent/chevron)
- **Progress** — `LinearProgress` (green on `#EDEAE3`), `CircularProgress`, segmented step bar
- **Inputs** — `SearchField`, `AppTextField` (focus = teal border), `SegmentedTabs`
- **Chrome** — `BrandAppBar` (teal, `logo-white` + wordmark), `BottomNavBar`

## Screens (`lib/ui/screens/`)
1. **Home** — greeting header, "Continue learning" `FeaturedCard`, "My courses" list.
2. **Courses** — `SearchField` + `SegmentedTabs` (All / Courses / Webinars), list/grid of `CourseCard`.
3. **Course detail** — header, progress, module list.
4. **Profile** — avatar, region/role, certificates.

Material 3, theme from `lib/theme/app_theme.dart`.
