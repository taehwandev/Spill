import Darwin
import Foundation

/// Bounded, memory-only stdout. Null stdin/stderr and an owned process group
/// prevent status probes from hanging or leaving a helper running afterward.
enum TokenUsageAntigravityQuotaProcess {
    static func output(
        executable: URL,
        arguments: [String],
        directory: URL,
        timeout: TimeInterval,
        maximumBytes: Int = 1_048_576,
        shouldCancel: () -> Bool
    ) -> Data? {
        guard !shouldCancel() else { return nil }
        let ownership = TokenUsageAntigravityProcessOwnership()
        var environment = ProcessInfo.processInfo.environment
        environment[TokenUsageAntigravityProcessOwnership.markerKey] = ownership.marker
        let argv = ([executable.path] + arguments).map { strdup($0) } + [nil]
        let envp = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer {
            argv.forEach { free($0) }
            envp.forEach { free($0) }
        }
        var descriptors: [Int32] = [0, 0]
        guard pipe(&descriptors) == 0 else { return nil }
        defer { close(descriptors[0]) }
        var writeFD = descriptors[1]
        defer { if writeFD >= 0 { close(writeFD) } }
        var actions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        guard posix_spawn_file_actions_init(&actions) == 0 else { return nil }
        defer { posix_spawn_file_actions_destroy(&actions) }
        guard posix_spawnattr_init(&attributes) == 0 else { return nil }
        defer { posix_spawnattr_destroy(&attributes) }
        guard posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT)) == 0,
              posix_spawnattr_setpgroup(&attributes, 0) == 0,
              posix_spawn_file_actions_addchdir_np(&actions, directory.path) == 0,
              posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0) == 0,
              posix_spawn_file_actions_addopen(&actions, STDERR_FILENO, "/dev/null", O_WRONLY, 0) == 0,
              posix_spawn_file_actions_adddup2(&actions, writeFD, STDOUT_FILENO) == 0,
              posix_spawn_file_actions_addclose(&actions, descriptors[0]) == 0,
              posix_spawn_file_actions_addclose(&actions, writeFD) == 0
        else { return nil }
        var pid: pid_t = 0
        let spawnResult = argv.withUnsafeBufferPointer { args in
            envp.withUnsafeBufferPointer { env in
                posix_spawn(&pid, executable.path, &actions, &attributes, args.baseAddress!, env.baseAddress!)
            }
        }
        close(writeFD)
        writeFD = -1
        guard spawnResult == 0 else { return nil }
        defer { ownership.cleanup(group: pid) }
        _ = fcntl(descriptors[0], F_SETFL, O_NONBLOCK)
        return readOutput(fd: descriptors[0], pid: pid, timeout: timeout,
                          maximumBytes: maximumBytes, shouldCancel: shouldCancel)
    }

    private static func readOutput(
        fd: Int32, pid: pid_t, timeout: TimeInterval,
        maximumBytes: Int, shouldCancel: () -> Bool
    ) -> Data? {
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        var output = Data()
        var buffer = [UInt8](repeating: 0, count: 16_384)
        var status: Int32 = 0
        var reaped = false
        defer {
            if !reaped {
                kill(-pid, SIGKILL)
                while waitpid(pid, &status, 0) < 0, errno == EINTR {}
            }
        }
        while true {
            guard !shouldCancel(), ProcessInfo.processInfo.systemUptime < deadline else { return nil }
            while true {
                let count = read(fd, &buffer, buffer.count)
                if count <= 0 { break }
                guard output.count + count <= maximumBytes else { return nil }
                output.append(contentsOf: buffer.prefix(count))
            }
            if !reaped {
                let result = waitpid(pid, &status, WNOHANG)
                if result == pid {
                    reaped = true
                    // One more drain admits bytes written just before exit.
                    continue
                }
                if result < 0, errno != EINTR { return nil }
            } else {
                guard status & 0x7f == 0, (status >> 8) & 0xff == 0 else { return nil }
                return output
            }
            usleep(10_000)
        }
    }
}
