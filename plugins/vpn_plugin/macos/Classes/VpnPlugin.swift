import Cocoa
import FlutterMacOS
import TrustTunnelClient
import VpnClientFramework

public class VpnPlugin: NSObject, FlutterPlugin {
    private static var vpnApi: IVpnManagerImpl?
    private static var deepLink: IDeepLink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger

        let vpnImpl = IVpnManagerImpl(
            bundleIdentifier: "com.adguard.TrustTunnel.Extension",
            appGroup: "group.com.adguard.TrustTunnel"
        )
        IVpnManagerSetup.setUp(binaryMessenger: messenger, api: vpnImpl)

        let deepLinkImpl = IDeepLinkImpl()
        IDeepLinkSetup.setUp(binaryMessenger: messenger, api: deepLinkImpl)

        let events = FlutterEventChannel(
            name: "vpn_plugin_event_channel",
            binaryMessenger: messenger
        )
        events.setStreamHandler(vpnImpl)

        let queryLogEvents = FlutterEventChannel(
            name: "vpn_plugin_event_channel_query_log",
            binaryMessenger: messenger
        )
        queryLogEvents.setStreamHandler(vpnImpl.queryLogHandler)

        self.vpnApi = vpnImpl
        self.deepLink = deepLinkImpl
    }
}

final class IVpnManagerImpl: NSObject, IVpnManager, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private var vpnManager: VpnManager?
    var queryLogHandler = QueryLogStreamHandler()

    init(bundleIdentifier: String, appGroup: String) {
        super.init()
        self.vpnManager = VpnManager(
            bundleIdentifier: bundleIdentifier,
            appGroup: appGroup,
            stateChangeCallback: { [weak self] newState in
                self?.state = VpnManagerState(rawValue: newState) ?? .disconnected
            },
            connectionInfoCallback: { [weak self] info in
                DispatchQueue.main.async {
                    self?.queryLogHandler.emitQueryLog(info)
                }
            }
        )
    }

    private var state: VpnManagerState = .disconnected {
        didSet {
            emitState(state)
        }
    }

    func start(config: String) throws {
        vpnManager?.start(config: config)
    }

    func updateConfiguration(config: String?) throws {
        vpnManager?.updateConfiguration(config: config)
    }

    func stop() throws {
        vpnManager?.stop()
    }

    func getCurrentState() throws -> VpnManagerState {
        return state
    }

    func exportLogs() throws -> [String] {
        return vpnManager?.exportLogs() ?? []
    }

    func clearLogs() throws {
        _ = vpnManager?.clearLogs()
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
        -> FlutterError?
    {
        self.eventSink = events
        emitState(state)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    private func emitState(_ state: VpnManagerState) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(state.rawValue)
        }
    }
}

final class QueryLogStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private var queue: [String] = []

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
        -> FlutterError?
    {
        self.eventSink = events
        for log in queue {
            self.eventSink?(log)
        }
        queue = []
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    func emitQueryLog(_ value: String) {
        if eventSink == nil {
            queue.append(value)
        } else {
            eventSink?(value)
        }
    }
}

final class IDeepLinkImpl: NSObject, IDeepLink {
    func decode(uri: String) throws -> String {
        return try TrustTunnelDeepLink.decodeDeeplink(_: uri)
    }
}
