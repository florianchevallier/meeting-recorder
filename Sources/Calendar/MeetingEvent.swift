import Foundation

struct MeetingEvent {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isTeamsMeeting: Bool
    let joinUrl: String?
    
    var duration: TimeInterval {
        return endDate.timeIntervalSince(startDate)
    }
    
    var isCurrentlyActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }
    
    var startsWithinMinutes: Int? {
        let now = Date()
        let timeUntilStart = startDate.timeIntervalSince(now)
        
        if timeUntilStart > 0 && timeUntilStart <= 600 { // Within 10 minutes
            return Int(timeUntilStart / 60)
        }
        return nil
    }
    
    static func isTeamsMeetingTitle(_ title: String) -> Bool {
        let teamsKeywords = [
            "microsoft teams",
            "teams meeting",
            "teams call",
            "join microsoft teams",
            "équipe teams",
            "réunion teams"
        ]
        
        let lowercaseTitle = title.lowercased()
        return teamsKeywords.contains { keyword in
            lowercaseTitle.contains(keyword)
        }
    }
    
    static func hasTeamsUrl(_ url: String?) -> Bool {
        guard let url = url else { return false }
        return url.contains("teams.microsoft.com") || url.contains("teams.live.com")
    }
}