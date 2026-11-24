import SwiftUI

/// Les thèmes de couleurs disponibles (modifiables dans l'écran "Personnaliser").
enum Theme: String, CaseIterable, Identifiable {
    case ocean, coucher, foret, neon, lave, minimal

    var id: String { rawValue }

    var nom: String {
        switch self {
        case .ocean:   return "Océan"
        case .coucher: return "Coucher de soleil"
        case .foret:   return "Forêt"
        case .neon:    return "Néon"
        case .lave:    return "Lave"
        case .minimal: return "Minimal"
        }
    }

    var couleurs: [Color] {
        switch self {
        case .ocean:   return [Color(red: 0.16, green: 0.42, blue: 0.98), Color(red: 0.20, green: 0.80, blue: 0.92)]
        case .coucher: return [Color(red: 1.00, green: 0.52, blue: 0.30), Color(red: 0.94, green: 0.28, blue: 0.56)]
        case .foret:   return [Color(red: 0.08, green: 0.55, blue: 0.40), Color(red: 0.55, green: 0.80, blue: 0.30)]
        case .neon:    return [Color(red: 0.50, green: 0.25, blue: 0.98), Color(red: 0.95, green: 0.30, blue: 0.82)]
        case .lave:    return [Color(red: 0.85, green: 0.15, blue: 0.20), Color(red: 1.00, green: 0.62, blue: 0.15)]
        case .minimal: return [Color(red: 0.22, green: 0.23, blue: 0.27), Color(red: 0.45, green: 0.47, blue: 0.52)]
        }
    }

    var accent: Color { couleurs[0] }

    var degrade: LinearGradient {
        LinearGradient(colors: couleurs, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Clair / sombre / comme l'iPhone.
enum Apparence: String, CaseIterable, Identifiable {
    case systeme, clair, sombre

    var id: String { rawValue }

    var nom: String {
        switch self {
        case .systeme: return "Auto"
        case .clair:   return "Clair"
        case .sombre:  return "Sombre"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .systeme: return nil
        case .clair:   return .light
        case .sombre:  return .dark
        }
    }
}

/// Icônes proposées pour un lieu.
let iconesLieux = [
    "mappin", "building.2.fill", "house.fill", "briefcase.fill", "book.fill",
    "laptopcomputer", "figure.climbing", "dumbbell.fill", "cup.and.saucer.fill",
    "fork.knife", "cart.fill", "music.note", "gamecontroller.fill", "tree.fill"
]

// Permet à toutes les vues de lire le thème avec @Environment(\.theme)
private struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .ocean
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
