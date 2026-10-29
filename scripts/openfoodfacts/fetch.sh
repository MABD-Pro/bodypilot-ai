#!/usr/bin/env bash
# Interroge Open Food Facts pour chaque article de items.json et garde les réponses brutes.
# Usage : scripts/openfoodfacts/fetch.sh <dossier de sortie>
# Deux recherches possibles : l'historique (search.pl, 10 requêtes par minute, souvent saturée)
# puis la nouvelle (search.openfoodfacts.org). Une requête toutes les 7 s.
set -euo pipefail
out="$1"
here="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$out"
python3 - "$here/items.json" "$out" <<'PY'
import json, pathlib, sys, time, urllib.parse, urllib.request

items = json.load(open(sys.argv[1]))["items"]
out = pathlib.Path(sys.argv[2])
fields = "code,product_name,product_name_fr,brands,nutriscore_grade,nova_group,unique_scans_n,nutriments,countries_tags"
headers = {"User-Agent": "BodyPilot/0.1 (https://github.com/MABD-Pro/bodypilot-ai)"}

def legacy(terms):
    query = urllib.parse.urlencode({
        "search_terms": terms, "search_simple": 1, "action": "process", "json": 1,
        "tagtype_0": "countries", "tag_contains_0": "contains", "tag_0": "france",
        "sort_by": "unique_scans_n", "page_size": 100, "fields": fields,
    })
    return "https://world.openfoodfacts.org/cgi/search.pl?" + query, "products"

def searchalicious(terms):
    query = urllib.parse.urlencode({
        "q": f'{terms} countries_tags:"en:france"', "langs": "fr",
        "page_size": 100, "sort_by": "-unique_scans_n", "fields": fields,
    })
    return "https://search.openfoodfacts.org/search?" + query, "hits"

def fetch(name, terms):
    for attempt in range(4):
        for source in (legacy, searchalicious):
            url, key = source(terms)
            try:
                with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=60) as response:
                    data = json.load(response)
                products = data.get(key)
                if isinstance(products, list):
                    return source.__name__, products
                print(f"{name} : {source.__name__} sans liste ({list(data)[:6]})", file=sys.stderr)
            except Exception as error:
                print(f"{name} : {source.__name__} essai {attempt + 1} raté ({error})", file=sys.stderr)
            time.sleep(7)
        time.sleep(20)
    sys.exit(f"{name} : Open Food Facts ne répond pas")

for index, (name, item) in enumerate(items.items()):
    source, products = fetch(name, item["terms"])
    for product in products:
        # La nouvelle recherche donne les marques en liste.
        if isinstance(product.get("brands"), list):
            product["brands"] = ", ".join(product["brands"])
    (out / f"{index:02d}.json").write_text(json.dumps({"name": name, "source": source, "products": products}, ensure_ascii=False))
    print(f"{name} : {len(products)} produits ({source})")
    time.sleep(7)
PY
