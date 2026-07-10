import SwiftUI

struct TrainerRootView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("TrainerApp")
                    .font(.largeTitle.bold())

                Text("The user-facing workout app starts after the PoseBakeoff harness proves the pose engine.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Trainer")
        }
    }
}
