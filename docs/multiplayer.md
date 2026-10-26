# MURDL Multiplayer

Status: async challenges built for 2.4; bar games designed, not started.
Decisions (Bill, 2026-10-26): async challenges first, then bar games; multiplayer is a paid
unlock; challenges carry the player's name, which they can change any time.

Pattern source: Qross (`docs/business/regular-multiplayer-flows.md`, `MultiplayerPayload.swift`,
ADR-003): self-contained signed links, no server state, integrity not authenticity. Read for
patterns, written fresh here.

## 1. Async challenges

| Step | What happens |
|---|---|
| Send | After any finished game: Challenge a Friend (game-over card or More menu on iOS; header button, File menu, Command-Shift-M on the Mac). The sheet asks for a name the first time, then shares a link and message. The record is written when the player taps Send or Copy, so a cancelled offer leaves nothing. |
| Open | The link opens `1041soft.com/murdl/c/#<code>`, whose button opens `murdl://c/<code>`. The app shows the challenger and the score to beat, or the paywall. |
| Play | Same answers, board count, variant and mode. The player's own mode and variant are not touched and come back with the next practice game or Daily. Answers missing from an older word list are added as allowed guesses (`WordDictionary.allowing`). |
| Result | At game end the comparison sheet opens; the first result counts. Send Result returns a reply link with both results and no answers. |
| Reply | Opening a reply shows who won and fills in the sender's record. Free, no unlock needed. |

Winner order: unassisted beats Helper, then most boards solved, then fewest guesses, then less
time in Stopwatch and Sprint, else a tie.

### Link format

`v|kind|id|boards|variant|mode|answers|name|solved|guesses|seconds|flags` and, in a reply, the
friend's `name|solved|guesses|seconds|flags`. UTF-8, XORed with a fixed SplitMix64 stream so
the answers are not readable, then a 6-byte keyed FNV-1a checksum, then base64url. About 130
characters for 4 boards and 210 for 16. FNV rather than CryptoKit HMAC because MurdlCore also
builds on Windows. Like Qross, it stops corruption, not a determined cheater, which a friendly
game does not need to.

### Paid unlock

Non-consumable `com.billdonner.murdl27.multiplayer` ("MURDL Multiplayer"), StoreKit 2,
cached in `MurdlMultiplayerUnlocked` so it opens unlocked offline. Needed to send and to play;
not to read a reply. It must be created in App Store Connect (price, review screenshot) and
submitted with the first version that ships challenges.

### Later

- Universal links (`applinks:1041soft.com`, AASA under `.well-known`) so a tap opens the app
  without the web page; needs the Associated Domains capability on the App ID.
- Best of 3 and rematch, like Qross match rounds.
- Free reading of the challenge on the web page (would need the scramble key in public JS).

## 2. Bar games (designed, not started)

A hosted night: a Mac or iPad on the bar's TV is the host screen, everyone in the room plays
the same boards on their phone at the same moment, and a live leaderboard runs on the big
screen. Async challenges become the "challenge the table" button afterwards.

| Transport | For | Against |
|---|---|---|
| PeerLink (`~/peerlink`, used by PickledBalls) | No server or accounts; peer-to-peer Wi-Fi survives bar Wi-Fi that isolates clients | App required; Local Network prompt; untested in a crowd |
| Game Center live matches | Built in | 16-player cap, Game Center accounts, clunky for "this room" |
| Small server with a room code (Fly) | Any network, big rooms, could join from a browser (the Showcase spectator page already runs MURDL in JavaScript) | MURDL's first server: hosting, upkeep, privacy policy |

Recommendation: prototype on PeerLink with a Mac or iPad host and phones as players; add the
server and browser join only if venues want it.
