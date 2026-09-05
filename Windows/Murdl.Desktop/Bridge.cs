using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Murdl.Desktop;

/// <summary>P/Invoke surface over MurdlBridge (murdl.h). .NET resolves "MurdlBridge" to
/// MurdlBridge.dll on Windows and libMurdlBridge.dylib on macOS.</summary>
internal static class Native
{
    private const string Lib = "MurdlBridge";

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern int murdl_version();
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern IntPtr murdl_match_new(int boardCount);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern void murdl_match_free(IntPtr match);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern void murdl_match_set_typing(IntPtr match, [MarshalAs(UnmanagedType.LPUTF8Str)] string letters);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern int murdl_match_validate(IntPtr match, [MarshalAs(UnmanagedType.LPUTF8Str)] string word);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern int murdl_match_play(IntPtr match, [MarshalAs(UnmanagedType.LPUTF8Str)] string word);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern IntPtr murdl_match_state_json(IntPtr match);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern void murdl_match_lose_unfinished(IntPtr match);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern void murdl_string_free(IntPtr s);

    public static string TakeString(IntPtr p)
    {
        if (p == IntPtr.Zero) return "";
        try { return Marshal.PtrToStringUTF8(p) ?? ""; }
        finally { murdl_string_free(p); }
    }
}

/// <summary>One live game, owned through a native handle.</summary>
public sealed class Match : IDisposable
{
    private IntPtr _handle;
    private static readonly JsonSerializerOptions Json = new() { PropertyNameCaseInsensitive = true };

    public Match(int boardCount)
    {
        _handle = Native.murdl_match_new(boardCount);
        if (_handle == IntPtr.Zero) throw new ArgumentException($"MurdlBridge refused {boardCount} boards");
    }

    public void SetTyping(string letters) => Native.murdl_match_set_typing(_handle, letters);

    /// <summary>0 playable, 1 game over, 2 wrong length, 3 not a word.</summary>
    public int Validate(string word) => Native.murdl_match_validate(_handle, word);

    /// <summary>Boards solved by the word, or -1 if refused.</summary>
    public int Play(string word) => Native.murdl_match_play(_handle, word);

    /// <summary>Sprint ran out: every unfinished board is lost.</summary>
    public void LoseUnfinished() => Native.murdl_match_lose_unfinished(_handle);

    public Snapshot State()
    {
        var json = Native.TakeString(Native.murdl_match_state_json(_handle));
        return JsonSerializer.Deserialize<Snapshot>(json, Json) ?? throw new InvalidOperationException("Empty snapshot");
    }

    public void Dispose()
    {
        if (_handle == IntPtr.Zero) return;
        Native.murdl_match_free(_handle);
        _handle = IntPtr.Zero;
    }
}

public sealed class Snapshot
{
    public int BoardCount { get; set; }
    public int MaxGuesses { get; set; }
    public int CurrentRow { get; set; }
    public int GuessesRemaining { get; set; }
    public int SolvedCount { get; set; }
    public bool IsOver { get; set; }
    public bool DidWin { get; set; }
    public string Score { get; set; } = "";
    public Dictionary<string, string> KeyMarks { get; set; } = new();
    public List<Board> Boards { get; set; } = new();

    public sealed class Board
    {
        public int Id { get; set; }
        public string Answer { get; set; } = "";
        public int? SolvedRow { get; set; }
        public bool IsLost { get; set; }
        public string Status { get; set; } = "";
        public List<List<Cell>> Rows { get; set; } = new();
        [JsonIgnore] public bool IsFinished => SolvedRow.HasValue || IsLost;
    }

    public sealed class Cell
    {
        public string Letter { get; set; } = "";
        public string Mark { get; set; } = "empty";
    }
}
