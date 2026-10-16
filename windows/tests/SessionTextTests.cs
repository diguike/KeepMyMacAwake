using Awake.Core;
using Xunit;
namespace Awake.Core.Tests;
// Same cases as macos/tests/SessionTextTests.swift so both clients word sessions alike.
public class SessionTextTests
{
    private static DateTime At(int day, int hour, int minute) => new(2026, 10, day, hour, minute, 0);
    [Fact] public void EndTimeNamesTheNextDay()
    {
        Assert.Equal("07:30 结束", SessionText.EndTime(At(13, 7, 30), At(13, 6, 30)));
        Assert.Equal("明天 07:05 结束", SessionText.EndTime(At(14, 7, 5), At(13, 23, 5)));
        Assert.Equal("2 天后 00:10 结束", SessionText.EndTime(At(15, 0, 10), At(13, 23, 50)));
    }
    [Theory] [InlineData(30, "不足 1 分钟")] [InlineData(45 * 60, "45 分钟")] [InlineData(8 * 3600, "8 小时")] [InlineData(90 * 60 + 59, "1 小时 30 分钟")]
    public void DurationText(double seconds, string expected) => Assert.Equal(expected, SessionText.Duration(seconds));
    [Fact] public void NumberPartsMatchMac()
    {
        Assert.Equal([new("6", "小时"), new SessionText.NumberPart("28", "分")], SessionText.Parts(6 * 3600 + 28 * 60));
        Assert.Equal([new("45", "分"), new SessionText.NumberPart("12", "秒")], SessionText.Parts(45 * 60 + 11.2));
        Assert.Equal([new SessionText.NumberPart("8", "小时")], SessionText.Parts(8 * 3600, false));
        Assert.Equal([new SessionText.NumberPart("24", "小时")], SessionText.Parts(24 * 3600, false));
        Assert.Equal([new("1", "小时"), new SessionText.NumberPart("30", "分")], SessionText.Parts(90 * 60, false));
        Assert.Equal([new SessionText.NumberPart("30", "分钟")], SessionText.Parts(30 * 60, false));
        Assert.Equal([new("0", "分"), new SessionText.NumberPart("0", "秒")], SessionText.Parts(-5));
    }
    [Fact] public void EndedAtMatchesMac()
    {
        Assert.Equal("07:10", SessionText.EndedAt(At(14, 7, 10), At(14, 9, 0)));
        Assert.Equal("昨天 23:10", SessionText.EndedAt(At(13, 23, 10), At(14, 9, 0)));
        Assert.Equal("10/11 07:05", SessionText.EndedAt(At(11, 7, 5), At(14, 9, 0)));
    }
    [Fact] public void LastResultKeepsTimesDurationAndReason() =>
        Assert.Equal("上次 2026/10/13 23:10–2026/10/14 07:10 · 运行 8 小时 · 设定时间已到", SessionText.LastResult(At(13, 23, 10), At(14, 7, 10), "设定时间已到"));
}
