using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace Awake.App;

/// Width-adaptive remaining ticks, matching the Mac status card.
public sealed class TickMeter : Control
{
    public static readonly DependencyProperty ProgressProperty = DependencyProperty.Register(nameof(Progress), typeof(double), typeof(TickMeter), new FrameworkPropertyMetadata(0d, FrameworkPropertyMetadataOptions.AffectsRender));
    public static readonly DependencyProperty StartBrushProperty = DependencyProperty.Register(nameof(StartBrush), typeof(Brush), typeof(TickMeter), new FrameworkPropertyMetadata(Brushes.Orange, FrameworkPropertyMetadataOptions.AffectsRender));
    public static readonly DependencyProperty TrackBrushProperty = DependencyProperty.Register(nameof(TrackBrush), typeof(Brush), typeof(TickMeter), new FrameworkPropertyMetadata(Brushes.Gray, FrameworkPropertyMetadataOptions.AffectsRender));
    public double Progress { get => (double)GetValue(ProgressProperty); set => SetValue(ProgressProperty, value); }
    public Brush StartBrush { get => (Brush)GetValue(StartBrushProperty); set => SetValue(StartBrushProperty, value); }
    public Brush TrackBrush { get => (Brush)GetValue(TrackBrushProperty); set => SetValue(TrackBrushProperty, value); }
    protected override void OnRender(DrawingContext drawing)
    {
        base.OnRender(drawing);
        int count = Math.Max(8, (int)((ActualWidth + 2.5) / 5));
        double width = Math.Max(1, (ActualWidth - 2.5 * (count - 1)) / count);
        int filled = (int)Math.Ceiling(Math.Clamp(Progress, 0, 1) * count);
        for (int index = 0; index < count; index++)
        {
            Brush brush = TrackBrush;
            if (index < filled)
            {
                brush = Foreground;
                if (StartBrush is SolidColorBrush start && Foreground is SolidColorBrush end)
                {
                    double t = (double)index / Math.Max(1, count - 1);
                    brush = new SolidColorBrush(Color.FromRgb((byte)(start.Color.R + (end.Color.R - start.Color.R) * t),
                        (byte)(start.Color.G + (end.Color.G - start.Color.G) * t), (byte)(start.Color.B + (end.Color.B - start.Color.B) * t)));
                }
            }
            drawing.DrawRoundedRectangle(brush, null, new Rect(index * (width + 2.5), 0, width, ActualHeight), width / 2, width / 2);
        }
    }
}
