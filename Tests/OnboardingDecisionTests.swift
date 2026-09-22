import Testing
@testable import MeetingRecorder

@Suite("Onboarding decision")
struct OnboardingDecisionTests {
    @Test("Already completed never presents")
    func alreadyComplete() {
        #expect(
            OnboardingCoordinator.decide(hasCompleted: true, microphone: .denied, accessibility: .denied)
                == .alreadyComplete)
    }

    @Test("Microphone and accessibility granted completes immediately")
    func complete() {
        #expect(
            OnboardingCoordinator.decide(hasCompleted: false, microphone: .granted, accessibility: .granted)
                == .complete)
    }

    @Test(
        "Any missing core permission presents",
        arguments: [
            (PermissionStatus.notDetermined, PermissionStatus.granted),
            (.granted, .notDetermined),
            (.denied, .granted),
            (.granted, .denied),
        ])
    func present(microphone: PermissionStatus, accessibility: PermissionStatus) {
        #expect(
            OnboardingCoordinator.decide(hasCompleted: false, microphone: microphone, accessibility: accessibility)
                == .present)
    }
}
