import Foundation
import Synchronization

/// Fake WhisperX server behind `URLProtocol`. Each test uses its own host, so suites can run in
/// parallel; `respond` gets the method and path (`GET /api/status`) and returns status + body.
final class StubServer: Sendable {
    typealias Handler = @Sendable (_ route: String) -> (Int, String)

    let host = "stub-\(UUID().uuidString.lowercased()).test"
    var baseURL: String { "https://\(host)/api" }
    private let calls = Mutex<[String]>([])

    init(_ respond: @escaping Handler) {
        StubURLProtocol.handlers.withLock { $0[host] = (self, respond) }
    }

    /// Routes received so far, in order.
    var routes: [String] { calls.withLock { $0 } }
    func count(_ route: String) -> Int { routes.filter { $0 == route }.count }

    func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    fileprivate func record(_ route: String) { calls.withLock { $0.append(route) } }
}

final class StubURLProtocol: URLProtocol {
    static let handlers = Mutex<[String: (StubServer, StubServer.Handler)]>([:])

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let host = url.host(),
            let (server, respond) = Self.handlers.withLock({ $0[host] })
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
            return
        }
        let route = "\(request.httpMethod ?? "GET") \(url.path())"
        server.record(route)
        let (status, body) = respond(route)
        if let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// `Clock` whose `sleep` returns at once and moves time forward: delays of minutes cost nothing.
final class InstantClock: Clock, Sendable {
    typealias Instant = ManualClock.Instant
    private let time = Mutex(Instant(offset: .zero))

    var now: Instant { time.withLock { $0 } }
    var minimumResolution: Duration { .zero }
    /// Total time slept so far.
    var elapsed: Duration { now.offset }

    func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        try Task.checkCancellation()
        time.withLock { $0 = max($0, deadline) }
        await Task.yield()
    }
}
