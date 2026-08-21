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
                    Stepper(value: $moveGoal, in: 50...2_000, step: 25) {
                        SettingsValueRow(title: "Move", value: "\(moveGoal) kcal")
                    }
                    Stepper(value: $activeGoal, in: 5...240, step: 5) {
                        SettingsValueRow(title: "Active", value: "\(activeGoal) min")
                    }
                    Stepper(value: $stepGoal, in: 1_000...50_000, step: 500) {
                        SettingsValueRow(title: "Steps", value: DashboardFormatting.integer(Double(stepGoal)))
                    }
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
                        onSignOut()
                        dismiss()
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
        }
    }
}

private struct SettingsValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
