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
| Dev machine | Windows 11 laptop plus a spare Mac used for builds (§1A.1). |
| Test devices | iPhones only. First test phone: iPhone 12. |
| Engine | Unity 6 + AR Foundation (ARKit provider) as written; under review against native Swift (§1A.2). |
| Order | Gun mode first, bow second. |
| Shared coordinate frame | Every client scans a marker on the host's screen (§6). |
| Hit decision | Shooter's phone: ray through a 0.25 m sphere, target in frame, >= 30 % people-mask pixels at the target's range, excluding the shooter's own hand (§8). Host only sanity-checks and applies damage. |
| Network | One phone hosts over LAN with Netcode for GameObjects. No dedicated server. |
| Modes for testing | `PracticeRange` (with calibration) and `TeamDeathmatch`. |
| Killcam | 5 s from both points of view on a kill (§11). |
| Rankings | Behind `ILeaderboardService`; backend swappable (§12). |
| Repo | `D:\Projects\OutlawDuels`, new, separate from FletchFlow. |

Not settled: see §15 (Open decisions).

---

## 1A. Design update, 2026-11-13

Decisions made by the user after the first draft. **Where this section conflicts with a
later section, this section wins.** The later sections are brought in line once the engine
(§1A.2) is chosen, because that choice rewrites §2, §3, §10 and §12 anyway.

### 1A.1 Hardware and builds

| Item | Value | |
|---|---|---|
| Build machine | The user's spare Mac: local Xcode, cable or Wi-Fi install to the phone | (U) model, chip, memory and macOS version not yet known |
| Gate | The Mac must install the Xcode version Apple currently requires for App Store upload | (U) check once the model is known |
| Cloud build of §2.1 | Fallback only, used if the Mac fails the gate | |
| Test phone | iPhone 12 (A14, no LiDAR) | |
| Minimum device | iPhone 12, iOS 17.0 | (T) replaces "iPhone 11" in §2 |
| Windows laptop | Editing, planning, `Core` unit tests if the engine stays Unity | |

A macOS virtual machine on the Windows laptop is ruled out: Apple's licence does not allow
it, and the iPhone simulator has no camera or AR, so it could not test this game.

### 1A.2 Engine: open

| Option | Stack | Consequence for this file |
|---|---|---|
| A. Unity (as written) | Unity 6, AR Foundation, Netcode for GameObjects, MediaPipe through a native plugin | None |
| B. Native Swift | ARKit + RealityKit, MultipeerConnectivity, Core Haptics, MediaPipe Tasks through CocoaPods or Swift Package Manager, XCTest | §2, §3, §10 transport and §12 (C# to Swift) are rewritten. Algorithms, constants, state machines, feasibility tests and milestones are unchanged. |

Recommendation: B if the Mac passes the gate of §1A.1 and the user is willing to develop on
it; otherwise A with the Mac as build machine. B gives direct access to people depth,
collaborative sessions and haptics, minute-scale device builds, and networking that may not
need Wi-Fi (U). B gives up Android and all testing on the Windows laptop.

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

Networks that block phone-to-phone traffic are out of scope for now. Under engine option
B, MultipeerConnectivity may make both paths unnecessary (U).

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
| Unity Editor | 6000.3 LTS, latest patch on day 1 | (U) confirm the patch number in Unity Hub and write it into this table and `ProjectSettings/ProjectVersion.txt`. |
| `com.unity.xr.arfoundation` | 6.3.x matching the editor | (U) exact patch from Package Manager. |
| `com.unity.xr.arkit` | same version as AR Foundation | Must match AR Foundation exactly. |
| `com.unity.netcode.gameobjects` | 2.x, the release listed for 6000.3 | (U) exact patch. |
| `com.unity.transport` | 2.x (pulled in by Netcode) | UDP, port 7777. |
| `com.unity.multiplayer.playmode` | 1.x | Up to 4 virtual players in the Windows editor. |
| `com.unity.services.leaderboards` + `com.unity.services.authentication` | latest 2.x / 3.x | Only from M6. |
| MediaPipe Tasks Vision (iOS CocoaPod `MediaPipeTasksVision`) | 0.10.x | (U) exact patch; same `hand_landmarker.task` model as FletchFlow. |
| ZXing.Net | 0.16.9 | QR encode/decode for the join code. Apache-2.0. |
| Render pipeline | URP, Forward, MSAA off, HDR off | |
| Scripting backend | IL2CPP, .NET Standard 2.1, ARM64 | |
| Minimum device | iPhone 11 (A13), iOS 17.0 | (T) set from the oldest test phone, §15. People segmentation needs A12 or newer. |
| Orientation | Portrait, locked | (T) one hand holds the phone, the other makes the gun. |
| Frame rate | `Application.targetFrameRate = 60` | |
| Bundle id | `com.ntran306.outlawduels` | (T) |

Every package version is pinned in `Packages/manifest.json`; no `latest` tags.

### 2.1 Builds without a Mac

Chosen path: **GitHub Actions + GameCI + fastlane to TestFlight.**

| Stage | Runner | What it does | Expected time |
|---|---|---|---|
| 1 `unity-ios` | `ubuntu-latest` | `game-ci/unity-builder` with `targetPlatform: iOS` exports the Xcode project; uploads it as an artifact | 15–25 min (T) |
| 2 `xcode-testflight` | `macos-latest` | `pod install` (MediaPipe), `fastlane gym`, `fastlane pilot upload` | 10–15 min (T) |

Why this over Codemagic: GameCI documents activation with a Unity Personal licence, and the
Unity export runs on a Linux runner, so only stage 2 uses macOS minutes. Codemagic's Unity
workflow asks for a paid Unity serial (U), which Unity Personal does not have.

Cost: GitHub gives 2,000 free minutes a month on private repos and bills macOS at 10x, so
stage 2 costs 100–150 minutes per build, about 13–20 builds a month. Public repos are not
metered. Both figures (U) — check the current GitHub pricing page.

Requirements regardless of path: Apple Developer Program (US$99/year), an App Store Connect
API key stored as GitHub secrets (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`), Unity
licence secrets (`UNITY_LICENSE`, `UNITY_EMAIL`, `UNITY_PASSWORD`).

Because a device build takes 25–40 minutes, everything that can run in the Windows editor
must: all of `Core` is plain C# with EditMode tests, and devices are simulated (§13).

---

## 3. Repo layout

The Unity project is the repo root.

```
D:\Projects\OutlawDuels\
  PLAN.md
  .gitignore                      Unity template + *.ulf, *.p8
  .gitattributes                  LFS for *.png *.wav *.fbx *.task
  .github/workflows/ios.yml       the two-stage build of §2.1
  fastlane/Fastfile, Appfile
  tools/export_fletchflow_audio.py   one-off WAV export, run with FletchFlow's venv (§14)
  Packages/manifest.json
  ProjectSettings/
  Assets/
    OutlawDuels/
      Core/        OutlawDuels.Core.asmdef       pure C#, no UnityEngine.XR, no Netcode
      Tracking/    OutlawDuels.Tracking.asmdef   AR session, shared frame, people mask
      Hands/       OutlawDuels.Hands.asmdef      hand tracker implementations
      Weapons/     OutlawDuels.Weapons.asmdef    FingerGun, Bow, hit test
      Net/         OutlawDuels.Net.asmdef        lobby, messages, pose stream
      Modes/       OutlawDuels.Modes.asmdef      PracticeRange, TeamDeathmatch
      Replay/      OutlawDuels.Replay.asmdef     killcam buffer, transfer, playback
      Services/    OutlawDuels.Services.asmdef   profile, leaderboard
      UI/          OutlawDuels.UI.asmdef         menus, HUD, sync screen
      Art/Models/  Art/Markers/  Audio/Sfx/  Audio/Music/
      Scenes/      Boot.unity  Menu.unity  Game.unity
    Plugins/iOS/   HandTrackerBridge.swift, HandTrackerBridge.mm, Podfile fragment
    StreamingAssets/hand_landmarker.task
    Spikes/        throwaway feasibility scenes F1–F4; deleted after §4 passes
    Tests/EditMode/  Tests/PlayMode/
```

### 3.1 Module dependency rule

| Module | May reference |
|---|---|
| `Core` | nothing but `UnityEngine.CoreModule` math types |
| `Tracking`, `Hands`, `Services` | `Core` |
| `Weapons` | `Core`, `Tracking`, `Hands` |
| `Net` | `Core` |
| `Replay` | `Core`, `Net` |
| `Modes` | `Core`, `Weapons`, `Net`, `Replay`, `Services`, `Tracking` |
| `UI` | everything |

`Core` holds every state machine, filter, formula and data shape in this plan. It is the
only place FletchFlow logic is ported to, and it is fully testable on Windows.

---

## 4. Feasibility tests (throwaway, before any milestone work beyond M0)

Each is one scene under `Assets/Spikes/`, built to two iPhones through the §2.1 pipeline.

| ID | Question | Method | Pass | Fail action |
|---|---|---|---|---|
| F1 | Do two phones agree on position after a marker sync? | Sync per §6. Put phone B on a tape mark 5.00 m from phone A. Each phone logs the other's position in the shared frame for 3 min while both are carried around and returned to their marks every 30 s. | Distance error median <= 0.15 m, p95 <= 0.25 m, at 0 and at 3 min. Sync takes <= 5 s per client. | Switch §6 to an ARKit collaborative session (`ARKitSessionSubsystem.collaborationRequested`, `ARParticipantManager`) (U). |
| F2 | Does hand tracking run fast enough beside AR? | AR session on, rear camera, MediaPipe hand landmarker fed 480x360 frames, people stencil on. Log rates for 5 min. | Hand results >= 25 Hz, capture-to-result latency p95 <= 60 ms, render >= 55 fps, on the oldest test iPhone. No `ProcessInfo.thermalState` of serious within 10 min. | Drop input to 320x240; if still failing, use Apple Vision `VNDetectHumanHandPoseRequest` and re-derive 2D thresholds (§7.6). |
| F3 | Does the depth-aware people check separate "visible" from "behind a wall" with the shooter's own hand in the way? | Phone A aims at a person holding phone B at 2, 5 and 8 m, 20 trigger pulls each, **always with the finger gun raised and the fingertip over the target**; then the same with the person fully behind a door frame, finger gun still raised over where they are. Log per pull: `count(G)`, `own`, `target`, `fraction`, obscured or not, and the human depth read at the target and at the hand. Repeat the hidden trials with human depth disabled to test the silhouette fallback. | Visible: condition 3 true on >= 90 % of pulls at 2 m and 5 m, >= 75 % at 8 m; `obscured` on <= 10 % of pulls. Hidden: condition 3 false on >= 95 % of pulls, with depth and with the fallback. Human depth at a person at 5 m reads within 1.25 m of the tape distance on >= 90 % of pulls; at the hand it reads < 1.0 m on >= 95 %. | Tune the §8 constants and stencil/depth resolution; if depth is too poor, use the silhouette fallback as the primary rule; if 8 m fails only, set `MAX_RANGE_M` = 6. |
| F4 | (Bow only; run before M5) Can the selfie camera feed and 6-DoF tracking run together? | `ARCameraManager.requestedFacingDirection = User` with `ARSession.requestedTrackingMode = PositionAndRotation`. Walk a 2 m square, return to start. | Front camera frames >= 30 fps, loop-closure position error <= 0.10 m, world origin unchanged across a rear -> front camera switch (error <= 0.10 m). | Bow aims by gyroscope from a fixed stance; see §9.4. |

---

## 5. Coordinates, time and identifiers

- Units: metres, seconds, radians unless a field name says otherwise.
- Unity axes: left-handed, +X right, +Y up, +Z forward.
- **Local frame**: each phone's ARKit world. Gravity-aligned (+Y up) on every phone.
- **Shared frame**: origin at the sync marker centre at sync time, +Y up, +Z = the marker's
  outward normal projected onto the horizontal plane. Local and shared frames differ only
  by a yaw and a translation: `struct FrameAlignment { float yawRad; Vector3 translationM; }`
  with `p_shared = RotY(yawRad) * p_local + translationM`.
- **Time**: `NetworkManager.ServerTime.Time` (seconds, double). Messages carry it as
  `uint serverTimeMs`. Hand samples carry local `Time.realtimeSinceStartupAsDouble` and are
  converted when a shot is built.
- **Player id**: `byte` slot 0–7 assigned by the host. `Guid playerGuid` persists on the
  device for reconnects and leaderboards.
- Max players: 8 (4 v 4) (T). Test target: 2–4 phones.

### 5.1 Smoothing: constant-velocity Kalman filters

Players move a lot, so all tracking smoothing uses a Kalman filter with a constant-velocity
model. This **replaces** FletchFlow's One Euro filter (`vision/smoothing.py`, parameters
`ONE_EURO_MIN_CUTOFF` 1.5 Hz, `ONE_EURO_BETA` 0.3, `ONE_EURO_D_CUTOFF` 1.0 Hz in
`config.py`). One Euro is still ported, but only as a comparison baseline selectable in the
Practice Range (§13.1).

One filter class, `Core/Filters/KalmanCv1D.cs`, run independently per axis:

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
`Vector2` and `Vector3` wrappers (`KalmanCv2D`, `KalmanCv3D`) hold one `KalmanCv1D` per axis.

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
| Tracking marker | 60 mm x 60 mm (T). Pixels = `60 / 25.4 * Screen.dpi`. | Fixed image `Assets/OutlawDuels/Art/Markers/sync_marker.png`, also in the app's `XRReferenceImageLibrary` with physical size 0.060 m. |
| Join QR | 30 mm x 30 mm below the marker | `OD1|<hostIPv4>|7777|<matchId>` encoded with ZXing.Net. |

The marker is a fixed image rather than the QR itself so ARKit can validate it at build
time; the QR only carries the address. Manual IP entry is the fallback for joining.

Procedure:

1. Host holds the phone at chest height, screen toward the clients, rear camera seeing the
   room (so its own tracking stays normal). Leaning it upright against something also works.
2. Client decodes the QR from `ARCameraManager.TryAcquireLatestCpuImage` at 5 Hz, connects.
3. Client's `ARTrackedImageManager` reports the marker pose. Host streams its own device
   pose at 20 Hz.
4. Client collects samples for `SYNC_WINDOW_S` and solves `FrameAlignment`.

Solve, client side, per sample: marker pose `M_c` in client-local; host device pose `H_h`
in host-local at the same server time (interpolated); marker pose in host-local
`M_h = H_h * CAMERA_TO_SCREEN`. Yaw of a pose = `atan2(n.x, n.z)` of its normal `n`
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
| `MediaPipeHandTracker` | `Hands/`, calls `Plugins/iOS/HandTrackerBridge.swift` | Device. Live-stream mode, 1 hand, confidences 0.5 / 0.5 / 0.5 (P, `config.py` `MIN_*_CONFIDENCE`). |
| `ReplayHandTracker` | `Hands/` | Editor and tests. Plays `HandPoseSample` JSON-lines files. |
| `NullHandTracker` | `Hands/` | Menus. |

Input: the AR camera CPU image converted to RGBA 480x360 (T), at most 30 Hz, tagged with
the camera pose of that frame. Landmarks are converted from sensor image coordinates to
viewport coordinates with the frame's display matrix before leaving `Hands/`.

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
the infinite line. Port: `Core/Gun/GunGesture.cs`, function `GunGesture.Measure(in HandPoseSample)`.

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

Port: `Core/Gun/GunTrigger.cs`, class `GunTrigger`, method `GunSnapshot Update(in HandPoseSample? sample, double nowSec)`.
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
  Port: `Core/Filters/OneEuroFilter.cs`. Both implement `ISmoother2D` so the Practice Range
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

Port target: `Weapons/HitTest.cs`, pure geometry in `Core/Combat/HitMath.cs`.

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

Netcode for GameObjects, host mode, Unity Transport over UDP port 7777. Events are RPCs on
a single `MatchNetwork : NetworkBehaviour`. The pose stream uses
`NetworkManager.CustomMessagingManager` named messages so delivery can be unreliable.

iOS needs `NSLocalNetworkUsageDescription` and `NSCameraUsageDescription` in `Info.plist`.
No Bonjour and no multicast entitlement: joining is by the QR of §6.

### 10.1 Messages

| Message | Direction | Delivery | Rate | Payload bytes |
|---|---|---|---|---|
| `DevicePoseMsg` | client -> host | UnreliableSequenced | 20 Hz | 28 |
| `PoseBatchMsg` | host -> each client | UnreliableSequenced | 20 Hz | 4 + 28 per player (228 at 8 players) |
| `ShotMsg` | client -> host | Reliable | per shot, <= 6.7 Hz | 46 |
| `HitMsg` | host -> all | Reliable | per hit | 17 |
| `ShotFxMsg` (tracer for others) | host -> all | Unreliable | per shot | 32 |
| `LifeStateMsg` | host -> all | Reliable | per change | 12 |
| `MatchStateMsg` | host -> all | Reliable | per change + every 1 s | 24 |
| `SyncPoseMsg` (host pose during §6) | host -> syncing client | UnreliableSequenced | 20 Hz | 28 |
| `KillcamChunkMsg` | via host | ReliableFragmentedSequenced | on kill | 22 header + <= 32,000 |

Payload sizes are the field-by-field serialized sizes of §12 with no padding (fields are
written one by one through `INetworkSerializable`, not as a blitted struct).

Load at 8 players: the host sends 7 x (228 + ~40 transport overhead) x 20 = about 37.5 kB/s
(300 kbit/s) and receives 7 x 20 = 140 pose messages a second. A killcam is a 1.0–1.5 MB
burst (§11).

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
| App backgrounded | `OnApplicationPause(true)` | Treated as client silent; on resume the AR session relocalises, then the "client returns" row applies |

---

## 11. Killcam

Each phone keeps the last 5 s of what its screen showed (camera plus overlays).

| Constant | Value | |
|---|---|---|
| `CLIP_SECONDS` | 5.0 | |
| `CLIP_FPS` | 15 | (T) |
| `CLIP_SIZE` | 270 x 480 px portrait | (T) |
| `CLIP_FRAMES` | 75 | |
| `CLIP_JPEG_QUALITY` | 60 | (T) about 12–18 kB a frame, 0.9–1.4 MB a clip |
| Ring buffer memory | 75 x 270 x 480 x 3 bytes = 29 MB RGB24 | |
| `CLIP_CHUNK_BYTES` | 32,000 | (T) |

Capture: every 4th rendered frame is blitted to a 270x480 `RenderTexture` and read with
`AsyncGPUReadback` into the ring (`Replay/ClipRecorder.cs`). Nothing is encoded until a
kill. On a kill, both phones encode their ring to JPEG on a worker thread
(`ImageConversion.EncodeNativeArrayToJPG`) and send `KillcamClipHeader` plus chunks.

Routing: the killer's clip goes killer -> host -> victim. The victim's clip stays local.
The victim sees both side by side for 5.0 s, labelled KILLER and YOU, with the killer's
clip time-aligned by `endServerTimeMs`. The killer is not interrupted. For the kill that
ends the match, both clips are sent to every player and shown before the scoreboard.

Clips exist only in memory, travel only over the LAN and are dropped after playback.

---

## 12. Data shapes crossing module boundaries

All in `Assets/OutlawDuels/Core/`. Network structs implement `INetworkSerializable` in
`Net/` via partial types so `Core` stays free of Netcode.

```csharp
namespace OutlawDuels.Core
{
    public enum WeaponKind : byte { FingerGun = 0, Bow = 1 }
    public enum Team : byte { None = 0, Red = 1, Blue = 2 }
    public enum LifeState : byte { Alive, DeadKillcam, Respawning, Protected, Untracked, Disconnected }
    public enum MatchPhase : byte { Menu, Lobby, Sync, Countdown, Live, End }
    public enum TrackingQuality : byte { None = 0, Limited = 1, Normal = 2 }

    // Hands -> Weapons. One per tracker result.
    public struct HandPoseSample
    {
        public double captureTimeSec;        // local realtimeSinceStartup of the camera frame
        public Pose worldFromCamera;         // local frame, metres; camera pose of that frame
        public bool isRightHand;
        public float score;                  // 0..1 tracker confidence
        public Vector2[] viewport;           // 21 points, viewport units 0..1, origin bottom-left
        public Vector3[] worldM;             // 21 points, metres, hand-centred (MediaPipe world landmarks)
    }

    // Tracking -> Net, 28 bytes on the wire.
    public struct DevicePoseMsg
    {
        public byte playerId;
        public uint serverTimeMs;
        public Vector3 positionM;            // shared frame; 3 x float32
        public short qx, qy, qz, qw;         // rotation, each component * 32767
        public TrackingQuality tracking;
        public WeaponKind weapon;
        public byte flags;                   // bit 0: aiming (gun COCKED or bow DRAWN)
    }

    // Weapons -> Net, shooter -> host, 46 bytes.
    public struct ShotMsg
    {
        public ushort shotId;                // per shooter, wraps
        public byte shooterId;
        public WeaponKind weapon;
        public uint serverTimeMs;            // time of the lookback aim sample (gun) or impact (bow)
        public Vector3 originM;              // shared frame
        public Vector3 direction;            // unit; for the bow, the arrow direction at impact
        public float power;                  // 0..1; 1 for the gun
        public byte claimedTargetId;         // 255 = miss
        public float rangeM;                 // t of section 8
        public float missDistanceM;          // closest approach to the sphere centre
        public byte maskFraction;            // 0..255 = 0..1; section 8 condition 3 fraction
    }

    // Host -> all, 17 bytes.
    public struct HitMsg
    {
        public ushort shotId;
        public byte shooterId;
        public byte targetId;
        public byte damage;
        public byte targetHpAfter;
        public bool killed;
        public uint serverTimeMs;
        public Vector3 hitPointM;            // shared frame; sent as 3 x int16 centimetres
    }

    // Persisted per player per weapon: Application.persistentDataPath/calibration.json
    public struct CalibrationProfile
    {
        public int version;                  // 1
        public Guid playerGuid;
        public bool gunValid;
        public float gunTriggerPull;         // default 0.30
        public float gunTriggerReset;        // default 0.42
        public Vector2 gunAimOffsetViewport; // default (0, 0)
        public bool bowValid;
        public float bowFistOn;              // default 1.25
        public float bowFistOff;             // default 1.60
        public float bowDrawFullM;           // default 0.35
        public long savedUnixMs;
    }

    // Replay -> Net, 22 bytes, precedes the chunks.
    public struct KillcamClipHeader
    {
        public ushort clipId;
        public byte ownerId;                 // whose point of view
        public byte victimId;
        public ushort shotId;
        public ushort widthPx, heightPx;     // 270, 480
        public byte fps;                     // 15
        public byte frameCount;              // 75
        public uint endServerTimeMs;         // time of the last frame
        public uint totalBytes;
        public ushort chunkCount;
    }

    // Services.
    public struct LeaderboardEntry
    {
        public string boardId;               // "range_gun_60s", "tdm_kills"
        public Guid playerGuid;
        public string displayName;           // <= 16 chars
        public long score;
        public int rank;                     // 1-based; 0 when submitting
        public long submittedUnixMs;
        public string appVersion;
    }

    public interface IHandTracker
    {
        bool IsRunning { get; }
        float ResultRateHz { get; }
        void StartTracking(CameraFacing facing);            // Rear for the gun, Front for the bow
        void StopTracking();
        bool TryGetLatest(out HandPoseSample sample);       // false if no new sample since the last call
    }

    public interface IWeapon
    {
        WeaponKind Kind { get; }
        CameraFacing RequiredCamera { get; }
        void Equip(CalibrationProfile profile);
        void Unequip();
        // Call once per rendered frame. Returns true and fills shot on the frame a shot leaves.
        bool Tick(double nowSec, in Pose worldFromCamera, out ShotIntent shot);
        WeaponHudState Hud { get; }                         // trigger travel or draw power 0..1, aim point, state name
    }

    public struct ShotIntent { public Ray rayLocal; public float power; public double aimTimeSec; }

    public interface IGameMode
    {
        string Id { get; }                                  // "practice_range", "team_deathmatch"
        int MinPlayers { get; }
        int MaxPlayers { get; }
        bool UsesTeams { get; }
        void Enter(MatchContext ctx);                       // players, alignment, services
        void Tick(double serverTimeSec);
        void OnShot(in ShotMsg shot);                       // host: validate, apply
        void OnHit(in HitMsg hit);                          // everyone: effects, score
        bool IsOver(out MatchResult result);
        void Exit();
    }

    public interface ILeaderboardService
    {
        Task<bool> SubmitAsync(LeaderboardEntry entry);
        Task<IReadOnlyList<LeaderboardEntry>> GetTopAsync(string boardId, int count);
        Task<LeaderboardEntry?> GetMineAsync(string boardId, Guid playerGuid);
    }
}
```

`CameraFacing { Rear, Front }`, `WeaponHudState`, `MatchContext` and `MatchResult` are
plain structs in the same namespace. Future modes (free-for-all, minigames) are new
`IGameMode` classes registered in `Modes/ModeRegistry.cs`; nothing else changes.

Leaderboard implementations: `LocalLeaderboardService` (JSON in `persistentDataPath`, from
M1) and `UgsLeaderboardService` (Unity Gaming Services, anonymous sign-in, M6). Scores come
from the hosting phone and are forgeable; boards are for friends, not a ranked ladder.

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
to `persistentDataPath/telemetry/*.jsonl` for retuning the (U) thresholds.

### 13.2 Working on Windows

| Need | Tool |
|---|---|
| State machines, filters, hit maths | EditMode tests on `Core` (no device) |
| Hand input | `ReplayHandTracker` playing recorded `.jsonl` (from the phone, or converted from FletchFlow telemetry) |
| AR camera and motion | AR Foundation XR Simulation environments (U) |
| Multiplayer | Multiplayer Play Mode, up to 4 virtual players, each with a scripted pose path |
| People mask | `FakePeopleMask` returning a configurable fraction |

---

## 14. What comes over from FletchFlow

### 14.1 Files to copy

| Source (`D:\Projects\FletchFlow\`) | Destination (`D:\Projects\OutlawDuels\`) | Notes |
|---|---|---|
| `assets\models\FletchFlow_BowArrow.obj` | `Assets\OutlawDuels\Art\Models\FletchFlow_BowArrow.obj` | Original work, no credit owed. Objects `Bow` (380 tris) and `Arrow` (114 tris), no string. It is git-ignored in FletchFlow, so copy from disk. Used from M5. A `.fbx` re-export from the Blender workspace `Blender Models/FletchFlow/` is preferable if available. |
| `assets\models\hand_landmarker.task` | `Assets\StreamingAssets\hand_landmarker.task` | Google MediaPipe, Apache-2.0. Also downloaded rather than committed in FletchFlow. |
| Output of `tools/export_fletchflow_audio.py` | `Assets\OutlawDuels\Audio\Sfx\{shot,hit,bull,miss,cock,crack,shatter,tier,boot,over}.wav` | FletchFlow synthesises these at runtime (`gun/audio.py` `synth_sfx(seed=7)`); the export script does not exist yet and is an M1 task. 44,100 Hz, 16-bit. |
| same script | `Assets\OutlawDuels\Audio\Music\layer_{0..4}.wav` | `synth_music(seed=11)`: five phase-locked loops at 100 BPM. Layer volumes 0.35 / 0.45 / 0.30 / 0.28 / 0.30 (`GUN_MUSIC_LAYER_VOL`). |

SFX volumes to carry (`GUN_SFX_VOL`): shot 0.55, hit 0.6, bull 0.8, miss 0.25, cock 0.35,
crack 0.7, shatter 0.8, tier 0.6, boot 0.6, over 0.6.

### 14.2 Logic to port

| FletchFlow source | OutlawDuels destination | Section |
|---|---|---|
| `vision/smoothing.py` `OneEuroFilter` | `Core/Filters/OneEuroFilter.cs` (baseline only; replaced by the new `Core/Filters/KalmanCv1D.cs`) | §5.1, §7.4 |
| `gun/gesture.py` `measure_gun` (shape measures only) | `Core/Gun/GunGesture.cs` | §7.2 |
| `gun/trigger.py` `GunTrigger` | `Core/Gun/GunTrigger.cs` | §7.3 |
| `input/calibration.py` `Calibrator`, `_thresholds`, `_percentile` | `Core/Calibration/GunCalibrator.cs`, `BowCalibrator.cs` | §7.5, §9.1 |
| `input/bow_input.py` fist ratio, glitch rule, grace rules | `Core/Bow/BowDraw.cs` | §9.2 |
| `input/hand_pose.py` palm depth fit | `Core/Hands/PalmDepth.cs` | §9.1 |
| `game/physics.py` `step_arrows`, `score_for` | `Core/Combat/ArrowSim.cs`, `Core/Range/Scoring.cs` | §9.3, §13.1 |
| FletchFlow `tests/` cases for the above | `Assets/Tests/EditMode/` | same inputs, same expected outputs |

Not ported: `gun/aim.py` mapping, `input/mapping.py` bow sight, all pygame rendering, the
neon background and effects.

---

## 15. Open decisions (the user's)

| # | Decision | Default in this plan | Alternative |
|---|---|---|---|
| 0 | Engine (§1A.2) | Unity as written | Native Swift, recommended if the spare Mac passes the Xcode gate. Needs the Mac's model, chip, memory and macOS version. |
| 1 | How iOS builds are produced | **Decided 2026-11-13:** the user's spare Mac (§1A.1), pending the Xcode gate | GitHub Actions + GameCI + fastlane (§2.1) as fallback |
| 2 | Apple Developer Program, US$99/year | Enrol before M0; nothing reaches an iPhone without it on the default path | With a Mac, free provisioning installs builds that expire after 7 days |
| 3 | Repo visibility | Private (about 13–20 device builds a month free) | Public: unmetered macOS minutes |
| 4 | Oldest iPhone to support | **Decided 2026-11-13:** iPhone 12, iOS 17 | Other testers' phone models still to be listed |
| 5 | Bow without a see-through view (§9.4) | Arrows through walls is **decided** (§1A.4); the scope view is decided after F4 | Drop the selfie-camera draw and use a different draw gesture |
| 9 | Self view in gun mode (§1A.5) | Drawn face from the face anchor, after F5 | Hide the corner in gun mode |
| 6 | Leaderboard backend | Unity Gaming Services | Supabase free tier, or Game Center |
| 7 | Hand tracker | MediaPipe through a native plugin | Apple Vision (2D, thresholds re-derived) |
| 8 | Respawn rule | Timer only (§10.3) | Walk back to a team base marker |

---

## 16. Unverified items

| Item | Section | Verified by |
|---|---|---|
| Exact Unity, AR Foundation, Netcode, MediaPipe patch versions | §2 | Day 1 of M0 |
| GameCI activates a Unity Personal licence and exports iOS on Linux; Codemagic needs a paid serial; GitHub minute quotas | §2.1 | M0 |
| Marker sync accuracy with a 60 mm on-screen marker; `CAMERA_TO_SCREEN` offset | §6 | F1 |
| MediaPipe Tasks iOS inside a Unity build through CocoaPods; its speed beside ARKit | §7.1 | F2 |
| Gun thresholds with the camera behind the hand | §7.2, §7.3 | M1 telemetry |
| Human stencil resolution, range and behaviour behind obstacles | §8 | F3 |
| Human depth texture: available on every supported iPhone, same resolution as the stencil, accurate enough to separate the shooter's hand (< 1.0 m) from a target at 2–8 m; segmentation quality with a hand close to the lens | §8 condition 3 | F3 |
| How often the shooter's own hand covers the whole target region (`obscured`) | §8 condition 3 | F3 |
| Front camera frames with 6-DoF tracking; origin continuity across a camera switch; no rear image meanwhile | §9.4 | F4 |
| XR Simulation is usable on Windows for these scenes | §13.2 | M0 |
| Killcam readback and JPEG cost on device | §11 | M4 |

---

## 17. Milestones

Each ends with a TestFlight build. A milestone is done only when every criterion is measured.

### M0 — Toolchain

Unity project, modules and asmdefs of §3, empty AR scene, CI of §2.1.

- A push to `main` produces a TestFlight build with no manual step; commit to "processing" <= 45 min.
- The app shows the rear camera at >= 55 fps for 5 min on the oldest test iPhone.
- EditMode tests run in CI on the Linux stage; >= 1 test per `Core` folder.
- Every version in §2 replaced by the exact installed number.

### Feasibility — F1, F2, F3

Run per §4. M2 does not start until F1 passes or its fallback is chosen; M1 needs F2.

### M1 — Finger gun and Practice Range (solo)

`MediaPipeHandTracker`, `GunGesture`, `GunTrigger`, aim, gun calibration, range, audio export.

- Ported EditMode tests: 100 % of the FletchFlow `GunTrigger` and `OneEuroFilter` cases pass.
- Hand results >= 25 Hz with render >= 55 fps during a 60 s round.
- Trigger: of 50 deliberate thumb drops, >= 47 fire (94 %); <= 1 unintended shot in 60 s of holding the gun cocked.
- Thumb-drop to tracer on screen: p95 <= 150 ms (240 fps video of phone plus hand, 10 pulls).
- Accuracy after calibration: >= 9 of 10 shots within 0.10 m of the aimed point on a 5 m target.
- Calibration finishes in <= 20 s and survives an app restart.
- Smoothing, measured in the range for Kalman and for the One Euro baseline: fingertip jitter with the hand held still <= 0.003 viewport (standard deviation over 3 s); lag behind the raw fingertip during a 1 viewport/s sweep <= 35 ms. Kalman stays the default only if it meets both; the measured pair for each filter is recorded in §5.1.
- `KalmanCv1D` EditMode tests: a constant-velocity input with Gaussian noise of `sigma_z` converges to within 10 % of the true velocity in <= 0.5 s; a single 10-sigma outlier moves the estimate by 0.
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
- Every transition in §10.2, §10.3 and §10.4 has a PlayMode test with simulated players.
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

`UgsLeaderboardService`, display names, TestFlight external testers.

- A Practice Range score submitted on phone A appears in the top list on phone B in <= 5 s.
- With no internet the game is fully playable and scores queue locally, uploading within 10 s of reconnecting.
- External TestFlight build approved and installed by >= 3 testers outside the dev account.

---

## 18. Later, not planned here

Free-for-all and minigames (new `IGameMode` classes), internet play through a relay for
networks that block device-to-device traffic, host migration, LiDAR depth as a second
occlusion check, an Android port of gun mode.
