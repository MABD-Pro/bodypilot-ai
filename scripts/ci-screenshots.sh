#!/usr/bin/env bash
# Compile l'app pour un simulateur iPhone, la lance avec des données de démo
# et capture les écrans clés dans screenshots/ (publiés comme artefact de CI).
#
# CAPTURES choisit les écrans (chaque capture coûte ~10 s de macOS, facturé x10) :
#   vide        : seulement 1-aujourdhui, pour vérifier que l'app se lance ;
#   « toutes »  : toutes les captures ;
#   sinon       : expression régulière sur les noms, par ex. « 4h|4i|3c ».
set -euo pipefail

CAPTURES=${CAPTURES:-}
case "$CAPTURES" in
  "") CAPTURES='^1-aujourdhui$' ;;
  toutes|all) CAPTURES='.' ;;
esac

BUNDLE_ID=com.mabdpro.bodypilot
OUT=screenshots
mkdir -p "$OUT"

# iPhone du runtime iOS le plus récent (modèle Pro de préférence).
UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
runtimes = sorted((r for r in devices if "iOS" in r), key=lambda r: [int(x) for x in r.rsplit("iOS-", 1)[-1].split("-") if x.isdigit()])
phones = [d for d in devices[runtimes[-1]] if d["name"].startswith("iPhone")]
pro = [d for d in phones if "Pro" in d["name"] and "Max" not in d["name"]]
print((pro or phones)[0]["udid"])
')
echo "Simulateur : $UDID"

# Démarrage du simulateur en parallèle de la compilation.
xcrun simctl boot "$UDID" || true

start=$SECONDS
xcodebuild build \
  -project BodyPilot.xcodeproj \
  -scheme BodyPilot \
  -destination "id=$UDID" \
  -derivedDataPath build \
  -skipMacroValidation \
  -skipPackagePluginValidation \
  ONLY_ACTIVE_ARCH=YES \
  COMPILER_INDEX_STORE_ENABLE=NO \
  CODE_SIGNING_ALLOWED=NO > build.log 2>&1 || {
    grep -E "error:" build.log | sort -u | head -n 80
    tail -n 40 build.log
    exit 1
  }

echo "Compilation : $((SECONDS - start)) s"

APP=$(find build/Build/Products -name 'BodyPilot.app' -maxdepth 2 | head -n 1)

start=$SECONDS
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 || true
xcrun simctl install "$UDID" "$APP"

shoot() {
  local name=$1
  shift
  grep -Eq -- "$CAPTURES" <<< "$name" || return 0
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -AppleLanguages "(fr)" -AppleLocale fr_FR "$@"
  sleep 7
  xcrun simctl io "$UDID" screenshot "$OUT/$name.png"
}

shoot 0-chargement -demoData YES -demoHoldSplash YES
shoot 1-aujourdhui -demoData YES
shoot 2-aujourdhui-repas -demoData YES -demoScrollTo nutrition
shoot 2b-repas-pris -demoData YES -demoMeals breakfast=asPlanned,lunch=hearty -demoScrollTo nutrition
shoot 2c-repas-decrit -demoData YES -demoMeals breakfast=asPlanned -demoDescribed "lunch=une grande assiette de pâtes carbo et un coca" -demoScrollTo nutrition
shoot 2d-depense-mesuree -demoData YES -demoIntake YES -demoScrollTo nutrition
shoot 2e-phase-prise -demoData YES -demoTarget 92 -demoScrollTo nutrition
shoot 2f-liste-de-courses -demoData YES -demoGroceries YES
shoot 2g-marques-conseillees -demoData YES -demoGroceries YES -demoBrands "Skyr nature"
shoot 2h-faim -demoData YES -demoHunger YES -demoScrollTo nutrition
shoot 3z-fatigue-muscles -demoData YES -demoMuscles YES -demoScrollTo muscles
shoot 3m-fiche-muscles -demoData YES -demoLifts YES -demoTechnique YES -demoScrollTo training
shoot 3i-isolation -demoData YES -demoScrollTo training
shoot 3k-senior -demoData YES -demoLifts YES -demoAge 68 -demoScrollTo training
shoot 3j-sommeil-moyen -demoData YES -demoSleepAverage 6.25 -demoScrollTo training
shoot 4g-semaine-equilibre -demoData YES -demoMaintenanceOffer YES -demoScrollTo progress
shoot 5a-conseils-sources -demoData YES -demoGuides YES
shoot 4f-phase-progresser -demoData YES -demoTarget 92 -demoScrollTo progress
shoot 3-aujourdhui-seance -demoData YES -demoScrollTo training
shoot 3b-seance-exercice-remplace -demoData YES -demoSwap YES -demoScrollTo training
shoot 3c-ma-semaine -demoData YES -demoActivities YES -demoHealth YES -demoScrollTo week
shoot 3d-records-seance -demoData YES -demoLifts YES -demoScrollTo training
shoot 3e-test-de-force -demoData YES -demoCalibration YES -demoScrollTo training
shoot 3f-recuperation -demoData YES -demoRecovery YES -demoScrollTo training
shoot 3g-propositions-nuit-courte -demoData YES -demoSleep 5.5 -demoScrollTo training
shoot 4-aujourdhui-progression -demoData YES -demoScrollTo progress
shoot 4q-progresser-pas -demoData YES -demoHealth YES -demoSteps YES -demoScrollTo steps
shoot 4r-historique-pas -demoData YES -demoHealth YES -demoSteps YES -demoHistory Pas
shoot 4c-bilan-semaine -demoData YES -demoCheckIn YES -demoScrollTo progress
shoot 4b-progression-sante -demoData YES -demoHealth YES -demoScrollTo progress
shoot 4h-bilan-7-jours -demoData YES -demoReview YES -demoActivities YES -demoSteps YES -demoMeals breakfast=asPlanned
shoot 4i-bilan-7-jours-calories -demoData YES -demoReview YES -demoActivities YES -demoSteps YES -demoMeals breakfast=asPlanned -demoScrollTo calories
shoot 4j-bilan-7-jours-jours -demoData YES -demoReview YES -demoActivities YES -demoSteps YES -demoScrollTo days
shoot 4n-bilan-ressenti -demoData YES -demoReview YES -demoActivities YES -demoSteps YES -demoFeeling soso:hunger,time
shoot 1c-retour-plancher -demoData YES -demoComeback YES
shoot 1d-semaine-plancher -demoData YES -demoFloorWeek YES
shoot 4o-et-si -demoData YES -demoWhatIf 200:2000
shoot 1e-debrief-soir -demoData YES -demoDebrief "Séance faite, pizza ce soir et je suis crevé"
shoot 1f-garde-fou -demoData YES -demoEatingCare YES
# Repas habituel au petit-déjeuner, sans poisson ni laitages.
shoot 1g-habitudes -demoData YES -demoHabits YES -demoAvoid fish,dairy -demoScrollTo nutrition
shoot 1h-recuperation -demoData YES -demoLowRecovery YES -demoRecovery YES
shoot 1i-agenda -demoData YES -demoAgenda YES
shoot 1j-agenda-deplacement -demoData YES -demoAgenda travel
shoot 1k-agenda-journee-pleine -demoData YES -demoAgenda full
shoot 1l-agenda-invitation -demoData YES -demoAgendaInvite YES
shoot 4k-bilan-jour -demoData YES -demoReview jour -demoActivities YES -demoSteps YES
shoot 4l-repas-jour-passe -demoData YES -demoHistory Repas -demoPastMeals YES
shoot 4m-detail-seance -demoData YES -demoActivities YES -demoHealth YES -demoHistory Séances -demoSessionDetail YES
shoot 4e-pas -demoData YES -demoHealth YES -demoSteps YES -demoScrollTo progress
shoot 4d-records-progression -demoData YES -demoLifts YES -demoScrollTo progress
shoot 5-ajustement-20min-fatigue -demoData YES -demoAdjustments shortOnTime,tired -demoScrollTo training
shoot 6a-phrase-resto-genou-repas -demoData YES -demoCommand "J'ai mal au genou et ce soir resto" -demoScrollTo nutrition
shoot 6b-phrase-resto-genou-seance -demoData YES -demoCommand "J'ai mal au genou et ce soir resto" -demoScrollTo training
shoot 7-accueil -demoOnboarding YES
shoot 7b-questionnaire-sante -demoOnboarding YES -demoOnboardingStep 1
shoot 7c-consentement -demoOnboarding YES -demoConsent YES
shoot 3h-seance-avis-medical -demoData YES -demoScreening caution -demoCalibration YES -demoScrollTo training
shoot 1b-bandeau-sante -demoData YES -demoScreening pending
xcrun simctl ui "$UDID" appearance dark
shoot 8-aujourdhui-sombre -demoData YES
echo "Captures : $((SECONDS - start)) s"
