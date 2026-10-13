using Awake.Core;
using Xunit;
namespace Awake.Core.Tests;
// Same cases as macos/tests/SessionTextTests.swift so both clients word sessions alike.
public class SessionTextTests
{
    private static DateTime At(int day, int hour, int minute) => new(2026, 10, day, hour, minute, 0);
    [Fact] public void EndTimeNamesTheNextDay()
    {
        Assert.Equal("预计 07:30 结束", SessionText.EndTime(At(13, 7, 30), At(13, 6, 30)));
        Assert.Equal("预计明天 07:05 结束", SessionText.EndTime(At(14, 7, 5), At(13, 23, 5)));
        Assert.Equal("预计 2 天后 00:10 结束", SessionText.EndTime(At(15, 0, 10), At(13, 23, 50)));
    }
    [Theory] [InlineData(30, "不足 1 分钟")] [InlineData(45 * 60, "45 分钟")] [InlineData(8 * 3600, "8 小时")] [InlineData(90 * 60 + 59, "1 小时 30 分钟")]
    public void DurationText(double seconds, string expected) => Assert.Equal(expected, SessionText.Duration(seconds));
    [Fact] public void LastResultKeepsTimesDurationAndReason() =>
        Assert.Equal("上次 23:10–07:10 · 运行 8 小时 · 设定时间已到", SessionText.LastResult(At(13, 23, 10), At(14, 7, 10), "设定时间已到"));
}
