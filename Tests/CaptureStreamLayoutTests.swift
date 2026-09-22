import Testing
@testable import MeetingRecorder

@Suite("CaptureStreamLayout inference")
struct CaptureStreamLayoutTests {

    @Test("Mono mic first, stereo tap last")
    func micFirst() throws {
        let layout = try #require(
            CaptureStreamLayout.infer(
                bufferChannelCounts: [1, 2], microphoneStreamChannelCounts: [1], tapChannelCount: 2, sampleRate: 48_000
            ))
        #expect(layout.microphoneStreams.map(\.bufferIndex) == [0])
        #expect(layout.tapStreams.map(\.bufferIndex) == [1])
        #expect(layout.hasMicrophone)
    }

    @Test("Tap first, mic last is accepted")
    func tapFirst() throws {
        let layout = try #require(
            CaptureStreamLayout.infer(
                bufferChannelCounts: [2, 1], microphoneStreamChannelCounts: [1], tapChannelCount: 2, sampleRate: 44_100
            ))
        #expect(layout.tapStreams.map(\.bufferIndex) == [0])
        #expect(layout.microphoneStreams.map(\.bufferIndex) == [1])
        #expect(layout.sampleRate == 44_100)
    }

    @Test("Stereo mic followed by stereo tap resolves by order")
    func ambiguousChannelsResolvedByOrder() throws {
        let layout = try #require(
            CaptureStreamLayout.infer(
                bufferChannelCounts: [2, 2], microphoneStreamChannelCounts: [2], tapChannelCount: 2, sampleRate: 48_000
            ))
        #expect(layout.microphoneStreams.map(\.bufferIndex) == [0])
        #expect(layout.tapStreams.map(\.bufferIndex) == [1])
    }

    @Test("Multi-stream microphone")
    func multiStreamMic() throws {
        let layout = try #require(
            CaptureStreamLayout.infer(
                bufferChannelCounts: [1, 1, 2], microphoneStreamChannelCounts: [1, 1], tapChannelCount: 2,
                sampleRate: 48_000
            ))
        #expect(layout.microphoneStreams.count == 2)
        #expect(layout.tapStreams.map(\.bufferIndex) == [2])
    }

    @Test("Tap only")
    func tapOnly() throws {
        let layout = try #require(
            CaptureStreamLayout.infer(
                bufferChannelCounts: [2], microphoneStreamChannelCounts: [], tapChannelCount: 2, sampleRate: 48_000
            ))
        #expect(!layout.hasMicrophone)
        #expect(layout.tapStreams.count == 1)
    }

    @Test("Unexpected shape yields nil")
    func unexpected() {
        #expect(
            CaptureStreamLayout.infer(
                bufferChannelCounts: [1, 1, 1], microphoneStreamChannelCounts: [1], tapChannelCount: 2,
                sampleRate: 48_000
            ) == nil)
    }
}
