using Awake.Core;
using System.Text.Json;

namespace Awake.Service;

internal sealed class ProtectedRecoveryStore : IRecoveryStore
{
    private readonly string path;
    public ProtectedRecoveryStore()
    {
        var directory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "KeepMyMacAwake", "recovery");
        // Only the future signed installer may provision this directory tree.
        // The service never creates/adopts a predictable path in shared ProgramData.
        var anchor = Path.GetDirectoryName(Path.GetDirectoryName(directory)!)!;
        CheckNotReparse(anchor);
        var root = Path.GetDirectoryName(directory)!;
        RequireProtectedDirectory(root); RequireProtectedDirectory(directory);
        path = Path.Combine(directory, "lid-v1.json");
    }
    private static void CheckNotReparse(string path)
    {
        if ((File.GetAttributes(path) & FileAttributes.ReparsePoint) != 0) throw new IOException("恢复路径不能包含链接");
    }
    private static void RequireProtectedDirectory(string path)
    {
        if (!Directory.Exists(path)) throw new IOException("恢复目录必须由可信安装程序预先配置");
        CheckNotReparse(path);
        InstallationTrust.CheckDirectory(path);
    }
    private void ValidateTree()
    {
        var directory = Path.GetDirectoryName(path)!;
        var root = Path.GetDirectoryName(directory)!;
        // Revalidate before every operation; do not follow renamed/replaced parents.
        CheckNotReparse(Path.GetDirectoryName(root)!);
        RequireProtectedDirectory(root); RequireProtectedDirectory(directory);
    }
    private bool JournalExists()
    {
        // File.Exists hides ACL/I/O failures as false; a privileged recovery path
        // must distinguish unavailable evidence from an absent record.
        FileAttributes attributes;
        try { attributes = File.GetAttributes(path); }
        catch (FileNotFoundException) { return false; }
        if ((attributes & (FileAttributes.ReparsePoint | FileAttributes.Directory)) != 0)
            throw new IOException("恢复记录必须是普通文件，不能是目录或链接");
        return true;
    }
    public LidRecoveryRecord? Load()
    {
        ValidateTree();
        if (!JournalExists()) return null;
        if ((File.GetAttributes(path) & FileAttributes.ReparsePoint) != 0) throw new IOException("恢复记录不能是链接");
        InstallationTrust.CheckFile(path);
        if (new FileInfo(path).Length > 4096) throw new IOException("恢复记录过长");
        return JsonSerializer.Deserialize<LidRecoveryRecord>(File.ReadAllText(path)) ?? throw new IOException("恢复记录为空");
    }
    public void Save(LidRecoveryRecord record)
    {
        ValidateTree();
        if (JournalExists()) throw new IOException("已有恢复记录，拒绝覆盖");
        var temporary = Path.Combine(Path.GetDirectoryName(path)!, Guid.NewGuid().ToString("N") + ".tmp");
        try
        {
            using (var file = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None, 4096, FileOptions.WriteThrough))
            { JsonSerializer.Serialize(file, record); file.Flush(true); }
            File.Move(temporary, path, false);
        }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }
    public void Clear()
    {
        ValidateTree();
        if (JournalExists()) { InstallationTrust.CheckFile(path); File.Delete(path); }
    }
}
