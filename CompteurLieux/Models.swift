import Foundation
import SwiftData

/// Un lieu surveillé (une zone circulaire autour d'un point GPS).
@Model
final class Lieu {
    var id: UUID = UUID()
    var nom: String = ""
    var icone: String = "mappin"
    var latitude: Double = 0
    var longitude: Double = 0
    var rayon: Double = 150          // en mètres (iOS impose ~100 m minimum en pratique)
    var creeLe: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Visite.lieu)
    var visites: [Visite] = []

    @Relationship(deleteRule: .cascade, inverse: \Ajustement.lieu)
    var ajustements: [Ajustement] = []

    init(nom: String, icone: String, latitude: Double, longitude: Double, rayon: Double) {
        self.nom = nom
        self.icone = icone
        self.latitude = latitude
        self.longitude = longitude
        self.rayon = rayon
    }

    /// La visite pas encore terminée (si on est actuellement sur place).
    var visiteEnCours: Visite? {
        visites.first { $0.fin == nil }
    }

    /// Temps total passé dans ce lieu entre deux dates (visites + ajustements manuels).
    func duree(depuis debut: Date, jusqua fin: Date = .now) -> TimeInterval {
        let tempsVisites = visites.reduce(0) { $0 + $1.duree(entre: debut, et: fin) }
        let tempsAjustes = ajustements
            .filter { $0.date >= debut && $0.date <= fin }
            .reduce(0) { $0 + $1.secondes }
        return max(0, tempsVisites + tempsAjustes)
    }
}

/// Une visite = une entrée dans la zone, puis une sortie.
@Model
final class Visite {
    var debut: Date = Date()
    var fin: Date?                   // nil tant qu'on est encore sur place
    var manuelle: Bool = false       // true si créée ou modifiée à la main
    var lieu: Lieu?

    init(debut: Date) {
        self.debut = debut
    }

    var dureeTotale: TimeInterval {
        max(0, (fin ?? .now).timeIntervalSince(debut))
    }

    /// Partie de la visite comprise dans l'intervalle [a, b].
    func duree(entre a: Date, et b: Date) -> TimeInterval {
        let start = max(debut, a)
        let end = min(fin ?? .now, b)
        return max(0, end.timeIntervalSince(start))
    }
}

/// Temps ajouté (secondes > 0) ou retiré (secondes < 0) à la main.
@Model
final class Ajustement {
    var date: Date = Date()
    var secondes: Double = 0
    var note: String = ""
    var lieu: Lieu?

    init(date: Date, secondes: Double, note: String) {
        self.date = date
        self.secondes = secondes
        self.note = note
    }
}

func formatDuree(_ secondes: TimeInterval) -> String {
    let total = Int(secondes)
    let h = total / 3600
    let m = (total % 3600) / 60
    if h > 0 {
        return "\(h) h \(String(format: "%02d", m))"
    }
    return "\(m) min"
}
