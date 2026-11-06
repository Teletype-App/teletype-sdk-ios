import Foundation

/// Backend endpoints for the two Teletype clusters. Mirrors the web widget's
/// `.env.dev` / `.env.prod` so the same accounts work.
public struct TeletypeEnvironment: Equatable, Sendable {
    /// Cluster label reported by the backend (`dev` or `stable`).
    public var mode: String
    /// Widget protocol version reported to the backend.
    public var version: String
    /// REST API base url (trailing slash).
    public var apiUrl: String
    /// socket.io endpoint.
    public var wsUrl: String
    /// Static assets base url.
    public var assetsUrl: String
    /// API version segment used in REST routes.
    public var apiVersion: String
    /// Marketing/landing url.
    public var landingUrl: String

    public init(
        mode: String,
        version: String,
        apiUrl: String,
        wsUrl: String,
        assetsUrl: String,
        apiVersion: String,
        landingUrl: String
    ) {
        self.mode = mode
        self.version = version
        self.apiUrl = apiUrl
        self.wsUrl = wsUrl
        self.assetsUrl = assetsUrl
        self.apiVersion = apiVersion
        self.landingUrl = landingUrl
    }
}

/// Public switch chosen by the integrator.
public enum TeletypeMode: String, Sendable {
    case dev
    case prod
}

/// Development cluster (`teletypeapp.com`). Matches `widget/.env.dev`.
public let DEV_ENVIRONMENT = TeletypeEnvironment(
    mode: "dev",
    version: "4.0.0",
    apiUrl: "https://api.teletypeapp.com/",
    wsUrl: "https://websocket-widget.teletypeapp.com",
    assetsUrl: "https://widget.teletypeapp.com/",
    apiVersion: "1",
    landingUrl: "https://teletype.app"
)

/// Production / stable cluster (`teletype.app`). Matches `widget/.env.prod`.
public let PROD_ENVIRONMENT = TeletypeEnvironment(
    mode: "stable",
    version: "5.0.0",
    apiUrl: "https://api.teletype.app/",
    wsUrl: "https://websocket-widget.teletype.app/",
    assetsUrl: "https://widget.teletype.app/",
    apiVersion: "1",
    landingUrl: "https://teletype.app"
)

public let DEFAULT_MODE: TeletypeMode = .prod
public let DEFAULT_ENVIRONMENT = PROD_ENVIRONMENT

public func getEnvironment(_ mode: TeletypeMode = DEFAULT_MODE) -> TeletypeEnvironment {
    mode == .dev ? DEV_ENVIRONMENT : PROD_ENVIRONMENT
}

extension TeletypeEnvironment {
    public func merging(_ overrides: TeletypeEnvironmentOverrides?) -> TeletypeEnvironment {
        guard let overrides else { return self }
        var copy = self
        if let mode = overrides.mode { copy.mode = mode }
        if let version = overrides.version { copy.version = version }
        if let apiUrl = overrides.apiUrl { copy.apiUrl = apiUrl }
        if let wsUrl = overrides.wsUrl { copy.wsUrl = wsUrl }
        if let assetsUrl = overrides.assetsUrl { copy.assetsUrl = assetsUrl }
        if let apiVersion = overrides.apiVersion { copy.apiVersion = apiVersion }
        if let landingUrl = overrides.landingUrl { copy.landingUrl = landingUrl }
        return copy
    }
}

/// Fine-grained endpoint overrides applied on top of a cluster preset.
public struct TeletypeEnvironmentOverrides: Sendable {
    public var mode: String?
    public var version: String?
    public var apiUrl: String?
    public var wsUrl: String?
    public var assetsUrl: String?
    public var apiVersion: String?
    public var landingUrl: String?

    public init(
        mode: String? = nil,
        version: String? = nil,
        apiUrl: String? = nil,
        wsUrl: String? = nil,
        assetsUrl: String? = nil,
        apiVersion: String? = nil,
        landingUrl: String? = nil
    ) {
        self.mode = mode
        self.version = version
        self.apiUrl = apiUrl
        self.wsUrl = wsUrl
        self.assetsUrl = assetsUrl
        self.apiVersion = apiVersion
        self.landingUrl = landingUrl
    }
}
