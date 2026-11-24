import SwiftUI
import SwiftData
import MapKit

struct AjoutLieuView: View {
    @Environment(\.modelContext) private var contexte
    @Environment(\.dismiss) private var fermer
    @Environment(\.theme) private var theme

    @State private var nom = ""
    @State private var icone = "mappin"
    @State private var centre: CLLocationCoordinate2D?
    @State private var rayon: Double = 150
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)

    private let localisation = LocationManager.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Nom") {
                    TextField("Ex : 42, salle de sport…", text: $nom)
                }

                Section("Icône") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(iconesLieux, id: \.self) { nomIcone in
                                let choisie = icone == nomIcone
                                Button {
                                    icone = nomIcone
                                } label: {
                                    Image(systemName: nomIcone)
                                        .font(.title3)
                                        .frame(width: 46, height: 46)
                                        .foregroundStyle(choisie ? Color.white : Color.primary)
                                        .background {
                                            if choisie {
                                                Circle().fill(theme.degrade)
                                            } else {
                                                Circle().fill(Color(.tertiarySystemFill))
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    MapReader { proxy in
                        Map(position: $camera) {
                            UserAnnotation()
                            if let centre {
                                Marker(nom.isEmpty ? "Lieu" : nom, systemImage: icone, coordinate: centre)
                                    .tint(theme.accent)
                                MapCircle(center: centre, radius: rayon)
                                    .foregroundStyle(theme.accent.opacity(0.2))
                                    .stroke(theme.accent, lineWidth: 2)
                            }
                        }
                        .onTapGesture { point in
                            if let coord = proxy.convert(point, from: .local) {
                                centre = coord
                            }
                        }
                    }
                    .frame(height: 300)
                    .listRowInsets(EdgeInsets())

                    Button("Utiliser ma position actuelle", systemImage: "location.fill") {
                        localisation.localiser()
                    }
                } header: {
                    Text("Emplacement")
                } footer: {
                    Text("Touche la carte pour placer le lieu.")
                }

                Section("Rayon : \(Int(rayon)) m") {
                    Slider(value: $rayon, in: 100...500, step: 25)
                }
            }
            .navigationTitle("Nouveau lieu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { fermer() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { enregistrer() }
                        .disabled(nom.trimmingCharacters(in: .whitespaces).isEmpty || centre == nil)
                }
            }
            .onAppear {
                localisation.localiser()
            }
            .onChange(of: localisation.positionActuelle) { _, nouvelle in
                guard let nouvelle else { return }
                centre = nouvelle.coordinate
                camera = .region(MKCoordinateRegion(
                    center: nouvelle.coordinate,
                    latitudinalMeters: 1000,
                    longitudinalMeters: 1000
                ))
            }
        }
    }

    private func enregistrer() {
        guard let centre else { return }
        let lieu = Lieu(
            nom: nom.trimmingCharacters(in: .whitespaces),
            icone: icone,
            latitude: centre.latitude,
            longitude: centre.longitude,
            rayon: rayon
        )
        contexte.insert(lieu)
        try? contexte.save()
        localisation.surveiller(lieu)
        fermer()
    }
}
