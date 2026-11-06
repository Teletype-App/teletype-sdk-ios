import Foundation

public typealias UploadProgressHandler = (Int) -> Void

/// Thin REST client for the Teletype widget HTTP API.
public final class ApiClient {
    private let env: TeletypeEnvironment
    private let externalId: String
    private let session: URLSession

    public init(env: TeletypeEnvironment, externalId: String, session: URLSession = .shared) {
        self.env = env
        self.externalId = externalId
        self.session = session
    }

    private func base(_ path: String) -> URL {
        URL(string: env.apiUrl + path)!
    }

    private func v(_ path: String) -> URL {
        base("api/v\(env.apiVersion)/\(path)")
    }

    private func getJSON(_ url: URL) async throws -> Any {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw TeletypeError.uploadFailed
        }
        let raw = try JSONSerialization.jsonObject(with: data)
        return camelKeys(raw) as Any
    }

    private func postForm(_ url: URL, payload: [String: Any]) async throws -> Any {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = serialize(payload).data(using: .utf8)
        let (data, _) = try await session.data(for: request)
        let raw = try JSONSerialization.jsonObject(with: data)
        return camelKeys(raw) as Any
    }

    public func getIp() async throws -> String {
        let json = try await getJSON(v("widget/ip"))
        if let dict = json as? [String: Any] {
            return stringVal(dict["data"]) ?? ""
        }
        return ""
    }

    public func getConfig() async throws -> Any {
        try await getJSON(v("widget/\(externalId)/config"))
    }

    public func getHistory(appealId: String) async throws -> Any {
        let dt = "2018-02-12T17:08:55+0000".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return try await getJSON(v("history/\(externalId)/\(appealId)/messages?datetime=\(dt)"))
    }

    public func uploadFile(_ file: LocalFile, onProgress: UploadProgressHandler? = nil) async throws -> UploadFileResponse {
        let url = v("widget-attachment/\(externalId)")
        let fileURL = URL(fileURLWithPath: file.uri.replacingOccurrences(of: "file://", with: ""))
        let resolved = file.uri.hasPrefix("file://") ? URL(string: file.uri) ?? fileURL : fileURL

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let filename = file.name.isEmpty ? "file" : file.name
        let mime = file.type.isEmpty ? "application/octet-stream" : file.type
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
        let fileData = try Data(contentsOf: resolved)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"externalId\"\r\n\r\n".data(using: .utf8)!)
        body.append(externalId.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        onProgress?(0)
        let (data, response) = try await session.data(for: request)
        onProgress?(100)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let snippet = String(data: data, encoding: .utf8) ?? ""
            throw NSError(
                domain: "TeletypeSDK",
                code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                userInfo: [NSLocalizedDescriptionKey: "uploadFailed: \(snippet.prefix(200))"]
            )
        }
        let raw = try JSONSerialization.jsonObject(with: data)
        let camel = camelKeys(raw) as Any
        if let decoded = decodeJSON(camel, as: UploadFileResponse.self) {
            return decoded
        }
        throw TeletypeError.uploadFailed
    }

    public func reportError(_ data: [String: Any]) async throws {
        _ = try await postForm(base("api/v\(env.apiVersion)/widget/error"), payload: snakeKeys(data) as? [String: Any] ?? data)
    }

    public func notifyLocationChange(_ location: String) async throws {
        _ = try await postForm(
            v("widget/\(externalId)/url"),
            payload: snakeKeys(["clientUrl": location]) as? [String: Any] ?? [:]
        )
    }

    public func collect(_ data: [String: Any]) async throws {
        _ = try await postForm(
            base("api/v\(env.apiVersion)/collect"),
            payload: snakeKeys(data) as? [String: Any] ?? data
        )
    }
}

public enum TeletypeError: String, Error, LocalizedError {
    case fileSizeError
    case fileFormatNotAllowed
    case uploadFailed
    case channel
    case socketTimeout
    case notReady

    public var errorDescription: String? { rawValue }
}
