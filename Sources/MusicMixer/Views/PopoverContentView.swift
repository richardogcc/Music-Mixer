import SwiftUI
import AppKit

struct PopoverContentView: View {
    @EnvironmentObject var audioManager: AudioProcessManager
    @StateObject private var masterVolume = MasterVolumeManager()

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──────────────────────────────────────────────
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(.secondary)
                Text("Music Mixer")
                    .font(.headline)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial)

            Divider()

            // ── Master volume ────────────────────────────────────────
            MasterVolumeRow(manager: masterVolume)

            Divider()

            // ── Per-app rows ─────────────────────────────────────────
            if audioManager.processes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "speaker.slash")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No apps playing audio")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(audioManager.processes) { process in
                            AppVolumeRow(process: process, audioManager: audioManager)
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
            }
        }
        .frame(width: 320)
        .background(.regularMaterial)
        .onAppear { masterVolume.start() }
        .onDisappear { masterVolume.stop() }
    }
}
