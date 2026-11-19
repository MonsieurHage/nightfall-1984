# NIGHTFALL 1984 — PROTOCOLE SKYNET

FPS 3D pédagogique, en français, inspiré de l'ambiance des films de science-fiction des
années 1980. Le jeu est un **hommage original** : aucun extrait, image, son, dialogue ou
logo de *Terminator* (1984) n'est redistribué. Tous les modèles, textures, polices et sons
sont soit des créations originales générées par les scripts du dépôt, soit des ressources
libres de droits (CC0 / SIL OFL 1.1) — voir [`docs/LICENSES.md`](docs/LICENSES.md).

L'objectif réel est de **faire apprendre le programme de technologie du cycle 4** (Bulletin
officiel n° 9 du 29 février 2024) tout en restant un jeu addictif : exploration, armes,
ennemis, conduits de ventilation, jets de vapeur, caméras de surveillance, rayon
rétrécissant, boss, et bornes de QCM contextuelles qui débloquent l'environnement suivant.

---

## 🌐 Jouer en ligne (PC / tablette / mobile)

**URL :** https://monsieurhage.github.io/nightfall-1984/

Le build Web est embarqué dans `docs/` et servi par GitHub Pages. Il utilise le renderer
**Compatibility (WebGL2)** pour fonctionner sur navigateur, avec manette tactile automatique
sur mobile/tablette. Les comptes, la sauvegarde et le classement passent par Supabase :
voir [`docs/SUPABASE.md`](docs/SUPABASE.md) pour la configuration (à faire une seule fois).

---

## 1. Lancer le jeu

### Prérequis
- **Godot 4.7.2 stable** (`Forward+`) — binaire utilisé pour le développement :
  `P:\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`.
- Aucune installation de Blender n'est nécessaire pour *jouer* : les 6 modèles GLB sont
  déjà générés dans `assets/models/`. Blender 5.3 ne sert qu'à les régénérer.

### Ouverture
1. Ouvrir Godot, puis **Importer** (`Import`), et sélectionner le dossier
   `Nightfall1984_Godot` (le fichier `project.godot`).
2. Appuyer sur **F5** (ou le bouton ▶). La scène principale est `scenes/main.tscn`.
3. Cliquer sur **NOUVELLE MISSION**.

> Astuce : au premier lancement laissez Godot réimporter les ressources (textures, audio,
> polices). L'import est déjà préparé ; aucun message d'erreur n'est attendu.

### Ligne de commande (tests / chargement direct d'un niveau)
```powershell
$exe  = 'P:\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
$proj = '\\DC2K22-PEDAGO\hager$\Documents\Projet par défaut\Nightfall1984_Godot'

# Validation de tous les scripts sans lancer le jeu
& $exe --headless --path $proj --editor --quit

# Chargement direct d'un environnement (alley|factory|vents|plant|core)
& $exe --headless --path $proj --test-level=alley --quit-after 400
```

---

## 2. Commandes

| Touche | Action |
|---|---|
| **Z Q S D** | Se déplacer |
| **Souris** | Viser |
| **Clic gauche** | Tirer |
| **E** | Interagir (bornes, portes, vannes, objets, extraction) |
| **Maj (Shift)** | Courir |
| **Ctrl** | Se baisser (indispensable dans les conduits) |
| **Espace** | Sauter |
| **Q** | Spécial (rayon rétrécissant / agrandissant) |
| **R** | Recharger |
| **1 / 2 / 3** | Choisir une arme |
| **F** | Lampe torche |
| **Tab** | Classeur technologique (codex) |
| **Échap** | Pause |

---

## 3. Les cinq environnements

| # | Environnement | Thème | Objectifs pédagogiques dominants |
|---|---|---|---|
| 01 | **Rue industrielle (Alley)** | 1984, pluie, néons | Démarche de projet, chaîne d'énergie |
| 02 | **Usine CyberTech (Factory)** | Convoyeurs, bras robots | Matériaux, mécanismes, carte d'accès |
| 03 | **Conduits & serveurs (Vents)** | Infiltration, caméras | Information, cybersécurité, sécurité |
| 04 | **Centrale (Plant)** | Générateurs, séquence de disjoncteurs | Chaîne énergétique, fluides |
| 05 | **Noyau Skynet (Core)** | Arène, boss bouclier | QCM mélangés des 7 thèmes |

Boucle de jeu : **mission → objectifs + bornes pédagogiques (QCM) → XP/score →
déblocage de l'environnement suivant**. Les réussites et les fiches codex alimentent un
bilan consultable dans le **mode professeur**, avec export CSV dans `user://`.

---

## 4. Pédagogie

- Banque : **84 questions** (7 thèmes × 12) et **35 fiches codex**, avec explications et
  référence au texte officiel (`bo_ref`) pour chaque item — [`data/questions.json`](data/questions.json),
  [`data/codex.json`](data/codex.json).
- Les 7 thèmes du jeu sont un **découpage interne** (Matière, Énergie, Information + projet
  + sécurité + mécanique + fluides) ; le BO officiel s'organise en 3 thèmes / 9 compétences,
  chaque question étant rattachée au paragraphe correspondant. Aucune question ne présente
  « TECHNE » comme un sigle officiel : le jeu parle de **démarche de projet**.
- Détail complet, progression 5e/4e/3e et correspondances BO :
  [`docs/PEDAGOGIE.md`](docs/PEDAGOGIE.md).

---

## 5. Architecture technique

- **Godot 4.7.2 / GDScript**, rendu **Forward+**, MSAA, ACES/tonemapping filmique, glow,
  brouillard, ombres limitées. Pas de raytracing ni de volumétrique lourd : cible
  **1080p 45–60 fps** sur GPU Intel intégré (~2 Go partagé), Core 5 210H, 16 Go RAM.
- **Données séparées** du code : `data/{questions,missions,codex}.json` (schémas dans
  [`docs/CONTEXT.md`](docs/CONTEXT.md)).
- **Autoloads** : `Game` (état, score/XP, sauvegarde, matériaux), `Audio` (musiques à
  fondu croisé + SFX), `Quiz` (sélection/évaluation), `Missions` (objectifs/déblocage).
- **FPS** (`scripts/player.gd`) : CharacterBody3D, 3 armes (pistolet, fusil plasma,
  réducteur quantique), lampe, interaction par raycast. Ennemis `endo`/`drone`/`turret` et boss à
  bouclier avec 3 terminaux à neutraliser (`scripts/enemy.gd`, `scripts/boss.gd`).
- **Génération de niveaux** : `scripts/levels/level_base.gd` fournit géométrie, lumières,
  néons, pluie, props GLB, pickups, ennemis, conduits, alarmes et lasers ; chaque
  `level_<id>.gd` compose son environnement.
- **UI** (`scripts/ui/ui.gd`) construite en code (menu, sélection, HUD, QCM, codex, pause,
  bilan, décès, mode professeur), avec polices OFL et shader de vignettage
  (`assets/shaders/cinematic.gdshader`).
- **Assets 3D originaux** : 6 GLB.glTF 2.0 (~2,5 Mio, 39 objets) générés par
  [`tools/blender/generate_assets.py`](tools/blender/generate_assets.py) — détails dans
  [`docs/ASSETS.md`](docs/ASSETS.md).

---

## 6. Régénérer les assets (optionnel)

```powershell
# Textures, HDRI, polices (Poly Haven CC0 / Google Fonts OFL)
python tools/fetch_assets.py

# Musiques et effets sonores (synthèse Python, aucune banque tierce)
python tools/generate_audio.py

# Modèles 3D (Blender 5.3 headless)
& 'P:\Downloads\blender-5.3.0-windows-x64\blender-5.3.0-windows-x64\blender.exe' `
  -b -P 'tools\blender\generate_assets.py' -- --out 'assets\models'
```

Sources effectivement utilisées : [`tools/asset_sources.json`](tools/asset_sources.json).
Licences : [`docs/LICENSES.md`](docs/LICENSES.md).

---

## 7. Captures

Des captures en mode fenêtré sont fournies dans [`docs/screenshots/`](docs/screenshots/)
(`alley.png`, `core.png`, 1600×900). Elles sont générables pour n'importe quel niveau :

```powershell
$out = "docs\screenshots\$lvl.png"
& $exe --path $proj "--test-level=$lvl" "--capture=$out" --quit-after 600
```

L'option `--capture=<chemin>` est gérée par `scripts/main.gd` (capture après 2 s de rendu).

---

## 8. État & déploiement

Projet **terminé et testé** (0 erreur de script sur les 5 environnements, headless et
fenêtré). Un `.gitignore` et le script [`tools/setup_git.ps1`](tools/setup_git.ps1)
préparent un dépôt Git **local sans remote ni push** — à exécuter une fois Git installé
(s'il ne l'est pas déjà sur la machine).

Le **déploiement sur GitHub est volontairement différé** et ne sera effectué que sur
demande explicite.

Dernière validation : 2026-11-19 — Godot 4.7.2 stable, Blender 5.3.0.
