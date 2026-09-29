package com.kprl.exam.data

import java.util.Locale

enum class ExamCategory { UNIVERSITY, SCHOOL, LANGUAGE, PROFESSIONAL, INTERNATIONAL }

enum class SchedulePolicy { OFFICIAL_DATES, MULTIPLE_SESSIONS, USER_SELECTED, SCHOOL_DEFINED }

data class ExamDefinition(
    val id: String,
    val countryCode: String?,
    val shortName: String,
    val title: String,
    val category: ExamCategory,
    val syllabusPackId: String,
    val schedulePolicy: SchedulePolicy,
    val international: Boolean = false
)

data class CountryDefinition(
    val code: String,
    val name: String,
    val flag: String,
    val examIds: List<String>
)

data class StudySetup(
    val country: CountryDefinition,
    val exam: ExamDefinition,
    val languageCode: String,
    val goalKey: String = "improve",
    val dailyMinutes: Int = 20,
    val diagnosticPercent: Int = 50
)

object ExamCatalog {
    private val exams = listOf(
        ExamDefinition("tr_yks", "TR", "YKS", "University Entrance Exam", ExamCategory.UNIVERSITY, "tr.yks.v1", SchedulePolicy.OFFICIAL_DATES),
        ExamDefinition("tr_lgs", "TR", "LGS", "High School Entrance Exam", ExamCategory.SCHOOL, "tr.lgs.v1", SchedulePolicy.OFFICIAL_DATES),
        ExamDefinition("tr_kpss", "TR", "KPSS", "Public Personnel Selection", ExamCategory.PROFESSIONAL, "tr.kpss.v1", SchedulePolicy.OFFICIAL_DATES),
        ExamDefinition("tr_ales", "TR", "ALES", "Academic Personnel & Graduate Education", ExamCategory.PROFESSIONAL, "tr.ales.v1", SchedulePolicy.MULTIPLE_SESSIONS),
        ExamDefinition("tr_dgs", "TR", "DGS", "Vertical Transfer Exam", ExamCategory.UNIVERSITY, "tr.dgs.v1", SchedulePolicy.OFFICIAL_DATES),

        ExamDefinition("us_sat", "US", "SAT", "College Admission Test", ExamCategory.UNIVERSITY, "us.sat.v1", SchedulePolicy.MULTIPLE_SESSIONS),
        ExamDefinition("us_act", "US", "ACT", "College Admission Test", ExamCategory.UNIVERSITY, "us.act.v1", SchedulePolicy.MULTIPLE_SESSIONS),
        ExamDefinition("us_ap", "US", "AP", "Advanced Placement", ExamCategory.SCHOOL, "us.ap.v1", SchedulePolicy.OFFICIAL_DATES),

        ExamDefinition("gb_gcse", "GB", "GCSE", "General Certificate of Secondary Education", ExamCategory.SCHOOL, "gb.gcse.v1", SchedulePolicy.OFFICIAL_DATES),
        ExamDefinition("gb_alevel", "GB", "A Level", "Advanced Level", ExamCategory.SCHOOL, "gb.alevel.v1", SchedulePolicy.OFFICIAL_DATES),

        ExamDefinition("in_jee_main", "IN", "JEE Main", "Engineering Entrance", ExamCategory.UNIVERSITY, "in.jee-main.v1", SchedulePolicy.MULTIPLE_SESSIONS),
        ExamDefinition("in_neet_ug", "IN", "NEET UG", "Medical Entrance", ExamCategory.UNIVERSITY, "in.neet-ug.v1", SchedulePolicy.OFFICIAL_DATES),
        ExamDefinition("in_cuet_ug", "IN", "CUET UG", "Common University Entrance", ExamCategory.UNIVERSITY, "in.cuet-ug.v1", SchedulePolicy.OFFICIAL_DATES),

        ExamDefinition("br_enem", "BR", "ENEM", "National High School Exam", ExamCategory.UNIVERSITY, "br.enem.v1", SchedulePolicy.OFFICIAL_DATES),
        ExamDefinition("kr_csat", "KR", "CSAT", "College Scholastic Ability Test", ExamCategory.UNIVERSITY, "kr.csat.v1", SchedulePolicy.OFFICIAL_DATES),
        ExamDefinition("de_abitur", "DE", "Abitur", "Higher Education Entrance Qualification", ExamCategory.SCHOOL, "de.abitur.v1", SchedulePolicy.SCHOOL_DEFINED),
        ExamDefinition("es_pau", "ES", "PAU", "University Access Exam", ExamCategory.UNIVERSITY, "es.pau.v1", SchedulePolicy.OFFICIAL_DATES),
        ExamDefinition("fr_bac", "FR", "Baccalauréat", "French Baccalaureate", ExamCategory.SCHOOL, "fr.bac.v1", SchedulePolicy.OFFICIAL_DATES),
        ExamDefinition("jp_common_test", "JP", "Common Test", "Common Test for University Admissions", ExamCategory.UNIVERSITY, "jp.common-test.v1", SchedulePolicy.OFFICIAL_DATES),

        ExamDefinition("intl_ielts", null, "IELTS", "International English Language Testing System", ExamCategory.LANGUAGE, "intl.ielts.v1", SchedulePolicy.MULTIPLE_SESSIONS, true),
        ExamDefinition("intl_toefl", null, "TOEFL", "Test of English as a Foreign Language", ExamCategory.LANGUAGE, "intl.toefl.v1", SchedulePolicy.MULTIPLE_SESSIONS, true),
        ExamDefinition("intl_cambridge", null, "Cambridge", "Cambridge English Qualifications", ExamCategory.LANGUAGE, "intl.cambridge.v1", SchedulePolicy.MULTIPLE_SESSIONS, true),
        ExamDefinition("intl_ib", null, "IB", "International Baccalaureate Diploma", ExamCategory.INTERNATIONAL, "intl.ib.v1", SchedulePolicy.OFFICIAL_DATES, true),
        ExamDefinition("intl_igcse", null, "IGCSE", "International GCSE", ExamCategory.INTERNATIONAL, "intl.igcse.v1", SchedulePolicy.OFFICIAL_DATES, true),
        ExamDefinition("intl_sat", null, "SAT", "International SAT", ExamCategory.INTERNATIONAL, "us.sat.v1", SchedulePolicy.MULTIPLE_SESSIONS, true)
    )

    val countries = listOf(
        CountryDefinition("TR", "Türkiye", "🇹🇷", listOf("tr_yks", "tr_lgs", "tr_kpss", "tr_ales", "tr_dgs")),
        CountryDefinition("US", "United States", "🇺🇸", listOf("us_sat", "us_act", "us_ap")),
        CountryDefinition("GB", "United Kingdom", "🇬🇧", listOf("gb_gcse", "gb_alevel")),
        CountryDefinition("IN", "India", "🇮🇳", listOf("in_jee_main", "in_neet_ug", "in_cuet_ug")),
        CountryDefinition("BR", "Brazil", "🇧🇷", listOf("br_enem")),
        CountryDefinition("KR", "South Korea", "🇰🇷", listOf("kr_csat")),
        CountryDefinition("DE", "Germany", "🇩🇪", listOf("de_abitur")),
        CountryDefinition("ES", "Spain", "🇪🇸", listOf("es_pau")),
        CountryDefinition("FR", "France", "🇫🇷", listOf("fr_bac")),
        CountryDefinition("JP", "Japan", "🇯🇵", listOf("jp_common_test")),
        CountryDefinition("OTHER", "Other country", "🌍", emptyList())
    )

    private val internationalExams = exams.filter { it.international }

    fun suggestedCountryIndex(): Int {
        val code = Locale.getDefault().country.uppercase()
        return countries.indexOfFirst { it.code == code }.takeIf { it >= 0 } ?: countries.lastIndex
    }

    fun examsFor(country: CountryDefinition): List<ExamDefinition> {
        val local = country.examIds.mapNotNull { id -> exams.firstOrNull { it.id == id } }
        val global = internationalExams.filterNot { international ->
            local.any { localExam -> localExam.syllabusPackId == international.syllabusPackId }
        }
        return local + global
    }

    fun languageCode(): String = com.kprl.exam.localization.AppLanguage.resolve()

    fun findExam(id: String): ExamDefinition? = exams.firstOrNull { it.id == id }

    fun findCountry(code: String): CountryDefinition? = countries.firstOrNull { it.code == code }
}
