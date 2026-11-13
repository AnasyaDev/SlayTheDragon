#!/usr/bin/env python3
"""Fabrique les fonds des scènes (Media/Backgrounds/*.tga) à partir d'illustrations du jeu.

Les illustrations sont des écrans de chargement de Blizzard extraits du jeu (FileDataID ci-dessous),
téléchargés depuis wago.tools (`https://wago.tools/api/casc/<id>?download`, BLP lu par Pillow) dans
build/decors_src/. À RÉÉVALUER avant toute publication de l'addon (droits de Blizzard).

Pour chaque fond retenu (BACKGROUNDS) : la source est ramenée à ses vraies proportions (`aspect` =
largeur / hauteur de l'image telle qu'affichée par le jeu : les écrans classiques 2048 × 2048 sont des
4:3 étirés), puis la zone `box` (fractions x0, y0, x1, y1 de l'image redressée, sans logo ni cadre)
est étirée sur toute la texture 1024 × 512. Le rapport réel de la zone (`ratio`, affiché par le script
et recopié dans UI/Art.lua) permet à l'interface de rétablir les proportions : elle n'en montre qu'une
bande au format du décor (1034 × 380 ≈ 2,72:1), placée en hauteur par `focus` (0 = haut, 1 = bas)
selon la scène. Une même image sert ainsi plusieurs scènes avec des cadrages différents.

Sorties : Media/Backgrounds/<clé>.tga (TGA 32 bits non compressé, même écriture que
tools/build_media.py : origine en bas à gauche, descripteur 0x08) et build/media_png/Backgrounds/<clé>.png
(aperçus pour Sim/ui_render.lua).

Usage (depuis la racine du dépôt, venv de tools/build_media.py) :
  build/venv/bin/python -I tools/build_backgrounds.py            # télécharge au besoin, fabrique
  build/venv/bin/python -I tools/build_backgrounds.py planche    # + build/decors_planche.jpg
"""
import pathlib, struct, sys, time, urllib.request
from PIL import Image, ImageDraw, ImageEnhance, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "build/decors_src"
OUT = ROOT / "Media/Backgrounds"
PREVIEW = ROOT / "build/media_png/Backgrounds"
PLANCHE = ROOT / "build/decors_planche.jpg"
URL = "https://wago.tools/api/casc/{}?download"
TEX_W, TEX_H = 1024, 512
BAND = 1034 / 380  # format de la bande du décor (UI/Scene.lua : S.W / S.DECOR_H)

# Fonds retenus : clé -> source. `scenes` = scènes d'Art.scenes qui l'emploient (planche, rapport).
# (La route, la colline, le camp, le marchand et le feu de camp de Westfall sont des décors peints
# depuis le 13/11/2026 : UI/Art.lua, Art.paintings ; l'illustration d'Elwynn n'est plus fabriquée.)
BACKGROUNDS = {
    "farm": dict(fdid=407226, name="Pics-Jumeaux (ferme et chemin)",
                 path="interface/glues/loadingscreens/loadscreentwinpeaksbg",
                 aspect=4 / 3, box=(0, 0.265, 1, 0.86), scenes="farm"),
    "deadmines": dict(fdid=131833, name="Mortemines (écran classique)",
                      path="interface/glues/loadingscreens/loadscreendeadmines",
                      aspect=4 / 3, box=(0, 0.235, 1, 0.80), scenes="mine"),
    "ruins": dict(fdid=7963782, name="Ruines de Lordaeron (écran Forever)",
                  path="interface/glues/loadingscreens/camelot160/main/loadscreen_camelot_ruinsoflordaeron",
                  aspect=2992 / 1684, box=(0, 0.162, 1, 0.838), scenes="ruins"),
    "coast": dict(fdid=427941, name="Gilnéas (phare et côte)",
                  path="interface/glues/loadingscreens/loadscreengilneasbg2",
                  aspect=4 / 3, box=(0, 0.26, 1, 0.86), scenes="coast"),
}

# Autres candidats examinés (planche seulement).
OTHERS = {
    "elwynn": dict(fdid=7377860, name="Forêt d'Elwynn (logement, Midnight)", aspect=2992 / 1684,
                   box=(0, 0.06, 1, 0.94), scenes="retiré : pas Westfall"),
    "excavation": dict(fdid=7963777, name="Excavation (écran Forever)", aspect=2992 / 1684,
                       box=(0, 0.165, 1, 0.838), scenes="farm ?"),
    "arathi": dict(fdid=2820825, name="Bassin d'Arathi (BfA, large)", aspect=16 / 9,
                   box=(0, 0.20, 1, 0.84), scenes="farm ?"),
    "goblinmine": dict(fdid=2016712, name="Mine gobeline (BfA, large)", aspect=16 / 9,
                       box=(0, 0.20, 1, 0.84), scenes="mine ?"),
    "ruinedcity": dict(fdid=131866, name="Cité en ruine (écran classique)", aspect=4 / 3,
                       box=(0, 0.24, 1, 0.80), scenes="ruins ?"),
    "gilneas": dict(fdid=405445, name="Gilnéas, la ville (crépuscule)", aspect=4 / 3,
                    box=(0, 0.26, 1, 0.86), scenes="night ?"),
    "waycrest": dict(fdid=1984118, name="Manoir Malvoie (BfA, large)", aspect=16 / 9,
                     box=(0, 0.20, 1, 0.84), scenes="night ?"),
    "ekforever": dict(fdid=7963776, name="Royaumes de l'Est (écran Forever)", aspect=2992 / 1684,
                      box=(0, 0.165, 1, 0.838), scenes="road ?"),
    "warsong": dict(fdid=2827086, name="Goulet des Chanteguerres (BfA, large)", aspect=16 / 9,
                    box=(0, 0.20, 1, 0.84), scenes="road ?"),
}

# Cadrage par scène pour la planche (mêmes valeurs que `focus` dans UI/Art.lua).
FOCUS = {"farm": 0.55, "deadmines": 0.5, "ruins": 0.5, "coast": 0.45}


def fetch(fdid):
    path = SRC / f"{fdid}.blp"
    if path.exists() and path.stat().st_size > 0:
        return path
    SRC.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(URL.format(fdid), headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = r.read()
    path.write_bytes(data)
    time.sleep(0.3)
    return path


def upright(spec):
    """Image source redressée à ses vraies proportions (largeur conservée)."""
    im = Image.open(fetch(spec["fdid"])).convert("RGB")
    w, h = im.size
    th = round(w / spec["aspect"])
    return im if th == h else im.resize((w, th), Image.LANCZOS)


def region(spec):
    """Zone `box` de l'image redressée et son rapport réel largeur / hauteur."""
    im = upright(spec)
    w, h = im.size
    x0, y0, x1, y1 = spec["box"]
    box = (round(x0 * w), round(y0 * h), round(x1 * w), round(y1 * h))
    return im.crop(box), (box[2] - box[0]) / (box[3] - box[1])


def band(im, ratio, focus):
    """Bande au format du décor dans une région de rapport `ratio`, placée par `focus`."""
    w, h = im.size
    if ratio >= BAND:
        bw = round(w * BAND / ratio)
        x = (w - bw) // 2
        return im.crop((x, 0, x + bw, h))
    bh = round(h * ratio / BAND)
    y = round((h - bh) * focus)
    return im.crop((0, y, w, y + bh))


def write_tga(im, path):
    """Comme tools/build_media.py : 32 bits, non compressé, origine en bas à gauche (0x08)."""
    im = im.convert("RGBA")
    w, h = im.size
    assert w & (w - 1) == 0 and h & (h - 1) == 0, f"{path} : dimensions {w}×{h} hors puissances de deux"
    flip = im.transpose(Image.FLIP_TOP_BOTTOM)
    r, g, b, a = flip.split()
    data = Image.merge("RGBA", (b, g, r, a)).tobytes()
    hdr = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 8)
    with open(path, "wb") as f:
        f.write(hdr)
        f.write(data)


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    PREVIEW.mkdir(parents=True, exist_ok=True)
    total = 0
    print("-- ratios à recopier dans UI/Art.lua (Art.backgrounds) :")
    for key, spec in BACKGROUNDS.items():
        im, ratio = region(spec)
        tex = im.resize((TEX_W, TEX_H), Image.LANCZOS)
        dst = OUT / f"{key}.tga"
        write_tga(tex, dst)
        tex.save(PREVIEW / f"{key}.png")
        total += dst.stat().st_size
        print(f"  {key:10s} {spec['fdid']:>8d}  ratio = {ratio:.3f}  ({dst.stat().st_size} octets)")
    print(f"total : {total} octets ({total / 1e6:.2f} Mo)")


def planche():
    cols, tw = 3, 530
    th = round(tw / BAND)
    entries = [(k, s, True) for k, s in BACKGROUNDS.items()] + [(k, s, False) for k, s in OTHERS.items()]
    rows = (len(entries) + cols - 1) // cols
    cap = 46
    sheet = Image.new("RGB", (cols * tw + (cols + 1) * 8, rows * (th + cap + 8) + 8), (28, 30, 36))
    d = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("DejaVuSans.ttf", 15)
        bold = ImageFont.truetype("DejaVuSans-Bold.ttf", 15)
    except OSError:
        font = bold = ImageFont.load_default()
    for i, (key, spec, kept) in enumerate(entries):
        im, ratio = region(spec)
        b = band(im, ratio, FOCUS.get(key, 0.5)).resize((tw, th), Image.LANCZOS)
        x = 8 + (i % cols) * (tw + 8)
        y = 8 + (i // cols) * (th + cap + 8)
        sheet.paste(b, (x, y))
        # tiers bas (sol des personnages)
        d.line((x, y + th * 2 // 3, x + tw, y + th * 2 // 3), fill=(255, 255, 255), width=1)
        if kept:
            d.rectangle((x - 3, y - 3, x + tw + 2, y + th + 2), outline=(240, 200, 60), width=3)
        d.text((x, y + th + 4), f"{spec['fdid']}  {spec['name']}", font=bold if kept else font,
               fill=(240, 200, 60) if kept else (220, 220, 220))
        d.text((x, y + th + 24), ("RETENU · " if kept else "écarté · ") + f"scènes : {spec['scenes']}"
               + f" · rapport {ratio:.2f}", font=font, fill=(180, 190, 200))
    sheet.save(PLANCHE, quality=88)
    print(f"planche : {PLANCHE} ({sheet.size[0]} × {sheet.size[1]})")


def scenes():
    """Aperçu des scènes illustrées telles que l'interface les compose (bande cadrée par `focus`,
    teinte, voile du bas), d'après Art.scenes relu dans UI/Art.lua : build/decors_scenes.jpg. Les décors
    peints (sans `art`) se voient dans les instantanés du harnais (Sim/ui_harness.lua, section UW)."""
    import re
    art = (ROOT / "UI/Art.lua").read_text(encoding="utf-8")
    block = art[art.index("Art.scenes = {"):]
    block = block[:block.index("\n}\n")]
    ill = art[art.index("Art.illustrations = {"):art.index("Art.scenes = {")]
    first = {}  # illustration -> fond embarqué en tête de sa liste
    for name, body in re.findall(r"\n  (\w+) = \{(.*?)\n?  ?\},?", ill, re.S):
        m = re.search(r"B\.(\w+)", body)
        if m:
            first[name] = m.group(1)
    tw = 517
    th = round(tw / BAND)
    rows = []
    for line in block.splitlines()[1:]:
        m = re.match(r"\s*(\w+) = \{ art = \"(\w+)\"(.*)", line)
        if not m:
            continue
        sid, ill_key, rest = m.groups()
        fm = re.search(r"focus = ([\d.]+)", rest)
        tm = re.search(r"tint = \{ ([\d.]+), ([\d.]+), ([\d.]+) \}", rest)
        rows.append((sid, first.get(ill_key), float(fm.group(1)) if fm else 0.5,
                     tuple(float(x) for x in tm.groups()) if tm else (1, 1, 1)))
    cols = 2
    sheet = Image.new("RGB", (cols * (tw + 8) + 8, ((len(rows) + 1) // 2) * (th + 30) + 8), (28, 30, 36))
    d = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("DejaVuSans.ttf", 15)
    except OSError:
        font = ImageFont.load_default()
    ground = Image.new("L", (1, 170))
    for y in range(170):
        ground.putpixel((0, y), round(255 * 0.38 * y / 169))
    for i, (sid, key, focus, tint) in enumerate(rows):
        spec = BACKGROUNDS[key]
        im, ratio = region(spec)
        b = band(im, ratio, focus).resize((1034, 380), Image.LANCZOS)
        r, g, bl = b.split()
        b = Image.merge("RGB", [c.point(lambda v, k=k: round(v * k)) for c, k in zip((r, g, bl), tint)])
        veil = Image.new("RGB", (1034, 170), (5, 8, 13))
        b.paste(veil, (0, 380 - 170), ground.resize((1034, 170)))
        x = 8 + (i % cols) * (tw + 8)
        y = 8 + (i // cols) * (th + 30)
        sheet.paste(b.resize((tw, th), Image.LANCZOS), (x, y))
        d.text((x, y + th + 5), f"{sid} : {key}.tga · focus {focus} · teinte {tint}", font=font, fill=(220, 220, 220))
    out = ROOT / "build/decors_scenes.jpg"
    sheet.save(out, quality=88)
    print(f"scènes : {out}")


if __name__ == "__main__":
    build()
    if "planche" in sys.argv[1:]:
        planche()
    if "scenes" in sys.argv[1:]:
        scenes()
