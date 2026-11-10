#!/usr/bin/env python3
"""Déclinaisons de cartes composées avec les vraies textures d'interface du client.
Usage : variants.py <dossier des textures .png> <dossier des icônes .jpg> <sortie.png>"""
import sys, pathlib
from PIL import Image, ImageDraw, ImageFont, ImageChops, ImageFilter

T = pathlib.Path(sys.argv[1]); IC = pathlib.Path(sys.argv[2]); OUT = sys.argv[3]
S = 2  # facteur de rendu
FONT = str(T / "f615960.ttf")  # Friz Quadrata, la police du jeu
QUALITY = {"common": (255, 255, 255), "uncommon": (30, 255, 0), "rare": (0, 112, 221), "epic": (163, 53, 238)}
GOLD = (255, 209, 0)


def tex(i): return Image.open(T / f"{i}.png").convert("RGBA")
def font(px): return ImageFont.truetype(FONT, int(px * S))


def tint(im, rgb):
    r, g, b, a = im.split()
    m = Image.merge("RGB", (r, g, b))
    m = ImageChops.multiply(m, Image.new("RGB", im.size, rgb))
    return Image.merge("RGBA", (*m.split(), a))


def tile(im, w, h):
    out = Image.new("RGBA", (w, h))
    for y in range(0, h, im.height):
        for x in range(0, w, im.width):
            out.paste(im, (x, y))
    return out


def fit(im, w, h): return im.resize((w, h), Image.LANCZOS)


def rounded_mask(w, h, r):
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w - 1, h - 1), r, fill=255)
    return m


def backdrop(w, h, edge, size, color=None):
    """Bordure façon SetBackdrop : fichier à 8 cases (G, D, H, B, coins)."""
    e = tex(edge)
    if color: e = tint(e, color)
    cw = e.width // 8
    cell = lambda i: e.crop((i * cw, 0, (i + 1) * cw, e.height)).resize((size, size), Image.LANCZOS)
    out = Image.new("RGBA", (w, h))
    L, R = cell(0), cell(1)
    Tp, B = cell(2).rotate(-90), cell(3).rotate(-90)
    for y in range(size, h - size, size):
        out.paste(L, (0, y)); out.paste(R, (w - size, y))
    for x in range(size, w - size, size):
        out.paste(Tp, (x, 0)); out.paste(B, (x, h - size))
    # recouvre les fins de bande
    out.paste(L, (0, h - 2 * size)); out.paste(R, (w - size, h - 2 * size))
    out.paste(Tp, (w - 2 * size, 0)); out.paste(B, (w - 2 * size, h - size))
    out.paste(cell(4), (0, 0)); out.paste(cell(5), (w - size, 0))
    out.paste(cell(6), (0, h - size)); out.paste(cell(7), (w - size, h - size))
    return out


def solid_crop(i, thr=150):
    im = tex(i)
    return im.crop(im.split()[3].point(lambda a: 255 if a > thr else 0).getbbox())


def text(d, xy, s, f, fill, anchor="la", shadow=True, outline=0):
    x, y = xy
    if shadow:
        d.text((x + S, y + S), s, font=f, fill=(0, 0, 0, 230), anchor=anchor)
    d.text((x, y), s, font=f, fill=fill, anchor=anchor, stroke_width=outline, stroke_fill=(0, 0, 0, 255))


def rich_lines(im, cx, cy, lines, px, base, bold, shadow=True, lead=1.32):
    """Texte centré ; **gras** = couleur d'accent (comme les valeurs d'une infobulle)."""
    d = ImageDraw.Draw(im); f = font(px)
    y = cy - (len(lines) - 1) * px * lead * S / 2
    for ln in lines:
        parts = ln.split("**")
        w = sum(d.textlength(p, font=f) for p in parts)
        x = cx - w / 2
        for k, p in enumerate(parts):
            text(d, (x, y), p, f, bold if k % 2 else base, anchor="lm", shadow=shadow)
            x += d.textlength(p, font=f)
        y += px * lead * S


def icon(name, px):
    return Image.open(IC / f"{name}.jpg").convert("RGBA").resize((px * S, px * S), Image.LANCZOS)


def cost_orb(n, kind="mana"):
    """Gemme de coût : disque bleu cerclé par la bordure d'emplacement du jeu."""
    r = 15 * S
    im = Image.new("RGBA", (2 * r, 2 * r))
    d = ImageDraw.Draw(im)
    d.ellipse((1, 1, 2 * r - 2, 2 * r - 2), fill=(8, 12, 30, 255))
    for i in range(r - 3 * S, 0, -1):
        t = i / (r - 3 * S)
        d.ellipse((r - i - 3 * S * t * .4, r - i - 3 * S * t * .4, r + i - 3 * S * t * .4, r + i - 3 * S * t * .4),
                  fill=(int(40 + 110 * (1 - t)), int(90 + 120 * (1 - t)), int(200 + 55 * (1 - t)), 255))
    ring = Image.new("RGBA", im.size); rd = ImageDraw.Draw(ring)
    rd.ellipse((1, 1, 2 * r - 2, 2 * r - 2), outline=(0, 0, 0, 255), width=S)
    rd.ellipse((S, S, 2 * r - 1 - S, 2 * r - 1 - S), outline=(214, 178, 96, 255), width=int(1.6 * S))
    rd.ellipse((int(2.6 * S), int(2.6 * S), 2 * r - 1 - int(2.6 * S), 2 * r - 1 - int(2.6 * S)), outline=(70, 50, 20, 255), width=S)
    im.alpha_composite(ring)
    text(d, (r, r - S), str(n), font(18), (255, 255, 255), anchor="mm", outline=S)
    return im


def shadowed(card):
    pad = 14 * S
    base = Image.new("RGBA", (card.width + 2 * pad, card.height + 2 * pad))
    sh = Image.new("RGBA", base.size)
    sh.paste((0, 0, 0, 190), (pad, pad + 4 * S), card.split()[3])
    base.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5 * S)))
    base.alpha_composite(card, (pad, pad))
    return base


W, H = 124 * S, 176 * S
CARD = dict(title="Pénitence", cost=2, rarity="uncommon", icon="spell_holy_penance",
            lines=["Inflige **6** trois fois.", "Sous **Expiation** :", "**2** Absorption par coup."])


def place_common(card, c, name_y, name_fill, name_px=12.5, orb=True, icon_frame="slot", icon_xy=(80, 8), outline=0):
    d = ImageDraw.Draw(card)
    ix, iy = icon_xy[0] * S, icon_xy[1] * S
    ic = icon(c["icon"], 36)
    if icon_frame == "ach":
        fr = fit(solid_crop(130656, 60), 48 * S, 48 * S)
        card.alpha_composite(ic, (ix, iy)); card.alpha_composite(fr, (ix - 6 * S, iy - 6 * S))
    else:
        card.alpha_composite(ic, (ix, iy))
        b = ImageDraw.Draw(card)
        b.rectangle((ix - S, iy - S, ix + 36 * S, iy + 36 * S), outline=(0, 0, 0, 255), width=S)
        b.rectangle((ix - 2 * S, iy - 2 * S, ix + 37 * S, iy + 37 * S), outline=(150, 120, 60, 255), width=S)
    text(d, (W // 2, name_y * S), c["title"], font(name_px), name_fill, anchor="mm", outline=outline)
    if orb:
        card.alpha_composite(cost_orb(c["cost"]), (2 * S, 2 * S))


def v_tooltip(c):
    """A — Infobulle : fond sombre et liseré d'infobulle teinté à la couleur de qualité."""
    card = Image.new("RGBA", (W, H))
    bg = Image.new("RGBA", (W - 6 * S, H - 6 * S), (9, 10, 24, 242))
    card.paste(bg, (3 * S, 3 * S), rounded_mask(bg.width, bg.height, 5 * S))
    card.alpha_composite(backdrop(W, H, 137057, 14 * S, QUALITY[c["rarity"]]))
    d = ImageDraw.Draw(card)
    d.line((12 * S, 66 * S, W - 12 * S, 66 * S), fill=(110, 110, 130, 160), width=S)
    place_common(card, c, 56, QUALITY[c["rarity"]], name_px=13)
    rich_lines(card, W // 2, 116 * S, c["lines"], 9.6, (255, 255, 255), GOLD)
    return card


def v_achievement(c):
    """B — Haut fait : parchemin, cadre de bois, bandeau rouge, cadre d'icône doré, écu pour le coût."""
    card = Image.new("RGBA", (W, H))
    par = fit(tex(130662), W - 8 * S, H - 8 * S)
    card.paste(par, (4 * S, 4 * S), rounded_mask(par.width, par.height, 4 * S))
    strip = tex(130667).crop((0, 1, 420, 20)).resize((W - 12 * S, 19 * S), Image.LANCZOS)
    card.alpha_composite(strip, (6 * S, 47 * S))
    card.alpha_composite(backdrop(W, H, 130672, 20 * S))
    place_common(card, c, 56, (255, 255, 255), orb=False, icon_frame="ach", icon_xy=(78, 9))
    sh = fit(solid_crop(130665, 120), 34 * S, 40 * S)
    card.alpha_composite(sh, (5 * S, 4 * S))
    text(ImageDraw.Draw(card), (22 * S, 22 * S), str(c["cost"]), font(17), (255, 255, 255), anchor="mm", outline=S)
    d = ImageDraw.Draw(card)
    gem = QUALITY[c["rarity"]]
    d.polygon([(W // 2, 68 * S), (W // 2 + 6 * S, 74 * S), (W // 2, 80 * S), (W // 2 - 6 * S, 74 * S)], fill=gem, outline=(40, 25, 5))
    rich_lines(card, W // 2, 122 * S, c["lines"], 9.6, (58, 36, 14), (120, 20, 10), shadow=False)
    return card


def v_plaque(c, body, edge, header, base, bold, name_fill, crop_thr=150):
    card = Image.new("RGBA", (W, H))
    b = tile(tex(body), W, H) if tex(body).width < 200 else fit(tex(body), W - 10 * S, H - 10 * S)
    if b.size == (W, H):
        b = b.crop((5 * S, 5 * S, W - 5 * S, H - 5 * S))
    card.paste(b, (5 * S, 5 * S), rounded_mask(b.width, b.height, 6 * S))
    card.alpha_composite(backdrop(W, H, edge, 16 * S))
    pl = fit(solid_crop(header, crop_thr), W - 6 * S, 28 * S)
    card.alpha_composite(pl, (3 * S, 46 * S))
    place_common(card, c, 60, name_fill, name_px=12)
    d = ImageDraw.Draw(card)
    gem = QUALITY[c["rarity"]]
    d.polygon([(W // 2, 76 * S), (W // 2 + 6 * S, 82 * S), (W // 2, 88 * S), (W // 2 - 6 * S, 82 * S)], fill=gem, outline=(20, 14, 6))
    rich_lines(card, W // 2, 126 * S, c["lines"], 9.6, base, bold, shadow=base[0] > 128)
    return card


variants = [
    ("A — Infobulle", "Fond et liseré des infobulles d'objet.\nLe nom et le liseré prennent la couleur de qualité.", v_tooltip(CARD)),
    ("B — Haut fait", "Parchemin, cadre de bois, bandeau rouge,\ncadre d'icône et écu des hauts faits.", v_achievement(CARD)),
    ("C — Pierre et or", "Pierre des stèles, bordure dorée et cartouche\ndes fenêtres de dialogue.", v_plaque(CARD, 136279, 131076, 131079, (236, 226, 200), GOLD, (255, 232, 160))),
    ("D — Marbre", "Marbre des livres, bordure et cartouche\nargentés des fenêtres de dialogue.", v_plaque(CARD, 136271, 131072, 131080, (40, 36, 30), (110, 20, 14), QUALITY[CARD["rarity"]])),
]

BW, BH = 1040 * S, 620 * S
board = tile(tex(312922), BW, BH)
board = Image.alpha_composite(board, Image.new("RGBA", board.size, (20, 14, 10, 110)))
d = ImageDraw.Draw(board)
text(d, (28 * S, 24 * S), "Cartes — quatre déclinaisons avec les éléments d'interface du jeu", font(17), GOLD, anchor="lm")
colw = BW // 4
for i, (name, desc, card) in enumerate(variants):
    cx = i * colw + colw // 2
    big = shadowed(card.resize((int(W * 1.75), int(H * 1.75)), Image.LANCZOS))
    board.alpha_composite(big, (cx - big.width // 2, 44 * S))
    small = shadowed(card.resize((W // S, H // S), Image.LANCZOS) if S != 2 else card.resize((W // 2, H // 2), Image.LANCZOS))
    # taille réelle en jeu (1×) et taille de la main survolée
    real = shadowed(card.resize((int(W / S * 1.0) * S // S, int(H / S) * S // S), Image.LANCZOS)) if False else None
    one = card.resize((124 * S, 176 * S), Image.LANCZOS)
    text(d, (cx, 372 * S), name, font(15), (255, 255, 255), anchor="mm")
    for k, ln in enumerate(desc.split("\n")):
        text(d, (cx, (392 + k * 15) * S), ln, font(10.5), (200, 190, 170), anchor="mm")
    sm = shadowed(card.resize((int(W * 0.5), int(H * 0.5)), Image.LANCZOS).resize((W, H), Image.LANCZOS)) if False else shadowed(card)
    board.alpha_composite(sm, (cx - sm.width // 2, 420 * S))
board.save(OUT)
for i, (_, _, card) in enumerate(variants):
    card.save(str(pathlib.Path(OUT).with_name(f"variant{i}.png")))
print(board.size)
