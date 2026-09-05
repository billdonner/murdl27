using Avalonia.Input;
using Avalonia.Media;

namespace Murdl.Desktop;

/// <summary>The MURDL look, shared by every window. Colors match the Mac app and the web showcase.</summary>
internal static class Look
{
    public static readonly Color[] Accents =
    {
        Color.Parse("#1AB252"), Color.Parse("#F28C14"), Color.Parse("#1A7DEB"), Color.Parse("#DB3852"),
        Color.Parse("#8F5CE6"), Color.Parse("#00A1AB"), Color.Parse("#D4AB1F"), Color.Parse("#E0529E"),
        Color.Parse("#5C8C33"), Color.Parse("#CC5C1A"), Color.Parse("#3D52C7"), Color.Parse("#9E2433"),
        Color.Parse("#66339E"), Color.Parse("#1A737A"), Color.Parse("#997A14"), Color.Parse("#9E3870"),
    };
    public static Color Accent(int board) => Accents[board % Accents.Length];

    public static readonly IBrush Ground = new SolidColorBrush(Color.Parse("#15171D"));
    public static readonly IBrush Panel = new SolidColorBrush(Color.Parse("#1E2129"));
    public static readonly IBrush Ink = new SolidColorBrush(Color.Parse("#F1F0EA"));
    public static readonly IBrush Ink2 = new SolidColorBrush(Color.Parse("#9A9EA9"));
    public static readonly IBrush Correct = new SolidColorBrush(Color.Parse("#3DBE5B"));
    public static readonly IBrush Present = new SolidColorBrush(Color.Parse("#F2A33A"));
    public static readonly IBrush Absent = new SolidColorBrush(Color.Parse("#5E626C"));
    public static readonly IBrush KeyFill = new SolidColorBrush(Color.Parse("#2A2E38"));
    public static readonly IBrush Warn = new SolidColorBrush(Color.Parse("#F2A33A"));
    public static readonly IBrush Danger = new SolidColorBrush(Color.Parse("#E5423F"));
    public static readonly FontFamily Font = new("Inter, Segoe UI, Helvetica, sans-serif");

    public static IBrush MarkBrush(string mark, Color accent) => mark switch
    {
        "correct" => Correct, "present" => Present, "absent" => Absent,
        "editing" => new SolidColorBrush(accent, 0.45), _ => new SolidColorBrush(accent, 0.22),
    };
}

/// <summary>Routes unmodified keys to the session from any MURDL window.</summary>
internal static class InputRouter
{
    /// <returns>True when the key was consumed.</returns>
    public static bool Handle(GameSession session, KeyEventArgs e)
    {
        if (e.KeyModifiers != KeyModifiers.None && e.KeyModifiers != KeyModifiers.Shift) return false;
        switch (e.Key)
        {
            case >= Key.A and <= Key.Z: session.Enter(((char)('A' + (e.Key - Key.A))).ToString()); return true;
            case Key.Enter: session.Submit(); return true;
            case Key.Back: session.Delete(); return true;
            case Key.Escape: session.Clear(); return true;
            case Key.Left: session.MoveFocus(-1, 0); return true;
            case Key.Right: session.MoveFocus(1, 0); return true;
            case Key.Up: session.MoveFocus(0, -1); return true;
            case Key.Down: session.MoveFocus(0, 1); return true;
            case Key.F2: session.HelperStep(); return true;
            default: return false;
        }
    }
}
