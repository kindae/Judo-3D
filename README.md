# Judo 3D — prototype Godot 4 natif pour Android

Jeu de judo en 3D, **indépendant des autres jeux**, écrit en **GDScript** avec
**Godot 4.7.2**. Rendu 3D natif (moteur *Mobile*, repli automatique sur *Compatibility*
/ OpenGL ES 3 pour les appareils sans Vulkan fiable). Aucun HTML, JavaScript ni WebView,
fonctionnement 100 % hors ligne, aucune permission Android demandée.

Objectif secondaire : comparer les performances d'un jeu Godot natif avec les jeux
JavaScript exécutés dans une WebView. La surcouche de mesures (voir plus bas) sert à ça.

## État du prototype (étape 13 du cahier des charges)

| Élément | État |
|---|---|
| Tatami réglementaire 8 × 8 m + 3 m de sécurité, dojo, gradins, décor | fait |
| Deux judokas 3D (squelette 65 os), judogi blanc / bleu, ceinture personnalisable | fait |
| Caméra 3ᵉ personne (suivi, distance auto, recentrage pendant les projections, ralenti ippon) | fait |
| Déplacements (suri-ashi avant / arrière / latéral), saisie, kuzushi | fait |
| Technique : **O-soto-gari** (conditions, endurance, fenêtre de défense, animations tori/uke synchronisées) | fait |
| Ne-waza : **Kesa-gatame** (osaekomi, toketa) | première version |
| IA (3 difficultés), commandes tactiles + clavier | fait |
| Règles FIJ : 4 min, ippon / waza-ari / yuko, osaekomi, shido de sortie, hansoku-make, golden score | fait |
| Combat rapide, entraînement, sélection de difficulté, réglages graphiques | fait |
| O-goshi, Ippon-seoi-nage, De-ashi-barai, Ko-uchi-gari, Uchi-mata, Tai-otoshi | **à faire** (déclarées dans `scripts/fighter/technique.gd`, sans animation) |
| Carrière, tournois, progression par ceintures | **à faire** (architecture prévue : `Game.Mode`, `Game.profile_data`) |
| Sons (arbitre, chutes, public) | **à faire** |
| Ombres précalculées (lightmaps) | **à faire** (voir « Limites ») |

## Commandes

| Action | Tactile | Clavier |
|---|---|---|
| Se déplacer | joystick (moitié gauche de l'écran) | ZQSD / WASD / flèches |
| Saisir | SAISIR | J |
| Projeter (technique adaptée au déséquilibre) | PROJETER | K |
| Défendre (maintenir) / casser la saisie / se dégager au sol (tapoter) | DÉFENSE | L |
| Technique spéciale (plus coûteuse, plus efficace) | SPÉCIAL | I |
| Immobiliser (contextuel, après une projection) | IMMOBILISER | U |
| Pause | bouton II | Échap / P |
| Mesures de performance | Réglages | F3 |

Principe : saisir, **pousser** l'adversaire (joystick vers lui) pour le déséquilibrer vers
l'arrière (jauge « Déséquilibre adverse », zone rouge), puis projeter avec O-soto-gari.
Plus le déséquilibre est grand et l'endurance haute, meilleur est le score. Défendre au bon
moment (fenêtre de 0,38 s) bloque l'attaque.

## Règles appliquées

Vérifiées dans les *IJF Sport and Organisation Rules — Refereeing Rules* (version publiée en
juillet 2026, fichier `IJF_SOR_Refereeing_Rules`) :

- combat de 4 minutes de temps réel (le chronomètre s'arrête à « mate ») ;
- ippon = victoire immédiate ; deux waza-ari = ippon (*waza-ari-awasete-ippon*) ;
- yuko : se compte (1, 2, 3…) mais ne s'additionne pas en waza-ari ;
- osaekomi : 5-9 s yuko, 10-19 s waza-ari, 20 s ippon ; si le temps expire pendant un
  osaekomi, il continue jusqu'à toketa ou au score ;
- shido pour sortie de l'aire de combat ; 3ᵉ shido = hansoku-make ;
- égalité de scores techniques : golden score sans limite de temps, scores et shido
  conservés, premier score technique gagnant ; en golden score, 5 s d'osaekomi = yuko et fin.

Simplifications du prototype : la qualité d'une projection (ippon / waza-ari / yuko) est
calculée à partir du déséquilibre, de l'endurance et de la défense — l'atterrissage animé
est le même quelle que soit la note. Seule la sortie de tatami donne un shido (pas encore
de shido pour passivité, saisies illégales, etc.).

## Compiler

Prérequis : Godot **4.7.2** + modèles d'export 4.7.2, JDK 17 ou 21, SDK Android
(`platforms;android-35`, `build-tools;35.0.1`).

```bash
# 1. Importer le projet (une fois)
godot --headless --path . --import

# 2. APK de test (signé avec la clé de debug Android)
godot --headless --path . --export-debug "Android APK" build/judo3d-debug.apk

# 3. APK release et AAB (le préréglage AAB utilise Gradle : téléchargements au 1er passage)
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/chemin/vers/ma-cle.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=mon_alias
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=mon_mot_de_passe
godot --headless --path . --export-release "Android APK" build/judo3d.apk
godot --headless --path . --install-android-build-template --export-release "Android AAB" build/judo3d.aab
```

Les chemins du SDK et du JDK se règlent dans les paramètres de l'éditeur
(`export/android/android_sdk_path`, `export/android/java_sdk_path`), ou dans
`~/.config/godot/editor_settings-4.7.tres` en ligne de commande.

Sur GitHub : *Actions > « Judo 3D Android » > Run workflow* fabrique l'APK et l'AAB
(clé de debug générée à la volée si les secrets `JUDO3D_KEYSTORE_*` ne sont pas définis).
**Ne jamais publier sur le Play Store avec la clé de debug.**

Installation sur un téléphone : `adb install -r build/judo3d-debug.apk`, ou copier l'APK
sur le téléphone et autoriser l'installation depuis cette source.

## Architecture

```
./
  project.godot, export_presets.cfg
  assets/characters/judoka.glb   modèle généré (corps CC0 + judogi + ceinture + 2 coiffures)
  assets/animations/hand_poses.json  pose des doigts (extraite d'une animation CC0)
  assets/textures/               textures CC0 1K (ambientCG)
  scenes/main_menu.tscn, match.tscn
  scripts/
    autoload/settings.gd   profils graphiques, FPS, difficulté, sauvegarde
    autoload/game.gd       navigation, modes, pause en arrière-plan
    core/match.gd          déroulement du combat (phases, saisies, projections, ne-waza)
    core/scoreboard.gd     règles de score FIJ
    fighter/fighter.gd     judoka : modèle, matériaux partagés, locomotion, endurance, kuzushi
    fighter/pose_solver.gd poses clés -> squelette (cinématique inverse bras/jambes)
    fighter/judo_anims.gd  toutes les animations de judo (générées au lancement, ~50 ms)
    fighter/technique.gd   base de données des techniques
    ai/ai_controller.gd    IA (facile / normale / difficile)
    camera/match_camera.gd caméra
    env/dojo.gd            dojo, tatami, éclairage, environnement
    input/player_controller.gd, ui/*  clavier, tactile, HUD, menus, mesures
  tools/                   scripts de génération et de test (exclus de l'export)
```

Ajouter une technique : écrire les deux séquences `xxx_tori()` / `xxx_uke()` dans
`judo_anims.gd` (mêmes instants clés, uke placé à `GRIP_DIST` face à tori), les enregistrer
dans `build_library()`, puis renseigner `anim_tori`, `anim_uke` et `implemented = true` dans
`technique.gd`. Le choix de la technique selon la direction du déséquilibre se fait dans
`Match.on_action()`.

Régénérer le modèle des judokas :
`blender -b --python tools/blender/build_judoka.py -- "<dossier Universal Base Characters[Standard]>" assets/characters/judoka.glb`
puis `python3 tools/fix_imports.py` et réimporter.

## Optimisation

- 60 FPS par défaut, mode économie d'énergie à 30 FPS ; 5 FPS et pause automatique quand
  l'application passe en arrière-plan.
- Profils Faible / Moyen / Élevé : résolution interne 67 / 85 / 100 %, FXAA ou MSAA 2×,
  ombres dynamiques désactivées en Faible (ombres de contact conservées), halo lumineux,
  lumière d'appoint seulement en Élevé, détails de texture.
- Une seule lumière avec ombres (orthogonale, courte distance) ; seuls les judokas
  projettent des ombres ; le décor n'en projette pas.
- Tatami de 98 dalles dessiné en un seul appel (MultiMesh). Matériaux partagés et mis en
  cache, textures 1K compressées (ETC2/ASTC) avec mipmaps.
- Collisions simplifiées : distance entre deux cercles au sol, aucune physique.
- Judoka : ~17 700 triangles affichés, peau cachée par le judogi supprimée du maillage.

## Mesures de performance

Voir la section « Mesures réelles » ci-dessous : seules les valeurs effectivement mesurées
y figurent. **Les FPS sur téléphone restent à mesurer** : activer *Réglages > Mesures de
performance* (ou F3), jouer 1 minute, et noter les valeurs affichées ; elles sont aussi
écrites dans le journal toutes les 10 s (`adb logcat -s godot | grep PERF`).

## Mesures réelles

Mesurées le 25/11/2026 dans le conteneur de développement, **sans GPU** : rendu logiciel
(Mesa Lavapipe/llvmpipe sur CPU), 1280 × 720, combat CPU contre CPU (`tools/capture.gd`),
30 s par profil. Les temps d'image **ne représentent pas un téléphone** (le rendu logiciel
est bien plus lent qu'un GPU mobile) ; les appels de dessin et primitives, eux, dépendent
de la scène et non du matériel.

| Moteur / profil | Appels de dessin (moy. / max) | Primitives (moy. / max) | VRAM | Temps d'image (rendu logiciel) |
|---|---|---|---|---|
| Mobile · Faible | 108 / 126 | 35 942 / 38 795 | 50 Mo | 67,5 ms |
| Mobile · Moyen | 136 / 150 | 68 785 / 72 346 | 75 Mo | 133 ms |
| Mobile · Élevé | 133 / 145 | 70 559 / 71 382 | 90 Mo | 133 ms |
| Compatibility · Moyen | 135 / 150 | 68 362 / 72 020 | 45 Mo | 103 ms |

Autres valeurs mesurées :
- génération des 25 animations au lancement : 20 à 51 ms (selon la charge du CPU) ;
- taille : APK release arm64 **50,3 Mo**, APK debug 52,2 Mo, AAB (arm64 + armv7) 68,4 Mo.
  L'essentiel est le moteur (`libgodot_android.so`, 71 Mo non compressé) ; les ressources
  du jeu pèsent environ 15 Mo. Une version du moteur compilée sans les modules inutiles
  réduirait nettement la taille.

Pistes d'optimisation identifiées : les ombres doublent les primitives (les judokas sont
redessinés dans la carte d'ombres) ; ~100 appels de dessin viennent du décor construit en
petites boîtes (quadrillage des shoji, gradins), à fusionner en un seul maillage statique.

**Non mesuré** : FPS, température et autonomie sur un vrai téléphone Android — aucun
appareil ni émulateur n'est disponible ici. À faire avec la surcouche de mesures.

## Licences et crédits

- Personnages : *Universal Base Characters* (version Standard gratuite) — Quaternius,
  **CC0 1.0** (domaine public). Le judogi et la ceinture sont générés à partir de ce maillage
  par `tools/blender/build_judoka.py`.
- Pose des doigts : extraite de *Universal Animation Library* (Standard) — Quaternius, **CC0 1.0**.
- Textures : ambientCG (WoodFloor051, Plaster001, Tatami001, Fabric086, Wood097,
  Paper006) — **CC0 1.0**.
- Animations de judo : créées pour ce projet (poses clés + cinématique inverse).
- Moteur : Godot Engine, licence MIT.
