import Foundation
import Network
import Combine

// MARK: - Discovered Host Model

public struct DiscoveredHost: Identifiable, Hashable {
    public var id: String // Unique Host UUID
    public var name: String
    public var endpoint: NWEndpoint
    public var ip: String
    public var port: UInt16
    public var certFingerprint: String
    public var isOnline: Bool = true
    public var lastDiscovered: Date = Date()
}

// MARK: - mDNS Discovery via NWBrowser

public final class MdnsDiscovery: ObservableObject {
    public static let shared = MdnsDiscovery()

    @Published public private(set) var discoveredHosts: [DiscoveredHost] = []
    @Published public private(set) var isScanning: Bool = false

    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "com.airpulse.mdns", qos: .userInitiated)

    private init() {}

    public func startScanning() {
        guard browser == nil else { return }

        let descriptor = NWBrowser.Descriptor.bonjour(type: "_airpulse._tcp", domain: "local.")
        let params = NWParameters()
        params.includePeerToPeer = true

        let b = NWBrowser(for: descriptor, using: params)
        self.browser = b

        b.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isScanning = true
                case .failed(let err):
                    print("mDNS Browser failed: \(err)")
                    self?.isScanning = false
                case .cancelled:
                    self?.isScanning = false
                default:
                    break
                }
            }
        }

        b.browseResultsChangedHandler = { [weak self] results, changes in
            self?.handleBrowseResults(results)
        }

        b.start(queue: queue)
    }

    public func stopScanning() {
        browser?.cancel()
        browser = nil
        DispatchQueue.main.async {
            self.isScanning = false
        }
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        var hosts: [DiscoveredHost] = []

        for result in results {
            var hostName = ""
            var hostId = ""
            var port: UInt16 = 7001
            var fp = ""

            switch result.endpoint {
            case .service(let name, _, _, _):
                hostName = name
            default:
                break
            }

            if case let .bonjour(txt) = result.metadata {
                for (k, v) in txt.dictionary {
                    switch k {
                    case "id": hostId = v
                    case "name": if let decoded = v.removingPercentEncoding { hostName = decoded }
                    case "port": if let p = UInt16(v) { port = p }
                    case "fp": fp = v
                    default: break
                    }
                }
            }

            if hostId.isEmpty {
                hostId = hostName
            }

            // Estimate IP from endpoint or local network resolution
            let ipAddress = extractIpFromEndpoint(result.endpoint)

            let h = DiscoveredHost(
                id: hostId,
                name: hostName.isEmpty ? "PC" : hostName,
                endpoint: result.endpoint,
                ip: ipAddress,
                port: port,
                certFingerprint: fp,
                isOnline: true,
                lastDiscovered: Date()
            )
            hosts.append(h)
        }

        DispatchQueue.main.async {
            self.discoveredHosts = hosts
        }
    }

    private func extractIpFromEndpoint(_ ep: NWEndpoint) -> String {
        switch ep {
        case .hostPort(let host, _):
            switch host {
            case .ipv4(let ipv4):
                return "\(ipv4)"
            case .name(let name, _):
                return name
            default:
                return "192.168.1.x"
            }
        case .service(let name, _, _, _):
            return name
        default:
            return ""
        }
    }
}
