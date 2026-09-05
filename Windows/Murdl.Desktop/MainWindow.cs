using System;
using System.Collections.Generic;
using System.Linq;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Input;
using Avalonia.Layout;
using Avalonia.Media;

namespace Murdl.Desktop;

/// <summary>The whole MURDL window, built in code: header, boards, status line, letter status keys.
/// Every rule lives in the Swift engine behind <see cref="Match"/>; this class only draws and types.</summary>
public sealed class MainWindow : Window
{
    private static readonly int[] BoardOptions = { 2, 4, 8, 16 };
    private static readonly Color[] Accents =
    {
        Color.Parse("#1AB252"), Color.Parse("#F28C14"), Color.Parse("#1A7DEB"), Color.Parse("#DB3852"),
        Color.Parse("#8F5CE6"), Color.Parse("#00A1AB"), Color.Parse("#D4AB1F"), Color.Parse("#E0529E"),
        Color.Parse("#5C8C33"), Color.Parse("#CC5C1A"), Color.Parse("#3D52C7"), Color.Parse("#9E2433"),
        Color.Parse("#66339E"), Color.Parse("#1A737A"), Color.Parse("#997A14"), Color.Parse("#9E3870"),
    };
    private static readonly IBrush Ground = new SolidColorBrush(Color.Parse("#15171D"));
    private static readonly IBrush Panel = new SolidColorBrush(Color.Parse("#1E2129"));
    private static readonly IBrush Ink = new SolidColorBrush(Color.Parse("#F1F0EA"));
    private static readonly IBrush Ink2 = new SolidColorBrush(Color.Parse("#9A9EA9"));
    private static readonly IBrush Correct = new SolidColorBrush(Color.Parse("#3DBE5B"));
    private static readonly IBrush Present = new SolidColorBrush(Color.Parse("#F2A33A"));
    private static readonly IBrush Absent = new SolidColorBrush(Color.Parse("#5E626C"));
    private static readonly IBrush KeyFill = new SolidColorBrush(Color.Parse("#2A2E38"));

    private Match _match;
    private Snapshot _state;
    private string _typing = "";
    private string _status = "Ready";
    private bool _assisted;

    private readonly TextBlock _solved = new();
    private readonly TextBlock _guesses = new();
    private readonly TextBlock _statusText = new();
    private readonly WrapPanel _boards = new() { HorizontalAlignment = HorizontalAlignment.Center };
    private readonly StackPanel _keys = new() { Spacing = 4, HorizontalAlignment = HorizontalAlignment.Center };
    private readonly ComboBox _boardCount = new();
    private readonly Dictionary<(int board, int row, int col), (Border box, TextBlock text)> _tiles = new();
    private readonly Dictionary<string, Border> _keyBoxes = new();
    private readonly Dictionary<int, TextBlock> _boardStatus = new();

    public MainWindow()
    {
        Title = "MURDL";
        Width = 1280; Height = 820; MinWidth = 900; MinHeight = 600;
        Background = Ground;
        FontFamily = new FontFamily("Inter, Segoe UI, Helvetica, sans-serif");

        var count = BoardOptions.Contains(Settings.BoardCount) ? Settings.BoardCount : 8;
        _match = new Match(count);
        _state = _match.State();

        Content = BuildLayout(count);
        Rebuild();
        KeyDown += OnKeyDown;
        Closed += (_, _) => _match.Dispose();
    }

    // Layout

    private Control BuildLayout(int count)
    {
        var title = new TextBlock { Text = "MURDL", FontSize = 34, FontWeight = FontWeight.Black, Foreground = Ink };
        var subtitle = new TextBlock { FontSize = 12, Foreground = Ink2, Margin = new Thickness(0, 4, 0, 0) };
        subtitle.Bind(TextBlock.TextProperty, new Avalonia.Data.Binding { Source = this, Path = nameof(Subtitle) });
        var brand = new StackPanel { Children = { title, subtitle } };

        _solved.FontSize = 24; _solved.FontWeight = FontWeight.Bold; _solved.Foreground = Ink;
        _guesses.FontSize = 12; _guesses.Foreground = Ink2;
        var counters = new StackPanel { HorizontalAlignment = HorizontalAlignment.Right, Children = { _solved, _guesses } };

        foreach (var option in BoardOptions) _boardCount.Items.Add($"{option} boards, {option + 5} guesses");
        _boardCount.SelectedIndex = Array.IndexOf(BoardOptions, count);
        _boardCount.SelectionChanged += (_, _) =>
        {
            if (_boardCount.SelectedIndex >= 0) NewGame(BoardOptions[_boardCount.SelectedIndex]);
        };

        var helper = new Button { Content = "Helper step" };
        ToolTip.SetTip(helper, "Plays the answer of the next unfinished board (F2)");
        helper.Click += (_, _) => HelperStep();
        var newGame = new Button { Content = "New game" };
        newGame.Click += (_, _) => NewGame(_state.BoardCount);
        var help = new Button { Content = "?" };
        help.Click += (_, _) => ShowHelp();
        var controls = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8, VerticalAlignment = VerticalAlignment.Center,
            Children = { counters, _boardCount, helper, newGame, help } };

        var header = new Grid { ColumnDefinitions = new ColumnDefinitions("Auto,*,Auto"), Margin = new Thickness(0, 0, 0, 12) };
        Grid.SetColumn(brand, 0); Grid.SetColumn(controls, 2);
        header.Children.Add(brand); header.Children.Add(controls);

        _statusText.FontSize = 18; _statusText.FontWeight = FontWeight.Bold; _statusText.Foreground = Ink;
        _statusText.HorizontalAlignment = HorizontalAlignment.Center;
        var statusStrip = new Border { Background = Panel, CornerRadius = new CornerRadius(8), Padding = new Thickness(12, 8),
            Margin = new Thickness(0, 12, 0, 12), Child = _statusText, MaxWidth = 700, HorizontalAlignment = HorizontalAlignment.Stretch };

        var scroller = new ScrollViewer { Content = _boards, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };

        var root = new Grid { RowDefinitions = new RowDefinitions("Auto,*,Auto,Auto"), Margin = new Thickness(20, 16, 20, 20) };
        Grid.SetRow(header, 0); Grid.SetRow(scroller, 1); Grid.SetRow(statusStrip, 2); Grid.SetRow(_keys, 3);
        root.Children.Add(header); root.Children.Add(scroller); root.Children.Add(statusStrip); root.Children.Add(_keys);
        BuildKeys();
        return root;
    }

    public string Subtitle => $"{_state.BoardCount} boards  {_state.MaxGuesses} guesses";

    private void BuildKeys()
    {
        foreach (var row in new[] { "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM" })
        {
            var panel = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 4, HorizontalAlignment = HorizontalAlignment.Center };
            foreach (var ch in row)
            {
                var box = new Border { Width = 34, Height = 38, CornerRadius = new CornerRadius(5), Background = KeyFill,
                    Child = new TextBlock { Text = ch.ToString(), Foreground = Ink, FontWeight = FontWeight.Bold, FontSize = 14,
                        HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center } };
                var letter = ch.ToString();
                box.PointerPressed += (_, _) => Enter(letter);
                _keyBoxes[letter] = box;
                panel.Children.Add(box);
            }
            _keys.Children.Add(panel);
        }
    }

    /// <summary>Rebuilds every board control. Called when the board count changes or a new game starts.</summary>
    private void Rebuild()
    {
        _boards.Children.Clear();
        _tiles.Clear();
        _boardStatus.Clear();
        var columns = Math.Min(_state.BoardCount, 8);
        var tile = _state.BoardCount switch { <= 2 => 56.0, <= 4 => 48.0, <= 8 => 34.0, _ => 26.0 };
        _boards.MaxWidth = columns * (tile * 5 + 3 * 4 + 14 + 8) + 8;

        foreach (var board in _state.Boards)
        {
            var accent = Accents[board.Id % Accents.Length];
            var rows = new StackPanel { Spacing = 3 };
            for (var r = 0; r < _state.MaxGuesses; r++)
            {
                var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 3 };
                for (var c = 0; c < 5; c++)
                {
                    var text = new TextBlock { FontWeight = FontWeight.Black, FontSize = tile * 0.5, Foreground = Ink,
                        HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
                    var box = new Border { Width = tile, Height = tile, CornerRadius = new CornerRadius(4), Child = text };
                    _tiles[(board.Id, r, c)] = (box, text);
                    row.Children.Add(box);
                }
                rows.Children.Add(row);
            }
            var number = new Border { Background = new SolidColorBrush(accent), CornerRadius = new CornerRadius(999), Padding = new Thickness(7, 3),
                Child = new TextBlock { Text = $"#{board.Id + 1}", Foreground = Brushes.White, FontWeight = FontWeight.Bold, FontSize = 12 } };
            var status = new TextBlock { Foreground = Ink2, FontSize = 11, FontWeight = FontWeight.Bold, VerticalAlignment = VerticalAlignment.Center };
            _boardStatus[board.Id] = status;
            var head = new Grid { ColumnDefinitions = new ColumnDefinitions("Auto,*,Auto") };
            Grid.SetColumn(number, 0); Grid.SetColumn(status, 2);
            head.Children.Add(number); head.Children.Add(status);
            var panel = new Border { Padding = new Thickness(7), Margin = new Thickness(4), CornerRadius = new CornerRadius(9),
                BorderThickness = new Thickness(1), BorderBrush = new SolidColorBrush(accent, 0.6),
                Background = new SolidColorBrush(accent, 0.16), Tag = board.Id,
                Child = new StackPanel { Spacing = 6, Children = { head, rows } } };
            _boards.Children.Add(panel);
        }
        Refresh();
    }

    /// <summary>Pushes the current snapshot into the existing controls.</summary>
    private void Refresh()
    {
        _solved.Text = $"{_state.SolvedCount}/{_state.BoardCount}";
        _guesses.Text = _state.IsOver ? _state.Score : $"{_state.GuessesRemaining} left";
        _statusText.Text = _status;

        foreach (var board in _state.Boards)
        {
            var accent = Accents[board.Id % Accents.Length];
            var panel = (Border)_boards.Children[board.Id];
            panel.BorderBrush = new SolidColorBrush(accent, board.IsFinished ? 1 : 0.6);
            panel.Opacity = board.IsLost ? 0.7 : 1;
            var status = _boardStatus[board.Id];
            status.Text = board.Status;
            status.Foreground = board.IsFinished ? new SolidColorBrush(accent) : Ink2;

            for (var r = 0; r < board.Rows.Count; r++)
                for (var c = 0; c < board.Rows[r].Count; c++)
                {
                    var cell = board.Rows[r][c];
                    var (box, text) = _tiles[(board.Id, r, c)];
                    text.Text = cell.Letter;
                    box.Background = cell.Mark switch
                    {
                        "correct" => Correct, "present" => Present, "absent" => Absent,
                        "editing" => new SolidColorBrush(accent, 0.45), _ => new SolidColorBrush(accent, 0.22),
                    };
                    box.BorderThickness = new Thickness(cell.Mark == "editing" ? 2 : 1);
                    box.BorderBrush = cell.Mark == "editing" ? new SolidColorBrush(accent) : new SolidColorBrush(Colors.White, 0.08);
                    text.Foreground = cell.Mark is "empty" ? Ink2 : Brushes.White;
                }
        }

        foreach (var (letter, box) in _keyBoxes)
        {
            _state.KeyMarks.TryGetValue(letter, out var mark);
            box.Background = mark switch { "correct" => Correct, "present" => Present, "absent" => Absent, _ => KeyFill };
        }
    }

    // Input

    private void OnKeyDown(object? sender, KeyEventArgs e)
    {
        if (e.KeyModifiers != KeyModifiers.None && e.KeyModifiers != KeyModifiers.Shift)
        {
            if (e.KeyModifiers.HasFlag(KeyModifiers.Control) && e.Key == Key.N) { NewGame(_state.BoardCount); e.Handled = true; }
            return;
        }
        switch (e.Key)
        {
            case >= Key.A and <= Key.Z: Enter(((char)('A' + (e.Key - Key.A))).ToString()); break;
            case Key.Enter: Submit(); break;
            case Key.Back: if (_typing.Length > 0) SetTyping(_typing[..^1]); break;
            case Key.Escape: SetTyping(""); break;
            case Key.F2: HelperStep(); break;
            case Key.F1: ShowHelp(); break;
            default: return;
        }
        e.Handled = true;
    }

    private void Enter(string letter)
    {
        if (_state.IsOver || _typing.Length >= 5) return;
        SetTyping(_typing + letter);
    }

    private void SetTyping(string letters)
    {
        _typing = letters;
        _status = "";
        _match.SetTyping(_typing);
        _state = _match.State();
        Refresh();
    }

    private void Submit()
    {
        switch (_match.Validate(_typing))
        {
            case 1: return;
            case 2: _status = "Enter 5 letters"; Refresh(); return;
            case 3: _status = $"{_typing} is not in the dictionary"; Refresh(); return;
        }
        var word = _typing;
        _typing = "";
        Play(word);
    }

    private void Play(string word)
    {
        _match.Play(word);
        _state = _match.State();
        _status = _state.DidWin ? $"Won MURDL {_state.Score}"
                : _state.IsOver ? $"Lost MURDL {_state.Score}"
                : $"{_state.SolvedCount} of {_state.BoardCount} solved";
        if (_state.IsOver && _assisted) _status += " (helper)";
        Refresh();
    }

    private void HelperStep()
    {
        var target = _state.Boards.FirstOrDefault(b => !b.IsFinished);
        if (target == null) return;
        _assisted = true;
        Play(target.Answer);
        if (!_state.IsOver) { _status = $"Helper solved board {target.Id + 1} with {target.Answer.ToUpperInvariant()}."; Refresh(); }
    }

    private void NewGame(int boardCount)
    {
        _match.Dispose();
        _match = new Match(boardCount);
        _state = _match.State();
        _typing = ""; _status = "Ready"; _assisted = false;
        Settings.BoardCount = boardCount;
        Rebuild();
    }

    private async void ShowHelp()
    {
        var text = "MURDL is Wordle with more boards. Type a five-letter word and press Enter; it is played on every unfinished board.\n\n" +
                   "Green: right letter, right place. Orange: in that board's answer, elsewhere. Gray: not in that board's answer.\n\n" +
                   "You get five more guesses than boards. Backspace removes a letter, Escape clears them, F2 plays a helper step, Ctrl-N starts a new game.";
        var dialog = new Window { Title = "MURDL Help", Width = 520, Height = 300, Background = Ground,
            Content = new TextBlock { Text = text, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(20), Foreground = Ink, FontSize = 14 } };
        await dialog.ShowDialog(this);
    }
}

/// <summary>Tiny settings store: a JSON file in the user's application data folder.</summary>
internal static class Settings
{
    private static readonly string Path = System.IO.Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "MURDL", "settings.json");

    public static int BoardCount
    {
        get
        {
            try
            {
                var doc = System.Text.Json.JsonDocument.Parse(System.IO.File.ReadAllText(Path));
                return doc.RootElement.GetProperty("boardCount").GetInt32();
            }
            catch { return 8; }
        }
        set
        {
            try
            {
                System.IO.Directory.CreateDirectory(System.IO.Path.GetDirectoryName(Path)!);
                System.IO.File.WriteAllText(Path, $"{{\"boardCount\":{value}}}");
            }
            catch { }
        }
    }
}
