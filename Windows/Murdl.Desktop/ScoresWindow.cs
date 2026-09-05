using Avalonia;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;

namespace Murdl.Desktop;

public sealed class ScoresWindow : Window
{
    private readonly GameSession _session;
    private readonly StackPanel _summary = new() { Orientation = Orientation.Horizontal, Spacing = 22 };
    private readonly Grid _table = new() { ColumnDefinitions = new ColumnDefinitions("150,60,90,120,*,70,70") };

    public ScoresWindow(GameSession session)
    {
        _session = session;
        Title = "Scores"; Width = 760; Height = 420; Background = Look.Ground; FontFamily = Look.Font;

        var clear = new Button { Content = "Clear", HorizontalAlignment = HorizontalAlignment.Right };
        clear.Click += (_, _) => _session.ClearRecords();
        var top = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto"), Margin = new Thickness(0, 0, 0, 12) };
        Grid.SetColumn(clear, 1);
        top.Children.Add(_summary); top.Children.Add(clear);

        var root = new Grid { RowDefinitions = new RowDefinitions("Auto,*"), Margin = new Thickness(16) };
        var scroller = new ScrollViewer { Content = _table };
        Grid.SetRow(top, 0); Grid.SetRow(scroller, 1);
        root.Children.Add(top); root.Children.Add(scroller);
        Content = root;

        _session.Changed += Refresh;
        Closed += (_, _) => _session.Changed -= Refresh;
        Refresh();
    }

    private static Control Stat(string title, string value) => new StackPanel
    {
        Children =
        {
            new TextBlock { Text = value, FontSize = 20, FontWeight = FontWeight.Black, Foreground = Look.Ink },
            new TextBlock { Text = title, FontSize = 11, Foreground = Look.Ink2 },
        }
    };

    private void Refresh()
    {
        var s = _session.Summary;
        _summary.Children.Clear();
        _summary.Children.Add(Stat("Played", s.Played.ToString()));
        _summary.Children.Add(Stat("Won", s.Won.ToString()));
        _summary.Children.Add(Stat("Win %", s.WinPercent.ToString()));
        _summary.Children.Add(Stat("Streak", s.CurrentStreak.ToString()));
        _summary.Children.Add(Stat("Best streak", s.BestStreak.ToString()));
        _summary.Children.Add(Stat("Best score", s.BestScore ?? "–"));
        _summary.Children.Add(Stat($"Best time ({_session.BoardCount})", s.BestTime is int t ? Clock.Format(t) : "–"));

        _table.Children.Clear(); _table.RowDefinitions.Clear();
        AddRow(0, new[] { "Date", "Boards", "Mode", "Result", "Score", "Guesses", "Time" }, header: true);
        var row = 1;
        foreach (var r in _session.Records)
        {
            AddRow(row++, new[] { r.Date.ToString("MMM d, h:mm tt"), r.BoardCount.ToString(), r.ModeText, r.ResultText, r.Score, $"{r.GuessesUsed}/{r.MaxGuesses}", r.TimeText },
                good: r.IsHonestWin);
        }
        if (_session.Records.Count == 0)
            AddRow(1, new[] { "Finish a game to record a score.", "", "", "", "", "", "" });
    }

    private void AddRow(int row, string[] cells, bool header = false, bool good = false)
    {
        _table.RowDefinitions.Add(new RowDefinition(GridLength.Auto));
        for (var c = 0; c < cells.Length; c++)
        {
            var text = new TextBlock
            {
                Text = cells[c], Margin = new Thickness(6, 5), FontSize = 13,
                FontWeight = header ? FontWeight.Bold : FontWeight.Normal,
                Foreground = header ? Look.Ink2 : (c == 3 && good ? Look.Correct : Look.Ink),
                FontFamily = c == 4 ? new FontFamily("Consolas, Menlo, monospace") : Look.Font,
            };
            Grid.SetRow(text, row); Grid.SetColumn(text, c);
            _table.Children.Add(text);
        }
    }
}
