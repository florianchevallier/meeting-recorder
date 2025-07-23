import Foundation

struct RecordingSession: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    let fileName: String
    let fileURL: URL
    var meetingTitle: String?
    var duration: TimeInterval {
        guard let endTime = endTime else {
            return Date().timeIntervalSince(startTime)
        }
        return endTime.timeIntervalSince(startTime)
    }
    
    var isRecording: Bool {
        return endTime == nil
    }
    
    var fileSize: Int64? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            return attributes[.size] as? Int64
        } catch {
            return nil
        }
    }
    
    init(fileName: String, fileURL: URL, meetingTitle: String? = nil) {
        self.id = UUID()
        self.startTime = Date()
        self.fileName = fileName
        self.fileURL = fileURL
        self.meetingTitle = meetingTitle
    }
    
    mutating func stopRecording() {
        self.endTime = Date()
    }
}

extension RecordingSession {
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "00:00:00"
    }
    
    var formattedFileSize: String {
        guard let fileSize = fileSize else { return "Unknown" }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}