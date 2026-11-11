#!/usr/bin/env python3
"""Habillage « WoW » de l'interface (direction B, mana et parcours façon C) : pièces de l'interface de
World of Warcraft EMBARQUÉES dans l'addon (Media/WowUI/*.tga) et table UI/WowSkin.lua.

Les pièces sont des textures de Blizzard extraites du jeu (CASC retail, téléchargées par FileDataID) :
À RÉÉVALUER avant toute publication de l'addon. Elles ne sont jamais appelées par SetAtlas ni par un
chemin Interface\\… du client (sur WoW Forever, une texture absente s'affiche en aplat vert et rien ne
permet de le savoir) : tout est découpé ici puis livré avec l'addon.

Usage (depuis la racine du dépôt, venv de tools/build_media.py) :
  build/venv/bin/python -I tools/build_wowui.py [planche] [doc]
Sources : build/wowui_src/<FileDataID>.blp, retéléchargées si absentes depuis
https://wago.tools/api/casc/<FileDataID>?download (User-Agent générique).
Sorties : Media/WowUI/*.tga (TGA 32 bits non compressé, origine en bas à gauche, 8 bits d'alpha, toiles
en puissances de deux : même écriture que tools/build_media.py), UI/WowSkin.lua (GÉNÉRÉ), aperçus PNG
build/media_png/WowUI/*.png ; `planche` : build/wowui_planche.png (chaque pièce découpée, à contrôler
à l'œil) et build/wowui_assemblages.png (neuf et trois tranches assemblées).

Découpes : coordonnées d'atlas (table UiTextureAtlasMember, build 12.1.5) VÉRIFIÉES À L'ŒIL sur les
fichiers servis ; plusieurs feuilles ne correspondent plus à l'atlas connu (cadre d'unité compact,
barres, cadre doré des cases) : leurs rectangles sont mesurés à la main ou recalés sur l'alpha
(`fit`).
"""
import math, pathlib, struct, sys, urllib.request
from PIL import Image, ImageChops, ImageDraw, ImageOps

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "build" / "wowui_src"
MEDIA = ROOT / "Media" / "WowUI"
PREVIEW = ROOT / "build" / "media_png" / "WowUI"
LUA = ROOT / "UI" / "WowSkin.lua"
LUA_ROOT = "Interface\\AddOns\\SlayTheDragon\\Media\\WowUI\\"
UA = "Mozilla/5.0 (X11; Linux x86_64) Gecko/20100101"

# ---------------------------------------------------------------------------
# Sources : FileDataID -> fichier du client (retail 12.1.5)
# ---------------------------------------------------------------------------
FILES = {
    374155: "interface/framegeneral/ui-background-rock.blp",
    2406979: "interface/framegeneral/uiframemetal2x.blp",
    2406984: "interface/framegeneral/uiframemetalvertical2x.blp",
    2406987: "interface/framegeneral/uiframemetalhorizontal2x.blp",
    3056750: "interface/framegeneral/uiframediamondmetal2x.blp",
    3056755: "interface/framegeneral/uiframediamondmetalvertical2x.blp",
    3058483: "interface/framegeneral/uiframediamondmetalheader2x.blp",
    4699279: "interface/framegeneral/uiframedragonflightbackgroundtile.blp",
    4699152: "interface/framegeneral/uiframedragonflight.blp",
    2142239: "interface/framegeneral/uiframeneutral.blp",
    6794983: "interface/buttons/128redbutton9sliced.blp",
    3856481: "interface/buttons/128goldredbutton.blp",
    4698972: "interface/buttons/redbutton2x.blp",
    4642466: "interface/hud/uiunitframe2x.blp",
    4703662: "interface/hud/uiunitframeboss2x.blp",
    4615764: "interface/hud/uiactionbar2x.blp",
    4691255: "interface/containerframe/bags2x.blp",
    1300837: "interface/targetingframe/nameplates.blp",
    1121272: "interface/minimap/objecticonsatlas.blp",
    1455734: "interface/taxiframe/taxinodesatlas.blp",
    1455735: "interface/taxiframe/uitaxiline.blp",
    137032: "interface/taxiframe/ui-taxi-icon-gray.blp",
    137033: "interface/taxiframe/ui-taxi-icon-green.blp",
    137035: "interface/taxiframe/ui-taxi-icon-red.blp",
    137037: "interface/taxiframe/ui-taxi-icon-yellow.blp",
    4614134: "interface/common/checkboxminimal.blp",
    4567914: "interface/buttons/minimalsliderbar.blp",
}


def fetch(fid):
    p = SRC / f"{fid}.blp"
    if p.exists() and p.stat().st_size > 0:
        return p
    SRC.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(f"https://wago.tools/api/casc/{fid}?download", headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = r.read()
    if data[:4] != b"BLP2":
        raise SystemExit(f"{fid} : réponse inattendue (pas un BLP2)")
    p.write_bytes(data)
    print("téléchargé", fid, FILES[fid])
    return p


def load_blp(p):
    """BLP2 : Pillow (DXT, palette), sinon encodage 3 (BGRA brut) lu à la main."""
    try:
        im = Image.open(p)
        im.load()
        return im.convert("RGBA")
    except Exception:
        b = p.read_bytes()
        assert b[:4] == b"BLP2", p
        enc = b[8]
        w, h = struct.unpack_from("<II", b, 12)
        off = struct.unpack_from("<16I", b, 20)[0]
        if enc != 3:
            raise
        return Image.frombytes("RGBA", (w, h), b[off:off + w * h * 4], "raw", "BGRA")


_TEX = {}


def tex(fid):
    if fid not in _TEX:
        _TEX[fid] = load_blp(fetch(fid))
    return _TEX[fid]


def crop(fid, box):
    x, y, w, h = box
    return tex(fid).crop((x, y, x + w, y + h))


def fit(fid, box, pad=0, thr=10):
    """Rectangle resserré sur l'alpha (seuil thr) à l'intérieur d'une zone (élargie de pad)."""
    x, y, w, h = box
    im = tex(fid)
    x0, y0 = max(0, x - pad), max(0, y - pad)
    x1, y1 = min(im.width, x + w + pad), min(im.height, y + h + pad)
    a = im.crop((x0, y0, x1, y1)).split()[3].point(lambda v: 255 if v > thr else 0)
    bb = a.getbbox()
    assert bb, f"{fid} {box} : vide"
    return (x0 + bb[0], y0 + bb[1], bb[2] - bb[0], bb[3] - bb[1])


def rs(im, k):
    if k == 1:
        return im
    return im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)


# ---------------------------------------------------------------------------
# Écriture (même format que tools/build_media.py)
# ---------------------------------------------------------------------------

def bleed(im):
    """Couleur des pixels transparents = moyenne des voisins visibles (pas de liseré sombre au
    filtrage) ; l'alpha ne change pas."""
    import numpy as np
    from PIL import ImageFilter
    im = im.convert("RGBA")
    arr = np.asarray(im).astype(np.float32)
    rgb, a = arr[..., :3], arr[..., 3:] / 255.0
    known = (a > 0).astype(np.float32)
    out = rgb.copy()
    if known.all() or not known.any():
        return im
    w = a * known
    for r in (1, 2, 4, 8, 16, 32, 64):
        pm = Image.fromarray(np.clip(rgb * w, 0, 255).astype(np.uint8))
        km = Image.fromarray((w[..., 0] * 255).astype(np.uint8))
        pb = np.asarray(pm.filter(ImageFilter.BoxBlur(r))).astype(np.float32)
        kb = np.asarray(km.filter(ImageFilter.BoxBlur(r))).astype(np.float32)[..., None] / 255.0
        fill = (known[..., 0] == 0) & (kb[..., 0] > 0.004)
        out[fill] = np.clip(pb[fill] / kb[fill], 0, 255)
        known[fill] = 1
        rgb = out
        w = np.maximum(w, known * 0.5)
        if known.all():
            break
    res = np.concatenate([out, arr[..., 3:]], axis=-1).astype(np.uint8)
    return Image.fromarray(res, "RGBA")


def write_tga(im, path):
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


def pow2(n):
    p = 1
    while p < n:
        p *= 2
    return p


# ---------------------------------------------------------------------------
# Pièces
# ---------------------------------------------------------------------------
# PIECES[nom] = image découpée (pixels stockés) ; INFO[nom] = { fid, src (rectangle source), s (pixels
# stockés par pixel source), usage, + marges (cap / nine) en pixels stockés }.
PIECES, INFO = {}, {}
TILES = {}       # nom -> image d'un fichier à part (répétée en jeu : remplit sa toile sur l'axe répété)


def add(name, im, fid, src, s, usage, **extra):
    PIECES[name] = im
    INFO[name] = dict(fid=fid, src=list(src) if src else None, s=s, usage=usage, **extra)


def piece(name, fid, box, s=1.0, usage="", refine=False, **extra):
    if refine:
        box = fit(fid, box)
    add(name, rs(crop(fid, box), s), fid, box, s, usage, **extra)


def tile(name, im, fid, src, s, usage, axis, canvas=None):
    """Fichier à part : axis = "h" (répété horizontalement : largeur = toile), "v", "hv"."""
    w, h = im.size
    cw, ch = canvas or (pow2(w), pow2(h))
    if "h" in axis:
        assert cw == w, f"{name} : largeur {w} ≠ toile {cw} (répétition horizontale)"
    if "v" in axis:
        assert ch == h, f"{name} : hauteur {h} ≠ toile {ch} (répétition verticale)"
    cv = Image.new("RGBA", (cw, ch))
    cv.alpha_composite(im, (0, 0))
    TILES[name] = cv
    INFO[name] = dict(fid=fid, src=list(src) if src else None, s=s, usage=usage, tile=axis, pw=w, ph=h)


# --- Fenêtre : cadre métal (UI-Frame-Metal, -2x), fond roche, table Dragonflight
for n, box in (("metal_tl", (1, 1, 150, 150)), ("metal_tr", (153, 1, 150, 150)),
               ("metal_bl", (153, 153, 64, 64)), ("metal_br", (219, 153, 64, 64))):
    piece(n, 2406979, box, 1, "cadre de la fenêtre (UI-Frame-Metal-Corner*-2x)")
tile("metal_top", crop(2406987, (0, 1, 64, 150)), 2406987, (0, 1, 64, 150), 1, "barre de titre (_UI-Frame-Metal-EdgeTop-2x)", "h")
tile("metal_bottom", crop(2406987, (0, 153, 32, 64)), 2406987, (0, 153, 32, 64), 1, "bord bas, filet du plateau (_UI-Frame-Metal-EdgeBottom-2x)", "h")
tile("metal_left", crop(2406984, (1, 0, 150, 32)), 2406984, (1, 0, 150, 32), 1, "bord gauche (!UI-Frame-Metal-EdgeLeft-2x)", "v")
tile("metal_right", crop(2406984, (153, 0, 150, 32)), 2406984, (153, 0, 150, 32), 1, "bord droit (!UI-Frame-Metal-EdgeRight-2x)", "v")
tile("rock", rs(tex(374155), 0.25), 374155, (0, 0, 1024, 1024), 0.25, "fond des fenêtres (UI-Background-Rock), réduit à 256", "hv")
tile("table", tex(4699279).copy(), 4699279, (0, 0, 256, 256), 1, "table du bas (UI-Frame-DragonFlight-BackgroundTile)", "hv")

# --- Boîtes de dialogue : DiamondMetal (-2x, stockées à 0,5)
for n, box in (("diamond_tl", (1, 521, 128, 128)), ("diamond_tr", (1, 651, 128, 128)),
               ("diamond_bl", (1, 261, 128, 128)), ("diamond_br", (1, 391, 128, 128))):
    piece(n, 3056750, box, 0.5, "boîte de dialogue (UI-Frame-DiamondMetal-Corner*-2x)")
tile("diamond_top", rs(crop(3056750, (0, 131, 128, 128)), 0.5), 3056750, (0, 131, 128, 128), 0.5, "bord haut (_UI-Frame-DiamondMetal-EdgeTop-2x)", "h")
tile("diamond_bottom", rs(crop(3056750, (0, 1, 128, 128)), 0.5), 3056750, (0, 1, 128, 128), 0.5, "bord bas (_UI-Frame-DiamondMetal-EdgeBottom-2x)", "h")
tile("diamond_left", rs(crop(3056755, (1, 0, 128, 128)), 0.5), 3056755, (1, 0, 128, 128), 0.5, "bord gauche (!UI-Frame-DiamondMetal-EdgeLeft-2x)", "v")
tile("diamond_right", rs(crop(3056755, (131, 0, 128, 128)), 0.5), 3056755, (131, 0, 128, 128), 0.5, "bord droit (!UI-Frame-DiamondMetal-EdgeRight-2x)", "v")
piece("header_l", 3058483, (1, 159, 128, 156), 0.5, "en-tête de titre (UI-Frame-DiamondMetal-Header-CornerLeft-2x)")
piece("header_r", 3058483, (1, 317, 128, 156), 0.5, "en-tête de titre (UI-Frame-DiamondMetal-Header-CornerRight-2x)")
tile("header_m", rs(crop(3058483, (0, 1, 128, 156)), 0.5), 3058483, (0, 1, 128, 156), 0.5, "en-tête de titre (_UI-Frame-DiamondMetal-Header-Tile-2x)", "h")

# --- Parchemins : Dragonflight (texte des rencontres), Neutral (carte des trajets)
tile("parch_text", crop(4699152, (169, 448, 515, 438)).resize((256, 218), Image.LANCZOS), 4699152, (169, 448, 515, 438),
     256 / 515, "parchemin des textes (UI-Frame-DragonFlight-CardParchmentWider)", "")
tile("parch_map", crop(2142239, (257, 152, 515, 438)).resize((512, 435), Image.LANCZOS), 2142239, (257, 152, 515, 438),
     512 / 515, "parchemin du parcours (UI-Frame-Neutral-CardParchmentWider)", "")
piece("ribbon", 2142239, (649, 592, 281, 84), 1, "ruban du nom du boss (UI-Frame-Neutral-Ribbon)")

# --- Boutons : rouge (128-RedButton, neuf tranches), rouge et or (128-GoldRedButton), fermeture
piece("btn_red", 6794983, (1, 261, 470, 128), 0.5, "bouton rouge (128-RedButton-Up, 9-sliced)", refine=True, cap=24)
gl, gr = crop(3856481, (295, 521, 114, 128)), crop(3856481, (1, 521, 292, 128))
gold = Image.new("RGBA", (gl.width + gr.width, 128))
gold.alpha_composite(gl, (0, 0))
gold.alpha_composite(gr, (gl.width, 0))
gold = gold.crop(gold.getbbox())
add("btn_goldred", rs(gold, 0.5), 3856481, (295, 521, 406, 128), 0.5,
    "bouton rouge et or (128-GoldRedButton-Left + Right)", cap=24)
piece("btn_close", 4698972, (39, 1, 36, 38), 1, "bouton de fermeture (RedButton-Exit-2x)", refine=True)

# --- Cadres d'unité et barres (Dragonflight, -2x, stockés à 0,75)
S_UNIT = 0.75
piece("unit_player", 4642466, (1, 171, 396, 142), S_UNIT, "cadre du héros (UI-HUD-UnitFrame-Player-PortraitOn-2x)")
piece("bar_hp", 4642466, (889, 415, 248, 40), 0.75, "barre de vie (…-Player-PortraitOn-Bar-Health-2x)")
piece("bar_absorb", 4642466, (642, 524, 240, 18), 0.75, "barre d'Absorption (…-Bar-Mana-2x, mesurée à la main)")
piece("bar_yellow", 4703662, (337, 209, 169, 15), 0.75, "barre jaune : incantation, réputation (…-Boss-Small-PortraitOff-Bar-Energy-2x)", refine=True)
piece("unit_boss", 4703662, (201, 1, 230, 112), S_UNIT, "cadre compact d'élite / boss, dragon d'or (…-Boss-Small-PortraitOff-2x)")
# Cadre compact ordinaire : la moitié gauche du même cadre (sans le dragon) et son miroir.
fr = crop(4703662, (203, 18, 90, 76))
clean = Image.new("RGBA", (180, 76))
clean.alpha_composite(fr, (0, 0))
clean.alpha_composite(ImageOps.mirror(fr), (90, 0))
add("unit_enemy", rs(clean, S_UNIT), 4703662, (203, 18, 90, 76), S_UNIT,
    "cadre compact d'ennemi (moitié gauche du cadre de boss et son miroir, sans le dragon)", cap=18)
piece("bar_enemy", 4703662, (337, 165, 169, 20), 0.75, "barre de vie compacte (…-Boss-Small-PortraitOff-Bar-Health-2x)")
piece("elite_dragon", 1300837, (1, 1, 80, 80), 1, "dragon d'or des élites et boss (nameplates-icon-elite-gold)")

# --- Cases d'icônes (barre d'action Dragonflight, -2x, stockées à 0,75 : nettes jusqu'à 60 unités)
piece("slot_bg", 4615764, (359, 209, 128, 124), 0.75, "fond de case (UI-HUD-ActionBar-IconFrame-Slot-2x)")
piece("slot_frame", 4615764, (359, 649, 92, 90), 0.75, "cadre de case (UI-HUD-ActionBar-IconFrame-2x)")
piece("slot_hover", 4615764, (358, 543, 92, 94), 0.75, "cadre doré de survol (UI-HUD-ActionBar-IconFrame-Mouseover-2x, mesuré)", refine=True)

# --- Anneaux dorés
ring = crop(2406979, (12, 165, 130, 130))
m = Image.new("L", (130 * 4, 130 * 4), 0)
c, ro, ri = 65 * 4, 61.5 * 4, 49 * 4
ImageDraw.Draw(m).ellipse((c - ro, c - ro, c + ro, c + ro), fill=255)
ImageDraw.Draw(m).ellipse((c - ri, c - ri, c + ri, c + ri), fill=0)
m = m.resize((130, 130), Image.LANCZOS)
ring.putalpha(ImageChops.multiply(ring.split()[3], m))
# restes du cadre métal sous l'anneau (gris peu saturé, ni or ni ombre) : effacés
px = ring.load()
for yy in range(ring.height):
    for xx in range(ring.width):
        r_, g_, b_, a_ = px[xx, yy]
        if a_ and max(r_, g_, b_) - min(r_, g_, b_) < 28 and (r_ + g_ + b_) / 3 > 50:
            px[xx, yy] = (r_, g_, b_, 0)
ring = ring.crop(ring.getbbox())
add("ring_large", ring, 2406979, (12, 165, 130, 130), 1,
    "grand anneau doré : mana, objets ronds, boss (anneau de UI-Frame-PortraitMetal-CornerTopLeft-2x, isolé)")
piece("ring_small", 4691255, (295, 1, 61, 61), 1, "petit anneau doré : étapes du parcours, Démence (bag-border-2x)", refine=True)

# --- Parcours (carte de vol)
piece("boot", 1455734, (1, 187, 74, 74), 1, "botte ailée : position (taxi_frame_yellow)", refine=True)
line = crop(1455735, (1, 0, 32, 32)).rotate(90, expand=True)
add("taxi_line", line, 1455735, (1, 0, 32, 32), 1, "trait de trajet, couché (!UI-Taxi-Line)", stretch="h")
piece("elite_node", 1121272, (203, 659, 64, 64), 1, "étape d'élite (VignetteKillElite)", refine=True)
for col, fid in (("green", 137033), ("yellow", 137037), ("gray", 137032), ("red", 137035)):
    piece("pip_" + col, fid, (0, 0, 16, 16), 1, f"pastille de progression (ui-taxi-icon-{col})")

# --- Menus : case à cocher et curseur minimaux
piece("check_box", 4614134, (1, 1, 30, 29), 1, "case à cocher (checkbox-minimal)", refine=True)
piece("check_mark", 4614134, (4, 31, 28, 28), 1, "coche (checkbox-minimal, coche jaune)", refine=True)
piece("slider_l", 4567914, (14, 41, 11, 17), 1, "curseur, bout gauche (Minimal_SliderBar_Left)")
piece("slider_m", 4567914, (0, 1, 1, 17), 1, "curseur, milieu (_Minimal_SliderBar_Middle)", stretch="h")
piece("slider_r", 4567914, (1, 62, 11, 17), 1, "curseur, bout droit (Minimal_SliderBar_Right)")
piece("slider_thumb", 4567914, (1, 20, 20, 19), 1, "poignée (Minimal_SliderBar_Button)")
piece("arrow_l", 4567914, (1, 41, 11, 19), 1, "flèche gauche (Minimal_SliderBar_Button_Left)")
piece("arrow_r", 4567914, (1, 81, 9, 18), 1, "flèche droite (Minimal_SliderBar_Button_Right)")


# ---------------------------------------------------------------------------
# Mesures (métadonnées pour la mise en page)
# ---------------------------------------------------------------------------

def rows_alpha(im, x):
    return [im.getpixel((x, y))[3] for y in range(im.height)]


def runs(vals, thr=40):
    out, start = [], None
    for i, v in enumerate(vals + [0]):
        if v > thr and start is None:
            start = i
        elif v <= thr and start is not None:
            out.append((start, i))
            start = None
    return out


META = {}
top = TILES["metal_top"].crop((0, 0, 64, 150))
lum = [sum(top.getpixel((32, y))[:3]) * top.getpixel((32, y))[3] // 255 for y in range(150)]
opaque = [y for y in range(150) if top.getpixel((32, y))[3] > 200]
META["metal"] = {"barTop": opaque[0], "barBottom": opaque[-1] + 1}
left = TILES["metal_left"].crop((0, 0, 150, 32))
cols = [x for x in range(150) if left.getpixel((x, 16))[3] > 120]
META["metal"]["lineL0"], META["metal"]["lineL1"] = cols[0], cols[-1] + 1
right = TILES["metal_right"].crop((0, 0, 150, 32))
cols = [x for x in range(150) if right.getpixel((x, 16))[3] > 120]
META["metal"]["lineR0"], META["metal"]["lineR1"] = cols[0], cols[-1] + 1
bot = TILES["metal_bottom"].crop((0, 0, 32, 64))
rows = [y for y in range(64) if bot.getpixel((16, y))[3] > 120]
META["metal"]["lineB0"], META["metal"]["lineB1"] = rows[0], rows[-1] + 1
# DiamondMetal : position du filet (pixels stockés, 64 par bord)
dt = TILES["diamond_top"].crop((0, 0, 64, 64))
rows = [y for y in range(64) if dt.getpixel((32, y))[3] > 120]
META["diamond"] = {"lineT0": rows[0], "lineT1": rows[-1] + 1}
db_ = TILES["diamond_bottom"].crop((0, 0, 64, 64))
rows = [y for y in range(64) if db_.getpixel((32, y))[3] > 120]
META["diamond"]["lineB0"], META["diamond"]["lineB1"] = rows[0], rows[-1] + 1
dl = TILES["diamond_left"].crop((0, 0, 64, 64))
cols = [x for x in range(64) if dl.getpixel((x, 32))[3] > 120]
META["diamond"]["lineL0"], META["diamond"]["lineL1"] = cols[0], cols[-1] + 1
dr = TILES["diamond_right"].crop((0, 0, 64, 64))
cols = [x for x in range(64) if dr.getpixel((x, 32))[3] > 120]
META["diamond"]["lineR0"], META["diamond"]["lineR1"] = cols[0], cols[-1] + 1
hm = TILES["header_m"].crop((0, 0, 64, 78))
rows = [y for y in range(78) if hm.getpixel((32, y))[3] > 120]
META["header"] = {"top": rows[0], "bottom": rows[-1] + 1}
# Cadre du héros : portrait (anneau), barres (pixels stockés, mesurés sur la pièce)
# Cadres d'unité : logements mesurés sur les pièces stockées à 0,6, convertis à l'échelle stockée.
UNIT_META = {"unit_player": {"portrait": [11, 8, 64, 64], "name": [84, 12, 142, 18], "hp": [81, 31, 148, 23],
                             "absorb": [81, 56, 148, 12]},
             "unit_enemy": {"name": [6, 2, 96, 15], "hp": [3, 19, 102, 11], "low": [3, 32, 102, 9]},
             "unit_boss": {"name": [5, 11, 96, 15], "hp": [3, 29, 100, 11], "low": [3, 42, 100, 9]}}
for _n, _d in UNIT_META.items():
    META[_n] = {k: [round(v * S_UNIT / 0.6, 1) for v in box] for k, box in _d.items()}

# ---------------------------------------------------------------------------
# Atlas : rangées (étagères) dans une toile de 1024 de large, 3 pixels d'écart, bords répétés
# ---------------------------------------------------------------------------
PAD = 3
order = sorted(PIECES, key=lambda n: (-PIECES[n].height, n))
W = 1024
x = y = PAD
rowh = 0
SLOT = {}
for n in order:
    im = PIECES[n]
    if x + im.width + PAD > W:
        x = PAD
        y += rowh + 2 * PAD
        rowh = 0
    SLOT[n] = (x, y)
    x += im.width + 2 * PAD
    rowh = max(rowh, im.height)
H = pow2(y + rowh + PAD)
atlas = Image.new("RGBA", (W, H))
for n, (px, py) in SLOT.items():
    im = PIECES[n]
    # bords répétés dans l'écart (filtrage bilinéaire aux limites d'une tranche : rien ne déborde)
    ext = Image.new("RGBA", (im.width + 2 * PAD, im.height + 2 * PAD))
    big = im.resize((im.width, im.height))
    ext.paste(big.crop((0, 0, im.width, 1)).resize((im.width, PAD)), (PAD, 0))
    ext.paste(big.crop((0, im.height - 1, im.width, im.height)).resize((im.width, PAD)), (PAD, PAD + im.height))
    ext.paste(ext.crop((PAD, 0, PAD + 1, ext.height)).resize((PAD, ext.height)), (0, 0))
    ext.paste(ext.crop((PAD + im.width - 1, 0, PAD + im.width, ext.height)).resize((PAD, ext.height)), (PAD + im.width, 0))
    ext.paste(im, (PAD, PAD))
    ext.putalpha(Image.new("L", ext.size, 0))
    a = Image.new("L", ext.size, 0)
    a.paste(im.split()[3], (PAD, PAD))
    a.paste(a.crop((PAD, PAD, PAD + im.width, PAD + 1)).resize((im.width, PAD)), (PAD, 0))
    a.paste(a.crop((PAD, PAD + im.height - 1, PAD + im.width, PAD + im.height)).resize((im.width, PAD)), (PAD, PAD + im.height))
    a.paste(a.crop((PAD, 0, PAD + 1, a.height)).resize((PAD, a.height)), (0, 0))
    a.paste(a.crop((PAD + im.width - 1, 0, PAD + im.width, a.height)).resize((PAD, a.height)), (PAD + im.width, 0))
    ext.putalpha(a)
    atlas.alpha_composite(ext, (px - PAD, py - PAD))
# les écarts gardent l'alpha des bords répétés : seule la couleur des pixels encore transparents est saignée
atlas = bleed(atlas)

MEDIA.mkdir(parents=True, exist_ok=True)
PREVIEW.mkdir(parents=True, exist_ok=True)
for old in MEDIA.glob("*.tga"):
    old.unlink()
write_tga(atlas, MEDIA / "atlas.tga")
atlas.save(PREVIEW / "atlas.png")
for n, im in TILES.items():
    im2 = bleed(im)
    write_tga(im2, MEDIA / f"{n}.tga")
    im2.save(PREVIEW / f"{n}.png")


# ---------------------------------------------------------------------------
# UI/WowSkin.lua
# ---------------------------------------------------------------------------

def num(v):
    if isinstance(v, float):
        s = ("%.5f" % v).rstrip("0").rstrip(".")
        return s if s not in ("", "-0") else "0"
    return str(v)


def lua(v, ind=""):
    if isinstance(v, dict):
        inner = ind + "  "
        parts = []
        for k in sorted(v):
            kk = k if isinstance(k, str) and k.isidentifier() else f'["{k}"]'
            parts.append(f"{inner}{kk} = {lua(v[k], inner)},")
        return "{\n" + "\n".join(parts) + "\n" + ind + "}"
    if isinstance(v, (list, tuple)):
        return "{ " + ", ".join(lua(x, ind) for x in v) + " }"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return num(v)
    return '"' + str(v).replace("\\", "\\\\").replace('"', '\\"') + '"'


pieces = {}
for n, im in PIECES.items():
    px, py = SLOT[n]
    e = {"file": "atlas.tga", "w": W, "h": H, "pw": im.width, "ph": im.height,
         "tc": [px / W, (px + im.width) / W, py / H, (py + im.height) / H], "fid": INFO[n]["fid"]}
    for k in ("cap", "nine", "stretch"):
        if k in INFO[n]:
            e[k] = INFO[n][k]
    pieces[n] = e
for n, im in TILES.items():
    i = INFO[n]
    e = {"file": f"{n}.tga", "w": im.width, "h": im.height, "pw": i["pw"], "ph": i["ph"],
         "tc": [0, i["pw"] / im.width, 0, i["ph"] / im.height], "fid": i["fid"]}
    if i["tile"]:
        e["tile"] = i["tile"]
    pieces[n] = e

head = ("-- Fichier GÉNÉRÉ par tools/build_wowui.py : ne pas modifier à la main (relancer le script).\n"
        "-- Habillage WoW : pièces de l'interface de World of Warcraft (textures de Blizzard extraites du jeu,\n"
        "-- à réévaluer avant publication), EMBARQUÉES dans Media/WowUI (jamais d'atlas ni de chemin du client).\n"
        "-- pieces[nom] = { file, w × h (toile), pw × ph (pièce, pixels stockés), tc = coordonnées de texture\n"
        "-- de la pièce, cap = bouts d'un trois tranches (pixels stockés), tile = axe répété (fichier à part),\n"
        "-- stretch = axe étiré par construction (milieu d'un rail, trait de trajet),\n"
        "-- fid = FileDataID de la source } ; meta = mesures pour la mise en page (pixels stockés).\n"
        "local _, ns = ...\n\n")
LUA.write_text(head + "ns.WowSkin = " + lua({"root": LUA_ROOT, "pieces": pieces, "meta": META}) + "\n", encoding="utf-8")

total = sum(p.stat().st_size for p in MEDIA.glob("*.tga"))
print(f"{len(PIECES)} pièces dans l'atlas {W}×{H}, {len(TILES)} fichiers répétés ; Media/WowUI = {total / 1048576:.2f} Mo")


# ---------------------------------------------------------------------------
# Planches de contrôle
# ---------------------------------------------------------------------------

def label_sheet(items, path, cols_w=1500, bg=(60, 66, 60)):
    x = y = 10
    rowh = 0
    pos = []
    for n, im in items:
        w = max(im.width, 110)
        if x + w + 10 > cols_w:
            x = 10
            y += rowh + 26
            rowh = 0
        pos.append((n, im, x, y))
        x += w + 12
        rowh = max(rowh, im.height)
    sheet = Image.new("RGBA", (cols_w, y + rowh + 34), bg + (255,))
    d = ImageDraw.Draw(sheet)
    for n, im, x, y in pos:
        d.rectangle((x - 1, y - 1, x + im.width, y + im.height), outline=(255, 0, 255))
        sheet.alpha_composite(im, (x, y))
        d.text((x, y + im.height + 4), f"{n} {im.width}x{im.height}", fill=(255, 255, 0))
    sheet.convert("RGB").save(path)


def three(im, cap, w, h):
    k = h / im.height
    c = round(cap * k)
    L = im.crop((0, 0, cap, im.height)).resize((c, h), Image.LANCZOS)
    R = im.crop((im.width - cap, 0, im.width, im.height)).resize((c, h), Image.LANCZOS)
    M = im.crop((cap, 0, im.width - cap, im.height)).resize((max(1, w - 2 * c), h), Image.LANCZOS)
    out = Image.new("RGBA", (w, h))
    out.alpha_composite(M, (c, 0))
    out.alpha_composite(L, (0, 0))
    out.alpha_composite(R, (w - c, 0))
    return out


if "planche" in sys.argv[1:]:
    items = [(n, PIECES[n]) for n in sorted(PIECES)] + [(n, TILES[n]) for n in sorted(TILES)]
    label_sheet(items, ROOT / "build" / "wowui_planche.png")
    asm = [("btn_red 220x40", three(PIECES["btn_red"], INFO["btn_red"]["cap"], 220, 40)),
           ("btn_goldred 260x50", three(PIECES["btn_goldred"], INFO["btn_goldred"]["cap"], 260, 50)),
           ("unit_enemy 140x59", three(PIECES["unit_enemy"], INFO["unit_enemy"]["cap"], 140, 46)),
           ("slider 200x17", three(Image.merge("RGBA", PIECES["slider_l"].split()), 0, 1, 17))]
    sl = Image.new("RGBA", (200, 17))
    sl.alpha_composite(PIECES["slider_m"].resize((200 - 22, 17)), (11, 0))
    sl.alpha_composite(PIECES["slider_l"], (0, 0))
    sl.alpha_composite(PIECES["slider_r"], (189, 0))
    asm[-1] = ("slider 200x17", sl)
    # case d'action avec icône
    slot = Image.new("RGBA", (64, 62))
    slot.alpha_composite(PIECES["slot_bg"], (0, 0))
    fr = PIECES["slot_frame"]
    slot.alpha_composite(fr, ((64 - fr.width) // 2, (62 - fr.height) // 2))
    asm.append(("case", slot))
    # cadre de fenêtre réduit (k = 0,87) : coins et bords répétés
    k = 0.87
    def sc(im):
        return im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
    tl, tr, bl, br = sc(PIECES["metal_tl"]), sc(PIECES["metal_tr"]), sc(PIECES["metal_bl"]), sc(PIECES["metal_br"])
    tp, bt = sc(TILES["metal_top"].crop((0, 0, 64, 150))), sc(TILES["metal_bottom"])
    lf, rt = sc(TILES["metal_left"].crop((0, 0, 150, 32))), sc(TILES["metal_right"].crop((0, 0, 150, 32)))
    FW, FH = 700, 300
    fw = Image.new("RGBA", (FW, FH), (30, 30, 34, 255))
    for xx in range(tl.width, FW - tr.width, tp.width):
        fw.alpha_composite(tp, (xx, 0))
    for xx in range(bl.width, FW - br.width, bt.width):
        fw.alpha_composite(bt, (xx, FH - bt.height))
    for yy in range(tl.height, FH - bl.height, lf.height):
        fw.alpha_composite(lf, (0, yy))
        fw.alpha_composite(rt, (FW - rt.width, yy))
    fw.alpha_composite(tl, (0, 0))
    fw.alpha_composite(tr, (FW - tr.width, 0))
    fw.alpha_composite(bl, (0, FH - bl.height))
    fw.alpha_composite(br, (FW - br.width, FH - br.height))
    asm.append(("cadre métal k=0,87", fw))
    # boîte DiamondMetal (k = 0,5 des pièces stockées)
    k2 = 0.5
    def sc2(im):
        return im.resize((max(1, round(im.width * k2)), max(1, round(im.height * k2))), Image.LANCZOS)
    DW, DH = 300, 200
    dd = Image.new("RGBA", (DW, DH), (30, 30, 34, 255))
    rock = TILES["rock"]
    for xx in range(0, DW, rock.width):
        for yy in range(0, DH, rock.height):
            dd.alpha_composite(rock, (xx, yy))
    p = {n: sc2(PIECES[n]) for n in ("diamond_tl", "diamond_tr", "diamond_bl", "diamond_br")}
    t = {n: sc2(TILES[n]) for n in ("diamond_top", "diamond_bottom", "diamond_left", "diamond_right")}
    c0 = p["diamond_tl"].width
    for xx in range(c0, DW - c0, t["diamond_top"].width):
        dd.alpha_composite(t["diamond_top"], (xx, 0))
        dd.alpha_composite(t["diamond_bottom"], (xx, DH - t["diamond_bottom"].height))
    for yy in range(c0, DH - c0, t["diamond_left"].height):
        dd.alpha_composite(t["diamond_left"], (0, yy))
        dd.alpha_composite(t["diamond_right"], (DW - t["diamond_right"].width, yy))
    dd.alpha_composite(p["diamond_tl"], (0, 0))
    dd.alpha_composite(p["diamond_tr"], (DW - c0, 0))
    dd.alpha_composite(p["diamond_bl"], (0, DH - c0))
    dd.alpha_composite(p["diamond_br"], (DW - c0, DH - c0))
    asm.append(("dialogue DiamondMetal", dd))
    label_sheet(asm, ROOT / "build" / "wowui_assemblages.png", bg=(40, 44, 40))
    print("planches : build/wowui_planche.png, build/wowui_assemblages.png")

if "doc" in sys.argv[1:]:
    # table des pièces pour docs/interface.md (nom, FileDataID, taille stockée, usage)
    print("| Pièce | FileDataID | Stockée (px) | Usage |")
    print("|---|---|---|---|")
    for n in sorted(INFO):
        i = INFO[n]
        im = PIECES.get(n) or TILES[n]
        w, h = (im.size if n in PIECES else (i["pw"], i["ph"]))
        print(f"| `{n}` | {i['fid']} | {w}×{h}{' (répétée)' if i.get('tile') else ''} | {i['usage']} |")
