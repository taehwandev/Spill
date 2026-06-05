import Foundation
import Darwin

final class TokenUsageBridgeServer: @unchecked Sendable {
    static let defaultPort: UInt16 = 48731

    private let store: TokenUsageStore
    private let port: UInt16
    private let queue = DispatchQueue(label: "app.spill.token-usage-bridge")
    private var listenSocket: Int32 = -1
    private var acceptSource: DispatchSourceRead?

    init(
        store: TokenUsageStore = TokenUsageStore(),
        port: UInt16 = TokenUsageBridgeServer.defaultPort
    ) {
        self.store = store
        self.port = port
    }

    func start() throws {
        guard acceptSource == nil else {
            return
        }

        let socket = try makeLoopbackSocket(port: port)
        let source = DispatchSource.makeReadSource(fileDescriptor: socket, queue: queue)

        source.setEventHandler { [weak self] in
            self?.acceptAvailableConnections()
        }
        source.setCancelHandler {
            Darwin.close(socket)
        }

        listenSocket = socket
        acceptSource = source
        source.resume()
    }

    func stop() {
        acceptSource?.cancel()
        acceptSource = nil
        listenSocket = -1
    }

    private func makeLoopbackSocket(port: UInt16) throws -> Int32 {
        let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard socket >= 0 else {
            throw currentPOSIXError()
        }

        do {
            var reuseAddress: Int32 = 1
            guard setsockopt(
                socket,
                SOL_SOCKET,
                SO_REUSEADDR,
                &reuseAddress,
                socklen_t(MemoryLayout<Int32>.size)
            ) == 0 else {
                throw currentPOSIXError()
            }

            try setNonBlocking(socket)

            var address = sockaddr_in()
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            address.sin_family = sa_family_t(AF_INET)
            address.sin_port = port.bigEndian
            address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

            let bindResult = withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                    Darwin.bind(
                        socket,
                        sockaddrPointer,
                        socklen_t(MemoryLayout<sockaddr_in>.size)
                    )
                }
            }
            guard bindResult == 0 else {
                throw currentPOSIXError()
            }

            guard Darwin.listen(socket, SOMAXCONN) == 0 else {
                throw currentPOSIXError()
            }

            return socket
        } catch {
            Darwin.close(socket)
            throw error
        }
    }

    private func setNonBlocking(_ socket: Int32) throws {
        let flags = fcntl(socket, F_GETFL, 0)
        guard flags >= 0 else {
            throw currentPOSIXError()
        }
        guard fcntl(socket, F_SETFL, flags | O_NONBLOCK) == 0 else {
            throw currentPOSIXError()
        }
    }

    private func acceptAvailableConnections() {
        while listenSocket >= 0 {
            let clientSocket = Darwin.accept(listenSocket, nil, nil)
            if clientSocket >= 0 {
                try? setBlocking(clientSocket)
                handle(clientSocket: clientSocket)
                continue
            }

            if errno == EWOULDBLOCK || errno == EAGAIN {
                return
            }
            return
        }
    }

    private func handle(clientSocket: Int32) {
        queue.async { [weak self] in
            guard let self else {
                Darwin.close(clientSocket)
                return
            }

            var noSigPipe: Int32 = 1
            setsockopt(
                clientSocket,
                SOL_SOCKET,
                SO_NOSIGPIPE,
                &noSigPipe,
                socklen_t(MemoryLayout<Int32>.size)
            )

            defer {
                Darwin.close(clientSocket)
            }

            let request = self.readHTTPRequest(from: clientSocket)
            let response = self.response(for: request)
            self.send(response, to: clientSocket)
        }
    }

    private func setBlocking(_ socket: Int32) throws {
        let flags = fcntl(socket, F_GETFL, 0)
        guard flags >= 0 else {
            throw currentPOSIXError()
        }
        guard fcntl(socket, F_SETFL, flags & ~O_NONBLOCK) == 0 else {
            throw currentPOSIXError()
        }
    }

    private func readHTTPRequest(from socket: Int32) -> Data {
        var request = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)

        while request.count < 128 * 1024 {
            let bytesRead = Darwin.recv(socket, &buffer, buffer.count, 0)
            if bytesRead > 0 {
                request.append(contentsOf: buffer.prefix(bytesRead))
                if isCompleteHTTPRequest(request) {
                    break
                }
                continue
            }

            if bytesRead == 0 {
                break
            }

            if errno == EINTR {
                continue
            }

            break
        }

        return request
    }

    private func isCompleteHTTPRequest(_ data: Data) -> Bool {
        guard let headerEnd = data.range(of: Data("\r\n\r\n".utf8)),
              let headerText = String(data: data[..<headerEnd.lowerBound], encoding: .utf8)
        else {
            return false
        }

        let contentLength = headerText
            .components(separatedBy: "\r\n")
            .compactMap { line -> Int? in
                let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
                guard parts.count == 2,
                      parts[0].caseInsensitiveCompare("Content-Length") == .orderedSame
                else {
                    return nil
                }
                return Int(parts[1].trimmingCharacters(in: .whitespaces))
            }
            .first ?? 0

        return data.count - headerEnd.upperBound >= contentLength
    }

    private func send(_ data: Data, to socket: Int32) {
        data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                return
            }

            var offset = 0
            while offset < rawBuffer.count {
                let bytesSent = Darwin.send(
                    socket,
                    baseAddress.advanced(by: offset),
                    rawBuffer.count - offset,
                    0
                )
                if bytesSent > 0 {
                    offset += bytesSent
                } else if errno != EINTR {
                    return
                }
            }
        }
    }

    func response(for requestData: Data) -> Data {
        guard let request = TokenUsageBridgeRequest(data: requestData) else {
            return httpResponse(status: 400, body: errorBody("invalid_request"))
        }

        switch (request.method, request.path) {
        case ("OPTIONS", _):
            return httpResponse(status: 204, body: Data())
        case ("GET", "/v1/usage/health"):
            return httpResponse(status: 200, body: Data(#"{"status":"ok","source":"spill_local_app"}"#.utf8))
        case ("GET", "/v1/usage/events"):
            do {
                return httpResponse(status: 200, body: try store.envelopeData())
            } catch {
                return httpResponse(status: 500, body: errorBody("store_read_failed"))
            }
        case ("POST", "/v1/usage/events"):
            do {
                let event = try TokenUsageSanitizer.sanitizeEventJSONData(request.body)
                let events = try store.appendEvent(event)
                return httpResponse(
                    status: 201,
                    body: try TokenUsageSanitizer.envelopeData(events: events)
                )
            } catch {
                return httpResponse(status: 400, body: errorBody("invalid_usage_event"))
            }
        case ("DELETE", "/v1/usage/events"):
            do {
                try store.clearEvents()
                return httpResponse(
                    status: 200,
                    body: try TokenUsageSanitizer.envelopeData(events: [])
                )
            } catch {
                return httpResponse(status: 500, body: errorBody("store_clear_failed"))
            }
        default:
            return httpResponse(status: 404, body: errorBody("not_found"))
        }
    }

    private func httpResponse(status: Int, body: Data) -> Data {
        let reason = reasonPhrase(for: status)
        let headers = [
            "HTTP/1.1 \(status) \(reason)",
            "Content-Type: application/json; charset=utf-8",
            "Content-Length: \(body.count)",
            "Cache-Control: no-store",
            "Access-Control-Allow-Origin: *",
            "Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS",
            "Access-Control-Allow-Headers: Content-Type",
            "Connection: close",
            "",
            ""
        ].joined(separator: "\r\n")

        var data = Data(headers.utf8)
        data.append(body)
        return data
    }

    private func errorBody(_ code: String) -> Data {
        Data(#"{"error":"\#(code)"}"#.utf8)
    }

    private func reasonPhrase(for status: Int) -> String {
        switch status {
        case 200:
            return "OK"
        case 201:
            return "Created"
        case 204:
            return "No Content"
        case 400:
            return "Bad Request"
        case 404:
            return "Not Found"
        case 500:
            return "Internal Server Error"
        default:
            return "OK"
        }
    }

    private func currentPOSIXError() -> POSIXError {
        POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
}

struct TokenUsageBridgeRequest: Equatable {
    let method: String
    let path: String
    let body: Data

    init?(data: Data) {
        guard let headerEnd = data.range(of: Data("\r\n\r\n".utf8)),
              let headerText = String(data: data[..<headerEnd.lowerBound], encoding: .utf8)
        else {
            return nil
        }

        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            return nil
        }

        let parts = requestLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard parts.count >= 2 else {
            return nil
        }

        method = parts[0].uppercased()
        path = parts[1].components(separatedBy: "?").first ?? parts[1]
        body = data[headerEnd.upperBound...]
    }
}
