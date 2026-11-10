#!/usr/bin/env python3
"""Écran de combat dans le style du pack Mechanized Magic (pièces extraites du PSD).
Usage : combat_pack.py <pièces ui/> <cartes out/> <ICONS .tga> <sortie.jpg>"""
import sys, pathlib, subprocess, colorsys
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops, ImageOps

UI, CARDS, ICONS, OUT = map(pathlib.Path, sys.argv[1:5])
HERE = pathlib.Path(__file__).parent
FONT = str(pathlib.Path.home() / ".local/share/fonts/BalooChettan2.ttf")
S = 2
W, H = 1040 * S, 620 * S
ICON_INDEX = {p.stem.lower(): p for p in ICONS.glob("*.tga")}


def font(px, w=700):
    f = ImageFont.truetype(FONT, round(px * S))
    try: f.set_variation_by_axes([w])
    except Exception: pass
    return f


def ui(name): return Image.open(UI / f"{name}.png").convert("RGBA")
def fit(im, w, h): return im.resize((round(w * S), round(h * S)), Image.LANCZOS)
def fith(im, h): return im.resize((round(im.width * h * S / im.height), round(h * S)), Image.LANCZOS)


def put(dst, im, cx, cy):
    dst.alpha_composite(im, (round(cx * S - im.width / 2), round(cy * S - im.height / 2)))


def text(dst, x, y, s, px, fill=(255, 255, 255), w=700, anchor="mm", shadow=True):
    d = ImageDraw.Draw(dst); f = font(px, w)
    if shadow:
        sh = Image.new("RGBA", dst.size); ImageDraw.Draw(sh).text((x * S, y * S + 1.5 * S), s, font=f, fill=(0, 0, 0, 210), anchor=anchor)
        box = sh.getbbox()
        if box:
            pad = 4 * S; box = (max(box[0] - pad, 0), max(box[1] - pad, 0), min(box[2] + pad, dst.width), min(box[3] + pad, dst.height))
            dst.alpha_composite(sh.crop(box).filter(ImageFilter.GaussianBlur(1.2 * S)), box[:2])
    d.text((x * S, y * S), s, font=f, fill=fill, anchor=anchor)


def icon(name, px, shape="disc", grey=False):
    im = Image.open(ICON_INDEX[name.lower()]).convert("RGBA")
    k = int(im.width * 0.07); im = im.crop((k, k, im.width - k, im.height - k)).resize((round(px * S),) * 2, Image.LANCZOS)
    if grey: im = ImageOps.grayscale(im).convert("RGBA").point(lambda v: int(v * 0.6))
    m = Image.new("L", im.size, 0); d = ImageDraw.Draw(m)
    if shape == "disc": d.ellipse((0, 0, im.width - 1, im.height - 1), fill=255)
    else: d.rounded_rectangle((0, 0, im.width - 1, im.height - 1), round(px * S * 0.2), fill=255)
    im.putalpha(m); return im


def hue(im, h, sat=1.0, val=1.0):
    """Reteinte une pièce en gardant son modelé."""
    r, g, b, a = im.split(); hsv = Image.merge("RGB", (r, g, b)).convert("HSV"); hh, ss, vv = hsv.split()
    hh = hh.point(lambda _: int(h * 255)); ss = ss.point(lambda v: min(255, int(v * sat))); vv = vv.point(lambda v: min(255, int(v * val)))
    out = Image.merge("HSV", (hh, ss, vv)).convert("RGB"); out.putalpha(a); return out


def shadow(im, blur=4, dy=3, alpha=170):
    pad = round(blur * 3 * S); b = Image.new("RGBA", (im.width + 2 * pad, im.height + 2 * pad)); s = Image.new("RGBA", b.size)
    s.paste((0, 0, 0, alpha), (pad, pad + round(dy * S)), im.split()[3])
    b.alpha_composite(s.filter(ImageFilter.GaussianBlur(blur * S))); b.alpha_composite(im, (pad, pad)); return b


# ---- matières tirées des pièces du pack
PANEL = ui("panel")
SLATE = PANEL.crop((120, 90, 548, 350))            # cuir ardoise du panneau de texte


def slate(w, h, tint=None, bright=1.0):
    t = Image.new("RGBA", (round(w * S), round(h * S)))
    for y in range(0, t.height, SLATE.height):
        for x in range(0, t.width, SLATE.width):
            tile = SLATE if (x // SLATE.width) % 2 == 0 else ImageOps.mirror(SLATE)
            t.paste(tile, (x, y))
    if bright != 1.0: t = t.point(lambda v: min(255, int(v * bright)))
    if tint: t = ImageChops.multiply(t, Image.new("RGBA", t.size, tint + (255,)))
    t.putalpha(255); return t


def plaque(w, h, r=8, rim=(214, 220, 230), tint=None, bright=1.0, rim_w=2.0):
    """Plaque ardoise au liseré d'argent, comme le panneau de texte des cartes."""
    w2, h2 = round(w * S), round(h * S)
    m = Image.new("L", (w2, h2), 0); ImageDraw.Draw(m).rounded_rectangle((0, 0, w2 - 1, h2 - 1), r * S, fill=255)
    body = slate(w, h, tint, bright); body.putalpha(m)
    d = ImageDraw.Draw(body)
    d.rounded_rectangle((0, 0, w2 - 1, h2 - 1), r * S, outline=(18, 22, 30, 255), width=S)
    d.rounded_rectangle((S, S, w2 - 1 - S, h2 - 1 - S), (r - 1) * S, outline=rim + (255,), width=round(rim_w * S))
    d.rounded_rectangle((S + round(rim_w * S), S + round(rim_w * S), w2 - 1 - S - round(rim_w * S), h2 - 1 - S - round(rim_w * S)), max(r - 3, 1) * S, outline=(12, 16, 22, 200), width=S)
    gl = Image.new("RGBA", body.size); ImageDraw.Draw(gl).rounded_rectangle((3 * S, 3 * S, w2 - 3 * S, h2 * 0.45), (r - 2) * S, fill=(255, 255, 255, 16))
    body.alpha_composite(gl); body.putalpha(ImageChops.multiply(body.split()[3], m)); return body


ST = ui("stats")
HEX_RED = ST.crop((0, 0, ST.width // 3, ST.height)); HEX_RED = HEX_RED.crop(HEX_RED.getbbox())
HEX_GREEN = ST.crop((ST.width * 2 // 3, 0, ST.width, ST.height)); HEX_GREEN = HEX_GREEN.crop(HEX_GREEN.getbbox())
HEX_BLUE = hue(HEX_GREEN, 0.60, 1.0, 1.1); HEX_STEEL = hue(HEX_GREEN, 0.58, 0.35, 1.15); HEX_VOID = hue(HEX_GREEN, 0.76, 0.9, 1.05)
HEX_EMPTY = hue(HEX_GREEN, 0.6, 0.15, 0.45)
RING = ui("ring"); CARDBACK = ui("cardback")


def hexnum(dst, cx, cy, sprite, n, size, px=None):
    put(dst, shadow(fith(sprite, size), 2, 2), cx, cy + 1)
    if n != "": text(dst, cx, cy - size * 0.03, str(n), px or size * 0.5, w=800)


def hpbar(dst, x, y, w, cur, mx, flash=None):
    tr = plaque(w, 13, r=6, rim=(120, 130, 146), rim_w=1.2, bright=0.6)
    dst.alpha_composite(shadow(tr, 2, 2), (round(x * S) - round(6 * S), round(y * S) - round(6 * S)))
    d = ImageDraw.Draw(dst); x0, y0 = (x + 3) * S, (y + 3) * S; full = (w - 6) * S; hh = 7 * S
    if flash: d.rounded_rectangle((x0, y0, x0 + full * flash / mx, y0 + hh), 3 * S, fill=(255, 236, 170, 255))
    fw = max(full * cur / mx, 8 * S)
    d.rounded_rectangle((x0, y0, x0 + fw, y0 + hh), 3 * S, fill=(214, 38, 44, 255))
    d.rounded_rectangle((x0 + 2 * S, y0 + S, x0 + fw - 2 * S, y0 + 3 * S), S, fill=(255, 130, 130, 200))
    hexnum(dst, x - 2, y + 6.5, HEX_RED, cur, 34, 15)


def token(dst, cx, cy, ic, n):
    put(dst, shadow(fith(RING, 30), 2, 2), cx, cy + 1); put(dst, icon(ic, 23), cx, cy - 0.6)
    text(dst, cx + 10, cy + 9, str(n), 12.5, w=800)


def intent(dst, cx, y, rim, ic, label):
    big = len(str(label)) <= 2
    w = 64 if big else 46 + 7.6 * len(str(label))
    p = plaque(w, 30, r=15, rim=rim)
    tail = Image.new("RGBA", (round(18 * S), round(10 * S))); td = ImageDraw.Draw(tail)
    td.polygon([(0, 0), (18 * S, 0), (9 * S, 10 * S)], fill=(34, 42, 54, 255), outline=rim + (255,))
    put(dst, shadow(tail, 2, 2), cx, y + 33); put(dst, shadow(p, 3, 2), cx, y + 15)
    put(dst, icon(ic, 22), cx - w / 2 + 16, y + 15)
    text(dst, cx - w / 2 + 31, y + 14, str(label), 19 if big else 13.5, w=800, anchor="lm")


def card(name): return Image.open(CARDS / f"{name}.png").convert("RGBA")
BODY_W = 860                                        # largeur du corps dans la toile 1062 × 1471


def hand_card(dst, name, cx, top, scale=1.0, off=None, glow=False):
    im = card(name)
    if off:
        r, g, b, a = im.split(); gr = ImageOps.grayscale(Image.merge("RGB", (r, g, b))).point(lambda v: int(v * 0.62)).convert("RGB"); gr.putalpha(a); im = gr
    k = 124 * scale * S / BODY_W
    im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
    x = round(cx * S - im.width / 2); y = round(top * S - 183 * k)
    if glow:
        g = Image.new("RGBA", (im.width + 80 * S, im.height + 80 * S)); g.paste((255, 214, 96, 255), (40 * S, 40 * S), im.split()[3])
        g = g.filter(ImageFilter.GaussianBlur(7 * S)); dst.alpha_composite(g, (x - 40 * S, y - 40 * S)); dst.alpha_composite(g, (x - 40 * S, y - 40 * S))
    sh = shadow(im, 5, 4); dst.alpha_composite(sh, (x - round(15 * S), y - round(15 * S)))
    if off:
        p = plaque(104, 20, r=10, rim=(255, 170, 160), tint=(255, 120, 110), bright=1.5)
        put(dst, p, cx, top + 150 * scale); text(dst, cx, top + 149 * scale, off, 11.5, w=700)


def scene_png():
    """Décor et personnages provisoires, repris de la maquette vectorielle."""
    src = (HERE / "gen.py").read_text(); ns = {}
    exec(src[src.index("HERO = "):src.index("def page(")], ns)
    src2 = (HERE / "gen2.py").read_text(); ns2 = {}
    exec("ENEMY = " + src2[src2.index("ENEMY = ") + 8:src2.index("def combat()")], ns2)
    defs = src[src.index('<linearGradient id="sky"'):src.index('<linearGradient id="bar"')]
    E = ns2["ENEMY"]
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1040 620" width="{W}" height="{H}"><defs>{defs}</defs>'
           f'{ns["SCENE"].replace(chr(121) + "=" + chr(34) + "44" + chr(34), "y=" + chr(34) + "46" + chr(34))}{ns["HERO"]}'
           f'<g transform="translate(535 130)">{E["gnoll"]}</g><g transform="translate(711 158) scale(0.9)">{E["mystic"]}</g><g transform="translate(875 134)">{E["bandit"]}</g></svg>')
    p = OUT.with_name("_scene.svg"); p.write_text(svg)
    subprocess.run(["rsvg-convert", str(p), "-o", str(OUT.with_name("_scene.png"))], check=True)
    return Image.open(OUT.with_name("_scene.png")).convert("RGBA")


b = Image.new("RGBA", (W, H), (24, 30, 40, 255))
b.alpha_composite(scene_png().crop((0, 46 * S, W, 424 * S)), (0, 46 * S))
cool = Image.new("RGBA", (W, 378 * S), (60, 90, 150, 38)); b.alpha_composite(cool, (0, 46 * S))

# ---- bandeau
bar = slate(1040, 46, bright=1.15); b.alpha_composite(bar, (0, 0))
d = ImageDraw.Draw(b)
d.rectangle((0, 44 * S, W, 46 * S), fill=(18, 22, 30, 255)); d.rectangle((0, 43 * S, W, 44.4 * S), fill=(206, 214, 226, 255))
text(b, 20, 22, "Prêtre", 18, anchor="lm")
hexnum(b, 108, 23, HEX_RED, "", 22); text(b, 123, 22, "52", 17, anchor="lm", w=800); text(b, 147, 23, "/65", 12.5, (190, 200, 214), anchor="lm", w=600)
put(b, icon("INV_Misc_Coin_01", 20), 200, 23); text(b, 215, 22, "84", 17, (255, 214, 96), anchor="lm", w=800)
put(b, shadow(fith(CARDBACK, 30), 1, 1), 266, 23); text(b, 282, 22, "13", 17, anchor="lm", w=800)
text(b, 520, 14, "Marche de l'Ouest", 13, (226, 232, 242), w=600)
d = ImageDraw.Draw(b)
d.line((443 * S, 32 * S, 597 * S, 32 * S), fill=(18, 22, 30, 255), width=4 * S); d.line((443 * S, 32 * S, 597 * S, 32 * S), fill=(92, 104, 124, 255), width=2 * S)
d.line((443 * S, 32 * S, 487 * S, 32 * S), fill=(255, 214, 96, 255), width=2 * S)
for i in range(8):
    x = (443 + 22 * i) * S; y = 32 * S
    if i < 2: d.ellipse((x - 4.5 * S, y - 4.5 * S, x + 4.5 * S, y + 4.5 * S), fill=(255, 214, 96, 255), outline=(18, 22, 30, 255), width=S)
    elif i == 2: d.ellipse((x - 6.5 * S, y - 6.5 * S, x + 6.5 * S, y + 6.5 * S), fill=(255, 250, 224, 255), outline=(255, 214, 96, 255), width=2 * S)
    elif i < 7: d.ellipse((x - 4 * S, y - 4 * S, x + 4 * S, y + 4 * S), fill=(40, 48, 62, 255), outline=(130, 142, 160, 255), width=S)
    else: hexnum(b, 443 + 22 * i, 32, HEX_RED, "", 16)
hexnum(b, 742, 23, HEX_VOID, "+2", 28, 11.5)


def slot(cx, ic=None):
    fr = plaque(30, 30, r=7, rim=(206, 214, 226), rim_w=1.6, bright=0.7)
    put(b, shadow(fr, 1, 1), cx, 23)
    if ic: put(b, icon(ic, 23, "square"), cx, 23)
for cx, ic in [(782, "INV_Misc_Herb_01"), (816, "INV_Misc_Gear_01")]: slot(cx, ic)
ImageDraw.Draw(b).rectangle((840 * S, 11 * S, 841.5 * S, 35 * S), fill=(18, 22, 30, 255))
for cx, ic in [(866, "INV_Potion_54"), (900, "INV_Potion_76"), (934, None)]: slot(cx, ic)
for cx, glyph, tintc in [(972, "menu", None), (1008, "x", (255, 110, 110))]:
    p = plaque(28, 28, r=14, rim=(206, 214, 226), rim_w=1.6, tint=tintc, bright=1.5 if tintc else 1.0)
    put(b, shadow(p, 1, 1), cx, 23); d = ImageDraw.Draw(b)
    if glyph == "menu":
        for dy in (-4.5, 0, 4.5): d.line(((cx - 5.5) * S, (23 + dy) * S, (cx + 5.5) * S, (23 + dy) * S), fill=(255, 255, 255, 255), width=round(2 * S))
    else:
        d.line(((cx - 4.5) * S, 18.5 * S, (cx + 4.5) * S, 27.5 * S), fill=(255, 255, 255, 255), width=round(2.4 * S)); d.line(((cx + 4.5) * S, 18.5 * S, (cx - 4.5) * S, 27.5 * S), fill=(255, 255, 255, 255), width=round(2.4 * S))

# ---- héros
cp = plaque(190, 36, r=10)
put(b, shadow(cp, 3, 2), 196, 100); put(b, fith(RING, 32), 121, 100); put(b, icon("Spell_Holy_SearingLight", 24), 121, 99.4)
text(b, 140, 94, "Flammes sacrées", 12.5, anchor="lm", w=700)
d = ImageDraw.Draw(b); d.rounded_rectangle((140 * S, 104 * S, 280 * S, 110 * S), 3 * S, fill=(12, 16, 22, 255)); d.rounded_rectangle((141 * S, 105 * S, 228 * S, 109 * S), 2 * S, fill=(255, 214, 96, 255))
hpbar(b, 134, 306, 138, 52, 65)
hexnum(b, 290, 312, HEX_STEEL, 8, 30, 14)
token(b, 180, 348, "Ability_Priest_Atonement", 2); token(b, 216, 348, "Spell_Holy_Renew", 3)

# ---- ennemis
intent(b, 595, 86, (255, 120, 110), "Ability_MeleeDamage", 6)
g = Image.new("RGBA", b.size); gd = ImageDraw.Draw(g); gd.ellipse((535 * S, 255 * S, 655 * S, 281 * S), outline=(255, 214, 96, 255), width=3 * S)
b.alpha_composite(g.filter(ImageFilter.GaussianBlur(4 * S))); b.alpha_composite(g)
d = ImageDraw.Draw(b); d.text((644 * S, 164 * S), "−9", font=font(34, 800), fill=(255, 255, 255), anchor="mm", stroke_width=round(3 * S), stroke_fill=(150, 24, 20))
hpbar(b, 542, 292, 120, 5, 14, flash=14); text(b, 598, 326, "Gnoll Rivepatte", 13.5, w=600)
token(b, 598, 348, "Spell_Shadow_ShadowWordPain", 4)
intent(b, 765, 114, (196, 150, 255), "Spell_Shadow_EvilEye", "Guette")
hpbar(b, 714, 304, 114, 12, 12); text(b, 768, 338, "Mystique Rivepatte", 13.5, w=600)
intent(b, 935, 90, (150, 196, 255), "INV_Shield_04", 6)
hpbar(b, 882, 296, 120, 13, 18); text(b, 938, 330, "Bandit défias", 13.5, w=600)

# ---- plateau
tb = slate(1040, 196, bright=0.95); b.alpha_composite(tb, (0, 424 * S))
d = ImageDraw.Draw(b)
d.rectangle((0, 424 * S, W, 427 * S), fill=(18, 22, 30, 255)); d.rectangle((0, 426 * S, W, 428.6 * S), fill=(206, 214, 226, 255)); d.rectangle((0, 428.6 * S, W, 430 * S), fill=(18, 22, 30, 255))
sh = Image.new("RGBA", (W, 26 * S)); sd = ImageDraw.Draw(sh)
for y in range(26 * S): sd.line((0, y, W, y), fill=(0, 0, 0, int(120 * (1 - y / (26 * S)))))
b.alpha_composite(sh, (0, 430 * S))
hexnum(b, 84, 490, HEX_BLUE, "", 96); text(b, 78, 486, "2", 40, w=800); text(b, 103, 494, "/3", 20, (214, 230, 255), w=700)
for i, sp in enumerate([HEX_BLUE, HEX_BLUE, HEX_EMPTY]): hexnum(b, 62 + i * 22, 548, sp, "", 20)
hexnum(b, 130, 452, HEX_VOID, 3, 36, 16)
for cx, n, a in [(52, 7, 255), (116, 3, 150)]:
    cb = fith(CARDBACK, 52)
    if a < 255: cb.putalpha(cb.split()[3].point(lambda v: v * a // 255))
    put(b, shadow(cb, 2, 2), cx, 590); text(b, cx, 589, str(n), 17, w=800)
hand_card(b, "smite", 258, 454); hand_card(b, "penance", 388, 440); hand_card(b, "fire", 660, 440)
hand_card(b, "spirit", 790, 454, off="Mana insuffisant")
hand_card(b, "blast", 524, 372, scale=1.18, glow=True)
for i, (n, ic) in enumerate([(2, "Spell_Holy_PowerWordShield"), (1, "Spell_Holy_HolyNova")]):
    cx = 916 + i * 54
    fr = plaque(46, 46, r=9, rim=(150, 160, 176), rim_w=1.6, bright=0.7); put(b, shadow(fr, 2, 2), cx, 470)
    put(b, icon(ic, 38, "square", grey=True), cx, 470); text(b, cx, 469, str(n), 24, w=800)
btn = plaque(156, 50, r=25, rim=(255, 244, 200), rim_w=2.2)
gold = Image.new("RGBA", btn.size); gd2 = ImageDraw.Draw(gold)
for yy in range(btn.height):
    t = yy / btn.height; gd2.line((0, yy, btn.width, yy), fill=(int(255 - 30 * t), int(214 - 70 * t), int(96 - 60 * t), 225))
im2 = Image.new("RGBA", btn.size); mm = Image.new("L", btn.size, 0); ImageDraw.Draw(mm).rounded_rectangle((4 * S, 4 * S, btn.width - 4 * S, btn.height - 4 * S), 21 * S, fill=255)
im2.paste(gold, (0, 0), mm); btn.alpha_composite(im2)
gl2 = Image.new("RGBA", btn.size); ImageDraw.Draw(gl2).rounded_rectangle((10 * S, 7 * S, btn.width - 10 * S, 20 * S), 8 * S, fill=(255, 255, 255, 80)); btn.alpha_composite(gl2)
put(b, shadow(btn, 4, 4, 200), 944, 548); text(b, 944, 546, "Fin du tour", 19, (52, 34, 8), w=800, shadow=False)

# ---- cadre
d = ImageDraw.Draw(b)
d.rounded_rectangle((0, 0, W - 1, H - 1), 9 * S, outline=(18, 22, 30, 255), width=3 * S)
d.rounded_rectangle((2 * S, 2 * S, W - 1 - 2 * S, H - 1 - 2 * S), 7 * S, outline=(206, 214, 226, 255), width=round(1.6 * S))
m = Image.new("L", (W, H), 0); ImageDraw.Draw(m).rounded_rectangle((0, 0, W - 1, H - 1), 9 * S, fill=255)
out = Image.new("RGB", (W, H), (20, 24, 32)); out.paste(b.convert("RGB"), (0, 0), m)
out.save(OUT, quality=92); out.resize((1560, 930), Image.LANCZOS).save(str(OUT).replace(".jpg", "_prev.jpg"), quality=86)
