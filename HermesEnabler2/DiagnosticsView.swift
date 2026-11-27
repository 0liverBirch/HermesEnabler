import SwiftUI

// Diagnostic view, added on the 0liverBirch fork (27 Nov 2026).
// The Class-2 parent fallback exists in BQCore but was never wired to any
// UI, and bqtool.log had no way to be seen on the Watch. This view wires
// both up so a failed MobileGestalt access can be diagnosed on-device:
// it shows the app group the running build actually sees, lets the
// Class-2 fallback be turned on, and shows the log.
struct DiagnosticsView: View {

    @State private var groupID = "(none)"
    @State private var groupRoot = "(none)"
    @State private var logPath = ""
    @State private var logText = "No log yet. Try enabling a face first, then come back here and tap Refresh log."
    @State private var sendStatus = ""

    var body: some View {
        List {
            Section("App Group") {
                Text("Group: \(groupID)")
                    .font(.footnote)
                Text("Root: \(groupRoot)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Class-2 Fallback") {
                Toggle(isOn: Binding(
                    get: { BQClass2ParentEnabled() },
                    set: { BQSetClass2ParentEnabled($0) }
                )) {
                    Text("Class-2 fallback (experimental)")
                }
                Text("Off by default. Moving the app's Library can be killed by the sandbox on some builds. Enable it, then retry enabling a face.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("App Log") {
                Button("Refresh log") {
                    refresh()
                }
                Button("Send log to iPhone") {
                    if WatchConnectivityManager.shared.transferDiagnosticLog() {
                        sendStatus = "Log sent — open HermesEnabler on your iPhone to read it."
                    } else {
                        sendStatus = "Could not send — no log yet, or the Watch session is not active."
                    }
                }
                if !sendStatus.isEmpty {
                    Text(sendStatus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Text(logText)
                    .font(.system(.caption, design: .monospaced))
            }
        }
        .navigationTitle("Diagnostics")
        .onAppear {
            refresh()
        }
    }

    private func refresh() {
        let gid: String? = BQGroupID()
        groupID = gid ?? "(none)"
        let root: String? = BQGroupRoot()
        groupRoot = root ?? "(none)"
        let path: String? = BQLogPath()
        logPath = path ?? ""
        guard let path, let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            logText = "No log yet. Try enabling a face first, then come back here and tap Refresh log."
            return
        }
        // Keep only the tail: the most recent attempt is what matters.
        logText = text.count > 4000 ? String(text.suffix(4000)) : text
    }
}
