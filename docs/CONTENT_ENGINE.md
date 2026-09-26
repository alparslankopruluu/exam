# Exam Content Engine

The app must not treat exam preparation as a generic question generator with a different title.

Each exam resolves to a versioned content pack. A pack owns:

- section/session structure
- curriculum / domain taxonomy
- scoring model
- timing
- question types
- mock-exam blueprint
- diagnostic strategy
- localization terminology
- verified source metadata
- review date

## Runtime resolution

```
country + selectedExam
        ↓
ExamDefinition.syllabusPackId
        ↓
RemoteContentRepository
        ↓
cached verified pack
        ↓
Diagnostic / Practice / Mock / Tutor context
```

Native bundles contain safe seed packs. Remote packs can supersede them only when schema validation passes.

## Question generation pipeline

```
Blueprint
  → Retrieve topic constraints
  → Generate candidate
  → Solve independently
  → Verify answer / rubric
  → Check difficulty
  → Check exam-style constraints
  → Publish
```

Generated questions need provenance metadata and a quality state. High-stakes claims should not be invented by the model.

## Personal Knowledge Graph

Mastery is stored per canonical skill ID rather than screen name:

```
skillId
masteryEstimate
attemptCount
correctRate
medianResponseTime
lastSeenAt
nextReviewAt
errorPatterns[]
```

This lets Daily Plan, Mistake Review, Tutor, and Mock Analysis share one learner state.

## Source policy

Official exam authorities are the primary source of truth for structure and rule changes. Each pack records its sources and `reviewedAt` date.
