import Foundation
import EventKit

struct MeetingEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let notes: String?
    let calendar: String
    
    var duration: TimeInterval {
        return endDate.timeIntervalSince(startDate)
    }
    
    var isCurrentlyActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }
    
    var isUpcoming: Bool {
        return startDate > Date()
    }
    
    var hasStarted: Bool {
        return startDate <= Date()
    }
    
    var timeUntilStart: TimeInterval {
        return startDate.timeIntervalSince(Date())
    }
    
    init(from ekEvent: EKEvent) {
        self.id = ekEvent.eventIdentifier
        self.title = ekEvent.title ?? "Untitled Meeting"
        self.startDate = ekEvent.startDate
        self.endDate = ekEvent.endDate
        self.location = ekEvent.location
        self.notes = ekEvent.notes
        self.calendar = ekEvent.calendar.title
    }
    
    static func isMeetingEvent(_ event: EKEvent) -> Bool {
        let meetingKeywords = [
            "meeting", "réunion", "reunion", "call", "appel",
            "conference", "conférence", "zoom", "teams",
            "skype", "hangout", "webex", "meet", "rendez-vous"
        ]
        
        let title = event.title?.lowercased() ?? ""
        let notes = event.notes?.lowercased() ?? ""
        let location = event.location?.lowercased() ?? ""
        
        let searchText = "\(title) \(notes) \(location)"
        
        return meetingKeywords.contains { keyword in
            searchText.contains(keyword)
        }
    }
}

extension MeetingEvent {
    var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
    
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
    
    var shouldStartRecording: Bool {
        // Start recording 2 minutes before the meeting
        let recordingStartTime = startDate.addingTimeInterval(-120)
        let now = Date()
        
        return now >= recordingStartTime && now < endDate
    }
}