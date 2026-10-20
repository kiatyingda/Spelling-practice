import SwiftUI

struct ParentHomeView: View {
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Button("← Done", action: onDone)
                    .buttonStyle(.surface)
                Spacer()
                Text("Parent")
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                Spacer()
                // Balances the header; settings arrive in step 2.
                Color.clear.frame(width: Theme.touch, height: Theme.touch)
            }
            Text("Sheets, voices and pace arrive in the next step.")
                .foregroundStyle(Theme.muted)
        }
        .screen()
    }
}

#Preview {
    ParentHomeView {}
}
