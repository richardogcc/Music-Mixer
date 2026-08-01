import SwiftUI
import AppKit

struct MasterVolumeRow: View {
    @ObservedObject var manager: MasterVolumeManager

    var body: some View {
        HStack(spacing: 10) {
            // Fixed-width icon area
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("System Output")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Slider(
                    value: Binding(
                        get: { Double(manager.volume) },
                        set: { manager.setVolume(Float($0)) }
                    ),
                    in: 0...1
                )
                .controlSize(.small)
                .tint(Color.accentColor)
            }

            muteButton
                .frame(width: 28)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var muteButton: some View {
        Button {
            manager.setMuted(!manager.isMuted)
        } label: {
            Image(systemName: manager.isMuted ? "speaker.slash.fill" : "speaker.fill")
                .font(.system(size: 14))
                .foregroundStyle(manager.isMuted ? Color.red : Color.secondary)
                .frame(width: 24, height: 24)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .help(manager.isMuted ? "Unmute" : "Mute")
    }
}
