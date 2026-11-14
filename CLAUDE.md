# OutlawDuels

AR combat game for iPhone: players in the same real room shoot each other with a finger
gun (rear camera, thumb drop to fire) or a bow (phone as bow, fist draw). Read `PLAN.md`
first; §1A and §1B hold the newest decisions and override later sections where they
conflict. §17 is the phase order: Phase 0 toolchain and recorder, Phase 1 finger gun core
(Kalman aim, detection, trajectory, effects), Phase 2 Practice Range minigame, Phase 3
multiplayer finger gun 1 v 1 (the main goal), then team play, killcam, bow, leaderboards.
§19 lists what the user must install, pay for and test.

## State as of 2026-11-14

- Planning is complete enough to start. No code exists yet: no Swift package, no Xcode
  project. The next work is Phase 0 (`PLAN.md` §17), in the step order 0a–0g given there,
  done in an implementation session separate from the hub session.
- Laptop tools installed and checked 2026-11-14: Swift 6.4.2 (a throwaway package built and
  passed a Swift Testing test; edit-build-test took 7 s), GitHub CLI 2.104.0 signed in with
  `repo` and `workflow` scopes, Sideloadly with desktop iTunes and iCloud. `swift` and `gh`
  are on the path only in terminals opened after the install.
- The laptop's Swift is newer than the one inside Xcode 26.6 on the build runner (U: which),
  so `Core` must avoid language features the older one rejects.
- The spare Mac is out as a build machine: macOS 10.15 (Catalina), no newer macOS offered,
  while the iPhone runs iOS 26.6.1 and needs Xcode 26 (U). Builds go through a GitHub
  Actions macOS runner as an unsigned `.ipa`; Sideloadly on the Windows laptop signs it
  with a free Apple ID (7-day expiry) and installs it. Apple Developer Program only at
  release (`PLAN.md` §1A.1, §2.1).
- Engine decided 2026-11-13: native Swift (the user wants to learn it). `PLAN.md` §2, §3,
  §5, §6, §10–§14 and §17 were rewritten for it. Logic lives in the pure-Swift package
  `Core/` (Foundation only, tested on Windows with `swift test`); only the `App/` target
  touches Apple frameworks.
- Hardware: Windows 11 laptop (this repo at `D:\Projects\OutlawDuels`), one iPhone 12 on
  iOS 26.6.1 for testing, and an old Mac that cannot build.
- Nothing in the plan has been tested on a device. Items marked (U) are unverified.

## How the work is organised

- One hub session handles design features, skills and plugins, and overall high-level
  planning. `PLAN.md` is its document.
- Each feature or functionality gets its own smaller plan, written in a separate session.
  Do not start those until the user says so. Candidates are listed in `PLAN.md` §1A.10.

## Planning rules (the user's)

- Give concrete values, not vague descriptions: exact versions, thresholds, formulas,
  constants, file paths, API and function names. A tunable value still gets a starting
  number and is marked tunable.
- Express state machines and branching logic as transition tables with exact conditions
  (threshold plus duration), not prose.
- Every milestone gets measurable acceptance criteria.
- Name the exact data shapes that cross module boundaries, with fields and units.

## Source of the ported algorithms

The predecessor is FletchFlow, a desktop Python prototype at `D:\Projects\FletchFlow`
(branch `dev`) on the Windows laptop. `PLAN.md` quotes its constants with their source
files. To port code on another machine, clone FletchFlow there as well; its bow model and
`hand_landmarker.task` are git-ignored and must be copied by hand (`PLAN.md` §14.1).

## Preferences stated so far

- Kalman filtering for tracking, with One Euro kept only as a comparison baseline.
- Screen as plain as possible: camera view, HP and ammunition top left, menu top right,
  self view in a bottom corner.
- Gun first, bow second. Same Wi-Fi first, host hotspot as fallback.
- Players are told apart by colour markers, not name tags. Maximum 10 players (5 v 5).
- Camera-based correction of other players' positions is wanted (`PLAN.md` §1B.7).
- The user's main Apple ID is used for Sideloadly signing; a separate one is optional.
