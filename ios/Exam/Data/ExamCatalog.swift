import Foundation

enum ExamCategory: Hashable {
    case university
    case school
    case language
    case professional
    case international
}

enum SchedulePolicy: Hashable {
    case officialDates
    case multipleSessions
    case userSelected
    case schoolDefined
}

struct ExamDefinition: Identifiable, Hashable {
    let id: String
    let countryCode: String?
    let shortName: String
    let title: String
    let category: ExamCategory
    let syllabusPackId: String
    let schedulePolicy: SchedulePolicy
    let international: Bool
}

struct CountryDefinition: Identifiable, Hashable {
    var id: String { code }
    let code: String
    let name: String
    let flag: String
    let examIds: [String]
}

extension CountryDefinition {
    /// The country name in the app language, falling back to the catalogue name.
    var localizedName: String {
        Locale(identifier: ExamCatalog.languageCode).localizedString(forRegionCode: code) ?? name
    }
}

struct StudySetup: Hashable {
    let country: CountryDefinition
    let exam: ExamDefinition
    let languageCode: String
    let goalKey: String
    let dailyMinutes: Int
    let diagnosticPercent: Int

    init(
        country: CountryDefinition,
        exam: ExamDefinition,
        languageCode: String,
        goalKey: String = "improve",
        dailyMinutes: Int = 20,
        diagnosticPercent: Int = 50
    ) {
        self.country = country
        self.exam = exam
        self.languageCode = languageCode
        self.goalKey = goalKey
        self.dailyMinutes = dailyMinutes
        self.diagnosticPercent = diagnosticPercent
    }
}

enum ExamCatalog {
    private static let allExams: [ExamDefinition] = [
        .init(id: "tr_yks", countryCode: "TR", shortName: "YKS", title: "University Entrance Exam", category: .university, syllabusPackId: "tr.yks.v1", schedulePolicy: .officialDates, international: false),
        .init(id: "tr_lgs", countryCode: "TR", shortName: "LGS", title: "High School Entrance Exam", category: .school, syllabusPackId: "tr.lgs.v1", schedulePolicy: .officialDates, international: false),
        .init(id: "tr_kpss", countryCode: "TR", shortName: "KPSS", title: "Public Personnel Selection", category: .professional, syllabusPackId: "tr.kpss.v1", schedulePolicy: .officialDates, international: false),
        .init(id: "tr_ales", countryCode: "TR", shortName: "ALES", title: "Academic Personnel & Graduate Education", category: .professional, syllabusPackId: "tr.ales.v1", schedulePolicy: .multipleSessions, international: false),
        .init(id: "tr_dgs", countryCode: "TR", shortName: "DGS", title: "Vertical Transfer Exam", category: .university, syllabusPackId: "tr.dgs.v1", schedulePolicy: .officialDates, international: false),

        .init(id: "us_sat", countryCode: "US", shortName: "SAT", title: "College Admission Test", category: .university, syllabusPackId: "us.sat.v1", schedulePolicy: .multipleSessions, international: false),
        .init(id: "us_act", countryCode: "US", shortName: "ACT", title: "College Admission Test", category: .university, syllabusPackId: "us.act.v1", schedulePolicy: .multipleSessions, international: false),
        .init(id: "us_ap", countryCode: "US", shortName: "AP", title: "Advanced Placement", category: .school, syllabusPackId: "us.ap.v1", schedulePolicy: .officialDates, international: false),

        .init(id: "gb_gcse", countryCode: "GB", shortName: "GCSE", title: "General Certificate of Secondary Education", category: .school, syllabusPackId: "gb.gcse.v1", schedulePolicy: .officialDates, international: false),
        .init(id: "gb_alevel", countryCode: "GB", shortName: "A Level", title: "Advanced Level", category: .school, syllabusPackId: "gb.alevel.v1", schedulePolicy: .officialDates, international: false),

        .init(id: "in_jee_main", countryCode: "IN", shortName: "JEE Main", title: "Engineering Entrance", category: .university, syllabusPackId: "in.jee-main.v1", schedulePolicy: .multipleSessions, international: false),
        .init(id: "in_neet_ug", countryCode: "IN", shortName: "NEET UG", title: "Medical Entrance", category: .university, syllabusPackId: "in.neet-ug.v1", schedulePolicy: .officialDates, international: false),
        .init(id: "in_cuet_ug", countryCode: "IN", shortName: "CUET UG", title: "Common University Entrance", category: .university, syllabusPackId: "in.cuet-ug.v1", schedulePolicy: .officialDates, international: false),

        .init(id: "br_enem", countryCode: "BR", shortName: "ENEM", title: "National High School Exam", category: .university, syllabusPackId: "br.enem.v1", schedulePolicy: .officialDates, international: false),
        .init(id: "kr_csat", countryCode: "KR", shortName: "CSAT", title: "College Scholastic Ability Test", category: .university, syllabusPackId: "kr.csat.v1", schedulePolicy: .officialDates, international: false),
        .init(id: "de_abitur", countryCode: "DE", shortName: "Abitur", title: "Higher Education Entrance Qualification", category: .school, syllabusPackId: "de.abitur.v1", schedulePolicy: .schoolDefined, international: false),
        .init(id: "es_pau", countryCode: "ES", shortName: "PAU", title: "University Access Exam", category: .university, syllabusPackId: "es.pau.v1", schedulePolicy: .officialDates, international: false),
        .init(id: "fr_bac", countryCode: "FR", shortName: "Baccalauréat", title: "French Baccalaureate", category: .school, syllabusPackId: "fr.bac.v1", schedulePolicy: .officialDates, international: false),
        .init(id: "jp_common_test", countryCode: "JP", shortName: "Common Test", title: "Common Test for University Admissions", category: .university, syllabusPackId: "jp.common-test.v1", schedulePolicy: .officialDates, international: false),

        .init(id: "intl_ielts", countryCode: nil, shortName: "IELTS", title: "International English Language Testing System", category: .language, syllabusPackId: "intl.ielts.v1", schedulePolicy: .multipleSessions, international: true),
        .init(id: "intl_toefl", countryCode: nil, shortName: "TOEFL", title: "Test of English as a Foreign Language", category: .language, syllabusPackId: "intl.toefl.v1", schedulePolicy: .multipleSessions, international: true),
        .init(id: "intl_cambridge", countryCode: nil, shortName: "Cambridge", title: "Cambridge English Qualifications", category: .language, syllabusPackId: "intl.cambridge.v1", schedulePolicy: .multipleSessions, international: true),
        .init(id: "intl_ib", countryCode: nil, shortName: "IB", title: "International Baccalaureate Diploma", category: .international, syllabusPackId: "intl.ib.v1", schedulePolicy: .officialDates, international: true),
        .init(id: "intl_igcse", countryCode: nil, shortName: "IGCSE", title: "International GCSE", category: .international, syllabusPackId: "intl.igcse.v1", schedulePolicy: .officialDates, international: true),
        .init(id: "intl_sat", countryCode: nil, shortName: "SAT", title: "International SAT", category: .international, syllabusPackId: "us.sat.v1", schedulePolicy: .multipleSessions, international: true)
    ]

    static let countries: [CountryDefinition] = [
        .init(code: "TR", name: "Türkiye", flag: "🇹🇷", examIds: ["tr_yks", "tr_lgs", "tr_kpss", "tr_ales", "tr_dgs"]),
        .init(code: "US", name: "United States", flag: "🇺🇸", examIds: ["us_sat", "us_act", "us_ap"]),
        .init(code: "GB", name: "United Kingdom", flag: "🇬🇧", examIds: ["gb_gcse", "gb_alevel"]),
        .init(code: "IN", name: "India", flag: "🇮🇳", examIds: ["in_jee_main", "in_neet_ug", "in_cuet_ug"]),
        .init(code: "BR", name: "Brazil", flag: "🇧🇷", examIds: ["br_enem"]),
        .init(code: "KR", name: "South Korea", flag: "🇰🇷", examIds: ["kr_csat"]),
        .init(code: "DE", name: "Germany", flag: "🇩🇪", examIds: ["de_abitur"]),
        .init(code: "ES", name: "Spain", flag: "🇪🇸", examIds: ["es_pau"]),
        .init(code: "FR", name: "France", flag: "🇫🇷", examIds: ["fr_bac"]),
        .init(code: "JP", name: "Japan", flag: "🇯🇵", examIds: ["jp_common_test"]),
        .init(code: "OTHER", name: "Other country", flag: "🌍", examIds: [])
    ]

    static var suggestedCountryIndex: Int {
        let code = Locale.current.region?.identifier ?? "OTHER"
        return countries.firstIndex(where: { $0.code == code }) ?? (countries.count - 1)
    }

    static var languageCode: String {
        AppLanguage.resolve()
    }

    static func exam(id: String) -> ExamDefinition? {
        allExams.first { $0.id == id }
    }

    static func country(code: String) -> CountryDefinition? {
        countries.first { $0.code == code }
    }

    static func exams(for country: CountryDefinition) -> [ExamDefinition] {
        let local = country.examIds.compactMap { id in allExams.first(where: { $0.id == id }) }
        let international = allExams.filter { exam in
            exam.international && !local.contains(where: { $0.syllabusPackId == exam.syllabusPackId })
        }
        return local + international
    }
}
