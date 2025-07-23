import Foundation
import EventKit

class CalendarManager: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var upcomingMeetings: [MeetingEvent] = []
    @Published var currentMeeting: MeetingEvent?
    
    private var updateTimer: Timer?
    
    init() {
        setupUpdateTimer()
    }
    
    deinit {
        updateTimer?.invalidate()
    }
    
    private func setupUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task {
                await self?.updateMeetings()
            }
        }
    }
    
    @MainActor
    func updateMeetings() async {
        do {
            let events = try await fetchTodaysMeetings()
            let meetings = events.compactMap { MeetingEvent(from: $0) }
            
            self.upcomingMeetings = meetings.filter { $0.isUpcoming }
            self.currentMeeting = meetings.first { $0.isCurrentlyActive }
            
        } catch {
            print("Failed to update meetings: \(error)")
        }
    }
    
    private func fetchTodaysMeetings() async throws -> [EKEvent] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        return events.filter { MeetingEvent.isMeetingEvent($0) }
    }
    
    func getNextMeetingToRecord() -> MeetingEvent? {
        return upcomingMeetings.first { $0.shouldStartRecording }
    }
    
    func getMeetingStartingSoon(within minutes: Int = 5) -> MeetingEvent? {
        let threshold = TimeInterval(minutes * 60)
        return upcomingMeetings.first { meeting in
            meeting.timeUntilStart <= threshold && meeting.timeUntilStart > 0
        }
    }
}