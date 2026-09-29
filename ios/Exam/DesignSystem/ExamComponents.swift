import SwiftUI

struct ExamPrimaryButton: View {
    let title: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .foregroundStyle(.white)
                .background(enabled ? ExamPalette.primary : ExamPalette.border)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

struct ExamSelectionCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let accent: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 46, height: 46)
                    .background(accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ExamPalette.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(ExamPalette.textSecondary)
                }

                Spacer()

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(selected ? ExamPalette.primary : ExamPalette.border)
            }
            .padding(14)
            .background(ExamPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selected ? ExamPalette.primary : ExamPalette.border, lineWidth: selected ? 1.5 : 1)
            }
            .shadow(color: selected ? ExamPalette.primary.opacity(0.08) : .clear, radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }
}

struct ExamStatPill: View {
    let value: String
    let label: String
    let symbol: String
    let accent: Color

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol).foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(ExamPalette.textPrimary)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(ExamPalette.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(ExamPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ExamPalette.border, lineWidth: 1)
        }
    }
}
