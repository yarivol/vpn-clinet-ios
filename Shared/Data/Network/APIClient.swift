//
//  APIClient.swift
//  pantherapp
//
//  Talks to the same BotVPN FastAPI backend the Android app and the web cabinet
//  use, via the nginx /mobile-api/cabinet/ passthrough — mirrors Android's
//  data/remote/PantherApi.kt + NetworkModule.kt (same 8 endpoints, same Bearer
//  auth pattern: the token is read fresh from tokenProvider on every request,
//  not cached at client-construction time, so login/logout takes effect
//  immediately without recreating this client).
//

import Foundation

enum APIError: Error {
    case invalidResponse
    case httpError(status: Int, body: String?)
}

final class APIClient {
    static let shared = APIClient()

    /// Set once at app startup (from the auth layer) so every request can read
    /// the current access token without APIClient depending on TokenStore directly.
    var tokenProvider: (() -> String?)?

    private let baseURL: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        baseURL: URL = URL(string: "https://panthervpn.store/mobile-api/cabinet/")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    // MARK: - Auth

    func exchangeMagicLink(token: String) async throws -> AuthSessionResponse {
        try await post("auth/magic-link", body: MagicLinkRequest(token: token))
    }

    func exchangeSubscriptionLink(link: String) async throws -> AuthSessionResponse {
        try await post("auth/subscription-link", body: SubscriptionLinkRequest(link: link))
    }

    // MARK: - Cabinet

    func getCabinetMe() async throws -> CabinetMeResponse {
        try await get("me")
    }

    func getTrafficHistory() async throws -> TrafficHistoryResponse {
        try await get("traffic/history")
    }

    /// Raw Xray-core JSON (array of per-server configs) — no typed model, the
    /// caller (CabinetRepository.parseServersFromConfig) walks the raw JSON
    /// directly, same as Android does, since re-modeling it into Swift types
    /// and back would be pure waste (it's handed to the VPN engine almost
    /// verbatim). `hwid` registers/identifies this device with Remnawave so it
    /// renders real servers instead of the "device not supported" placeholder.
    func getVpnConfig(
        hwid: String? = nil,
        platform: String? = nil,
        osVersion: String? = nil,
        deviceModel: String? = nil,
        userAgent: String? = nil
    ) async throws -> Data {
        let query = [
            "hwid": hwid,
            "platform": platform,
            "os_version": osVersion,
            "device_model": deviceModel,
            "user_agent": userAgent,
        ]
        return try await getRaw("vpn-config", query: query)
    }

    func getDevices() async throws -> DevicesResponse {
        try await get("devices")
    }

    func removeDevice(hwid: String) async throws {
        _ = try await postRaw("devices/remove", body: DeviceRemoveRequest(hwid: hwid))
    }

    // MARK: - Request plumbing

    private func get<T: Decodable>(_ path: String, query: [String: String?] = [:]) async throws -> T {
        let data = try await getRaw(path, query: query)
        return try decoder.decode(T.self, from: data)
    }

    private func getRaw(_ path: String, query: [String: String?] = [:]) async throws -> Data {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        let items = query.compactMap { key, value -> URLQueryItem? in
            guard let value else { return nil }
            return URLQueryItem(name: key, value: value)
        }
        if !items.isEmpty { components.queryItems = items }

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        applyAuthHeader(&request)
        return try await execute(request)
    }

    private func post<Body: Encodable, T: Decodable>(_ path: String, body: Body) async throws -> T {
        let data = try await postRaw(path, body: body)
        return try decoder.decode(T.self, from: data)
    }

    /// Like `post`, but doesn't try to decode the response — for endpoints
    /// (e.g. devices/remove) whose response body isn't a typed model we need.
    private func postRaw<Body: Encodable>(_ path: String, body: Body) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        applyAuthHeader(&request)
        return try await execute(request)
    }

    private func applyAuthHeader(_ request: inout URLRequest) {
        if let token = tokenProvider?() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func execute(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.httpError(status: http.statusCode, body: String(data: data, encoding: .utf8))
        }
        return data
    }
}
