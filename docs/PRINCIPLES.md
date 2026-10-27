# BodyPilot AI — Principes fondateurs non négociables

Ces principes guident toutes les décisions de conception, d'architecture, de développement et de commercialisation.

## 1. Philosophie produit : coach-first, not tracking-first

BodyPilot AI n'est pas un compteur de calories, un journal alimentaire ou un carnet d'entraînement. C'est un coach personnel intelligent qui accompagne l'utilisateur, prend en compte ses contraintes et lui propose chaque jour des actions concrètes.

### Principes obligatoires

- Le coaching est la fonctionnalité centrale de l'application.
- Le suivi des données sert à améliorer les décisions du coach.
- L'utilisateur ne doit pas passer son temps à saisir des informations.
- L'application exploite automatiquement les données disponibles, avec les autorisations nécessaires.
- Les recommandations sont personnalisées, explicables et directement applicables.
- L'utilisateur peut modifier son programme en quelques secondes.
- Le coach anticipe les difficultés lorsqu'il dispose d'informations suffisantes.
- Les objectifs évoluent selon les résultats réels.
- L'application minimise les manipulations et la charge mentale.
- L'utilisateur conserve toujours le contrôle des décisions importantes.

### Expérience quotidienne attendue

À l'ouverture, l'application répond immédiatement à trois questions :

1. Que dois-je manger aujourd'hui ?
2. Quel entraînement dois-je effectuer ?
3. Est-ce que je progresse vers mon objectif ?

L'écran principal présente un programme directement exploitable. L'utilisateur peut déclarer simplement :

- « Je n'ai que 20 minutes. »
- « Je suis fatigué. »
- « Je mange au restaurant. »
- « J'ai raté ma séance. »
- « Je n'ai pas faim. »
- « J'ai mal au genou. »
- « Je pars en déplacement. »

Le moteur adaptatif propose immédiatement les ajustements appropriés, dans les limites de sécurité définies.

> **Règle fondamentale : l'utilisateur suit son coach, le coach s'adapte à l'utilisateur.**

## 2. Architecture technique obligatoire

Développement SwiftUI natif, architecture local-first, backend léger, utilisation sélective de l'IA cloud. Ces quatre éléments sont des exigences structurantes.

### 2.1 Développement iOS 100 % natif

Swift 6, SwiftUI, Swift Concurrency, SwiftData ou Core Data, HealthKit, WorkoutKit (lorsque pertinent), App Intents, Apple Foundation Models (appareils compatibles), Vision, Core ML, AVKit, Charts, StoreKit 2.

Éviter les frameworks multiplateformes lorsqu'ils n'apportent pas d'avantage décisif. Privilégier les composants Apple natifs pour la fluidité, les performances, l'autonomie et la maintenance.

### 2.2 Architecture local-first

Données principales disponibles localement : profil, objectifs, programme alimentaire, programme sportif, journal des repas, journal des séances, records personnels, mensurations, historique, préférences, décisions précédentes du coach.

- L'application reste utilisable hors connexion pour les fonctionnalités essentielles.
- Les données locales sont la source opérationnelle principale.
- Synchronisation sécurisée et gestion explicite des conflits entre appareils.

### 2.3 Backend léger

Limité à ce qui nécessite réellement un serveur : authentification et synchronisation multi-appareils, appels sécurisés aux API d'IA, abonnements et droits, quotas, stockage distant facultatif, distribution des contenus, configuration distante, services commerciaux.

Comparer les solutions selon leur coût total, leur sécurité, leur maintenance et leur capacité d'évolution. Éviter les architectures complexes et coûteuses avant qu'elles soient nécessaires.

### 2.4 IA cloud uniquement lorsqu'elle apporte une valeur mesurable

Ne jamais envoyer systématiquement toutes les opérations à un modèle cloud.

| Traitement | Exemples |
|---|---|
| Calcul déterministe local | Calories et macros, tendances du poids, historique des performances, progression des charges, règles de sécurité, planification simple |
| IA locale (si disponible) | Compréhension de commandes, résumés simples, assistance contextuelle, classification |
| IA cloud (si nécessaire) | Reconnaissance alimentaire complexe par photo, raisonnement approfondi, analyse multimodale, planification complexe, synthèse longitudinale, recommandations avancées |

### 2.5 AI Cost Router

Ordre de priorité :

1. Calcul déterministe local.
2. Modèle IA local.
3. Modèle cloud économique.
4. Modèle cloud avancé, uniquement si nécessaire.

Chaque appel cloud est justifié par une valeur fonctionnelle. Mesurer : nombre d'appels, tokens consommés, coût par fonctionnalité, coût par utilisateur, temps de réponse, qualité des résultats, taux d'erreur. Limites de consommation configurables.

### 2.6 Architecture évolutive

Doit permettre : un utilisateur pilote, puis plusieurs centaines, puis plusieurs milliers ; le remplacement des fournisseurs IA ; l'ajout de modules ; l'internationalisation ; l'Apple Watch ; l'abonnement. Éviter toute dépendance forte à un fournisseur externe.

## 3. Critère de validation des fonctionnalités

Avant d'ajouter une fonctionnalité :

1. Améliore-t-elle réellement le coaching ?
2. Réduit-elle les efforts demandés à l'utilisateur ?
3. Améliore-t-elle les chances d'atteindre ses objectifs ?
4. Peut-elle fonctionner localement ?
5. Nécessite-t-elle réellement une IA cloud ?
6. Son coût est-il justifié ?
7. Peut-elle évoluer vers le grand public ?

Une fonctionnalité qui ajoute de la complexité sans bénéfice démontrable est simplifiée, reportée ou supprimée.

## 4. En résumé

BodyPilot AI est : coach-first, SwiftUI natif, local-first, backend léger, IA hybride, économiquement optimisé, extrêmement intuitif, orienté résultats, adaptatif au quotidien, évolutif vers le grand public.

Ne jamais sacrifier la simplicité ou la fiabilité pour des fonctionnalités spectaculaires. L'objectif est une application qui aide réellement ses utilisateurs à progresser, pas une démonstration technologique.
