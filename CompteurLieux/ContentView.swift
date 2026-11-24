import SwiftUI
import SwiftData
import CoreLocation

// MARK: - Écran principal

struct ContentView: View {
    @Environment(\.modelContext) private var contexte
    @Environment(\.theme) private var theme
    @Query(sort: \Lieu.creeLe) private var lieux: [Lieu]

    @State private var afficherAjout = false
    @State private var afficherReglages = false
    @State private var lieuASupprimer: Lieu?

    private let localisation = LocationManager.shared

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { ctx in
                ScrollView {
                    VStack(spacing: 14) {
                        if localisation.autorisation != .authorizedAlways {
                            BandeauAutorisation(statut: localisation.autorisation)
                        }

                        if lieux.isEmpty {
                            EtatVide { afficherAjout = true }
                        } else {
                            CarteResume(lieux: lieux, maintenant: ctx.date)

                            ForEach(lieux) { lieu in
                                NavigationLink(value: lieu) {
                                    CarteLieu(lieu: lieu, maintenant: ctx.date)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Supprimer", systemImage: "trash", role: .destructive) {
                                        lieuASupprimer = lieu
                                    }
                                }
                            }

                            Text("Appui long sur un lieu pour le supprimer")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 4)
                        }
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Mes lieux")
            .navigationDestination(for: Lieu.self) { lieu in
                DetailLieuView(lieu: lieu)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        afficherReglages = true
                    } label: {
                        Image(systemName: "paintpalette.fill")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        afficherAjout = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $afficherAjout) {
                AjoutLieuView()
                    .environment(\.theme, theme)
                    .tint(theme.accent)
            }
            .sheet(isPresented: $afficherReglages) {
                ReglagesView()
                    .environment(\.theme, theme)
                    .tint(theme.accent)
            }
            .confirmationDialog(
                "Supprimer ce lieu ?",
                isPresented: Binding(
                    get: { lieuASupprimer != nil },
                    set: { if !$0 { lieuASupprimer = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Supprimer le lieu et son historique", role: .destructive) {
                    if let lieu = lieuASupprimer { supprimer(lieu) }
                }
            }
        }
    }

    private func supprimer(_ lieu: Lieu) {
        localisation.arreter(lieu)
        contexte.delete(lieu)
        try? contexte.save()
        lieuASupprimer = nil
    }
}

// MARK: - Carte "Aujourd'hui" en haut

struct CarteResume: View {
    @Environment(\.theme) private var theme
    let lieux: [Lieu]
    let maintenant: Date

    var body: some View {
        let debutJour = Calendar.current.startOfDay(for: maintenant)
        let totalJour = lieux.reduce(0) { $0 + $1.duree(depuis: debutJour, jusqua: maintenant) }
        let actuel = lieux.first { $0.visiteEnCours != nil }

        VStack(alignment: .leading, spacing: 6) {
            Text("Aujourd'hui")
                .font(.subheadline.weight(.medium))
                .opacity(0.85)
            Text(formatDuree(totalJour))
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            if let actuel {
                Label("En ce moment : \(actuel.nom)", systemImage: "location.fill")
                    .font(.subheadline.weight(.semibold))
            } else {
                Text("Tu n'es dans aucun de tes lieux")
                    .font(.subheadline)
                    .opacity(0.85)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(theme.degrade, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: theme.accent.opacity(0.35), radius: 18, y: 8)
    }
}

// MARK: - Carte d'un lieu

struct CarteLieu: View {
    @Environment(\.theme) private var theme
    let lieu: Lieu
    let maintenant: Date

    var body: some View {
        let cal = Calendar.current
        let debutJour = cal.startOfDay(for: maintenant)
        let debutSemaine = cal.dateInterval(of: .weekOfYear, for: maintenant)?.start ?? debutJour

        HStack(spacing: 14) {
            Image(systemName: lieu.icone)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(theme.degrade, in: RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(lieu.nom)
                    .font(.headline)
                    .lineLimit(1)
                StatutLieu(lieu: lieu, maintenant: maintenant)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatDuree(lieu.duree(depuis: debutJour, jusqua: maintenant)))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                Text("\(formatDuree(lieu.duree(depuis: debutSemaine, jusqua: maintenant))) / sem.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct StatutLieu: View {
    let lieu: Lieu
    let maintenant: Date

    var body: some View {
        if let visite = lieu.visiteEnCours {
            HStack(spacing: 6) {
                PointPulsant()
                Text("Sur place · \(formatDuree(maintenant.timeIntervalSince(visite.debut)))")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)
        } else if let derniere = lieu.visites.compactMap(\.fin).max() {
            Text("Dernière visite \(derniere.formatted(.relative(presentation: .named)))")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("Pas encore de visite")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct PointPulsant: View {
    @State private var anime = false

    var body: some View {
        Circle()
            .fill(.green)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(.green, lineWidth: 2)
                    .scaleEffect(anime ? 2.4 : 1)
                    .opacity(anime ? 0 : 0.8)
            )
            .onAppear {
                withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                    anime = true
                }
            }
    }
}

// MARK: - États particuliers

struct EtatVide: View {
    @Environment(\.theme) private var theme
    let ajouter: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 96, height: 96)
                .background(theme.degrade, in: Circle())
            Text("Aucun lieu pour l'instant")
                .font(.title3.bold())
            Text("Ajoute un endroit (ton école, la salle de sport…) et l'app comptera toute seule le temps que tu y passes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: ajouter) {
                Label("Ajouter un lieu", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(theme.degrade, in: Capsule())
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .padding(.top, 40)
    }
}

struct BandeauAutorisation: View {
    let statut: CLAuthorizationStatus

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "location.slash.fill")
                .font(.title3)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text("Localisation « Toujours » nécessaire")
                    .font(.subheadline.bold())
                Text("Sans elle, l'app ne peut pas compter le temps quand elle est fermée.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if statut == .notDetermined {
                    Button("Autoriser") {
                        LocationManager.shared.demanderAutorisation()
                    }
                    .font(.subheadline.weight(.semibold))
                } else {
                    Button("Ouvrir les Réglages") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
