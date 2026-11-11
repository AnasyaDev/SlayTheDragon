#!/usr/bin/env python3
"""Planche et fichier d'inventaire des pièces d'interface WoW (build/wowui/inventaire.jpg et .json).
Usage : python3 -I docs/maquette/gen_wowui_inventaire.py   (après gen_wowui.py, qui écrit used.json)"""
import sys, json, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent))
import wowui_kit as K
from PIL import Image, ImageDraw

FAMILIES = [
    ("Boutons", ["panel_button", "dialog_button", "red128", "goldred", "redbutton9", "red_exit", "minimize"]),
    ("Cadres et fonds", ["dialog_border", "dialog_gold", "dialog_bg", "dialog_header", "bg_", "metal_", "diamond_", "df_corner", "df_bg", "df_parch",
                         "neutral_", "parch_", "questbg", "quest_", "taxi_tl", "tooltip"]),
    ("Cases d'icônes", ["quickslot", "emptyslot", "actionbutton", "whiteicon", "df_icon", "bag_", "tracking"]),
    ("Étapes du parcours", ["taxi_frame", "taxi_line", "taxinode", "vignette", "questnormal", "innkeeper", "banker", "dungeon", "questskull", "raid_skull",
                            "elite_", "talent", "boss_winged"]),
    ("Barres et cadres d'unité", ["statusbar", "target_frame", "nameplate", "skills_bar", "df_player", "df_boss", "essence", "adv_"]),
    ("Menus, monnaie, dialogue", ["checkbox", "slider", "min_slider", "gold_icon", "coin_gold", "gossip", "portrait"]),
]


def family(name):
    for fam, prefixes in FAMILIES:
        if any(name.startswith(p) for p in prefixes): return fam
    return "Divers"


SLICE_NOTE = {
    "3 tranches": "trois tranches", "neuf": "neuf tranches", "backdrop": "neuf tranches (backdrop : 8 segments)",
    "bord répété": "bord de neuf tranches", "4 quarts": "4 quarts assemblés (fenêtre fixe)", "tuile": "pavage",
    "répété": "pavage linéaire", "étirable": "étirable", "entier": "pièce entière",
}


def slicing(desc):
    for k, v in SLICE_NOTE.items():
        if desc.startswith(k) or k in desc: return v
    return desc


def pow2(n):
    v = 1
    while v < n: v *= 2
    return v


def tga_bytes(name, w, h):
    """TGA 32 bits non compressé dans une toile 2^n ; les grands fonds sont plafonnés à 1024 × 512 (réduits)."""
    W, H = pow2(w), pow2(h)
    while W * H > 1024 * 512: W, H = max(1, W // 2), max(1, H // 2)
    return W * H * 4 + 18


def main():
    used = {}
    up = K.B / "used.json"
    if up.exists(): used = json.loads(up.read_text())
    entries = {}
    for name, (fid, box, src, sl, use) in K.PIECES.items():
        w, h = K.native(name)
        is_2x = src.lower().endswith("-2x") or "-2x" in src.lower()
        pts = (w / 2, h / 2) if is_2x else (w, h)
        entries[name] = {
            "famille": family(name), "source": src, "fichier": None, "fileDataID": fid,
            "region": {"x": box[0], "y": box[1], "w": box[2], "h": box[3]} if box else "texture entière",
            "taille_native_px": [w, h], "atlas_2x": is_2x,
            "decoupe": slicing(sl), "decoupe_detail": sl, "usage": use,
            "directions": sorted(d for d, names in used.items() if name in names),
            "nette_jusqua_points_a_115pct": [round(pts[0] * (2 if is_2x else 1) / 1.15), round(pts[1] * (2 if is_2x else 1) / 1.15)],
            "tga_toile_px": [pow2(w), pow2(h)],
            "tga_octets": tga_bytes(name, w, h),
        }
    files = json.loads((K.B / "fichiers.json").read_text()) if (K.B / "fichiers.json").exists() else {}
    for e in entries.values(): e["fichier"] = files.get(str(e["fileDataID"]))
    doc = {
        "_lisezmoi": [
            "Pièces d'interface de World of Warcraft repérées pour l'habillage de Slay the Dragon (maquettes du 11/11/2026).",
            "fileDataID : fichier BLP de la build retail 12.1.5.70783, téléchargé par https://wago.tools/api/casc/<id>?download ; "
            "region : rectangle en pixels dans la texture (coordonnées de l'atlas, table UiTextureAtlasMember).",
            "nette_jusqua_points_a_115pct : taille d'affichage maximale (en points d'interface de la fenêtre) avant agrandissement, "
            "fenêtre à l'échelle 115 % sur un écran où 1 point = 1 pixel ; au-delà la texture est étirée et floute. Pour un atlas -2x, "
            "la taille native en pixels est le double de la taille logique : il reste net jusqu'à sa taille native.",
            "Embarquement : toutes ces pièces seront découpées et EMBARQUÉES dans l'addon en TGA (Media/WowUI/…), jamais appelées par "
            "SetAtlas ni par chemin du client : sur WoW Forever on ne peut pas tester de façon fiable qu'un fichier ou un atlas existe, "
            "et une texture absente s'affiche en aplat vert. Les TGA doivent avoir des côtés en puissance de 2 (on les place dans une "
            "toile 2^n et on règle SetTexCoord).",
            "Licence : art de Blizzard Entertainment, réutilisé dans un addon pour le jeu lui-même (même statut que les fonds de scène déjà embarqués).",
        ],
        "pieces": entries,
    }
    poids = {}
    for d, names in used.items():
        tot = sum(entries[n]["tga_octets"] for n in names if n in entries)
        poids[d] = {"pieces": len(names), "tga_32bits_ko": round(tot / 1024), "pieces_les_plus_lourdes": sorted(names, key=lambda n: -entries[n]["tga_octets"])[:5]}
    doc["poids_par_direction"] = poids
    print(json.dumps(poids, ensure_ascii=False))
    (K.B / "inventaire.json").write_text(json.dumps(doc, ensure_ascii=False, indent=1))

    # ---- planche
    S = 1; colw, pad = 300, 14
    fams = [f for f, _ in FAMILIES]
    by = {f: [n for n in K.PIECES if family(n) == f] for f in fams}
    ncol = 6
    f_t = K.ImageFont.truetype(str(K.FONTS["friz"]), 26)
    f_l = K.ImageFont.truetype(str(K.FONTS["friz"]), 15)
    f_s = K.ImageFont.truetype(str(K.FONTS["friz"]), 13)
    rows = []
    for f in fams:
        items = by[f]; cells = []
        for n in items:
            im = K.piece(n); k = min(260 / im.width, 150 / im.height, 3.0)
            if k > 1: im = im.resize((round(im.width * k), round(im.height * k)), Image.NEAREST)
            else: im = K.rs(im, im.width * k, im.height * k)
            cells.append((n, im))
        rows.append((f, cells))
    cell_h = 230
    height = 40 + sum(60 + ((len(c) + ncol - 1) // ncol) * cell_h for _, c in rows)
    out = Image.new("RGBA", (ncol * colw + 2 * pad, height), (28, 30, 36, 255)); d = ImageDraw.Draw(out)
    y = 20
    for f, cells in rows:
        d.text((pad, y), f, font=f_t, fill=(255, 209, 0)); y += 46
        for i, (n, im) in enumerate(cells):
            cx = pad + (i % ncol) * colw; cy = y + (i // ncol) * cell_h
            d.rectangle((cx + 4, cy, cx + colw - 6, cy + 160), fill=(64, 70, 64))
            out.alpha_composite(im, (cx + colw // 2 - im.width // 2, cy + 80 - im.height // 2))
            e = entries[n]; w, h = e["taille_native_px"]
            d.text((cx + 6, cy + 164), n, font=f_l, fill=(255, 255, 255))
            src = e["source"].split("/")[-1]
            d.text((cx + 6, cy + 183), (src[:36] + "…") if len(src) > 37 else src, font=f_s, fill=(190, 200, 214))
            dirs = ",".join(e["directions"]) or "-"
            d.text((cx + 6, cy + 200), f"FDID {e['fileDataID']}  ·  {w}×{h}  ·  {dirs}", font=f_s, fill=(160, 220, 160))
        y += ((len(cells) + ncol - 1) // ncol) * cell_h + 14
    out.convert("RGB").save(K.B / "inventaire.jpg", quality=88)
    print("inventaire :", len(entries), "pièces")


if __name__ == "__main__":
    main()
