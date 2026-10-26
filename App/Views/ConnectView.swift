import OSLog
import SwiftUI
import ThumbmixCore

/// Built for one thumb: the console used last is a card just above the buttons, the rarer choices sit higher.
/// A scan runs on every visit and every 5 s while it lasts; a row found later goes below the others, so nothing
/// moves under a thumb.
struct ConnectView: View {
    let model: AppModel
    private static let log = Logger(subsystem: "thumbmix", category: "connect")
    @State private var sightings = ConsoleSightings()
    @State private var isScanning = true
    @State private var hasWiFiAddress = true
    @State private var isTypingAddress = false
    /// The last scan's log line: a repeat is kept in the phone's log only when it differs.
    @State private var lastScanLine = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Thumbmix").font(.largeTitle.bold()).padding([.horizontal, .top], 16)
            ConsoleList(model: model, sightings: sightings, emptyText: emptyText)
            VStack(spacing: 10) {
                if let lastUsed = model.known.lastUsed {
                    LastUsedCard(console: lastUsed, presence: sightings.presence(of: lastUsed)) {
                        model.connect(to: lastUsed.host, name: lastUsed.name)
                    }
                }
                HStack(spacing: 8) {
                    Button(isScanning ? "Scanning…" : "Scan again") { Task { await scan() } }
                        .disabled(isScanning)
                    Button("Enter IP") { isTypingAddress = true }
                        .modifier(EnterAddressAlert(isPresented: $isTypingAddress) { model.connect(to: $0) })
                }
                .buttonStyle(.wideDarkCapsule)
                DemoLink(model: model)
            }
            .padding(.horizontal, 16)
        }
        .modifier(ConnectFailureAlert(model: model))
        .task {
            await scan()
            // A desk still booting when the screen opened would stay Not found until a restart.
            while (try? await Task.sleep(for: .seconds(5))) != nil {
                if !isScanning { await scan(showing: false) }
            }
        }
    }

    /// Shown only while the list would otherwise be empty.
    private var emptyText: LocalizedStringKey? {
        guard model.known.all.isEmpty, sightings.rows(known: model.known).isEmpty else { return nil }
        if isScanning { return "Scanning…" }
        if !hasWiFiAddress { return "No Wi-Fi. Join the desk's Wi-Fi, then scan again." }
        return "No console found. Is this iPhone on the desk's Wi-Fi?"
    }

    /// `showing`: false for the repeated scans, so the button doesn't flicker to "Scanning…" every few seconds.
    private func scan(showing: Bool = true) async {
        if showing { isScanning = true }
        defer { if showing { isScanning = false } }
        let me = Discovery.localIPv4()
        hasWiFiAddress = me != nil
        let hosts = Discovery.scanHosts(around: me, known: model.known.all.map(\.host))
        let found = await Discovery.scan(hosts: hosts, port: AppModel.consolePort)
        sightings.scanned(found, known: model.known)
        let lastUsed = model.known.lastUsed.map { "\($0.id) \(sightings.presence(of: $0))" } ?? "none"
        let line = "from \(me ?? "no Wi-Fi"): found \(found.map(\.id)), last used \(lastUsed)"
        Self.log.log(level: showing || line != lastScanLine ? .default : .info, "scan \(line, privacy: .public)")
        lastScanLine = line
    }
}

private struct ConsoleList: View {
    let model: AppModel
    let sightings: ConsoleSightings
    let emptyText: LocalizedStringKey?

    var body: some View {
        let rows = sightings.rows(known: model.known)
        List {
            if !rows.isEmpty || emptyText != nil {
                Section(model.known.lastUsed == nil ? "Consoles" : "Other consoles") {
                    ForEach(rows) { row($0) }
                    if let emptyText {
                        Text(emptyText).font(.callout).foregroundStyle(Theme.secondaryText)
                            .listRowBackground(Theme.track)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    /// Only a remembered console can be forgotten; one the scan just found isn't kept anyway.
    private func row(_ console: NetworkConsole) -> some View {
        let presence = sightings.presence(of: console)
        let isRemembered = model.known.all.contains(console)
        return Button {
            model.connect(to: console.host, name: console.name)
        } label: {
            ConsoleRow(console: console, presence: presence)
        }
        .disabled(presence == .notAnM32)
        .swipeActions {
            if isRemembered {
                Button("Forget", role: .destructive) { model.forget(console) }
            }
        }
        .listRowBackground(Theme.track)
    }
}

private struct ConsoleRow: View {
    let console: NetworkConsole
    let presence: Presence

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: console.name).font(.headline)
                Text(verbatim: "\(console.model) · \(console.host)").font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            PresenceLabel(presence: presence)
            Image(systemName: "chevron.right").foregroundStyle(Theme.secondaryText)
        }
        .opacity(presence == .notAnM32 ? 0.4 : 1)
    }
}

/// Online only when the console answered this visit's latest scan; before that, no state at all.
private struct PresenceLabel: View {
    let presence: Presence

    var body: some View {
        switch presence {
        case .unknown:
            EmptyView()
        case .online:
            HStack(spacing: 4) {
                Circle().frame(width: 7, height: 7)
                Text("Online")
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.usualOnGreen)
        case .notFound:
            Text("Not found").font(.footnote).foregroundStyle(Theme.secondaryText)
        case .notAnM32:
            Text("Not an M32").font(.footnote).foregroundStyle(Theme.secondaryText)
        }
    }
}

/// No swipe here, so the console used last can't be forgotten by accident; it moves into the list once
/// another console is used.
private struct LastUsedCard: View {
    let console: NetworkConsole
    let presence: Presence
    let connect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Last used").font(.footnote).foregroundStyle(Theme.secondaryText).padding(.leading, 4)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: console.name).font(.title3.bold())
                    Spacer()
                    PresenceLabel(presence: presence)
                }
                Text(verbatim: "\(console.model) · \(console.host)").font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                Button("Connect", action: connect)
                    .buttonStyle(.wideProminentDarkCapsule)
                    .padding(.top, 8)
            }
            .padding(14)
            .background(Theme.track, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

private struct DemoLink: View {
    let model: AppModel

    var body: some View {
        Button("Try a demo console") { Task { await model.startOffline() } }
            .font(.footnote)
            .foregroundStyle(Theme.secondaryText)
            .disabled(model.isStartingOffline)
            .padding(.vertical, 8)
            .alert(
                "The demo didn't start",
                isPresented: Binding(
                    get: { model.offlineFailed }, set: { if !$0 { model.dismissOfflineFailure() } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Try again, or restart Thumbmix.")
            }
    }
}

/// Typing starts from this phone's network, so at a venue only the last number is typed; it can be deleted for
/// a desk on another network. Text that isn't an address reopens the alert with the text kept to fix.
private struct EnterAddressAlert: ViewModifier {
    @Binding var isPresented: Bool
    let connect: (String) -> Void
    @State private var typed = ""
    @State private var refused = false

    func body(content: Content) -> some View {
        content
            .alert(refused ? "Not an IP address" : "Connect to an IP address", isPresented: $isPresented) {
                TextField("192.168.1.62", text: $typed)
                    .keyboardType(.decimalPad)
                    // The decimal pad types the region's separator, a comma in the Netherlands; show the dot it means.
                    .onChange(of: typed) { _, text in
                        if text.contains(",") { typed = text.replacingOccurrences(of: ",", with: ".") }
                    }
                Button("Cancel", role: .cancel) { refused = false }
                // Never .disabled: a disabled state that changes while typing makes Connect lose its action (iOS 27).
                Button("Connect", action: submit)
            } message: {
                Text(refused ? "Like 192.168.1.62" : "The console's IP, shown on the desk under Setup → Network.")
            }
            .onChange(of: isPresented) { _, isOpen in isOpen ? opened() : closed() }
    }

    private func submit() {
        guard let host = Discovery.typedAddress(typed) else {
            refused = true
            return
        }
        refused = false
        connect(host)
    }

    private func opened() {
        if !refused { typed = Discovery.networkPrefix(of: Discovery.localIPv4()) }
    }

    /// Reopening while the alert still animates out is ignored, so it waits for the dismissal to finish.
    private func closed() {
        guard refused else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            isPresented = true
        }
    }
}

/// iOS reports a denied Local Network permission as plain silence, so "no reply" asks about both causes.
private struct ConnectFailureAlert: ViewModifier {
    let model: AppModel
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content.alert(
            title, isPresented: Binding(get: { model.failure != nil }, set: { if !$0 { model.disconnect() } })
        ) {
            if model.failure == .noReply, let settings = URL(string: UIApplication.openSettingsURLString) {
                Button("Settings") { openURL(settings) }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(message)
        }
    }

    private var title: String {
        switch model.failure {
        case .notAnM32(let consoleModel): String(localized: "That's an \(consoleModel)")
        default: String(localized: "Can't reach \(model.target ?? "")")
        }
    }

    private var message: String {
        switch model.failure {
        case .notAnM32: String(localized: "Thumbmix only works with the Midas M32.")
        default: String(localized: "Is this iPhone on the desk's Wi-Fi, with Local Network on for Thumbmix?")
        }
    }
}

#if DEBUG
    #Preview {
        ConnectView(model: AppModel()).background(Theme.background)
    }
#endif
