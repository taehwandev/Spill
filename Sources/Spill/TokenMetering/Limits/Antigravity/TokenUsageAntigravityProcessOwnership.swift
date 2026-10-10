import Darwin
import Foundation

/// Owns only processes spawned by this probe. A private inherited marker also
/// identifies helper children that detach from the original process group.
/// Never decodes or logs argv, environment values, or inspected process data.
struct TokenUsageAntigravityProcessOwnership {
    static let markerKey = "SPILL_AGY_QUOTA_OWNER"
    let marker = UUID().uuidString
    private let existingPIDs = Self.allPIDs()

    func cleanup(group: pid_t) {
        guard group > 0 else { return }
        kill(-group, SIGTERM)
        let detached = ownedPIDs()
        for pid in detached { kill(pid, SIGTERM) }
        usleep(100_000)
        kill(-group, SIGKILL)
        // Recheck exact ownership immediately before signaling a detached PID.
        for pid in ownedPIDs() { kill(pid, SIGKILL) }
    }

    private func ownedPIDs() -> Set<pid_t> {
        let expected = Data("\(Self.markerKey)=\(marker)".utf8)
        return Set(Self.allPIDs().subtracting(existingPIDs).filter { pid in
            var info = proc_bsdinfo()
            let size = Int32(MemoryLayout<proc_bsdinfo>.size)
            guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size,
                  info.pbi_uid == getuid()
            else { return false }
            return Self.hasEnvironmentMarker(pid: pid, expected: expected)
        })
    }

    private static func allPIDs() -> Set<pid_t> {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(count) + 64)
        let found = pids.withUnsafeMutableBytes {
            proc_listallpids($0.baseAddress, Int32($0.count))
        }
        guard found > 0 else { return [] }
        return Set(pids.prefix(Int(found)).filter { $0 > 0 })
    }

    private static func hasEnvironmentMarker(pid: pid_t, expected: Data) -> Bool {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var length = 0
        guard sysctl(&mib, 3, nil, &length, nil, 0) == 0,
              length > 4, length <= 1_048_576
        else { return false }
        var bytes = [UInt8](repeating: 0, count: length)
        let read = bytes.withUnsafeMutableBytes {
            sysctl(&mib, 3, $0.baseAddress, &length, nil, 0)
        }
        guard read == 0, length > 4 else { return false }
        let argc = bytes.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
        guard argc >= 0, argc <= 65_536 else { return false }
        var offset = 4
        // Skip executable path and argument bytes without interpreting them.
        guard skipString(in: bytes, limit: length, offset: &offset) else { return false }
        while offset < length, bytes[offset] == 0 { offset += 1 }
        for _ in 0..<argc {
            guard skipString(in: bytes, limit: length, offset: &offset) else { return false }
        }
        while offset < length {
            let start = offset
            guard skipString(in: bytes, limit: length, offset: &offset) else { return false }
            if Data(bytes[start..<(offset - 1)]) == expected { return true }
        }
        return false
    }

    private static func skipString(in bytes: [UInt8], limit: Int, offset: inout Int) -> Bool {
        while offset < limit, bytes[offset] != 0 { offset += 1 }
        guard offset < limit else { return false }
        offset += 1
        return true
    }
}
