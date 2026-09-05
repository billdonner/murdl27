using System.Collections.Generic;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Layout;
using Avalonia.Media;

namespace Murdl.Desktop;

/// <summary>The small always-on-top letter-status keyboard. Typing goes to the game from here too.</summary>
public sealed class KeyboardWindow : Window
{
    private readonly GameSession _session;
    private readonly Dictionary<string, Border> _keys = new();

    public KeyboardWindow(GameSession session)
    {
        _session = session;
        Title = "Keyboard";
        Topmost = true; CanResize = false; ShowInTaskbar = false;
        SizeToContent = SizeToContent.WidthAndHeight;
        Background = Look.Ground; FontFamily = Look.Font;

        var rows = new StackPanel { Spacing = 4, Margin = new Thickness(10) };
        foreach (var row in new[] { "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM" })
        {
            var panel = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 4, HorizontalAlignment = HorizontalAlignment.Center };
            if (row == "ZXCVBNM") panel.Children.Add(Command("⏎", () => _session.Submit()));
            foreach (var ch in row)
            {
                var letter = ch.ToString();
                var box = new Border { Width = 30, Height = 32, CornerRadius = new CornerRadius(5), Background = Look.KeyFill,
                    Child = new TextBlock { Text = letter, Foreground = Look.Ink, FontWeight = FontWeight.Bold, FontSize = 13,
                        HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center } };
                box.PointerPressed += (_, _) => _session.Enter(letter);
                _keys[letter] = box;
                panel.Children.Add(box);
            }
            if (row == "ZXCVBNM") panel.Children.Add(Command("⌫", () => _session.Delete()));
            rows.Children.Add(panel);
        }
        Content = rows;

        if (session.Settings.KeyboardX is int x && session.Settings.KeyboardY is int y)
            Position = new PixelPoint(x, y);
        PositionChanged += (_, e) => { session.Settings.KeyboardX = e.Point.X; session.Settings.KeyboardY = e.Point.Y; session.Settings.Save(); };
        KeyDown += (_, e) => { if (InputRouter.Handle(_session, e)) e.Handled = true; };
        _session.Changed += Refresh;
        Closed += (_, _) => _session.Changed -= Refresh;
        Refresh();
    }

    private Border Command(string glyph, System.Action action)
    {
        var box = new Border { Width = 44, Height = 32, CornerRadius = new CornerRadius(5), Background = Look.KeyFill,
            Child = new TextBlock { Text = glyph, Foreground = Look.Ink, FontWeight = FontWeight.Bold, FontSize = 14,
                HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center } };
        box.PointerPressed += (_, _) => action();
        return box;
    }

    private void Refresh()
    {
        foreach (var (letter, box) in _keys)
        {
            _session.State.KeyMarks.TryGetValue(letter, out var mark);
            box.Background = mark switch { "correct" => Look.Correct, "present" => Look.Present, "absent" => Look.Absent, _ => Look.KeyFill };
        }
    }
}
