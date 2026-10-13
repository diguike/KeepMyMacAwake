using System;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using Awake.Core;
using Microsoft.Win32;

namespace Awake.App;

internal sealed class PreferencesStore
{
    private sealed record SavedSettings(Preferences Preferences, bool HasOnboarded);
    private readonly string directory;
    internal PreferencesStore(string? directory = null)
    {
        this.directory = directory ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "KeepMyMacAwake", "windows");
    }
    private readonly JsonSerializerOptions json = new() { WriteIndented = true, Converters = { new JsonStringEnumConverter() } };
    private string FilePath => Path.Combine(directory, "preferences.json");
    public (Preferences Preferences, bool HasOnboarded, string? Notice) Load()
    {
        try
        {
            if (!File.Exists(FilePath)) return (new(), false, null);
            if (new FileInfo(FilePath).Length > 65536) throw new InvalidDataException("设置文件过大");
            var value = JsonSerializer.Deserialize<SavedSettings>(File.ReadAllText(FilePath), json);
            if (value?.Preferences is null || !value.Preferences.IsValid) throw new InvalidDataException("设置字段无效");
            return (value.Preferences, value.HasOnboarded, null);
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or JsonException)
        { return (new(), false, "无法读取原设置，已使用默认值：" + error.Message); }
    }
    public void Save(Preferences preferences, bool hasOnboarded)
    {
        if (!preferences.IsValid) throw new ArgumentException("设置无效");
        Directory.CreateDirectory(directory);
        string temporary = Path.Combine(directory, ".pending-" + Guid.NewGuid().ToString("N"));
        try
        {
            using (var file = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            { JsonSerializer.Serialize(file, new SavedSettings(preferences, hasOnboarded), json); file.Flush(true); }
            File.Move(temporary, FilePath, true);
        }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }
}

internal static class LoginStartup
{
    private const string KeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string ValueName = "KeepMyMacAwake.Windows";
    private static string Command
    {
        get
        {
            string path = Environment.ProcessPath ?? throw new InvalidOperationException("无法取得应用路径");
            if (!Path.GetFileName(path).Equals("KeepMyMacAwake.Windows.exe", StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("登录启动需要使用已打包的 Windows 应用");
            return "\"" + path + "\" --startup";
        }
    }
    public static bool IsEnabled
    {
        get
        {
            using var key = Registry.CurrentUser.OpenSubKey(KeyPath);
            try { return key?.GetValue(ValueName) as string == Command; } catch (InvalidOperationException) { return false; }
        }
    }
    public static void Set(bool enabled)
    {
        using var key = Registry.CurrentUser.CreateSubKey(KeyPath, true);
        if (enabled) key.SetValue(ValueName, Command, RegistryValueKind.String);
        else key.DeleteValue(ValueName, false);
        if (enabled != IsEnabled) throw new IOException("登录启动设置读回失败");
    }
}
