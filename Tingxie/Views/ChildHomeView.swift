import SwiftUI

struct ChildHomeView: View {
    let onParent: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("听写")
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                Spacer()
                LongPressGate(action: onParent)
            }
            VStack(spacing: 8) {
                Text("No sheets yet.")
                    .font(.system(.title, design: .rounded))
                Text("Ask a grown-up to add this week's list.")
                    .font(.title3)
                    .foregroundStyle(Theme.muted)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .screen()
    }
}

#Preview {
    ChildHomeView {}
}
