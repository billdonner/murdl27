using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;

namespace Murdl.Desktop;

/// <summary>One finished game. Same fields as the Mac app's GameRecord.</summary>
public sealed class GameRecord
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public DateTime Date { get; set; }
    public int BoardCount { get; set; }
    public int SolvedCount { get; set; }
    public int GuessesUsed { get; set; }
    public bool DidWin { get; set; }
    public string Score { get; set; } = "";
    public int Seconds { get; set; }
    public string Mode { get; set; } = "classic";
    public bool Assisted { get; set; }
    public bool TimedOut { get; set; }

    public bool IsHonestWin => DidWin && !Assisted;
    public int MaxGuesses => BoardCount + 5;
    public string ResultText => Assisted ? (DidWin ? "Helper" : "Helper, lost")
        : TimedOut ? $"Time up {SolvedCount}/{BoardCount}"
        : DidWin ? "Won" : $"Lost {SolvedCount}/{BoardCount}";
    public string TimeText => Clock.Format(Seconds);
    public string ModeText => GameModes.Title(Mode);
}

public sealed class ScoreSummary
{
    public int Played, Won, CurrentStreak, BestStreak;
    public string? BestScore;
    public int? BestTime;
    public int WinPercent => Played == 0 ? 0 : (int)Math.Round(100.0 * Won / Played);

    /// <param name="records">Newest first.</param>
    public ScoreSummary(IReadOnlyList<GameRecord> records, int boardCount)
    {
        Played = records.Count;
        Won = records.Count(r => r.IsHonestWin);
        foreach (var r in records) { if (!r.IsHonestWin) break; CurrentStreak++; }
        var run = 0;
        foreach (var r in records.Reverse()) { run = r.IsHonestWin ? run + 1 : 0; BestStreak = Math.Max(BestStreak, run); }
        BestScore = records.Where(r => r.IsHonestWin).Select(r => r.Score).DefaultIfEmpty(null).Min(StringComparer.Ordinal);
        var times = records.Where(r => r.IsHonestWin && GameModes.IsTimed(r.Mode) && r.BoardCount == boardCount).Select(r => r.Seconds).ToList();
        BestTime = times.Count == 0 ? null : times.Min();
    }
}

public static class RecordStore
{
    private static readonly string File = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "MURDL", "records.json");
    private static readonly JsonSerializerOptions Json = new() { PropertyNameCaseInsensitive = true };

    public static List<GameRecord> Load()
    {
        try { return JsonSerializer.Deserialize<List<GameRecord>>(System.IO.File.ReadAllText(File), Json) ?? new(); }
        catch { return new(); }
    }

    public static void Save(List<GameRecord> records)
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(File)!);
            System.IO.File.WriteAllText(File, JsonSerializer.Serialize(records, Json));
        }
        catch { }
    }
}

public static class GameModes
{
    public static readonly string[] All = { "classic", "stopwatch", "sprint" };
    public const double SprintSecondsPerBoard = 45;
    public const double SprintBonusPerSolve = 10;
    public static string Title(string mode) => mode switch { "stopwatch" => "Stopwatch", "sprint" => "Sprint", _ => "Classic" };
    public static bool IsTimed(string mode) => mode != "classic";
}

/// <summary>Elapsed-time bookkeeping that survives pauses, like the Mac app's GameClock.</summary>
public sealed class Clock
{
    private double _accumulated;
    private DateTime? _runningSince;
    public bool HasStarted { get; private set; }
    public bool IsRunning => _runningSince.HasValue;

    public double Elapsed => _accumulated + (_runningSince.HasValue ? (DateTime.UtcNow - _runningSince.Value).TotalSeconds : 0);

    public void Start() { if (HasStarted) return; HasStarted = true; _runningSince = DateTime.UtcNow; }
    public void Pause() { if (!_runningSince.HasValue) return; _accumulated += (DateTime.UtcNow - _runningSince.Value).TotalSeconds; _runningSince = null; }
    public void Resume() { if (HasStarted && !_runningSince.HasValue) _runningSince = DateTime.UtcNow; }

    public static string Format(double seconds)
    {
        var whole = Math.Max(0, (int)Math.Floor(seconds));
        return $"{whole / 60}:{whole % 60:00}";
    }
}
