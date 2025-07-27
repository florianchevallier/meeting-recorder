import Cocoa

/// Générateur d'icône optimisée pour la status bar
struct StatusBarIconGenerator {
    
    /// Crée une icône optimisée pour la status bar (18x18 pixels)
    static func createStatusBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Fond transparent
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Couleur principale (gris foncé pour s'adapter au thème système)
        let primaryColor = NSColor.labelColor
        
        // Dessiner un rectangle arrondi pour représenter un écran/fenêtre de meeting
        let screenRect = NSRect(x: 2, y: 4, width: 14, height: 10)
        let screenPath = NSBezierPath(roundedRect: screenRect, xRadius: 2, yRadius: 2)
        primaryColor.setStroke()
        screenPath.lineWidth = 1.5
        screenPath.stroke()
        
        // Dessiner des points pour représenter les participants
        let dotColor = NSColor.labelColor
        dotColor.setFill()
        
        // Participant principal (plus gros)
        let mainParticipant = NSBezierPath(ovalIn: NSRect(x: 7, y: 6, width: 4, height: 4))
        mainParticipant.fill()
        
        // Participants secondaires (plus petits)
        let participant1 = NSBezierPath(ovalIn: NSRect(x: 4, y: 7, width: 2, height: 2))
        participant1.fill()
        
        let participant2 = NSBezierPath(ovalIn: NSRect(x: 12, y: 7, width: 2, height: 2))
        participant2.fill()
        
        // Point rouge pour indiquer l'enregistrement (optionnel, activé via état)
        // Sera ajouté dynamiquement selon l'état de l'application
        
        image.unlockFocus()
        
        // Configurer l'image comme template pour s'adapter au thème système
        image.isTemplate = true
        
        return image
    }
    
    /// Crée une icône d'enregistrement avec un point rouge
    static func createRecordingIcon() -> NSImage {
        let baseIcon = createStatusBarIcon()
        let size = NSSize(width: 18, height: 18)
        let recordingIcon = NSImage(size: size)
        
        recordingIcon.lockFocus()
        
        // Dessiner l'icône de base
        baseIcon.draw(in: NSRect(origin: .zero, size: size))
        
        // Ajouter un point rouge pour l'enregistrement
        let redColor = NSColor.systemRed
        redColor.setFill()
        let recordingDot = NSBezierPath(ovalIn: NSRect(x: 13, y: 12, width: 4, height: 4))
        recordingDot.fill()
        
        recordingIcon.unlockFocus()
        
        // Ne pas faire template pour garder la couleur rouge
        recordingIcon.isTemplate = false
        
        return recordingIcon
    }
    
    /// Crée une icône avec indicateur Teams détecté
    static func createTeamsDetectedIcon() -> NSImage {
        let baseIcon = createStatusBarIcon()
        let size = NSSize(width: 18, height: 18)
        let teamsIcon = NSImage(size: size)
        
        teamsIcon.lockFocus()
        
        // Dessiner l'icône de base
        baseIcon.draw(in: NSRect(origin: .zero, size: size))
        
        // Ajouter un point bleu pour Teams détecté
        let blueColor = NSColor.systemBlue
        blueColor.setFill()
        let teamsDot = NSBezierPath(ovalIn: NSRect(x: 13, y: 12, width: 4, height: 4))
        teamsDot.fill()
        
        teamsIcon.unlockFocus()
        
        // Ne pas faire template pour garder la couleur bleue
        teamsIcon.isTemplate = false
        
        return teamsIcon
    }
}