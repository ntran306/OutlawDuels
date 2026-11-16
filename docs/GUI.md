# OutlawDuels — GUI spec ("High Noon")

Written 2026-11-16. Sub-plan of `PLAN.md` §1A.10. Legend as in `PLAN.md`: **(T)** tunable
starting value, **(U)** unverified on the device. Mock-up the user chose from:
https://claude.ai/artifact/85X8C1uaic5eJAaSwTbn94 (look C).

## 1. Decisions (the user's, 2026-11-16)

| Topic | Decision |
|---|---|
| Direction | **C High Noon**: plum-to-amber sunset sky, black silhouettes, flat shapes only |
| Tone | Stylised and professional, "not AI slop". This document is a draft to tune on the phone |
| Match HUD | Plain, themed only by colour: thin bar, six round pips, no plate |
| Launch | 1.6 s, skippable by tap, one sting |
| Transitions | Sky stays; the sun slides along the horizon; content fades through |
| Menu audio | Ambience loop plus the launch sting; no looping tune |
| Sound style | Punchy stylised revolver; every sound synthesised by a script in this repo |
| Silent switch | Obeyed everywhere; haptics still fire |
| Logo | Black finger-gun silhouette on the amber sun disc; OUTLAW / DUELS beneath |
| Scope now | Launch, main menu, settings, Practice briefing, match HUD (fake values), countdown, results. Lobby, sync, death/respawn specified here, built in Phase 3 |
| Fonts | Alfa Slab One (titles) + Barlow Condensed (everything else), bundled |
| Colour-blind | Setting "Shapes on markers", off by default |
| Match start | "3, 2, 1, DRAW" only if the players vote for a count; with no count the match is open as soon as everyone is ready and starts at the first shot (§7.1) |
| Finger gun | No gun model in play: the player's real finger is the gun, and effects appear at the index fingertip (`PLAN.md` §1B.3). The drawn finger gun is the logo only |

Rules that keep it professional: one accent (`sun`) per screen; no drop shadows on menu
screens (one exception, the launch wordmark, §4); no gradients other than the sky and the sun; all spacing on a 4 pt grid; text is
upper case only in Barlow Condensed labels; nothing bounces more than 6 % past its target.

## 2. Tokens

`App/UI/Theme/Theme.swift` (`enum Theme`), colours as sRGB.

| Token | Hex | Use |
|---|---|---|
| `sun` | `#F6B642` | Sun disc edge, HP fill, accent |
| `sunCore` | `#FFE2A0` | Sun disc centre (radial, centre to 70 % radius) |
| `ember` | `#E2572B` | Sky middle stop (58 %) |
| `plum` | `#5B1E3A` | Sky top stop (0 %) |
| `night` | `#1A0F14` | Silhouettes, text on light, scrims |
| `cream` | `#FFF1D6` | Text on sky, primary button fill |
| `danger` | `#D8382E` | Low-health vignette, HP fill at <= 25 |
| `hudWhite` | `#FFFFFF` | HUD pips, reticle, menu bars |

Sky: `LinearGradient` top to bottom, stops `plum` 0.00, `ember` 0.58, `sun` 1.00.
Player colours are those of `PLAN.md` §1B.8, unchanged.

Fonts (SIL OFL 1.1, from `github.com/google/fonts`, folders `ofl/alfaslabone` and
`ofl/barlowcondensed`; commit each `OFL.txt` beside the files):

| File in `App/Resources/Fonts/` | PostScript name (U: log `UIFont.fontNames`) | Role |
|---|---|---|
| `AlfaSlabOne-Regular.ttf` | `AlfaSlabOne-Regular` | Wordmark, screen titles, countdown digits, result score |
| `BarlowCondensed-SemiBold.ttf` | `BarlowCondensed-SemiBold` | Buttons, labels, HUD numbers |
| `BarlowCondensed-Medium.ttf` | `BarlowCondensed-Medium` | Body text, settings rows |

Registered with `UIAppFonts` in `project.yml`.

| Style | Font | Size pt | Tracking | Scales with Dynamic Type |
|---|---|---|---|---|
| `wordmark` | Alfa Slab | 44 | 0.04 em | No |
| `title` | Alfa Slab | 28 | 0.02 em | `relativeTo: .title`, cap `accessibility1` |
| `button` | Barlow SemiBold, upper case | 20 | 0.12 em | `relativeTo: .headline`, cap `accessibility1` |
| `body` | Barlow Medium | 18 | 0 | `relativeTo: .body`, cap `accessibility1` |
| `caption` | Barlow SemiBold, upper case | 13 | 0.20 em | `relativeTo: .caption`, cap `xxxLarge` |
| `hudNumber` | Barlow SemiBold, `.monospacedDigit()` (U) | 15 | 0 | No (fixed) |
| `countdown` | Alfa Slab | 160 | 0 | No |

Spacing: `s1` 4, `s2` 8, `s3` 12, `s4` 16, `s6` 24, `s8` 32 pt. Screen side margin 24.
Buttons: height 56, corner radius 28, full width minus margins, gap 12. Primary: fill
`cream`, text `night`. Secondary: fill `night` at 50 %, text `cream`. Tertiary (Settings,
Back): no fill, height 44, text `cream` above y 0.45 of the screen and `night` below it
(§9 contrast rule). Pressed: scale 0.97 and opacity 0.85, 80 ms
ease-out; release 160 ms.

Motion tokens (added to `Tuning` so they are live-tunable through `tools/tuning.json`):

| Key | Start | Curve |
|---|---|---|
| `uiTransitionMs` | 450 (T) | `spring(response: 0.45, dampingFraction: 0.86)` for the sun |
| `uiFadeOutMs` | 150 (T) | ease-in `timingCurve(0.4, 0, 1, 1)` |
| `uiFadeInMs` | 250 (T) | ease-out `timingCurve(0, 0, 0.2, 1)`, starts at 150 ms |
| `uiStaggerMs` | 40 (T) | delay per button, in order, on fade-in |
| `uiLaunchMs` | 1600 (T) | scales every launch keyframe proportionally |
| `uiDuskMs` | 500 (T) | sky to camera, ease-in-out |

## 3. Shared pieces

| Piece | File | Specification |
|---|---|---|
| Sky | `App/UI/Theme/SkyBackground.swift` | Gradient above, full screen, ignores safe area. One instance lives under all menu screens and never animates |
| Sun | `App/UI/Theme/SunDisc.swift` | `Circle` with `RadialGradient(sunCore -> sun, endRadius 0.7 r)`. Position and diameter come from `SunPose` per screen (§4) |
| Finger gun | `App/UI/Theme/FingerGunShape.swift` | A SwiftUI `Shape` in a 64 x 44 box, pointing right, built from rounded rects: index (24,12,39,9 r4.5), thumb (13,1,9,20 r4.5, rotated -12° about 17,20), palm (6,12,27,27 r7), curled fingers (27,20,14,7), (27,26.5,12,7), (27,33,9,6), wrist (0,23,12,19 r3, rotated 8°). Fill `night`. Drawn on the sun at 56 % of its diameter. Logo use only (launch, menu, app icon); never drawn during play |
| Skyline | `App/UI/Theme/SkylineShape.swift` | `Shape` in a 210 x 90 box, stretched to screen width, height 21 % of screen height, pinned to the bottom, fill `night`. Path: `M0 90 V62 H70 V46 H112 V58 H150 L158 50 H186 V64 H210 V90 Z` plus a cactus on the left ledge: trunk x 26–36 from y 63 up to a round top at y 19; right arm from (36,46) out to x 51, up to y 31.5 rounded; left arm from (26,52) out to x 11, up to y 35.5 rounded |
| App icon | `App/Resources/Assets.xcassets/AppIcon` | 1024 px PNG rendered by `tools/make_icon.py` (Pillow): sky gradient, sun at 62 % width centred, finger gun on it. No text |

No bitmap textures anywhere in the UI. No blur, no `Material`, no shadows on menu screens.

## 4. Screens

Layout values assume 390 x 844 pt (iPhone 12); positions are fractions so other sizes hold.
`SunPose` = centre x, centre y (fractions of the screen), diameter (pt).

| Screen | Background | `SunPose` | Content, top to bottom | Build |
|---|---|---|---|---|
| `launch` | Sky + skyline | (0.50, 0.38, 200) | Sun with finger gun; wordmark OUTLAW / DUELS two lines centred at y 0.60, `cream` with a hard offset shadow (`night` 35 %, radius 0, y 2 pt) because the sky there gives only about 3.3:1; caption "DRAW AT HIGH NOON" at y 0.74 in `night` | Now |
| `menu` | Sky + skyline | (0.50, 0.14, 96) | Title "OUTLAW DUELS" one line at y 0.24; buttons from y 0.36: Practice Range (primary), Host a Duel, Join a Duel (both secondary, disabled at 40 % opacity until Phase 3), Settings (tertiary); caption version "v0.1 (build n)" at bottom margin 24 above the skyline text-safe area | Now |
| `settings` | Sky, no skyline | (0.86, 0.08, 56) | Back (tertiary, top left); title "SETTINGS"; rows 56 pt high on `night` 50 % rounded 16: Effects volume slider, Ambience volume slider, Haptics toggle, Shapes on markers toggle, Reduce motion (follows the system; read-only note), Dev server field (existing), Tuning revision | Now |
| `practiceBriefing` | Sky + skyline | (0.18, 0.12, 72) | Back; title "PRACTICE RANGE"; three numbered steps in `body` (1 Point your finger gun at a target, thumb up. 2 Drop your thumb to fire. 3 Take your hand out of view to reload.); best score caption; toggle row "3-2-1 count" (default on, `UserDefaults` key `practiceCount`); Start (primary) at bottom margin 48 | Now |
| `countdown` | Camera | none | Shown only when a count was voted (§7.1). Digit "3", "2", "1" then "DRAW" centred, `countdown` style ("DRAW" at 96 pt), `cream` with 2 pt `night` outline | Now |
| `match` | Camera | none | HUD of §5. While the match is in STANDOFF (§7.1): caption "FIRE WHEN READY" in `caption` style, white with the HUD shadow, centred at y 0.16; it fades out in 150 ms at the first shot | Now, fake values |
| `results` | Camera under `night` 70 % scrim | none | Caption "ROUND OVER" (or "YOU WIN" / "YOU LOSE" in duels); score in Alfa Slab 72; three stat rows (shots, hits, accuracy %); Again (primary), Menu (secondary) | Now |
| `lobby` | Sky + skyline | (0.82, 0.12, 72) | Back; title "LOBBY"; join QR 220 pt on `cream` rounded 16 (host only); roster rows: colour disc 20 pt (plus glyph if on), "PLAYER n", ready dot, count-vote mark ("3-2-1" in `caption` when that player votes for a count); toggle row "Vote for 3-2-1 count" (each player, default off); Start (primary, host only) | Phase 3 |
| `sync` | Camera | none | Caption "SCAN THE HOST'S SCREEN"; 240 pt square bracket frame `cream` 3 pt; progress ring `sun` | Phase 3 |
| `dead` | Camera under `night` 55 % scrim | none | Title "DOWN"; caption "BACK IN n" counting `RESPAWN_WAIT_S`; killer's colour disc 28 pt | Phase 3 |
| `pause` | Camera under `night` 70 % scrim | none | Resume (primary), Settings (secondary), Leave (tertiary, `danger` text) | Now |

## 5. Match HUD (replaces nothing in `PLAN.md` §1A.5; fills in its drawing)

All HUD items get `shadow(color: night 70 %, radius 1.5, y: 1)` for legibility on any room;
no plates.

| Item | Position | Drawing |
|---|---|---|
| Own colour | 12 pt from left safe edge, 12 pt below top safe edge | Disc 12 pt in the player's colour |
| HP bar | 8 pt right of the disc, vertically centred on it | Track 120 x 6 pt, radius 3, white 35 %; fill `sun`, `danger` at HP <= 25; width change animates 200 ms ease-out |
| HP number | 8 pt right of the bar | `hudNumber`, white |
| Ammunition | 10 pt below the bar, left-aligned with the bar | Six discs 9 pt, gap 5 pt; loaded = white fill; spent = 1.5 pt white ring. Bow: "∞" in `hudNumber` |
| Menu | Top right, 44 x 44 pt hit area, 8 pt from edges | Three bars 20 x 2.5 pt, gap 5, white; no background |
| Self view | Bottom right, 90 x 120 pt, radius 8, 12 pt from edges | As `PLAN.md` §1A.5; `night` 45 % fill until F5 decides |
| Reticle | Aim point | White dot 6 pt with 1.5 pt `night` 55 % ring |
| Vignette | Edges | `PLAN.md` §1A.5 formula, colour `danger` |
| Marker glyphs | On each colour disc when "Shapes on markers" is on | White glyph at 55 % of disc size, by `colorIndex` 0–9: circle, triangle, square, diamond, plus, cross, bar, ring, chevron, star |

HUD micro-animations (each one view, opacity/scale/offset only):

| Event | What moves | Duration, curve | Reduce Motion |
|---|---|---|---|
| Shot | The spent pip scales 1.0 -> 0.6 -> 1.0 and becomes a ring | 120 ms ease-out | Instant swap |
| Reload | Pips fill left to right | 40 ms stagger, each 100 ms ease-out | All at once |
| Dry fire | Pip row shakes x ±3 pt, 2 cycles | 160 ms linear | Row opacity 1 -> 0.5 -> 1, 160 ms |
| Hit taken | HP number scales 1.25 -> 1.0 | 180 ms ease-out | None |
| Hit marker | `PLAN.md` §1B.3 (0.12 s) | — | Unchanged |

## 6. Animations

Launch (`uiLaunchMs` 1600; times in ms from first frame). At rest it equals the `launch`
row of §4. A tap at any time jumps to the end state and starts the transition to `menu`;
otherwise `menu` follows after a 400 ms hold (total 2000 ms).

| Start | Length | What | From -> to | Curve |
|---|---|---|---|---|
| 0 | 1000 | Sun rises | y offset +0.45 screen heights -> 0 | `timingCurve(0.16, 1, 0.3, 1)` |
| 0 | 1000 | Skyline rises | y offset +48 pt -> 0 | same |
| 100 | 0 | Sting `sting_launch` starts | | |
| 600 | 700 | Wordmark | opacity 0 -> 1, tracking 0.40 em -> 0.04 em, y +14 pt -> 0 | same |
| 1200 | 400 | Caption | opacity 0 -> 1 | ease-out |

Reduce Motion: everything at rest position; whole screen opacity 0 -> 1 in 300 ms; sting
still plays; hold 1300 ms.

| Animation | What moves | Duration, curve | Reduce Motion |
|---|---|---|---|
| Menu-to-menu transition | Old content opacity 1 -> 0 and y 0 -> -8 pt (`uiFadeOutMs`); sun moves and resizes to the new `SunPose` (`uiTransitionMs` spring); new content opacity 0 -> 1 and y +12 -> 0 (`uiFadeInMs`, from 150 ms, buttons staggered `uiStaggerMs`); skyline cross-fades 250 ms where one side has none. Back runs the same with y signs flipped | 450 ms total | Cross-fade 200 ms; sun jumps |
| Dusk (sky -> camera) | AR session starts on tap; when the first `ARFrame` arrives or 1500 ms pass: sun y -> 1.10 (sets behind the skyline), skyline y +100 %, sky opacity 1 -> 0 | `uiDuskMs` 500, ease-in-out | Sky opacity 1 -> 0, 300 ms |
| Dawn (camera -> sky) | Reverse of dusk; AR session paused when it ends | 500 ms | Fade 300 ms |
| Countdown digit | Each of "3", "2", "1" at 0 / 800 / 1600 ms (`PLAN.md` §10.2): scale 1.4 -> 1.0 and opacity 0 -> 1 in 180 ms ease-out, hold, opacity -> 0 in the last 150 ms. At 2400 ms "DRAW" (Alfa Slab 96 pt) scales 1.2 -> 1.0 in 120 ms and fades over 300 ms; weapons go live at 2400 ms | per digit 800 ms | Opacity only |
| Results in | Scrim 0 -> 70 % 250 ms; score counts up from 0 over 600 ms ease-out; rows fade in at 40 ms stagger | 850 ms | Scrim and final values, fade 200 ms |
| Scrims (pause, dead) | Opacity in 200 ms ease-out, out 150 ms | | Same |

Implementation constraints: one `ZStack` root with the sky, sun and skyline as persistent
siblings under a content layer switched on `AppFlow.screen`; no `NavigationStack` for these
screens. Animate only `opacity`, `scaleEffect`, `offset`, `position` and `frame` of the
sun. No `blur`, `mask` or `drawingGroup` over the camera. The log overlay and fps readout
move behind a "Debug" toggle in settings (default on in dev builds).

## 7. Screen flow

State lives in `Core/Sources/Core/UI/AppFlow.swift` (pure Swift, tested on Windows):

```swift
public enum Screen: UInt8, Sendable { case launch, menu, settings, practiceBriefing, countdown, match, results, pause, lobby, sync, dead }
public enum FlowEvent: Sendable { case launchFinished, setUseCount(Bool), tapPractice, tapHost, tapJoin, tapSettings, tapBack, tapStart, cameraReady, countdownFinished, roundEnded, tapAgain, tapMenu, tapPause, tapResume, tapLeave, allSynced, died, respawned, hostLost }
public enum TransitionKind: UInt8, Sendable { case none, sunSlide, sunSlideBack, dusk, dawn, scrimIn, scrimOut, cut }
public struct FlowStep: Sendable { public var to: Screen; public var kind: TransitionKind }
public struct AppFlow: Sendable {
    public private(set) var screen: Screen            // starts .launch
    public private(set) var settingsReturn: Screen    // .menu or .pause
    public private(set) var useCount: Bool            // result of the vote (§7.1); set by .setUseCount
    public mutating func handle(_ e: FlowEvent) -> FlowStep?   // nil = event ignored in this state
}
public struct SunPose: Sendable { public var x: Float; public var y: Float; public var diameterPt: Float }  // x, y: fraction of screen
public func sunPose(for s: Screen) -> SunPose?        // nil on camera screens
```

| From | Event | To | Transition | Sound |
|---|---|---|---|---|
| launch | `launchFinished` (2000 ms or tap) | menu | sunSlide | `ui_whoosh` |
| menu | `tapPractice` | practiceBriefing | sunSlide | `ui_tap`, `ui_whoosh` |
| menu | `tapSettings` | settings | sunSlide | same |
| menu | `tapHost` / `tapJoin` (Phase 3) | lobby | sunSlide | same |
| settings | `tapBack` | `settingsReturn` | sunSlideBack (to menu) or scrimIn (to pause) | `ui_back` |
| practiceBriefing | `tapBack` | menu | sunSlideBack | `ui_back` |
| practiceBriefing | `tapStart` then `cameraReady`, `useCount` true | countdown | dusk | `ui_confirm` |
| practiceBriefing | `tapStart` then `cameraReady`, `useCount` false | match (STANDOFF) | dusk | `ui_confirm` |
| lobby | `tapBack` | menu | sunSlideBack | `ui_back` |
| lobby | `tapStart` (Phase 3) | sync | dusk | `ui_confirm` |
| sync | `allSynced`, `useCount` true | countdown | cut | — |
| sync | `allSynced`, `useCount` false | match (STANDOFF) | cut | `cock` |
| countdown | `countdownFinished` (2400 ms) | match | cut | `count_tick` x3, `count_draw` |
| match | `tapPause` | pause | scrimIn | `ui_tap` |
| pause | `tapResume` | match | scrimOut | `ui_back` |
| pause | `tapSettings` | settings | scrimOut then sunSlide over a dawn-less sky at 100 % | `ui_tap` |
| pause | `tapLeave` | menu | dawn | `ui_back` |
| match | `roundEnded` | results | scrimIn | `sting_results` |
| match | `died` (Phase 3) | dead | scrimIn | `sting_down` |
| dead | `respawned` | match | scrimOut | `cock` |
| results | `tapAgain`, `useCount` true | countdown | scrimOut | `ui_confirm` |
| results | `tapAgain`, `useCount` false | match (STANDOFF) | scrimOut | `ui_confirm` |
| results | `tapMenu` | menu | dawn | `ui_back` |
| any camera screen | `hostLost` | menu | dawn | `ui_back` |

Events arriving while a transition runs are queued (at most 1, newest wins); taps on
buttons are disabled during a transition.

### 7.1 Match start: voted count or first shot (decided 2026-11-16)

| Item | Rule |
|---|---|
| Vote | Each player has one toggle in the lobby, default off. `useCount` = votes for a count > half of the connected players (T; a tie means no count). The host computes it when Start is tapped and sends it with the match state. Practice Range: the briefing toggle is the whole vote |
| With a count | COUNTDOWN as `PLAN.md` §10.2: "3", "2", "1" at 0 / 800 / 1600 ms, "DRAW" and weapons live at 2400 ms. A thumb drop before 2400 ms fires nothing |
| Without a count | New match state STANDOFF between SYNC and LIVE: weapons are live for everyone at once, with no signal. The first accepted shot by any player moves the match to LIVE; that shot counts, and the match clock (or the 60 s practice round) starts at its timestamp |

| From | To | Condition |
|---|---|---|
| SYNC | COUNTDOWN | all synced AND `useCount` |
| SYNC | STANDOFF | all synced AND NOT `useCount` |
| COUNTDOWN | LIVE | 2.4 s elapsed |
| STANDOFF | LIVE | first accepted shot from any player |

This changes `PLAN.md` §10.2 (which has COUNTDOWN always) and §13.1; those sections are
the hub session's to update. `MatchStateMachine` in `Core` owns STANDOFF; `AppFlow` only
picks the screen.

## 8. Audio

All files are generated by `tools/make_audio.py` (new; Python standard library `wave`,
`math`, `random`, `struct`; fixed seeds) into `App/Resources/Audio/`, mono 44,100 Hz
16-bit WAV, committed. Nothing is sampled from any recording, game or film, so no licence
applies. Loudness is normalised by the script to the peak listed; "Vol" is the playback
gain. Played with `AVAudioEngine` from `App/Audio/AudioPlayer.swift`, two mixer buses
(`effects`, `ambience`) with the settings sliders (defaults 1.0 and 0.6).
`AVAudioSession` category `.ambient` (obeys the silent switch, mixes with the user's
music). Haptics (`PLAN.md` §1A.6) are independent of it.

| File | Length s | Peak dBFS | Vol | Recipe | Plays |
|---|---|---|---|---|---|
| `Sfx/shot.wav` | 0.28 | -1 | 0.55 | White noise burst, 2 ms attack, exp decay tau 45 ms, band-pass 900–5000 Hz; plus sine sweep 180 -> 60 Hz, tau 60 ms; hard-clip at 0.9 | Every shot |
| `Sfx/ricochet.wav` | 0.45 | -6 | 0.30 | Sine sweep 2400 -> 900 Hz with 14 Hz vibrato, tau 150 ms | Miss (`kind == .none`) |
| `Sfx/hit.wav` | 0.14 | -3 | 0.60 | Noise low-passed 600 Hz tau 30 ms + sine 140 Hz tau 50 ms | Target or player hit |
| `Sfx/bull.wav` | 0.50 | -3 | 0.70 | `hit` + bell: sines 1318 and 1976 Hz, tau 180 ms | Centre ring |
| `Sfx/cock.wav` | 0.18 | -6 | 0.40 | Two clicks 70 ms apart: 3 ms noise bursts band-passed 2–6 kHz, second 3 dB louder | Reload, respawn |
| `Sfx/dry.wav` | 0.06 | -9 | 0.35 | One click as above, 1.5–4 kHz | Dry fire |
| `Sfx/hurt.wav` | 0.22 | -3 | 0.60 | Sine 90 Hz tau 80 ms + noise low-passed 300 Hz | Hit taken |
| `Ui/ui_tap.wav` | 0.05 | -12 | 0.50 | Wooden knock: sine 420 Hz tau 12 ms + 2 ms noise | Any button down |
| `Ui/ui_confirm.wav` | 0.30 | -9 | 0.50 | Spur jingle: 5 sines 3.1–5.4 kHz, random onsets within 60 ms, tau 70 ms | Start, Again |
| `Ui/ui_back.wav` | 0.08 | -12 | 0.45 | `ui_tap` at 300 Hz | Back, Resume, Leave |
| `Ui/ui_whoosh.wav` | 0.40 | -15 | 0.35 | Noise, band-pass centre sweeping 400 -> 1600 -> 600 Hz, sine-window envelope | Sun slide |
| `Ui/count_tick.wav` | 0.10 | -6 | 0.60 | Sine 660 Hz tau 30 ms | "3", "2", "1" |
| `Ui/count_draw.wav` | 0.35 | -3 | 0.70 | Sine 990 Hz tau 90 ms + `cock` layered at 0 ms | "DRAW" |
| `Music/sting_launch.wav` | 1.60 | -3 | 0.60 | Karplus-Strong plucked string: E2 at 0 ms, B2 at 180 ms, E3 at 360 ms, then G#3–B3 double stop at 620 ms; sine "whistle" E5 -> F#5 slide 900–1500 ms with 5.5 Hz vibrato; 300 ms fade | Launch, at 100 ms |
| `Music/sting_results.wav` | 1.20 | -3 | 0.60 | Plucks E3, G#3, B3, E4 at 110 ms spacing, last rings | Results in |
| `Music/sting_down.wav` | 1.00 | -3 | 0.55 | Plucks E3, D3, B2 at 160 ms spacing | Death |
| `Ambience/desert_loop.wav` | 30.0 | -18 | 0.60 (bus) | Wind: pink noise, low-pass cutoff wandering 250–700 Hz on a 0.07 Hz LFO, amplitude on a 0.11 Hz LFO; hawk cry (sine 2.6 -> 1.9 kHz, 0.5 s, -12 dB) at 7.0 s and 21.5 s; first and last 1.0 s cross-faded so the loop is seamless | Loops on all sky screens; fades out 500 ms in dusk, in 500 ms in dawn |

These replace the FletchFlow export of `PLAN.md` §14.1 for `shot`, `hit`, `bull`, `miss`
(now `ricochet`) and `cock`; that export script is no longer needed for Phase 2. Sounds
are preloaded into `AVAudioPCMBuffer`s at launch; `shot` has 4 player nodes for overlap.

## 9. Accessibility

| Item | Rule |
|---|---|
| Reduce Motion | `@Environment(\.accessibilityReduceMotion)`; variants in §5 and §6. No offset, scale or tracking animation when on |
| Text size | Menu text scales as in §2, capped; any button label that would wrap shrinks with `minimumScaleFactor(0.8)`. HUD is fixed size |
| Contrast | Computed WCAG ratios: `cream` on `plum` 11.1:1; `cream` on the sky at y 0.30 (`#A13B32`) 5.9:1; `cream` on `ember` 3.3:1; `cream` on `sun` below 2:1; `night` on `ember` 5.0:1; `night` on `sun` 10.4:1; `night` on `cream` 16.8:1. Rule: text drawn straight on the sky is `cream` above y 0.45 and `night` below it; text on buttons and rows follows §2. The one exception is the launch wordmark (§4) |
| Colour-blind | "Shapes on markers" setting (§5), stored in `UserDefaults` key `markerShapes`, default false; applies to markers, roster and own-colour disc. HP uses length and a number, never colour alone |
| VoiceOver | Every button has a label equal to its text; HUD items are one combined element "Health n, rounds n". Not usable for aiming; no further work in v1 |
| Touch targets | >= 44 x 44 pt everywhere; primary buttons 56 pt high, in the lower 65 % of the screen |

## 10. Build order (riskiest first, because each check costs a cloud build and an install)

| Pass | Contents | Checked on the phone |
|---|---|---|
| 1 | `tools/make_audio.py` and its WAVs (listen on the laptop first); fonts bundled; `Theme`; sky, sun, finger gun, skyline; `launch` and `menu` with the sun-slide between them; `AppFlow` in `Core` with tests; `uiTransitionMs` etc. in `Tuning`; `practiceBriefing` with the dusk into the existing camera view; HUD drawn with fake values (HP 72, 4 of 6 rounds) | Fonts load (not the system fallback), launch timing, sun slide smoothness, dusk with a live camera, HUD legibility in a bright and a dim room, fps |
| 2 | Settings restyle, pause, countdown, results, HUD micro-animations driven by a debug button, ambience loop and all UI sounds, Reduce Motion variants | Remaining criteria of §11 |
| 3 (Phase 3) | Lobby, sync, dead, marker glyphs | With multiplayer |

Pass 1 goes first because it holds every unknown: custom font registration through
XcodeGen, hand-drawn shapes that have never been seen rendered, a spring animation over
`ARView`, and the audio session next to ARKit.

## 11. Acceptance criteria

- `swift test --package-path Core`: every row of the §7 table has a test; an event not in the table returns `nil`.
- The log line `fonts_loaded` reports all 3 PostScript names present on the iPhone 12.
- Launch: from first frame to the menu fully drawn is 2.45 s ± 0.1 s untapped (2000 + 450), measured from `Log` events `launch_start` and `menu_shown`; a tap at 0.5 s gives `menu_shown` within 0.6 s of the tap.
- Menu-to-menu transition: `uiTransitionMs` ± 50 ms between `transition_start` and `transition_end`; frame rate >= 58 fps during it (no camera running).
- Dusk and every scrim over the camera: render stays >= 55 fps (the plan's target), minimum over 10 runs, from `FpsMeter`.
- HUD cost: with the HUD shown and the debug button firing 5 pip animations a second for 10 s, render >= 55 fps.
- A change to `uiTransitionMs` in `tools/tuning.json` changes the measured transition within 3 s, without a rebuild.
- Silent switch on: no sound from any screen; shot haptic still fires. Silent switch off with music playing in another app: the music keeps playing.
- `tools/make_audio.py` run twice gives byte-identical files; every file's length is within 10 ms and its peak within 0.5 dB of §8.
- Reduce Motion on: no view changes position or scale during launch, transitions or countdown (checked by eye against §6), and the flow timings above still hold within 0.2 s.
- Match start: with `useCount` false, 0 countdown digits are drawn and the round timer's first tick is within 50 ms of the first shot's timestamp (from `Log`); with it true, a thumb drop at 1.0 s fires nothing and one at 2.5 s fires.
- Largest allowed text size: no label is clipped or overlaps on the menu, settings and briefing screens.
- HUD legibility: HP number and pips readable at arm's length against a white wall and a dark doorway (the user's judgment, both yes).
- One-handed reach: every button on `menu`, `practiceBriefing`, `results` and `pause` is tappable with the thumb of the hand holding an iPhone 12 (the user's judgment).

## 12. Still open

| # | Item | Default until decided |
|---|---|---|
| 1 | Final wording of the caption "DRAW AT HIGH NOON" and menu labels | As written here |
| 2 | Whether the hand-drawn finger gun and skyline look good enough rendered, or need redrawing as proper vector art | Shapes of §3; judged after pass 1 |
| 3 | Whether sounds synthesised from the §8 recipes are good enough, or CC0 recordings are wanted for `shot` | Synthesised; judged by ear after pass 1 |
| 4 | Self view drawing in gun mode | Waits on F5 (`PLAN.md` §15 #9) |
| 5 | Killcam, bow reticle and scoreboard styling | Specified with their phases |
| 7 | Launch wordmark colour: `cream` with the hard shadow (as in the mock-up), or `night` like the silhouettes (5.0:1, no shadow needed) | `cream`; judged after pass 1 |
| 8 | Vote rule for the count: strict majority, or any one player, or the host decides | Strict majority, tie = no count |
| 9 | STANDOFF with no time limit: whether an idle standoff should ever end by itself | No limit |
| 6 | Debug readout (fps, tuning revision) placement once the HUD occupies the top left | Below the ammunition row, behind the Debug toggle |
