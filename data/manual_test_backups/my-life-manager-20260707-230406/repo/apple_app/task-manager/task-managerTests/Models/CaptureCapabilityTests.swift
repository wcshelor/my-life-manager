import Foundation
import Testing
@testable import task_manager

struct CaptureCapabilityTests {
    @Test func rawCaptureGeneratesTaskCandidate() {
        let capture = RawCapture(
            title: "Finish report",
            notes: "Send the draft",
            projectID: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174321")
        )

        let candidates = TaskCaptureCapability().captureCandidates(for: capture)

        #expect(candidates.count == 1)
        #expect(candidates.first?.moduleID == .tasks)
        #expect(candidates.first?.primaryActionTitle == "Review Task")
        #expect(candidates.first?.taskFormData?.title == "Finish report")
        #expect(candidates.first?.taskFormData?.notesText == "Send the draft")
        #expect(candidates.first?.taskFormData?.projectID == capture.projectID)
    }

    @Test func rawCaptureGeneratesShoppingCandidate() {
        let capture = RawCapture(title: "Milk", notes: "2 bottles")

        let candidates = ShoppingCaptureCapability().captureCandidates(for: capture)

        #expect(candidates.count == 1)
        #expect(candidates.first?.moduleID == .shopping)
        #expect(candidates.first?.primaryActionTitle == "Save Shopping Item")
        #expect(candidates.first?.shoppingFormData?.title == "Milk")
        #expect(candidates.first?.shoppingFormData?.notes == "2 bottles")
    }

    @Test func rawCaptureGeneratesMusicPracticeCandidate() {
        let capture = RawCapture(title: "Prelude in C", notes: "Hands separate")

        let candidates = MusicPracticeCaptureCapability().captureCandidates(for: capture)

        #expect(candidates.count == 1)
        #expect(candidates.first?.moduleID == .musicPractice)
        #expect(candidates.first?.primaryActionTitle == "Save Practice Piece")
        #expect(candidates.first?.practicePiece?.title == "Prelude in C")
        #expect(candidates.first?.practicePiece?.notes == "Hands separate")
    }

    @Test func taskFormDataNormalizesDateOnlyDueDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let dueDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 14, minute: 30))!
        let formData = MyTaskFormData(title: "Read", hasDueDate: true, dueDate: dueDate)

        #expect(formData.normalizedDueDate(keepingExactTime: false, calendar: calendar) == calendar.startOfDay(for: dueDate))
    }

    @Test func taskFormDataPreservesExactTimeWhenEnabled() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let dueDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 14, minute: 30))!
        let formData = MyTaskFormData(title: "Read", hasDueDate: true, dueDate: dueDate)

        #expect(formData.normalizedDueDate(keepingExactTime: true, calendar: calendar) == dueDate)
    }
}

