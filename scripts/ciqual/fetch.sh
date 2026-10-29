#!/usr/bin/env bash
# Télécharge la table Ciqual officielle (ANSES, Licence Ouverte) dans le dossier donné.
# Lancé par la CI (workflow « Ciqual ») : le conteneur cloud n'a pas accès aux sites de l'ANSES.
set -euo pipefail
out="${1:-ciqual-source}"
mkdir -p "$out"
# Version actuelle, sur recherche.data.gouv (Dataverse) : elle annule et remplace celle de 2020.
api="https://entrepot.recherche.data.gouv.fr/api"
doi="doi:10.57745/RDMHWY"
curl -fsSL "$api/datasets/:persistentId/?persistentId=$doi" -o "$out/dataset.json"
python3 - "$out" <<'PY'
import json, sys, urllib.request, pathlib
out = pathlib.Path(sys.argv[1])
version = json.loads((out / "dataset.json").read_text())["data"]["latestVersion"]
print("Version", version.get("versionNumber"), version.get("releaseTime"), version.get("license"))
for entry in version["files"]:
    file = entry["dataFile"]
    print(file["id"], file["filename"], file.get("filesize"))
    url = f"https://entrepot.recherche.data.gouv.fr/api/access/datafile/{file['id']}"
    urllib.request.urlretrieve(url, out / file["filename"])
PY
ls -la "$out"
