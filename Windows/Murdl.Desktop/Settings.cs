using System;
using System.IO;
using System.Text.Json;

namespace Murdl.Desktop;

/// <summary>Per-user preferences, one JSON file in the application data folder.</summary>
public sealed class Settings
{
    public int BoardCount { get; set; } = 8;
    public string Mode { get; set; } = "classic";
    public string Layout { get; set; } = "grid";
    public bool KeyboardOpen { get; set; } = true;
    public int? KeyboardX { get; set; }
    public int? KeyboardY { get; set; }

    private static readonly string Dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "MURDL");
    private static readonly string File = Path.Combine(Dir, "settings.json");
    private static readonly JsonSerializerOptions Json = new() { WriteIndented = true, PropertyNameCaseInsensitive = true };

    public static Settings Load()
    {
        try { return JsonSerializer.Deserialize<Settings>(System.IO.File.ReadAllText(File), Json) ?? new Settings(); }
        catch { return new Settings(); }
    }

    public void Save()
    {
        try { Directory.CreateDirectory(Dir); System.IO.File.WriteAllText(File, JsonSerializer.Serialize(this, Json)); }
        catch { }
    }
}
