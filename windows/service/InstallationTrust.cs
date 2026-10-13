using System.Security.AccessControl;
using System.Security.Principal;
namespace Awake.Service;

internal static class InstallationTrust
{
    // Until signed-installer and pinned-publisher verification are implemented and
    // tested, the privileged host cannot run. No environment variable unlocks it.
    public static void RequireProductionIdentity() => throw new InvalidOperationException(
        "此源码预览不启动特权服务：尚未实现并验收受保护安装、WinVerifyTrust 与固定发布者校验。请勿安装。合盖功能关闭。");
    internal static void CheckDirectory(string path) => Check(new DirectoryInfo(path).GetAccessControl());
    internal static void CheckFile(string path) => Check(new FileInfo(path).GetAccessControl());
    private static void Check(FileSystemSecurity acl)
    {
        var system = new SecurityIdentifier(WellKnownSidType.LocalSystemSid, null);
        var admins = new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null);
        var owner = acl.GetOwner(typeof(SecurityIdentifier)) as SecurityIdentifier
            ?? throw new UnauthorizedAccessException("恢复目录没有可验证所有者");
        if (!owner.Equals(system) && !owner.Equals(admins)) throw new UnauthorizedAccessException("恢复目录所有者不是 SYSTEM/Administrators");
        const FileSystemRights mutation = FileSystemRights.Write | FileSystemRights.Delete | FileSystemRights.DeleteSubdirectoriesAndFiles | FileSystemRights.ChangePermissions | FileSystemRights.TakeOwnership;
        foreach (FileSystemAccessRule rule in acl.GetAccessRules(true, true, typeof(SecurityIdentifier)))
            if (rule.AccessControlType == AccessControlType.Allow && (rule.FileSystemRights & mutation) != 0 &&
                !rule.IdentityReference.Equals(system) && !rule.IdentityReference.Equals(admins))
                throw new UnauthorizedAccessException("恢复目录可被普通用户写入");
    }
}
