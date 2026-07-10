import SwiftUI

struct TrainerRootView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick Start")
                            .font(.largeTitle.bold())

                        Text("Start a focused back-squat session without a plan or account.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.title2)
                                .frame(width: 36, height: 36)
                                .foregroundStyle(.tint)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Back Squat")
                                    .font(.title3.bold())
                                Text("Barbell · Side view")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Divider()

                        Label("Place your phone on a stable surface", systemImage: "iphone.gen3")
                        Label("You will confirm load before each set", systemImage: "scalemass")
                    }
                    .font(.subheadline)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))

                    NavigationLink {
                        BackSquatQuickSessionView()
                    } label: {
                        HStack {
                            Text("Start Quick Session")
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .accessibilityHidden(true)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Text("Recording will begin only after camera setup and a deliberate Start Set action.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Squat Trainer")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct BackSquatQuickSessionView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Quick Session")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text("Back Squat")
                        .font(.largeTitle.bold())

                    Text("Set 1")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Label("Barbell back squat", systemImage: "figure.strengthtraining.traditional")
                    Label("Side-view capture", systemImage: "camera.viewfinder")
                    Label("Quick-start session", systemImage: "bolt.fill")
                }
                .font(.body.weight(.medium))
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Before your first set")
                        .font(.headline)

                    Text("Set the phone far enough back to keep your full body in frame. You will confirm your weight and camera setup before recording starts.")
                        .foregroundStyle(.secondary)
                }

                Button("End Quick Session", role: .destructive) {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .navigationTitle("Back Squat")
        .navigationBarTitleDisplayMode(.inline)
    }
}
