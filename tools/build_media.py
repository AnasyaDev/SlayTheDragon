#!/usr/bin/env python3
"""Fabrique les textures des cartes (Media/), la police, les icônes et UI/SkinData.lua.

L'habillage de l'interface (fenêtre, boutons, cadres, cases, parcours) n'est plus fabriqué ici : ce sont
des pièces de l'interface du jeu, embarquées par tools/build_wowui.py (Media/WowUI, UI/WowSkin.lua).
Restent ici : pièces des cartes, dos de carte, ardoise et liseré des plaques posées sous une carte,
halos, masque rond, police et icônes.

Sources (lecture seule) :
  * le PSD « Card Constructor » du pack Mechanized Magic (Dumivid, CC0), piloté par photocraft-cli :
    chaque pièce est rendue seule (visibilité des calques), puis rognée, mise à l'échelle et posée
    dans une toile en puissances de deux ;
  * la police Baloo Chettan 2 (variable, OFL) : instances statiques 500 / 700 / 800, réduites au latin ;
  * les icônes améliorées 128 px (ICONS/*.tga) : seulement celles que nomme UI/Art.lua (champ `tga`).

Sorties : Media/*.tga (TGA 32 bits non compressé, origine en bas à gauche, alpha 8 bits — le format
des icônes améliorées et des addons), Media/Icons/*.tga, Media/Fonts/*.ttf, UI/SkinData.lua (table
nom -> fichier, taille de la toile, zone utile, coordonnées de texture, géométrie de la carte en
fractions de la largeur du corps). Aperçus PNG pour le rendu hors jeu : build/media_png/.

Usage (depuis la racine du dépôt) :
  python3 -m venv build/venv && build/venv/bin/pip install pillow fonttools
  build/venv/bin/python tools/build_media.py [--psd CHEMIN] [--icons DOSSIER] [--font FICHIER]
Rejouable : les rendus du PSD sont mis en cache dans build/media_cache (clé = commandes envoyées).
"""
import argparse, hashlib, json, math, os, pathlib, re, shutil, struct, subprocess, sys
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

ROOT = pathlib.Path(__file__).resolve().parent.parent
HOME = pathlib.Path.home()
ap = argparse.ArgumentParser()
ap.add_argument("--psd", default=str(HOME / "Téléchargements/1_Free Pack/PSD Card Constructor.psd"))
ap.add_argument("--icons", default=str(HOME / "Téléchargements/ICONS"))
ap.add_argument("--font", default=str(HOME / ".local/share/fonts/BalooChettan2.ttf"))
ARGS = ap.parse_args()

MEDIA = ROOT / "Media"
CACHE = ROOT / "build/media_cache"
PREVIEW = ROOT / "build/media_png"
LUA_ROOT = "Interface\\AddOns\\SlayTheDragon\\Media\\"
for d in (MEDIA, MEDIA / "Icons", MEDIA / "Fonts", CACHE, PREVIEW, PREVIEW / "Icons"):
    d.mkdir(parents=True, exist_ok=True)

SS = 4  # suréchantillonnage des formes dessinées

# ---------------------------------------------------------------------------
# TGA : 32 bits, non compressé, origine en bas à gauche, 8 bits d'alpha (descripteur 0x08)
# ---------------------------------------------------------------------------

def bleed(im):
    """Couleur des pixels transparents = moyenne des voisins visibles (pas de liseré sombre au filtrage
    bilinéaire du client) ; l'alpha ne change pas."""
    import numpy as np
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


def read_tga_header(path):
    with open(path, "rb") as f:
        return struct.unpack("<BBBHHBHHHHBB", f.read(18))

# ---------------------------------------------------------------------------
# PSD par photocraft-cli
# ---------------------------------------------------------------------------

PSD = ARGS.psd
INFO = json.loads(subprocess.run(["photocraft-cli", "info", "--compact", PSD], capture_output=True, text=True,
                                 check=True).stdout)
PSD_W, PSD_H = INFO["width"], INFO["height"]
PARENT, KIDS, VISIBLE, ALL, LAYER = {}, {}, {}, [], {}


def walk(node, parent):
    for c in node.get("layers") or node.get("children") or []:
        ALL.append(c["id"])
        LAYER[c["id"]] = c
        PARENT[c["id"]] = parent
        VISIBLE[c["id"]] = bool(c.get("visible"))
        KIDS.setdefault(parent, []).append(c["id"])
        walk(c, c["id"])


walk(INFO, None)

# Identifiants des calques (photocraft-cli info ; voir docs/maquette/gen_psd_cards.py)
L = dict(back=226, color=229, ribbon=246, cost=244, panel=242, plate=224, ring=235, icon=237, glass=239,
         stats=232, cardback=222, metal1=296, name=280)
METALS = (296, 294, 292, 290, 288)
GEMS = {"uncommon": 276, "rare": 274, "epic": 272, "legendary": 266}   # triangle vert, losange bleu, pentagone violet, carré orange


def render(name, show, extra=()):
    """Rend le PSD avec seulement `show` (et leurs ancêtres ; descendants à leur visibilité d'origine)."""
    keep = set()
    for i in show:
        j = i
        while j is not None:
            keep.add(j)
            j = PARENT[j]
        stack = list(KIDS.get(i, []))
        while stack:
            k = stack.pop()
            if VISIBLE[k]:
                keep.add(k)
            stack.extend(KIDS.get(k, []))
    cmds = []
    for i in ALL:
        cmds.append(("layer.setProps", {"layer": i, "visible": i in keep}))
    cmds.extend(extra)
    key = hashlib.sha1(json.dumps([PSD, cmds], sort_keys=True).encode()).hexdigest()[:16]
    out = CACHE / f"{name}-{key}.png"
    if not out.exists():
        args = ["photocraft-cli", "run", PSD]
        for cmd, p in cmds:
            args += ["--cmd", cmd, "--params", json.dumps(p, ensure_ascii=False)]
        r = subprocess.run(args + ["--out", str(out)], capture_output=True, text=True)
        errs = [l for l in (r.stdout + r.stderr).splitlines() if "error" in l.lower()]
        if r.returncode != 0 or errs:
            sys.exit(f"photocraft-cli : échec sur {name} : {errs[:3]}")
    im = Image.open(out).convert("RGBA")
    assert im.size == (PSD_W, PSD_H)
    return im


def piece(name, show, extra=(), metal=True):
    """Pièce rendue seule ; renvoie (image rognée, rectangle PSD x, y, w, h)."""
    im = render(name, list(show) + ([L["metal1"]] if metal else []), extra)
    bb = im.getbbox()
    return im.crop(bb), (bb[0], bb[1], bb[2] - bb[0], bb[3] - bb[1])

# ---------------------------------------------------------------------------
# Toiles, registre SkinData
# ---------------------------------------------------------------------------

TEX = {}       # nom -> entrée SkinData
GEOM = {}      # nom -> rectangle PSD


def pow2(n):
    p = 1
    while p < n:
        p *= 2
    return p


def emit(name, im, box=None, maxw=None, maxh=None, canvas=None, extra=None, subdir=""):
    """Met `im` à l'échelle (dans maxw × maxh), le pose en haut à gauche d'une toile en puissances de
    deux, écrit Media/<name>.tga et l'entrée SkinData."""
    w, h = im.size
    k = 1.0
    if maxw:
        k = min(k, maxw / w)
    if maxh:
        k = min(k, maxh / h)
    if k != 1.0:
        im = im.resize((max(1, round(w * k)), max(1, round(h * k))), Image.LANCZOS)
    cw, ch = im.size
    W, H = canvas if canvas else (pow2(cw), pow2(ch))
    assert cw <= W and ch <= H, f"{name} : zone utile {cw}×{ch} plus grande que la toile {W}×{H}"
    cv = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cv.alpha_composite(im, (0, 0))
    cv = bleed(cv)
    rel = (subdir + "\\" if subdir else "") + name + ".tga"
    write_tga(cv, MEDIA / subdir / (name + ".tga"))
    cv.save(PREVIEW / subdir / (name + ".png"))
    e = {"file": rel, "w": W, "h": H, "cw": cw, "ch": ch, "tc": [0, cw / W, 0, ch / H]}
    if extra:
        e.update(extra)
    TEX[name] = e
    if box:
        GEOM[name] = box
    return e

# ---------------------------------------------------------------------------
# Retouches (comme docs/maquette/gen_combat_pack.py)
# ---------------------------------------------------------------------------

def hue(im, h, sat=1.0, val=1.0):
    r, g, b, a = im.split()
    hh, ss, vv = Image.merge("RGB", (r, g, b)).convert("HSV").split()
    hh = hh.point(lambda _: int(h * 255))
    ss = ss.point(lambda v: min(255, int(v * sat)))
    vv = vv.point(lambda v: min(255, int(v * val)))
    out = Image.merge("HSV", (hh, ss, vv)).convert("RGB")
    out.putalpha(a)
    return out


def flatten(src, radius):
    """Retire les variations lentes (dégradés, taches) et garde le grain autour de la teinte moyenne :
    la tuile miroir ne montre plus de croix à la répétition."""
    import numpy as np
    rgb = src.convert("RGB")
    low = np.asarray(rgb.filter(ImageFilter.GaussianBlur(radius))).astype(np.float32)
    arr = np.asarray(rgb).astype(np.float32)
    mean = arr.reshape(-1, 3).mean(axis=0)
    out = np.clip(arr - low + mean, 0, 255).astype(np.uint8)
    return Image.fromarray(out, "RGB").convert("RGBA")


def mirror_tile(src, size):
    """Tuile raccordable sans symétrie visible : le carré de matière (aplati) fondu avec sa copie
    décalée d'une demi-tuile, dont les bords se raccordent (poids : 1 au centre, 0 aux bords)."""
    import numpy as np
    src = flatten(src, src.width / 6).convert("RGB")
    s = src.width
    a = np.asarray(src).astype(np.float32)
    b = np.roll(np.roll(a, s // 2, axis=0), s // 2, axis=1)
    idx = np.arange(s, dtype=np.float32)
    edge = np.minimum(idx, s - 1 - idx) / (s / 2)
    wgt = np.clip(np.minimum(edge[:, None], edge[None, :]) * 2.2, 0, 1)[..., None]
    out = a * wgt + b * (1 - wgt)
    t = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB").resize((size, size), Image.LANCZOS).convert("RGBA")
    t.putalpha(255)
    return t


def rounded_mask(w, h, r, inset=0):
    m = Image.new("L", (w * SS, h * SS), 0)
    ImageDraw.Draw(m).rounded_rectangle((inset * SS, inset * SS, (w - inset) * SS - 1, (h - inset) * SS - 1),
                                        max(0, (r - inset)) * SS, fill=255)
    return m.resize((w, h), Image.LANCZOS)


def ring_layer(w, h, r, a, b, color):
    """Anneau entre les retraits a et b (pixels) d'un rectangle arrondi de rayon r."""
    outer = rounded_mask(w, h, r, a)
    inner = rounded_mask(w, h, r, b)
    m = ImageChops.subtract(outer, inner)
    lay = Image.new("RGBA", (w, h), color + (255,) if len(color) == 3 else color)
    lay.putalpha(ImageChops.multiply(m, lay.split()[3]))
    return lay


def vgrad(w, h, top, bottom):
    g = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(g)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line((0, y, w, y), fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(len(top))))
    return g


def nine(name, w, h, r, layers, extra):
    """Texture à neuf tranches : coins de r pixels."""
    cv = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for lay in layers:
        cv.alpha_composite(lay)
    e = emit(name, cv, canvas=(w, h), extra=dict(corner=r, **extra))
    return e

# ===========================================================================
# 1. Carte : corps par couleur, panneau, ruban, languette de coût, plaque du bas, médaillon, gemmes
# ===========================================================================

BODY_COLORS = {"ivory": "#d9d2bd", "violet": "#7a52b8", "blue": "#4f86c8", "gold": "#e2b23a"}
body_box = None
for key, col in BODY_COLORS.items():
    im, box = piece("body_" + key, [L["back"], L["color"]], [("layer.fill.solidColor.set", {"layer": L["color"], "color": col})])
    body_box = body_box or box
    emit("card_body_" + key, im, box, maxh=512, canvas=(512, 512))
BX, BY, BW, BH = body_box

im, box = piece("ribbon", [L["ribbon"]])
emit("card_ribbon", im, box, maxw=512, canvas=(512, 256))
# Nom (ruban horizontal, redessiné dans le PSD) : centré à l'aplomb du corps, à la hauteur du calque de
# texte « Name » du PSD ; longueur utile = largeur, symétrique autour du centre, où la bande du ruban
# couvre toute la hauteur de ce calque (les replis et les queues sont exclus).
name_bounds = LAYER[L["name"]]["bounds"]       # x, y, w, h (pixels du PSD)
name_cx = BX + BW / 2
name_cy = name_bounds[1] + name_bounds[3] / 2
a = im.split()[3]
y0, y1 = round(name_cy - name_bounds[3] / 2 - box[1]), round(name_cy + name_bounds[3] / 2 - box[1])


def band_covers(x):
    return all(a.getpixel((x, y)) > 200 for y in range(y0, y1 + 1))


cx0 = round(name_cx - box[0])
half = 0
while cx0 - half - 1 >= 0 and cx0 + half + 1 < im.width and band_covers(cx0 - half - 1) and band_covers(cx0 + half + 1):
    half += 1
name_len = 2 * half

im, box = piece("cost", [L["cost"]])
emit("card_cost", im, box, maxw=256, canvas=(256, 128))
im, box = piece("panel", [L["panel"]])
emit("card_panel", im, box, maxw=256, canvas=(256, 256))
panel_img, panel_box = im, box
im, box = piece("plate", [L["plate"]])
emit("card_plate", im, box, maxw=256, canvas=(256, 128))

im, ring_box = piece("ring", [L["ring"]])
emit("medal_ring", im, ring_box, maxw=256, maxh=256, canvas=(256, 256))
im, box = piece("glass", [L["glass"]])
im.putalpha(im.split()[3].point(lambda v: int(v * 0.66)))      # opacité du calque « front circle »
emit("medal_glass", im, box, maxw=256, maxh=256, canvas=(256, 256))
white = CACHE / "_white688.png"
Image.new("RGBA", (688, 688), (255, 255, 255, 255)).save(white)
im, ap_box = piece("aperture", [L["icon"]], [("layer.smartObjects.replaceContents", {"layer": L["icon"], "path": str(white)})],
                   metal=False)
m = Image.new("RGBA", im.size, (255, 255, 255, 0))
m.putalpha(im.split()[3])
# Masque étiré à toute la toile (un masque se pose sans coordonnées de texture), recadré en jeu sur l'ouverture.
emit("medal_mask", m.resize((128, 128), Image.LANCZOS), ap_box, canvas=(128, 128))

for rk, lid in GEMS.items():
    im, box = piece("gem_" + rk, [lid], metal=False)
    emit("gem_" + rk, im, box, maxw=64, maxh=64, canvas=(64, 64))

# Halo de carte : silhouette du corps floutée (dorée en jeu par la couleur de sommet).
body_ivory = Image.open(PREVIEW / "card_body_ivory.png").crop((0, 0, TEX["card_body_ivory"]["cw"], TEX["card_body_ivory"]["ch"]))
k = 0.25
sil = body_ivory.split()[3].resize((round(body_ivory.width * k), round(body_ivory.height * k)), Image.LANCZOS)
pad = 20
g = Image.new("L", (sil.width + 2 * pad, sil.height + 2 * pad), 0)
g.paste(sil, (pad, pad))
g = g.filter(ImageFilter.GaussianBlur(6))
g = g.point(lambda v: min(255, v * 2))
glow = Image.new("RGBA", g.size, (255, 255, 255, 0))
glow.putalpha(g)
scale_px = BH / sil.height                   # pixels PSD par pixel de la silhouette
emit("card_glow", glow, (round(BX - pad * scale_px), round(BY - pad * scale_px), round(g.width * scale_px), round(g.height * scale_px)),
     maxh=256, canvas=(256, 256))

# ===========================================================================
# 2. Dos de carte, ardoise (matière des plaques sous les cartes)
# ===========================================================================

# dos : cadre doré, cristal pentagonal violet (calque « crystal 3 »), sans l'emblème au marteau
im, box = piece("cardback", [L["cardback"]], [("layer.setProps", {"layer": 215, "visible": False}),
                                             ("layer.setProps", {"layer": 197, "visible": True})], metal=False)
emit("card_back", im, None, maxh=256, canvas=(256, 256))

# Ardoise : intérieur du panneau de texte (comme la maquette), tuile miroir raccordable.
pw, ph = panel_img.size
sq = int(min(pw, ph) * 0.42)
src = panel_img.crop((int(pw * 0.12), int(ph * 0.24), int(pw * 0.12) + sq, int(ph * 0.24) + sq))
SLATE = mirror_tile(src, 256)
# Éclaircie de 1/0,8 : en jeu, la couleur de sommet 0,8 donne l'ardoise de la maquette et laisse de la
# marge pour les plaques survolées ou chaudes (une couleur de sommet ne dépasse pas 1).
SLATE = SLATE.point(lambda v: min(255, int(v * 1.25)))
SLATE.putalpha(255)
emit("tile_slate", SLATE, None, canvas=(256, 256), extra=dict(tile=True))
# ===========================================================================
# 3. Plaques sous les cartes (raison d'un refus, prix) : pilule d'ardoise et liseré d'argent
# ===========================================================================
# Coins de R pixels ; en jeu, un coin mesure le rayon voulu (unités d'écran), les bords s'étirent.
SILVER_TOP, SILVER_BOTTOM = (236, 240, 247), (176, 184, 198)
DARK = (18, 22, 30)


def fill_texture(name, mat, size, R, extra):
    tile = mat.resize((size, size), Image.LANCZOS)
    lay = tile.copy()
    lay.putalpha(rounded_mask(size, size, R))
    return nine(name, size, size, R, [lay], extra)


def rim_texture(name, size, R, dark, silver, inner, extra):
    outer = ring_layer(size, size, R, 0, dark, DARK)
    sil = vgrad(size, size, SILVER_TOP + (255,), SILVER_BOTTOM + (255,))
    sil.putalpha(ImageChops.subtract(rounded_mask(size, size, R, dark), rounded_mask(size, size, R, dark + silver)))
    inn = ring_layer(size, size, R, dark + silver, dark + silver + inner, DARK + (200,))
    return nine(name, size, size, R, [outer, sil, inn], dict(rim=dark + silver + inner, rimIn=dark + silver, **extra))


fill_texture("pill_slate", SLATE, 128, 48, {})
rim_texture("pill_rim", 128, 48, 2, 5, 2, {})
# lueur douce (halo des plaques survolées) : rectangle arrondi flouté, coins larges
gl = Image.new("L", (128, 128), 0)
ImageDraw.Draw(gl).rounded_rectangle((24, 24, 103, 103), 16, fill=255)
gl = gl.filter(ImageFilter.GaussianBlur(9))
glow = Image.new("RGBA", (128, 128), (255, 255, 255, 0))
glow.putalpha(gl)
nine("nine_glow", 128, 128, 48, [glow], dict(spread=24))
gd = Image.new("L", (128, 128), 0)
ImageDraw.Draw(gd).ellipse((22, 22, 105, 105), fill=255)
gd = gd.filter(ImageFilter.GaussianBlur(10))
glow = Image.new("RGBA", (128, 128), (255, 255, 255, 0))
glow.putalpha(gd)
emit("glow_round", glow, None, canvas=(128, 128), extra=dict(inner=(105 - 22) / 128))
md = Image.new("RGBA", (128, 128), (255, 255, 255, 0))
dm = Image.new("L", (128 * SS, 128 * SS), 0)
ImageDraw.Draw(dm).ellipse((0, 0, 128 * SS - 1, 128 * SS - 1), fill=255)
md.putalpha(dm.resize((128, 128), Image.LANCZOS))
emit("mask_disc", md, None, canvas=(128, 128))

# ===========================================================================
# 4. Police : instances statiques réduites au latin
# ===========================================================================
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools import subset as ftsubset

FONTS = {}
for label, wght in (("medium", 500), ("bold", 700), ("heavy", 800)):
    f = TTFont(ARGS.font)
    inst = instancer.instantiateVariableFont(f, {"wght": wght})
    opts = ftsubset.Options()
    opts.layout_features = ["kern", "liga", "calt"]
    opts.name_IDs = ["*"]
    sub = ftsubset.Subsetter(opts)
    sub.populate(unicodes=list(range(0x20, 0x7F)) + list(range(0xA0, 0x180)) + [0x2013, 0x2014, 0x2018, 0x2019, 0x201C,
                 0x201D, 0x2022, 0x2026, 0x2212, 0x00D7, 0x00B7, 0x202F, 0x2009, 0x20AC])
    sub.subset(inst)
    out = MEDIA / "Fonts" / f"BalooChettan2-{label}.ttf"
    inst.recalcTimestamp = False         # fichier identique d'une fabrication à l'autre
    inst.save(out)
    cmap = TTFont(out).getBestCmap()
    missing = [c for c in "àâäéèêëîïôöùûüçœæÀÂÉÈÊËÎÏÔÙÛÜÇŒ’«»—–…·×−" if ord(c) not in cmap]
    if missing:
        sys.exit(f"police {label} : glyphes manquants {missing}")
    FONTS[label] = "Fonts\\" + out.name

# Métriques pour le faux client du harnais (Sim/baloo_metrics.lua) : avance de chaque glyphe en
# millièmes de cadratin (sans crénage), hauteur de ligne = (ascendante + descendante) / cadratin.
metrics = ["-- Fichier GÉNÉRÉ par tools/build_media.py : métriques de Baloo Chettan 2 (Media/Fonts) pour le",
           "-- faux client de Sim/ui_harness.lua. adv[graisse][caractère UTF-8] = avance en millièmes de",
           "-- cadratin (sans crénage) ; lineHeight = hauteur d'une ligne en cadratins (hhea).",
           "return {"]
for label in ("medium", "bold", "heavy"):
    ft = TTFont(MEDIA / "Fonts" / f"BalooChettan2-{label}.ttf")
    upm, hm, hh = ft["head"].unitsPerEm, ft["hmtx"], ft["hhea"]
    if label == "bold":
        metrics.append(f"  lineHeight = {round((hh.ascent - hh.descent) / upm, 4)},")
    items = []
    for cp, g in sorted(ft.getBestCmap().items()):
        ch = chr(cp)
        key = ch.replace("\\", "\\\\").replace('"', '\\"')
        items.append(f'["{key}"]={round(hm[g][0] * 1000 / upm)}')
    metrics.append(f"  {label} = {{")
    for i in range(0, len(items), 12):
        metrics.append("    " + ", ".join(items[i:i + 12]) + ",")
    metrics.append("  },")
metrics.append("}")
(ROOT / "Sim/baloo_metrics.lua").write_text("\n".join(metrics) + "\n", encoding="utf-8")

# ===========================================================================
# 5. Icônes : celles que nomme UI/Art.lua (champ tga = "Nom")
# ===========================================================================

art = (ROOT / "UI/Art.lua").read_text(encoding="utf-8")
wanted = sorted(set(re.findall(r'tga\s*=\s*"([^"]+)"', art)), key=str.lower)
index = {p.name[:-4].lower(): p for p in pathlib.Path(ARGS.icons).glob("*.tga")}
ICONS, MISSING = {}, []


def icon_key(n):
    return n.lower()


for n in wanted:
    p = index.get(n.lower())
    if not p:
        MISSING.append(n)
        continue
    hdr = read_tga_header(p)
    fname = re.sub(r"[^a-z0-9_]", "_", n.lower())
    dst = MEDIA / "Icons" / (fname + ".tga")
    im = Image.open(p).convert("RGBA")
    if hdr[2] == 2 and hdr[10] == 32 and hdr[11] == 8 and im.size[0] & (im.size[0] - 1) == 0:
        shutil.copyfile(p, dst)                      # déjà au bon format : copie telle quelle
    else:
        write_tga(im.resize((128, 128), Image.LANCZOS), dst)
    im.save(PREVIEW / "Icons" / (fname + ".png"))
    ICONS[icon_key(n)] = "Icons\\" + fname + ".tga"

# ===========================================================================
# 6. Géométrie de la carte (fractions de la largeur du corps, origine = coin haut gauche du corps)
# ===========================================================================

def rel(box):
    x, y, w, h = box
    return [round((x - BX) / BW, 5), round((y - BY) / BW, 5), round(w / BW, 5), round(h / BW, 5)]


# Zone du texte : intérieur sombre du panneau (lignes / colonnes centrales assez sombres et opaques).
pim = panel_img
def dark(px):
    return px[3] > 250 and sum(px[:3]) < 3 * 120
cx0 = pim.width // 2
col = [dark(pim.getpixel((cx0, y))) for y in range(pim.height)]
ys = [y for y, v in enumerate(col) if v]
mid_y = (ys[0] + ys[-1]) // 2
row = [dark(pim.getpixel((x, mid_y))) for x in range(pim.width)]
xs = [x for x, v in enumerate(row) if v]
text_box = (panel_box[0] + xs[0], panel_box[1] + ys[0], xs[-1] - xs[0], ys[-1] - ys[0])

CARD = {
    "aspect": round(BH / BW, 5),
    "body": rel(body_box),
    "pieces": {k: rel(GEOM[k]) for k in ("card_ribbon", "card_cost", "card_panel", "card_plate",
                                         "medal_ring", "medal_glass", "medal_mask", "card_glow")},
    "gems": {k: rel(GEOM["gem_" + k]) for k in GEMS},
    "name": {"cx": round((name_cx - BX) / BW, 5), "cy": round((name_cy - BY) / BW, 5), "len": round(name_len / BW, 5)},
    "cost": {"cx": round((GEOM["card_cost"][0] + GEOM["card_cost"][2] / 2 - BX) / BW, 5),
             "cy": round((GEOM["card_cost"][1] + GEOM["card_cost"][3] * 0.47 - BY) / BW, 5)},
    "text": rel(text_box),
    "plateText": {"cx": round((GEOM["card_plate"][0] + GEOM["card_plate"][2] / 2 - BX) / BW, 5),
                  "cy": round((GEOM["card_plate"][1] + GEOM["card_plate"][3] * 0.5 - BY) / BW, 5),
                  "w": round(GEOM["card_plate"][2] * 0.78 / BW, 5)},
}

# ===========================================================================
# 7. UI/SkinData.lua
# ===========================================================================

def lua(v, ind=""):
    if isinstance(v, dict):
        keys = sorted(v)
        inner = ind + "  "
        parts = []
        for k in keys:
            kk = k if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", k) else '["%s"]' % k
            parts.append(f"{inner}{kk} = {lua(v[k], inner)},")
        return "{\n" + "\n".join(parts) + "\n" + ind + "}"
    if isinstance(v, (list, tuple)):
        return "{ " + ", ".join(lua(x, ind) for x in v) + " }"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        if isinstance(v, float):
            return ("%.5f" % v).rstrip("0").rstrip(".") if v != int(v) else str(int(v))
        return str(v)
    return '"' + str(v).replace("\\", "\\\\").replace('"', '\\"') + '"'


skin = {"root": LUA_ROOT, "tex": TEX, "card": CARD, "icons": ICONS, "fonts": FONTS,
        "slateTile": 128, "slateBase": 0.8}
head = ("-- Fichier GÉNÉRÉ par tools/build_media.py : ne pas modifier à la main (relancer le script).\n"
        "-- Textures de Media/ (TGA 32 bits non compressé, toiles en puissances de deux, contenu calé en haut à\n"
        "-- gauche) : file, w × h (toile), cw × ch (zone utile, pixels), tc = coordonnées de texture de la zone\n"
        "-- utile ; corner = coin des textures à neuf tranches (pixels), rim = épaisseur du liseré (pixels).\n"
        "-- card : géométrie de la carte en fractions de la largeur du corps, origine au coin haut gauche du\n"
        "-- corps (x, y, w, h) ; name : centre (cx, cy) et longueur utile du nom sur le ruban. Pièces : pack\n"
        "-- Mechanized Magic (Dumivid, CC0) ; police : Baloo Chettan 2 (OFL) ; icônes : pack d'icônes améliorées\n"
        "-- 128 px.\n"
        "local _, ns = ...\n\n")
(ROOT / "UI/SkinData.lua").write_text(head + "ns.Skin = " + lua(skin) + "\n", encoding="utf-8")

for old in ("hex_red", "hex_green", "hex_blue", "hex_blue_l", "hex_steel", "hex_violet", "hex_empty", "tile_ivory",
            "nine_slate", "nine_ivory", "nine_rim", "button_gold", "tail_slate", "tail_ivory", "tail_rim",
            "medal_ring_s", "mask_roundsq"):
    for f in (MEDIA / (old + ".tga"), PREVIEW / (old + ".png")):
        if f.exists():
            f.unlink()
total = sum(p.stat().st_size for p in MEDIA.rglob("*") if p.is_file())
print(f"{len(TEX)} textures, {len(ICONS)} icônes, {len(FONTS)} polices ; Media/ = {total / 1048576:.2f} Mo")
if MISSING:
    print("icônes introuvables (repli sur l'icône du jeu) :", ", ".join(MISSING))
