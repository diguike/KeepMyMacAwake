using System.ComponentModel;
using System.Windows;
using System.Windows.Input;

namespace Awake.App;

public partial class MainWindow : Window
{
    public MainWindow(MainViewModel model) { InitializeComponent(); DataContext = model; }
    public void Reveal() { Show(); if (WindowState == WindowState.Minimized) WindowState = WindowState.Normal; Activate(); }
    private void WindowClosing(object? sender, CancelEventArgs e)
    {
        if (((App)Application.Current).IsExiting || Application.Current.Dispatcher.HasShutdownStarted) return;
        e.Cancel = true; Hide();
    }
    private void ExitClicked(object sender, RoutedEventArgs e) => ((App)Application.Current).RequestExit();
    protected override void OnPreviewKeyDown(KeyEventArgs e)
    {
        if (e.Key == Key.Escape && DataContext is MainViewModel model && model.IsActive)
        { model.TryStop(); e.Handled = true; }
        base.OnPreviewKeyDown(e);
    }
}
