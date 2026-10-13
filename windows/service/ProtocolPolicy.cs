using System.Text.Json;
namespace Awake.Service;

public sealed record ServiceRequest(int Version, string Operation);
public sealed record ServiceResponse(int Version, bool Success, string State, string? Reason);
public static class ProtocolPolicy
{
    public const int Version = 1;
    public const int MaxBytes = 1024;
    public const string PipeName = "KeepMyMacAwake.Recovery.v1";
    public static ServiceRequest Parse(ReadOnlySpan<byte> bytes)
    {
        if (bytes.Length > MaxBytes) throw new InvalidDataException("请求过长");
        using var document = JsonDocument.Parse(bytes.ToArray());
        var root = document.RootElement;
        if (root.ValueKind != JsonValueKind.Object || root.EnumerateObject().Count() != 2 ||
            !root.TryGetProperty("version", out var version) || !root.TryGetProperty("operation", out var operation) ||
            !version.TryGetInt32(out var number) || number != Version || operation.ValueKind != JsonValueKind.String)
            throw new InvalidDataException("协议版本或格式不受支持");
        var op = operation.GetString()!;
        if (op is not ("status" or "recover" or "begin" or "renew" or "extend" or "release"))
            throw new InvalidDataException("未知固定操作");
        return new(number, op);
    }
    public static bool MayExecute(ServiceRequest request) => request.Version == Version && request.Operation is "status" or "recover";
    public static ServiceResponse Denied() => new(Version, false, "unsupported", "开发预览未完成签名身份、热保护与机型验证；合盖租约被禁用");
}
