import SwiftUI

struct SchedulerView: View {
    @EnvironmentObject var model: SchedulerModel
    @State private var settings = false
    let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                        .resizable().frame(width: 64, height: 64)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading) {
                        Text("Auto Session Start").font(.largeTitle.bold())
                        Text("Weekday greetings · Mac’s local timezone").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Settings…") { settings = true }
                }
                Text("Closing this window or quitting leaves enabled schedules running. The Mac must be powered on; exact execution during sleep is not guaranteed.")
                    .font(.callout).foregroundStyle(.secondary)
                if let error = model.setupError { Text(error).foregroundStyle(.red).textSelection(.enabled) }
                if model.needsSetup {
                    GroupBox("Setup") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Install schedules adopts existing jobs using their current labels. Opening this app does not install jobs or send greetings. Review paths in Settings first.")
                            Button("Install schedules") { Task { await model.install() } }
                                .disabled(!model.busy.isEmpty || model.inspections.isEmpty || model.setupError != nil)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
                    }
                }
                ForEach(Provider.allCases) { provider in ProviderSection(provider: provider) }
                Text("Run now sends a request through the selected service using the executable in Settings. A successful greeting does not verify a usage-window reset.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(24)
        }
        .frame(minWidth: 640, idealWidth: 700, minHeight: 650)
        .sheet(isPresented: $settings) { SettingsView().environmentObject(model) }
        .task { await model.refresh() }
        .onReceive(timer) { _ in Task { await model.refresh() } }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in Task { await model.refresh() } }
    }
}
struct ProviderSection: View {
    @EnvironmentObject var model: SchedulerModel
    let provider: Provider
    var key: String { provider.rawValue }
    var config: Configuration { model.drafts[key]! }
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(provider.title).font(.title2.bold()); Spacer()
                    if model.busy.contains(key) { ProgressView().controlSize(.small); Text("Working…") }
                }
                Text(installedSummary).foregroundStyle(.secondary)
                HStack(spacing: 16) {
                    Toggle("Schedule enabled", isOn: Binding(get: { config.enabled }, set: { model.drafts[key]?.enabled = $0 }))
                    DatePicker("Monday–Friday", selection: Binding(get: {
                        Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: config.hour, minute: config.minute))!
                    }, set: { date in
                        model.drafts[key]?.hour = Calendar.current.component(.hour, from: date)
                        model.drafts[key]?.minute = Calendar.current.component(.minute, from: date)
                    }), displayedComponents: .hourAndMinute)
                }
                if model.inspections[key]?.unsupported == true {
                    Text("The existing job has a schedule or trigger this version cannot represent. Applying will replace it with the weekday time above.").foregroundStyle(.orange)
                    Toggle("Replace existing schedule", isOn: Binding(get: { model.replacement.contains(key) }, set: { if $0 { model.replacement.insert(key) } else { model.replacement.remove(key) } }))
                }
                HStack {
                    Button("Apply schedule") { Task { await model.update(provider) } }.disabled(model.records[key]?.live == true)
                    if config != model.applied[key] { Text("Unapplied changes").font(.caption).foregroundStyle(.orange) }
                    Spacer()
                    Button("Run now") { Task { await model.run(provider) } }.disabled(model.records[key]?.live == true)
                    Button("View logs") { model.logs(provider) }
                }
                Text(model.records[key]?.summary ?? "No runs recorded").font(.callout)
                if let error = model.errors[key] { Text(error).foregroundStyle(.red).textSelection(.enabled).font(.callout) }
            }.padding(8)
        }.disabled(!model.busy.isEmpty || model.inspections.isEmpty || model.setupError != nil)
    }
    var installedSummary: String {
        guard let inspection = model.inspections[key] else { return "Inspecting installed schedule…" }
        if inspection.unsupported { return "Existing custom job · \(inspection.loaded ? "loaded" : "not loaded")" }
        if inspection.loaded, let config = inspection.configuration { return "Scheduled Monday–Friday at \(config.time)\(inspection.managed ? "" : " · awaiting migration")" }
        return inspection.exists ? "Disabled · plist still present; Apply to reconcile" : "Disabled · no installed job"
    }
}
