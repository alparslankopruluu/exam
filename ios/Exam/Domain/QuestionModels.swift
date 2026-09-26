import Foundation

struct StudyQuestion: Identifiable, Hashable {
    let id: String
    let topic: String
    let prompt: String
    let options: [String]
    let correctIndex: Int
    let explanation: String
}

enum SampleQuestionFactory {
    static func questions(for setup: StudySetup) -> [StudyQuestion] {
        switch setup.exam.id {
        case "intl_ielts":
            [
                StudyQuestion(
                    id: "ielts_grammar_1",
                    topic: "Grammar",
                    prompt: "Choose the sentence that is grammatically correct.",
                    options: [
                        "She have lived here for five years.",
                        "She has lived here for five years.",
                        "She is live here since five years.",
                        "She lived here since five years."
                    ],
                    correctIndex: 1,
                    explanation: "Present perfect uses has/have + past participle for a state that began in the past and continues now."
                ),
                StudyQuestion(
                    id: "ielts_vocab_1",
                    topic: "Vocabulary",
                    prompt: "Which word best completes the sentence? The results were _____ with the original hypothesis.",
                    options: ["consistent", "temporary", "remote", "casual"],
                    correctIndex: 0,
                    explanation: "Consistent with means compatible with or in agreement with something."
                )
            ]

        case "us_sat", "intl_sat":
            [
                StudyQuestion(
                    id: "sat_math_1",
                    topic: "Algebra",
                    prompt: "If 3x + 5 = 20, what is the value of x?",
                    options: ["3", "5", "7", "15"],
                    correctIndex: 1,
                    explanation: "Subtract 5 from both sides to get 3x = 15, then divide by 3."
                ),
                StudyQuestion(
                    id: "sat_rw_1",
                    topic: "Standard English Conventions",
                    prompt: "Choose the option that completes the sentence most logically: The researchers repeated the trial; _____, the result remained unchanged.",
                    options: ["however", "therefore", "for example", "meanwhile"],
                    correctIndex: 0,
                    explanation: "However signals contrast between repeating the trial and obtaining the same result."
                )
            ]

        case "tr_yks":
            [
                StudyQuestion(
                    id: "yks_math_1",
                    topic: "Matematik",
                    prompt: "2x + 6 = 18 olduğuna göre x kaçtır?",
                    options: ["4", "5", "6", "7"],
                    correctIndex: 2,
                    explanation: "Her iki taraftan 6 çıkarılır: 2x = 12. İkiye bölünür ve x = 6 bulunur."
                ),
                StudyQuestion(
                    id: "yks_math_2",
                    topic: "Temel Matematik",
                    prompt: "Bir sayının %25'i 20 ise sayının tamamı kaçtır?",
                    options: ["40", "60", "80", "100"],
                    correctIndex: 2,
                    explanation: "%25 dörtte birdir. 20 × 4 = 80."
                )
            ]

        default:
            [
                StudyQuestion(
                    id: "general_1",
                    topic: setup.exam.shortName,
                    prompt: "If 4x = 28, what is x?",
                    options: ["5", "6", "7", "8"],
                    correctIndex: 2,
                    explanation: "Divide both sides by 4: x = 7."
                ),
                StudyQuestion(
                    id: "general_2",
                    topic: "Reasoning",
                    prompt: "Which value is equivalent to 3/4?",
                    options: ["0.25", "0.5", "0.75", "1.25"],
                    correctIndex: 2,
                    explanation: "3 divided by 4 equals 0.75."
                )
            ]
        }
    }
}
