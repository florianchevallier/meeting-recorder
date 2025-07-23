import Foundation
import UserNotifications

@MainActor
class MeetingDetector: ObservableObject {
    private let calendarManager: CalendarManager
    private let audioRecorder: AudioRecorder
    
    @Published var isAutoRecordingEnabled = true
    @Published var recordingHistory: [RecordingSession] = []
    
    private var detectionTimer: Timer?
    private var currentAutoRecording: RecordingSession?
    
    init(calendarManager: CalendarManager, audioRecorder: AudioRecorder) {
        self.calendarManager = calendarManager
        self.audioRecorder = audioRecorder
        
        setupDetectionTimer()
        requestNotificationPermission()
    }
    
    deinit {
        detectionTimer?.invalidate()
    }
    
    private func setupDetectionTimer() {
        detectionTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task {
                await self?.checkForMeetingsToRecord()
            }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    private func checkForMeetingsToRecord() async {
        guard isAutoRecordingEnabled else { return }
        
        if let meetingToRecord = calendarManager.getNextMeetingToRecord() {
            await startAutoRecording(for: meetingToRecord)
        }
        
        if let currentMeeting = calendarManager.currentMeeting,
           currentAutoRecording != nil,
           !currentMeeting.isCurrentlyActive {
            await stopAutoRecording()
        }
    }
    
    private func startAutoRecording(for meeting: MeetingEvent) async {
        guard currentAutoRecording == nil else { return }
        
        do {
            try await audioRecorder.startRecording()
            
            let timestamp = DateFormatter.filenameDateFormatter.string(from: Date())
            let sanitizedTitle = meeting.title.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)
            let filename = "\(timestamp)_\(sanitizedTitle).m4a"
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = documentsPath.appendingPathComponent(filename)
            
            currentAutoRecording = RecordingSession(fileName: filename, fileURL: fileURL, meetingTitle: meeting.title)
            
            await sendNotification(title: "Enregistrement démarré", 
                                 body: "Enregistrement automatique pour: \(meeting.title)")
            
        } catch {
            print("Failed to start auto recording: \(error)")
        }
    }
    
    private func stopAutoRecording() async {
        guard var recording = currentAutoRecording else { return }
        
        Task {
            await audioRecorder.stopRecording()
        }
        recording.stopRecording()
        
        recordingHistory.append(recording)
        currentAutoRecording = nil
        
        await sendNotification(title: "Enregistrement terminé", 
                             body: "Fichier sauvé: \(recording.fileName)")
    }
    
    private func sendNotification(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to send notification: \(error)")
        }
    }
    
    func toggleAutoRecording() {
        isAutoRecordingEnabled.toggle()
        
        if !isAutoRecordingEnabled && currentAutoRecording != nil {
            Task {
                await stopAutoRecording()
            }
        }
    }
}