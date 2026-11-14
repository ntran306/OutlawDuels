# OutlawDuels — PLAN

AR combat game for iPhone. Players stand in the same real room, on the same Wi-Fi.
Gun players aim a finger gun through the rear camera and fire by dropping the thumb.
Bow players (second) aim the phone and draw with a fist seen by the selfie camera.
Hits are decided on the shooter's phone against the other phones' tracked positions.

Written 2026-11-09. Predecessor and algorithm source: `D:\Projects\FletchFlow` (desktop
Python prototype, branch `dev`). Every constant quoted from it names its source file.

Legend used throughout:

- **(T)** = tunable; the number is the starting value.
- **(U)** = unverified on a device or against current documentation. Each (U) is covered
  by a feasibility test in §4 or a check in §16.
- **(P)** = ported unchanged from FletchFlow.

---

## 1. Settled decisions

| Topic | Decision |
|---|---|
| Dev machine | Windows 11 laptop. Builds run on a GitHub Actions macOS runner; the old Mac cannot build (§1A.1). |
| Test devices | iPhones only. First test phone: iPhone 12 on iOS 26.6.1. |
| Engine | **Native Swift, decided 2026-11-13** (§1A.2): ARKit + RealityKit, Network.framework, Core Haptics, MediaPipe Tasks. The user wants to learn Swift. |
| Order | Gun mode first, bow second. |
| Shared coordinate frame | Every client scans a marker on the host's screen (§6). |
| Hit decision | Shooter's phone: ray through a 0.25 m sphere, target in frame, >= 30 % people-mask pixels at the target's range, excluding the shooter's own hand (§8). Host only sanity-checks and applies damage. |
| Network | One phone hosts over the LAN with Network.framework (UDP 7777 plus TCP 7778, §10). No dedicated server. |
| Modes for testing | `PracticeRange` (with calibration) and `TeamDeathmatch`. |
| Killcam | 5 s from both points of view on a kill (§11). |
| Rankings | Behind `ILeaderboardService`; backend swappable (§12). |
| Repo | `D:\Projects\OutlawDuels`, new, separate from FletchFlow. |

Not settled: see §15 (Open decisions).

---

## 1A. Design update, 2026-11-13

Decisions made by the user after the first draft. **Where this section conflicts with a
later section, this section wins.** The engine was chosen on 2026-11-13 (§1A.2, native
Swift) and the later sections were rewritten to match; where a later section still names
Unity, C# or Netcode it is a leftover to fix.

### 1A.1 Hardware and builds

| Item | Value | |
|---|---|---|
| Build machine | **Decided 2026-11-13:** GitHub Actions macOS runner (§2.1), unsigned `.ipa` | The spare Mac is out: it runs macOS 10.15 (Catalina) and Software Update offers nothing newer. Catalina's ceiling is Xcode 12.4, and the phone's iOS 26.6.1 needs Xcode 26 (U). |
| Install path | **Decided 2026-11-13:** Sideloadly on the Windows laptop signs the `.ipa` with a free Apple ID and installs over USB | Already installed. Free signing expires after 7 days (re-sign weekly), and the free account limits active apps and capabilities (U: 3 apps). The phone needs Developer Mode on. No debugger: debug from logs. |
| Release path | Apple Developer Program (US$99/year) when the user wants to release | Replaces the 7-day expiry with TestFlight. Not needed for development. |
| Spare Mac | Not a build machine | Revisit only if a Mac that runs macOS Sequoia 15.6 or newer (U) becomes available |
| Test phone | iPhone 12 (A14, no LiDAR), iOS 26.6.1 | |
| Minimum device | iPhone 12, iOS 17.0 | (T) replaces "iPhone 11" in §2 |
| Windows laptop | Editing, planning, and `swift test` on the pure-Swift `Core` package (§3, §13.2) | (U) the Swift Windows toolchain builds it; see §16 |

A macOS virtual machine on the Windows laptop is ruled out: Apple's licence does not allow
it, and the iPhone simulator has no camera or AR, so it could not test this game.

### 1A.2 Engine: native Swift, decided 2026-11-13

| Item | Value |
|---|---|
| Decision | Native Swift. The user chose it to learn Swift. Unity is dropped; §2, §3, §5, §6, §10, §11, §12, §13, §14.2 and §17 were rewritten on this date. Algorithms, constants, state machines and feasibility questions are unchanged. |
| Stack | SwiftUI shell, ARKit + RealityKit (`ARView`), Network.framework, Core Haptics, MediaPipe Tasks (CocoaPods), Swift Testing |
| What it costs | No Android. No Xcode on the user's machine: no previews, no debugger, and compile errors appear only in the cloud build or in `swift test` on the Core package. Every device change goes through the §2.1 loop, 15–25 min (T). |
| How the cost is limited | All logic lives in the pure-Swift `Core` package (§3), tested on Windows in seconds. The app target holds only code that must touch Apple frameworks. |
| What it gives | Direct access to people segmentation with depth, collaborative sessions and Core Haptics. |

Networking (§10) uses Network.framework with the QR join. MultipeerConnectivity is a
possible later replacement that might remove the need for shared Wi-Fi (U); it is not
planned.

### 1A.3 Health, damage, ammunition

| Constant | Value | |
|---|---|---|
| `MAX_HP` | 100 | |
| `GUN_BASE_DAMAGE` | 10 | (T) replaces `GUN_DAMAGE` 25 in §8 |
| `BOW_BASE_DAMAGE` | `50 + 50 * firePower` | (T) unchanged from §9.3 |
| `RESIST_FLOOR` | 0.5 | (T) damage multiplier at 0 HP |
| `GUN_MAG_SIZE` | 6 | (T) |
| `RELOAD_HAND_OFF_MS` | 300 | (T) equals `GUN_HAND_LOST_MS` |
| Fire rate | No limit beyond the trigger's own re-cock rule (`GUN_MIN_REFIRE_MS` 150, §7.3) | "as fast as the player can handle" |

Resistance, applied by the host when it accepts a hit:

```
multiplier = RESIST_FLOOR + (1 - RESIST_FLOOR) * hpBefore / MAX_HP      1.0 at 100 HP, 0.5 at 0 HP
damage     = max(1, round_half_up(baseDamage * multiplier))
```

With the starting values a full-health player dies to the 14th gun hit (10, 10, 9, 9, 8,
8, 7, 7, 7, 6, 6, 6, 5, 5), not the 10th.

Magazine (gun only; the bow has unlimited arrows):

| From | To | Condition | Effect |
|---|---|---|---|
| LOADED(n), n >= 2 | LOADED(n-1) | `GunTrigger` emits a shot | Shot fires |
| LOADED(1) | EMPTY | `GunTrigger` emits a shot | Shot fires; event `empty` |
| EMPTY | EMPTY | `GunTrigger` emits a shot | No shot; event `dry` (click sound, dry-fire haptic) |
| LOADED(n) with n < 6, or EMPTY | LOADED(6) | Tracker reports no hand for >= 300 ms | Event `reload` (cock sound) |

Taking the hand out of frame is the reload, as in an arcade light-gun game. It also
reloads a partly used magazine.

### 1A.4 Bow: accuracy circle, walls

```
a         = clamp(drawHeldSec / BOW_FULL_ACCURACY_S, 0, 1)     drawHeldSec = time since NOCKED -> DRAWN (§9.2)
spreadDeg = BOW_SPREAD_MAX_DEG * (1 - a)
```

| Constant | Value | |
|---|---|---|
| `BOW_SPREAD_MAX_DEG` | 6.0 | (T) half-angle of the cone at the start of the draw |
| `BOW_FULL_ACCURACY_S` | 1.2 | (T) |
| `BOW_GOLD_DEG` | 0.5 | (T) the circle turns gold at or below this |

The arrow leaves along the aim direction deflected by a uniformly random point in the disc
of angular radius `spreadDeg`. The reticle is a circle whose on-screen radius is the
projection of `spreadDeg`: large at first, shrinking, gold when fully accurate. Arrow speed
still comes from `firePower` (§9.3).

Arrows pass through walls by design: bow hits use condition 1 of §8 only. This replaces
the "fallback" wording in §9.4. Whether the bow player gets a see-through view still
depends on F4.

### 1A.5 Screen layout during play

| Element | Position | Content |
|---|---|---|
| Camera view | Full screen | Rear camera passthrough |
| Health and ammunition | Top left | HP bar 0–100; gun: 6 pips; bow: infinity mark |
| Menu | Top right, 44 x 44 pt | Three-bar button; opens pause, leave, settings |
| Self view | Bottom right, 90 x 120 pt (T) | See below |
| Reticle | At the aim point | Gun: dot. Bow: accuracy circle of §1A.4 |
| Low-health effect | Screen edges | Red vignette, opacity `0.6 * (1 - hp / 100)^2` (T) |

Nothing else is drawn except tracers, hit markers and teammate name tags.

Self view (U): with the rear camera tracking the room, ARKit supplies the user's face
position and expression (`userFaceTrackingEnabled`, `ARFaceAnchor`) but no front-camera
picture. In gun mode the corner therefore shows a simple drawn face driven by the face
anchor, or is hidden. Feasibility test F5: on the iPhone 12, confirm
`ARWorldTrackingConfiguration.supportsUserFaceTracking` is true and that enabling it keeps
render >= 55 fps with hand tracking on. In bow mode the front camera is the live feed (F4).

### 1A.6 Haptics

| Event | Pattern | |
|---|---|---|
| Shot fired | One transient: intensity 0.8, sharpness 0.9 | (T) |
| Hit taken | Continuous 0.30 s: intensity `0.6 + 0.4 * (1 - hpAfter / 100)`, sharpness 0.3 | (T) stronger at low health |
| Dry fire | One transient: intensity 0.3, sharpness 0.5 | (T) |

(U) whether the vibration disturbs hand tracking or position tracking; measured in M1.

### 1A.7 Killcam clips

Unchanged from §11: memory only, dropped after playback, no save to the camera roll in
v1. Players who want a clip use the iPhone's own screen recording. Saving to Photos is
listed in §18.

### 1A.8 Network fallback

| Order | Path | |
|---|---|---|
| 1 | All phones on the same Wi-Fi | As §10 |
| 2 | Host turns on Personal Hotspot; clients join it; same join QR | (U) host address on its own hotspot, expected 172.20.10.1 |

Networks that block phone-to-phone traffic are out of scope for now.
MultipeerConnectivity may make both paths unnecessary (U), but is not planned (§1A.2).

### 1A.9 Tracking other players

| Layer | Method | Status |
|---|---|---|
| Position source | Each phone tracks itself and sends its pose (§5, §10) | Kept. The only method that works through walls, which the bow needs. |
| Frame alignment | Marker sync (§6) **or** ARKit collaborative session (`isCollaborationEnabled`, `ARParticipantAnchor`) | F1 now measures both and keeps the one with the lower p95 error. Apple advises up to 4 participants for collaborative sessions, so matches above 2 v 2 keep the marker. |
| At the shot | Depth-aware people check near the predicted position (§8 condition 3) | Kept |
| Between packets | Kalman prediction (§5.1) | Kept |
| Ultra-wideband ranging | Not used | Direction between phones needs a stationary target |

### 1A.10 Feature sub-plans

Detailed plans per feature are written in separate sessions; this file stays the
high-level plan. None has been started. Candidates, in suggested order: shot feedback and
HUD (§1A.5, §1A.6); magazine and reload (§1A.3); live tuning of (T) constants without a
rebuild; frame alignment comparison (§1A.9); bow accuracy and scope view (§1A.4, §9.4).

---

## 2. Toolchain and versions

| Item | Pin | Note |
|---|---|---|
| Xcode | 26.x, the newest the CI runner image carries | (U) read the exact version from the runner image, write it here and in `.github/workflows/ios.yml`. iOS 26.6.1 on the test phone needs Xcode 26 to build for it. |
| Swift | 6.2 (the version in Xcode 26), Swift 6 language mode | (U) `Core` uses `swift-tools-version: 6.0`. Strict concurrency is on from day 1. |
| Deployment target | iOS 17.0 | (T) set from the oldest supported phone, §15 #4. People segmentation needs A12 or newer. |
| System frameworks | SwiftUI, ARKit, RealityKit (`ARView`), Network, CoreHaptics, AVFoundation, Vision, CoreImage, ImageIO | No third-party package for these. |
| MediaPipe Tasks Vision | CocoaPod `MediaPipeTasksVision` 0.10.x | (U) exact patch and that it links under Swift 6; same `hand_landmarker.task` model as FletchFlow. |
| CocoaPods | 1.16.x on the runner | (U) exact patch. `Podfile.lock` is committed. |
| XcodeGen | 2.4x on the runner | (U) exact patch. `project.yml` generates `OutlawDuels.xcodeproj` on the runner, because no Xcode project can be authored on Windows. The generated project is not committed. |
| Test framework | Swift Testing (`import Testing`) in `Core/Tests/CoreTests/` | XCTest only if Swift Testing is missing from the Windows toolchain (U). |
| Windows toolchain | Swift 6.2 release from swift.org for Windows, with Visual Studio Build Tools and the Windows SDK | (U) it builds and tests `Core`; see §16. |
| QR | Encode with CoreImage `CIQRCodeGenerator`; decode with Vision `VNDetectBarcodesRequest` | Replaces ZXing.Net. |
| Orientation | Portrait, locked | (T) one hand holds the phone, the other makes the gun. |
| Frame rate | `ARView` at 60 fps (`preferredFramesPerSecond = 60`) | |
| Bundle id | `com.ntran306.outlawduels` | (T) Sideloadly rewrites it for free signing. |
| Info.plist keys | `NSCameraUsageDescription`, `NSLocalNetworkUsageDescription`, `UIRequiredDeviceCapabilities` = `arkit` | Set in `project.yml`. |

Every dependency is pinned: `Podfile.lock` and, if `Core` ever gains a package dependency,
`Package.resolved`, both committed. No floating versions.

### 2.1 Builds without a Mac

**Development path, decided 2026-11-13.** Workflow `.github/workflows/ios.yml`, run on every
push to `main` and on manual dispatch.

| Job | Runner | Steps | Expected time |
|---|---|---|---|
| 1 `core-tests` | `ubuntu-latest` | Install the Swift 6.2 toolchain, `swift test --package-path Core` | 2–4 min (T) |
| 2 `ios-ipa` (needs 1) | `macos-26` (U: label) | Select Xcode 26.x; `brew install xcodegen`; `xcodegen generate`; `pod install`; `xcodebuild archive -workspace OutlawDuels.xcworkspace -scheme OutlawDuels -destination 'generic/platform=iOS' -archivePath build/OutlawDuels.xcarchive CODE_SIGNING_ALLOWED=NO`; copy the `.app` from the archive into `Payload/` and `zip -r OutlawDuels.ipa Payload`; upload artifact `OutlawDuels-ipa` (retention 7 days (T)) | 8–15 min (T) |

Pods and Swift package build products are cached with `actions/cache`, keyed on
`Podfile.lock`.

Install, on the Windows laptop: `tools/install.ps1` runs `gh run download --name OutlawDuels-ipa
--dir build\` for the latest successful run on `main`, then prints the path to open in
Sideloadly. Sideloadly signs it with the user's free Apple ID and installs it over USB.
Limits of free signing are in §1A.1. No Apple Developer Program, App Store Connect key or
TestFlight is needed for development.

Cost: GitHub gives 2,000 free minutes a month on private repos and bills macOS at 10x, so a
12-minute build uses 120 of them: about 16 device builds a month. Public repos are not
metered. Both figures (U) — check the current GitHub pricing page.

**Release path** (later, with the Apple Developer Program): the same job signs with an App
Store Connect API key stored as GitHub secrets (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`)
and uploads through `fastlane pilot` to TestFlight.

Because a device test takes 15–25 minutes (T) from push to running app, everything that can
run without a device must: all of `Core` is plain Swift with tests run on Windows by
`swift test` (§13.2).

---

## 3. Repo layout

```
D:\Projects\OutlawDuels\
  PLAN.md  CLAUDE.md
  .gitignore                      Xcode, Swift, Pods, build/, *.p8, *.mobileprovision
  .gitattributes                  LFS for *.png *.wav *.usdz *.task
  .github/workflows/ios.yml       the two jobs of §2.1
  project.yml                     XcodeGen spec: one iOS app target, deployment target 17.0
  Podfile                         pod 'MediaPipeTasksVision'
  tools/install.ps1               download the latest .ipa, print the Sideloadly step
  tools/export_fletchflow_audio.py   one-off WAV export, run with FletchFlow's venv (§14)
  Core/                           Swift package, no dependencies
    Package.swift                 swift-tools-version 6.0; library product "Core"
    Sources/Core/
      Math/         Vec2 Vec3 Quat Pose Ray FrameAlignment HitMath
      Filters/      KalmanCv1D KalmanCv2D KalmanCv3D OneEuroFilter Smoother2D
      Hands/        HandPoseSample PalmDepth HandReplayReader
      Gun/          GunGesture GunTrigger
      Bow/          BowDraw
      Combat/       ArrowSim
      Calibration/  GunCalibrator BowCalibrator CalibrationProfile
      Range/        Scoring
      Net/          Messages MessageCodec ServerClock PoseHistory Transport LoopbackTransport
      Match/        MatchStateMachine LifeStateMachine GameMode
      Replay/       KillcamClipHeader ClipChunker
      Services/     LeaderboardService LocalLeaderboardService
    Tests/CoreTests/              one test file per folder above
  App/                            the iOS app target; the only code that imports Apple frameworks
    OutlawDuelsApp.swift
    Tracking/       ARSessionController SharedFrame PeopleMask CoreBridging
    Hands/          MediaPipeHandTracker ReplayHandTracker NullHandTracker
    Weapons/        FingerGunWeapon BowWeapon HitTest
    Net/            NetworkHost NetworkClient MatchNetwork
    Modes/          PracticeRange TeamDeathmatch ModeRegistry
    Replay/         ClipRecorder ClipTransfer ClipPlayer
    Services/       Profile SupabaseLeaderboardService
    UI/             SwiftUI views, HUD, sync screen
    Haptics/        HapticsPlayer
    Resources/      hand_landmarker.task, Assets.xcassets (AR resource group "SyncMarkers"), Audio/, Art/
    Spikes/         throwaway feasibility screens F1–F4; deleted after §4 passes
```

### 3.1 Module dependency rule

`Core` imports `Foundation` only. It does **not** import `simd`, `ARKit`, `RealityKit`,
`Network`, `UIKit` or `CoreHaptics`, because those do not exist on Windows or Linux (U).
It has its own `Vec2`, `Vec3`, `Quat`, `Pose` and `Ray` (§12). `App/Tracking/CoreBridging.swift`
converts to and from `simd` and ARKit types at the boundary.

| App folder | May reference |
|---|---|
| `Tracking`, `Hands`, `Services`, `Haptics` | `Core` |
| `Weapons` | `Core`, `Tracking`, `Hands`, `Haptics` |
| `Net` | `Core` |
| `Replay` | `Core`, `Net`, `Tracking` |
| `Modes` | `Core`, `Weapons`, `Net`, `Replay`, `Services`, `Tracking` |
| `UI` | everything |

The App target is one Xcode target, so the compiler does not enforce the App rows; a review
checks them. `Core` is a separate package, so the compiler does enforce that it imports
nothing it should not.

`Core` holds every state machine, filter, formula, wire format and data shape in this plan.
It is the only place FletchFlow logic is ported to, and it is fully testable on Windows.

---

## 4. Feasibility tests (throwaway, before any milestone work beyond M0)

Each is one SwiftUI screen under `App/Spikes/`, installed on the iPhones through the §2.1
pipeline. F1 and F3 need two iPhones; the user has one (iPhone 12), so a second phone must
be borrowed for those two tests (U: whose).

| ID | Question | Method | Pass | Fail action |
|---|---|---|---|---|
| F1 | Do two phones agree on position after a marker sync? | Sync per §6. Put phone B on a tape mark 5.00 m from phone A. Each phone logs the other's position in the shared frame for 3 min while both are carried around and returned to their marks every 30 s. | Distance error median <= 0.15 m, p95 <= 0.25 m, at 0 and at 3 min. Sync takes <= 5 s per client. | Switch §6 to an ARKit collaborative session (`ARWorldTrackingConfiguration.isCollaborationEnabled`, `ARParticipantAnchor`, collaboration data sent through `session(_:didOutputCollaborationData:)`) (U). |
| F2 | Does hand tracking run fast enough beside AR? | AR session on, rear camera, MediaPipe hand landmarker fed 480x360 frames, people stencil on. Log rates for 5 min. | Hand results >= 25 Hz, capture-to-result latency p95 <= 60 ms, render >= 55 fps, on the oldest test iPhone. No `ProcessInfo.thermalState` of serious within 10 min. | Drop input to 320x240; if still failing, use Apple Vision `VNDetectHumanHandPoseRequest` and re-derive 2D thresholds (§7.6). |
| F3 | Does the depth-aware people check separate "visible" from "behind a wall" with the shooter's own hand in the way? | Phone A aims at a person holding phone B at 2, 5 and 8 m, 20 trigger pulls each, **always with the finger gun raised and the fingertip over the target**; then the same with the person fully behind a door frame, finger gun still raised over where they are. Log per pull: `count(G)`, `own`, `target`, `fraction`, obscured or not, and the human depth read at the target and at the hand. Repeat the hidden trials with human depth disabled to test the silhouette fallback. | Visible: condition 3 true on >= 90 % of pulls at 2 m and 5 m, >= 75 % at 8 m; `obscured` on <= 10 % of pulls. Hidden: condition 3 false on >= 95 % of pulls, with depth and with the fallback. Human depth at a person at 5 m reads within 1.25 m of the tape distance on >= 90 % of pulls; at the hand it reads < 1.0 m on >= 95 %. | Tune the §8 constants and stencil/depth resolution; if depth is too poor, use the silhouette fallback as the primary rule; if 8 m fails only, set `MAX_RANGE_M` = 6. |
| F4 | (Bow only; run before M5) Can the selfie camera feed and 6-DoF tracking run together? | `ARFaceTrackingConfiguration` with `isWorldTrackingEnabled = true` (check `ARFaceTrackingConfiguration.supportsWorldTracking` on the iPhone 12) (U). Walk a 2 m square, return to start. | Front camera frames >= 30 fps, loop-closure position error <= 0.10 m, world origin unchanged across a rear -> front camera switch (error <= 0.10 m). | Bow aims by gyroscope from a fixed stance; see §9.4. |

---

## 5. Coordinates, time and identifiers

- Units: metres, seconds, radians unless a field name says otherwise.
- ARKit axes: right-handed, +X right, +Y up, a camera looks along -Z. `RotY(t)` is a
  counter-clockwise rotation about +Y seen from above: `x' = x cos t + z sin t`,
  `z' = -x sin t + z cos t`. The yaw of a horizontal direction `n` is
  `yaw(n) = atan2(-n.x, -n.z)`, so `yaw(RotY(t) * (0, 0, -1)) = t` (a round-trip test in
  `Core`). The Unity-era plan used left-handed axes; every formula below uses these.
- **Local frame**: each phone's ARKit world. Gravity-aligned (+Y up) on every phone.
- **Shared frame**: origin at the sync marker centre at sync time, +Y up, +Z = the marker's
  outward normal projected onto the horizontal plane. Local and shared frames differ only
  by a yaw and a translation: `struct FrameAlignment { var yawRad: Float; var translationM: Vec3 }`
  with `p_shared = RotY(yawRad) * p_local + translationM`.
- **Time**: the host's clock, `ProcessInfo.systemUptime` on the host (seconds, `Double`).
  Messages carry it as `UInt32 serverTimeMs` (host uptime in milliseconds, wraps after 49.7
  days, so compared with wrap-safe subtraction). Hand samples carry the local
  `ARFrame.timestamp` (also seconds of uptime) and are converted when a shot is built.
  `Core/Net/ServerClock.swift` keeps the offset `serverTime = localUptime + offset`: on join
  the client sends 8 `ClockPingMsg` 100 ms apart, each pong gives
  `offset = tServer - (t0 + rtt/2)`, and the **median** is used; it re-estimates every 5 s
  (T) from 1 ping and moves the offset by at most 2 ms per update (slew, never a jump).
  Target accuracy +/- 5 ms (T)(U); the host's own offset is 0.
- **Player id**: `UInt8` slot 0–7 assigned by the host. `UUID playerGuid` persists on the
  device for reconnects and leaderboards.
- Max players: 8 (4 v 4) (T). Test target: 2–4 phones.

### 5.1 Smoothing: constant-velocity Kalman filters

Players move a lot, so all tracking smoothing uses a Kalman filter with a constant-velocity
model. This **replaces** FletchFlow's One Euro filter (`vision/smoothing.py`, parameters
`ONE_EURO_MIN_CUTOFF` 1.5 Hz, `ONE_EURO_BETA` 0.3, `ONE_EURO_D_CUTOFF` 1.0 Hz in
`config.py`). One Euro is still ported, but only as a comparison baseline selectable in the
Practice Range (§13.1).

One filter type, `Core/Sources/Core/Filters/KalmanCv1D.swift`, run independently per axis:

```
state      x = [p, v]                      position and velocity of one axis
predict    p' = p + v*dt ;  v' = v
           P' = F P F^T + Q                F = [[1, dt], [0, 1]]
           Q  = sigma_a^2 * [[dt^4/4, dt^3/2], [dt^3/2, dt^2]]     white-noise acceleration
update     y = z - p'                      innovation;  H = [1, 0]
           S = P'[0,0] + sigma_z^2
           K = P'[:,0] / S ;  x = x' + K*y ;  P = (I - K H) P'
gate       if y^2 > GATE_SIGMA^2 * S: skip the update (outlier); after GATE_MAX_SKIPS
           consecutive skips, re-initialise on the next measurement
init       p = z, v = 0, P = diag(sigma_z^2, V0^2)
```

`dt` is always the difference of measurement timestamps, never an assumed frame time.
`Vec2` and `Vec3` wrappers (`KalmanCv2D`, `KalmanCv3D`) hold one `KalmanCv1D` per axis.

| Signal | Units | Update rate | `sigma_z` (measurement) | `sigma_a` (process) | `V0` | Reset |
|---|---|---|---|---|---|---|
| Index fingertip on screen (§7.4) | viewport, 0..1 | tracker rate, ~30 Hz | 0.004 (T) (~2 px of a 480 px input) | 8 /s^2 (T) | 1 /s | hand lost > 300 ms |
| Remote player position (§8, name tags) | metres, shared frame | 20 Hz, on packet arrival | 0.01 m (T) | 4 m/s^2 (T) | 2 m/s | no packet for 3.0 s, or re-sync |
| Bow palm depth (§9.1) | metres | tracker rate, ~30 Hz | 0.02 m (T) | 6 m/s^2 (T) | 1 m/s | hand lost > 600 ms |

Shared constants: `GATE_SIGMA` 5 (T), `GATE_MAX_SKIPS` 3 (T).

The device's own pose is not filtered: ARKit already fuses camera and inertial data.

**Prediction between pose packets.** Remote poses are not delayed and interpolated; they
are predicted to the time they are needed.

| Query time `t` relative to the newest packet time `t_k` | Position used | Rotation used |
|---|---|---|
| `t <= t_k` (in the past, e.g. a shot's lookback time) | linear interpolation between the two stored filtered states that bracket `t`; history 1.0 s | slerp between the bracketing rotations |
| `t_k < t <= t_k + 250 ms` (`PREDICT_MAX_MS`, T) | `p + v * (t - t_k)` from the filter state | `q_k * exp(omega * (t - t_k))`, `omega` = angular velocity from the last two packets, low-passed with alpha 0.5 (T) |
| `t > t_k + 250 ms` | held at the 250 ms prediction; velocity treated as 0 | held |
| `t > t_k + 3.0 s` | player is DISCONNECTED (§10.4) | |

With packets at 20 Hz and typical LAN latency under 20 ms, a normal query predicts
50–70 ms ahead. Packets older than the newest one already applied are dropped.

**Fingertip latency.** The HUD reticle is drawn at the filter's prediction for the current
render time, capped at 80 ms (T) ahead of the last hand result. A shot never uses a
prediction: it uses the filtered estimate stored at the lookback sample's time (§7.3).

---

## 6. Shared frame: the sync marker

One scan both joins the match and aligns the frames.

The host's sync screen shows, in portrait:

| Element | Size on glass | Content |
|---|---|---|
| Tracking marker | 60 mm x 60 mm (T). Pixels = `60 / 25.4 * ppi`, with `ppi` from a model table in `Core/Math/DisplayTable.swift` (iPhone 12: 460 (U)), converted to points with `UIScreen.main.scale`. | Fixed image `App/Resources/sync_marker.png`, also in the asset catalog's AR resource group `SyncMarkers` with physical width 0.060 m, used by `ARImageTrackingConfiguration` / `ARWorldTrackingConfiguration.detectionImages`. |
| Join QR | 30 mm x 30 mm below the marker | `OD1|<hostIPv4>|7777|<matchId>` encoded with CoreImage `CIQRCodeGenerator`. |

The marker is a fixed image rather than the QR itself so ARKit can validate it at build
time; the QR only carries the address. Manual IP entry is the fallback for joining.

Procedure:

1. Host holds the phone at chest height, screen toward the clients, rear camera seeing the
   room (so its own tracking stays normal). Leaning it upright against something also works.
2. Client decodes the QR from `ARFrame.capturedImage` with Vision `VNDetectBarcodesRequest`
   at 5 Hz, connects.
3. Client's `ARImageAnchor` (session delegate `session(_:didUpdate:)`) reports the marker
   pose. Host streams its own device pose at 20 Hz.
4. Client collects samples for `SYNC_WINDOW_S` and solves `FrameAlignment`.

Solve, client side, per sample: marker pose `M_c` in client-local; host device pose `H_h`
in host-local at the same server time (interpolated); marker pose in host-local
`M_h = H_h * CAMERA_TO_SCREEN`. Yaw of a pose = `yaw(n)` (§5) of its normal `n`
projected on the horizontal plane. The host is the reference:
`host.alignment` maps host-local to shared using `M_h` averaged over the host's first sync;
`client.yawRad = yaw(M_h in shared) - yaw(M_c)`, `client.translationM = pos(M_h in shared) - RotY(client.yawRad) * pos(M_c)`.
Yaw is averaged on the circle, position by arithmetic mean.

| Constant | Value | |
|---|---|---|
| `SYNC_WINDOW_S` | 1.0 | (T) |
| `SYNC_MIN_SAMPLES` | 20 | (T) |
| `SYNC_MAX_YAW_STD_DEG` | 1.0 | (T) 1 degree is 8.7 cm at 5 m |
| `SYNC_MAX_POS_STD_M` | 0.01 | (T) |
| `SYNC_HOST_MAX_SPEED_MS` | 0.05 | (T) host must hold still |
| `SYNC_MARKER_MAX_TILT_DEG` | 30 from vertical | (T) keeps the normal's horizontal projection well defined |
| `SYNC_RANGE_M` | 0.3–0.8 | (T) client distance from the marker |
| `CAMERA_TO_SCREEN` | translation (0.02, -0.06, 0) m, rotation 180 deg about Y | (T)(U) one value for all models to start; error is a few cm |

A sync is accepted when sample count, both standard deviations and the host speed limit all
pass; otherwise the window restarts. Re-sync is offered between rounds and forced by the
tracking-loss rule in §10.4.

All of §6 is (U) until F1 passes.

---

## 7. Finger gun

### 7.1 Hand tracker

`IHandTracker` (shape in §12) has three implementations:

| Class | Where | Use |
|---|---|---|
| `MediaPipeHandTracker` | `App/Hands/`, calls MediaPipe Tasks `HandLandmarker` directly from Swift | Device. Live-stream mode (`detectAsync`), 1 hand, confidences 0.5 / 0.5 / 0.5 (P, `config.py` `MIN_*_CONFIDENCE`). |
| `ReplayHandTracker` | `App/Hands/` | Plays `HandPoseSample` JSON-lines files on the phone; `Core/Hands/HandReplayReader.swift` reads the same files in tests on Windows. |
| `NullHandTracker` | `App/Hands/` | Menus. |

Input: `ARFrame.capturedImage` (a `CVPixelBuffer`) scaled to BGRA 480x360 (T), at most 30 Hz,
passed to MediaPipe as `MPImage(pixelBuffer:orientation:)` with `timestampInMilliseconds` from
`ARFrame.timestamp`, and tagged with the camera pose of that frame. Landmarks come back
normalised with a top-left origin; they are converted to viewport units with a bottom-left
origin through `ARFrame.displayTransform(for: .portrait, viewportSize:)` before leaving
`App/Hands/`.

### 7.2 Shape measures (P, `gun/gesture.py`)

From the 21 MediaPipe **world** landmarks `w` (metres), indices as in `config.py`
(`WRIST` 0, `THUMB_TIP` 4, `INDEX_MCP` 5, `INDEX_PIP` 6, `INDEX_DIP` 7, `INDEX_TIP` 8,
`MIDDLE_MCP` 9, `RING_MCP` 13, `RING_TIP` 16, `PINKY_MCP` 17, `PINKY_TIP` 20):

```
ref      = |w0 - w9|                                   reject the frame if ref < 1e-4 m
trigger  = dist(w4, segment w5->w8) / ref              cocked ~0.68, pulled ~0.18
straight = |w8 - w5| / (|w6-w5| + |w7-w6| + |w8-w7|)   1.0 = straight
curl     = mean(|w16-w0| / |w13-w0|, |w20-w0| / |w17-w0|)   curled ~0.9, open ~1.9
```

The thumb is measured against the index segment with the parameter clamped to [0, 1], not
the infinite line. Port: `Core/Sources/Core/Gun/GunGesture.swift`, function `GunGesture.measure(_ sample: HandPoseSample)`.

These are ratios of 3D distances, so they do not depend on which way the hand faces. They
were tuned with the finger pointing at a webcam; here the camera sees the back of the hand.
The thresholds below are therefore (U) for this viewpoint and FletchFlow's own comment
already marks them unvalidated on real hands. M1 logs every reading.

### 7.3 Trigger state machine (P, `gun/trigger.py`, constants from `config.py`)

Frame counts assume a 30 Hz tracker. At another rate use
`frames = max(1, round(ms * rateHz / 1000))` with the millisecond column.

| Constant | Value | ms at 30 Hz |
|---|---|---|
| `GUN_TRIGGER_PULL` | 0.30 | |
| `GUN_TRIGGER_RESET` | 0.42 | |
| `GUN_TRIGGER_GLITCH` | 2.0 | |
| `GUN_STRAIGHT_ON` / `GUN_STRAIGHT_OFF` | 0.85 / 0.72 | |
| `GUN_CURL_ON` / `GUN_CURL_OFF` | 1.40 / 1.65 | |
| `GUN_ARM_FRAMES` | 3 | 100 |
| `GUN_PULL_FRAMES` | 2 | 67 |
| `GUN_RECOCK_FRAMES` | 2 | 67 |
| `GUN_MIN_REFIRE_MS` | 150 | |
| `GUN_SHAPE_LOST_FRAMES` | 6 | 200 |
| `GUN_HAND_LOST_MS` | 300 | |
| `GUN_AIM_HISTORY` | 15 samples | ~500 |
| `GUN_AIM_LOOKBACK_MAX_MS` | 250 | |
| `GUN_FINGER_MIN_M` | 0.04 | |

`shapeOn = straight >= 0.85 AND curl <= 1.40`. `shapeOff = straight < 0.72 OR curl > 1.65`.

| From | To | Condition, per tracked frame | Output |
|---|---|---|---|
| NONE | COCKED | `shapeOn` AND `trigger >= 0.42` for 3 consecutive frames | event `cock` |
| COCKED | FIRED | `trigger <= 0.30` for 2 consecutive frames | `GunShot`, event `shot` |
| FIRED | COCKED | `trigger >= 0.42` for 2 consecutive frames AND >= 150 ms since the shot | event `cock` |
| COCKED or FIRED | NONE | `shapeOff` for 6 consecutive frames, OR no hand for > 300 ms | event `lost` |
| any | unchanged | `trigger > 2.0` (tracking spike): counts as "hand seen", advances and resets no counter | none |

Trigger travel for the HUD: `clamp((0.42 - trigger) / (0.42 - 0.30), 0, 1)`.

Lookback rule (P): a shot aims from the newest sample in the last 250 ms whose trigger is
in [0.42, 2.0] (fully cocked); failing that the oldest sample in the window; failing that
the current one. Dropping the thumb jerks the hand, so the firing frame is not used.

Port: `Core/Sources/Core/Gun/GunTrigger.swift`, struct `GunTrigger`, method `mutating func update(_ sample: HandPoseSample?, nowSec: Double) -> GunSnapshot`.
The two-hand pick logic of FletchFlow (`GUN_HAND_SWITCH_RADIUS` 0.15) is not ported: the
tracker runs with one hand.

### 7.4 Aim

The aim ray starts at the camera and passes through the index fingertip (landmark 8) as
seen on screen. What the fingertip covers on screen is what gets shot.

- Fingertip viewport position is smoothed with the constant-velocity Kalman filter of §5.1
  (`KalmanCv2D`, `sigma_z` 0.004, `sigma_a` 8 /s^2).
- Comparison baseline only: One Euro (P, `vision/smoothing.py`) with `min_cutoff` 1.5 Hz,
  `beta` 0.3, `d_cutoff` 1.0 Hz (`config.py` `ONE_EURO_*`; FletchFlow runs it on normalized
  coordinates, so the unit-dependent `beta` carries over to viewport units).
  `alpha(fc, dt) = 1 / (1 + (1 / (2*pi*fc)) / dt)`;
  `dx_hat = lerp(dx_prev, (x - x_prev)/dt, alpha(d_cutoff, dt))`;
  `fc = min_cutoff + beta * |dx_hat|`; `x_hat = lerp(x_prev, x, alpha(fc, dt))`.
  First sample and any sample with `t <= t_prev` pass through. Reset when the hand is lost.
  Port: `Core/Sources/Core/Filters/OneEuroFilter.swift`. Both conform to `Smoother2D` so the Practice Range
  can switch `SmootherKind { Kalman, OneEuro }` live.
- Each `AimSample` stores the fingertip viewport point **and the camera pose of its frame**.
  The shot ray is `Camera.ViewportPointToRay` evaluated with the lookback sample's pose.
- `AimMode` (T): `Fingertip` (default) or `ScreenCentre` (ray through viewport 0.5, 0.5;
  the finger only pulls the trigger). Switchable in the Practice Range.

FletchFlow's finger-direction solve and blend mapping (`gun/aim.py`, `GUN_POS_GAIN` 1.3,
`GUN_DIR_GAIN` 0.8, `GUN_DIR_MAX_DEG` 60) are **not** ported: they map a hand in front of a
fixed webcam onto a screen, which is a different problem.

### 7.5 Gun calibration (Practice Range)

Routine structure and statistics ported from `input/calibration.py`; step lengths from
`config.py` `CALIB_STEP_S` (2.0 s each for the hold steps).

| Step | Prompt | Duration | Collects |
|---|---|---|---|
| 1 | "Make a finger gun, thumb up" | 2.0 s | `trigger` samples (cocked) |
| 2 | "Drop your thumb and hold" | 2.0 s | `trigger` samples (pulled) |
| 3 | "Shoot the centre dot 5 times" | until 5 shots or 15 s | fingertip viewport offset from the dot at each shot |

Result:

```
span          = median(cocked) - median(pulled)
triggerPull   = median(cocked) - 0.76 * span      (T) reproduces 0.30 on the canonical 0.677 / 0.180 hand
triggerReset  = median(cocked) - 0.52 * span      (T) reproduces 0.42
aimOffset     = median of the step-3 offsets, viewport units
```

Rejection (whole result falls back to defaults, never a partial mix — P):
fewer than 10 samples in step 1 or 2 (`CALIB_MIN_SAMPLES`); `span < 0.25` (T);
fewer than 5 shots; median absolute deviation of the step-3 offsets > 0.05 viewport (T).

### 7.6 Fallback if MediaPipe fails F2

Apple Vision gives 2D joints only. `straight` and `curl` become 2D ratios and `trigger`
becomes `dist2D(thumb tip, index segment) / dist2D(wrist, middle MCP)`. None of the §7.3
thresholds carry over; they are re-derived from Practice Range telemetry before M3.

---

## 8. Hit test (shooter side)

Port target: `App/Weapons/HitTest.swift`, pure geometry in `Core/Sources/Core/Math/HitMath.swift`.

| Constant | Value | |
|---|---|---|
| `HIT_SPHERE_RADIUS_M` | 0.25 | (T) |
| `HEAD_BACK_OFFSET_M` | 0.15 | (T) sphere centre = phone position minus 0.15 m along the phone's rear-camera forward, so it covers phone and head |
| `MIN_RANGE_M` | 1.0 | (T) equals `OWN_HAND_MAX_M` below |
| `MAX_RANGE_M` | 30 | (T) |
| `MASK_MIN_FRACTION` | 0.30 | (T) |
| `MASK_MIN_RADIUS_PX` | 3 | (T) at stencil resolution |
| Stencil | `AROcclusionManager.requestedHumanStencilMode = Fastest` (256x192) | (U) resolution |
| `GUN_DAMAGE` | 25 | (T) 4 hits |
| `PREDICT_MAX_MS` | 250 | (T) remote poses come from the Kalman filter of §5.1: interpolated for past times, predicted up to 250 ms ahead |

For a shot with ray origin `o`, unit direction `d` (from the lookback sample, shared frame)
and each living enemy `i` with sphere centre `c_i` (from §5.1: at the lookback time for
condition 1, predicted to the firing frame's time for conditions 2 and 3):

| # | Condition | Evaluated with |
|---|---|---|
| 1 | `t = (c_i - o) . d`, `1.0 <= t <= 30`, and `|c_i - (o + t d)| <= 0.25` | lookback sample |
| 2 | `c_i` projects inside the viewport: `0 <= u <= 1`, `0 <= v <= 1`, depth > 0 | firing frame camera pose |
| 3 | Depth-aware people check below returns `fraction >= 0.30` | firing frame stencil and human depth |

**Condition 3 in detail.** The shooter's own hand is a person in ARKit's human stencil, and
by §7.4 the fingertip sits on screen over the target. A plain stencil count would be
filled by the shooter's own finger and pass even with the target behind a wall. So the
check uses the human depth texture (`AROcclusionManager.humanDepthTexture`,
`requestedHumanDepthMode = Fastest`) to tell the hand from the target.

Region `G`: the union of two circles in stencil pixels, the head circle (centre = projection
of `c_i`, radius `max(3, f_stencil * 0.25 / t)`) and a torso circle (centre = projection of
`c_i - 0.45 m * up`, radius `max(3, f_stencil * 0.30 / t)`). The torso is included because
the finger usually covers part of the head.

Each pixel of `G` is classed as:

| Class | Rule |
|---|---|
| `own` | stencil = human AND depth < `OWN_HAND_MAX_M` |
| `target` | stencil = human AND depth >= `OWN_HAND_MAX_M` AND `abs(depth - t) <= max(DEPTH_TOL_MIN_M, DEPTH_TOL_FRAC * t)` |
| `other` | everything else (background, or a person at the wrong range) |

```
visible  = count(G) - count(own)
fraction = count(target) / visible
```

| Case | Result |
|---|---|
| `visible >= OBSCURED_MIN_FRACTION * count(G)` | condition 3 = `fraction >= 0.30` |
| `visible` below that (own hand covers the region) | re-evaluate on each of the next `OBSCURED_RETRY_FRAMES` rendered frames with the target re-projected; if still obscured, the shot is a miss, logged as `obscured` (T) |
| Human depth texture missing on this frame | use the newest one no older than 100 ms |
| Human depth unavailable on the device or for > 100 ms | `own` is instead any stencil pixel inside the shooter's hand silhouette: the convex hull of the 21 hand landmarks dilated by 15 % of `|wrist - middle MCP|` on screen, plus a strip of that width from the wrist to the bottom screen edge (forearm). `target` is then any other human pixel; the range test is skipped. |

| Constant | Value | |
|---|---|---|
| `OWN_HAND_MAX_M` | 1.0 | (T) nothing nearer than this can be a target (`MIN_RANGE_M` is raised to 1.0 to match) |
| `DEPTH_TOL_MIN_M` | 0.75 | (T) |
| `DEPTH_TOL_FRAC` | 0.25 | (T) tolerance is 1.25 m at 5 m, 2.0 m at 8 m; ARKit's human depth is an estimate |
| `OBSCURED_MIN_FRACTION` | 0.20 | (T) |
| `OBSCURED_RETRY_FRAMES` | 3 | (T) 50 ms at 60 fps |

The range test also fixes the "wrong person in front" case of the first draft: a teammate
or bystander well short of the target's range no longer counts.

All three true = hit. If several enemies pass, the smallest `t` wins. Teammates are never
tested (no friendly fire). Practice Range targets skip condition 3.

Known limits, accepted for v1: the shooter decides, so it is cheatable; a person standing
in the line within the depth tolerance of the target still counts as the target being visible.

Host sanity check on a claimed hit (reject otherwise): match is LIVE; shooter and target
ALIVE and on different teams; >= 150 ms since the shooter's previous shot; host's own
recomputation of condition 1 from its pose history passes with radius `0.25 + 0.15` m (T).
The host keeps 1.0 s of poses per player (20 samples).

---

## 9. Bow (second weapon, M5)

The phone is the bow. The selfie camera watches the draw hand pull back toward the face.

### 9.1 Measures (P, `config.py` and `input/bow_input.py`)

```
fist_ratio = mean over index, middle, ring, pinky of dist(tip, wrist) / dist(mcp, wrist)
             open hand ~1.9–2.3, closed fist ~0.7–1.1
pull_m     = z - z0     z = palm depth from the camera, z0 = palm depth when the fist closed
power      = clamp(pull_m / DRAW_FULL_M, 0, 1)
firePower  = max(power) over the last FIRE_POWER_WINDOW tracked frames
```

Palm depth: weak-perspective fit of the five palm points (`POSE_PALM_POINTS` = wrist and
the four finger MCPs) between image and world landmarks, as in FletchFlow's
`input/hand_pose.py`; frames with fit residual above `POSE_MAX_RESIDUAL_PX` 25 are dropped,
depth clamped to `POSE_DEPTH_RANGE_M` (0.15, 2.5) (P), then smoothed with the Kalman
filter of §5.1 (`sigma_z` 0.02 m, `sigma_a` 6 m/s^2). FletchFlow smooths it with One Euro
(`POSE_DEPTH_MIN_CUTOFF` 0.8 Hz, `POSE_DEPTH_BETA` 1.0, `POSE_DEPTH_D_CUTOFF` 1.0 Hz); those
values are kept only as the comparison baseline.
The residual limit is in pixels of a 1280x720 frame and must be rescaled to the phone's
tracker input size.

| Constant | Value | Source |
|---|---|---|
| `FIST_ON` / `FIST_OFF` | 1.25 / 1.60 | (P) `config.py`, marked unvalidated there; calibration replaces |
| `FIST_ON_FRAMES` / `FIST_OFF_FRAMES` | 3 / 2 | (P) |
| `FIST_RATIO_GLITCH` | 3.0 | (P) |
| `HAND_LOST_GRACE_MS` | 600 | (P) |
| `COOLDOWN_MS` | 300 | (P) |
| `FIRE_POWER_WINDOW` | 5 frames | (P) |
| `DRAW_FULL_M` | 0.35 | (T) FletchFlow uses 0.15 at a desk; at arm's length the pull to the face is longer |
| `CALIB_DRAW_CLAMP_M` | (0.20, 0.60) | (T) FletchFlow: (0.08, 0.40) |
| `CALIB_DRAW_PERCENTILE` | 90 | (P) |
| `CALIB_ON_FRACTION` / `CALIB_OFF_FRACTION` | 0.65 / 0.30 | (P) thresholds placed inside the player's own open-to-closed span |
| `CALIB_MIN_SEPARATION` | 0.45 | (P) |
| `MIN_FIRE_POWER` | 0.10 | (T) weaker releases cancel |

### 9.2 Draw state machine

Simplified from FletchFlow's four-state table (`input/bow_input.py`): there is no bow hand
to grab or drop, because the phone is the bow.

| From | To | Condition | Output |
|---|---|---|---|
| IDLE | NOCKED | `fist_ratio < 1.25` for 3 consecutive frames | store `z0`; event `nock` |
| NOCKED | DRAWN | `pull_m >= 0.05` (T) | |
| DRAWN | RELEASED | `fist_ratio > 1.60` for 2 consecutive frames AND `firePower >= 0.10` | `BowShot(firePower)` |
| DRAWN | IDLE | `fist_ratio > 1.60` for 2 consecutive frames AND `firePower < 0.10` | cancel, no shot |
| NOCKED | IDLE | `fist_ratio > 1.60` for 2 consecutive frames | cancel |
| NOCKED or DRAWN | IDLE | hand missing > 600 ms | cancel; within the grace, power holds its last value |
| RELEASED | IDLE | 300 ms elapsed | |
| any | unchanged | `fist_ratio > 3.0` (glitch): advances no counter | |

### 9.3 Arrow flight (P, `game/physics.py`, constants `config.py`)

| Constant | Value | |
|---|---|---|
| `ARROW_SPEED_MIN_MS` / `ARROW_SPEED_MAX_MS` | 9.0 / 19.0 | (P) `speed = lerp(9, 19, firePower)` |
| `GRAVITY_MS2` | 1.6 | (P) arcade-light on purpose. At 5 m: drop 0.05 m at full power, 0.25 m at zero. |
| `PHYSICS_DT` | 1/120 s | (P) |
| `ARROW_LENGTH_M` | 0.55 | (P) |
| `ARROW_MAX_RANGE_M` | 45 | (P) `ARROW_MAX_DEPTH_M`; also despawn after 3.0 s (T) |
| `BOW_DAMAGE` | `50 + 50 * firePower` | (T) |

Integration is semi-implicit Euler, velocity first: `v.y -= 1.6 * dt; p += v * dt`.
Collision is a swept test per step, segment `p_prev -> p` against each enemy sphere of §8,
so arrows cannot tunnel (FletchFlow uses the same idea with a plane crossing). The shooter
simulates its own arrows and claims hits exactly as in §8.

### 9.4 Open problem for the bow

While the selfie camera feed is active the rear camera image is not available (U), so the
bow player has no see-through view and no people mask. Consequences to design in M5, after
F4: the bow screen shows a rendered scope view with enemy markers instead of the camera,
and bow hits use condition 1 of §8 only (they pass through walls). If F4 fails entirely,
the bow aims by gyroscope from a fixed stance with its position frozen at the last rear
camera fix. This is listed in §15.

---

## 10. Network

Network.framework, host mode. The host runs one `NWListener` for UDP on port 7777 (pose
stream and other unreliable messages) and one for TCP on port 7778 (everything reliable).
A client opens an `NWConnection` of each kind to the address in the join QR. All messages
are the structs of §12, encoded by `Core/Net/MessageCodec.swift`; `App/Net/NetworkTransport`
is the `Transport` (§12) that carries them. `App/Net/MatchNetwork` routes decoded messages
to the match code.

Reliable messages travel over TCP. Unreliable messages travel over UDP with a `UInt16`
sequence number per sender and type; a receiver drops any message whose sequence is not
newer than the last applied one (`Int16(truncatingIfNeeded: seq &- last) > 0`).

iOS needs `NSLocalNetworkUsageDescription` and `NSCameraUsageDescription` in `Info.plist`
(set in `project.yml`, §2). The first connection triggers the system's Local Network
permission prompt. No Bonjour and no multicast entitlement: joining is by the QR of §6.

### 10.1 Messages

| Message | Direction | Delivery | Rate | Payload bytes |
|---|---|---|---|---|
| `DevicePoseMsg` | client -> host | UDP, sequenced | 20 Hz | 28 |
| `PoseBatchMsg` | host -> each client | UDP, sequenced | 20 Hz | 4 + 28 per player (228 at 8 players) |
| `ShotMsg` | client -> host | TCP | per shot, <= 6.7 Hz | 46 |
| `HitMsg` | host -> all | TCP | per hit | 17 |
| `ShotFxMsg` (tracer for others) | host -> all | UDP | per shot | 32 |
| `LifeStateMsg` | host -> all | TCP | per change | 12 |
| `MatchStateMsg` | host -> all | TCP | per change + every 1 s | 24 |
| `SyncPoseMsg` (host pose during §6) | host -> syncing client | UDP, sequenced | 20 Hz | 28 |
| `ClockPingMsg` / `ClockPongMsg` | client -> host / host -> client | UDP | 8 on join, then 1 every 5 s | 9 / 16 |
| `KillcamClipHeader` + `KillcamChunkMsg` | via host | TCP | on kill | 22 header; chunk = 4 + <= 32,000 |

Payload sizes are the field-by-field serialized sizes of §12 with no padding, excluding the
framing: a 1-byte message type, then on UDP a 2-byte sequence number, on TCP a 2-byte length.
A `KillcamChunkMsg` is `UInt16 clipId, UInt16 index, [UInt8] data`; TCP does the
retransmission and ordering, so there is no application-level reassembly beyond `index`.

Load at 8 players: the host sends 7 x (228 + 31 framing and UDP/IPv4 headers) x 20 = about
36 kB/s (290 kbit/s) and receives 7 x 20 = 140 pose messages a second. A killcam is a
1.0–1.5 MB burst (§11).

### 10.2 Match flow (host is the authority)

| From | To | Condition |
|---|---|---|
| MENU | LOBBY | Host taps Host; client scans the join QR and connects |
| LOBBY | SYNC | Host taps Start with >= 2 players and >= 1 per team (Practice Range: skip to COUNTDOWN alone) |
| SYNC | COUNTDOWN | Every connected player has an accepted `FrameAlignment` (§6). A player unsynced after 60 s (T) is moved to spectators. |
| COUNTDOWN | LIVE | 2.4 s elapsed; "3", "2", "1" at 0 / 0.8 / 1.6 s (P, `GUN_COUNTDOWN_S`) |
| LIVE | END | A team reaches `TDM_KILL_TARGET` 10 (T), OR `TDM_TIME_LIMIT_S` 300 (T) elapses, OR a team has 0 connected players for 15 s |
| END | LOBBY | Final killcam (§11) finishes and 8 s (T) of scoreboard, or host taps Continue |
| any | MENU | Host lost (§10.4) |

Killcam and respawn are per-player states (§10.3); the match stays LIVE for everyone else.

### 10.3 Player life state (host is the authority)

| Constant | Value |
|---|---|
| `MAX_HP` | 100 (T) |
| `KILLCAM_S` | 5.0 |
| `RESPAWN_WAIT_S` | 3.0 (T) after the killcam |
| `SPAWN_PROTECT_S` | 2.0 (T) |

| From | To | Condition | Effect |
|---|---|---|---|
| ALIVE | DEAD_KILLCAM | HP <= 0 from an accepted hit | Killer's team +1; victim's weapon disabled; killcam exchange starts |
| DEAD_KILLCAM | RESPAWNING | 5.0 s elapsed (the killcam plays, or a "clip unavailable" card if it did not arrive within 2.0 s) | |
| RESPAWNING | PROTECTED | 3.0 s elapsed | HP = 100 |
| PROTECTED | ALIVE | 2.0 s elapsed, or the player fires | Cannot be hit while PROTECTED |
| any | UNTRACKED | AR tracking state not `Tracking` for > 1.0 s | Cannot shoot, cannot be hit, marker greyed for others |
| UNTRACKED | previous state | Tracking normal for 0.5 s | |
| any | DISCONNECTED | §10.4 | |

Dead players are not tested in §8. There is no physical respawn point in v1 (T).

### 10.4 Connection and tracking loss

| Event | Detection | Action |
|---|---|---|
| Client silent | Host receives no `DevicePoseMsg` from it for 3.0 s | Player -> DISCONNECTED: not hittable, slot, team and score kept |
| Client returns | Reconnects with the same `playerGuid` within 30 s | Restored to RESPAWNING with its score; must pass a pose sanity check (position within 20 m of origin) or re-sync |
| Client gone | DISCONNECTED for > 30 s | Slot freed; team continues short-handed |
| Host silent | Client receives no host message for 3.0 s | "Reconnecting" overlay; 3 attempts 2.0 s apart |
| Host lost | All 3 attempts fail (about 9 s after the last message) | `MatchEnd(reason = HostLost)`; show the last known scoreboard; return to MENU. No host migration in v1. |
| Tracking lost | UNTRACKED for > 10 s | Prompt that player to re-scan the host marker; the match continues |
| App backgrounded | SwiftUI `scenePhase` becomes `.background` | Treated as client silent; on resume the AR session relocalises, then the "client returns" row applies |

---

## 11. Killcam

Each phone keeps the last 5 s of what its screen showed (camera plus overlays).

| Constant | Value | |
|---|---|---|
| `CLIP_SECONDS` | 5.0 | |
| `CLIP_FPS` | 15 | (T) |
| `CLIP_SIZE` | 270 x 480 px portrait | (T) |
| `CLIP_FRAMES` | 75 | |
| `CLIP_JPEG_QUALITY` | 0.60 (ImageIO `kCGImageDestinationLossyCompressionQuality`) | (T) about 12–18 kB a frame, 0.9–1.4 MB a clip |
| Ring buffer memory | 75 x 270 x 480 x 4 bytes = 38.9 MB BGRA | |
| `CLIP_CHUNK_BYTES` | 32,000 | (T) |

Capture: every 4th rendered frame is taken in the `ARView` post-process callback
(`ARView.renderCallbacks.postProcess`), scaled to 270x480 on the GPU
(`MPSImageBilinearScale`) and copied into a pre-allocated ring of 75 `CVPixelBuffer`s
(`App/Replay/ClipRecorder.swift`). (U) whether that callback exposes the camera plus
overlays at a cost under 2 fps; measured in M4. Nothing is encoded until a kill. On a
kill, both phones encode their ring to JPEG on a background queue (ImageIO
`CGImageDestination`) and send `KillcamClipHeader` plus chunks.

Routing: the killer's clip goes killer -> host -> victim. The victim's clip stays local.
The victim sees both side by side for 5.0 s, labelled KILLER and YOU, with the killer's
clip time-aligned by `endServerTimeMs`. The killer is not interrupted. For the kill that
ends the match, both clips are sent to every player and shown before the scoreboard.

Clips exist only in memory, travel only over the LAN and are dropped after playback.

---

## 12. Data shapes crossing module boundaries

All in `Core/Sources/Core/`. Plain Swift, `Foundation` only (§3.1). Every wire type has a
`write(to: inout ByteWriter)` and `init(from: inout ByteReader) throws` in
`Net/MessageCodec.swift`: fields are written one by one, little-endian, no padding, so the
byte counts below are exact. The wire form of every message is
`[UInt8 MsgType][payload]`; TCP adds a `UInt16` length in front, UDP adds a `UInt16`
sequence number after the type (§10.1). Payload sizes below exclude those.

```swift
import Foundation

public enum WeaponKind: UInt8, Sendable { case fingerGun = 0, bow = 1 }
public enum Team: UInt8, Sendable { case none = 0, red = 1, blue = 2 }
public enum LifeState: UInt8, Sendable { case alive, deadKillcam, respawning, protected, untracked, disconnected }
public enum MatchPhase: UInt8, Sendable { case menu, lobby, sync, countdown, live, end }
public enum TrackingQuality: UInt8, Sendable { case none = 0, limited = 1, normal = 2 }
public enum CameraFacing: UInt8, Sendable { case rear, front }

// Math, right-handed, metres, ARKit axes (§5): +X right, +Y up, -Z forward for a camera.
public struct Vec2: Sendable, Equatable { public var x: Float; public var y: Float }
public struct Vec3: Sendable, Equatable { public var x: Float; public var y: Float; public var z: Float }
public struct Quat: Sendable, Equatable { public var x: Float; public var y: Float; public var z: Float; public var w: Float }
public struct Pose: Sendable, Equatable { public var position: Vec3; public var rotation: Quat }
public struct Ray: Sendable, Equatable { public var origin: Vec3; public var direction: Vec3 }  // direction is unit length

// Hands -> Weapons. One per tracker result.
public struct HandPoseSample: Sendable {
    public var captureTimeSec: Double      // ARFrame.timestamp of the camera frame (seconds since boot)
    public var worldFromCamera: Pose       // local frame, metres; camera pose of that frame
    public var isRightHand: Bool
    public var score: Float                // 0...1 tracker confidence
    public var viewport: [Vec2]            // 21 points, viewport units 0...1, origin bottom-left
    public var worldM: [Vec3]              // 21 points, metres, hand-centred (MediaPipe world landmarks)
}

// Tracking -> Net, 28 bytes: 1 + 4 + 12 + 8 + 1 + 1 + 1.
public struct DevicePoseMsg: Sendable {
    public var playerId: UInt8
    public var serverTimeMs: UInt32
    public var position: Vec3              // shared frame; 3 x Float32
    public var qx: Int16, qy: Int16, qz: Int16, qw: Int16   // rotation, each component * 32767
    public var tracking: TrackingQuality
    public var weapon: WeaponKind
    public var flags: UInt8                // bit 0: aiming (gun COCKED or bow DRAWN)
}

// Weapons -> Net, shooter -> host, 46 bytes: 2+1+1+4+12+12+4+1+4+4+1.
public struct ShotMsg: Sendable {
    public var shotId: UInt16              // per shooter, wraps
    public var shooterId: UInt8
    public var weapon: WeaponKind
    public var serverTimeMs: UInt32        // time of the lookback aim sample (gun) or impact (bow)
    public var origin: Vec3                // shared frame
    public var direction: Vec3             // unit; for the bow, the arrow direction at impact
    public var power: Float                // 0...1; 1 for the gun
    public var claimedTargetId: UInt8      // 255 = miss
    public var rangeM: Float               // t of section 8
    public var missDistanceM: Float        // closest approach to the sphere centre
    public var maskFraction: UInt8         // 0...255 = 0...1; section 8 condition 3 fraction
}

// Host -> all, 17 bytes: 2+1+1+1+1+1+4+6.
public struct HitMsg: Sendable {
    public var shotId: UInt16
    public var shooterId: UInt8
    public var targetId: UInt8
    public var damage: UInt8
    public var targetHpAfter: UInt8
    public var killed: Bool
    public var serverTimeMs: UInt32
    public var hitPoint: Vec3              // shared frame; sent as 3 x Int16 centimetres
}

// Persisted per player: Application Support/OutlawDuels/calibration.json (Codable, JSONEncoder).
public struct CalibrationProfile: Codable, Sendable {
    public var version: Int = 1
    public var playerGuid: UUID
    public var gunValid: Bool = false
    public var gunTriggerPull: Float = 0.30        // default
    public var gunTriggerReset: Float = 0.42       // default
    public var gunAimOffsetViewportX: Float = 0    // default 0
    public var gunAimOffsetViewportY: Float = 0    // default 0
    public var bowValid: Bool = false
    public var bowFistOn: Float = 1.25             // default
    public var bowFistOff: Float = 1.60            // default
    public var bowDrawFullM: Float = 0.35          // default
    public var savedUnixMs: Int64 = 0
}

// Replay -> Net, 22 bytes, precedes the chunks: 2+1+1+2+2+2+1+1+4+4+2.
public struct KillcamClipHeader: Sendable {
    public var clipId: UInt16
    public var ownerId: UInt8              // whose point of view
    public var victimId: UInt8
    public var shotId: UInt16
    public var widthPx: UInt16, heightPx: UInt16   // 270, 480
    public var fps: UInt8                  // 15
    public var frameCount: UInt8           // 75
    public var endServerTimeMs: UInt32     // time of the last frame
    public var totalBytes: UInt32
    public var chunkCount: UInt16
}

// Services.
public struct LeaderboardEntry: Codable, Sendable {
    public var boardId: String             // "range_gun_60s", "tdm_kills"
    public var playerGuid: UUID
    public var displayName: String         // at most 16 characters
    public var score: Int64
    public var rank: Int                   // 1-based; 0 when submitting
    public var submittedUnixMs: Int64
    public var appVersion: String
}

// Time sync (§5, §10.1). 9 and 16 bytes.
public struct ClockPingMsg: Sendable { public var playerId: UInt8; public var t0: Double }          // client uptime seconds
public struct ClockPongMsg: Sendable { public var t0: Double; public var serverTimeSec: Double }

public protocol HandTracker: AnyObject {
    var isRunning: Bool { get }
    var resultRateHz: Float { get }
    func startTracking(facing: CameraFacing)       // .rear for the gun, .front for the bow
    func stopTracking()
    func takeLatest() -> HandPoseSample?           // nil if no new sample since the last call
}

public protocol Weapon: AnyObject {
    var kind: WeaponKind { get }
    var requiredCamera: CameraFacing { get }
    func equip(_ profile: CalibrationProfile)
    func unequip()
    // Call once per rendered frame. Returns a ShotIntent on the frame a shot leaves.
    func tick(nowSec: Double, worldFromCamera: Pose) -> ShotIntent?
    var hud: WeaponHudState { get }                // trigger travel or draw power 0...1, aim point, state name
}

public struct ShotIntent: Sendable { public var rayLocal: Ray; public var power: Float; public var aimTimeSec: Double }

public protocol GameMode: AnyObject {
    var id: String { get }                         // "practice_range", "team_deathmatch"
    var minPlayers: Int { get }
    var maxPlayers: Int { get }
    var usesTeams: Bool { get }
    func enter(_ ctx: MatchContext)                // players, alignment, services
    func tick(serverTimeSec: Double)
    func onShot(_ shot: ShotMsg)                   // host: validate, apply
    func onHit(_ hit: HitMsg)                      // everyone: effects, score
    func isOver() -> MatchResult?
    func exit()
}

public protocol LeaderboardService: Sendable {
    func submit(_ entry: LeaderboardEntry) async throws -> Bool
    func top(boardId: String, count: Int) async throws -> [LeaderboardEntry]
    func mine(boardId: String, playerGuid: UUID) async throws -> LeaderboardEntry?
}

// Core/Net/Transport.swift. Core talks to the network only through this.
public protocol Transport: AnyObject {
    func send(_ payload: [UInt8], to playerId: UInt8?, reliable: Bool)   // nil = every connected player
    var onReceive: ((_ from: UInt8, _ payload: [UInt8]) -> Void)? { get set }
}
```

`WeaponHudState`, `MatchContext` and `MatchResult` are plain structs in `Core`. Future
modes (free-for-all, minigames) are new `GameMode` classes registered in
`App/Modes/ModeRegistry.swift`; nothing else changes.

Transport implementations: `LoopbackTransport` (`Core`, in-memory, with configurable delay,
loss and reordering, used by tests, §13.2) and `NetworkTransport` (`App/Net`,
Network.framework, §10).

Leaderboard implementations: `LocalLeaderboardService` (JSON in Application Support, from
M1) and `SupabaseLeaderboardService` (REST through `URLSession`, anonymous key, M6). Scores
come from the hosting phone and are forgeable; boards are for friends, not a ranked ladder.

---

## 13. Practice Range and editor testing

### 13.1 Practice Range (solo, offline)

| Item | Value | Source |
|---|---|---|
| Round length | 60 s | (P) `GUN_ROUND_SECONDS` |
| Countdown | 2.4 s | (P) `GUN_COUNTDOWN_S` |
| Targets | Discs of radius 0.25 m (T), 3 at a time | FletchFlow: 0.9 m at 9 / 14 / 20 m, too large for a room |
| Target distances | 3 / 5 / 8 m from where the player stood at round start | (T) |
| Target height | 1.2–1.8 m above the detected floor | (T) |
| Respawn | 0.8 s after a hit, at a new bearing within +/- 40 degrees | (P) `TARGET_RESPAWN_S`; bearing (T) |
| Scoring | Distance from centre as a fraction of radius: <= 0.28 -> 10, <= 0.60 -> 5, <= 1.00 -> 2 | (P) `SCORE_RINGS` |
| Bow round | 10 arrows or 90 s | (P) `ROUND_ARROWS`, `ROUND_SECONDS` |

The range also hosts the calibration routines (§7.5, bow equivalent in M5), the `AimMode`
switch, the `SmootherKind` switch (Kalman or the One Euro baseline, §5.1) with a readout of
rest jitter and sweep lag for each, and a telemetry toggle that writes every `HandPoseSample`, trigger reading and shot
to `Application Support/OutlawDuels/telemetry/*.jsonl` for retuning the (U) thresholds.

### 13.2 Working on Windows

| Need | Tool |
|---|---|
| State machines, filters, hit maths, wire codec, match flow | Swift Testing tests in `Core/Tests/CoreTests/`, run with `swift test --package-path Core` on Windows and on the Linux CI job (no device) |
| Hand input | `HandReplayReader` in `Core` feeds recorded `.jsonl` (from the phone, or converted from FletchFlow telemetry) into `GunTrigger`, `BowDraw` and the filters |
| AR camera and motion | Device only. The iPhone simulator has no camera or ARKit (§1A.1). Net and match tests use scripted device poses instead. |
| Multiplayer | `LoopbackTransport` in `Core`: up to 8 virtual players, each with a scripted pose path, configurable delay, loss and reordering. The real `NetworkTransport` is tested on phones from M2. |
| People mask | `FakePeopleMask` (a `PeopleMask` protocol in `Core`) returning a configurable fraction |

---

## 14. What comes over from FletchFlow

### 14.1 Files to copy

| Source (`D:\Projects\FletchFlow\`) | Destination (`D:\Projects\OutlawDuels\`) | Notes |
|---|---|---|
| `assets\models\FletchFlow_BowArrow.obj` | `App\Resources\Art\FletchFlow_BowArrow.usdz` | Original work, no credit owed. Objects `Bow` (380 tris) and `Arrow` (114 tris), no string. It is git-ignored in FletchFlow, so copy from disk. RealityKit loads USD, not OBJ: export a `.usdz` from Blender (it can do so on Windows) (U). Used from M5. |
| `assets\models\hand_landmarker.task` | `App\Resources\hand_landmarker.task` | Google MediaPipe, Apache-2.0. Also downloaded rather than committed in FletchFlow. Loaded with `Bundle.main.path(forResource:ofType:)`. |
| Output of `tools/export_fletchflow_audio.py` | `App\Resources\Audio\Sfx\{shot,hit,bull,miss,cock,crack,shatter,tier,boot,over}.wav` | FletchFlow synthesises these at runtime (`gun/audio.py` `synth_sfx(seed=7)`); the export script does not exist yet and is an M1 task. 44,100 Hz, 16-bit. Played with `AVAudioEngine`. |
| same script | `App\Resources\Audio\Music\layer_{0..4}.wav` | `synth_music(seed=11)`: five phase-locked loops at 100 BPM. Layer volumes 0.35 / 0.45 / 0.30 / 0.28 / 0.30 (`GUN_MUSIC_LAYER_VOL`). |

SFX volumes to carry (`GUN_SFX_VOL`): shot 0.55, hit 0.6, bull 0.8, miss 0.25, cock 0.35,
crack 0.7, shatter 0.8, tier 0.6, boot 0.6, over 0.6.

### 14.2 Logic to port

| FletchFlow source | OutlawDuels destination | Section |
|---|---|---|
| `vision/smoothing.py` `OneEuroFilter` | `Core/Sources/Core/Filters/OneEuroFilter.swift` (baseline only; replaced by the new `Filters/KalmanCv1D.swift`) | §5.1, §7.4 |
| `gun/gesture.py` `measure_gun` (shape measures only) | `Core/Sources/Core/Gun/GunGesture.swift` | §7.2 |
| `gun/trigger.py` `GunTrigger` | `Core/Sources/Core/Gun/GunTrigger.swift` | §7.3 |
| `input/calibration.py` `Calibrator`, `_thresholds`, `_percentile` | `Core/Sources/Core/Calibration/GunCalibrator.swift`, `BowCalibrator.swift` | §7.5, §9.1 |
| `input/bow_input.py` fist ratio, glitch rule, grace rules | `Core/Sources/Core/Bow/BowDraw.swift` | §9.2 |
| `input/hand_pose.py` palm depth fit | `Core/Sources/Core/Hands/PalmDepth.swift` | §9.1 |
| `game/physics.py` `step_arrows`, `score_for` | `Core/Sources/Core/Combat/ArrowSim.swift`, `Range/Scoring.swift` | §9.3, §13.1 |
| FletchFlow `tests/` cases for the above | `Core/Tests/CoreTests/` | same inputs, same expected outputs |

Not ported: `gun/aim.py` mapping, `input/mapping.py` bow sight, all pygame rendering, the
neon background and effects.

---

## 15. Open decisions (the user's)

| # | Decision | Default in this plan | Alternative |
|---|---|---|---|
| 0 | Engine (§1A.2) | **Decided 2026-11-13:** native Swift (the user wants to learn it), built in the cloud | None |
| 1 | How iOS builds are produced | **Decided 2026-11-13:** GitHub Actions macOS runner producing an unsigned `.ipa`; the spare Mac failed the Xcode gate (§1A.1) | None |
| 2 | Apple Developer Program, US$99/year | **Decided 2026-11-13:** not for development; Sideloadly with a free Apple ID (7-day re-sign). Enrol when releasing. | Enrol earlier if the free account's limits block a feature |
| 3 | Repo visibility | Private (about 13–20 device builds a month free) | Public: unmetered macOS minutes |
| 4 | Oldest iPhone to support | **Decided 2026-11-13:** iPhone 12, iOS 17 | Other testers' phone models still to be listed |
| 5 | Bow without a see-through view (§9.4) | Arrows through walls is **decided** (§1A.4); the scope view is decided after F4 | Drop the selfie-camera draw and use a different draw gesture |
| 9 | Self view in gun mode (§1A.5) | Drawn face from the face anchor, after F5 | Hide the corner in gun mode |
| 6 | Leaderboard backend | Supabase free tier over `URLSession` (works with free signing) | Game Center: needs the Apple Developer Program |
| 7 | Hand tracker | MediaPipe Tasks from Swift (CocoaPods) | Apple Vision `VNDetectHumanHandPoseRequest` (2D, thresholds re-derived) |
| 8 | Respawn rule | Timer only (§10.3) | Walk back to a team base marker |

---

## 16. Unverified items

| Item | Section | Verified by |
|---|---|---|
| Exact Xcode, Swift, XcodeGen, CocoaPods and MediaPipe patch versions; the `macos-26` runner label and the Xcode it carries | §2 | Day 1 of M0 |
| An unsigned `.ipa` from `xcodebuild archive` is re-signed by Sideloadly with a free Apple ID and launches on iOS 26.6.1; ARKit, camera and Local Network permission work under free signing; limits on apps and App IDs per week; GitHub minute quotas | §2.1, §1A.1 | M0 |
| The Swift Windows toolchain builds and tests `Core` (Foundation only) and has Swift Testing | §2, §3.1, §13.2 | M0 |
| Marker sync accuracy with a 60 mm on-screen marker; `CAMERA_TO_SCREEN` offset | §6 | F1 |
| MediaPipe Tasks iOS linking under Swift 6 through CocoaPods; its speed beside ARKit | §7.1 | F2 |
| Clock offset accuracy of +/- 5 ms from the ping scheme | §5 | M2 |
| Gun thresholds with the camera behind the hand | §7.2, §7.3 | M1 telemetry |
| Human stencil resolution, range and behaviour behind obstacles | §8 | F3 |
| Human depth texture: available on every supported iPhone, same resolution as the stencil, accurate enough to separate the shooter's hand (< 1.0 m) from a target at 2–8 m; segmentation quality with a hand close to the lens | §8 condition 3 | F3 |
| How often the shooter's own hand covers the whole target region (`obscured`) | §8 condition 3 | F3 |
| Front camera frames with 6-DoF tracking; origin continuity across a camera switch; no rear image meanwhile | §9.4 | F4 |
| `ARView` post-process callback gives camera plus overlays; killcam copy and JPEG cost on device | §11 | M4 |

---

## 17. Milestones

Each ends with an installable `.ipa` from the §2.1 pipeline, installed with Sideloadly. A
milestone is done only when every criterion is measured.

### M0 — Toolchain

`Core` package and `App/` layout of §3, an `ARView` showing the rear camera, `project.yml`,
`Podfile`, CI of §2.1, `tools/install.ps1`.

- A push to `main` produces an `.ipa` artifact with no manual step; push to artifact <= 25 min (T).
- `tools/install.ps1` plus Sideloadly puts that build on the iPhone 12 in <= 5 min, and it launches on iOS 26.6.1.
- The app shows the rear camera at >= 55 fps for 5 min on the iPhone 12.
- `swift test --package-path Core` passes on the Windows laptop and in the Linux CI job; >= 1 test per `Core` folder.
- Every version in §2 replaced by the exact installed number.

### Feasibility — F1, F2, F3

Run per §4. M2 does not start until F1 passes or its fallback is chosen; M1 needs F2.

### M1 — Finger gun and Practice Range (solo)

`MediaPipeHandTracker`, `GunGesture`, `GunTrigger`, aim, gun calibration, range, audio export.

- Ported tests (Swift Testing): 100 % of the FletchFlow `GunTrigger` and `OneEuroFilter` cases pass.
- Hand results >= 25 Hz with render >= 55 fps during a 60 s round.
- Trigger: of 50 deliberate thumb drops, >= 47 fire (94 %); <= 1 unintended shot in 60 s of holding the gun cocked.
- Thumb-drop to tracer on screen: p95 <= 150 ms (240 fps video of phone plus hand, 10 pulls).
- Accuracy after calibration: >= 9 of 10 shots within 0.10 m of the aimed point on a 5 m target.
- Calibration finishes in <= 20 s and survives an app restart.
- Smoothing, measured in the range for Kalman and for the One Euro baseline: fingertip jitter with the hand held still <= 0.003 viewport (standard deviation over 3 s); lag behind the raw fingertip during a 1 viewport/s sweep <= 35 ms. Kalman stays the default only if it meets both; the measured pair for each filter is recorded in §5.1.
- `KalmanCv1D` tests: a constant-velocity input with Gaussian noise of `sigma_z` converges to within 10 % of the true velocity in <= 0.5 s; a single 10-sigma outlier moves the estimate by 0.
- Telemetry file written for every round with the toggle on.

### M2 — Lobby, sync, pose stream

Join by QR, §6 sync, `DevicePoseMsg` stream, name tags over other players.

- 4 phones join and all reach an accepted sync in <= 30 s total, <= 5 s each.
- Position agreement meets F1's numbers with 4 phones over a 5 min session.
- Name tag stays within 0.20 m of the real phone at 5 m while its holder walks at 1 m/s, and within 0.30 m during a sidestep (stand to 2 m/s in under 0.5 s), using the prediction of §5.1.
- With 2 consecutive pose packets dropped (150 ms gap, simulated), the predicted position error at 1 m/s stays <= 0.10 m.
- Pose stream: 20 Hz +/- 2 received per player; loss < 2 % on home Wi-Fi.
- A client force-quit and relaunched rejoins with its slot in <= 15 s.

### M3 — Team Deathmatch (gun only)

Hit test of §8, damage, life states, match flow, scoreboard, tracers and hit feedback.

- 2 v 2 on 4 phones completes a full match to 10 kills without a crash or desync, 3 times in a row.
- Hit registration: at 5 m, >= 8 of 10 well-aimed shots at a visible opponent register; 0 of 10 register on an opponent fully behind a wall or door.
- Shot to HP change on the victim's screen: p95 <= 200 ms.
- Every transition in §10.2, §10.3 and §10.4 has a `Core` test with simulated players on `LoopbackTransport`.
- Host force-quit: every client is back at the menu with the last scoreboard shown in <= 12 s.
- 10 min match: no thermal state of serious, battery use <= 8 % on the oldest phone.

### M4 — Killcam

`ClipRecorder`, transfer, side-by-side playback, end-of-match final kill.

- Both clips are playing on the victim's phone <= 2.0 s after the kill, in 9 of 10 kills.
- Clips are 5.0 s +/- 0.2 s and aligned to within 0.2 s of each other.
- Recording costs <= 2 fps of render rate (measured with it on and off).
- Clip size <= 1.5 MB; memory growth after 20 kills <= 10 MB.

### M5 — Bow

F4 first, then `BowDraw`, `PalmDepth`, `ArrowSim`, bow calibration, weapon choice in the lobby.

- F4 passes or its fallback is chosen and §9.4 is resolved in this file.
- Draw: of 30 draw-and-release attempts, >= 27 fire; 0 unintended fires in 60 s of holding a closed fist.
- Power repeatability: 10 full draws give `firePower` >= 0.90 on >= 8.
- Practice Range: >= 7 of 10 arrows hit a 0.25 m target at 5 m after calibration.
- A mixed 2 v 2 (one bow, one gun per team) completes a full match.

### M6 — Leaderboards and wider testing

`SupabaseLeaderboardService`, display names, TestFlight external testers (needs the Apple
Developer Program, §15 #2).

- A Practice Range score submitted on phone A appears in the top list on phone B in <= 5 s.
- With no internet the game is fully playable and scores queue locally, uploading within 10 s of reconnecting.
- External TestFlight build approved and installed by >= 3 testers outside the dev account.

---

## 18. Later, not planned here

Free-for-all and minigames (new `IGameMode` classes), internet play through a relay for
networks that block device-to-device traffic, host migration, LiDAR depth as a second
occlusion check, an Android port of gun mode.
