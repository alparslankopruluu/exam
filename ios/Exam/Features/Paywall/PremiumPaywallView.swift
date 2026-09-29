import SwiftUI

struct PremiumPaywallView: View {
    let setup: StudySetup
    let placement: String
    let onClose: () -> Void

    @State private var offer: StoreOfferPresentation = .placeholder
    @State private var special: OfferPresentation?
    @State private var selection: PlanChoice = .annual
    @State private var purchasing = false
    @State private var purchaseError: String?

    private var copy: LocalizedCopy {
        LocalizedCopy.load(languageCode: setup.languageCode)
    }

    private enum PlanChoice { case special, annual, monthly }

    private var selectedProductId: String {
        switch selection {
        case .special: special?.offer.productId ?? offer.annual.productId
        case .annual: offer.annual.productId
        case .monthly: offer.monthly.productId
        }
    }

    private var selectedPrice: String? {
        switch selection {
        case .special: special?.localizedPrice
        case .annual: offer.annual.localizedPrice
        case .monthly: offer.monthly.localizedPrice
        }
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

                        Text(copy.text("paywall_subtitle"))
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
                        benefit("sparkles", copy.text("advanced_ai_tutor"), copy.text("advanced_ai_tutor_hint"))
                        benefit("waveform", copy.text("voice_tutor"), copy.text("voice_tutor_hint"))
                        benefit("folder.fill", copy.text("unlimited_materials"), copy.text("unlimited_materials_hint"))
                        benefit("bolt.fill", copy.text("quick_practice"), copy.text("quick_practice_hint"))
                    }
                    .padding(.top, 14)

                    if let special {
                        specialOfferCard(special)
                            .padding(.top, 14)
                    }

                    planCard(offer.annual, displayTitle: copy.text("annual"), selected: selection == .annual) {
                        selection = .annual
                        AppServices.shared.analytics.event(
                            AnalyticsEvent.subscriptionPlanSelected,
                            params: [AnalyticsParam.productId: offer.annual.productId]
                        )
                    }
                    .padding(.top, 14)

                    planCard(offer.monthly, displayTitle: copy.text("monthly"), selected: selection == .monthly) {
                        selection = .monthly
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
                    let success = await StoreKitBillingService.shared.purchase(
                        productId: selectedProductId,
                        offer: selection == .special ? special?.offer : nil
                    )
                    purchasing = false
                    if success {
                        AppServices.shared.analytics.event(
                            AnalyticsEvent.purchaseCompleted,
                            params: [
                                AnalyticsParam.placement: placement,
                                AnalyticsParam.productId: selectedProductId
                            ]
                        )
                        onClose()
                    } else {
                        purchaseError = copy.text("purchase_not_completed")
                        AppServices.shared.analytics.event(
                            AnalyticsEvent.purchaseFailed,
                            params: [
                                AnalyticsParam.placement: placement,
                                AnalyticsParam.productId: selectedProductId
                            ]
                        )
                    }
                }
            } label: {
                Text(
                    purchasing
                    ? copy.text("processing")
                    : selectedPrice.map {
                        copy.text("continue_price", variables: ["price": $0])
                    } ?? copy.text("loading_price")
                )
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selectedPrice == nil ? ExamPalette.border : ExamPalette.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(selectedPrice == nil || purchasing)

            if let purchaseError {
                Text(purchaseError)
                    .font(.system(size: 11))
                    .foregroundStyle(ExamPalette.coral)
                    .padding(.top, 7)
            }

            Text(copy.text("price_terms"))
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
            if let active = await OfferService.shared.fetch(),
               let presented = await StoreKitBillingService.shared.present(active) {
                special = presented
                selection = .special
                AppServices.shared.analytics.event(
                    "offer_viewed",
                    params: [AnalyticsParam.placement: placement, "offer_kind": active.kind]
                )
            }
        }
    }

    private var headline: String {
        switch placement {
        case "voice_tutor":
            copy.text("paywall_voice_title")
        case "mock_analysis":
            copy.text("paywall_mock_title")
        case "document_limit":
            copy.text("paywall_documents_title")
        case "ai_limit":
            copy.text("paywall_ai_title")
        default:
            copy.text("paywall_title")
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

    private func specialOfferCard(_ presented: OfferPresentation) -> some View {
        Button {
            selection = .special
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(copy.text("offer_badge", variables: ["percent": String(presented.offer.discountPercent)]))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(ExamPalette.coral)
                        .clipShape(Capsule())
                    Spacer()
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(Self.countdown(to: presented.offer.expiresAt, now: context.date))
                            .font(.system(size: 13, weight: .bold).monospacedDigit())
                            .foregroundStyle(ExamPalette.coral)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: selection == .special ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(selection == .special ? ExamPalette.primary : ExamPalette.border)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(copy.text("offer_title_\(presented.offer.kind)"))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(ExamPalette.textPrimary)
                        Text(copy.text("offer_first_year"))
                            .font(.system(size: 11))
                            .foregroundStyle(ExamPalette.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(presented.localizedPrice)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(ExamPalette.textPrimary)
                        Text(presented.regularPrice)
                            .font(.system(size: 11))
                            .strikethrough()
                            .foregroundStyle(ExamPalette.textSecondary)
                    }
                }
            }
            .padding(14)
            .background(ExamPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selection == .special ? ExamPalette.coral : ExamPalette.border, lineWidth: selection == .special ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private static func countdown(to end: Date, now: Date) -> String {
        let seconds = max(0, Int(end.timeIntervalSince(now)))
        let days = seconds / 86_400
        let clock = String(format: "%02d:%02d:%02d", (seconds % 86_400) / 3600, (seconds % 3600) / 60, seconds % 60)
        return days > 0 ? "\(days)d \(clock)" : clock
    }

    private func planCard(
        _ plan: StorePlanPresentation,
        displayTitle: String,
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
                        Text(displayTitle)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(ExamPalette.textPrimary)

                        if plan.recommended {
                            Text(copy.text("best_value"))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(ExamPalette.primary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(ExamPalette.softBlue)
                                .clipShape(Capsule())
                        }
                    }

                    if plan.hasTrial {
                        Text(copy.text("paywall_trial_available"))
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
