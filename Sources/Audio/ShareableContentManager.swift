import Foundation
@preconcurrency import ScreenCaptureKit

@available(macOS 12.3, *)
@MainActor
class ShareableContentManager {
    static let shared = ShareableContentManager()
    
    private var cachedContent: SCShareableContent?
    private var lastUpdateTime: Date?
    private let cacheTimeout: TimeInterval = 2.0 // Cache for 2 seconds
    
    private init() {}
    
    func getShareableContent() async throws -> SCShareableContent {
        let now = Date()
        
        // Return cached content if still valid
        if let cached = cachedContent,
           let lastUpdate = lastUpdateTime,
           now.timeIntervalSince(lastUpdate) < cacheTimeout {
            Logger.shared.log("📋 [CONTENT_MANAGER] Using cached shareable content")
            return cached
        }
        
        // Fetch fresh content
        Logger.shared.log("📋 [CONTENT_MANAGER] Fetching fresh shareable content...")
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        // Cache the result
        cachedContent = content
        lastUpdateTime = now
        
        Logger.shared.log("📋 [CONTENT_MANAGER] Cached new content: \(content.displays.count) displays, \(content.windows.count) windows")
        return content
    }
    
    func getFirstDisplay() async throws -> SCDisplay {
        let content = try await getShareableContent()
        guard let display = content.displays.first else {
            throw ShareableContentError.noDisplayFound
        }
        return display
    }
    
    func clearCache() {
        Logger.shared.log("🗑️ [CONTENT_MANAGER] Clearing cache")
        cachedContent = nil
        lastUpdateTime = nil
    }
}

enum ShareableContentError: Error {
    case noDisplayFound
}