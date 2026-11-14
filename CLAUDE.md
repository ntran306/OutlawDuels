# OutlawDuels

AR combat game for iPhone: players in the same real room shoot each other with a finger
gun (rear camera, thumb drop to fire) or a bow (phone as bow, fist draw). Read `PLAN.md`
first; §1A holds the newest decisions and overrides later sections where they conflict.

## State as of 2026-11-13

- Only planning exists. No code, no Unity or Xcode project.
- Open decision blocking everything else: engine, Unity or native Swift (`PLAN.md` §1A.2).
  It depends on whether the user's spare Mac can install the Xcode version Apple requires.
  Ask for the Mac's model, chip, memory and macOS version if still unknown.
- Hardware: Windows 11 laptop (this repo at `D:\Projects\OutlawDuels`), a spare Mac for
  builds, one iPhone 12 for testing.
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
