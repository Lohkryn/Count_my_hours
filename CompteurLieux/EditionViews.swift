import SwiftUI
import SwiftData

// MARK: - Ajouter / retirer du temps

struct AjustementView: View {
    @Environment(\.modelContext) private var contexte
    @Environment(\.dismiss) private var fermer
    let lieu: Lieu

    @State private var ajouter = true
    @State private var heures = 1
    @State private var minutes = 0
    @State private var jour = Date()
    @State private var note = ""

    private var secondes: Double { Double(heures * 3600 + minutes * 60) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $ajouter) {
                        Text("Ajouter").tag(true)
                        Text("Retirer").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Text((ajouter ? "+" : "−") + formatDuree(secondes))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(ajouter ? Color.green : Color.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: secondes)
                    Stepper("Heures : \(heures)", value: $heures, in: 0...24)
                    Stepper("Minutes : \(minutes)", value: $minutes, in: 0...55, step: 5)
                }

                Section {
                    DatePicker("Jour concerné", selection: $jour, in: ...Date.now, displayedComponents: .date)
                    TextField("Note (optionnel)", text: $note)
                } footer: {
                    Text("Ce temps sera compté dans les totaux du jour choisi.")
                }
            }
            .navigationTitle("Ajuster le temps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { fermer() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { enregistrer() }
                        .disabled(secondes == 0)
                }
            }
        }
    }

    private func enregistrer() {
        // Aujourd'hui → maintenant ; un autre jour → midi ce jour-là
        let cal = Calendar.current
        let date = cal.isDateInToday(jour)
            ? Date.now
            : cal.startOfDay(for: jour).addingTimeInterval(12 * 3600)

        let ajustement = Ajustement(
            date: date,
            secondes: ajouter ? secondes : -secondes,
            note: note.trimmingCharacters(in: .whitespaces)
        )
        contexte.insert(ajustement)
        ajustement.lieu = lieu
        try? contexte.save()
        fermer()
    }
}

// MARK: - Créer ou modifier une visite

struct EditionVisiteView: View {
    @Environment(\.modelContext) private var contexte
    @Environment(\.dismiss) private var fermer

    let lieu: Lieu
    let visite: Visite?              // nil = nouvelle visite

    @State private var debut: Date
    @State private var fin: Date
    @State private var enCours: Bool

    init(lieu: Lieu, visite: Visite?) {
        self.lieu = lieu
        self.visite = visite
        let maintenant = Date()
        _debut = State(initialValue: visite?.debut ?? maintenant.addingTimeInterval(-3600))
        _fin = State(initialValue: visite?.fin ?? maintenant)
        _enCours = State(initialValue: visite != nil && visite?.fin == nil)
    }

    private var etaitEnCours: Bool { visite != nil && visite?.fin == nil }
    private var valide: Bool { enCours || fin > debut }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Début", selection: $debut, in: ...Date.now)
                    if etaitEnCours {
                        Toggle("Toujours sur place", isOn: $enCours)
                    }
                    if !enCours {
                        DatePicker("Fin", selection: $fin, in: ...Date.now)
                    }
                }

                Section {
                    HStack {
                        Text("Durée")
                        Spacer()
                        Text(valide ? formatDuree((enCours ? Date.now : fin).timeIntervalSince(debut)) : "—")
                            .bold()
                            .monospacedDigit()
                    }
                } footer: {
                    if !valide {
                        Text("La fin doit être après le début.")
                            .foregroundStyle(.red)
                    }
                }

                if let visite {
                    Section {
                        Button("Supprimer cette visite", role: .destructive) {
                            contexte.delete(visite)
                            try? contexte.save()
                            fermer()
                        }
                    }
                }
            }
            .navigationTitle(visite == nil ? "Nouvelle visite" : "Modifier la visite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { fermer() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { enregistrer() }
                        .disabled(!valide)
                }
            }
        }
    }

    private func enregistrer() {
        if let visite {
            visite.debut = debut
            visite.fin = enCours ? nil : fin
            visite.manuelle = true
        } else {
            let nouvelle = Visite(debut: debut)
            nouvelle.fin = fin
            nouvelle.manuelle = true
            contexte.insert(nouvelle)
            nouvelle.lieu = lieu
        }
        try? contexte.save()
        fermer()
    }
}

// MARK: - Personnaliser (thème + apparence)

struct ReglagesView: View {
    @Environment(\.dismiss) private var fermer
    @AppStorage("theme") private var themeBrut = Theme.ocean.rawValue
    @AppStorage("apparence") private var apparenceBrut = Apparence.systeme.rawValue

    var body: some View {
        NavigationStack {
            Form {
                Section("Thème") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 14) {
                        ForEach(Theme.allCases) { theme in
                            let choisi = theme.rawValue == themeBrut
                            Button {
                                withAnimation(.snappy) { themeBrut = theme.rawValue }
                            } label: {
                                VStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(theme.degrade)
                                        .frame(height: 70)
                                        .overlay {
                                            if choisi {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.title2)
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(choisi ? Color.primary : Color.clear, lineWidth: 2.5)
                                        )
                                    Text(theme.nom)
                                        .font(.caption.weight(.medium))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Apparence") {
                    Picker("Apparence", selection: $apparenceBrut) {
                        ForEach(Apparence.allCases) { apparence in
                            Text(apparence.nom).tag(apparence.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Personnaliser")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { fermer() }
                }
            }
        }
    }
}
