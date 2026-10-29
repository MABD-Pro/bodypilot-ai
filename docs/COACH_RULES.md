# Règles du coach (lot 1, 100 % local)

Tout est déterministe et calculé sur l'appareil. Aucun appel IA.

## Questionnaire de santé (`BodyPilotCore/HealthScreening`)

- À l'inscription (étape « Ta santé »), 7 questions par oui ou non, inspirées du PAR-Q+ (Warburton et al., 2011) : problème cardiaque ou hypertension, douleur à la poitrine, vertige ou perte de connaissance, autre maladie chronique, traitement chronique, problème d'os, d'articulation ou de tendon, sport sous surveillance médicale seulement. Les profils créés avant voient un bandeau sur l'écran Aujourd'hui, une seule fois, sans blocage.
- Un oui ne bloque rien. Tant que l'accord du médecin n'est pas noté (« Mon médecin m'a donné son accord… », dans Mon profil) : ni test de force, ni test de cardio, ni fractionné du cycle, ni séance dure de l'Hyrox, ni série au maximum ; la séance de force est allégée comme en cas de fatigue (une série de moins, sans impact, 3 répétitions en réserve), avec une note qui le dit. Pas de nouveau cycle de 12 semaines. Le dépistage de l'ACSM (Riebe et al., 2015) réserve lui aussi l'effort intense à l'accord médical quand une maladie est connue.
- Situations sans déficit : grossesse ou allaitement (femmes), trouble alimentaire actuel ou passé, moins de 18 ans (d'après l'âge). Les calories restent à l'équilibre, les bilans ne proposent jamais de baisse et une correction passée ne s'applique plus en dessous de l'équilibre. Le coach renvoie vers un professionnel de santé pour un objectif de poids.
- Tout reste sur l'iPhone, dans le profil (schéma V2) et la sauvegarde.

## Besoins nutritionnels (`Nutrition/EnergyCalculator`)

- Métabolisme de base : Mifflin-St Jeor. Dépense = métabolisme × facteur de la vie quotidienne hors sport (1,2 / 1,3 / 1,4 / 1,55, choix BodyPilot) + dépense des séances faites (`ProgressInsights/ExerciseEnergy`).
- Pas mesurés (`BodyPilotCore/DailySteps`) : dès 7 jours de pas lus dans Santé sur les 14 précédents (aujourd'hui exclu, jours à 0 écartés), la moyenne remplace le niveau déclaré : moins de 5 000 → 1,2 ; 5 000 à 7 499 → 1,3 ; 7 500 à 9 999 → 1,4 ; 10 000 et plus → 1,55 (paliers de Tudor-Locke et Bassett, 2004). Les pas des entraînements à pied de Santé, déjà comptés en calories, sont retirés (environ 110 pas/min en marche, 160 en course) : pas de double comptage. Limite : une séance seulement cochée dans l'app (sans enregistrement Santé) garde ses pas. L'explication des besoins le dit juste après la dépense, moyenne arrondie à la centaine. Siri et Raccourcis gardent le niveau déclaré.
- Objectif de pas (Progresser, Santé reliée) : la moyenne + 1 000, arrondie aux 500 du dessus, sans dépasser 10 000 avant 60 ans ni 8 000 ensuite ; sans moyenne, 8 000 ou 6 000. La mortalité baisse jusqu'à 8 000 à 10 000 pas avant 60 ans et 6 000 à 8 000 ensuite (Paluch et al., 2022). La hausse de 1 000 est un choix BodyPilot.
- Séances : moyenne par jour des 14 jours précédents, plafonnée à 600 kcal. Un jour avec des entraînements dans Santé compte leurs calories actives. Un jour avec seulement une séance cochée est estimé par MET (Compendium, Ainsworth 2011) : (MET − 1) × poids × durée, avec force 5, cardio 6, marche 3,5. Jamais compté deux fois. Le déficit s'applique sur ce total. Siri et Raccourcis ne lisent pas Santé : ils ne comptent que les séances cochées.
- Dépense mesurée (`ProgressInsights/EnergyBalance`) : chaque journée dont les quatre repas sont notés (pris, sautés, plus ou moins copieux, décrits) garde ses calories mangées (`DayLogRecord.eatenKcal`, schéma V3). Sur les 21 jours précédents, avec au moins 10 journées complètes et 6 pesées étalées sur 14 jours : dépense = apport moyen − pente des pesées × 7 700 kcal/kg (Hall et al., 2011, pour l'adaptation de la dépense ; 7 700 kcal/kg reste une approximation sur quelques semaines). Elle se mêle à l'équation au prorata des journées complètes (toute la place à 21), reste dans ±25 % de l'équation (au-delà, plutôt un oubli de saisie, choix BodyPilot), et les corrections des bilans s'effacent dans la même proportion : la mesure les remplace. Sans saisie des repas, rien ne change.
- Objectif unique : la **recomposition** (perdre du gras en gardant ou en gagnant du muscle). L'utilisateur ne choisit pas entre perdre du poids et prendre du muscle.
- Phase choisie par le coach (`BodyPilotCore/BodyPhase`), recalculée chaque jour sur le poids lissé :
  - **Équilibre** sans condition en cas de grossesse, d'allaitement, de trouble alimentaire ou avant 18 ans.
  - **Légère prise** si l'IMC est sous 18,5 (jamais de déficit) ou si le poids visé dépasse le poids actuel de plus de 0,5 kg : 10 % de surplus, plafonné à 300 kcal, pour une prise de 0,25 à 0,5 % du poids par semaine (Iraki et al., 2019). Le bilan propose +150 kcal si le poids ne monte plus depuis deux semaines.
  - **Perte de gras** si le poids visé est plus bas de plus de 0,5 kg : déficit ci-dessous.
  - **Équilibre** à 0,5 kg du poids visé.
  - Sans poids visé : perte de gras si le tour de taille atteint la moitié de la taille (Ashwell et al., 2012), sinon si le taux de gras de la balance atteint 25 % (homme) / 32 % (femme), sinon si l'IMC atteint 25 ; équilibre sinon.
  - La phase s'affiche dans Progresser à côté du poids visé, et une phrase l'explique dans les besoins du jour.
- Déficit selon l'écart au poids visé : 20 % à 10 kg ou plus, proportionnel en dessous (5 % au minimum), aucun à moins de 0,5 kg du poids visé. Sans poids visé : 10 %. Plafonné à 600 kcal. **Plancher** : jamais sous le métabolisme de base, ni sous 1 500 kcal (homme) / 1 200 kcal (femme). Pas de surplus en perte de gras.
- Protéines : 2,0 g/kg dans toutes les phases (au-dessus du plateau de 1,6 g/kg, Morton et al., 2018 ; dans la fourchette conseillée en déficit, Helms et al., 2014, Int J Sport Nutr Exerc Metab). Au-delà d'un IMC de 30, calculées sur le poids à IMC 30 (plafond continu : un kilo de plus ne fait jamais baisser l'objectif).
- Lipides : 27 % des calories. Glucides : le reste.
- Le poids utilisé est la **tendance mesurée** dès qu'elle existe, sinon le poids déclaré.

## Repas du jour (`Nutrition/MealPlanner`)

- Répartition : petit-déjeuner 25 %, déjeuner 35 %, collation 10 %, dîner 30 %.
- Protéines : 30 % du total du jour au petit-déjeuner, au déjeuner et au dîner, 10 % à la collation. Avec 2 g/kg, chaque repas principal dépasse 0,4 g/kg (Schoenfeld et Aragon, 2018). « Pas faim » ne réduit pas les protéines. Un repas allégé ou agrandi pour compenser garde sa proportion de protéines.
- Modèles de repas tournants (variété sans saisie), portions ajustées entre ×0,5 et ×2, arrondies à 5 g ou à l'unité (œufs, fruits). Les sources de protéines (au moins 30 % de leurs calories en protéines : viande, poisson, œufs, skyr, tofu, lentilles…) sont dosées pour l'objectif de protéines du repas, les accompagnements (×0,4 à ×2) pour les calories. Les calories passent avant si les deux ne tiennent pas ensemble.
- Valeurs nutritionnelles : moyennes arrondies, ordre de grandeur Ciqual. À remplacer par une vraie base.
- « Je mange au restaurant » : le prochain repas principal (déjeuner avant 15 h, dîner ensuite) devient « Au restaurant » avec quatre repères (protéine, légumes, une portion de féculents, un seul extra parmi sauce, dessert ou alcool). La collation est supprimée et son budget va au restaurant.
- « Je n'ai pas faim » : 85 % des calories, sans descendre sous le plancher de sécurité, collation dense en protéines.

## Repas pris (`Nutrition/MealPlanner`)

- Pour chaque repas, une touche : « Mangé comme prévu », ou bien sauté, plus léger (×0,6), plus copieux (×1,4), beaucoup plus copieux (×1,8). Pas de pesée ni de calcul.
- Les repas restants se recalculent pour viser le total du jour, dans une limite de ×0,6 à ×1,4 : on ne saute pas un repas pour compenser un excès, on ne double pas le dîner après un déjeuner sauté.
- Le coach le dit en une phrase, sans culpabiliser : une journée ne fait pas la tendance.

## Repas décrit en texte (`Nutrition/MealTextParser`, `Nutrition/MealDescriber`)

- « Décrire » sur un repas : l'utilisateur écrit ce qu'il a mangé, comme il le dirait (« une grande assiette de pâtes carbo et un coca »).
- Lecture locale d'abord : un catalogue de 81 aliments et plats courants (dont le petit-suisse, 60 g), les quantités en grammes ou en millilitres (« 200 g », « 33 cl »), en unités (« 2 œufs »), en contenants (« un bol », « une assiette », « une tranche ») et en tailles (« petite », « grande », « demi »).
- Aliment absent de ce catalogue : la table Ciqual 2025 de l'ANSES, embarquée (environ 3 300 aliments, valeurs pour 100 g, Licence Ouverte ; `Nutrition/CiqualMatcher`, table générée par `scripts/ciqual/build.py` depuis la branche `ci/ciqual` que remplit le workflow « Ciqual »). Tous les mots de l'aliment doivent figurer dans le nom Ciqual ; à égalité, le nom le plus générique gagne (« aliment moyen », « nature »), sans variante allégée ni forme sèche ou à cuire sauf si elles sont écrites. Quantité : grammes écrits, sinon contenant (« un bol » = 300 g), sinon le poids d'une pièce pour les fruits et légumes courants (« une mangue » = 220 g, choix BodyPilot), sinon 100 g à confirmer. Les entrées génériques du catalogue (Fromage, Fruit, Légumes, Poisson) gardent leur portion, mais un nom précis (« comté », « épinards ») prend le nom et les valeurs Ciqual. « Yaourt grec » = yaourt à la grecque du commerce ; le 0 % seulement s'il est écrit.
- Sans quantité, la portion habituelle est proposée et le coach demande « Quelle quantité ? » : petite (×0,7), normale ou grande (×1,4). La question ne bloque pas l'enregistrement.
- Aliment inconnu du catalogue : le modèle Apple embarqué l'estime (jamais le cloud), dans des bornes réalistes (portion de 1 g à 1,5 kg, densité sous 900 kcal/100 g, calories recalculées depuis les macros si elles se contredisent). Le modèle donne des valeurs pour 100 g et choisit un type de portion dans une liste fermée (pot 125 g, bol ou assiette 300 g, part 150 g, pièce 100 g, verre 200 g, tranche 35 g, poignée 30 g, cuillère 15 g), l'app fait le calcul et plafonne la densité selon la portion (verre 100, bol 150, pot 200, assiette 300, part 350, pièce 400, tranche 450, poignée 650 kcal/100 g ; le modèle a donné jusqu'à 850 kcal/100 g pour un tajine) ; une quantité écrite par l'utilisateur (« 120 g de … ») remplace la portion choisie par le modèle. Sans modèle disponible, le coach demande de préciser les aliments.
- Photo (appareil photo ou photothèque), analysée sur l'iPhone et non conservée. Avec iOS 27, si le modèle embarqué voit les images, il décrit le repas en une phrase. Sinon, le classifieur d'images de Vision donne des étiquettes (environ 90 aliments), traduites en français (`PhotoLabelReader`, confiance d'au moins 30 %, 4 aliments au plus). La phrase préremplit la saisie : l'utilisateur la corrige, puis le coach demande les portions. Jamais de cloud.
- Le repas décrit remplace le repas prévu et la saisie d'une touche. Les repas suivants s'ajustent comme pour un repas pris (×0,6 à ×1,4).
- La carte Manger affiche, pour chaque macro, ce qui a été mangé sur l'objectif du jour, ainsi que les calories restantes.

## Reprendre et améliorer un repas (`Nutrition/MealImprover`)

- « Reprendre » : les repas décrits des 7 derniers jours (aujourd'hui exclu), ceux du même moment de la journée d'abord, du plus récent au plus ancien, sans doublon de titre, 8 au plus.
- Plus léger : l'échange qui fait gagner le plus, s'il gagne au moins 50 kcal (frites → pommes de terre, soda → soda zéro, jus → fruit, carbonara → bolognaise, viennoiserie → pain complet, céréales → flocons d'avoine, saucisse → poulet, biscuits → fruit, glace → skyr ; sauce et fromage : moitié moins).
- Plus de protéines : sous 20 g (12 g en collation), un skyr au petit-déjeuner et en collation, 100 g de poulet au déjeuner et au dîner, ou un skyr si le plat a déjà sa source de protéines (≥ 15 g / 100 g).
- Une suggestion de chaque au plus ; elle s'applique d'une touche dans la feuille « Décrire ».

## Séance du jour (`Training/TrainingPlanner`)

- Au jour le jour, sans planning : chaque jour, le coach propose 2 ou 3 activités et le repos, en recommande une et dit pourquoi ; l'utilisateur choisit d'une touche (le choix vaut pour la journée). Propositions : force (seulement si la dernière séance de force, cochée dans l'app ou renforcement d'au moins 20 min dans Santé, date d'au moins 48 h, ou s'il n'y en a jamais eu : full body lourd A puis B, ou test de force), « Cardio et marche inclinée » (à la maison « en côte » : cardio continu modéré et sans impact, puis marche inclinée), marche tranquille de 30 min, repos.
- Recommandation, dans l'ordre : séance ratée → marche tranquille ; 6 jours d'activité d'affilée (app ou Santé, 20 min au moins) → repos ; fatigue et nuit de moins de 6 h (sommeil lu dans Santé) → repos ; nuit de moins de 6 h → cardio et marche (marche tranquille si la force date de moins de 48 h) ; courbatures → cardio et marche ; force possible → force ; séance intense de 45 min ou plus la veille dans Santé (fractionné, cours, sport, combat, course) → marche tranquille ; sinon cardio et marche.
- « Comment te sens-tu ? » en tête de la carte Bouger : En forme, Courbatures, Fatigué. Fatigué est le même ajustement que « Je suis fatigué » (séance allégée) ; changer de ressenti revient à la recommandation du coach.
- Fondements scientifiques et références : `docs/TRAINING_EVIDENCE.md`.
- Chaque séance enchaîne trois axes : musculation lourde en full body (A et B alternés : à la salle 4 × 5 à 8 répétitions sur les polyarticulaires, repos 2 à 3 min ; au poids du corps, variantes difficiles et tempo lent), puis un cardio varié qui change d'une séance à l'autre (rameur, vélo, corde, elliptique ; à la maison burpees, mountain climbers, jumping jacks, boxe), puis la marche inclinée ou l'escalier (tapis 10 à 12 %, stepper ; à la maison côte ou escaliers), qui sert aussi de retour au calme.
- Répartition : 60 % du temps pour la force, le reste partagé entre cardio et marche. Sous 30 minutes, la force seule.
- Compléments d'isolation (hors cycle, `WorkoutCatalog.accessories`) : après la force, 2 séries courtes (12 à 20 répétitions, repos 45 s) sur ce que les polyarticulaires travaillent peu. Salle : A → élévations latérales et curl, B → extension triceps à la poulie et mollets ; maison : A → pompes pike et mollets, B → pompes diamant et rowing serviette. Ils s'ajoutent tant que le cardio et la marche gardent 12 min et que les mouvements principaux gardent 3 séries (sinon seul l'équilibre des seniors reste), et partent en premier quand le temps manque.
- À partir de 60 ans ou d'un IMC de 30 (poids de départ), hors cycle : séries de 10 au lieu de 5 à 6, consigne de charge modérée (8 à 12 répétitions) et note dans la séance. À partir de 65 ans : « Équilibre sur une jambe » en premier complément et consigne de puissance (monter vite, redescendre en 3 s).
- Sommeil moyen des 7 dernières nuits (au moins 4 mesurées) sous 7 h, avec une nuit passée correcte : la raison du jour le signale, sans changer la séance. La nuit de moins de 6 h garde sa règle.
- « Je n'ai que 20 minutes » : on raccourcit les repos, puis l'échauffement, puis les séries, puis on retire les accessoires. Les exercices essentiels restent. Sous 12 minutes, marche rapide.
- « Je suis fatigué » : une série de moins (minimum 2), variantes sans impact, effort modéré. Nutrition inchangée.
- « J'ai mal au genou » : variantes sans flexion chargée ni impact (pont fessier, hip thrust, bird dog…), et conseil de consulter si la douleur est vive, gonfle ou dure. Jour de cardio : la marche en pente devient une marche à plat (ou vélo à la salle).
- « Je pars en déplacement » : séance au poids du corps, 30 minutes maximum.
- « J'ai raté ma séance » : jamais deux séances le même jour. Une marche tranquille le jour même ; la force non faite revient dès le lendemain, puisque la dernière force date toujours d'au moins 48 h.
- « Machine prise, pas de barre » : chaque exercice a deux ou trois variantes du même mouvement, avec le même matériel. Une touche passe à la variante suivante, puis revient à l'exercice d'origine. Séries, volume et repos ne changent pas. Le choix vaut pour la journée. Les règles de sécurité restent prioritaires : avec un genou douloureux, une variante qui charge le genou est remplacée par la version qui l'épargne, et celle-ci ne se remplace pas.

## Cycle de 12 semaines (`BodyPilotCore/Cycle`, `Training/StrengthCycle`)

- Choisi par l'utilisateur (salle) depuis la carte Bouger, objectif CrossFit ou Hyrox (plans validés par Mounaïm le 2026-10-28) ; commence le jour même.
- 3 phases de 4 semaines (base, puissance, conditioning) ; la 4ᵉ semaine de chaque phase est allégée. Après la 12ᵉ semaine, le cycle s'arrête et la carte propose d'en recommencer un.
- Mouvements principaux à la barre, avec charges (salle) : 5/3/1 de Wendler avec « First Set Last » (décision Mounaïm du 2026-10-28). Max d'entraînement = 90 % du max pondéré. Semaine 1 : 5 à 65 %, 5 à 75 %, 5+ à 85 % ; semaine 2 : 3 à 70 %, 3 à 80 %, 3+ à 90 % ; semaine 3 : 5 à 75 %, 3 à 85 %, 1+ à 95 % ; semaine allégée : 5 à 40, 50 et 60 %, rien au maximum. La série « + » se fait au maximum de répétitions propres en gardant 1 répétition en réserve (pas à l'échec) ; elle se note et recalcule le max (Epley plafonné à 12 répétitions), ce qui remplace la hausse du max d'entraînement à chaque cycle. Puis 5 × 5 à la charge de la première série (90 s de repos), sauf semaine allégée. Temps limité : les séries « First Set Last » passent à 3, puis disparaissent, avant que la vague ne soit touchée. Fatigue : la vague reste, sans série au maximum ni « First Set Last ». Variante choisie (remplacement) : la vague reste si elle se fait à la barre, sinon séries de 5 à la charge de la première série. Variante de sécurité du genou : jamais de vague (pas de série au maximum sur un genou douloureux). Charges à la barre par 2,5 kg, jamais sous 20 kg (barre vide) ; un exercice dérivé jamais noté prend le pourcentage du cycle sur son max dérivé.
- Autres mouvements principaux (priorité 1, sans barre ou sans charges) : semaine 1 : 3 × 6 à ~75 % du max, 3 répétitions en réserve ; semaine 2 : 4 × 6 à ~78 %, 2 en réserve ; semaine 3 : 4 × 5 à ~82 %, 1 en réserve ; semaine allégée : 2 × 5 à ~70 %, 4 en réserve. Exercices secondaires : 3 séries ; en semaine allégée, 2 séries à ~70 % du max. La semaine allégée raccourcit aussi la séance de force à 70 % du temps (au moins 30 min si le temps le permet) : le temps gagné ne part pas en cardio. Choix BodyPilot dans la fourchette de l'ACSM (2009) ; semaine allégée selon le consensus de Bell et al. (2023).
- Charge = pourcentage du max pondéré (`StrengthProgress.referenceOneRepMax`), arrondie aux disques en dessous ; elle remplace la surcharge progressive pendant le cycle. Le max se recalcule à chaque série notée : la phase suivante monte toute seule si la semaine 3 a progressé.
- Le coach du jour garde la main : fatigue, nuit courte, genou, temps limité et test de force passent avant le cycle. La note de la séance indique la semaine et la phase.
- Cardio du cycle (`Training/CycleCardio`) : les jours sans force, le premier cardio de la semaine du cycle est le fractionné (sans impact : rameur ou vélo, à la maison boxe dans le vide), si ni fatigue, ni courbatures, ni nuit de moins de 6 h ; les autres jours, aérobie continue à allure où l'on parle (zone de cardio modéré si connue), dans la limite du temps du jour. Le test de cardio passe avant.
- Séances par semaine (`CycleSessionPlan`, 2 à 6) : à chaque semaine du cycle, « Combien de séances cette semaine ? », préremplie avec la moyenne des 3 dernières semaines (jours actifs, app et Santé), sinon le dernier nombre choisi, sinon 4 ; une touche pour confirmer ou changer. Répartition : 2 → 2 forces avec le fractionné de la semaine en fin de séance (à la place du conditioning) ; 3 → 2 forces + fractionné ; 4 → 3 forces + fractionné ; 5 et 6 → + 1 ou 2 aérobies. Le coach recommande la force tant qu'il en manque (48 h entre deux), le cardio une fois les forces faites, une marche si la force attend 48 h et le cardio est fait, le repos une fois toutes les séances faites. Fatigue, nuit courte, courbatures, séance ratée et 6 jours d'affilée passent avant. Les séances comptées sont celles cochées dans l'app pendant la semaine du cycle.
- Cycle Hyrox (`Training/HyroxCycle`, document « Cycle de 12 semaines vers l'Hyrox ») : phases courir-marcher, courir en continu, courir fatigué. Force en rotation A / B (5/3/1 comme le CrossFit), suivie de 4 × 20 m de poussée (A) ou de tirage (B) de traîneau, 2 en semaine allégée. Répartition : 2 séances → 1 force + qualité ; 3 → 1 force + qualité + fondamentaux ; 4 → 2 forces + qualité + course facile (10 min d'ateliers en fin de force) ; 5 → 2 forces + qualité + fondamentaux + course facile ; 6 → + 1 course facile. Les jours de cardio : la séance de qualité d'abord si ni fatigue, ni courbatures, ni nuit de moins de 6 h, puis les fondamentaux, puis la course facile.
  - Course facile : semaines 1 à 4 en course-marche (8 × 1 min / 1 min 30 de marche, 7 × 2 min / 1 min 30, 6 × 3 min / 1 min, 5 × 3 min / 1 min), puis continue 20, 25, 30, 20, 30, 35, 40, 25 min (semaines 5 à 12), dans la limite du temps du jour. Course remplacée par le vélo en cas de fatigue ou de genou sensible.
  - Qualité : rameur 6 puis 8 × 2 min, SkiErg et rameur 5 × 3 min, vélo facile 20 min (semaine 4) ; 4, 5, 6 puis 3 × 1 km à allure Hyrox (2 min de récupération) ; course enchaînée 4 × (1 km + 1 atelier), demi-simulation 4 × (1 km + ateliers 1 à 4), 6 ×, puis 3 × en semaine 12. Semaines 1 et 11 : test 1 km + 50 wall balls + 1 km au chrono, noté comme le WOD de référence ; en semaine 1 (phase 1, pas de course dure), les 2 km se courent à allure soutenue mais contrôlée. Séance de cardio seule trop longue pour le temps disponible : elle perd des tours, jamais son échauffement (10 min), son retour au calme ni ses récupérations.
  - Fondamentaux : technique des ateliers à charge légère (phase 1 et semaine 12), tours de 200 m de marche du fermier, 50 m de fentes avec sac et 30 wall balls (2, 3, 3, 2 tours en phase 2), 100 wall balls en séries fixes (semaines 9 et 10), fentes et fermier à charge de course (semaine 11).
- Progression par semaine (aérobie / fractionné) : 1 : 30 min / 6 × 30 s-30 s ; 2 : 35 / 8 × 30-30 ; 3 : 40 / 10 × 30-30 ; 4 : 25 / 5 × 30-30 ; 5 : 40 / 3 × 3 min, récup 3 min ; 6 : 45 / 4 × 3 min ; 7 : 45 / 4 × 4 min ; 8 : 30 / 2 × 3 min ; 9 : 45 / 4 × 4 min ; 10 : 50 / 5 × 4 min ; 11 : 50 / 8 × 2 min-1 min ; 12 : 30 / pas de fractionné. Le fractionné perd des tours si le temps manque (au moins 2).
- Salle : rotation A / B / C pendant le cycle. Force C : phase 1 squat goblet, développé couché haltères, rowing haltère, gainage ; phase 2 squat avant, push press, tractions assistées, gainage ; phase 3 le gainage laisse la place au thruster léger. Les mouvements principaux suivent la semaine du cycle comme A et B.
- Fin de séance en salle : après la B, 10 minutes de technique (kettlebell swing 3 × 10 en phase 1, hang power clean 4 × 3 en phase 2, power clean 4 × 3 en phase 3, charges légères) ; après la A et la C, un conditioning sans saut à la place du cardio et de la marche : circuit rameur, kettlebell swings, step-ups (phase 1), EMOM swings et wall balls (phase 2), AMRAP wall balls, swings, rameur (phase 3). Durée par semaine : 8, 8, 10, 6, 10, 12, 12, 8, 12, 15, 15, 6 min. Genou sensible : rameur à la place. Le conditioning part en premier si le temps manque.
- WOD de référence (salle, semaines 11 et 12, à la place du fractionné) : « Helen » adaptée, 3 tours de 500 m de rameur, 21 kettlebell swings, 12 rowings aux anneaux, au chrono. Le temps se note dans la carte (`DayLogRecord.benchmarkSeconds`), comparé à la fois précédente.
- Fiches technique des nouveaux exercices ; vidéos à vérifier (recherche YouTube en attendant). Sauts et course restent exclus : les critères du plan (step-ups, corde à sauter) ne sont pas encore suivis dans l'app.

## Séance retouchée (`Training/SessionEdits`)

- Pour la journée : séries et répétitions (ou durée) par exercice, exercices retirés, exercices ajoutés parmi ceux qui ont une fiche (3 × 10, ou 3 × 1 min pour un atelier Hyrox). « Revenir à la proposition » efface tout ; changer de proposition aussi.
- 5/3/1 : la vague garde ses 3 séries, seules les séries « First Set Last » se règlent.
- Paliers (vague 5/3/1, test de force) : décalés ensemble de ± 2,5 kg à la barre (sinon le pas de charge), pour la journée seulement ; la prochaine charge part des séries vraiment notées.

## Séance sur l'Apple Watch (`Training/GuidedWorkout`)

- La séance envoyée est celle du jour, déjà adaptée (temps, fatigue, genou, déplacement).
- Chaque exercice devient un bloc répété autant de fois qu'il y a de séries : effort puis repos minuté.
- Une série en répétitions reste ouverte (on passe à la suite d'une touche) ; une série chronométrée et le repos ont une durée.
- Envoi via l'aperçu WorkoutKit : l'utilisateur confirme l'ajout sur sa montre, aucune autorisation supplémentaire.

## Records et charges (`Training/StrengthProgress`)

- Une touche sur un exercice de force aux répétitions note la meilleure série du jour (charge ou poids du corps, répétitions). Une seule par exercice et par jour : une nouvelle saisie remplace la précédente.
- Record : meilleur 1RM estimé (Epley, plafonné à 12 répétitions) ; au poids du corps, le plus de répétitions. Une série avec charge passe devant le poids du corps. Une première série n'est pas un record ; un record battu est fêté dans la carte Bouger et listé dans Progresser.
- Max de référence : le meilleur 1RM estimé de l'exercice, pondéré par son ancienneté au moment de la dernière séance de force, puis par la pause depuis cette séance (dernière série notée, séance cochée ou entraînement de force dans Santé). Même barème pour les deux : jusqu'à 21 jours 100 %, jusqu'à 6 semaines 95 %, jusqu'à 3 mois 90 %, au-delà 85 %. La force maximale se maintient environ 3 semaines sans entraînement (Bosquet et al., 2013) ; les paliers suivants sont un choix prudent.
- Objectif suivant : la plus haute des deux charges, celle tirée du max de référence (répétitions prévues plus 2 en réserve, arrondie vers le bas) et la progression de la dernière série (charge + ~5 % si elle a dépassé les répétitions prévues, sinon même charge ; pas de 2,5 kg, 1 kg sous 30 kg).
- Pause de plus de 3 semaines : charge tirée du max de référence seulement, sans hausse, et une note de reprise en tête de la séance de force. Plus de 3 mois sans force : le test de force revient, son premier essai part du max pondéré. Au poids du corps : une répétition de plus que la dernière fois, une fois les répétitions prévues atteintes.
- Effort ressenti (facultatif, une touche sous la série, hors test) : Facile (3 répétitions ou plus en réserve), Juste (1 à 2), Dur (aucune). Facile aux répétitions prévues → la charge monte sans attendre une répétition de plus ; Dur → la charge attend, et baisse d'un cran (~5 %) si la série n'est pas complète ; au poids du corps, Dur garde le même nombre de répétitions. Juste ou non noté : la règle habituelle. Pas pendant les vagues 5/3/1, qui fixent la charge par le cycle.
- Chaque variante (remplacement, genou) a ses propres records : le nom affiché sert de clé.
- Fiche exercice (`Training/ExerciseGuide`) : muscles travaillés et 4 consignes de technique pour chaque exercice de force du catalogue et ses variantes, dans la feuille de saisie. Pour les haltères, la charge notée est celle d'un haltère.
- Démonstration (`Training/ExerciseDemonstration`) : « Voir une démonstration » lit dans la fiche une vidéo YouTube choisie et vérifiée à la main, en français quand une bonne existe. Lecteur intégré youtube-nocookie (pas de cookies publicitaires tant que la vidéo n'est pas lancée), « Ouvrir dans YouTube » en secours. Sans vidéo choisie, « Chercher une démonstration » ouvre une recherche YouTube « <exercice> technique ». Aucune vidéo n'est stockée dans l'app.
- Charge d'essai (salle, avant toute série notée) : fraction prudente du poids du corps selon l'exercice et le sexe, arrondie vers le bas au pas de charge. Affichée « Essai : … » ; la première série notée la remplace.

## Calibrage des charges (`Training/StrengthCalibration`)

- À la salle, six mouvements de référence : squat, développé couché, rowing barre, soulevé de terre, développé militaire, tirage vertical à la poulie (pas de tractions). Tant que l'un d'eux n'a aucune charge notée, le jour de force devient un test.
- Deux séances de test, à 48 h d'écart : « Test de force 1/2 » (squat, développé couché, rowing) puis « 2/2 » (soulevé de terre, militaire, tirage vertical). Squat et soulevé de terre lourds ne se testent pas le même jour : les derniers mouvements seraient sous-estimés.
- Protocole par mouvement : 10 × 50 %, 5 × 70 %, 3 × 85 % du premier essai, puis séries de 5 en ajoutant ~10 % (jambes, 5 kg minimum) ou ~5 % (haut du corps, 2,5 kg minimum) tant que les 5 répétitions restent propres, 2 min 30 de repos. Le premier essai part de la charge d'essai prudente. L'utilisateur note sa série de 5 la plus lourde.
- Pas de test en cas de fatigue, de douleur au genou, en déplacement ou au poids du corps : la séance habituelle suit. Avec peu de temps, le test garde les mouvements qui tiennent dans la durée (au moins un). Le test ne se remplace pas et ne se resserre pas.
- Après le test : charge de travail = 1RM estimé (Epley) ramené aux répétitions prévues plus 2 en réserve, arrondi vers le bas. Les variantes (haltères, machines, hip thrust, roumain…) se déduisent du mouvement de référence par un ratio prudent, jusqu'à leur première série notée.
- L'inscription l'explique (écran « Ton point de départ »). Dans « Mon profil », « Refaire le test de force » (salle) remet le calibrage à zéro : seules les charges notées depuis comptent, le test revient au prochain jour de force et son premier essai part des dernières charges. Les records restent.

## Test de cardio (`Training/CardioTest`)

- Forme cardio = VO2max (ml/kg/min). La plus récente des mesures compte : la « Forme cardio » de l'Apple Watch lue dans Santé, ou un test de marche noté dans l'app.
- Sans mesure de moins de 8 semaines avant ce jour, un jour de cardio devient « Test de cardio : 1,6 km de marche ». C'est seulement possible sans fatigue, courbatures, nuit courte ni genou sensible, et avec au moins 25 min. Un jour de force, la force reste recommandée. Le test se fait en marchant le plus vite possible, sans courir, sur terrain plat. La Watch reçoit un objectif de 1,6 km.
- « Noter mon test » : temps et pouls à l'arrivée → VO2max par l'équation de Rockport. Un test par jour, corrigeable.
- Zone de cardio modéré : 40 à 59 % de la réserve cardiaque si le pouls au repos est connu (Santé), sinon 64 à 76 % de la fréquence maximale (208 − 0,7 × âge). Elle s'affiche dans la consigne des jours de cardio et dans Progresser.
- Siri et Raccourcis ne lisent pas Santé : ils ne voient que les tests notés dans l'app.

## Progression (`ProgressInsights/WeightTrendAnalyzer`)

- Poids lissé (moyenne mobile exponentielle, 0,25) pour gommer l'eau et le sel.
- Vitesse : régression linéaire sur 21 jours, au moins 3 pesées sur 7 jours.
- En bonne voie entre −0,1 % et −1 % du poids par semaine ; au-delà de −1 %, le coach suggère +150 kcal. Le coach suggère, l'utilisateur décide.
- Tour de taille : saisi à la main, au plus une fois par semaine suffit. Variation sur 4 semaines, avec deux mesures espacées d'au moins 10 jours. Une baisse d'au moins 1 cm montre que le gras part, même si le poids ne bouge pas : le coach ne parle pas de stagnation.
- Scan LiDAR du tour de taille (expérimental, iPhone Pro) : une personne tient l'iPhone et place la ligne centrale sur le nombril, de face puis de profil, bras croisés. Pour chaque vue, 15 images : largeur du corps sur la ligne (pixels dont la profondeur est à moins de 30 cm de celle du nombril, × distance / focale), médiane, puis périmètre d'une ellipse (Ramanujan). Le scan est enregistré à part (`WaistRecord.isScan`) : il n'entre ni dans la tendance ni dans le bilan. L'historique affiche l'écart moyen avec le ruban du même jour ; il ne remplacera le ruban que si l'écart reste sous 1 cm pendant deux semaines (choix BodyPilot).

## Régularité

- Pas d'objectif par semaine : la séance se décide au jour le jour. « Ma semaine » (carte Bouger) montre ce qui a été fait. `ProgressInsights/ConsistencyAnalyzer` reste disponible mais n'est plus affiché.

## Bilan de la semaine (`Coach/WeeklyCheckIn`)

- Au plus une fois par semaine, sur la carte Progresser. Le coach propose, l'utilisateur applique ou repousse.
- Perte trop rapide (plus de 1 % par semaine) : +150 kcal. Prise trop rapide (plus de 0,5 %) : −150 kcal.
- Stagnation ou mauvaise direction : correction seulement si c'était déjà le cas une semaine plus tôt (pas de réaction à l'eau). Si le tour de taille a baissé d'au moins 1 cm, aucune correction : la recomposition fonctionne. Sans mesure de taille, le coach propose −150 kcal et demande de mesurer la taille.
- Corrections cumulées limitées à ±450 kcal ; jamais sous le plancher de sécurité, jamais de surplus. Sans effet réel, pas de proposition.
- Cycle menstruel (femmes, suivi de cycle noté dans Santé) : pas de baisse proposée pendant les 5 premiers jours des règles ni les 5 jours qui les précèdent (prévus d'après la durée moyenne des 3 derniers cycles de 21 à 35 jours). La rétention d'eau y masque la perte de gras (White et al., 2011). Une hausse pour perte trop rapide reste proposée.
- L'objectif proposé tient compte de la dépense des séances, comme celui du jour.
- Semaine à l'équilibre (`BodyPilotCore/MaintenanceWeek`) : après 12 semaines en perte de gras sans pause (depuis la création du profil ou la dernière semaine à l'équilibre), Progresser propose une semaine à la dépense. Oui → 7 jours en phase d'équilibre, sans bilan, puis le déficit reprend ; Pas maintenant → reproposée 4 semaines plus tard. Présentée honnêtement : elle aide à tenir (faim, fatigue), elle ne fait pas perdre plus de gras.

## Pesées importées de Santé (`ProgressInsights/WeightImportPlanner`)

- Lecture seule du poids (HealthKit, `bodyMass`), 90 jours en arrière à la connexion, puis à chaque retour dans l'app. Aucune donnée ne quitte l'iPhone.
- Santé fournit aussi, en lecture : les entraînements (Watch, cours collectifs, autres apps), le sommeil de la nuit passée, la VO2max et le pouls au repos, et pour les femmes le suivi des règles (120 jours ; un saignement après 10 jours sans flux ouvre un nouveau cycle). Progresser affiche ce qui est relié et la nuit dernière.
- Profil : la taille, la date de naissance et le sexe de Santé remplacent ceux du profil à chaque retour dans l'app, donc les besoins se recalculent. « Mon profil » affiche le poids de la dernière pesée. Un poids modifié là devient la pesée du jour, et le poids de départ ne change pas.
- Une pesée par jour : la première de la journée (le plus souvent le matin à jeun).
- Un jour déjà renseigné n'est jamais écrasé : la saisie manuelle garde la main.
- Valeurs hors 25–350 kg écartées ; une mesure déjà importée (même identifiant Santé) ne revient pas.
- Composition corporelle (balance à impédance) : taux de gras (`bodyFatPercentage`) et masse maigre (`leanBodyMass`) lus dans Santé, 90 jours, une mesure par jour, valeurs aberrantes écartées (gras hors 3–70 %, masse maigre hors 20–150 kg). Sans masse maigre, elle se déduit du poids du même jour. Rien n'est enregistré dans l'app : Santé reste la source.
- Progresser affiche la moyenne de la dernière semaine de mesures et l'écart avec la première semaine sur 4 semaines (au moins 2 semaines de recul). Une mesure d'impédance varie avec l'hydratation : seule la tendance compte.
- Recomposition : une baisse du taux de gras d'au moins 0,5 point (choix BodyPilot) joue le même rôle que la taille qui baisse : message de progrès et aucune baisse de calories au bilan.

## Ma semaine (`ProgressInsights/WeekActivityAnalyzer`)

- La carte Bouger montre la semaine en cours : minutes bougées par jour, puis chaque activité (séances cochées dans l'app et entraînements de Santé, Apple Watch comprise), avec durée et kcal.
- Une séance cochée sans renforcement enregistré dans Santé le même jour s'affiche à part ; avec un enregistrement de la Watch, elle n'apparaît qu'une fois.
- Apple Watch : la séance du jour (celle choisie) s'envoie d'une touche. Pas de planning de semaine : la séance se décide chaque jour.

## Repas envoyés vers Santé (`Nutrition/HealthMealExport`)

- Avec Santé relié, chaque repas mangé (« Comme prévu », plus ou moins, décrit en texte ou en photo) part dans Santé > Nutrition : énergie consommée, protéines, glucides, lipides, nommés d'après le repas.
- Heure habituelle du repas (8 h, 12 h 30, 16 h 30, 20 h), jamais dans le futur.
- Identifiant stable par jour et par repas : une modification remplace les valeurs, une annulation ou un repas sauté les retire. Rien n'est réécrit tant que le contenu ne change pas.
- Écriture refusée dans Santé : l'app fonctionne sans. Rien ne quitte l'iPhone.

## Phrase libre (`Coach/CommandInterpreter`)

- « Je suis crevé, j'ai 15 min et resto ce soir » → fatigue + 15 minutes + restaurant.
- Passe par l'AIRouter au niveau déterministe : mots-clés français, sans accents ni casse, gratuit et hors ligne. Un temps précis (5 à 120 min) remplace les 20 minutes par défaut.
- Si les mots-clés ne reconnaissent rien, le modèle Apple embarqué (Foundation Models) prend le relais, s'il est disponible sur l'iPhone : gratuit, hors ligne, jamais de cloud. Phrases de plus de 280 caractères ignorées.
- Sa réponse est structurée (oui/non par ajustement, minutes, repas) puis contrôlée comme les mots-clés : temps entre 5 et 120 min, repas seulement si restaurant.
- Phrase toujours non comprise : le coach le dit et propose les ajustements en une touche.

## Historique (`App/History/HistoryView`, `ProgressInsights/SessionHistory`)

- Depuis Progresser, « Historique » ouvre quatre parties : Mesures, Force, Séances, Repas.
- Mesures : courbe des pesées, puis jour par jour le poids, le tour de taille et le taux de gras (balance dans Santé).
- Force : par exercice, courbe du 1RM estimé (Epley) de la meilleure série de chaque séance, puis toutes les séries notées, tests compris.
- Séances : jour par jour, les séances cochées dans l'app et les entraînements lus dans Santé (durée, calories).
- Repas : jour par jour, la saisie d'une touche de chaque repas ou le repas décrit avec ses calories. Les calories d'un repas « comme prévu » ne sont pas gardées : le plan d'un jour passé n'est pas recalculé.
- Démo : `-demoHistory Force` ouvre l'historique sur une partie.

## Mes 7 derniers jours (`ProgressInsights/WeekReview`, `App/Review/WeekReviewView`)

- Depuis Progresser, « Mes 7 derniers jours » : les 7 jours glissants (aujourd'hui compris), calories mangées par jour face à l'objectif, moyennes des nutriments, séances et minutes par jour, pas, puis le détail d'une journée d'une touche.
- Jours passés : le plan du jour est rejoué avec les repas notés ce jour-là et l'objectif recalculé avec le profil actuel (rien de nouveau n'est stocké). Aujourd'hui : le plan affiché.
- Journée complète : les 4 repas notés (pris, sautés ou décrits). Seules les journées complètes comptent dans les moyennes.
- Calories dans la cible de -15 % à +10 % de l'objectif ; protéines atteintes à 90 % (choix BodyPilot : les repas notés d'une touche sont des estimations).
- Repères de l'OMS (2020) : 150 min d'endurance par semaine (force et mobilité exclues) et 2 séances de renforcement ; les séances de force se comptent sur la semaine du calendrier, 48 h entre deux.
- Encouragements : ce qui a été tenu (force, endurance, protéines, cible de calories, repas notés, pas). Conseils du reste de la journée : repas restants (kcal, protéines, prochain repas), séance du jour, pas restants. Conseils de la semaine : 3 au plus, force d'abord, puis nutrition (repas à noter, protéines, calories avec le jour le plus au-dessus), endurance, pas.
- Tout est déterministe et local : aucun appel IA.
- Démo : `-demoReview YES` (ou `jour` pour ouvrir le détail de la veille), avec `-demoScrollTo calories|activity|days`.

## Nutriments détaillés (`BodyPilotCore/Macros`, `App/DesignSystem/Components`)

- Protéines, glucides, lipides et fibres partout : jauges du jour dans Manger, détail de chaque repas déplié, bilan « Mes 7 derniers jours » et détail d'une journée.
- Pourcentage : part des calories apportée par les protéines et les glucides (4 kcal/g) et les lipides (9 kcal/g). Les fibres s'affichent en grammes face à l'objectif.
- Objectif de fibres : 30 g par jour (ANSES, 2016). Fibres pour 100 g : valeurs de la table Ciqual 2025 (aliment Ciqual le plus proche pour le catalogue du plan et les aliments simples du lexique ; fruits rouges : moyenne framboise, fraise, myrtille) ; ordre de grandeur pour les plats composés du lexique (burger, kebab, quiche…). Un aliment estimé par le modèle embarqué compte 0 g ; un repas au restaurant compte 1 g pour 100 kcal.
- Bilan : sous 80 % de l'objectif de fibres en moyenne sur les journées complètes, un conseil de la semaine le signale.
- Les repas enregistrés avant l'ajout des fibres se relisent avec 0 g de fibres (pas de changement de schéma : les repas décrits sont stockés en JSON).

## Liste de courses (`Nutrition/GroceryList`, `App/Groceries/GroceryListView`)

- Depuis Manger, « Préparer mes courses » : les repas que le coach propose sur 3, 5 ou 7 jours à partir de demain, avec les objectifs du jour (pas de restaurant ni de repas noté prévus d'avance), pour les moments de la journée choisis.
- Agrégée par aliment, rangée par rayon dans l'ordre d'un parcours (fruits et légumes, viandes et poissons, frais et œufs, boulangerie, épicerie), avec le nombre de repas qui l'utilisent.
- Quantités d'achat : féculents cuits ramenés au poids sec (rapport des kcal cuit/cru : riz ×0,37, pâtes ×0,35, quinoa et lentilles ×0,33), poulet pesé cru (×1,33), patate douce épluchures comprises (×1,1), thon et pois chiches en boîtes, œufs, bananes, pommes et avocats à l'unité, huile en ml. Arrondi au-dessus : par 50 g, par 100 g au-delà d'un kilo, à l'unité avec 10 % de marge.
- Période fixée à la création (elle ne glisse pas d'un jour à l'autre), recréée à partir de demain une fois passée ou à la demande. Cochés, « J'en ai déjà » et articles ajoutés restent sur l'iPhone (réglages de l'app, hors base et hors sauvegarde). Partage en texte de ce qui reste à acheter.
- Démo : `-demoGroceries YES`.

## Conseils et sources (`App/Today/CoachGuidesSheet`)

- Menu Mon profil > « Conseils et sources » : texte fixe, rien à saisir.
- Créatine : monohydrate 3 à 5 g par jour, sans phase de charge, facultative ; prévient de la prise d'eau (1 à 2 kg) que la tendance du poids absorbe. Pas avant 18 ans, ni enceinte, ni avec une maladie des reins ; avec un oui au questionnaire de santé, avis du médecin d'abord (Kreider et al., 2017).
- Fibres : 30 g par jour (ANSES, 2016) et produits peu transformés (Hall et al., 2019 : environ 500 kcal de plus par jour avec des ultra-transformés, essai sur 20 adultes pendant 2 semaines).
- Sommeil : au moins 7 h (Watson et al., 2015).
- Sources : les références principales des règles, par thème. La liste complète reste dans ce fichier et dans `docs/TRAINING_EVIDENCE.md`.
