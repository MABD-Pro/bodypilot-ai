#!/usr/bin/env python3
"""Génère Packages/BodyPilotKit/Sources/Nutrition/CiqualTable.swift depuis la table Ciqual officielle.

Usage : scripts/ciqual/build.py <dossier des XML Ciqual>
Les XML viennent du workflow « Ciqual » (branche ci/ciqual) : git fetch origin ci/ciqual.
Garde, pour 100 g : énergie (kcal, règlement UE 1169/2011), protéines, glucides, lipides, fibres.
Les aliments infantiles (groupe 11) sont écartés.
"""
import glob, pathlib, sys
import xml.etree.ElementTree as ET

CONSTANTS = {"328": "kcal", "25000": "protein", "31000": "carbs", "40000": "fat", "34100": "fibre"}


def value(text):
    """« 12,3 » → 12.3 ; « traces » et « < 0,5 » → 0 ; « - » (non mesuré) → None."""
    text = (text or "").strip().replace(",", ".")
    if not text or text == "-":
        return None
    if text.lower() == "traces" or text.startswith("<"):
        return 0.0
    try:
        return float(text)
    except ValueError:
        return None


def main(folder):
    folder = pathlib.Path(folder)
    alim_file = sorted(glob.glob(str(folder / "alim_2*.xml")))[-1]
    compo_file = sorted(glob.glob(str(folder / "compo_*.xml")))[-1]
    edition = pathlib.Path(alim_file).stem.split("_", 1)[1]
    names = {}
    for alim in ET.parse(alim_file).getroot():
        if alim.findtext("alim_grp_code").strip() == "11":
            continue
        names[alim.findtext("alim_code").strip()] = " ".join(alim.findtext("alim_nom_fr").split())
    values = {code: {} for code in names}
    for _, element in ET.iterparse(compo_file):
        if element.tag != "COMPO":
            continue
        code = element.findtext("alim_code").strip()
        constant = CONSTANTS.get(element.findtext("const_code").strip())
        if code in values and constant:
            values[code][constant] = value(element.findtext("teneur"))
        element.clear()

    rows = []
    for code, name in names.items():
        found = values[code]
        # Sans énergie mesurée, l'aliment ne sert à rien au coach.
        if found.get("kcal") is None:
            continue
        numbers = [found.get(key) for key in ("kcal", "protein", "carbs", "fat", "fibre")]
        cells = ["" if number is None else f"{number:g}" for number in numbers]
        rows.append("\t".join([code, name.replace("\t", " ")] + cells))

    target = pathlib.Path(__file__).resolve().parents[2] / "Packages/BodyPilotKit/Sources/Nutrition/CiqualTable.swift"
    body = "\n".join(rows)
    target.write_text(
        "// Fichier généré par scripts/ciqual/build.py : ne pas modifier à la main.\n"
        f"// Table Ciqual (ANSES), édition {edition}, Licence Ouverte Etalab 2.0.\n"
        "// Colonnes : code, nom, kcal, protéines, glucides, lipides, fibres (pour 100 g ; vide = non mesuré).\n\n"
        "enum CiqualTable {\n"
        f"    static let edition = \"Ciqual {edition[:4]}\"\n"
        f"    static let rows = #\"\"\"\n{body}\n\"\"\"#\n"
        "}\n",
        encoding="utf-8",
    )
    print(f"{len(rows)} aliments écrits dans {target}")


if __name__ == "__main__":
    main(sys.argv[1])
