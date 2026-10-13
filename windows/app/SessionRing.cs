using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace Awake.App;

public sealed class SessionRing : Control
{
    public static readonly DependencyProperty ProgressProperty = DependencyProperty.Register(nameof(Progress), typeof(double), typeof(SessionRing), new FrameworkPropertyMetadata(0d, FrameworkPropertyMetadataOptions.AffectsRender));
    public static readonly DependencyProperty IsRunningProperty = DependencyProperty.Register(nameof(IsRunning), typeof(bool), typeof(SessionRing), new FrameworkPropertyMetadata(false, FrameworkPropertyMetadataOptions.AffectsRender));
    public double Progress { get => (double)GetValue(ProgressProperty); set => SetValue(ProgressProperty, value); }
    public bool IsRunning { get => (bool)GetValue(IsRunningProperty); set => SetValue(IsRunningProperty, value); }
    protected override void OnRender(DrawingContext drawing)
    {
        base.OnRender(drawing);
        double radius = Math.Max(0, Math.Min(ActualWidth, ActualHeight) / 2 - 3);
        var center = new Point(ActualWidth / 2, ActualHeight / 2);
        drawing.PushOpacity(.18); drawing.DrawEllipse(null, new Pen(Foreground, 4), center, radius, radius); drawing.Pop();
        double progress = Math.Clamp(Progress, 0, 1);
        if (IsRunning && progress > .999) drawing.DrawEllipse(null, new Pen(Foreground, 4), center, radius, radius);
        else if (IsRunning && progress > 0)
        {
            double angle = progress * 2 * Math.PI;
            var geometry = new StreamGeometry();
            using (var path = geometry.Open())
            {
                path.BeginFigure(new Point(center.X, center.Y - radius), false, false);
                path.ArcTo(new Point(center.X + Math.Sin(angle) * radius, center.Y - Math.Cos(angle) * radius), new Size(radius, radius), 0, progress > .5, SweepDirection.Clockwise, true, false);
            }
            drawing.DrawGeometry(null, new Pen(Foreground, 4), geometry);
        }
        var cup = new StreamGeometry();
        using (var path = cup.Open())
        {
            path.BeginFigure(new Point(center.X - 10, center.Y - 4), false, false);
            path.LineTo(new Point(center.X + 8, center.Y - 4), true, false);
            path.LineTo(new Point(center.X + 8, center.Y + 6), true, false);
            path.BezierTo(new Point(center.X + 8, center.Y + 14), new Point(center.X - 10, center.Y + 14), new Point(center.X - 10, center.Y + 6), true, false);
            path.LineTo(new Point(center.X - 10, center.Y - 4), true, false);
            path.BeginFigure(new Point(center.X + 8, center.Y - 2), false, false);
            path.BezierTo(new Point(center.X + 19, center.Y - 2), new Point(center.X + 19, center.Y + 7), new Point(center.X + 8, center.Y + 7), true, false);
        }
        drawing.DrawGeometry(null, new Pen(Foreground, 2), cup);
    }
}
