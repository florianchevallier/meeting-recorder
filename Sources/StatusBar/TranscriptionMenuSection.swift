import SwiftUI

/// Popover row for the WhisperX job: progress while transcribing, the error
/// with Retry after a failure, nothing otherwise.
struct TranscriptionMenuSection: View {
    let transcription: TranscriptionCoordinator

    var body: some View {
        if transcription.state.isTranscribing {
            VStack(spacing: 0) {
                Divider().padding(.horizontal, 20)

                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.1))
                            .frame(width: 32, height: 32)

                        Image(systemName: "waveform.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.purple)
                            .symbolEffect(.pulse, options: .repeating)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.menuTranscriptionRunning)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(transcription.state.progress)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        if let percent = transcription.state.percent {
                            ProgressView(value: Double(percent), total: 100)
                                .controlSize(.small)
                                .tint(.purple)
                        }

                        if !transcription.queue.isEmpty {
                            Text(L10n.menuTranscriptionQueued(transcription.queue.count))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if transcription.state.status == .running,
                        transcription.state.percent == nil
                    {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.8)
                    }

                    if transcription.current != nil {
                        Button(L10n.menuTranscriptionCancel) { transcription.cancel() }
                            .buttonStyle(.borderless)
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.purple.opacity(0.05))
            }
        } else if let error = transcription.state.error {
            VStack(spacing: 0) {
                Divider().padding(.horizontal, 20)

                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.menuTranscriptionError)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(error)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    if transcription.lastFailed != nil {
                        Button(L10n.menuTranscriptionRetry) { transcription.retry() }
                            .buttonStyle(.borderless)
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.05))
            }
        }
    }
}
