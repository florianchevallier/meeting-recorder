import Foundation

/// Strings of the Library window (keys in `Localizable.strings`, checked by `L10nParityTests`).
extension L10n {
    static let actionLibrary = "action.library".localized
    static let libraryWindowTitle = "library.window.title".localized
    static let librarySearchPrompt = "library.search.prompt".localized
    static let libraryEmpty = "library.empty".localized
    static let libraryNoResults = "library.no_results".localized
    static let libraryNoSelection = "library.no_selection".localized
    static let libraryTabTranscript = "library.tab.transcript".localized
    static let libraryTabLive = "library.tab.live".localized
    static let libraryTabParticipants = "library.tab.participants".localized
    static let libraryFile = "library.file".localized
    static let libraryRename = "library.rename".localized
    static let libraryRenameTitle = "library.rename.title".localized
    static let libraryRenameMessage = "library.rename.message".localized
    static let libraryRenamePlaceholder = "library.rename.placeholder".localized
    static let libraryCancel = "library.cancel".localized
    static let libraryLinkEvent = "library.link_event".localized
    static let libraryLinkEventNone = "library.link_event.none".localized
    static let libraryParticipantsEmpty = "library.participants.empty".localized
    static let libraryParticipantsHint = "library.participants.hint".localized
    static let libraryParticipantRemove = "library.participant.remove".localized
    static let libraryParticipantOrganizer = "library.participant.organizer".localized
    static let libraryParticipantMe = "library.participant.me".localized
    static let libraryParticipantAccepted = "library.participant.accepted".localized
    static let libraryParticipantTentative = "library.participant.tentative".localized
    static let libraryParticipantPending = "library.participant.pending".localized
    static func libraryErrorNameTaken(_ name: String) -> String {
        L10n.string("library.error.name_taken", name)
    }
}
