# MURDL 27

Modern SwiftUI rebuild of the archived MURDL game.

- Source archive: `/Users/billdonner/old-swift/MURDL`
- App id: `com.billdonner.murdl`
- Target: native macOS 26.0 or later
- Modes: 2, 4, 8, or 16 boards, 5 letters, guesses = boards + 5 (8 boards is the classic 13-guess game)
- Dictionaries: copied from `old-swift/MURDL/Documents/wtf/Dictionaries`
- Visual assets: copied from `old-swift/MURDL/Documents/wtf/wtf/Assets.xcassets`
- Help: bundled as `Sources/Murdl/Resources/Help.md`
- UI: each board has a distinct accent color and tinted empty rows
- Helper Mode: solves one unfinished board at a time from the app UI or Game menu
- Keyboard: small floating window (`Command-K`); typing works from any window via an app-wide key monitor; position and open state persist
- Board layout: grid (rows of up to 8, vertical scroll with the next row peeking) or horizontal strip (`Command-L`); scroll by trackpad swipe, scroll wheel, or arrow keys
- Scores: every finished game is recorded with result, score string, guesses, and time (`Command-Shift-S`)
- Keyboard font: cycle with `Command-Shift-F`
- Keyboard shortcuts live in the menu bar only; on-screen buttons mirror them

Generate the Xcode project with:

```sh
xcodegen generate
```

Build the native Mac app with:

```sh
xcodebuild -project Murdl.xcodeproj -scheme Murdl -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
```
