using Awake.Service;
using Awake.Platform;
using System.Runtime.InteropServices;
using System.Text;

int checks = 0;
void Check(bool value, string name) { if (!value) throw new Exception(name); checks++; }
void Reject(string json)
{
    try { ProtocolPolicy.Parse(Encoding.UTF8.GetBytes(json)); }
    catch (Exception e) when (e is InvalidDataException or System.Text.Json.JsonException or InvalidOperationException) { checks++; return; }
    throw new Exception("Accepted invalid input: " + json);
}
Check(Marshal.SizeOf<ReasonContext>() == 32, "REASON_CONTEXT ABI size");
Check(Marshal.OffsetOf<ReasonContext>(nameof(ReasonContext.SimpleReasonString)).ToInt64() == 8, "REASON_CONTEXT union offset");
foreach (var op in new[] { "status", "recover" })
    Check(ProtocolPolicy.MayExecute(ProtocolPolicy.Parse(Encoding.UTF8.GetBytes($"{{\"version\":1,\"operation\":\"{op}\"}}"))), op);
foreach (var op in new[] { "begin", "renew", "extend", "release" })
    Check(!ProtocolPolicy.MayExecute(ProtocolPolicy.Parse(Encoding.UTF8.GetBytes($"{{\"version\":1,\"operation\":\"{op}\"}}"))), "Privilege disabled: " + op);
Reject("{\"version\":2,\"operation\":\"status\"}");
Reject("{\"version\":1,\"operation\":\"shell\"}");
Reject("{\"version\":1,\"operation\":\"recover\",\"path\":\"x\"}");
Reject("{\"version\":1,\"operation\":\"status\",\"operation\":\"recover\"}");
Reject("{\"version\":1,\"operation\":null}");
Reject("[]");
Reject(new string(' ', 1025));
Check(!ProtocolPolicy.Denied().Success, "Disabled capability explicit response");
var fake = new FakeRequestFactory();
using (var backend = new WindowsPowerBackend(fake))
{
    backend.Start(false);
    Check(fake.Count == 1 && fake.Last!.SetTypes.SequenceEqual(new[] { 1 }), "system only");
    try { backend.Start(false); throw new Exception("duplicate start accepted"); } catch (InvalidOperationException) { checks++; }
    Check(fake.Count == 1, "duplicate start never increments request count");
    backend.Stop(); backend.Stop();
    Check(fake.Last!.Disposed && fake.Last.ClearTypes.SequenceEqual(new[] { 1 }), "stop idempotent");
    fake.FailType = 0;
    try { backend.Start(true); throw new Exception("display failure accepted"); } catch (IOException) { checks++; }
    Check(fake.Last!.Disposed && fake.Last.ClearTypes.SequenceEqual(new[] { 1 }), "partial start cleanup");
    fake.FailType = 1;
    try { backend.Start(false); throw new Exception("system failure accepted"); } catch (IOException) { checks++; }
    Check(fake.Last!.Disposed && fake.Last.ClearTypes.Count == 0, "initial request failure closes handle");
    fake.FailType = null; backend.Start(true); fake.Last!.FailClear = true;
    try { backend.Stop(); throw new Exception("clear failure accepted"); } catch (IOException) { checks++; }
    Check(fake.Last.Disposed && fake.Last.ClearTypes.SequenceEqual(new[] { 0, 1 }), "all clear attempted and handle closed despite failure");
}
var disposedBackend = new WindowsPowerBackend(new FakeRequestFactory());
disposedBackend.Dispose();
try { disposedBackend.Start(false); throw new Exception("disposed backend accepted start"); } catch (ObjectDisposedException) { checks++; }
Console.WriteLine($"{checks} service protocol/ABI/backend checks passed (mock requests; no Windows API or service installation).");

sealed class FakeRequestFactory : IRequestFactory
{
    public int Count; public int? FailType; public FakeRequest? Last;
    public IPowerRequest Create() { Count++; return Last = new FakeRequest { FailType = FailType }; }
}
sealed class FakeRequest : IPowerRequest
{
    public int? FailType; public bool FailClear, Disposed;
    public List<int> SetTypes = []; public List<int> ClearTypes = [];
    public void Set(int type) { if (type == FailType) throw new IOException("mock set failure"); SetTypes.Add(type); }
    public void Clear(int type) { ClearTypes.Add(type); if (FailClear) throw new IOException("mock clear failure"); }
    public void Dispose() { Disposed = true; }
}
