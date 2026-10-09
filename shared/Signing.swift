import Foundation
import Security
import AwakeCore

public enum Signing {
    public static func requirement(for executable: URL) throws -> String {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(executable as CFURL, [], &code) == errSecSuccess, let code = code,
              SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate), nil) == errSecSuccess else {
            throw AwakeError.backend("组件签名无效，请重新构建或安装")
        }
        var requirement: SecRequirement?
        var text: CFString?
        guard SecCodeCopyDesignatedRequirement(code, [], &requirement) == errSecSuccess,
              let requirement = requirement,
              SecRequirementCopyString(requirement, [], &text) == errSecSuccess, let text = text else {
            throw AwakeError.backend("无法取得组件签名身份")
        }
        return text as String
    }
    /// Immutable metadata in the helper's signed __TEXT,__info_plist section.
    public static func allowedClientRequirement() throws -> String {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var information: CFDictionary?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code = code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode = staticCode,
              SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let dict = information as? [String: Any],
              let plist = dict[kSecCodeInfoPList as String] as? [String: Any],
              let requirement = plist["AwakeClientRequirement"] as? String, !requirement.isEmpty else {
            throw AwakeError.backend("helper 缺少已签名的客户端身份，拒绝启动")
        }
        var parsed: SecRequirement?
        guard SecRequirementCreateWithString(requirement as CFString, [], &parsed) == errSecSuccess else {
            throw AwakeError.invalidRequest
        }
        return requirement
    }
}
