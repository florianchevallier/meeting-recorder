import Foundation

/// Puts names on WhisperX speaker labels. Pure: every input is passed in.
///
/// 1. Names the user typed (`.speakers.json`) always win.
/// 2. "Me": the speaker whose words mostly fall where the microphone dominates
///    the system audio (the local user speaks into the mic, remote people come
///    through the system tap).
/// 3. When exactly one speaker and one expected participant are left, they match
///    (this names both sides of every 1:1).
enum SpeakerLabeler {

    struct Thresholds: Sendable {
        /// Below this, the microphone is considered silent.
        var micFloorDB: Int = -40
        /// The microphone must beat the system audio by this much.
        var dominanceDB: Int = 10
        /// Share of a speaker's speech that must fall in mic-dominant windows.
        var selfShare: Double = 0.6
        /// The runner-up must be this far behind, or nobody is "me".
        var margin: Double = 0.25
        /// Speakers with less speech than this are ignored (a cough, a "yes").
        var minimumSpeech: Double = 3
    }

    /// The speaker who is the local user, if the activity makes it clear.
    static func selfSpeaker(
        in transcript: Transcript, activity: VoiceActivity, thresholds: Thresholds = Thresholds()
    ) -> String? {
        var total: [String: Double] = [:]
        var mine: [String: Double] = [:]

        for segment in transcript.segments {
            for word in segment.words ?? [] {
                guard let speaker = word.speaker ?? segment.speaker,
                    let start = word.start, let end = word.end, end > start
                else { continue }
                let duration = end - start
                total[speaker, default: 0] += duration
                if activity.isMicrophoneDominant(at: (start + end) / 2, thresholds: thresholds) {
                    mine[speaker, default: 0] += duration
                }
            }
        }

        let shares =
            total
            .filter { $0.value >= thresholds.minimumSpeech }
            .map { (speaker: $0.key, share: mine[$0.key, default: 0] / $0.value) }
            .sorted { $0.share > $1.share }

        guard let best = shares.first, best.share >= thresholds.selfShare else { return nil }
        if shares.count > 1, best.share - shares[1].share < thresholds.margin { return nil }
        return best.speaker
    }

    /// Names for the speakers that could be identified; the others stay unnamed.
    static func names(
        for transcript: Transcript,
        activity: VoiceActivity?,
        event: CalendarEvent?,
        manual: [String: String],
        selfFallbackName: String
    ) -> [String: String] {
        var names = manual.filter { !$0.value.isEmpty }
        let participants = event?.expectedParticipants ?? []

        let me = activity.flatMap { selfSpeaker(in: transcript, activity: $0) }
        if let me, names[me] == nil {
            let myName = participants.first(where: \.isCurrentUser)?.displayName ?? selfFallbackName
            if !names.values.contains(myName) {
                names[me] = myName
            }
        }

        // Until the microphone points at a speaker, the local user is still one of the candidates.
        let taken = Set(names.values)
        let remainingParticipants = participants.filter {
            !taken.contains($0.displayName) && !($0.isCurrentUser && me != nil)
        }
        let unnamedSpeakers = transcript.speakers.filter { names[$0] == nil }
        if unnamedSpeakers.count == 1, remainingParticipants.count == 1 {
            names[unnamedSpeakers[0]] = remainingParticipants[0].displayName
        }
        return names
    }
}
