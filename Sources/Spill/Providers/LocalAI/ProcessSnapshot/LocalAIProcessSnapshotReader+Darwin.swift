import Darwin
import Foundation

extension LocalAIProcessSnapshotReader {
    static func taskInfo(for processID: Int) -> proc_taskinfo? {
        var taskInfo = proc_taskinfo()
        let expectedSize = MemoryLayout<proc_taskinfo>.stride
        let result = withUnsafeMutablePointer(to: &taskInfo) { pointer in
            proc_pidinfo(
                Int32(processID),
                PROC_PIDTASKINFO,
                0,
                pointer,
                Int32(expectedSize)
            )
        }

        guard result == Int32(expectedSize) else {
            return nil
        }

        return taskInfo
    }

    static func processStartTimeNanoseconds(for processID: Int) -> UInt64? {
        var bsdInfo = proc_bsdinfo()
        let expectedSize = MemoryLayout<proc_bsdinfo>.stride
        let result = withUnsafeMutablePointer(to: &bsdInfo) { pointer in
            proc_pidinfo(
                Int32(processID),
                PROC_PIDTBSDINFO,
                0,
                pointer,
                Int32(expectedSize)
            )
        }

        guard result == Int32(expectedSize) else {
            return nil
        }

        return bsdInfo.pbi_start_tvsec * 1_000_000_000 + bsdInfo.pbi_start_tvusec * 1_000
    }

    static func memoryFootprintBytes(for processID: Int) -> UInt64? {
        var rusage = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &rusage) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { reboundPointer in
                proc_pid_rusage(
                    Int32(processID),
                    RUSAGE_INFO_V4,
                    reboundPointer
                )
            }
        }

        guard result == 0,
              rusage.ri_phys_footprint > 0
        else {
            return nil
        }

        return UInt64(rusage.ri_phys_footprint)
    }
}
