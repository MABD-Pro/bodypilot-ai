#!/usr/bin/env bash
# Interroge Open Food Facts pour chaque article de items.json et garde les réponses brutes.
# Usage : scripts/openfoodfacts/fetch.sh <dossier de sortie>
# La recherche (search.pl) limite à 10 requêtes par minute et répond souvent 503 : une requête
# toutes les 7 s, de longues pauses entre les essais, et une réponse déjà obtenue pour les mêmes
# termes est gardée (le workflow repart des réponses publiées sur ci/openfoodfacts).
# La nouvelle recherche (search.openfoodfacts.org) a été essayée : elle ignore les termes et renvoie
# les produits les plus scannés.
set -euo pipefail
out="$1"
here="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$out"
python3 - "$here/items.json" "$out" <<'PY'
import json, pathlib, sys, time, unicodedata, urllib.parse, urllib.request

items = json.load(open(sys.argv[1]))["items"]
out = pathlib.Path(sys.argv[2])
fields = "code,product_name,product_name_fr,brands,nutriscore_grade,nova_group,unique_scans_n,nutriments,countries_tags"

def slug(name):
    text = unicodedata.normalize("NFD", name.lower().replace("œ", "oe"))
    return "-".join("".join(c if c.isalnum() else " " for c in text if unicodedata.category(c) != "Mn").split())

missing = []
for name, item in items.items():
    path = out / f"{slug(name)}.json"
    if path.exists() and json.loads(path.read_text()).get("terms") == item["terms"]:
        print(f"{name} : réponse déjà là")
        continue
    query = urllib.parse.urlencode({
        "search_terms": item["terms"], "search_simple": 1, "action": "process", "json": 1,
        "tagtype_0": "countries", "tag_contains_0": "contains", "tag_0": "france",
        "sort_by": "unique_scans_n", "page_size": 100, "fields": fields,
    })
    request = urllib.request.Request(
        "https://world.openfoodfacts.org/cgi/search.pl?" + query,
        headers={"User-Agent": "BodyPilot/0.1 (https://github.com/MABD-Pro/bodypilot-ai)"},
    )
    products = None
    for attempt, pause in enumerate([15, 30, 60, 90]):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                products = json.load(response).get("products", [])
            break
        except Exception as error:
            print(f"{name} : essai {attempt + 1} raté ({error})", file=sys.stderr)
            time.sleep(pause)
    if products is None:
        missing.append(name)
        continue
    path.write_text(json.dumps({"name": name, "terms": item["terms"], "products": products}, ensure_ascii=False))
    print(f"{name} : {len(products)} produits")
    time.sleep(7)
if missing:
    print(f"Sans réponse, à relancer : {', '.join(missing)}", file=sys.stderr)
PY
