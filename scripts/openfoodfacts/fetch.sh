#!/usr/bin/env bash
# Interroge Open Food Facts pour chaque article de items.json et garde les réponses brutes.
# Usage : scripts/openfoodfacts/fetch.sh <dossier de sortie>
# L'API de recherche limite à 10 requêtes par minute : une requête toutes les 7 s.
set -euo pipefail
out="$1"
here="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$out"
python3 - "$here/items.json" "$out" <<'PY'
import json, pathlib, sys, time, urllib.parse, urllib.request

items = json.load(open(sys.argv[1]))["items"]
out = pathlib.Path(sys.argv[2])
fields = "code,product_name,product_name_fr,brands,nutriscore_grade,nova_group,unique_scans_n,quantity,nutriments,countries_tags"
for index, (name, item) in enumerate(items.items()):
    query = urllib.parse.urlencode({
        "search_terms": item["terms"], "search_simple": 1, "action": "process", "json": 1,
        "tagtype_0": "countries", "tag_contains_0": "contains", "tag_0": "france",
        "sort_by": "unique_scans_n", "page_size": 100, "fields": fields,
    })
    request = urllib.request.Request(
        "https://world.openfoodfacts.org/cgi/search.pl?" + query,
        headers={"User-Agent": "BodyPilot/0.1 (https://github.com/MABD-Pro/bodypilot-ai)"},
    )
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                data = json.load(response)
            break
        except Exception as error:
            print(f"{name} : essai {attempt + 1} raté ({error})", file=sys.stderr)
            time.sleep(20)
    else:
        sys.exit(f"{name} : Open Food Facts ne répond pas")
    (out / f"{index:02d}.json").write_text(json.dumps({"name": name, "products": data.get("products", [])}, ensure_ascii=False))
    print(f"{name} : {len(data.get('products', []))} produits")
    time.sleep(7)
PY
