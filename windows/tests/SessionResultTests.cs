using System.Text.Json;
using Awake.Core;
using Xunit;

namespace Awake.Core.Tests;

public class SessionResultTests
{
    [Fact] public void CompletedResultRoundTripsWithoutRuntimeLease()
    {
        var result = new SessionResult(DateTimeOffset.UnixEpoch, DateTimeOffset.UnixEpoch.AddMinutes(60), "设定时间已到");
        string json = JsonSerializer.Serialize(result);
        Assert.Equal(result, JsonSerializer.Deserialize<SessionResult>(json));
        Assert.DoesNotContain("Lease", json); Assert.DoesNotContain("Text", json);
    }
    [Fact] public void InvalidHistoryIsNotACompletedSession()
    {
        Assert.False(new SessionResult(DateTimeOffset.UnixEpoch.AddMinutes(1), DateTimeOffset.UnixEpoch, "停止").IsValid);
        Assert.False(new SessionResult(DateTimeOffset.UnixEpoch, DateTimeOffset.UnixEpoch, "").IsValid);
        Assert.False(new SessionResult(DateTimeOffset.UnixEpoch, DateTimeOffset.UnixEpoch, new string('x', 301)).IsValid);
    }
    [Fact] public void OlderPreferencesDoNotOptIntoNotifications()
    {
        var preferences = JsonSerializer.Deserialize<Preferences>("{\"DurationMinutes\":480,\"ShowCountdown\":true}")!;
        Assert.True(preferences.IsValid); Assert.False(preferences.NotifyOnEnd);
    }
}
