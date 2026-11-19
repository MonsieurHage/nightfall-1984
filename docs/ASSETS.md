# ASSETS 3D — NIGHTFALL 1984

Assets **originaux**, générés procéduralement par `tools/blender/generate_assets.py`
(Blender 5.3 headless). Aucun modèle, texture ou logo tiers ; aucune référence graphique
protégée. Les six GLB sont du **glTF 2.0 binaire** (unité = 1 mètre, axe **Y-up**,
avant = **-Z**, convention Godot 4), sans texture externe ni compression Draco.
Tous les matériaux sont PBR métallique/ rugosité, emissifs pour les voyants.

## Fichiers livrés

| Fichier | Taille | Tris | Objets |
|---|---:|---:|---|
| `assets/models/endoskeleton.glb` | 407 224 o | 13 244 | 15 |
| `assets/models/drone.glb` | 170 940 o | 6 746 | 1 |
| `assets/models/boss.glb` | 808 100 o | 27 836 | 2 |
| `assets/models/weapons.glb` | 294 400 o | 11 926 (≈4k/arme) | 3 |
| `assets/models/props.glb` | 859 124 o | 19 592 (≈1,2k/objet) | 16 |
| `assets/models/player_hands.glb` | 95 204 o | 3 288 | 2 |

**Total : 2 634 992 octets (≈2,51 Mio), 39 objets nommés.**

## Pivots et orientations

Les coordonnées ci-dessous sont celles du **nœud glTF/Godot** (Y-up). `L` = côté -X,
`R` = côté +X. Tous les avant (`Head`, lentilles, canons, écrans) regardent vers **-Z**.

### `endoskeleton.glb` — 1,80 m, 15 objets séparés

Pivot = centre de l'articulation, pour animation par rotation d'un `Node3D` parent.

| Objet | Pivot (m) | Rôle |
|---|---|---|
| `Head` | (0, 1,550, 0) | cou ; crâne chrome, mâchoire, yeux `red_emissive` |
| `Torso` | (0, 1,080, 0) | lombaire ; côtes, sternum, verins, épaules |
| `Pelvis` | (0, 0,940, 0) | bassin et rotules de hanche |
| `UpperArm_L` / `UpperArm_R` | (∓0,235, 1,480, 0) | épaule → coude |
| `LowerArm_L` / `LowerArm_R` | (∓0,247, 1,180, 0) | coude → poignet |
| `Hand_L` / `Hand_R` | (∓0,247, 0,900, 0) | poignet ; paume + 4 doigts + pouce |
| `UpperLeg_L` / `UpperLeg_R` | (∓0,105, 0,920, 0) | hanche → genou |
| `LowerLeg_L` / `LowerLeg_R` | (∓0,108, 0,480, 0) | genou → cheville |
| `Foot_L` / `Foot_R` | (∓0,108, 0,060, 0) | cheville ; semelle posée à y = 0 |

### `drone.glb`

`Drone` : pivot au **centre géométrique** (0, 0, 0), ≈0,82 m de diamètre, lentille
rouge vers -Z, quatre stabilisateurs annulaires.

### `boss.glb` — 4,21 m

- `Boss` : pivot à la **base** (0, 0, 0), au sol. Torse blindé, épaules, deux canons,
  cœur cyan/rouge, crête jusqu'à 4,21 m.
- `WeakPoint` : pivot au **centre** de la sphère, position (0, 2,905, -0,520),
  rayon ≈0,078 m. Cible à référencer depuis Godot.

### `weapons.glb`

`Pistol`, `Rifle`, `ShrinkRay` : pivot à la **poignée** (0, 0, 0), canon vers **-Z**.
Longueurs ≈0,31 m / 1,06 m / 0,61 m. Le fusil a une batterie à cellules
`emissive_cyan` ; le rayon rétrécissant a cinq bobines et un dôme `emissive_green`.

### `props.glb` — 16 objets

Pivot **base (y=0)** : `Crate`, `Barrel`, `Console`, `Monitor`, `ServerRack`,
`Turret`, `Door`.
Pivot **centre** : `VentGrate`, `Pipe`, `Keycard`, `MemoryChip`, `Medkit`, `Battery`,
`Camera`, `Valve`, `NeonSign`.
Face avant des éléments muraux (`VentGrate`, `Monitor`, `Camera`, `NeonSign`) : **-Z**.
Détails : vis, poignées, grilles, LEDs, rainures de panneaux, bandes d'avertissement.
`NeonSign` utilise un motif géométrique abstrait (aucun texte ni logo).

### `player_hands.glb` — viewmodel FPS

`Hand_L` (x = -0,105) et `Hand_R` (x = +0,105) : pivot au **poignet**, avant-bras
ganté vers +Z (arrière) et main/doigts vers **-Z**. Prévoir un décalage caméra dans
Godot pour éviter le clipping avec la géométrie du monde.

## Matériaux

Noms stables, réutilisés entre les fichiers :

`chrome` (métal 1,0 / rugosité 0,18), `dark_steel` (0,88 / 0,42),
`brushed_metal` (0,92 / 0,30), `gunmetal` (0,85 / 0,35),
`weathered_steel` (0,72 / 0,62), `black_plastic` (0,05 / 0,55),
`rubber` (0 / 0,86), `tinted_glass` (0,35 / 0,06, opaque brillant),
`circuit_green`, `gold`, `bone_white`, `warning_red`,
`red_emissive`, `emissive_cyan`, `emissive_green`, `emissive_amber`.

Aucune image n'est référencée dans les GLB : les apparences sont uniquement des
facteurs PBR + géométrie. Le glow doit être géré côté Godot (glow/Compositor).

## Régénération

Depuis la racine du projet, dans PowerShell :

```powershell
cd '\\DC2K22-PEDAGO\hager$\Documents\Projet par défaut\Nightfall1984_Godot'
& 'P:\Downloads\blender-5.3.0-windows-x64\blender-5.3.0-windows-x64\blender.exe' `
  -b -P 'tools\blender\generate_assets.py' -- --out 'assets\models'
```

Le script n'écrit **que** dans le dossier donné à `--out`. La génération est
déterministe : deux exécutions produisent six fichiers **octet pour octet identiques**
(vérifié avec SHA-256 le 2026-11-19). Chaque GLB est vérifié à l'export (> 5 Ko).

## Licence

Création originale pour NIGHTFALL 1984 — PROTOCOLE SKYNET. L'auteur place ces
fichiers et le script générateur sous licence **CC0 1.0 / domaine public**
(équivalent CC0) : utilisation, modification et redistribution libres, y compris
commerciales, sans attribution obligatoire. Aucun élément tiers n'est inclus.
