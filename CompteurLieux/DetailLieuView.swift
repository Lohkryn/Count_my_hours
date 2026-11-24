import SwiftUI
import SwiftData

// MARK: - Détail d'un lieu

struct DetailLieuView: View {
    @Environment(\.modelContext) private var contexte
    @Environment(\.theme) private var theme
    let lieu: Lieu

    @State private var visiteAEditer: Visite?
    @State private var nouvelleVisite = false
    @State private var afficherAjustement = false

    private var visitesTriees: [Visite] {
        lieu.visites.sorted { $0.debut > $1.debut }
    }

    private var ajustementsTries: [Ajustement] {
        lieu.ajustements.sorted { $0.date > $1.date }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            List {
                Section {
                    EnteteDetail(lieu: lieu, maintenant: ctx.date)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section {
                    Button {
                        afficherAjustement = true
                    } label: {
                        Label("Ajouter ou retirer du temps", systemImage: "plusminus.circle.fill")
                    }
                    Button {
                        nouvelleVisite = true
                    } label: {
                        Label("Ajouter une visite à la main", systemImage: "calendar.badge.plus")
                    }
                } header: {
                    Text("Modifier à la main")
                }

                if !ajustementsTries.isEmpty {
                    Section("Ajustements") {
                        ForEach(ajustementsTries) { ajustement in
                            LigneAjustement(ajustement: ajustement)
                        }
                        .onDelete { offsets in
                            let liste = ajustementsTries
                            for index in offsets { contexte.delete(liste[index]) }
                            try? contexte.save()
                        }
                    }
                }

                Section {
                    if visitesTriees.isEmpty {
                        Text("Aucune visite pour l'instant")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(visitesTriees) { visite in
                        Button {
                            visiteAEditer = visite
                        } label: {
                            LigneVisite(visite: visite)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        let liste = visitesTriees
                        for index in offsets { contexte.delete(liste[index]) }
                        try? contexte.save()
                    }
                } header: {
                    Text("Visites")
                } footer: {
                    Text("Touche une visite pour changer ses horaires. Balaye vers la gauche pour la supprimer.")
                }
            }
        }
        .navigationTitle(lieu.nom)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $visiteAEditer) { visite in
            EditionVisiteView(lieu: lieu, visite: visite)
                .environment(\.theme, theme)
                .tint(theme.accent)
        }
        .sheet(isPresented: $nouvelleVisite) {
            EditionVisiteView(lieu: lieu, visite: nil)
                .environment(\.theme, theme)
                .tint(theme.accent)
        }
        .sheet(isPresented: $afficherAjustement) {
            AjustementView(lieu: lieu)
                .environment(\.theme, theme)
                .tint(theme.accent)
        }
    }
}

// MARK: - En-tête avec les totaux

struct EnteteDetail: View {
    @Environment(\.theme) private var theme
    let lieu: Lieu
    let maintenant: Date

    var body: some View {
        let cal = Calendar.current
        let jour = cal.startOfDay(for: maintenant)
        let semaine = cal.dateInterval(of: .weekOfYear, for: maintenant)?.start ?? jour
        let mois = cal.dateInterval(of: .month, for: maintenant)?.start ?? jour

        VStack(spacing: 16) {
            Image(systemName: lieu.icone)
                .font(.title.weight(.semibold))
                .frame(width: 64, height: 64)
                .background(.white.opacity(0.2), in: Circle())

            VStack(spacing: 2) {
                Text("Total")
                    .font(.subheadline)
                    .opacity(0.85)
                Text(formatDuree(lieu.duree(depuis: .distantPast, jusqua: maintenant)))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }

            HStack(spacing: 0) {
                Stat(titre: "Aujourd'hui", valeur: formatDuree(lieu.duree(depuis: jour, jusqua: maintenant)))
                Rectangle().fill(.white.opacity(0.35)).frame(width: 1, height: 32)
                Stat(titre: "Semaine", valeur: formatDuree(lieu.duree(depuis: semaine, jusqua: maintenant)))
                Rectangle().fill(.white.opacity(0.35)).frame(width: 1, height: 32)
                Stat(titre: "Mois", valeur: formatDuree(lieu.duree(depuis: mois, jusqua: maintenant)))
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 12)
        .background(theme.degrade, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

struct Stat: View {
    let titre: String
    let valeur: String

    var body: some View {
        VStack(spacing: 2) {
            Text(valeur)
                .font(.headline)
                .monospacedDigit()
            Text(titre)
                .font(.caption)
                .opacity(0.85)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Lignes de liste

struct LigneVisite: View {
    let visite: Visite

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(visite.debut, format: .dateTime.weekday(.wide).day().month())
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 4) {
                    Text(visite.debut, style: .time)
                    Image(systemName: "arrow.right").font(.caption2)
                    if let fin = visite.fin {
                        Text(fin, style: .time)
                    } else {
                        Text("en cours").foregroundStyle(.green)
                    }
                    if visite.manuelle {
                        Image(systemName: "hand.point.up.left.fill")
                            .font(.caption2)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text(formatDuree(visite.dureeTotale))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

struct LigneAjustement: View {
    let ajustement: Ajustement

    private var positif: Bool { ajustement.secondes >= 0 }

    var body: some View {
        HStack {
            Image(systemName: positif ? "plus.circle.fill" : "minus.circle.fill")
                .foregroundStyle(positif ? Color.green : Color.red)
            VStack(alignment: .leading, spacing: 2) {
                Text(ajustement.note.isEmpty ? (positif ? "Temps ajouté" : "Temps retiré") : ajustement.note)
                    .font(.subheadline)
                Text(ajustement.date, format: .dateTime.weekday(.wide).day().month())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text((positif ? "+" : "−") + formatDuree(abs(ajustement.secondes)))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(positif ? Color.green : Color.red)
        }
    }
}
