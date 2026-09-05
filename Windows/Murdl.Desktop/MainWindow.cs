using System;
using System.Collections.Generic;
using System.Linq;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Input;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;

namespace Murdl.Desktop;

/// <summary>The board window: menu bar, header with counters and clock, boards in a grid or a
/// horizontal strip, and the status line. Rules live in the Swift engine; this only draws and types.</summary>
public sealed class MainWindow : Window
{
    private readonly GameSession _session;
    private readonly TextBlock _solved = new();
    private readonly TextBlock _guesses = new();
    private readonly TextBlock _clock = new();
    private readonly TextBlock _clockCaption = new();
    private readonly TextBlock _subtitle = new();
    private readonly TextBlock _statusText = new();
    private readonly ComboBox _boardCount = new();
    private readonly ComboBox _mode = new();
    private readonly ScrollViewer _scroller = new();
    private readonly Dictionary<(int board, int row, int col), (Border box, TextBlock text)> _tiles = new();
    private readonly Dictionary<int, (Border panel, TextBlock status)> _boards = new();
    private KeyboardWindow? _keyboard;
    private ScoresWindow? _scores;
    private Window? _help;
    private int _builtCount = -1;
    private string _builtLayout = "";
    private bool _syncing;

    public MainWindow()
    {
        _session = new GameSession(Settings.Load());
        Title = "MURDL";
        Width = 1180; Height = 760; MinWidth = 860; MinHeight = 560;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        Background = Look.Ground; FontFamily = Look.Font;

        Content = BuildLayout();
        _session.Changed += Refresh;
        _session.ClockTicked += RefreshClock;
        Refresh();

        var ticker = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(250) };
        ticker.Tick += (_, _) => _session.Tick();
        ticker.Start();

        KeyDown += (_, e) => { if (InputRouter.Handle(_session, e)) e.Handled = true; };
        Activated += (_, _) => _session.SetPaused(background: false);
        Deactivated += (_, _) => { if (!IsAnyMurdlWindowActive()) _session.SetPaused(background: true); };
        Opened += (_, _) => { if (_session.Settings.KeyboardOpen) ShowKeyboard(); Activate(); };
        Closing += (_, _) =>
        {
            _session.Settings.KeyboardOpen = _keyboard is { IsVisible: true };
            _session.Settings.Save();
        };
        Closed += (_, _) => { ticker.Stop(); _session.Dispose(); };
    }

    private bool IsAnyMurdlWindowActive() => IsActive || _keyboard is { IsActive: true } || _scores is { IsActive: true };

    // Layout

    private Control BuildLayout()
    {
        var title = new TextBlock { Text = "MURDL", FontSize = 34, FontWeight = FontWeight.Black, Foreground = Look.Ink };
        _subtitle.FontSize = 12; _subtitle.Foreground = Look.Ink2; _subtitle.Margin = new Thickness(0, 4, 0, 0);
        var brand = new StackPanel { Children = { title, _subtitle } };

        _solved.FontSize = 24; _solved.FontWeight = FontWeight.Black; _solved.Foreground = Look.Ink;
        _guesses.FontSize = 12; _guesses.Foreground = Look.Ink2;
        var counters = new StackPanel { HorizontalAlignment = HorizontalAlignment.Right, Children = { _solved, _guesses } };
        _clock.FontSize = 24; _clock.FontWeight = FontWeight.Black; _clock.Foreground = Look.Ink;
        _clockCaption.FontSize = 11; _clockCaption.Foreground = Look.Ink2;
        var clock = new StackPanel { HorizontalAlignment = HorizontalAlignment.Right, MinWidth = 70, Children = { _clock, _clockCaption } };

        foreach (var option in GameSession.BoardOptions) _boardCount.Items.Add($"{option} boards");
        _boardCount.SelectionChanged += (_, _) => { if (!_syncing && _boardCount.SelectedIndex >= 0) _session.NewGame(GameSession.BoardOptions[_boardCount.SelectedIndex]); };
        foreach (var mode in GameModes.All) _mode.Items.Add(GameModes.Title(mode));
        _mode.SelectionChanged += (_, _) => { if (!_syncing && _mode.SelectedIndex >= 0) _session.SetMode(GameModes.All[_mode.SelectedIndex]); };

        var helper = new Button { Content = "Helper step" }; helper.Click += (_, _) => _session.HelperStep();
        var newGame = new Button { Content = "New game" }; newGame.Click += (_, _) => _session.NewGame();
        var controls = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 10, VerticalAlignment = VerticalAlignment.Center,
            Children = { counters, clock, _boardCount, _mode, helper, newGame } };

        var header = new Grid { ColumnDefinitions = new ColumnDefinitions("Auto,*,Auto"), Margin = new Thickness(20, 10, 20, 10) };
        Grid.SetColumn(brand, 0); Grid.SetColumn(controls, 2);
        header.Children.Add(brand); header.Children.Add(controls);

        _statusText.FontSize = 18; _statusText.FontWeight = FontWeight.Bold; _statusText.Foreground = Look.Ink;
        _statusText.HorizontalAlignment = HorizontalAlignment.Center;
        var statusStrip = new Border { Background = Look.Panel, CornerRadius = new CornerRadius(8), Padding = new Thickness(12, 8),
            Margin = new Thickness(20, 10, 20, 16), Child = _statusText, MaxWidth = 700 };

        _scroller.Margin = new Thickness(20, 0);

        var root = new Grid { RowDefinitions = new RowDefinitions("Auto,Auto,*,Auto") };
        var menu = BuildMenu();
        Grid.SetRow(menu, 0); Grid.SetRow(header, 1); Grid.SetRow(_scroller, 2); Grid.SetRow(statusStrip, 3);
        root.Children.Add(menu); root.Children.Add(header); root.Children.Add(_scroller); root.Children.Add(statusStrip);
        return root;
    }

    private Menu BuildMenu()
    {
        MenuItem Item(string header, Action action, string? gesture = null)
        {
            var item = new MenuItem { Header = header };
            if (gesture != null) { item.InputGesture = KeyGesture.Parse(gesture); item.HotKey = KeyGesture.Parse(gesture); }
            item.Click += (_, _) => action();
            return item;
        }

        var boards = new MenuItem { Header = "Boards" };
        for (var i = 0; i < GameSession.BoardOptions.Length; i++)
        {
            var count = GameSession.BoardOptions[i];
            boards.Items.Add(Item($"{count} boards, {count + 5} guesses", () => _session.NewGame(count), $"Ctrl+D{i + 1}"));
        }
        var modes = new MenuItem { Header = "Mode" };
        for (var i = 0; i < GameModes.All.Length; i++)
        {
            var mode = GameModes.All[i];
            modes.Items.Add(Item(GameModes.Title(mode), () => _session.SetMode(mode), $"Ctrl+Alt+D{i + 1}"));
        }
        var file = new MenuItem { Header = "_File", Items = { Item("New game", () => _session.NewGame(), "Ctrl+N"), boards, modes, new Separator(), Item("Exit", Close) } };

        var game = new MenuItem { Header = "_Game", Items =
        {
            Item("Submit guess", () => _session.Submit()),
            Item("Delete letter", () => _session.Delete()),
            Item("Clear letters", () => _session.Clear()),
            new Separator(),
            Item("Helper step", () => _session.HelperStep(), "F2"),
            new Separator(),
            Item("Previous board", () => _session.MoveFocus(-1, 0)),
            Item("Next board", () => _session.MoveFocus(1, 0)),
            Item("Board above", () => _session.MoveFocus(0, -1)),
            Item("Board below", () => _session.MoveFocus(0, 1)),
        } };
        var view = new MenuItem { Header = "_View", Items =
        {
            Item("Grid layout", () => _session.SetLayout("grid"), "Ctrl+Alt+G"),
            Item("Horizontal strip", () => _session.SetLayout("strip"), "Ctrl+Alt+T"),
            Item("Toggle layout", () => _session.ToggleLayout(), "Ctrl+L"),
        } };
        var window = new MenuItem { Header = "_Window", Items =
        {
            Item("Show keyboard", ShowKeyboard, "Ctrl+K"),
            Item("Show scores", ShowScores, "Ctrl+Shift+S"),
            Item("Clear scores", () => _session.ClearRecords()),
        } };
        var help = new MenuItem { Header = "_Help", Items = { Item("MURDL help", ShowHelp, "F1") } };
        return new Menu { Items = { file, game, view, window, help }, Background = Look.Panel };
    }

    /// <summary>Rebuilds every board control. Only when the board count or layout changes.</summary>
    private void RebuildBoards()
    {
        var state = _session.State;
        _tiles.Clear(); _boards.Clear();
        var strip = _session.Layout == "strip";
        var columns = strip ? state.BoardCount : Math.Min(state.BoardCount, 8);
        var tile = strip ? 34.0 : state.BoardCount switch { <= 2 => 56.0, <= 4 => 48.0, <= 8 => 34.0, _ => 26.0 };
        var boardWidth = tile * 5 + 3 * 4 + 14 + 8;
        _session.LayoutColumns = columns;

        Avalonia.Controls.Panel host = strip
            ? new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Center }
            : new WrapPanel { HorizontalAlignment = HorizontalAlignment.Center, MaxWidth = columns * boardWidth + 8 };

        foreach (var board in state.Boards)
        {
            var accent = Look.Accent(board.Id);
            var rows = new StackPanel { Spacing = 3 };
            for (var r = 0; r < state.MaxGuesses; r++)
            {
                var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 3 };
                for (var c = 0; c < 5; c++)
                {
                    var text = new TextBlock { FontWeight = FontWeight.Black, FontSize = tile * 0.5, Foreground = Look.Ink,
                        HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
                    var box = new Border { Width = tile, Height = tile, CornerRadius = new CornerRadius(4), Child = text };
                    _tiles[(board.Id, r, c)] = (box, text);
                    row.Children.Add(box);
                }
                rows.Children.Add(row);
            }
            var number = new Border { Background = new SolidColorBrush(accent), CornerRadius = new CornerRadius(999), Padding = new Thickness(7, 3),
                Child = new TextBlock { Text = $"#{board.Id + 1}", Foreground = Brushes.White, FontWeight = FontWeight.Bold, FontSize = 12 } };
            var status = new TextBlock { Foreground = Look.Ink2, FontSize = 11, FontWeight = FontWeight.Bold, VerticalAlignment = VerticalAlignment.Center };
            var head = new Grid { ColumnDefinitions = new ColumnDefinitions("Auto,*,Auto") };
            Grid.SetColumn(number, 0); Grid.SetColumn(status, 2);
            head.Children.Add(number); head.Children.Add(status);
            var panel = new Border { Padding = new Thickness(7), Margin = new Thickness(4), CornerRadius = new CornerRadius(9),
                BorderThickness = new Thickness(1), Background = new SolidColorBrush(accent, 0.16),
                Child = new StackPanel { Spacing = 6, Children = { head, rows } } };
            var id = board.Id;
            panel.PointerPressed += (_, _) => _session.FocusBoard(id);
            _boards[board.Id] = (panel, status);
            host.Children.Add(panel);
        }
        _scroller.Content = host;
        _scroller.HorizontalScrollBarVisibility = strip ? ScrollBarVisibility.Auto : ScrollBarVisibility.Disabled;
        _scroller.VerticalScrollBarVisibility = strip ? ScrollBarVisibility.Disabled : ScrollBarVisibility.Auto;
        _builtCount = state.BoardCount; _builtLayout = _session.Layout;
    }

    /// <summary>Pushes the session into the controls.</summary>
    private void Refresh()
    {
        var state = _session.State;
        if (state.BoardCount != _builtCount || _session.Layout != _builtLayout) RebuildBoards();

        _syncing = true;
        _boardCount.SelectedIndex = Array.IndexOf(GameSession.BoardOptions, state.BoardCount);
        _mode.SelectedIndex = Array.IndexOf(GameModes.All, _session.Mode);
        _syncing = false;

        _subtitle.Text = $"{state.BoardCount} boards  {state.MaxGuesses} guesses";
        _solved.Text = $"{state.SolvedCount}/{state.BoardCount}";
        _guesses.Text = state.IsOver ? state.Score : $"{state.GuessesRemaining} left";
        _statusText.Text = _session.Status;
        RefreshClock();

        foreach (var board in state.Boards)
        {
            var accent = Look.Accent(board.Id);
            var (panel, status) = _boards[board.Id];
            var focused = _session.FocusedBoard == board.Id;
            panel.BorderBrush = focused ? Brushes.White : new SolidColorBrush(accent, board.IsFinished ? 1 : 0.6);
            panel.BorderThickness = new Thickness(focused ? 2 : 1);
            panel.Opacity = board.IsLost ? 0.7 : 1;
            status.Text = board.Status;
            status.Foreground = board.IsFinished ? new SolidColorBrush(accent) : Look.Ink2;
            if (focused) panel.BringIntoView();

            for (var r = 0; r < board.Rows.Count; r++)
                for (var c = 0; c < board.Rows[r].Count; c++)
                {
                    var cell = board.Rows[r][c];
                    var (box, text) = _tiles[(board.Id, r, c)];
                    text.Text = cell.Letter;
                    box.Background = Look.MarkBrush(cell.Mark, accent);
                    box.BorderThickness = new Thickness(cell.Mark == "editing" ? 2 : 1);
                    box.BorderBrush = cell.Mark == "editing" ? new SolidColorBrush(accent) : new SolidColorBrush(Colors.White, 0.08);
                    text.Foreground = cell.Mark == "empty" ? Look.Ink2 : Brushes.White;
                }
        }
    }

    private void RefreshClock()
    {
        var text = _session.ClockText;
        _clock.IsVisible = _clockCaption.IsVisible = text != null;
        if (text == null) return;
        _clock.Text = text;
        _clockCaption.Text = _session.ClockCaption;
        var remaining = _session.SprintRemaining;
        _clock.Foreground = _session.Mode == "sprint" && _session.Clock.HasStarted && !_session.IsOver
            ? (remaining <= 10 ? Look.Danger : remaining <= 30 ? Look.Warn : Look.Ink) : Look.Ink;
    }

    // Windows

    private void ShowKeyboard()
    {
        if (_keyboard is { IsVisible: true }) { _keyboard.Activate(); return; }
        _keyboard = new KeyboardWindow(_session);
        if (_session.Settings.KeyboardX == null)
            _keyboard.Position = new PixelPoint(Position.X + (int)Width - 380, Position.Y + (int)Height - 150);
        _keyboard.Closed += (_, _) => { _session.Settings.KeyboardOpen = false; _session.Settings.Save(); };
        _keyboard.Show(this);
        _session.Settings.KeyboardOpen = true; _session.Settings.Save();
        Activate();
    }

    private void ShowScores()
    {
        if (_scores is { IsVisible: true }) { _scores.Activate(); return; }
        _scores = new ScoresWindow(_session);
        _scores.Show(this);
    }

    private async void ShowHelp()
    {
        if (_help != null) return;
        const string text =
            "MURDL is Wordle with more boards. Type a five-letter word and press Enter; it is played on every unfinished board. " +
            "Green: right letter, right place. Orange: in that board's answer, elsewhere. Gray: not in that board's answer. " +
            "You get five more guesses than boards.\n\n" +
            "Modes: Classic has no clock. Stopwatch counts up from your first keystroke. Sprint counts down from 45 seconds per board, " +
            "adds 10 seconds per solved board, and loses every unfinished board at zero. The clock pauses while Help is open or MURDL is in the background. " +
            "Helper games are recorded as assisted and do not count as wins.\n\n" +
            "Keys: letters type, Enter submits, Backspace deletes, Escape clears, arrows move the board highlight, F2 plays a helper step. " +
            "Ctrl-N new game, Ctrl-1..4 boards, Ctrl-Alt-1..3 mode, Ctrl-L toggle grid and strip, Ctrl-K keyboard window, Ctrl-Shift-S scores, F1 help.";
        _help = new Window { Title = "MURDL Help", Width = 560, Height = 360, Background = Look.Ground, FontFamily = Look.Font,
            Content = new TextBlock { Text = text, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(20), Foreground = Look.Ink, FontSize = 14 } };
        _help.KeyDown += (_, e) => { if (e.Key is Key.Escape or Key.F1) _help.Close(); };
        _session.SetPaused(help: true);
        await _help.ShowDialog(this);
        _help = null;
        _session.SetPaused(help: false);
    }
}
