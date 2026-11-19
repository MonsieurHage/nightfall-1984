# Licences des ressources — NIGHTFALL 1984 : PROTOCOLE SKYNET

Toutes les ressources distribuées avec ce projet sont **libres de droits** (CC0) ou
**sous licence SIL Open Font License 1.1**, ou bien des **créations originales**
générées par les scripts de ce dépôt. **Aucun extrait de film, aucune image, aucun
son ou dialogue de *Terminator* (1984) n'est redistribué** : le jeu est un hommage
original, avec des modèles, textures, polices et sons indépendants.

## Tableau des ressources

| Ressource | Fichiers concernés | Source (URL) | Licence |
|---|---|---|---|
| Bitume usé (4 cartes PBR 1k JPG) | `assets/textures/asphalt_{diffuse,normal,rough,ao}.jpg` | https://polyhaven.com/a/asphalt_01 | CC0 1.0 (Poly Haven) |
| Béton usé (4 cartes PBR 1k JPG) | `assets/textures/concrete_{diffuse,normal,rough,ao}.jpg` | https://polyhaven.com/a/concrete_floor_01 | CC0 1.0 (Poly Haven) |
| Métal industrial (4 cartes PBR 1k JPG) | `assets/textures/metal_{diffuse,normal,rough,ao}.jpg` | https://polyhaven.com/a/metal_plate | CC0 1.0 (Poly Haven) |
| Rouille (4 cartes PBR 1k JPG) | `assets/textures/rust_{diffuse,normal,rough,ao}.jpg` | https://polyhaven.com/a/rust_coarse_01 | CC0 1.0 (Poly Haven) |
| Panneaux métalliques d'usine (4 cartes PBR 1k JPG) | `assets/textures/panel_{diffuse,normal,rough,ao}.jpg` | https://polyhaven.com/a/factory_wall | CC0 1.0 (Poly Haven) |
| HDRI nocturne 1k | `assets/hdri/night_1k.hdr` | https://polyhaven.com/a/rogland_clear_night | CC0 1.0 (Poly Haven) |
| Orbitron Bold | `assets/fonts/Orbitron-Bold.ttf`, `assets/fonts/Orbitron-OFL.txt` | https://github.com/google/fonts/tree/c8e3197f63e4ff7b487f69f76cf17bcc023c980c/ofl/orbitron | SIL OFL 1.1 |
| Rajdhani SemiBold | `assets/fonts/Rajdhani-SemiBold.ttf`, `assets/fonts/Rajdhani-OFL.txt` | https://github.com/google/fonts/tree/main/ofl/rajdhani | SIL OFL 1.1 |
| Musiques (5 pistes stéréo, 76–96 s, bouclables) | `assets/audio/music_{menu,alley,factory,vents,boss}.wav` et `.ogg` | Création originale — `tools/generate_audio.py` | Création originale (domaine public / libre d'usage dans ce projet) |
| Effets sonores (17 SFX mono) | `assets/audio/sfx_*.wav` | Création originale — `tools/generate_audio.py` | Création originale (domaine public / libre d'usage dans ce projet) |

## Détails

- **Poly Haven** : les textures sont téléchargées via l'API officielle
  (`https://api.polyhaven.com/assets?t=textures`, `https://api.polyhaven.com/files/<id>`)
  en résolution **1024 × 1024 JPG**. Les normales utilisent la convention **OpenGL**
  (`nor_gl`) ; `rough` et `ao` proviennent des canaux `Rough` et `AO` d'origine.
  License : https://polyhaven.com/license — CC0 1.0 Universal (aucune attribution
  obligatoire, attribution donnée ici à titre informatif).
- **Google Fonts** : Orbitron Bold provient du commit figé
  `c8e3197f63e4ff7b487f69f76cf17bcc023c980c` (dernière version contenant le TTF
  statique Bold), Rajdhani SemiBold de la branche `main`. Les textes de licence
  OFL sont copiés dans `assets/fonts/Orbitron-OFL.txt` et
  `assets/fonts/Rajdhani-OFL.txt`. License : https://openfontlicense.org/.
- **Audio** : aucune banque de sons tierce n'est utilisée. Les musiques et SFX sont
  synthétisés échantillon par échantillon avec la bibliothèque standard Python
  (`math`, `random`, `array`, `wave`, `struct`), à 44,1 kHz / 16 bits, normalisés à
  -1 dBFS avec fondus anti-clic. Les `.ogg` sont des conversions locales (libvorbis)
  des `.wav` conservés.
- **Fallback** : si un téléchargement échoue, `tools/fetch_assets.py` génère des
  substituts procéduraux (JPEG baseline et HDR Radiance écrits en Python pur).
  Lors de l'exécution finale, **aucun fallback n'a été nécessaire** : toutes les
  ressources viennent des sources listées ci-dessus.
- Les scripts de génération (`tools/fetch_assets.py`, `tools/generate_audio.py`)
  sont fournis pour permettre de régénérer ou vérifier l'ensemble des fichiers.
  Le manifeste `tools/asset_sources.json` consigne les URL effectivement utilisées.
