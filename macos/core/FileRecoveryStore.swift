import Foundation
#if os(Linux)
import Glibc
#else
import Darwin
#endif

/// Private directory, exclusive no-follow files, fsync + atomic rename.
/// Production uses a fixed root-owned directory under /var/db; no client paths.
public final class FileRecoveryStore: RecoveryStore {
    private let directory: URL
    private let file: URL
    public init(directory: URL) throws {
        self.directory = directory; file = directory.appendingPathComponent("recovery.json")
        if mkdir(directory.path, 0o700) != 0 && errno != EEXIST { throw failure() }
        var info = stat()
        guard lstat(directory.path, &info) == 0, info.st_mode & mode_t(S_IFMT) == mode_t(S_IFDIR),
              info.st_uid == getuid(), info.st_mode & 0o077 == 0 else {
            throw AwakeError.backend("恢复目录的所有者或权限不安全")
        }
    }
    public func load() throws -> RecoveryRecord? {
        let fd = open(file.path, O_RDONLY | O_NOFOLLOW)
        if fd < 0 { if errno == ENOENT { return nil }; throw failure() }
        defer { _ = close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_uid == getuid(), info.st_mode & 0o077 == 0,
              info.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG), info.st_size > 0, info.st_size <= 4096 else {
            throw AwakeError.backend("恢复记录的权限或长度无效")
        }
        var bytes = [UInt8](repeating: 0, count: Int(info.st_size))
        let length = bytes.count
        var offset = 0
        while offset < length {
            let count = bytes.withUnsafeMutableBytes { read(fd, $0.baseAddress!.advanced(by: offset), length - offset) }
            if count < 0 && errno == EINTR { continue }
            guard count > 0 else { throw failure() }
            offset += count
        }
        return try JSONDecoder().decode(RecoveryRecord.self, from: Data(bytes))
    }
    public func save(_ record: RecoveryRecord) throws {
        let temporary = directory.appendingPathComponent(".pending-" + UUID().uuidString)
        let fd = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw failure() }
        defer { _ = close(fd); _ = unlink(temporary.path) }
        let data = try JSONEncoder().encode(record)
        try data.withUnsafeBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let count = write(fd, buffer.baseAddress!.advanced(by: offset), buffer.count - offset)
                if count < 0 && errno == EINTR { continue }
                guard count > 0 else { throw failure() }
                offset += count
            }
        }
        guard fsync(fd) == 0, rename(temporary.path, file.path) == 0 else { throw failure() }
        try syncDirectory()
    }
    public func clear() throws {
        guard unlink(file.path) == 0 || errno == ENOENT else { throw failure() }
        try syncDirectory()
    }
    private func syncDirectory() throws {
        let fd = open(directory.path, O_RDONLY | O_NOFOLLOW)
        guard fd >= 0 else { throw failure() }
        defer { _ = close(fd) }
        guard fsync(fd) == 0 else { throw failure() }
    }
    private func failure() -> AwakeError { .backend("恢复记录 I/O 失败：\(String(cString: strerror(errno)))") }
}
