import SwiftUI

/// A tab's last row: resetting rewrites a whole section on the desk at once, so it asks first.
struct ResetButton: View {
    let title: LocalizedStringKey
    let alertTitle: Text
    var message: String?
    let action: () -> Void
    @State private var isConfirming = false

    var body: some View {
        Button(title, role: .destructive) { isConfirming = true }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Theme.track, in: RoundedRectangle(cornerRadius: 10))
            .alert(alertTitle, isPresented: $isConfirming) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive, action: action)
            } message: {
                if let message { Text(verbatim: message) }
            }
    }
}
