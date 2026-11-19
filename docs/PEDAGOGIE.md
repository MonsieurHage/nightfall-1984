# PÉDAGOGIE — Nightfall 1984 : Protocole Skynet

Ce jeu est un support d'entraînement formatif au **programme de technologie du cycle 4** publié au **Bulletin officiel n° 9 du 29 février 2024** (arrêté du 9 février 2024, NOR MENE2402802A). Application échelonnée : **5e à la rentrée 2024**, **4e à la rentrée 2025**, **3e à la rentrée 2026** (article 2 de l'arrêté). Le guide d'accompagnement de **mai 2024** sert de complément interprétatif, sans se substituer au texte du programme.

Banque livrée : `data/questions.json` (84 questions, 7 thèmes × 12, 4 options, une seule bonne réponse) et `data/codex.json` (35 fiches, 5 par thème). Aucune question n'est hors programme : chaque item porte un champ `bo_ref` et une explication qui ramène explicitement au texte officiel.

## 1. Les sept thèmes du jeu et leur correspondance BO

| Id du thème | Libellé | Ancrage officiel | Contexte de jeu dominant | Couleur |
|---|---|---|---|---|
| `projet` | Démarche de projet, cycle de vie, écoconception | BO 2024, thème 3 « Création, conception, réalisation, innovations » ; guide mai 2024 §§3.3, 8 | Atelier / table de conception (`projet`) | `#e07a5f` |
| `energie` | Sources, conversions, chaîne d'énergie, rendement | BO 2024, thème 2 « Fonctions, solutions, constituants de la chaîne d'énergie » ; thème 3 « Le choix d'une source d'énergie » | Disjoncteur, centrale (`energie`) | `#ff9f1c` |
| `information` | Données, algorithmes, capteurs, réseaux | BO 2024, thème 2 « Chaîne d'information », « Structuration et traitement des données », « La circulation de l'information dans un réseau informatique » | Terminal, serveur (`terminal`) | `#3a86ff` |
| `materiaux` | Propriétés, procédés, choix critérié | BO 2024, thème 2 « Matériaux et procédés », « Le dépannage et la réparation » ; guide §3.3 | Établi, étagère de matériaux (`materiaux`) | `#8ac926` |
| `mecanique` | Transmissions, transformations, dépannage | BO 2024, thème 2 « mouvements mécaniques : transmissions et transformations », « Le dépannage et la réparation » | Engrenages, bras articulé (`mecanique`) | `#ff006e` |
| `fluides` | Vérins, pression, débit, performance | BO 2024, thème 2 (conversions du **vérin**, formes d'énergie, débit) et thème 1 « La performance des OST » | Conduites, pompes (`fluides`) | `#48cae4` |
| `securite` | Sécurité, ergonomie, cybersécurité | BO 2024, thème 1 « L'OST dans son environnement », « Usages et impacts sociétaux du numérique » ; guide §7.2 | Coffret EPI, borne cyber (`securite`, `terminal`) | `#f72585` |

**Deux précisions d'honnêteté scientifique :**

- Le programme officiel s'organise en **3 thèmes et 9 compétences de fin de cycle**, pas en 7 thèmes. Les identifiants ci-dessus sont un **découpage pédagogique du jeu** (MEI + projet + sécurité), chaque item étant rattaché au paragraphe officiel correspondant.
- Le sigle **« TECHNE » n'apparaît pas** dans le BO ni dans le guide de mai 2024 comme démarche nommée. Le vocabulaire officiel est **« démarche de projet »** (intention, planification, produit final), adossée aux démarches d'investigation, technologique, de résolution de problème et d'étude de cas, et à la formule « faire pour apprendre et apprendre à faire ». Le thème `projet` couvre ces attendus ; aucune question ne présente « TECHNE » comme un acronyme officiel.
- Le thème `fluides` n'est pas un chapitre autonome du BO : il exploite les entrées officielles « vérin », « formes d'énergie », « débit », « instruments de mesure » et « performance des OST ». Il permet de contextualiser la chaîne d'énergie dans la salle des conduits du jeu.

### Structure et fonctionnement des OST (chaînes MEI)

Le triptyque **Matière – Énergie – Information** est rappelé comme invariant disciplinaire dans le guide de mai 2024 (§3.3) et dans le préambule du BO. Dans le jeu :

- **Chaîne d'énergie** : source → constituant de transfert/commande (batterie, relais/interrupteur) → conversion (moteur, lampe, radiateur, génératrice, vérin) → mouvement ou effet utile. Formes : électrique, cinétique, potentielle, thermique, lumineuse.
- **Chaîne d'information** : capteur (température, présence, distance) → microcontrôleur → programme → sortie vers un actionneur ou une IHM (boutons, afficheurs). Les grandeurs analogiques sont associées à des données exploitables en 3e.
- **Matière** : choix critérié d'un matériau (propriétés, conductibilités, modes de sollicitation), procédés d'ajout/enlèvement de matière, mise en forme, assemblages fixes ou démontables, cycle de vie et écoconception.
- **Réseaux** : terminal, carte réseau, liaisons filaires/WiFi, commutateur, adresse IP en 4e ; routeur, tables de routage et circulation sur Internet en 3e. La cybersécurité (mots de passe, phishing, traces, identité, sauvegardes, chiffrement, propriété intellectuelle) relève du thème 1 et du guide §7.2.

### Modélisation, simulation, algorithmique et programmation

Le BO renforce la **pensée informatique** : abstraction, décomposition, modélisation, représentation sous forme d'algorithme, simulation, résolution à l'aide d'un dispositif de traitement. Quatre piliers sont partagés avec les mathématiques : données et représentations, algorithmes, langages, machines.

Progression des attendus :

| | 5e | 4e | 3e |
|---|---|---|---|
| **Programme associé à une fonctionnalité** | Identifier données utilisées/produites ; traduire en algorithme en langage naturel ; modifier des paramètres et en évaluer les effets | Analyser les données et déduire des modifications ; compléter un programme ; tester et valider en environnement simulé ou réel | Déterminer les données, concevoir l'algorithme d'une nouvelle fonctionnalité, programmer et tester |
| **Concevoir un programme** | Analyser un programme simple et tester s'il répond au besoin | Modifier un programme fourni ; concevoir un algorithme en langage naturel puis le traduire | Programmer et mettre au point un système réel avec IHM, structuré en sous-programmes/fonctions ; passage à la programmation textuelle en fin de 3e |
| **Notions** | Entrées/sorties, affectation, séquence, condition simple | Opérateurs ET/OU/NON, itérations, événements, listes | Structuration, modularité, commentaires, programmation textuelle |
| **Simulation / tests** | Utiliser une simulation fournie ; suivre un protocole fourni | Mettre en œuvre un protocole de test ; paramétrer une simulation | Proposer un protocole, modéliser, prototyper et valider au regard du cahier des charges |

## 2. Progression 5e / 4e / 3e (repères du BO)

| Niveau | Analyse externe (thème 1) | Analyse interne (thème 2) | Conception (thème 3) |
|---|---|---|---|
| **5e** | Mise en service, manipulation, paramétrage ; collecter/trier/analyser des données ; repérer les matériaux, sources et formes d'énergie ; identifier composants d'un réseau local et règles de sécurité numérique | Identifier entrées/sorties ; chaînes fournies ; modifier des paramètres ; repérer visuellement une pièce défectueuse et réparer avec protocole fourni | Mini-projets avec planification établie ; assembler des constituants fournis ; fabriquer une solution pour améliorer un OST ; analyser un programme simple |
| **4e** | Intégrer conditions et contraintes ; choisir les appareils de mesure ; indices énergétique et de réparabilité ; comparer des sources et des matériaux | Explorer les composants des chaînes ; flux matière/énergie/information ; architecture de réseau local ; protocole de réparation ; compléter et tester un programme | Lier besoin – fonction – solution ; ajouter une fonctionnalité avec approche MEI et conscience environnementale ; protocole de test ; concevoir un algorithme puis le traduire |
| **3e** | Choix multicritères, bilan carbone, efficacité énergétique, cycle de vie et trois piliers du développement durable ; numérisation et transmission des données | Chaînes en matière de fonctions ; schémas blocs et modèles ; circulation des données sur Internet et routage ; pièce sur mesure ou composants de bibliothèque | Projet de groupe sur une thématique choisie (ex. ODD), écoconception, processus réaliste, modélisation, prototypage et programmation structurée avec IHM |

Le guide de mai 2024 met en garde contre une progression « séance après séance » qui isolerait les compétences : les 9 compétences doivent être **regroupées dans des séquences porteuses de sens**, en logique **spiralaire de complexité croissante**. La banque de questions respecte cette logique : un même concept (par exemple le rendement) est traité en 4e sous forme de calcul simple et en 3e sous forme de raisonnement sur les transferts.

## 3. Usage des QCM dans le jeu

Le champ `contexte` déclenche la borne pédagogique dans la salle correspondante ; le champ `theme` pilote le contenu enseigné. Les deux champs sont volontairement distincts : une borne près d'un disjoncteur (`energie`) peut poser une question de mécanique (`mecanique`), et un terminal réseau (`terminal`) peut poser une question de cybersécurité (`securite`) ou de programmation (`information`).

| Salle du jeu | `contexte` | Thèmes les plus fréquents |
|---|---|---|
| Rue / Alley 1984, zone de briefing | `projet` | `projet` |
| Usine, atelier, étagères | `materiaux` | `materiaux`, `projet` |
| Centrale, disjoncteurs | `energie` | `energie`, `mecanique`, `fluides` |
| Conduits, pompes, vérins | `fluides` | `fluides`, `energie` |
| Salle des serveurs, terminaux | `terminal` | `information`, `securite`, `projet` |
| Coffrets de sécurité, EPI | `securite` | `securite`, `materiaux`, `fluides` |
| Pont roulant, engrenages | `mecanique` | `mecanique`, `energie` |

Modalités recommandées :

- Afficher la question **au moment de l'action** (ex. après avoir rétabli une alimentation), pas sous forme de quiz abstrait en fin de niveau.
- Une seule bonne réponse (`answer` = index 0..3) ; les 4 options sont toujours proposées dans le même ordre pour éviter les indices visuels.
- Après réponse, afficher `explication` puis `bo_ref`, et débloquer la fiche `codex` du même thème : l'explication est l'objet d'apprentissage, le score (`score`: 100) n'est qu'un retour formatif.
- `difficulte` 1 / 2 / 3 = rappel / compréhension et calcul simple / raisonnement multicritère ou décryptage. Les fichiers contiennent 34 questions de niveau 1, 42 de niveau 2 et 8 de niveau 3.
- `niveau` 5e / 4e / 3e permet au mode professeur de filtrer selon l'année réellement concernée par l'arrêté (attention : en 2025-2026, le programme 2024 est en vigueur en 5e et 4e ; la 3e reste sous l'ancien programme jusqu'à la fin de l'année scolaire 2025-2026).
- Exporter les résultats (id question, thème, réponse, temps) pour construire un temps de structuration en classe, comme le préconise le guide de mai 2024.

## 4. Conseils à l'enseignant

- Utiliser les QCM comme **formation continue et non comme évaluation certificative** : l'objectif est de rendre l'élève actif (« faire pour apprendre et apprendre à faire »), pas de le classer.
- Toujours faire verbaliser le pourquoi de la bonne réponse à partir de l'explication ; faire reformuler avec les mots du BO (fonction, solution, constituant, conversion, flux, exigence).
- Profiter des erreurs fréquentes pour organiser une manipulation réelle : une courroie qui patine, une pile mal polarisée, un capteur mal paramétré, une pièce à réparer. Le BO privilégie les activités pratiques et l'atelier de fabrication collaboratif.
- Croiser les thèmes dans une même séquence : par exemple « éclairage de secours » relie chaîne d'énergie, capteur de présence, choix de matériau, autonomie et écoconception. C'est exactement ce que demande le guide : ne pas isoler les compétences.
- Pour la cybersécurité, s'appuyer sur le kit **CyberEnJeux** (ANSSI / ministère) et le référentiel CNIL cités par le guide de mai 2024 (§7.2) ; adapter les questions au niveau d'attention des élèves.
- Pour le développement durable, faire expliciter les trois piliers et les étapes du cycle de vie ; éviter les réponses « vertes » simplistes (une source renouvelable n'est pas sans impact).
- La banque est modifiable : conserver le schéma JSON et le champ `bo_ref` si vous ajoutez des questions locales, afin de garder la traçabilité au programme.

## 5. Sources consultées (consultation : 19 novembre 2026)

1. **Arrêté du 9 février 2024** modifiant l'arrêté du 9 novembre 2015 (NOR MENE2402802A), *Bulletin officiel n° 9 du 29 février 2024*, article 2 sur l'entrée en vigueur échelonnée — https://www.education.gouv.fr/bo/2024/Hebdo9/MENE2402802A
2. **Annexe — Programme de technologie du cycle 4**, BO n° 9 du 29 février 2024 (16 pages) — https://sti.eduscol.education.fr/sites/eduscol.education.fr.sti/files/textes/16802-programme-de-technologie-c4.pdf
3. **Guide d'accompagnement du programme de technologie publié en février 2024**, éduscol, mai 2024 (43 pages) — https://eduscol.education.gouv.fr/sites/default/files/document/guide-daccompagnement-du-programme-de-technologie-mai-2024pdf-106860.pdf
4. **Ressources d'accompagnement du programme de technologie au cycle 4**, page éduscol (mise à jour 30 décembre 2025) — https://eduscol.education.gouv.fr/5745/ressources-d-accompagnement-du-programme-de-technologie-au-cycle-4
5. **Nouveau Programme du Cycle 4**, éduscol STI, publié le 13 mars 2024 — https://sti.eduscol.education.fr/articles/nouveau-programme-du-cycle-4
6. **Les démarches pédagogiques préconisées**, portail pédagogique de l'académie d'Orléans-Tours, publié le 27 août 2024, modifié le 18 décembre 2024 (démarche de projet, étude de cas) — https://pedagogie.ac-orleans-tours.fr/spip.php?article1222

> Rappel de calendrier : l'ancien programme (BO n° 31 du 30 juillet 2020) reste en vigueur en classe de 3e jusqu'à la fin de l'année scolaire 2025-2026 ; le programme 2024 s'applique à la 3e à compter de la rentrée 2026-2027.
