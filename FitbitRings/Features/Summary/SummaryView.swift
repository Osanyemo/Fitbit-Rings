import SwiftUI

struct SummaryView: View {
    @Bindable var viewModel: SummaryViewModel
    let accountEmail: String?
    let onSignOut: () -> Void
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    ActivityRingsView(rings: viewModel.snapshot.rings)
                    RingGoalProgress(rings: viewModel.snapshot.rings)

                    ActivitySummarySection(
                        summary: viewModel.snapshot.activity,
                        units: viewModel.preferences.units
                    )
                    LatestWorkoutCard(
                        workout: viewModel.snapshot.latestWorkout,
                        units: viewModel.preferences.units
                    )
                    HeartSummarySection(summary: viewModel.snapshot.heart)
                    SleepSummarySection(summary: viewModel.snapshot.sleep)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .background(.fitbitBackground)
            .refreshable {
                await viewModel.refresh()
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(
                    viewModel: viewModel,
                    accountEmail: accountEmail,
                    onSignOut: onSignOut
                )
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Date.now.formatted(date: .complete, time: .omitted))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text(DashboardFormatting.relativeUpdate(viewModel.snapshot.lastUpdated))
                if viewModel.snapshot.syncState == .refreshing {
                    ProgressView()
                        .scaleEffect(0.75)
                }
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(viewModel.snapshot.syncState == .failed ? .red : .secondary)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
}
