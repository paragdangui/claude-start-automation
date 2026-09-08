import SwiftUI
struct SettingsView: View {
    @EnvironmentObject var model: SchedulerModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Settings").font(.title.bold())
            Text("Use existing CLI installations and logins. Path changes are saved with Apply schedule for that provider. Run now uses the path currently shown here.")
            ForEach(Provider.allCases) { provider in
                VStack(alignment: .leading) {
                    Text("\(provider.title) executable").font(.headline)
                    HStack {
                        TextField("Absolute executable path", text: Binding(get: { model.drafts[provider.rawValue]!.executable }, set: { model.drafts[provider.rawValue]?.executable = $0 }))
                        Button("Choose…") { model.chooseExecutable(provider) }
                    }
                }
            }
            Text("Settings, runners, status and logs: \(model.manager.store.root.path)").font(.caption).textSelection(.enabled)
            Text("Moving or deleting the app does not uninstall jobs. Disable both schedules and apply each change before removing the app.").font(.callout)
            HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }
        }.padding(24).frame(width: 600).disabled(!model.busy.isEmpty)
    }
}
