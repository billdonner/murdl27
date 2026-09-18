# MURDL 27

Modern SwiftUI rebuild of the archived MURDL game.

- Source archive: `/Users/billdonner/old-swift/MURDL`
- App id: `com.billdonner.murdl27`
- Target: native macOS 26.0 or later
- Modes: 1, 2, 4, 8, or 16 boards, 5 letters, guesses = boards + 5 (1 board is the six-guess beginner game, 8 boards the classic 13-guess game)
- Engine: `MurdlCore/` Swift package (rules, scoring, dictionary, clock, records) with XCTest coverage; built and tested on Windows and macOS by `.github/workflows/core.yml`. The Mac app is a SwiftUI front end over it.
- C bridge: `MurdlCore/Sources/MurdlBridge` exposes the engine as a C ABI (`murdl.h`) built as `MurdlBridge.dll` on Windows and `libMurdlBridge.dylib` on macOS; CI uploads the Windows DLL as a build artifact. Front ends drive it with `murdl_match_new`, `murdl_match_play`, and `murdl_match_state_json`.
- Dictionaries: bundled inside MurdlCore, copied from `old-swift/MURDL/Documents/wtf/Dictionaries`
- Visual assets: copied from `old-swift/MURDL/Documents/wtf/wtf/Assets.xcassets`
- Help: bundled as `Sources/Murdl/Resources/Help.md`
- UI: each board has a distinct accent color and tinted empty rows
- Helper Mode: solves one unfinished board at a time from the app UI or Game menu
- Keyboard: small floating window (`Command-K`); typing works from any window via an app-wide key monitor; position and open state persist
- Board layout: grid (rows of up to 8, vertical scroll with the next row peeking) or horizontal strip (`Command-L`); scroll by trackpad swipe, scroll wheel, or arrow keys
- Modes: Classic, Stopwatch (counts up from first keystroke, best time per board count), Sprint (45 s per board + 10 s per solve, unfinished boards lost at zero); clock pauses for Help and app background; helper games recorded as assisted
- Scores: every finished game is recorded with result, score string, guesses, and time (`Command-Shift-S`)
- Every action has a menu item and shortcut: `⌘1-4` boards, `⌥⌘1-3` mode, `⌘L`/`⌥⌘G`/`⌥⌘T` layout, `⇧⌘F`/`⌃⌘1-4` keyboard font, arrows move the board highlight, `⌘K` keyboard, `⇧⌘S` scores, `⌘/` help
- Keyboard shortcuts live in the menu bar only; on-screen buttons mirror them

## Mac App Store

- Sandboxed (no extra entitlements) with hardened runtime; version and build shown at the foot of the main window.
- Listing copy lives in `~/coworking/MURDL-AppStore.md` (pushed with `/asc-push MURDL` once the ASC record exists).
- `Screenshots/` holds 2560x1600 captures taken from the app at 1280x800 points: eight boards with the keyboard window, sixteen boards, Sprint, Scores, Help.
- Archive through Xcode Cloud (this Mac runs a macOS beta; local archives fail ingestion). Two workflows per platform: Build on main, Archive on the `release` branch with App Store deployment (`scripts/xcode-cloud-workflows.py` creates them). Pin Xcode 26.6.
- Build numbers follow Xcode Cloud's counter for both platforms; after each cloud archive set `CURRENT_PROJECT_VERSION` in `project.yml` to the number it used.

## iOS (iPad first)

- Second XcodeGen target `MurdlIOS` (scheme `MurdlIOS`, product MURDL) on the same bundle id and App Store record as the Mac app, so it is a universal purchase. iOS 26.0 or later.
- Shares `Sources/Murdl/Models` and `Sources/Murdl/Views` with the Mac app; `Sources/MurdlIOS` holds the app entry, a two-row header, the docked keyboard (with a Clear key), and its own `Help.md`. `MurdlGame` is platform-neutral; each app reports foreground and background so timed games pause.
- iPad only for now (`TARGETED_DEVICE_FAMILY` 2, all orientations). The grid picks the column count with the biggest tiles among those that fill every row, so eight boards wrap into two rows of four in portrait. A hardware keyboard types through `.onKeyPress`; arrows move the board highlight.
- Game over: a card over the boards with confetti on a win (haptic too), the score, Share, and New Game; tap outside it to study the boards. Share (also in the More menu at any time) sends plain text from `MurdlMatch.shareText`: headline, mode and clock, full emoji rows for up to 4 boards, one line per board above that, tested in `ShareTextTests`.
- Planned next version: iPhone, portrait only, one board per page with a board switcher strip (`TARGETED_DEVICE_FAMILY` 1,2).
- `Screenshots/iPad/` holds the six 2064x2752 App Store captures (eight boards, sixteen boards, Sprint, Helper Mode, Scores, one board). They come from the Debug-only demo hook in `Sources/MurdlIOS/App/Demo.swift`: launch the simulator build with `SIMCTL_CHILD_MURDL_DEMO=one|eight|sixteen|sprint|helper|scores` and it plays real guesses through the game API, then `xcrun simctl io <device> screenshot`. Nothing from it is compiled into archives.

Build for the simulator with:

```sh
xcodebuild -project Murdl.xcodeproj -scheme MurdlIOS -destination 'generic/platform=iOS Simulator' build
```

Run the engine tests on any platform with Swift 6:

```sh
cd MurdlCore && swift test
```

Generate the Xcode project with:

```sh
xcodegen generate
```

Build the native Mac app with:

```sh
xcodebuild -project Murdl.xcodeproj -scheme Murdl -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
```
