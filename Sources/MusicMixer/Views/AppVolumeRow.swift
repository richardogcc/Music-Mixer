import SwiftUI
import AppKit

struct AppVolumeRow: View {
    @ObservedObject var process: AudioProcess
    let audioManager: AudioProcessManager

    var body: some View {
        HStack(spacing: 10) {
            appIconView

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(process.appName)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Spacer()
                    Text("\(Int(process.volume * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 30, alignment: .trailing)
                }

                Slider(
                    value: Binding(
                        get: { Double(process.volume) },
                        set: { audioManager.setVolume(Float($0), for: process) }
                    ),
                    in: 0...1
                )
                .controlSize(.small)
                .disabled(process.isMuted)
                .opacity(process.isMuted ? 0.4 : 1.0)
            }

            muteButton
                .frame(width: 28)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var appIconView: some View {
        Group {
            if let icon = process.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
            } else {
                Image(systemName: "app.dashed")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var muteButton: some View {
        Button {
            audioManager.setMuted(!process.isMuted, for: process)
        } label: {
            Image(systemName: process.isMuted ? "speaker.slash.fill" : "speaker.fill")
                .font(.system(size: 14))
                .foregroundStyle(process.isMuted ? Color.red : Color.secondary)
                .frame(width: 24, height: 24)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .help(process.isMuted ? "Unmute \(process.appName)" : "Mute \(process.appName)")
    }
}
