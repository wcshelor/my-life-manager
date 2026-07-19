import Combine
import Foundation

@MainActor
final class PeopleMemoryViewModel: ObservableObject {
    enum OverviewFilter: String, CaseIterable, Identifiable {
        case all
        case due
        case needsCues
        case tagged
        case studyReady

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:
                return "All"
            case .due:
                return "Due"
            case .needsCues:
                return "Needs cues"
            case .tagged:
                return "Tagged"
            case .studyReady:
                return "Study ready"
            }
        }
    }

    static let starterTagNames = [
        "School",
        "Work",
        "Neighbor",
        "Conference",
        "Friend of friend",
        "Service",
        "Hobby",
    ]

    @Published private(set) var people: [PersonMemory] = []
    @Published private(set) var tags: [PersonTag] = []
    @Published var searchText = ""
    @Published var overviewFilter: OverviewFilter = .all
    @Published private(set) var studyCards: [PeopleStudyCard] = []
    @Published private(set) var studiedPersonIDs: Set<UUID> = []
    @Published private(set) var errorMessage: String?

    private let peopleMemoryRepository: any PeopleMemoryRepository
    private let calendar: Calendar
    private let nowProvider: @Sendable () -> Date
    private var hasLoaded = false

    init(
        peopleMemoryRepository: any PeopleMemoryRepository,
        calendar: Calendar = .current,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.peopleMemoryRepository = peopleMemoryRepository
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    var tagLookup: [UUID: PersonTag] {
        Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0) })
    }

    var summary: HomePeopleMemorySummary {
        HomePeopleMemorySummary(people: people, now: nowProvider())
    }

    var filteredPeople: [PersonMemory] {
        people.filter { person in
            person.matchesSearchText(searchText, tags: tags) && matchesOverviewFilter(person)
        }
    }

    var overviewFilters: [(filter: OverviewFilter, count: Int)] {
        OverviewFilter.allCases.map { filter in
            (filter, count(for: filter))
        }
    }

    var mostUsedTags: [PersonTag] {
        let counts = Dictionary(grouping: people.flatMap(\.tagIDs), by: { $0 })
            .mapValues(\.count)

        return tags.sorted { leftTag, rightTag in
            let leftCount = counts[leftTag.id] ?? 0
            let rightCount = counts[rightTag.id] ?? 0
            if leftCount != rightCount {
                return leftCount > rightCount
            }

            return leftTag.name.localizedCaseInsensitiveCompare(rightTag.name) == .orderedAscending
        }
    }

    var starterTags: [PersonTag] {
        let existingKeys = Set(tags.map(\.normalizedKey))
        return Self.starterTagNames.compactMap { name in
            guard existingKeys.contains(PersonTag.normalizedKey(for: name)) == false else {
                return nil
            }

            return PersonTag(name: name)
        }
    }

    func tags(for person: PersonMemory) -> [PersonTag] {
        person.tagIDs.compactMap { tagLookup[$0] }
    }

    func loadIfNeeded() {
        guard hasLoaded == false else {
            return
        }

        load()
    }

    func load() {
        do {
            people = try peopleMemoryRepository.fetchPeople()
            tags = try peopleMemoryRepository.fetchTags()
            errorMessage = nil
            hasLoaded = true
        } catch {
            errorMessage = "Unable to load People: \(error.localizedDescription)"
        }
    }

    func savePerson(
        _ person: PersonMemory,
        replacingPersonWithID originalID: UUID? = nil,
        selectedTagNames: [String]
    ) {
        do {
            let savedTags = try saveTags(named: selectedTagNames)
            var updatedPerson = person
            updatedPerson.tagIDs = savedTags.map(\.id)
            updatedPerson.updatedAt = nowProvider()
            try peopleMemoryRepository.savePerson(updatedPerson, replacingPersonWithID: originalID)
            load()
        } catch {
            errorMessage = "Unable to save person: \(error.localizedDescription)"
        }
    }

    func addPerson(named name: String) -> Bool {
        guard let person = PersonMemory(newName: name, createdAt: nowProvider()) else {
            return false
        }

        do {
            try peopleMemoryRepository.savePerson(person, replacingPersonWithID: nil)
            load()
            return true
        } catch {
            errorMessage = "Unable to save person: \(error.localizedDescription)"
            return false
        }
    }

    func deletePerson(withID id: UUID) {
        do {
            try peopleMemoryRepository.deletePerson(withID: id)
            load()
        } catch {
            errorMessage = "Unable to delete person: \(error.localizedDescription)"
        }
    }

    func startStudy(limit: Int = 5) {
        studiedPersonIDs = []
        studyCards = PeopleStudyQueue.cards(
            from: people,
            tags: tags,
            now: nowProvider(),
            limit: limit
        )
    }

    func applyStudyRating(_ rating: PeopleStudyRating, to personID: UUID) {
        guard let person = people.first(where: { $0.id == personID }),
              studiedPersonIDs.contains(personID) == false
        else {
            return
        }

        do {
            let reviewedAt = nowProvider()
            let updatedPerson = person.applyingStudyRating(
                rating,
                reviewedAt: reviewedAt,
                calendar: calendar
            )
            try peopleMemoryRepository.savePerson(updatedPerson, replacingPersonWithID: personID)
            studiedPersonIDs.insert(personID)
            studyCards.removeAll { $0.id == personID }
            load()
        } catch {
            errorMessage = "Unable to update study card: \(error.localizedDescription)"
        }
    }

    private func matchesOverviewFilter(_ person: PersonMemory) -> Bool {
        switch overviewFilter {
        case .all:
            return true
        case .due:
            return person.isDue(at: nowProvider())
        case .needsCues:
            return person.needsEnrichment
        case .tagged:
            return person.tagIDs.isEmpty == false
        case .studyReady:
            return person.isStudyReady
        }
    }

    private func count(for filter: OverviewFilter) -> Int {
        people.filter { person in
            switch filter {
            case .all:
                return true
            case .due:
                return person.isDue(at: nowProvider())
            case .needsCues:
                return person.needsEnrichment
            case .tagged:
                return person.tagIDs.isEmpty == false
            case .studyReady:
                return person.isStudyReady
            }
        }.count
    }

    private func saveTags(named names: [String]) throws -> [PersonTag] {
        var savedTags: [PersonTag] = []
        var seenKeys: Set<String> = []

        for name in names {
            guard let cleanedName = PersonTag.cleanedName(from: name) else {
                continue
            }

            let key = PersonTag.normalizedKey(for: cleanedName)
            guard seenKeys.insert(key).inserted else {
                continue
            }

            if let existingTag = try peopleMemoryRepository.tag(withNormalizedKey: key) {
                savedTags.append(existingTag)
                continue
            }

            let tag = PersonTag(name: cleanedName, createdAt: nowProvider())
            try peopleMemoryRepository.saveTag(tag, replacingTagWithID: nil)
            savedTags.append(tag)
        }

        return savedTags.sortedForPersonTags()
    }
}
