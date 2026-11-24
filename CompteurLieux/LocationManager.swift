import CoreLocation
import SwiftData
import Observation

/// Gère la géolocalisation et la surveillance des zones (geofencing).
/// iOS prévient l'app quand on entre / sort d'une zone, même si l'app est fermée.
@MainActor
@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var container: ModelContainer?

    var autorisation: CLAuthorizationStatus = .notDetermined
    var positionActuelle: CLLocation?

    /// Si on ressort puis rentre en moins de 5 min (GPS qui saute), on recolle à la visite précédente.
    private let delaiFusion: TimeInterval = 5 * 60
    /// Les visites de moins de 2 min sont ignorées (simple passage devant).
    private let dureeMinimale: TimeInterval = 2 * 60

    private override init() {
        super.init()
        manager.delegate = self
        autorisation = manager.authorizationStatus
    }

    // MARK: - API utilisée par l'interface

    func configurer(container: ModelContainer) {
        self.container = container

        let lieux = (try? container.mainContext.fetch(FetchDescriptor<Lieu>())) ?? []
        let idsLieux = Set(lieux.map { $0.id.uuidString })
        let surveilles = Set(manager.monitoredRegions.map(\.identifier))

        // Zones dont le lieu a été supprimé → on arrête de les surveiller
        for region in manager.monitoredRegions where !idsLieux.contains(region.identifier) {
            manager.stopMonitoring(for: region)
        }
        // Lieux pas encore surveillés → on les ajoute
        for lieu in lieux where !surveilles.contains(lieu.id.uuidString) {
            surveiller(lieu)
        }
        // On redemande l'état de chaque zone pour se resynchroniser
        for region in manager.monitoredRegions {
            manager.requestState(for: region)
        }
    }

    func demanderAutorisation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    func localiser() {
        manager.requestLocation()
    }

    func surveiller(_ lieu: Lieu) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        let rayon = min(max(lieu.rayon, 100), manager.maximumRegionMonitoringDistance)
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: lieu.latitude, longitude: lieu.longitude),
            radius: rayon,
            identifier: lieu.id.uuidString
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        manager.startMonitoring(for: region)
    }

    func arreter(_ lieu: Lieu) {
        for region in manager.monitoredRegions where region.identifier == lieu.id.uuidString {
            manager.stopMonitoring(for: region)
        }
    }

    // MARK: - Logique entrée / sortie

    private func mettreAJour(lieuID: String, dedans: Bool) {
        guard let container, let uuid = UUID(uuidString: lieuID) else { return }
        let contexte = container.mainContext

        let descripteur = FetchDescriptor<Lieu>(predicate: #Predicate { $0.id == uuid })
        guard let lieu = try? contexte.fetch(descripteur).first else { return }

        let enCours = lieu.visiteEnCours

        if dedans && enCours == nil {
            // Entrée : soit on recolle à la dernière visite si elle vient de finir, soit on en crée une
            let derniere = lieu.visites
                .filter { $0.fin != nil }
                .max { $0.fin! < $1.fin! }
            if let derniere, let fin = derniere.fin, Date.now.timeIntervalSince(fin) < delaiFusion {
                derniere.fin = nil
            } else {
                let visite = Visite(debut: .now)
                contexte.insert(visite)
                visite.lieu = lieu
            }
        } else if !dedans, let visite = enCours {
            // Sortie : on ferme la visite
            visite.fin = .now
            if visite.dureeTotale < dureeMinimale {
                contexte.delete(visite)
            }
        }

        try? contexte.save()
    }

    // MARK: - CLLocationManagerDelegate
    // Ces méthodes sont "nonisolated" : on récupère les infos utiles
    // puis on repasse sur le thread principal pour toucher à l'état / la base.

    nonisolated func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        let statut = m.authorizationStatus
        Task { @MainActor in
            self.autorisation = statut
            if statut == .authorizedWhenInUse {
                // Étape 2 : on demande "Toujours" (nécessaire pour l'arrière-plan)
                self.manager.requestAlwaysAuthorization()
            }
        }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let c = locations.last?.coordinate else { return }
        let lat = c.latitude, lon = c.longitude
        Task { @MainActor in
            self.positionActuelle = CLLocation(latitude: lat, longitude: lon)
        }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        print("Erreur de localisation : \(error.localizedDescription)")
    }

    nonisolated func locationManager(_ m: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        // Dès qu'une zone est surveillée, on demande si on est déjà dedans
        m.requestState(for: region)
    }

    nonisolated func locationManager(_ m: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        // Appelé à chaque entrée/sortie ET après requestState → on gère tout ici
        guard state != .unknown else { return }
        let dedans = (state == .inside)
        let id = region.identifier
        Task { @MainActor in
            self.mettreAJour(lieuID: id, dedans: dedans)
        }
    }

    nonisolated func locationManager(_ m: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("Échec de surveillance de zone : \(error.localizedDescription)")
    }
}
