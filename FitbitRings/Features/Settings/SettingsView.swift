import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: FitnessDashboardStore
    let accountEmail: String?
    let onSignOut: () -> Void

    @State private var moveGoal: Int
    @State private var activeGoal: Int
    @State private var stepGoal: Int
    @State private var distanceUnit: DistanceUnit
    @State private var appearance: AppearancePreference
    @State private var isConfirmingDisconnect = false

    init(store: FitnessDashboardStore, accountEmail: String?, onSignOut: @escaping () -> Void) {
        self.store = store
        self.accountEmail = accountEmail
        self.onSignOut = onSignOut
        _moveGoal = State(initialValue: store.preferences.goals.moveCalories)
        _activeGoal = State(initialValue: store.preferences.goals.activeMinutes)
        _stepGoal = State(initialValue: store.preferences.goals.steps)
        _distanceUnit = State(initialValue: store.preferences.units.distanceUnit)
        _appearance = State(initialValue: store.preferences.units.appearance)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Goals") {
                    Stepper(value: $stepGoal, in: 1_000...50_000, step: 500) {
                        SettingsValueRow(title: "Steps", value: DashboardFormatting.integer(Double(stepGoal)))
                    }
                    .accessibilityLabel("Step goal")
                    .accessibilityValue("\(stepGoal) steps")
                    Stepper(value: $activeGoal, in: 5...240, step: 5) {
                        SettingsValueRow(title: "Active", value: "\(activeGoal) min")
                    }
                    .accessibilityLabel("Active minute goal")
                    .accessibilityValue("\(activeGoal) minutes")
                    Stepper(value: $moveGoal, in: 50...2_000, step: 25) {
                        SettingsValueRow(title: "Move", value: "\(moveGoal) kcal")
                    }
                    .accessibilityLabel("Move goal")
                    .accessibilityValue("\(moveGoal) kilocalories")
                }

                Section("Units") {
                    Picker("Distance", selection: $distanceUnit) {
                        Text("Kilometers").tag(DistanceUnit.kilometers)
                        Text("Miles").tag(DistanceUnit.miles)
                    }
                }

                Section("Appearance") {
                    Picker("Mode", selection: $appearance) {
                        Text("System").tag(AppearancePreference.system)
                        Text("Light").tag(AppearancePreference.light)
                        Text("Dark").tag(AppearancePreference.dark)
                    }
                }

                Section("Google Health") {
                    SettingsValueRow(title: "Account", value: accountEmail ?? "Connected")
                    Button(role: .destructive) {
                        isConfirmingDisconnect = true
                    } label: {
                        Label("Disconnect Google Health", systemImage: "person.crop.circle.badge.xmark")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        store.saveGoals(
                            moveCalories: moveGoal,
                            activeMinutes: activeGoal,
                            steps: stepGoal
                        )
                        store.saveUnits(distanceUnit)
                        store.saveAppearance(appearance)
                        dismiss()
                    }
                }
            }
            .alert("Disconnect Google Health?", isPresented: $isConfirmingDisconnect) {
                Button("Cancel", role: .cancel) {}
                Button("Disconnect", role: .destructive) {
                    onSignOut()
                    dismiss()
                }
            } message: {
                Text("This signs you out and removes cached health data from this iPhone. You can reconnect later.")
            }
        }
    }
}

private struct SettingsValueRow: View {
    let title: String
    let value: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                Spacer(minLength: 12)
                valueText
                    .multilineTextAlignment(.trailing)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                valueText
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var valueText: some View {
        Text(value)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }
}
