# Monetization

## Principle

Free must be useful. Premium should remove limits and deepen personalization rather than block the first learning outcome.

## Subscription

One primary Premium entitlement.

Suggested product surfaces:
- Annual: visually recommended, trial when store eligibility permits
- Monthly: no assumed trial
- Store localized price only

Do not hardcode currency, discounts, or "per month" math without deriving it from store data.

## Credits

Credits are reserved for high marginal-cost generation:
- AI video explanations
- long audio/video transcription
- premium generated visuals

Normal question solving, basic explanations and ordinary learning loops should not feel like an arcade currency system.

## Contextual paywalls

Placements are semantic:
- onboarding
- AI fair-use limit
- voice tutor
- study material limit
- mock analysis
- win-back

The paywall headline uses known context such as the selected exam and completed progress.

## Offers

A countdown is displayed only when a server-issued expiry exists. No fake urgency.

## Experiment dimensions

Remote config may safely test:
- headline
- hero illustration
- benefit order
- annual/monthly ordering
- trial copy
- offer timing
- post-value paywall placement

Entitlement semantics and billing truth are never experiment text.

## Store catalog (approved 2026-09-28)

| Product ID | Type | TR | US | Grants |
|---|---|---|---|---|
| `premium_monthly` | Auto-renewable, group "Premium" | ₺149,99 | $7.99 | premium |
| `premium_annual` | Auto-renewable, group "Premium", 7-day free trial intro | ₺899,99 | $49.99 | premium |
| `premium_annual_offer` | Auto-renewable, same group (iOS only) | ₺539,99 | $29.99 | premium |
| `ai_credits_small` | Consumable | ₺49,99 | $2.99 | 50 credits |
| `ai_credits_medium` | Consumable | ₺129,99 | $6.99 | 150 credits |
| `ai_credits_large` | Consumable | ₺349,99 | $19.99 | 500 credits |

Credit amounts are granted from `backend/functions/src/catalog.ts`; clients only display them.

## Dynamic offers

`getActiveOffer` (Cloud Function) returns at most one offer per user, each kind issued once with a fixed server expiry stored in `users/{uid}/offers/{kind}`.

| Kind | Who | Discount | Window | iOS | Android (on `premium_annual`) |
|---|---|---|---|---|---|
| `welcome` | Never subscribed, first 72h | 40% first year | 48h | buy `premium_annual_offer` | offer tag `welcome` |
| `exam_sprint` | Never subscribed, exam ≤ 45 days (needs `daysToExam`) | 40% first year | 72h | buy `premium_annual_offer` | offer tag `welcome` |
| `winback` | Lapsed subscriber | 50% first year | 7 days | promotional offer `winback_annual_50` (server-signed) | offer tag `winback` |

Store setup required:
- App Store Connect: promotional offer `winback_annual_50` on `premium_annual` (pay up front, 1 year).
- Play Console, `premium_annual` base plan: offers tagged `trial` (7-day free, new customers), `welcome` (40% first year, developer-determined), `winback` (50% first year, developer-determined).
- The app only shows an offer when the store returns a matching price, and never picks an arbitrary Play offer.

Kill switch: functions param `OFFERS_ENABLED=false`.

Local testing: `ios/Exam/Exam.storekit` is attached to the Exam scheme's Run action (Xcode only).
