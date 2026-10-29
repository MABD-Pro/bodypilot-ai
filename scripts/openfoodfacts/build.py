#!/usr/bin/env python3
"""Génère Packages/BodyPilotKit/Sources/Nutrition/GroceryBrandTable.swift depuis les réponses
d'Open Food Facts (scripts/openfoodfacts/fetch.sh).

Usage : scripts/openfoodfacts/build.py <dossier des réponses> [fichier Swift de sortie]
Les règles de choix sont celles de GroceryBrands (Swift) : les deux doivent rester identiques.
Données Open Food Facts, licence ODbL : la source est citée dans l'app.
"""
import json, math, pathlib, sys, unicodedata

ROOT = pathlib.Path(__file__).resolve().parents[2]
ITEMS = json.load(open(pathlib.Path(__file__).with_name("items.json")))["items"]
GRADES = {"a": 0, "b": 1, "c": 2, "d": 3, "e": 4}
PICKS = 2


def normalize(text):
    text = unicodedata.normalize("NFD", text.lower())
    text = "".join(c for c in text if unicodedata.category(c) != "Mn")
    return " ".join("".join(c if c.isalnum() else " " for c in text).split())


def contains(name_words, phrase):
    """Les mots de la phrase se suivent dans le nom, chacun au début d'un mot (« lentille » → « lentilles »)."""
    words = phrase.split()
    for start in range(len(name_words) - len(words) + 1):
        if all(name_words[start + i].startswith(w) for i, w in enumerate(words)):
            return True
    return False


def starts(name_words, phrase):
    """Le nom commence par la phrase (« Feta AOP » pour feta, pas « Lentilles boulgour féta »)."""
    words = phrase.split()
    return len(name_words) >= len(words) and all(name_words[i].startswith(w) for i, w in enumerate(words))


def score(product, item):
    """Plus petit = meilleur. Nutri-Score d'abord, puis NOVA, protéines pour les sources, popularité."""
    grade = GRADES.get((product.get("nutriscore_grade") or "").lower(), 5)
    nova = product.get("nova_group") or 4
    value = grade * 3 + (int(nova) - 1) * 2
    if item.get("protein"):
        value -= float((product.get("nutriments") or {}).get("proteins_100g") or 0) / 10
    value -= math.log10(float(product.get("unique_scans_n") or 0) + 1) / 2
    return value


def eligible(product, item):
    name = product.get("product_name_fr") or product.get("product_name") or ""
    brand = (product.get("brands") or "").split(",")[0].strip()
    if not name or not brand or not product.get("code"):
        return False
    tags = product.get("countries_tags")
    if tags and "en:france" not in tags:
        return False
    words = normalize(name).split()
    lead = item.get("lead", [])
    if lead and not any(starts(words, normalize(w)) for w in lead):
        return False
    if not all(contains(words, normalize(w)) for w in item["must"]):
        return False
    if any(contains(words, normalize(w)) for w in item.get("exclude", [])):
        return False
    if "maxFat" in item:
        fat = (product.get("nutriments") or {}).get("fat_100g")
        if fat is None or float(fat) > item["maxFat"]:
            return False
    return True


def picks(products, item):
    ranked = sorted((p for p in products if eligible(p, item)), key=lambda p: score(p, item))
    chosen, brands = [], []
    for product in ranked:
        # « Barilla » et « BARILLA NORGE AS » sont la même marque.
        brand = normalize(product["brands"].split(",")[0])
        if any(brand.startswith(seen) or seen.startswith(brand) for seen in brands):
            continue
        brands.append(brand)
        chosen.append(product)
        if len(chosen) == PICKS:
            break
    return chosen


def swift(text):
    return json.dumps(text, ensure_ascii=False)


def main(folder, output):
    responses = {}
    for path in sorted(pathlib.Path(folder).glob("*.json")):
        data = json.load(open(path))
        # Seules les réponses de search.pl pour les termes actuels comptent.
        if data.get("name") in ITEMS and data.get("terms") == ITEMS[data["name"]]["terms"]:
            responses[data["name"]] = data["products"]
    lines = [
        "// Fichier généré par scripts/openfoodfacts/build.py : ne pas modifier à la main.",
        "// Données Open Food Facts (openfoodfacts.org), licence ODbL.",
        "",
        "enum GroceryBrandTable {",
        "    static let entries: [String: GroceryBrandEntry] = [",
    ]
    for name, item in ITEMS.items():
        chosen = picks(responses.get(name, []), item)
        print(f"{name} : {', '.join(p['brands'].split(',')[0] + ' – ' + (p.get('product_name_fr') or p.get('product_name')) for p in chosen) or 'aucun produit retenu'}")
        query = (
            f"GroceryBrandQuery(terms: {swift(item['terms'])}, must: {swift(item['must'])}, exclude: {swift(item.get('exclude', []))}"
            + (f", lead: {swift(item['lead'])}" if item.get("lead") else "")
            + (f", maxFat: {item['maxFat']}" if "maxFat" in item else "")
            + (", isProteinSource: true" if item.get("protein") else "")
            + ")"
        )
        picks_swift = ",\n".join(
            "                GroceryBrandPick("
            f"brand: {swift(p['brands'].split(',')[0].strip())}, "
            f"product: {swift((p.get('product_name_fr') or p.get('product_name')).strip())}, "
            f"nutriScore: {swift((p.get('nutriscore_grade') or '').upper()) if (p.get('nutriscore_grade') or '').lower() in GRADES else 'nil'}, "
            f"nova: {int(p['nova_group']) if p.get('nova_group') else 'nil'}, "
            f"barcode: {swift(p['code'])})"
            for p in chosen
        )
        lines.append(f"        {swift(name)}: GroceryBrandEntry(")
        lines.append(f"            query: {query},")
        lines.append(f"            picks: [\n{picks_swift},\n            ]" if chosen else "            picks: []")
        lines.append("        ),")
    lines += ["    ]", "}", ""]
    pathlib.Path(output).write_text("\n".join(lines))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else ROOT / "Packages/BodyPilotKit/Sources/Nutrition/GroceryBrandTable.swift")
