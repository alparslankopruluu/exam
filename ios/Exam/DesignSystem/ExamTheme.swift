import SwiftUI

enum ExamPalette {
    static let background = Color(red: 247/255, green: 249/255, blue: 252/255)
    static let surface = Color.white
    static let textPrimary = Color(red: 15/255, green: 23/255, blue: 42/255)
    static let textSecondary = Color(red: 100/255, green: 116/255, blue: 139/255)
    static let primary = Color(red: 59/255, green: 108/255, blue: 246/255)
    static let indigo = Color(red: 92/255, green: 92/255, blue: 246/255)
    static let mint = Color(red: 44/255, green: 203/255, blue: 140/255)
    static let amber = Color(red: 245/255, green: 165/255, blue: 36/255)
    static let coral = Color(red: 242/255, green: 109/255, blue: 109/255)
    static let purple = Color(red: 139/255, green: 92/255, blue: 246/255)
    static let border = Color(red: 230/255, green: 234/255, blue: 242/255)
    static let softBlue = Color(red: 234/255, green: 241/255, blue: 255/255)
    static let softMint = Color(red: 233/255, green: 249/255, blue: 242/255)
    static let softPurple = Color(red: 242/255, green: 238/255, blue: 255/255)
}

extension View {
    func examCard(radius: CGFloat = 20) -> some View {
        self
            .background(ExamPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(ExamPalette.border, lineWidth: 1)
            }
    }
}
