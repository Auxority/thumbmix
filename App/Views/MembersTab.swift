import SwiftUI
import ThumbmixCore

struct MembersTab: View {
    let dca: Int
    let mirror: ConsoleMirror

    var body: some View {
        let members = mirror.dcaMembers(dca)
        ScrollView {
            VStack(spacing: 6) {
                if members.isEmpty {
                    Text("No channels assigned to this DCA.")
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.top, 20)
                }
                ForEach(members) { strip in
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 3).fill(Theme.color(mirror.color(strip))).frame(
                            width: 6, height: 28)
                        Text(mirror.name(strip)).font(.headline)
                        Spacer()
                        Text(strip.defaultName).font(.caption).foregroundStyle(Theme.secondaryText)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(Theme.track, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("member-" + strip.id)
                }
            }
        }
    }
}

#if DEBUG
    #Preview {
        MembersTab(dca: 1, mirror: .preview()).padding().background(Theme.background)
    }
#endif
