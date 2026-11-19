# CONTEXTE COMPACT — NIGHTFALL 1984 : PROTOCOLE SKYNET

## Demande
FPS 3D first-person, graphismes « qualité maximale » pour le PC présent, inspiré de Terminator (1984),
orienté pédagogie technologie (BO cycle 4, arrêté 29/02/2024, applicable 5e en 2024, 4e en 2025, 3e en 2026).
Missions -> environnements débloquables. Armes/objets, ennemis, exploration (conduits, jets, caméras,
rayon rétrécissant), boss. Objectif réel = faire apprendre le BO en restant addictif.
Déploiement GitHub plus tard, sur demande.

## Environnement (vérifié 2026-11-19)
- Godot 4.7.2 stable : `P:\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`
- Blender 5.3.0 : `P:\Downloads\blender-5.3.0-windows-x64\blender-5.3.0-windows-x64\blender.exe`
- GPU : Intel(R) Graphics intégré (~2 Go partagé), CPU Core 5 210H 8 cœurs, RAM 16 Go, Windows.
- Donc : rendu Forward+, lumières cuites/proxies, glow, tonemapping filmique, brouillard,
  ombres limitées, pas de raytracing/volumétrique lourd. Cible 1080p 45-60 fps.
- Projet racine : `\\DC2K22-PEDAGO\hager$\Documents\Projet par défaut\Nightfall1984_Godot`
- Projet antérieur (non utilisé, référence d'ambiance) : `C:\Games\Nightfall_1984` (Python/Panda3D).

## Décisions
- Titre original (homage, assets 100% originaux/CC0) : NIGHTFALL 1984 — PROTOCOLE SKYNET.
- Langue : FR. 5 environnements : Alley (1984), Usine, Conduits/Serveurs, Centrale, Noyau Skynet (boss).
- Boucle : mission -> objectifs + bornes pédagogiques (QCM contextuels) -> XP/score -> déblocage environnement.
- Pédagogie : questions BO (MEI : Matière, Énergie, Information + démarche de projet, sécurité, durable),
  fiches codex, bonus/malus, résultats exportables, mode professeur.
- Assets : glTF/GLB générés par Blender (scripts), textures PBR CC0 Poly Haven, audio synthétisé/CC0.

## Structure / interfaces (à respecter)
```
project.godot, icon.svg
assets/models/{endoskeleton,drone,boss,weapons,props,player_hands}.glb
assets/textures/polyhaven/*_{diffuse,normal,rough,ao}.jpg ; assets/textures/gen/*
assets/audio/{music_*,sfx_*}.wav|ogg ; assets/hdri/*.hdr ; assets/fonts/*
data/questions.json  data/missions.json  data/codex.json
scripts/{autoload,levels,ui,...}.gd
scenes/*.tscn
tools/blender/*.py  tools/*.py
docs/{CONTEXT.md,README.md,PEDAGOGIE.md,LICENSES.md}
```
### questions.json
`{"version":1,"themes":[{id,label,bo_ref,color}],"questions":[{id,theme,niveau,difficulte,prompt,options:[4],answer:int,explication,bo_ref,contexte,tags:[],score}]}`
### missions.json
`{"version":1,"missions":[{id,name,level_scene,unlocked_by,brief,objectives:[{id,type,target,label,quiz_theme}],quiz_themes:[],reward_xp}]}`
### codex.json
`{"version":1,"entries":[{id,theme,title,text,bo_ref}]}`

## Avancement (finalisé le 2026-11-19)
- [x] Environnement inspecté, versions vérifiées, dossier créé
- [x] Banque de questions BO : 84 questions (7 thèmes × 12) + 35 fiches codex + `docs/PEDAGOGIE.md`
- [x] Modèles Blender GLB : 6 fichiers glTF 2.0 valides (39 objets nommés) + `docs/ASSETS.md`
- [x] Textures/HDRI/audio/fonts CC0 : 20 cartes PBR, 1 HDRI, 5 musiques + 17 SFX, 2 polices OFL + `docs/LICENSES.md`
- [x] Moteur de jeu Godot : FPS (marche/sprint/crouch/saut, 3 armes, lampe), ennemis, boss, objets interactifs, conduits, jets, caméras, disjoncteurs séquentiels, 5 niveaux, UI complète (menu, HUD, QCM, codex, pause, bilan, mode professeur, export CSV)
- [x] Intégration des signaux, sauvegarde, score/XP/déblocage
- [x] Tests headless `--editor --quit` et `--test-level=<id>` pour les 5 environnements : 0 erreur de script
- [x] Captures fenêtrées `docs/screenshots/{alley,core}.png` (option `--capture=` dans `main.gd`)
- [x] Préparation Git locale : `.gitignore` + `tools/setup_git.ps1` (aucun push/remote)
- [x] Documentation : `README.md`, `PEDAGOGIE.md`, `ASSETS.md`, `LICENSES.md`, ce `CONTEXT.md`

## Remarques pédagogiques (voir `docs/PEDAGOGIE.md`)
- Le BO 2024 s'organise en **3 thèmes / 9 compétences** ; les 7 identifiants du jeu sont un découpage interne MEI + projet + sécurité, chaque question portant un `bo_ref` explicite.
- « TECHNE » n'est pas un sigle officiel : le jeu parle de **démarche de projet**.
- `fluides` est un découpage de jeu dérivé du vérin, du débit et des grandeurs mesurables du BO, pas un chapitre autonome.

## Tests reproductibles
```powershell
$exe = 'P:\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
$proj = '\\DC2K22-PEDAGO\hager$\Documents\Projet par défaut\Nightfall1984_Godot'
& $exe --headless --path $proj --editor --quit                      # validation des scripts
foreach ($lvl in 'alley','factory','vents','plant','core') {
  & $exe --headless --path $proj "--test-level=$lvl" --quit-after 400
}
```
Le drapeau `--test-level=<id>` est géré par `scripts/main.gd` (chargement direct d'un environnement).
