![DEMO](https://media3.giphy.com/media/v1.Y2lkPTc5MGI3NjExMGl4b3B4c2k4MDdhM2hta3RpZGozNWo0NjdwZ3ZuYnlyZG45ZWwzZyZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/UoYVe41j58xs663TMv/giphy.gif)

# Compteur d'horaire par localisation 

App iPhone (SwiftUI, iOS 17 minimum) qui compte automatiquement le temps passé dans des lieux grâce au geofencing.

## Ce qu'il y a dedans

- Détection automatique des entrées / sorties (même app fermée)
- Totaux du jour, de la semaine, du mois et depuis le début
- **Modifs à la main** : ajouter/retirer du temps, ajouter une visite, changer les horaires d'une visite
- **Thèmes** : Océan, Coucher de soleil, Forêt, Néon, Lave, Minimal + clair/sombre/auto (bouton 🎨 en haut à gauche)
- Une icône par lieu

## Fichiers

```
CompteurLieux/            ← le code Swift
.github/workflows/build.yml  ← dit à GitHub comment compiler l'app
project.yml               ← décrit le projet Xcode (généré par GitHub)
```

## Compiler l'app avec GitHub (sans Mac)

1. Crée un compte sur github.com si tu n'en as pas
2. **New repository** → nom `CompteurLieux` → **Public** → Create
   (en public, les Mac de GitHub sont gratuits sans limite ; en privé tu as ~200 min/mois, soit ~40 compilations)
3. Sur la page du dépôt, clique **uploading an existing file**
4. Dézippe le zip, ouvre le dossier `CompteurLieux`, sélectionne **tout ce qu'il contient** (le dossier `CompteurLieux`, le dossier `.github`, `project.yml`, `LISEZMOI.md`) et glisse-le dans la page → **Commit changes**
5. Vérifie que le dossier `.github` apparaît bien dans le dépôt.
   S'il manque : **Add file > Create new file**, tape le nom `.github/workflows/build.yml`, colle le contenu du fichier `build.yml`, puis **Commit**
6. Onglet **Actions** : la compilation démarre toute seule (~5 min)
   - ✅ vert : c'est bon
   - ❌ rouge : clique dessus, ouvre l'étape en rouge et copie l'erreur à Claude
7. Le fichier **CompteurLieux.ipa** est dans **Releases** (colonne de droite de la page du dépôt)

Chaque fois que tu modifies le code sur GitHub, une nouvelle version est compilée.

## Installer sur l'iPhone

Avec **SideStore** (gratuit, renouvelle l'app tout seul tous les 7 jours). La première installation de SideStore demande ton PC une seule fois.
Ensuite : télécharge le `.ipa` depuis Releases sur ton iPhone → ouvre-le avec SideStore.

Au premier lancement : autorise la localisation, puis choisis **Toujours**
(sinon : Réglages > Lieux > Position > Toujours).

## Bon à savoir

- Précision : quelques dizaines de mètres et parfois quelques minutes de décalage. Un rayon de 150–200 m marche bien.
- 20 lieux maximum (limite d'iOS).
- Les passages de moins de 2 min sont ignorés ; une sortie suivie d'un retour en moins de 5 min reste une seule visite (réglable en haut de `LocationManager.swift`).
