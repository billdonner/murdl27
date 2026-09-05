# MURDL Desktop (Windows front end)

A C# / Avalonia front end over the Swift engine in `../MurdlCore`. It is the Windows build
of MURDL, and because Avalonia is cross-platform the same code runs natively on macOS and
Linux, which is how it gets seen and tested on a Mac without a Windows machine.

- `Murdl.Desktop/Bridge.cs` — P/Invoke over `MurdlBridge` (`murdl.h`) plus the JSON snapshot model.
- `Murdl.Desktop/MainWindow.cs` — the whole window: header, boards, status, letter keys, typing.
- `Murdl.Desktop/make-mac-app.sh` — wraps a build in a `.app` bundle for launching on macOS.

## Build on a Mac

```sh
brew install --cask dotnet-sdk            # or: dotnet-install.sh --channel 9.0 into ~/.dotnet
cd MurdlCore && swift build -c release --product MurdlBridge && cd ..
cd Windows/Murdl.Desktop && dotnet build -c Release && ./make-mac-app.sh
open bin/Release/net9.0/MURDL.app
```

## Windows build

`.github/workflows/desktop.yml` builds the Swift DLL and the app on a Windows runner, runs the
app, types a guess, and uploads two artifacts: `MURDL-windows-x64` (a self-contained folder,
run `MURDL.exe`) and `MURDL-windows-screenshot` (what it looked like on the runner). The
macOS job uploads `MURDL-macOS-arm64.zip`, a self-contained bundle that needs no .NET install.

## Keys

Letters type, Enter submits, Backspace deletes, Escape clears, F2 plays a helper step,
F1 shows help, Ctrl-N starts a new game. Board count is the drop-down in the header.

## Not yet ported from the Mac app

Timers and modes, the score book, board layouts and arrow navigation, and the floating keyboard.
The engine already supports all of them; they are front-end work.
