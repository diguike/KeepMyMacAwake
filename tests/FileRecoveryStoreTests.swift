import XCTest
@testable import AwakeCore
#if os(Linux)
import Glibc
#else
import Darwin
#endif

final class FileRecoveryStoreTests: XCTestCase {
    private func directory() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }
    func testRoundTripAndPermissions() throws {
        let dir = directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let store = try FileRecoveryStore(directory: dir)
        XCTAssertNil(try store.load())
        let record = RecoveryRecord(created: Date(timeIntervalSince1970: 123))
        try store.save(record); XCTAssertEqual(try store.load(), record)
        let attributes = try FileManager.default.attributesOfItem(atPath: dir.appendingPathComponent("recovery.json").path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        try store.clear(); XCTAssertNil(try store.load())
    }
    func testSymlinkDirectoryIsRejected() throws {
        let target = directory(); let link = directory()
        defer { try? FileManager.default.removeItem(at: link); try? FileManager.default.removeItem(at: target) }
        _ = try FileRecoveryStore(directory: target)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        XCTAssertThrowsError(try FileRecoveryStore(directory: link))
    }
    func testSymlinkJournalIsRejected() throws {
        let dir = directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let store = try FileRecoveryStore(directory: dir)
        try FileManager.default.createSymbolicLink(atPath: dir.appendingPathComponent("recovery.json").path, withDestinationPath: "/etc/passwd")
        XCTAssertThrowsError(try store.load())
    }
    func testCorruptJournalIsPreserved() throws {
        let dir = directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let store = try FileRecoveryStore(directory: dir)
        let path = dir.appendingPathComponent("recovery.json")
        try Data("invalid".utf8).write(to: path)
        chmod(path.path, 0o600)
        XCTAssertThrowsError(try store.load())
        XCTAssertTrue(FileManager.default.fileExists(atPath: path.path))
    }
    func testPublicDirectoryIsRejected() throws {
        let dir = directory(); defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false)
        chmod(dir.path, 0o755)
        XCTAssertThrowsError(try FileRecoveryStore(directory: dir))
    }
}
