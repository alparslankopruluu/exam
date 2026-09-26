import SwiftUI

struct PremiumPaywallView: View {
    let setup: StudySetup
    let placement: String
    let onClose: () -> Void

    @State private var offer: StoreOfferPresentation = .placeholder
    @State private var annualSelected = true
    @State private var purchasing = false
    @State private var purchaseError: String?

    private var selectedPlan: StorePlanPresentation {
        annualSelected ? offer.annual : offer.monthly
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    AppServices.shared.analytics.event(
                        AnalyticsEvent.paywallClosed,
                        params: [AnalyticsParam.placement: placement]
                    )
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(ExamPalette.textSecondary)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(setup.exam.shortName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.16))
                            .clipShape(Capsule())

                        Text(headline)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.top, 20)

                        Text("Premium keeps your \(setup.exam.shortName) plan adaptive across practice, tutoring and review.")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineSpacing(3)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(22)
                    .background(
                        LinearGradient(
                            colors: [ExamPalette.primary, ExamPalette.indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                    VStack(spacing: 0) {
                        benefit("sparkles", "Advanced AI Tutor", "Ask follow-ups until you understand.")
                        benefit("waveform", "Voice Tutor", "Interactive speaking and spoken explanations.")
                        benefit("folder.fill", "Unlimited study materials", "Turn notes and documents into practice.")
                        benefit("chart.xyaxis.line", "Advanced progress", "See mastery and mistake patterns over time.")
                    }
                    .padding(.top, 14)

                    planCard(offer.annual, selected: annualSelected) {
                        annualSelected = true
                        AppServices.shared.analytics.event(
                            AnalyticsEvent.subscriptionPlanSelected,
                            params: [AnalyticsParam.productId: offer.annual.productId]
                        )
                    }
                    .padding(.top, 14)

                    planCard(offer.monthly, selected: !annualSelected) {
                        annualSelected = false
                        AppServices.shared.analytics.event(
                            AnalyticsEvent.subscriptionPlanSelected,
                            params: [AnalyticsParam.productId: offer.monthly.productId]
                        )
                    }
                    .padding(.top, 9)
                }
            }

            Button {
                Task { @MainActor in
                    purchasing = true
                    purchaseError = nil
                    let success = await StoreKitBillingService.shared.purchase(productId: selectedPlan.productId)
                    purchasing = false
                    if success {
                        AppServices.shared.analytics.event(
                            AnalyticsEvent.purchaseCompleted,
                            params: [
                                AnalyticsParam.placement: placement,
                                AnalyticsParam.productId: selectedPlan.productId
                            ]
                        )
                        onClose()
                    } else {
                        purchaseError = "Purchase was not completed."
                        AppServices.shared.analytics.event(
                            AnalyticsEvent.purchaseFailed,
                            params: [
                                AnalyticsParam.placement: placement,
                                AnalyticsParam.productId: selectedPlan.productId
                            ]
                        )
                    }
                }
            } label: {
                Text(
                    purchasing
                    ? "Processing…"
                    : selectedPlan.localizedPrice.map { "Continue · \($0)" } ?? "Loading local price…"
                )
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selectedPlan.localizedPrice == nil ? ExamPalette.border : ExamPalette.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(selectedPlan.localizedPrice == nil || purchasing)

            if let purchaseError {
                Text(purchaseError)
                    .font(.system(size: 11))
                    .foregroundStyle(ExamPalette.coral)
                    .padding(.top, 7)
            }

            Text("Price, trial eligibility and renewal terms come directly from the App Store for your account and region.")
                .font(.system(size: 10))
                .foregroundStyle(ExamPalette.textSecondary)
                .lineSpacing(2)
                .padding(.top, 8)
                .padding(.bottom, 10)
        }
        .padding(.horizontal, 20)
        .background(ExamPalette.background.ignoresSafeArea())
        .task {
            AppServices.shared.analytics.event(
                AnalyticsEvent.paywallViewed,
                params: [
                    AnalyticsParam.placement: placement,
                    AnalyticsParam.examId: setup.exam.id,
                    AnalyticsParam.contentPackId: setup.exam.syllabusPackId
                ]
            )
            offer = await StoreKitBillingService.shared.loadOffer()
        }
    }

    private var headline: String {
        switch placement {
        case "voice_tutor":
            "Talk it through until it clicks."
        case "mock_analysis":
            "Turn every mock exam into a better next week."
        case "document_limit":
            "Turn all your material into study sessions."
        default:
            "Keep your full personalized plan."
        }
    }

    private func benefit(_ symbol: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .foregroundStyle(ExamPalette.primary)
                .frame(width: 38, height: 38)
                .background(ExamPalette.softBlue)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(ExamPalette.textSecondary)
            }
            Spacer()
        }
        .padding(.vertical, 7)
    }

    private func planCard(
        _ plan: StorePlanPresentation,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(selected ? ExamPalette.primary : ExamPalette.border)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(plan.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(ExamPalette.textPrimary)

                        if plan.recommended {
                            Text("BEST VALUE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(ExamPalette.primary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(ExamPalette.softBlue)
                                .clipShape(Capsule())
                        }
                    }

                    if let trialText = plan.trialText {
                        Text(trialText)
                            .font(.system(size: 11))
                            .foregroundStyle(ExamPalette.textSecondary)
                    }
                }

                Spacer()

                Text(plan.localizedPrice ?? "—")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ExamPalette.textPrimary)
            }
            .padding(14)
            .background(ExamPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selected ? ExamPalette.primary : ExamPalette.border, lineWidth: selected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}
