using System.ComponentModel;
using System.Windows;
using System.Windows.Input;

namespace Awake.App;

public partial class MainWindow : Window
{
    public MainWindow(MainViewModel model)
    {
        InitializeComponent(); DataContext = model;
        Resources["ContentMaxHeight"] = System.Math.Max(200, SystemParameters.WorkArea.Height - 170);
        Resources["HeroNumberSize"] = 42d;
        MaxHeight = SystemParameters.WorkArea.Height;
    }
    public void Reveal() { Show(); if (WindowState == WindowState.Minimized) WindowState = WindowState.Normal; Activate(); }
    internal void RevealPage(bool settings) { Pages.SelectedIndex = settings ? 1 : 0; Reveal(); }
    private void WindowClosing(object? sender, CancelEventArgs e)
    {
        if (((App)Application.Current).IsExiting || Application.Current.Dispatcher.HasShutdownStarted) return;
        e.Cancel = true; Hide();
        ((App)Application.Current).ShowCloseHint();
    }
    private void ExitClicked(object sender, RoutedEventArgs e) => ((App)Application.Current).RequestExit();
    protected override void OnPreviewKeyDown(KeyEventArgs e)
    {
        if (e.Key == Key.Escape && DataContext is MainViewModel model && model.IsActive)
        { model.TryStop(); e.Handled = true; }
        base.OnPreviewKeyDown(e);
    }
}
