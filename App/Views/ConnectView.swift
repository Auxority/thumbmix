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
                        // The decimal pad offers the region's separator: a comma in the Netherlands.
                        // An IP address never holds one, so a comma is always a dot the user meant.
                        .onChange(of: address) { _, typed in
                            let dotted = typed.replacingOccurrences(of: ",", with: ".")
                            if dotted != typed { address = dotted }
                        }
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.title3.monospacedDigit())
                        .padding(12)
                        .background(Theme.track, in: RoundedRectangle(cornerRadius: 10))
                    Button("Connect") { model.connect(to: trimmedAddress) }
                        .buttonStyle(.borderedProminent)
                        // The white app tint makes the enabled fill white and the disabled fill dark grey,
                        // so the label colour has to follow the state or it vanishes into the fill.
                        .foregroundStyle(canConnect ? Color.black : Theme.secondaryText)
                        .disabled(!canConnect)
                }
            }
            Button {
                Task { await scan() }
            } label: {
                Label(
                    isScanning ? "Scanning…" : "Scan this network",
                    systemImage: "dot.radiowaves.left.and.right")
            }
            .disabled(isScanning)
            offlineButton
            ForEach(found) { console in
                Button {
                    model.connect(to: console.host)
                } label: {
                    ConsoleRow(console: console)
                }
                .buttonStyle(.plain)
                .disabled(!console.model.hasPrefix("M32"))
            }
            if hasScanned, !isScanning, !hasWiFiAddress {
                Text("This phone has no Wi-Fi address. Join the console's Wi-Fi network, then scan again.")
                    .font(.callout)
                    .foregroundStyle(Theme.secondaryText)
            } else if hasScanned, !isScanning, found.isEmpty {
                Text(
                    "No console answered. Check that the phone is on the console's Wi-Fi, and Settings → Privacy & Security → Local Network → Thumbmix."
                )
                .font(.callout)
                .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
        }
        .padding(16)
        .onAppear { address = model.lastHost ?? "" }
    }

    @ViewBuilder private var offlineButton: some View {
        Button {
            Task { await model.startOffline() }
        } label: {
            Label("Try offline (demo console)", systemImage: "slider.horizontal.3")
        }
        if model.offlineFailed {
            Text("The demo console couldn't start. Try again, or restart Thumbmix.")
                .font(.callout)
                .foregroundStyle(.yellow)
        }
    }

    private var trimmedAddress: String { address.trimmingCharacters(in: .whitespaces) }
    private var canConnect: Bool { Discovery.isUsableIPv4(trimmedAddress) }

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
            return String(
                localized:
                    "No reply from \(host). Check that the phone is on the console's Wi-Fi, and Settings → Privacy & Security → Local Network → Thumbmix."
            )
        case .notAnM32(let consoleModel):
            return String(
                localized: "\(host) is a \(consoleModel). Thumbmix supports the Midas M32 only.")
        }
    }
}

private struct ConsoleRow: View {
    let console: DiscoveredConsole

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(console.name).font(.headline)
                Text("\(console.model) · \(console.host)").font(.caption).foregroundStyle(
                    Theme.secondaryText)
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
