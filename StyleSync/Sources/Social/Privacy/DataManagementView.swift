import SwiftUI

struct DataManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var privacyManager = PrivacyManager.shared
    @State private var selectedRetentionDays = 30
    @State private var showingDataExport = false
    @State private var showingDataDeletion = false
    @State private var dataSize = "Calculating..."
    @State private var lastBackup: Date?

    private let retentionOptions = [7, 30, 90, 180, 365, 0]

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    headerSection
                    dataRetentionSection
                    dataOverviewSection
                    exportSection
                    deletionSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color.black)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingDataExport) {
            DataExportView()
        }
        .alert("Delete All Data", isPresented: $showingDataDeletion) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAllData()
            }
        } message: {
            Text("This will permanently delete all your StyleSync data, including posts, messages, and profile information. This action cannot be undone.")
        }
        .onAppear {
            calculateDataSize()
            loadLastBackupDate()
            selectedRetentionDays = privacyManager.privacySettings.dataRetentionDays
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }

                Spacer()

                Text("Data Management")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: {}) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(width: 32, height: 32)
                }
            }

            VStack(spacing: 8) {
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white)

                Text("Control your data storage and retention")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var dataRetentionSection: some View {
        VStack(spacing: 16) {
            SectionHeader(
                title: "Data Retention",
                icon: "clock.arrow.circlepath",
                description: "Automatically delete old data to save storage"
            )

            VStack(spacing: 16) {
                Text("Keep data for:")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(retentionOptions, id: \.self) { days in
                        RetentionOptionCard(
                            days: days,
                            isSelected: selectedRetentionDays == days
                        ) {
                            selectedRetentionDays = days
                            privacyManager.scheduleDataDeletion(after: days)
                            HapticManager.shared.impact(.light)
                        }
                    }
                }

                if selectedRetentionDays > 0 {
                    Text("Data older than \(selectedRetentionDays) days will be automatically deleted")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
            }
        }
        .glassCard()
    }

    private var dataOverviewSection: some View {
        VStack(spacing: 16) {
            SectionHeader(
                title: "Storage Overview",
                icon: "chart.pie",
                description: "View how much space your data is using"
            )

            VStack(spacing: 12) {
                DataUsageRow(
                    title: "Total Data Size",
                    value: dataSize,
                    icon: "externaldrive",
                    color: .blue
                )

                DataUsageRow(
                    title: "Photos & Videos",
                    value: "1.2 GB",
                    icon: "photo",
                    color: .green
                )

                DataUsageRow(
                    title: "Messages",
                    value: "45 MB",
                    icon: "message",
                    color: .purple
                )

                DataUsageRow(
                    title: "Profile Data",
                    value: "12 MB",
                    icon: "person.circle",
                    color: .orange
                )

                if let backup = lastBackup {
                    HStack {
                        Text("Last Backup:")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)

                        Spacer()

                        Text(formatDate(backup))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .glassCard()
    }

    private var exportSection: some View {
        VStack(spacing: 16) {
            SectionHeader(
                title: "Data Export",
                icon: "square.and.arrow.up",
                description: "Download your data for backup or transfer"
            )

            VStack(spacing: 12) {
                ActionButton(
                    title: "Export All Data",
                    description: "Download all your StyleSync data",
                    icon: "doc.zipper",
                    action: {
                        showingDataExport = true
                    }
                )

                ActionButton(
                    title: "Export Photos & Videos",
                    description: "Download your media files",
                    icon: "photo.on.rectangle",
                    action: {
                        exportMedia()
                    }
                )

                ActionButton(
                    title: "Export Messages",
                    description: "Download your conversation history",
                    icon: "message.circle",
                    action: {
                        exportMessages()
                    }
                )
            }

            Text("Exports are encrypted and include all your personal data in a portable format.")
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .glassCard()
    }

    private var deletionSection: some View {
        VStack(spacing: 16) {
            SectionHeader(
                title: "Data Deletion",
                icon: "trash",
                description: "Permanently remove data from StyleSync"
            )

            VStack(spacing: 12) {
                ActionButton(
                    title: "Clear Cache",
                    description: "Free up space by clearing temporary files",
                    icon: "trash.circle",
                    action: {
                        clearCache()
                    }
                )

                ActionButton(
                    title: "Delete Media Files",
                    description: "Remove downloaded photos and videos",
                    icon: "photo.badge.minus",
                    action: {
                        deleteMediaFiles()
                    }
                )

                Button(action: { showingDataDeletion = true }) {
                    HStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.red)
                            .frame(width: 24, height: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Delete All Data")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.red)

                            Text("Permanently delete your StyleSync account and all data")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 12)
                }
                .hapticFeedback(.heavy, trigger: true)
            }

            Text("⚠️ Deletion actions are permanent and cannot be undone.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
        }
        .glassCard()
    }

    private func calculateDataSize() {
        Task {
            let size = await calculateStorageSize()
            DispatchQueue.main.async {
                self.dataSize = size
            }
        }
    }

    private func calculateStorageSize() async -> String {
        await Task.sleep(1_000_000_000)
        return "1.3 GB"
    }

    private func loadLastBackupDate() {
        lastBackup = UserDefaults.standard.object(forKey: "lastBackupDate") as? Date
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func exportMedia() {
        HapticManager.shared.impact(.medium)
    }

    private func exportMessages() {
        HapticManager.shared.impact(.medium)
    }

    private func clearCache() {
        HapticManager.shared.impact(.light)
    }

    private func deleteMediaFiles() {
        HapticManager.shared.impact(.medium)
    }

    private func deleteAllData() {
        HapticManager.shared.impact(.heavy)
    }
}

struct RetentionOptionCard: View {
    let days: Int
    let isSelected: Bool
    let onTap: () -> Void

    private var displayText: String {
        if days == 0 {
            return "Never"
        } else if days < 30 {
            return "\(days) days"
        } else if days < 365 {
            return "\(days / 30) months"
        } else {
            return "\(days / 365) year"
        }
    }

    var body: some View {
        Button(action: onTap) {
            Text(displayText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.white : Color.white.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.clear : Color.white.opacity(0.2), lineWidth: 1)
                )
        }
        .scaleEffect(isSelected ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

struct DataUsageRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
                .frame(width: 20, height: 20)

            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.white)

            Spacer()

            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.vertical, 8)
    }
}

struct DataExportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isExporting = false
    @State private var exportProgress: Double = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "doc.zipper")
                        .font(.system(size: 64, weight: .light))
                        .foregroundColor(.white)

                    Text("Export Data")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text("This will create an encrypted archive of all your StyleSync data.")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                if isExporting {
                    VStack(spacing: 16) {
                        ProgressView(value: exportProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .white))
                            .frame(height: 8)

                        Text("\(Int(exportProgress * 100))% Complete")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 40)
                }

                VStack(spacing: 16) {
                    Button(action: startExport) {
                        Text(isExporting ? "Exporting..." : "Start Export")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(isExporting ? Color.gray : Color.white)
                            )
                    }
                    .disabled(isExporting)
                    .hapticFeedback(.medium, trigger: !isExporting)

                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                    .hapticFeedback(.light, trigger: true)
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .background(Color.black)
            .navigationBarHidden(true)
        }
    }

    private func startExport() {
        isExporting = true
        exportProgress = 0

        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            exportProgress += 0.02
            if exportProgress >= 1.0 {
                timer.invalidate()
                isExporting = false
                HapticManager.shared.success()
                dismiss()
            }
        }
    }
}

#Preview {
    DataManagementView()
        .preferredColorScheme(.dark)
}