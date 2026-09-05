using System;
using System.Collections.Generic;
using System.Linq;

namespace Murdl.Desktop;

/// <summary>Everything around a match that is not a rule: typing, the clock and modes, helper,
/// records, and layout preferences. Mirrors the Mac app's MurdlGame. Raises Changed after every
/// state change so windows can redraw.</summary>
public sealed class GameSession : IDisposable
{
    public static readonly int[] BoardOptions = { 2, 4, 8, 16 };

    public Match Match { get; private set; }
    public Snapshot State { get; private set; }
    public string Typing { get; private set; } = "";
    public string Status { get; private set; } = "Ready";
    public string Mode { get; private set; }
    public string Layout { get; private set; }
    public bool Assisted { get; private set; }
    public bool TimedOut { get; private set; }
    public Clock Clock { get; private set; } = new();
    public double BonusSeconds { get; private set; }
    public int? FocusedBoard { get; private set; }
    public int LayoutColumns { get; set; } = 1;
    public List<GameRecord> Records { get; } = RecordStore.Load();
    public Settings Settings { get; }

    private bool _pausedForHelp, _pausedForBackground;

    public event Action? Changed;
    public event Action? ClockTicked;

    public GameSession(Settings settings)
    {
        Settings = settings;
        Mode = GameModes.All.Contains(settings.Mode) ? settings.Mode : "classic";
        Layout = settings.Layout == "strip" ? "strip" : "grid";
        var count = BoardOptions.Contains(settings.BoardCount) ? settings.BoardCount : 8;
        Match = new Match(count);
        State = Match.State();
    }

    public int BoardCount => State.BoardCount;
    public bool IsOver => State.IsOver;
    public ScoreSummary Summary => new(Records, BoardCount);

    // Game flow

    public void NewGame(int? boardCount = null)
    {
        var count = boardCount ?? BoardCount;
        Match.Dispose();
        Match = new Match(count);
        State = Match.State();
        Typing = ""; Status = "Ready"; Assisted = false; TimedOut = false;
        Clock = new Clock(); BonusSeconds = 0; FocusedBoard = null;
        Settings.BoardCount = count; Settings.Save();
        Changed?.Invoke();
    }

    public void SetMode(string mode)
    {
        if (mode == Mode || !GameModes.All.Contains(mode)) return;
        Mode = mode; Settings.Mode = mode; Settings.Save();
        NewGame();
    }

    public void Enter(string letter)
    {
        if (IsOver || Typing.Length >= 5) return;
        StartClockIfNeeded();
        SetTyping(Typing + letter.ToUpperInvariant());
    }

    public void Delete() { if (Typing.Length > 0) SetTyping(Typing[..^1]); }
    public void Clear() { if (Typing.Length > 0) SetTyping(""); }

    private void SetTyping(string letters)
    {
        Typing = letters; Status = "";
        Match.SetTyping(Typing);
        State = Match.State();
        Changed?.Invoke();
    }

    public void Submit()
    {
        switch (Match.Validate(Typing))
        {
            case 1: return;
            case 2: Status = "Enter 5 letters"; Changed?.Invoke(); return;
            case 3: Status = $"{Typing} is not in the dictionary"; Changed?.Invoke(); return;
        }
        var word = Typing;
        Typing = "";
        Play(word);
    }

    private void Play(string word)
    {
        StartClockIfNeeded();
        var solved = Match.Play(word);
        Match.SetTyping(Typing);
        State = Match.State();
        if (Mode == "sprint" && solved > 0) BonusSeconds += GameModes.SprintBonusPerSolve * solved;
        Status = State.DidWin ? $"Won MURDL {State.Score}" : State.IsOver ? $"Lost MURDL {State.Score}" : $"{State.SolvedCount} of {BoardCount} solved";
        if (State.IsOver) FinishGame();
        Changed?.Invoke();
    }

    public void HelperStep()
    {
        if (IsOver) return;
        var target = State.Boards.FirstOrDefault(b => !b.IsFinished);
        if (target == null) return;
        Assisted = true;
        Play(target.Answer);
        if (!IsOver) { Status = $"Helper solved board {target.Id + 1} with {target.Answer.ToUpperInvariant()}."; Changed?.Invoke(); }
    }

    private void FinishGame()
    {
        Clock.Pause();
        Records.Insert(0, new GameRecord
        {
            Date = DateTime.Now, BoardCount = BoardCount, SolvedCount = State.SolvedCount, GuessesUsed = State.CurrentRow,
            DidWin = State.DidWin, Score = State.Score, Seconds = (int)Math.Round(Clock.Elapsed), Mode = Mode,
            Assisted = Assisted, TimedOut = TimedOut,
        });
        RecordStore.Save(Records);
    }

    public void ClearRecords() { Records.Clear(); RecordStore.Save(Records); Changed?.Invoke(); }

    // Clock

    public double SprintBudget => GameModes.SprintSecondsPerBoard * BoardCount + BonusSeconds;
    public double SprintRemaining => Math.Max(0, SprintBudget - Clock.Elapsed);

    public string? ClockText => Mode switch
    {
        "stopwatch" => Clock.Format(Clock.Elapsed),
        "sprint" => Clock.Format(SprintRemaining),
        _ => null,
    };

    public string ClockCaption => IsOver ? "Final" : !Clock.HasStarted ? "Type to start" : Clock.IsRunning ? GameModes.Title(Mode) : "Paused";

    private void StartClockIfNeeded() { if (!Clock.HasStarted && !IsOver) Clock.Start(); }

    public void SetPaused(bool? help = null, bool? background = null)
    {
        if (help.HasValue) _pausedForHelp = help.Value;
        if (background.HasValue) _pausedForBackground = background.Value;
        if (_pausedForHelp || _pausedForBackground) Clock.Pause(); else if (!IsOver) Clock.Resume();
        ClockTicked?.Invoke();
    }

    /// <summary>Call a few times a second from a UI timer.</summary>
    public void Tick()
    {
        if (Mode == "sprint" && !IsOver && Clock.HasStarted && SprintRemaining <= 0)
        {
            Match.LoseUnfinished();
            State = Match.State();
            TimedOut = true;
            Status = $"Time's up. Lost MURDL {State.Score}";
            FinishGame();
            Changed?.Invoke();
        }
        ClockTicked?.Invoke();
    }

    // Layout and focus

    public void SetLayout(string layout)
    {
        Layout = layout == "strip" ? "strip" : "grid";
        Settings.Layout = Layout; Settings.Save();
        Changed?.Invoke();
    }

    public void ToggleLayout() => SetLayout(Layout == "grid" ? "strip" : "grid");

    public void FocusBoard(int? id) { FocusedBoard = id; Changed?.Invoke(); }

    public void MoveFocus(int dx, int dy)
    {
        var step = dx + dy * LayoutColumns;
        if (step == 0) return;
        var current = FocusedBoard ?? (step > 0 ? -1 : BoardCount);
        var next = current + step;
        if (next < 0 || next >= BoardCount) return;
        FocusedBoard = next;
        Changed?.Invoke();
    }

    public void Dispose() => Match.Dispose();
}
