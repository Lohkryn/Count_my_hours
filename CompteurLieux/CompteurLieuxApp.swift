import SwiftUI
import SwiftData

@main
struct CompteurLieuxApp: App {
    let container: ModelContainer

    @AppStorage("theme") private var themeBrut = Theme.ocean.rawValue
    @AppStorage("apparence") private var apparenceBrut = Apparence.systeme.rawValue

    private var theme: Theme { Theme(rawValue: themeBrut) ?? .ocean }
    private var apparence: Apparence { Apparence(rawValue: apparenceBrut) ?? .systeme }

    init() {
        do {
            container = try ModelContainer(for: Lieu.self, Visite.self, Ajustement.self)
        } catch {
            fatalError("Impossible de créer la base de données : \(error)")
        }
        // Important : le gestionnaire de localisation doit être créé dès le lancement.
        // Quand iOS relance l'app en arrière-plan (entrée/sortie d'une zone),
        // c'est ici que l'événement est récupéré.
        LocationManager.shared.configurer(container: container)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.theme, theme)
                .tint(theme.accent)
                .preferredColorScheme(apparence.colorScheme)
        }
        .modelContainer(container)
    }
}
