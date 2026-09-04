# MURDL 27

Modern SwiftUI rebuild of the archived MURDL game.

- Source archive: `/Users/billdonner/old-swift/MURDL`
- App id: `com.billdonner.murdl`
- Target: native macOS 26.0 or later
- Modes: 2, 4, 8, or 16 boards, 5 letters, guesses = boards + 5 (8 boards is the classic 13-guess game)
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
