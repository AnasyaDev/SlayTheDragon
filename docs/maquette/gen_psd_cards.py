#!/usr/bin/env python3
"""Génère des cartes depuis le « PSD Card Constructor » (pack Mechanized Magic, CC0)
en pilotant photocraft-cli. Usage : psd_cards.py <PSD> <dossier ICONS .tga> <dossier de sortie>"""
import json, subprocess, sys, pathlib
from PIL import Image, ImageDraw, ImageFont, ImageFilter

FONT = str(pathlib.Path.home() / ".local/share/fonts/BalooChettan2.ttf")

PSD, ICONS, OUT = sys.argv[1], pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3])
OUT.mkdir(parents=True, exist_ok=True)

# identifiants des calques (photocraft-cli info)
TXT = dict(health=283, attack=282, desc=281, name=280, type=279, mana=278)
RARITY = {1: 276, 2: 274, 3: 272, 4: 270, 5: 268, 6: 266, 7: 264, 8: 262}   # 1 triangle vert, 2 losange bleu, 3 pentagone violet, 4 orbe d'or, 5 rubis, 6 carré orange, 7 étoile bleue, 8 étoile rose
QUALITY = {"common": None, "uncommon": 1, "rare": 2, "epic": 3, "legendary": 6}
EMBLEM = {1: 259, 2: 257, 3: 255, 4: 253, 5: 251, 6: 249}
METAL = {1: 296, 2: 294, 3: 292, 4: 290, 5: 288}
PLASTIC = {1: 25, 2: 23, 3: 21}
ICON, STATS, DOWN, COLOR, GRADIENT, DARKER, INVERT = 237, 232, 224, 229, 228, 227, 230
FRONT_CIRCLE, BACK_CIRCLE = 239, 235


def icon_file(name, size=688):
    """Icône du jeu (128 px améliorée) agrandie à la taille du médaillon."""
    dst = OUT / f"_icon_{name}.png"
    if not dst.exists():
        im = Image.open(ICONS / f"{name}.tga").convert("RGBA")
        k = 0.07                                   # rogne le liseré d'origine de l'icône
        w = im.width
        im = im.crop((int(w * k), int(w * k), int(w * (1 - k)), int(w * (1 - k))))
        im.resize((size, size), Image.LANCZOS).save(dst)
    return str(dst)


def build(out, name, cost, desc, icon, color, rarity=None, emblem=None, metal=4, plastic=1,
          tag=None, darker=False, gradient=False, stats=False, desc_size=None, name_px=None, desc_dy=0):
    cmds = []
    def c(cmd, **p): cmds.append((cmd, p))
    def vis(layer, v): c("layer.setProps", layer=layer, visible=bool(v))
    for k, lid in RARITY.items(): vis(lid, k == rarity)
    for k, lid in EMBLEM.items(): vis(lid, k == emblem)
    for k, lid in METAL.items(): vis(lid, k == metal)
    for k, lid in PLASTIC.items(): vis(lid, k == plastic)
    vis(STATS, stats); vis(TXT["attack"], stats); vis(TXT["health"], stats)
    vis(DOWN, bool(tag)); vis(TXT["type"], bool(tag))
    vis(DARKER, darker); vis(GRADIENT, gradient)
    c("layer.fill.solidColor.set", layer=COLOR, color=color)
    vis(TXT["name"], False)      # le texte sur tracé se décentre quand on le remplace : nom redessiné après coup
    rarity = QUALITY.get(rarity, rarity)
    cmds[:] = [x for x in cmds if not (x[0] == "layer.setProps" and x[1]["layer"] in RARITY.values())]
    for k, lid in RARITY.items(): vis(lid, k == rarity)
    c("type.edit", layer=TXT["mana"], text=str(cost))
    parts = desc.split("**"); plain = "".join(parts); runs = []; pos = 0
    for i, part in enumerate(parts):
        if i % 2: runs.append({"start": pos, "end": pos + len(part), "weight": 800})
        pos += len(part)
    c("type.edit", layer=TXT["desc"], text=plain)
    if runs: c("type.edit", layer=TXT["desc"], runs=runs)
    if tag: c("type.edit", layer=TXT["type"], text=tag)
    if desc_size: c("type.setStyle", layer=TXT["desc"], size=desc_size)
    if desc_dy: c("type.edit", layer=TXT["desc"], move=[0, desc_dy])
    c("layer.smartObjects.replaceContents", layer=ICON, path=icon_file(icon))
    args = ["photocraft-cli", "run", PSD]
    for cmd, p in cmds:
        args += ["--cmd", cmd, "--params", json.dumps(p, ensure_ascii=False)]
    args += ["--out", str(OUT / out)]
    r = subprocess.run(args, capture_output=True, text=True)
    errs = [l for l in (r.stdout + r.stderr).splitlines() if "error" in l.lower()]
    print(out, "OK" if r.returncode == 0 and not errs else f"ECHEC {r.returncode}", *errs[:4], sep="\n  " if errs else " ")
    im = Image.open(OUT / out).convert("RGBA")
    f = ImageFont.truetype(FONT, name_px or 72)
    try: f.set_variation_by_axes([700])
    except Exception: pass
    lay = Image.new("RGBA", (900, 200)); d = ImageDraw.Draw(lay)
    sh = Image.new("RGBA", lay.size); ImageDraw.Draw(sh).text((450, 106), name, font=f, fill=(0, 0, 0, 200), anchor="mm")
    lay.alpha_composite(sh.filter(ImageFilter.GaussianBlur(4)))
    d.text((450, 100), name, font=f, fill=(255, 255, 255, 255), anchor="mm")
    lay = lay.rotate(-7.5, resample=Image.BICUBIC, expand=True)
    im.alpha_composite(lay, (522 - lay.width // 2, 222 - lay.height // 2))
    im.save(OUT / out)
    return OUT / out


if __name__ == "__main__":
    CARDS = json.loads(pathlib.Path(sys.argv[4]).read_text()) if len(sys.argv) > 4 else []
    for k in CARDS:
        build(**k)
