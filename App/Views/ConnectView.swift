import SwiftUI
import ThumbmixCore

struct ConnectView: View {
    let model: AppModel
    @State private var address = ""
    @State private var found: [DiscoveredConsole] = []
    @State private var isScanning = false
    @State private var hasScanned = false
    @State private var hasWiFiAddress = true

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Thumbmix").font(.largeTitle.bold())
            if let failure = model.failure {
                Label(message(for: failure), systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.yellow)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Console IP").font(.subheadline).foregroundStyle(Theme.secondaryText)
                HStack(spacing: 10) {
                    TextField("192.168.1.50", text: $address)
                        .accessibilityIdentifier("console-ip")
                        .keyboardType(.decimalPad)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.title3.monospacedDigit())
                        .padding(12)
                        .background(Theme.track, in: RoundedRectangle(cornerRadius: 10))
                    Button("Connect") { model.connect(to: trimmedAddress) }
                        .buttonStyle(.borderedProminent)
                        .disabled(!Discovery.isUsableIPv4(trimmedAddress))
                }
            }
            Button {
                Task { await scan() }
            } label: {
                Label(isScanning ? "Scanning…" : "Scan this network", systemImage: "dot.radiowaves.left.and.right")
            }
            .disabled(isScanning)
            ForEach(found) { console in
                Button { model.connect(to: console.host) } label: { ConsoleRow(console: console) }
                    .buttonStyle(.plain)
                    .disabled(!console.model.hasPrefix("M32"))
            }
            if hasScanned, !isScanning, !hasWiFiAddress {
                Text("This phone has no Wi-Fi address. Join the console's Wi-Fi network, then scan again.")
                    .font(.callout)
                    .foregroundStyle(Theme.secondaryText)
            } else if hasScanned, !isScanning, found.isEmpty {
                Text("No console answered. Check that the phone is on the console's Wi-Fi, and Settings → Privacy & Security → Local Network → Thumbmix.")
                    .font(.callout)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
        }
        .padding(16)
        .onAppear { address = model.lastHost ?? "" }
    }

    private var trimmedAddress: String { address.trimmingCharacters(in: .whitespaces) }

    private func scan() async {
        isScanning = true
        defer {
            isScanning = false
            hasScanned = true
        }
        let me = Discovery.localIPv4()
        hasWiFiAddress = me != nil
        guard let me else { return }
        found = await Discovery.scan(hosts: Discovery.sweepHosts(around: me))
    }

    /// iOS reports a denied Local Network permission as plain silence, so "no reply" names both causes.
    private func message(for failure: LinkFailure) -> String {
        let host = model.host ?? String(localized: "the console")
        switch failure {
        case .noReply:
            return String(localized: "No reply from \(host). Check that the phone is on the console's Wi-Fi, and Settings → Privacy & Security → Local Network → Thumbmix.")
        case let .notAnM32(consoleModel):
            return String(localized: "\(host) is a \(consoleModel). Thumbmix supports the Midas M32 only.")
        }
    }
}

private struct ConsoleRow: View {
    let console: DiscoveredConsole

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(console.name).font(.headline)
                Text("\(console.model) · \(console.host)").font(.caption).foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.secondaryText)
        }
        .padding(14)
        .background(Theme.track, in: RoundedRectangle(cornerRadius: 12))
    }
}

#if DEBUG
#Preview {
    ConnectView(model: AppModel()).background(Theme.background)
}
#endif
