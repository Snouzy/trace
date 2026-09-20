# Trace — todo

## Fait

- [x] `./build.sh` compile sans erreur ni warning, cible macOS 12, mode Swift 6, bundle 200 Ko
- [x] Règles Swift dans `.claude/rules/swift.md`
- [x] Couleurs 1-5 et épaisseur [ ] par code de touche physique (AZERTY)
- [x] `mouseDragged` : plus de copie du tableau de points à chaque ajout
- [x] Raccourci global configurable, libellé selon la disposition clavier
- [x] Dépôt git local + dépôt privé `Snouzy/trace` (rien de commité ni poussé)
- [x] Outil ligne (L), flèche façon CleanShot « Standard » (A) : rendu hors écran vérifié
- [x] Maj : trait droit par pas de 45° pour main levée, surligneur, ligne, flèche : rendu hors écran vérifié
- [x] Étiquette d'une seconde sous l'icône à chaque raccourci : rendu vérifié, position sous l'icône non vérifiée
- [x] Paramètres : une ligne par outil + fondu, touche modifiable ; refus des doublons, de 1-5, de [ ], de ⌘/⌃/⌥, d'Espace : testé
- [x] Outil sélection (V) : sélectionner, déplacer, supprimer ; protégé du fondu ; testé hors écran en six étapes
- [x] Main levée sur T, texte sur E
- [x] Maj : carré et cercle parfaits, au tracé et au redimensionnement : testé hors écran
- [x] Surligneur : couleur propre, jaune par défaut ; 1 à 5 change la couleur de l'outil actif : testé hors écran
- [x] Sélection : poignées (extrémités, coins, taille du texte), double-clic pour modifier un texte, 1 à 5 et [ ] sur l'élément sélectionné : testé hors écran en neuf étapes
- [x] Maj en déplaçant : un seul axe : testé hors écran
- [x] Flèches courbes : point de courbure par segment, ajout en tirant, retrait au double-clic, queue effilée qui suit la courbe : testé hors écran
- [x] `README.md` en anglais sur le modèle d'Annotate, `CLAUDE.md` traduit en anglais
- [x] README : tableau comparatif avec Annotate 1.6.0, mesuré ; `CLAUDE.md` : règle « Keep this file current »
- [x] Q (modifiable) et pastille poubelle suppriment l'élément sélectionné : testé hors écran
- [x] Dépôt GitHub : description en anglais, neuf mots-clés
- [x] Rotation de tous les éléments par la pastille ↻, Maj par pas de 15°, redimensionnement d'un élément pivoté sans saut : testé hors écran en onze étapes

## À vérifier à la main

- [ ] Raccourci global depuis n'importe quelle app, y compris plein écran
- [ ] Paramètres : changer une touche d'outil, elle marche dans l'overlay et survit à un redémarrage
- [ ] Paramètres : fermer la fenêtre pendant l'écoute, le raccourci global revient
- [ ] Sélection : cliquer près d'un trait fin le prend bien (tolérance 8 px), déplacer ne laisse pas de pixels fantômes
- [ ] Poignées : faciles à attraper (8 px), redimensionner ne laisse pas de pixels fantômes
- [ ] Double-clic sur un texte : le champ s'ouvre au même endroit, sans saut visible
- [ ] Pastille ↻ : facile à attraper (10 px), ne gêne pas la poignée du coin bas droit
- [ ] Points de courbure : faciles à attraper, une flèche très courbée garde une queue propre
- [ ] Texte pivoté modifié au double-clic : il revient pivoté, avec un léger décalage si sa longueur change (connu)
- [ ] Clics captés sur les zones transparentes
- [ ] Chaque outil dessine, texte compris (saisie, Entrée, Échap)
- [ ] L'étiquette apparaît bien sous l'icône crayon, et disparaît après 1 s même pendant un tracé
- [ ] Maj en cours de tracé à main levée : pas de pixels fantômes de l'ancien tracé
- [ ] Multi-écran : un overlay par écran, le clavier suit l'écran cliqué
- [ ] Échap rend le focus à l'app précédente
- [ ] Fondu : les traits s'effacent, le minuteur s'arrête

## Mémoire

- [x] Après lancement : 12 Mo (Annotate 1.6.0 au même instant : 38 Mo)
- [ ] Après une session de dessin, overlay fermé : 41 Mo juste après la fermeture, 27 Mo une minute plus tard. Ne retombe pas à 12 Mo. Le gros est du tas (`MALLOC_SMALL`, 15 Mo). À expliquer : `heap Trace`, `vmmap --summary Trace`, puis `leaks Trace`
- [ ] `footprint -p Trace` et `vmmap --summary Trace` : overlay ouvert, ouvert après des traits sur tout l'écran, refermé
- [ ] `heap Trace | grep -E "OverlayWindow|Canvas"` et `leaks Trace` après fermeture

## Décisions ouvertes

- [ ] Release `v0.1.0` : `release.sh` est prêt (build universel, signature, DMG, notarisation, `gh release create`), testé jusqu'au contrôle du certificat. Il manque, côté Mathias : le certificat « Developer ID Application » et le profil `notarytool` nommé `trace-notary`. Après la première release : ajouter « Download Release » au README
- [x] Identifiant du bundle : `com.snouzy.trace` (avant : `local.trace`), changé avant la première release. Ne plus le changer ensuite

- [ ] `main.swift` fait 1020 lignes pour une limite d'environ 600. Un second fichier fait apparaître de fausses erreurs SourceKit dans l'éditeur (pas de projet Xcode ni de Package). Choix : relever la limite, ou scinder et accepter les fausses erreurs
- [ ] `CAShapeLayer` par trait au lieu de `draw(_:)` : 10 Mo au lieu de 154 Mo écrans pleins (mesure de l'agent, pas vérifiée), change l'architecture
- [ ] Surligneur : j'ai compris « gérer la couleur simplement » comme « une couleur propre au surligneur ». Si c'était une palette cliquable à l'écran, c'est un autre chantier
- [ ] Ombre portée sous la flèche, comme CleanShot (coût : zone de redessin plus large)

## Écarts connus avec `.claude/rules/swift.md`

- [ ] Fondu : le minuteur tourne pendant les 3 s d'attente (environ 90 tics sans rien dessiner)
- [ ] `extent(of:)` reconstruit un `NSBezierPath` à chaque passe ; stocker l'emprise du trait fini
