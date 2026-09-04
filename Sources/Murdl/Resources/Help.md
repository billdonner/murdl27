# MURDL Help

MURDL is Wordle with more boards. Every guess you type is played on every board at once, and each board has its own five-letter answer. Solve them all before the guesses run out.

## The basics

Type a five-letter word and press Return. The same word lands on every unfinished board, and each board colors it against its own answer:

- Green: right letter, right position.
- Orange: the letter is in that board's answer, but somewhere else.
- Gray: the letter is not in that board's answer.

A board turns green all the way across when it is solved and stops taking guesses. Keep going with the rest. You always have five more guesses than boards, so 2 boards gives 7 guesses, 8 gives 13, and 16 gives 21.

Letters you type appear on every unfinished board in the current row. Delete removes the last letter. A guess must be a real word, and any answer word is always accepted.

## Boards and layout

Choose 2, 4, 8, or 16 boards from the picker in the header or from File > Boards. Changing the count starts a new game, and MURDL remembers your choice.

Boards are laid out as a grid of up to eight per row, or as one horizontal strip. Switch with the layout button, View > Board Layout, or Command-L. When the boards do not all fit, the grid scrolls down with the next row peeking above the fold, and the strip scrolls sideways.

Move around with a two-finger swipe on the trackpad, a scroll wheel, or the arrow keys. Left and right step the highlight to the next board, up and down move a whole row, and the highlighted board scrolls into view. Click a board to highlight it. The highlight is only a pointer; it never changes which boards receive a guess.

## The keyboard window

A small floating keyboard shows the best result each letter has earned on any board: orange if it is present somewhere, green if it has been placed correctly anywhere, gray if every board has ruled it out. Type on your real keyboard from any window; click the floating keys only if you prefer the mouse.

Close the keyboard window if you do not need it and reopen it with Command-K. MURDL remembers where you put it and whether it was open.

## Modes and timers

Pick a mode from the header or File > Mode. Changing mode starts a new game.

- Classic: no clock on screen. Time is still recorded in Scores.
- Stopwatch: the clock counts up. Your fastest win at each board count is kept as a best time.
- Sprint: the clock counts down from 45 seconds per board. Every board you solve adds 10 seconds. The clock turns orange under 30 seconds and red under 10. At zero, every unfinished board is lost.

In both timed modes the clock does not start until your first keystroke, so you can study the board first. It pauses while Help is open or while MURDL is in the background, and resumes when you come back.

## Helper Mode

Helper Mode plays the game for you one board at a time. Turn it on with the sparkles button or Command-Shift-H. The helper bar names the next unfinished board and its answer; press Command-Shift-G to play that answer as the next guess. Letters you had already typed stay in place for your next guess.

A game that used the helper is recorded as assisted. It counts as played but never as a win, it breaks your streak, and it never sets a best time.

## Scores

Every finished game is recorded: date, boards, mode, result, score, guesses used, and time. Games you abandon with New Game are not recorded. Open Scores with Command-Shift-S.

The score string has one character per board, giving the row that board was solved on. Rows 10 and up are written as letters starting at A, so row 10 is A, row 13 is D, and row 21 is L. When every board is solved the characters are sorted lowest first, and a lower string is a better game. When a board is missed it scores as one past the last row and the characters are sorted highest first.

The summary shows games played, wins, win percentage, current and best streak, best score, and best time for the current board count. Clear removes every record.

## Keyboard shortcuts

- Command-N: new game.
- Command-1, 2, 3, 4: play 2, 4, 8, or 16 boards.
- Option-Command-1, 2, 3: Classic, Stopwatch, or Sprint mode.
- Return: submit the guess. Delete: remove the last letter.
- Arrow keys: move the board highlight.
- Command-Shift-H: Helper Mode on or off. Command-Shift-G: play the next helper step.
- Command-L: switch between grid and strip. Option-Command-G: grid. Option-Command-T: strip.
- Command-Shift-F: next keyboard font. Control-Command-1, 2, 3, 4: System, Rounded, Monospaced, or Serif.
- Command-K: show the keyboard window. Command-Shift-S: show Scores.
- Command-/: this help.
