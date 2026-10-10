import Darwin
import Foundation
import XCTest
@testable import Spill

final class TokenUsageAntigravityQuotaProcessTests: XCTestCase {
    func testStdoutNullInputStderrAndPrivateWorkingDirectory() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let output = run("test -z \"$(cat)\" && printf 'status'; printf 'discard' >&2", in: directory)
        XCTAssertEqual(output, Data("status".utf8))
        let cwd = run("pwd", in: directory)
        let actualPath = try XCTUnwrap(String(data: try XCTUnwrap(cwd), encoding: .utf8))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let actual = try FileManager.default.attributesOfItem(atPath: actualPath)
        let expected = try FileManager.default.attributesOfItem(atPath: directory.path)
        XCTAssertEqual(actual[.systemFileNumber] as? NSNumber, expected[.systemFileNumber] as? NSNumber)
        XCTAssertEqual(actual[.systemNumber] as? NSNumber, expected[.systemNumber] as? NSNumber)
    }

    func testTimeoutAndCancellationStopOwnedChildren() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let script = "sleep 30 & echo $! > child.pid; wait"
        let start = Date()
        XCTAssertNil(run(script, in: directory, timeout: 0.2))
        XCTAssertLessThan(Date().timeIntervalSince(start), 2)
        assertChildStopped(in: directory)
        var checks = 0
        XCTAssertNil(run(script, in: directory, shouldCancel: { checks += 1; return checks > 20 }))
        assertChildStopped(in: directory)
    }

    func testSuccessCleansDetachedChildWithExactInheritedOwner() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let script = "/usr/bin/python3 -c 'import os,time; os.setsid(); open(\"child.pid\",\"w\").write(str(os.getpid())); time.sleep(30)' & sleep 0.5; printf done"
        XCTAssertEqual(run(script, in: directory), Data("done".utf8))
        assertChildStopped(in: directory)
    }

    func testOutputOverflowNonzeroAndPrecancelAreRejected() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertNil(run("printf '12345'", in: directory, maximumBytes: 4))
        XCTAssertNil(run("printf 'not a valid success'; exit 1", in: directory))
        XCTAssertNil(run("touch should-not-exist", in: directory, shouldCancel: { true }))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("should-not-exist").path))
    }

    private func run(_ script: String, in directory: URL, timeout: TimeInterval = 3,
                     maximumBytes: Int = 1024, shouldCancel: @escaping () -> Bool = { false }) -> Data? {
        TokenUsageAntigravityQuotaProcess.output(executable: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", script], directory: directory, timeout: timeout,
            maximumBytes: maximumBytes, shouldCancel: shouldCancel)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        return directory
    }

    private func assertChildStopped(in directory: URL, file: StaticString = #filePath, line: UInt = #line) {
        let text = try? String(contentsOf: directory.appendingPathComponent("child.pid"), encoding: .utf8)
        guard let text, let pid = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            XCTFail("Test child did not write its PID", file: file, line: line)
            return
        }
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        let exists = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size
        let running = exists && info.pbi_status != UInt32(SZOMB)
        if running { kill(pid, SIGKILL) }
        XCTAssertFalse(running, "Owned test child remained running", file: file, line: line)
    }
}
