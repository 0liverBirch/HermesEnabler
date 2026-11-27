import SwiftUI
import UniformTypeIdentifiers

// MARK: - Content View

struct ContentView: View {

    @StateObject private var watchManager = WatchConnectivityManager()
    @Environment(\.scenePhase) private var scenePhase

    @State private var showingHistory = false
    @State private var showingImporter = false
    @State private var shareURL: ShareItem?
    @State private var alertMessage = ""
    @State private var showingAlert = false

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(spacing: 22) {

                    WatchDeviceCard(watchManager: watchManager)
                    WatchInstallationCard(watchManager: watchManager)
                    LatestBackupCard(watchManager: watchManager)

                    diagnosticLogSection

                    actionButtons
                }
                .padding()
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("HermesEnabler")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        watchManager.loadBackupHistory()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh")
                }
            }
        }
        .sheet(isPresented: $showingHistory) {
            BackupHistoryView(manager: watchManager)
        }
        .sheet(item: $shareURL) { item in
            ActivityViewController(activityItems: [item.url])
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.propertyList],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert("HermesEnabler", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                watchManager.refreshConnectionStatus()
                watchManager.loadBackupHistory()
            }
        }
    }

    // MARK: - Diagnostic log

    private var diagnosticLogSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Diagnostic Log", systemImage: "info.circle")
                .font(.headline)

            Text(watchManager.diagnosticLogStatus)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let logText = watchManager.diagnosticLogText {
                if let date = watchManager.diagnosticLogDate {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ScrollView {
                    Text(String(logText.suffix(4000)))
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 220)
            } else {
                Text("No log received yet. On the Watch, open Diagnostics and tap “Send log to iPhone”.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button {
                    _ = watchManager.requestDiagnosticLog()
                } label: {
                    Label("Request Log", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.bordered)

                if let url = watchManager.diagnosticLogExportURL() {
                    Button {
                        shareURL = ShareItem(url: url)
                    } label: {
                        Label("Share Log", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Main actions

    private var actionButtons: some View {

        VStack(spacing: 12) {

            Button {
                showingImporter = true
            } label: {
                Label(
                    "Import Backup",
                    systemImage: "square.and.arrow.down"
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)

            Button {
                guard let latest = watchManager.latestBackup else {
                    showMessage(String(localized: "No backup to export."))
                    return
                }

                exportBackup(latest)

            } label: {
                Label(
                    "Export Latest Backup",
                    systemImage: "square.and.arrow.up"
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
            }
            .buttonStyle(.bordered)

            Button {
                watchManager.loadBackupHistory()
                showingHistory = true
            } label: {
                Label(
                    "Backup History",
                    systemImage: "clock.arrow.circlepath"
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Import

    private func handleImport(
        _ result: Result<[URL], Error>
    ) {

        switch result {

        case .success(let urls):

            guard let url = urls.first else {
                return
            }

            do {
                switch try watchManager.importBackup(from: url) {

                case .imported(let record):

                    showMessage(
                        String(localized: "Backup imported successfully. Size: \(record.formattedSize).")
                    )

                case .duplicate:

                    showMessage(
                        String(localized: "An identical backup is already in the history.")
                    )
                }

            } catch {

                showMessage(
                    String(localized: "Could not import the backup:\n\(error.localizedDescription)")
                )
            }

        case .failure(let error):

            showMessage(
                String(localized: "Could not select the file:\n\(error.localizedDescription)")
            )
        }
    }

    // MARK: - Export

    private func exportBackup(
        _ record: WatchConnectivityManager.BackupRecord
    ) {

        guard let url = watchManager.exportURL(for: record) else {
            showMessage(String(localized: "The file to export could not be found."))
            return
        }

        shareURL = ShareItem(url: url)
    }

    // MARK: - Alert

    private func showMessage(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}
