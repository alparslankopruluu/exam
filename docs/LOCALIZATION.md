# Localization

Country, exam and UI language are independent.

Examples:
- Türkiye + English UI + IELTS
- Germany + Turkish UI + Abitur
- India + English UI + JEE Main

Device language is a suggestion. Users will be able to override it in Profile.

## Shared locale assets

The seed locale dictionaries live in `content/locales/` and are bundled into both native apps.

Initial UI locales:
- English
- Turkish
- German
- Spanish
- French
- Portuguese
- Korean
- Japanese
- Hindi

English is always the fallback.

Exam terminology may override generic UI wording inside a content pack when an official local term is required.

## Rules

- Never infer exam choice from language.
- Never infer language from country after the user overrides it.
- Store prices always come from App Store / Google Play localization.
- Dates, decimals and percentages use the platform locale.
- AI Tutor answers in the user's selected UI / tutoring language unless the learning task itself targets another language.
- Language-learning exercises preserve target-language content while navigation and coaching remain localized.
