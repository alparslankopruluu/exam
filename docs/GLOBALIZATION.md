# Globalization model

Country, interface language and exam are independent axes.

A user may live in Türkiye, use English UI and prepare for IELTS or SAT. A user in Germany may use Turkish UI and prepare for Abitur. Device locale is only a suggestion and is never treated as the user's exam choice.

## Resolution order
1. Device language suggests UI language.
2. Device region suggests country.
3. User explicitly confirms/changes country.
4. Country determines the local exam catalog.
5. International exams remain visible in every country.
6. Selected exam determines syllabus, scoring, question style and schedule rules.

## Content packs
Every exam resolves to a versioned content pack:
- curriculum / syllabus tree
- subject and topic taxonomy
- scoring rules
- question formats
- diagnostic blueprint
- mock-exam blueprint
- official-date strategy
- localized terminology
- source / review metadata

Content must be remotely versionable. Native builds ship a safe seed catalog only.

## Monetization
Never hardcode currency strings. StoreKit / Google Play own localized product price presentation. Offers and paywall copy may be market-configured remotely, but entitlement rules stay consistent.

## Initial catalog seeds
Local markets: Türkiye, US, UK/England, India, Brazil, South Korea, Germany, Spain, France, Japan.
International: IELTS, TOEFL, Cambridge English, IB Diploma, IGCSE, SAT.

"Other country" always exists and uses the international/general-study catalog.
