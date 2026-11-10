#!/usr/bin/env python3
"""Déclinaisons de cartes avec le pack « Mechanized Magic » de Dumivid (CC0).
Usage : pack_cards.py <dossier du pack> <icônes .jpg> <police.ttf> <sortie.jpg>"""
import sys, pathlib
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

P = pathlib.Path(sys.argv[1]) / "Card Sprites"; IC = pathlib.Path(sys.argv[2]); FONT = sys.argv[3]; OUT = sys.argv[4]
CW, CH = 1062, 1471          # toile d'une carte, à la taille d'origine du pack
BODY = {"clair": "Minion/Alternate (2).png", "violet": "Minion/Alternate (3).png", "or": "Minion/minion (1).png", "vert": "Minion/Alternate (1).png"}
RARITY = {"common": "_Rarity/rarity (6).png", "uncommon": "_Rarity/rarity (1).png", "rare": "_Rarity/rarity (7).png", "epic": "_Rarity/rarity (5).png"}


def sp(name): return Image.open(P / name).convert("RGBA")


def font(px, w=700):
    f = ImageFont.truetype(FONT, px)
    try: f.set_variation_by_axes([w])
    except Exception: pass
    return f


def scaled(im, k): return im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
def put(c, im, cx, cy): c.alpha_composite(im, (round(cx - im.width / 2), round(cy - im.height / 2)))


def txt(c, cx, cy, s, px, fill=(255, 255, 255), w=700, stroke=0, sfill=(20, 26, 40)):
    ImageDraw.Draw(c).text((cx, cy), s, font=font(px, w), fill=fill, anchor="mm", stroke_width=stroke, stroke_fill=sfill)


def rich(c, cx, cy, lines, px, base=(232, 238, 246), bold=(255, 255, 255), lead=1.28):
    d = ImageDraw.Draw(c); fr, fb = font(px, 500), font(px, 800)
    y = cy - (len(lines) - 1) * px * lead / 2
    for ln in lines:
        parts = ln.split("**")
        ws = [d.textlength(p, font=fb if k % 2 else fr) for k, p in enumerate(parts)]
        x = cx - sum(ws) / 2
        for k, p in enumerate(parts):
            d.text((x, y), p, font=fb if k % 2 else fr, fill=bold if k % 2 else base, anchor="lm")
            x += ws[k]
        y += px * lead


def icon_disc(name, d):
    im = Image.open(IC / f"{name}.jpg").convert("RGBA").resize((d, d), Image.LANCZOS)
    m = Image.new("L", (d, d), 0); ImageDraw.Draw(m).ellipse((0, 0, d - 1, d - 1), fill=255)
    im.putalpha(m); return im


def icon_square(name, d, r):
    im = Image.open(IC / f"{name}.jpg").convert("RGBA").resize((d, d), Image.LANCZOS)
    m = Image.new("L", (d, d), 0); ImageDraw.Draw(m).rounded_rectangle((0, 0, d - 1, d - 1), r, fill=255)
    im.putalpha(m); return im


def card(c, layout, body="clair"):
    """layout : 'medaillon' (icône au centre) | 'coin' (icône en haut à droite) | 'bandeau' (icône dans le ruban)."""
    cv = Image.new("RGBA", (CW, CH))
    cx = CW // 2
    put(cv, sp(BODY[body]), cx, 760)
    # languette du coût
    put(cv, sp("Minion/minion (7).png"), cx, 118)
    txt(cv, cx, 88, str(c["cost"]), 120, w=800, stroke=5, sfill=(8, 50, 130))
    if layout == "medaillon":
        ring = scaled(sp("Minion/minion (4).png"), 0.56)
        put(cv, ring, cx, 470)
        put(cv, icon_disc(c["icon"], 322), cx - 2, 462)
        panel = sp("Minion/minion (2).png").resize((780, 600), Image.LANCZOS); py = 960
        put(cv, panel, cx, py)
        put(cv, scaled(sp("Minion/minion (6).png"), 0.93), cx, 236)
        txt(cv, cx, 226, c["title"], 70, w=700)
        put(cv, scaled(sp(RARITY[c["rarity"]]), 0.62), cx, 690)
        rich(cv, cx, py + 20, c["lines"], 45 if len(c["lines"]) > 2 else 60)
    elif layout == "coin":
        panel = sp("Minion/minion (2).png").resize((760, 760), Image.LANCZOS); py = 880
        put(cv, panel, cx, py)
        put(cv, scaled(sp("Minion/minion (6).png"), 0.93), cx, 236)
        txt(cv, cx, 226, c["title"], 70, w=700)
        ring = scaled(sp("Minion/minion (4).png"), 0.36)
        put(cv, ring, 800, 400)
        put(cv, icon_disc(c["icon"], 206), 799, 395)
        put(cv, scaled(sp(RARITY[c["rarity"]]), 0.62), cx, 505)
        rich(cv, cx, py + 30, c["lines"], 45 if len(c["lines"]) > 2 else 62)
    else:  # bandeau : pas de médaillon, l'icône carrée posée sur le panneau
        panel = sp("Minion/minion (2).png").resize((760, 800), Image.LANCZOS); py = 860
        put(cv, panel, cx, py)
        put(cv, scaled(sp("Minion/minion (6).png"), 0.93), cx, 236)
        txt(cv, cx, 226, c["title"], 70, w=700)
        d = 250
        fr = Image.new("RGBA", (d + 28, d + 28)); fd = ImageDraw.Draw(fr)
        fd.rounded_rectangle((0, 0, d + 27, d + 27), 40, fill=(235, 240, 248, 255))
        fd.rounded_rectangle((7, 7, d + 20, d + 20), 34, fill=(40, 52, 72, 255))
        put(cv, fr, cx, 600); put(cv, icon_square(c["icon"], d, 28), cx, 600)
        put(cv, scaled(sp(RARITY[c["rarity"]]), 0.55), cx, 745)
        rich(cv, cx, 960, c["lines"], 45 if len(c["lines"]) > 2 else 62)
    if c.get("tag"):
        put(cv, scaled(sp("Minion/minion (3).png"), 0.72), cx, 1330)
        txt(cv, cx, 1322, c["tag"], 56, w=600)
    return cv


def shadowed(im, blur, dy):
    pad = blur * 3
    b = Image.new("RGBA", (im.width + 2 * pad, im.height + 2 * pad)); s = Image.new("RGBA", b.size)
    s.paste((0, 0, 0, 170), (pad, pad + dy), im.split()[3])
    b.alpha_composite(s.filter(ImageFilter.GaussianBlur(blur))); b.alpha_composite(im, (pad, pad)); return b


PEN = dict(title="Pénitence", cost=2, rarity="uncommon", icon="spell_holy_penance",
           lines=["Inflige **6** trois fois.", "Sous **Expiation** :", "**2** Absorption par coup."])
BLAST = dict(title="Attaque mentale", cost=1, rarity="common", icon="spell_shadow_unholyfrenzy",
             lines=["Inflige **9**.", "**+2 Démence**."], tag="Recharge 1")
SMITE = dict(title="Châtiment", cost=1, rarity="common", icon="spell_holy_holysmite", lines=["Inflige **6**."])
SPIRIT = dict(title="Esprit de rédemption", cost=3, rarity="rare", icon="spell_holy_greaterheal",
              lines=["Une fois par combat,", "survit à **1 PV**."])

cols = [("1 — Médaillon", "L'icône du sort dans le médaillon central du pack.", card(PEN, "medaillon"), [card(BLAST, "medaillon", "violet"), card(SMITE, "medaillon")]),
        ("2 — Icône en coin", "Petit médaillon en haut à droite, grand panneau de texte.", card(PEN, "coin"), [card(BLAST, "coin", "violet"), card(SPIRIT, "coin")]),
        ("3 — Icône encadrée", "Icône carrée, comme dans le jeu, posée sur le panneau.", card(PEN, "bandeau"), [card(BLAST, "bandeau", "violet"), card(SMITE, "bandeau", "or")])]

S = 2
BW, BH = 1040 * S, 620 * S
board = Image.new("RGBA", (BW, BH), (38, 46, 60, 255))
g = Image.new("RGBA", (BW, BH)); gd = ImageDraw.Draw(g)
for y in range(BH):
    gd.line((0, y, BW, y), fill=(18, 22, 32, int(150 * y / BH)))
board.alpha_composite(g)
txt_l = lambda x, y, s, px, fill, w=600: ImageDraw.Draw(board).text((x, y), s, font=font(px, w), fill=fill, anchor="lm")
txt_l(28 * S, 22 * S, "Cartes — pack « Mechanized Magic » (Dumivid, CC0). En haut : agrandie. En bas : taille réelle en jeu.", 14 * S, (255, 255, 255), 700)
colw = BW // 3
for i, (name, desc, big, smalls) in enumerate(cols):
    x0 = i * colw
    k = 290 * S / CH
    b = shadowed(scaled(big, k), 6 * S, 4 * S)
    board.alpha_composite(b, (x0 + colw // 2 - b.width // 2, 36 * S))
    # taille réelle en jeu : 124 × 176 pour le corps (la toile du pack déborde un peu)
    ks = 176 * S / 1197
    for j, sm in enumerate(smalls):
        s_ = shadowed(scaled(sm, ks), 4 * S, 3 * S)
        board.alpha_composite(s_, (x0 + colw // 2 + (j * 2 - 1) * 84 * S - s_.width // 2, 322 * S))
    cx = x0 + colw // 2
    ImageDraw.Draw(board).text((cx, 566 * S), name, font=font(18 * S, 700), fill=(255, 255, 255), anchor="mm")
    for n, ln in enumerate(desc.split("\n")):
        ImageDraw.Draw(board).text((cx, (588 + n * 19) * S), ln, font=font(13 * S, 500), fill=(196, 206, 222), anchor="mm")
0 and ImageDraw.Draw(board).text((BW // 2, 588 * S), "À gauche de chaque colonne : la carte agrandie. À droite : deux cartes à leur taille réelle en jeu.", font=font(12 * S, 500), fill=(150, 162, 182), anchor="mm")
board.convert("RGB").save(OUT, quality=92)
board.convert("RGB").resize((1560, 930), Image.LANCZOS).save(OUT.replace(".jpg", "_prev.jpg"), quality=86)
