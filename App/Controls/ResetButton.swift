import SwiftUI

/// A tab's last row: resetting rewrites a whole section on the desk at once, so it asks first. It waits disabled
/// until the desk sent every value it writes (`ConsoleMirror.isReadForReset`): an earlier tap would reset only part.
struct ResetButton: View {
    let title: LocalizedStringKey
    let alertTitle: Text
    var message: String?
    let isRead: Bool
    let action: () -> Void
    @State private var isConfirming = false

    var body: some View {
        Button(title, role: .destructive) { isConfirming = true }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Theme.track, in: RoundedRectangle(cornerRadius: 10))
            .dimmedUntilRead(isRead)
            .alert(alertTitle, isPresented: $isConfirming) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive, action: action)
            } message: {
                if let message { Text(verbatim: message) }
            }
    }
}
