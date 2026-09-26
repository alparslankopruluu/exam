# Analytics contract

Analytics is designed around the learning loop and monetization funnel, not raw screen views.

## Funnel

```
onboarding_started
→ country_selected
→ exam_selected
→ goal_selected
→ diagnostic_started
→ diagnostic_completed
→ plan_generated
→ paywall_viewed
→ trial_started / purchase_completed / paywall_closed
→ daily_mission_started
→ daily_mission_completed
```

## Learning quality

Question-level events should include:
- exam_id
- content_pack_id
- subject_id
- topic_id
- difficulty
- answer_correct
- response_time_ms
- session_type
- premium_status

Do not send raw question text, uploaded note content, voice transcripts or personally sensitive study material as analytics parameters.

## Core product KPI

Weekly Successful Study Sessions.

Supporting:
- onboarding completion
- first-session completion
- D1 / D7 / D30 retention
- free → trial
- trial → paid
- renewal
- daily mission completion
- AI explanation → next-question continuation
- mistake review completion
- mock → follow-up review completion

The event vocabulary is shared between iOS and Android.
