import Foundation
import ScreenCaptureKit
import AVFoundation

@available(macOS 15.0, *)
final class UnifiedScreenCapture: NSObject {
    private var stream: SCStream?
    private var isRecording = false
    private var recordingStartTime: Date?
    private var outputURL: URL?
    private var recordingFinishedContinuation: CheckedContinuation<Void, Never>?
    private var recordingFinalizationWatcher: Task<Void, Never>?
    
    // Queues dédiées pour chaque type de contenu
    private let screenQueue = DispatchQueue(label: "UnifiedCapture.ScreenQueue", qos: .userInitiated)
    private let audioQueue = DispatchQueue(label: "UnifiedCapture.AudioQueue", qos: .userInitiated)
    private let microphoneQueue = DispatchQueue(label: "UnifiedCapture.MicrophoneQueue", qos: .userInitiated)
    
    // Configuration pour enregistrement direct
    private var recordingOutput: SCRecordingOutput?
    
    // ✨ Gestion d'erreur et recovery
    private var retryCount = 0
    private let maxRetryCount = 3
    private let retryDelay: TimeInterval = 2.0
    private var lastStreamConfiguration: SCStreamConfiguration?
    private var lastContentFilter: SCContentFilter?
    private var isRecovering = false
    
    // Callback pour notifier l'application des erreurs critiques
    var onCriticalError: ((Error) -> Void)?
    var onRecoveryAttempt: ((Int) -> Void)?
    var onRecoverySuccess: (() -> Void)?
    
    // ✨ Surveillance continue de l'état du stream
    private var healthCheckTimer: Timer?
    private let healthCheckInterval: TimeInterval = 5.0 // Vérifier toutes les 5 secondes
    private var lastSampleTime: Date?
    private var sampleCount = 0
    private var healthCheckCounter = 0
    
    override init() {
        super.init()
    }
    
    /// Démarre l'enregistrement unifié avec sauvegarde directe en .mov
    func startDirectRecording() async throws {
        guard !isRecording else {
            Logger.shared.log("⚠️ [UNIFIED_CAPTURE] Already recording")
            return
        }
        
        Logger.shared.log("🚀 [UNIFIED_CAPTURE] Starting unified recording (macOS 15+)...")
        
        // Reset retry counter pour un nouveau démarrage
        retryCount = 0
        isRecovering = false
        
        try await startDirectRecordingInternal()
    }
    
    /// Implémentation interne avec retry automatique
    private func startDirectRecordingInternal() async throws {
        // Configuration du stream
        let configuration = SCStreamConfiguration()
        
        // Obtenir les dimensions réelles de l'écran
        let availableContent = try await SCShareableContent.current
        guard let display = availableContent.displays.first else {
            throw NSError(domain: "UnifiedCaptureError", code: 1, 
                         userInfo: [NSLocalizedDescriptionKey: "No display available"])
        }
        
        // Configuration écran avec dimensions valides
        configuration.width = display.width
        configuration.height = display.height
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 15)
        configuration.showsCursor = true
        
        // Configuration audio système
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true
        
        // ✨ Configuration microphone (nouveau dans macOS 15+)
        configuration.captureMicrophone = true
        if let defaultMicrophone = AVCaptureDevice.default(for: .audio) {
            configuration.microphoneCaptureDeviceID = defaultMicrophone.uniqueID
            Logger.shared.log("🎤 [UNIFIED_CAPTURE] Using microphone: \(defaultMicrophone.localizedName)")
        }
        
        // Fix pour macOS 15: utiliser includingApplications au lieu d'excludingWindows avec tableau vide
        let filter = SCContentFilter(display: display, 
                                   including: availableContent.applications, 
                                   exceptingWindows: [])
        
        // Sauvegarder la configuration pour recovery
        lastStreamConfiguration = configuration
        lastContentFilter = filter
        
        // Préparer l'URL de sortie (seulement si pas déjà définie lors d'un retry)
        if outputURL == nil {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let timestamp = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let filename = "meeting_unified_\(formatter.string(from: timestamp)).mov"
            outputURL = documentsPath.appendingPathComponent(filename)
            Logger.shared.log("🎬 [UNIFIED_CAPTURE] Recording to: \(filename)")
        }
        
        // ✨ Configuration d'enregistrement direct
        guard let safeOutputURL = outputURL else {
            throw NSError(domain: "UnifiedCaptureError", code: 2,
                         userInfo: [NSLocalizedDescriptionKey: "Output URL not configured"])
        }

        let recordingConfiguration = SCRecordingOutputConfiguration()
        recordingConfiguration.outputURL = safeOutputURL
        recordingConfiguration.outputFileType = .mov
        recordingConfiguration.videoCodecType = .hevc

        // Créer l'output d'enregistrement
        let newRecordingOutput = SCRecordingOutput(configuration: recordingConfiguration, delegate: self)
        recordingOutput = newRecordingOutput

        // Créer et configurer le stream
        stream = SCStream(filter: filter, configuration: configuration, delegate: self)

        guard let stream = stream else {
            throw NSError(domain: "UnifiedCaptureError", code: 3,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create SCStream - check screen recording permissions"])
        }

        // Ajouter l'output d'enregistrement au stream
        try stream.addRecordingOutput(newRecordingOutput)
        
        // Démarrer la capture
        try await stream.startCapture()
        
        isRecording = true
        if recordingStartTime == nil {
            recordingStartTime = Date()
        }
        
        // Démarrer la surveillance de santé
        startHealthMonitoring()
        
        Logger.shared.log("✅ [UNIFIED_CAPTURE] Unified recording started - Screen + System Audio + Microphone")
    }
    
    /// Démarre l'enregistrement unifié avec gestion manuelle des samples
    func startManualRecording() async throws {
        guard !isRecording else {
            Logger.shared.log("⚠️ [UNIFIED_CAPTURE] Already recording")
            return
        }
        
        Logger.shared.log("🚀 [UNIFIED_CAPTURE] Starting manual unified recording (macOS 15+)...")
        
        // Configuration identique mais sans SCRecordingOutput
        let configuration = SCStreamConfiguration()
        
        let availableContent = try await SCShareableContent.current
        guard let display = availableContent.displays.first else {
            throw NSError(domain: "UnifiedCaptureError", code: 2, 
                         userInfo: [NSLocalizedDescriptionKey: "No display available"])
        }
        
        configuration.width = display.width
        configuration.height = display.height
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 15)
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true
        configuration.captureMicrophone = true
        
        if let defaultMicrophone = AVCaptureDevice.default(for: .audio) {
            configuration.microphoneCaptureDeviceID = defaultMicrophone.uniqueID
        }
        
        // Fix pour macOS 15: utiliser includingApplications au lieu d'excludingWindows avec tableau vide
        let filter = SCContentFilter(display: display, 
                                   including: availableContent.applications, 
                                   exceptingWindows: [])
        stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        
        guard let stream = stream else {
            throw NSError(domain: "UnifiedCaptureError", code: 3, 
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create SCStream - check screen recording permissions"])
        }
        
        // Ajouter les outputs pour gestion manuelle
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: screenQueue)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
        try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: microphoneQueue)
        
        try await stream.startCapture()
        
        isRecording = true
        recordingStartTime = Date()
        Logger.shared.log("✅ [UNIFIED_CAPTURE] Manual unified recording started")
    }
    
    func stopRecording() async -> URL? {
        guard isRecording, let stream = self.stream else {
            Logger.shared.log("⚠️ [UNIFIED_CAPTURE] Not currently recording or stream is nil")
            return nil
        }
        
        Logger.shared.log("🛑 [UNIFIED_CAPTURE] Stopping unified recording...")
        
        do {
            // 1. D'abord, on demande au flux de s'arrêter et ON ATTEND que ce soit terminé
            try await stream.stopCapture()
            
            // 2. Attendre que SCRecordingOutput ait complètement fini d'écrire le fichier
        Logger.shared.log("⏳ [UNIFIED_CAPTURE] Waiting for recording output to finish...")
        await withCheckedContinuation { continuation in
            self.recordingFinishedContinuation = continuation

            self.recordingFinalizationWatcher?.cancel()
            self.recordingFinalizationWatcher = Task { [weak self] in
                guard let self else { return }

                let maxWait: TimeInterval = 120
                let checkInterval: TimeInterval = 0.5
                var elapsed: TimeInterval = 0
                var lastSize: UInt64 = 0
                var stableCount = 0

                while !Task.isCancelled {
                    if self.recordingFinishedContinuation == nil {
                        return
                    }

                    try? await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
                    elapsed += checkInterval

                    guard let fileURL = self.outputURL else { continue }

                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                           let sizeNumber = attrs[.size] as? NSNumber {
                            let currentSize = sizeNumber.uint64Value
                            if currentSize > 0 && currentSize == lastSize {
                                stableCount += 1
                            } else {
                                stableCount = 0
                                lastSize = currentSize
                            }
                        }

                        if stableCount >= 3 {
                            Logger.shared.log("⏳ [UNIFIED_CAPTURE] Fallback detected stable MOV file, resuming completion")
                            if let cont = self.recordingFinishedContinuation {
                                self.recordingFinishedContinuation = nil
                                cont.resume()
                            }
                            return
                        }
                    }

                    if elapsed >= maxWait {
                        Logger.shared.log("⚠️ [UNIFIED_CAPTURE] Timeout waiting for recording output after \(Int(maxWait))s")
                        if let cont = self.recordingFinishedContinuation {
                            self.recordingFinishedContinuation = nil
                            cont.resume()
                        }
                        return
                    }
                }
            }
        }

        recordingFinalizationWatcher?.cancel()
        recordingFinalizationWatcher = nil
            
            // 3. Une fois que la capture est VRAIMENT arrêtée, on peut retirer les outputs
            if let recordingOutput = self.recordingOutput {
                try stream.removeRecordingOutput(recordingOutput)
            }
            
        } catch {
            // On log l'erreur mais on continue le nettoyage
            Logger.shared.log("❌ [UNIFIED_CAPTURE] Error during stream stop/cleanup: \(error)")
        }
        
        // 4. Maintenant que tout est arrêté et nettoyé, on peut détruire les objets
        self.recordingOutput = nil
        self.stream = nil
        isRecording = false
        
        if let startTime = recordingStartTime {
            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.log("🎬 [UNIFIED_CAPTURE] Recording stopped. Duration: \(String(format: "%.1f", duration))s")
        }
        
        recordingStartTime = nil
        
        // Arrêter la surveillance de santé
        stopHealthMonitoring()
        
        Logger.shared.log("✅ [UNIFIED_CAPTURE] Unified recording stopped successfully")
        
        return outputURL
    }
    
    // MARK: - Health Monitoring
    
    /// Démarre la surveillance continue de l'état du stream
    private func startHealthMonitoring() {
        Logger.shared.log("🩺 [HEALTH_MONITOR] Starting stream health monitoring")
        
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: healthCheckInterval, repeats: true) { [weak self] _ in
            self?.performHealthCheck()
        }
        
        lastSampleTime = Date()
        sampleCount = 0
    }
    
    /// Arrête la surveillance de santé
    private func stopHealthMonitoring() {
        Logger.shared.log("🩺 [HEALTH_MONITOR] Stopping stream health monitoring")
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        lastSampleTime = nil
        sampleCount = 0
    }
    
    /// Effectue une vérification de santé du stream
    private func performHealthCheck() {
        guard isRecording, let _ = self.stream else {
            return
        }
        
        // Vérifier si on reçoit des samples
        let now = Date()
        if let lastSample = lastSampleTime {
            let timeSinceLastSample = now.timeIntervalSince(lastSample)
            if timeSinceLastSample > 10.0 { // Plus de 10 secondes sans sample
                Logger.shared.log("🩺 [HEALTH_MONITOR] ⚠️ No samples received for \(timeSinceLastSample)s - investigating...")
                Logger.shared.log("🩺 [HEALTH_MONITOR] Total samples so far: \(sampleCount)")
                
                // Vérifier l'état du système seulement si problème détecté
                checkStreamHealth()
            }
        }
        
        // Log des statistiques seulement toutes les minutes (12 checks * 5s = 60s)
        healthCheckCounter += 1
        if healthCheckCounter >= 12 {
            Logger.shared.log("🩺 [HEALTH_MONITOR] Stream healthy - \(sampleCount) samples received")
            healthCheckCounter = 0
        }
    }
    
    /// Vérifie la santé du stream en détail
    private func checkStreamHealth() {
        Logger.shared.log("🩺 [STREAM_HEALTH] Checking stream health in detail...")
        
        Task {
            do {
                // Vérifier que le contenu est toujours disponible
                let content = try await SCShareableContent.current
                Logger.shared.log("🩺 [STREAM_HEALTH] Displays available: \(content.displays.count)")
                Logger.shared.log("🩺 [STREAM_HEALTH] Applications available: \(content.applications.count)")
                
                // Vérifier les permissions
                let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
                Logger.shared.log("🩺 [STREAM_HEALTH] Microphone permission: \(micStatus.rawValue)")
                
                // Vérifier si le microphone est toujours disponible
                if let defaultMic = AVCaptureDevice.default(for: .audio) {
                    Logger.shared.log("🩺 [STREAM_HEALTH] Default microphone: \(defaultMic.localizedName)")
                    Logger.shared.log("🩺 [STREAM_HEALTH] Microphone connected: \(defaultMic.isConnected)")
                    
                    if !defaultMic.isConnected {
                        Logger.shared.log("🩺 [STREAM_HEALTH] ⚠️ MICROPHONE DISCONNECTED!")
                    }
                } else {
                    Logger.shared.log("🩺 [STREAM_HEALTH] ⚠️ NO DEFAULT MICROPHONE AVAILABLE!")
                }
                
            } catch {
                Logger.shared.log("🩺 [STREAM_HEALTH] ❌ Error during health check: \(error)")
            }
        }
    }
    
    var recordingDuration: TimeInterval {
        guard let startTime = recordingStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
    
    /// Convertit un fichier MOV en M4A (audio uniquement)
    func convertMOVToM4A(sourceURL: URL) async throws -> URL {
        // Attendre que le fichier soit réellement prêt (jusqu'à ~15s)
        let maxWaitSeconds: Double = 15
        let checkIntervalSeconds: Double = 0.5
        let deadline = Date().addingTimeInterval(maxWaitSeconds)
        var lastSize: UInt64 = 0
        var stableCount = 0

        Logger.shared.log("⏳ [CONVERSION] Waiting for MOV to stabilize (max \(Int(maxWaitSeconds))s)...")

        var fileReady = false

        while Date() < deadline {
            guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                stableCount = 0
                lastSize = 0
                try? await Task.sleep(nanoseconds: UInt64(checkIntervalSeconds * 1_000_000_000))
                continue
            }

            // 1) Vérifier la stabilité de la taille du fichier
            if let attrs = try? FileManager.default.attributesOfItem(atPath: sourceURL.path),
               let sizeNumber = attrs[.size] as? NSNumber {
                let currentSize = sizeNumber.uint64Value
                if currentSize > 0 && currentSize == lastSize {
                    stableCount += 1
                } else {
                    stableCount = 0
                    lastSize = currentSize
                }
            }

            // 2) Essayer de charger la durée (dépendance AVFoundation mentionnée dans l'erreur)
            do {
                let probeAsset = AVURLAsset(url: sourceURL)
                let duration = try await probeAsset.load(.duration)
                if duration.isValid && duration.seconds > 0 && stableCount >= 2 {
                    fileReady = true
                    break // prêt
                }
            } catch {
                // Ignorer et réessayer jusqu'au timeout
            }

            try? await Task.sleep(nanoseconds: UInt64(checkIntervalSeconds * 1_000_000_000))
        }

        guard fileReady else {
            throw NSError(domain: "ConversionError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Fichier source introuvable ou incomplet : \(sourceURL.path)"])
        }

        // Procéder à la conversion
        let asset = AVURLAsset(url: sourceURL)

        // Charger la durée (va lever si encore non prêt)
        let duration = try await asset.load(.duration)
        Logger.shared.log("📹 [CONVERSION] Asset loaded, duration: \(CMTimeGetSeconds(duration))s")

        // Vérifier qu'il y a des pistes audio
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw NSError(domain: "ConversionError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Aucune piste audio trouvée dans le fichier"])
        }
        Logger.shared.log("🎵 [CONVERSION] Found \(audioTracks.count) audio track(s)")

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "ConversionError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Impossible de créer la session d'exportation."])
        }

        let outputURL = sourceURL.deletingPathExtension().appendingPathExtension("m4a")

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        Logger.shared.log("🔄 [CONVERSION] Starting export to: \(outputURL.lastPathComponent)")
        await exportSession.export()

        switch exportSession.status {
        case .completed:
            Logger.shared.log("✅ [CONVERSION] Fichier converti avec succès en M4A : \(outputURL.lastPathComponent)")
            return outputURL
        case .failed:
            let errorDescription = exportSession.error?.localizedDescription ?? "Erreur inconnue"
            let errorCode = (exportSession.error as? NSError)?.code ?? -1
            Logger.shared.log("❌ [CONVERSION] Export failed with code \(errorCode): \(errorDescription)")
            throw exportSession.error ?? NSError(domain: "ConversionError", code: 2, userInfo: [NSLocalizedDescriptionKey: "L'exportation a échoué avec une erreur inconnue."])
        case .cancelled:
            throw NSError(domain: "ConversionError", code: 3, userInfo: [NSLocalizedDescriptionKey: "L'exportation a été annulée."])
        default:
            throw NSError(domain: "ConversionError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Statut d'exportation inattendu: \(exportSession.status.rawValue)."])
        }
    }
    
    deinit {
        // Arrêter le timer de surveillance de santé (synchrone, safe dans deinit)
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil

        // Annuler les tâches en cours
        recordingFinalizationWatcher?.cancel()
        recordingFinalizationWatcher = nil

        // Note: Ne pas appeler de méthodes async dans deinit car l'objet sera déjà désalloué
        // Le cleanup async doit être fait explicitement via stopRecording() avant de libérer l'objet
        if isRecording {
            Logger.shared.log("⚠️ [UNIFIED_CAPTURE] deinit appelé pendant l'enregistrement - le fichier peut être incomplet")
        }
    }
}

// MARK: - SCStreamDelegate
@available(macOS 15.0, *)
extension UnifiedScreenCapture: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        Logger.shared.log("❌ [UNIFIED_CAPTURE] Stream stopped with error: \(error)")
        
        // Analyser l'erreur pour décider de la stratégie de recovery
        let nsError = error as NSError
        let errorCode = nsError.code
        let errorDomain = nsError.domain
        
        Logger.shared.log("🔍 [UNIFIED_CAPTURE] Error details - Domain: \(errorDomain), Code: \(errorCode)")
        
        // Classifier l'erreur
        let isRecoverableError = isErrorRecoverable(error)
        
        if isRecoverableError && retryCount < maxRetryCount && !isRecovering {
            Logger.shared.log("🔄 [UNIFIED_CAPTURE] Attempting recovery (\(retryCount + 1)/\(maxRetryCount))")
            attemptRecovery()
        } else {
            Logger.shared.log("🚨 [UNIFIED_CAPTURE] Critical error or max retries reached - stopping recording")
            handleCriticalError(error)
        }
    }
    
    /// Analyse approfondie de l'erreur pour comprendre la cause
    private func analyzeStreamError(_ error: Error) {
        let nsError = error as NSError
        let errorCode = nsError.code
        let errorDomain = nsError.domain
        let errorDescription = nsError.localizedDescription
        
        Logger.shared.log("🔍 [UNIFIED_CAPTURE] === ANALYSE DÉTAILLÉE DE L'ERREUR ===")
        Logger.shared.log("🔍 [UNIFIED_CAPTURE] Domain: \(errorDomain)")
        Logger.shared.log("🔍 [UNIFIED_CAPTURE] Code: \(errorCode)")
        Logger.shared.log("🔍 [UNIFIED_CAPTURE] Description: \(errorDescription)")
        Logger.shared.log("🔍 [UNIFIED_CAPTURE] UserInfo: \(nsError.userInfo)")
        
        // Diagnostic spécifique pour -3821
        if errorCode == -3821 {
            Logger.shared.log("🔍 [UNIFIED_CAPTURE] === DIAGNOSTIC -3821: DIFFUSION ARRÊTÉE PAR LE SYSTÈME ===")
            
            // Vérifier l'état du système
            checkSystemState()
            
            // Vérifier les permissions
            checkPermissions()
            
            // Vérifier les ressources
            checkSystemResources()
            
            // Vérifier les changements de configuration
            checkDisplayConfiguration()
            
            // Vérifier les autres apps utilisant ScreenCaptureKit
            checkCompetingApps()
        }
    }
    
    /// Vérifie l'état général du système
    private func checkSystemState() {
        Logger.shared.log("🔍 [SYSTEM_CHECK] Checking system state...")
        
        // Vérifier la mémoire disponible
        var memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &memoryInfo) { memoryInfoPtr in
            withUnsafeMutablePointer(to: &count) { countPtr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), 
                         UnsafeMutablePointer<integer_t>(OpaquePointer(memoryInfoPtr)), countPtr)
            }
        }
        
        if result == KERN_SUCCESS {
            let memoryMB = memoryInfo.resident_size / (1024 * 1024)
            Logger.shared.log("🔍 [SYSTEM_CHECK] App memory usage: \(memoryMB) MB")
        }
        
        // Vérifier les processus système
        let processInfo = ProcessInfo.processInfo
        Logger.shared.log("🔍 [SYSTEM_CHECK] System uptime: \(processInfo.systemUptime)s")
        Logger.shared.log("🔍 [SYSTEM_CHECK] Thermal state: \(processInfo.thermalState.rawValue)")
    }
    
    /// Vérifie les permissions de capture
    private func checkPermissions() {
        Logger.shared.log("🔍 [PERMISSIONS_CHECK] Checking capture permissions...")
        
        Task {
            do {
                // Vérifier les permissions d'enregistrement d'écran
                let content = try await SCShareableContent.current
                Logger.shared.log("🔍 [PERMISSIONS_CHECK] Available displays: \(content.displays.count)")
                Logger.shared.log("🔍 [PERMISSIONS_CHECK] Available applications: \(content.applications.count)")
                Logger.shared.log("🔍 [PERMISSIONS_CHECK] Available windows: \(content.windows.count)")
                
                // Vérifier les permissions microphone
                let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
                Logger.shared.log("🔍 [PERMISSIONS_CHECK] Microphone permission: \(micStatus.rawValue)")
                
                // Vérifier si on peut accéder au microphone par défaut
                if let defaultMic = AVCaptureDevice.default(for: .audio) {
                    Logger.shared.log("🔍 [PERMISSIONS_CHECK] Default microphone: \(defaultMic.localizedName)")
                    Logger.shared.log("🔍 [PERMISSIONS_CHECK] Microphone connected: \(defaultMic.isConnected)")
                } else {
                    Logger.shared.log("🔍 [PERMISSIONS_CHECK] ⚠️ No default microphone available")
                }
                
            } catch {
                Logger.shared.log("🔍 [PERMISSIONS_CHECK] ❌ Error checking permissions: \(error)")
            }
        }
    }
    
    /// Vérifie les ressources système
    private func checkSystemResources() {
        Logger.shared.log("🔍 [RESOURCES_CHECK] Checking system resources...")
        
        // Vérifier l'espace disque
        if let outputURL = outputURL {
            do {
                let resourceValues = try outputURL.resourceValues(forKeys: [.volumeAvailableCapacityKey])
                if let availableCapacity = resourceValues.volumeAvailableCapacity {
                    let availableGB = availableCapacity / (1024 * 1024 * 1024)
                    Logger.shared.log("🔍 [RESOURCES_CHECK] Available disk space: \(availableGB) GB")
                }
            } catch {
                Logger.shared.log("🔍 [RESOURCES_CHECK] ❌ Error checking disk space: \(error)")
            }
        }
        
        // Vérifier la charge CPU
        var cpuInfo: processor_info_array_t!
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCpus, &cpuInfo, &numCpuInfo)
        if result == KERN_SUCCESS {
            Logger.shared.log("🔍 [RESOURCES_CHECK] CPU cores: \(numCpus)")
        }
    }
    
    /// Vérifie les changements de configuration d'écran
    private func checkDisplayConfiguration() {
        Logger.shared.log("🔍 [DISPLAY_CHECK] Checking display configuration...")
        
        Task {
            do {
                let content = try await SCShareableContent.current
                for (index, display) in content.displays.enumerated() {
                    Logger.shared.log("🔍 [DISPLAY_CHECK] Display \(index): \(display.width)x\(display.height)")
                    Logger.shared.log("🔍 [DISPLAY_CHECK] Display \(index) frame: \(display.frame)")
                }
                
                // Comparer avec la configuration sauvegardée
                if let lastConfig = lastStreamConfiguration {
                    Logger.shared.log("🔍 [DISPLAY_CHECK] Last config: \(lastConfig.width)x\(lastConfig.height)")
                    
                    if let currentDisplay = content.displays.first {
                        if currentDisplay.width != lastConfig.width || currentDisplay.height != lastConfig.height {
                            Logger.shared.log("🔍 [DISPLAY_CHECK] ⚠️ DISPLAY RESOLUTION CHANGED!")
                            Logger.shared.log("🔍 [DISPLAY_CHECK] Previous: \(lastConfig.width)x\(lastConfig.height)")
                            Logger.shared.log("🔍 [DISPLAY_CHECK] Current: \(currentDisplay.width)x\(currentDisplay.height)")
                        }
                    }
                }
                
            } catch {
                Logger.shared.log("🔍 [DISPLAY_CHECK] ❌ Error checking display config: \(error)")
            }
        }
    }
    
    /// Vérifie les applications concurrentes utilisant ScreenCaptureKit
    private func checkCompetingApps() {
        Logger.shared.log("🔍 [COMPETING_APPS] Checking for competing applications...")
        
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        
        // Applications connues pour utiliser ScreenCaptureKit
        let screenCapturingApps = [
            "com.apple.QuickTimePlayerX",
            "com.apple.screencapture",
            "us.zoom.xos",
            "com.microsoft.teams2",
            "com.skype.skype",
            "com.google.Chrome",
            "org.mozilla.firefox",
            "com.apple.Safari"
        ]
        
        var competitorsFound: [String] = []
        var videoConferencingApps: [String] = []
        
        for app in runningApps {
            if let bundleId = app.bundleIdentifier {
                if screenCapturingApps.contains(bundleId) {
                    competitorsFound.append(app.localizedName ?? bundleId)
                }
                
                // Vérifier les apps de visioconférence spécifiquement
                if bundleId.contains("zoom") || bundleId.contains("teams") || bundleId.contains("meet") {
                    videoConferencingApps.append(app.localizedName ?? bundleId)
                }
            }
        }
        
        // Log résumé au lieu de chaque app individuellement
        if !competitorsFound.isEmpty {
            Logger.shared.log("🔍 [COMPETING_APPS] Potential competitors: \(competitorsFound.joined(separator: ", "))")
        }
        
        if !videoConferencingApps.isEmpty {
            Logger.shared.log("🔍 [COMPETING_APPS] ⚠️ Video conferencing apps: \(videoConferencingApps.joined(separator: ", "))")
        }
        
        if competitorsFound.isEmpty && videoConferencingApps.isEmpty {
            Logger.shared.log("🔍 [COMPETING_APPS] No known competitors detected")
        }
    }
    
    /// Détermine si l'erreur peut être récupérée automatiquement
    private func isErrorRecoverable(_ error: Error) -> Bool {
        let nsError = error as NSError
        let errorCode = nsError.code
        
        // D'abord analyser l'erreur en détail
        analyzeStreamError(error)
        
        // Erreurs récupérables connues
        switch errorCode {
        case -3821: // "Diffusion arrêtée par le système"
            Logger.shared.log("💡 [UNIFIED_CAPTURE] Error -3821 is potentially recoverable (system stopped stream)")
            return true
        case -3812: // Paramètre invalide (peut être temporaire)
            Logger.shared.log("💡 [UNIFIED_CAPTURE] Error -3812 might be recoverable (invalid parameter)")
            return true
        case -3801: // Stream configuration error (peut être temporaire)
            Logger.shared.log("💡 [UNIFIED_CAPTURE] Error -3801 might be recoverable (configuration error)")
            return true
        default:
            Logger.shared.log("⚠️ [UNIFIED_CAPTURE] Error \(errorCode) is not in recoverable list")
            return false
        }
    }
    
    /// Tente une récupération automatique
    private func attemptRecovery() {
        isRecovering = true
        retryCount += 1
        
        // Notifier l'application
        onRecoveryAttempt?(retryCount)
        
        Task {
            do {
                // Attendre avant de retry
                Logger.shared.log("⏳ [UNIFIED_CAPTURE] Waiting \(retryDelay)s before retry...")
                try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                
                // Nettoyer l'ancien stream
                await cleanupStream()
                
                // Tenter de redémarrer
                Logger.shared.log("🔄 [UNIFIED_CAPTURE] Attempting restart...")
                try await startDirectRecordingInternal()
                
                Logger.shared.log("✅ [UNIFIED_CAPTURE] Recovery successful!")
                retryCount = 0 // Reset counter après succès
                isRecovering = false
                onRecoverySuccess?()
                
            } catch {
                Logger.shared.log("❌ [UNIFIED_CAPTURE] Recovery attempt \(retryCount) failed: \(error)")
                isRecovering = false
                
                // Si on a atteint le max, traiter comme erreur critique
                if retryCount >= maxRetryCount {
                    handleCriticalError(error)
                } else {
                    // Sinon, le prochain didStopWithError déclenchera un autre retry
                    Logger.shared.log("🔄 [UNIFIED_CAPTURE] Will retry again if stream fails")
                }
            }
        }
    }
    
    /// Nettoie le stream actuel
    private func cleanupStream() async {
        if let stream = self.stream {
            do {
                try await stream.stopCapture()
            } catch {
                Logger.shared.log("⚠️ [UNIFIED_CAPTURE] Error stopping stream during cleanup: \(error)")
            }
        }
        
        self.stream = nil
        self.recordingOutput = nil
        recordingFinalizationWatcher?.cancel()
        recordingFinalizationWatcher = nil
        recordingFinishedContinuation = nil
        isRecording = false
    }
    
    /// Gère les erreurs critiques non récupérables
    private func handleCriticalError(_ error: Error) {
        isRecording = false
        isRecovering = false
        retryCount = 0
        
        // Nettoyer
        Task {
            await cleanupStream()
        }
        
        // Notifier l'application
        onCriticalError?(error)
    }
}

// MARK: - SCRecordingOutputDelegate
@available(macOS 15.0, *)
extension UnifiedScreenCapture: SCRecordingOutputDelegate {
    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        Logger.shared.log("❌ [UNIFIED_CAPTURE] Recording output failed: \(error)")
        isRecording = false
    }
    
    func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        Logger.shared.log("✅ [UNIFIED_CAPTURE] Recording output finished successfully - file is now ready")
        
        recordingFinalizationWatcher?.cancel()
        recordingFinalizationWatcher = nil
        
        // Signaler que le fichier est complètement écrit sur le disque
        if let continuation = recordingFinishedContinuation {
            recordingFinishedContinuation = nil
            continuation.resume()
        }
    }
}

// MARK: - SCStreamOutput (pour gestion manuelle si nécessaire)
@available(macOS 15.0, *)
extension UnifiedScreenCapture: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        switch type {
        case .screen:
            handleScreenSample(sampleBuffer)
        case .audio:
            handleSystemAudioSample(sampleBuffer)
        case .microphone:
            handleMicrophoneSample(sampleBuffer)
        @unknown default:
            Logger.shared.log("⚠️ [UNIFIED_CAPTURE] Unknown sample type received")
        }
    }
    
    private func handleScreenSample(_ sampleBuffer: CMSampleBuffer) {
        // Mettre à jour les statistiques de santé
        updateSampleStats()
        
        // On ignore les samples vidéo pour économiser les ressources
        // L'enregistrement est configuré pour produire une vidéo minimale
    }
    
    private func handleSystemAudioSample(_ sampleBuffer: CMSampleBuffer) {
        // Mettre à jour les statistiques de santé
        updateSampleStats()
        
        // Log seulement occasionnellement pour éviter le spam
        if sampleCount % 100 == 0 {
            Logger.shared.log("🔊 [UNIFIED_CAPTURE] System audio active (\(sampleCount) samples)")
        }
    }
    
    private func handleMicrophoneSample(_ sampleBuffer: CMSampleBuffer) {
        // Mettre à jour les statistiques de santé
        updateSampleStats()
        
        // Log seulement occasionnellement pour éviter le spam
        if sampleCount % 100 == 0 {
            Logger.shared.log("🎤 [UNIFIED_CAPTURE] Microphone active (\(sampleCount) samples)")
        }
    }
    
    /// Met à jour les statistiques de samples pour la surveillance de santé
    private func updateSampleStats() {
        lastSampleTime = Date()
        sampleCount += 1
    }
}
