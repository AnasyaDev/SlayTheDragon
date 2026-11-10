#!/usr/bin/env python3
"""Autres écrans dans le style du pack : récompense, rencontre, parcours, marchand, feu de camp.
Usage : screens_pack.py <pièces ui/> <cartes out/> <ICONS .tga> <dossier de sortie>"""
import sys, pathlib, subprocess, random

HERE = pathlib.Path(__file__).parent
OUTDIR = pathlib.Path(sys.argv[4])
sys.argv[4] = str(OUTDIR / "x.jpg")
_src = (HERE / "combat_pack.py").read_text()
exec(_src[:_src.index("\nb = Image.new")])                                   # boîte à outils de combat_pack.py
TOPBAR = _src[_src.index("# ---- bandeau"):_src.index("# ---- héros")]
TABLE = _src[_src.index("# ---- plateau"):_src.index("hexnum(b, 84, 480")]
_g = (HERE / "gen.py").read_text(); _ns = {}
exec(_g[_g.index("HERO = "):_g.index("def page(")], _ns)
SKY_DEFS = _g[_g.index('<linearGradient id="sky"'):_g.index('<linearGradient id="bar"')]
SCENE_SVG = _ns["SCENE"].replace('y="44"', 'y="46"'); HERO_SVG = _ns["HERO"]
NPC = '''<g transform="translate(790 124)"><ellipse cx="60" cy="160" rx="52" ry="9" fill="#2b1b0c" opacity="0.5"/>
<path d="M60 46 C34 62 28 120 24 156 H96 C92 120 86 62 60 46Z" fill="#7a9a5a" stroke="#3f5a2a" stroke-width="2"/>
<path d="M40 86 H80 V150 H40Z" fill="#f4efe2" stroke="#8a7350" stroke-width="2"/><circle cx="60" cy="28" r="18" fill="#e8c9a0" stroke="#8a7350" stroke-width="2"/>
<path d="M42 22 Q60 2 78 22" fill="none" stroke="#8a4a22" stroke-width="7"/></g>'''
FIRE = '''<g transform="translate(520 250)"><ellipse cx="0" cy="48" rx="70" ry="12" fill="#2b1b0c" opacity="0.5"/><circle r="120" cy="10" fill="#ffb347" opacity="0.18"/><circle r="70" cy="14" fill="#ffd27a" opacity="0.22"/>
<path d="M-44 46 L44 30 M-44 30 L44 46" stroke="#4a2f18" stroke-width="11" stroke-linecap="round"/>
<path d="M0 -44 C12 -18 34 -8 30 18 A30 30 0 0 1 -30 18 C-34 0 -18 -8 -14 -22 C-6 -14 -4 -8 -2 0 C6 -12 6 -28 0 -44Z" fill="#f08a2a"/>
<path d="M0 -14 C8 0 16 6 14 20 A14 14 0 0 1 -14 20 C-16 10 -6 4 0 -14Z" fill="#ffe08a"/></g>'''


def scene(extra="", hero=True, night=False):
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1040 620" width="{W}" height="{H}"><defs>{SKY_DEFS}</defs>'
           f'{SCENE_SVG}{HERO_SVG if hero else ""}{extra}</svg>')
    p = OUTDIR / "_s.svg"; p.write_text(svg)
    subprocess.run(["rsvg-convert", str(p), "-o", str(OUTDIR / "_s.png")], check=True)
    im = Image.open(OUTDIR / "_s.png").convert("RGBA").crop((0, 46 * S, W, 424 * S))
    im.alpha_composite(Image.new("RGBA", im.size, (20, 30, 80, 150) if night else (60, 90, 150, 38)))
    return im


def start(sc=None, table=True):
    global b, d
    b = Image.new("RGBA", (W, H), (24, 30, 40, 255))
    if sc: b.alpha_composite(sc, (0, 46 * S))
    exec(TOPBAR, globals())
    if table: exec(TABLE, globals())
    return b


def finish(name):
    d = ImageDraw.Draw(b)
    d.rounded_rectangle((0, 0, W - 1, H - 1), 9 * S, outline=(18, 22, 30, 255), width=3 * S)
    d.rounded_rectangle((2 * S, 2 * S, W - 1 - 2 * S, H - 1 - 2 * S), 7 * S, outline=(206, 214, 226, 255), width=round(1.6 * S))
    m = Image.new("L", (W, H), 0); ImageDraw.Draw(m).rounded_rectangle((0, 0, W - 1, H - 1), 9 * S, fill=255)
    out = Image.new("RGB", (W, H), (20, 24, 32)); out.paste(b.convert("RGB"), (0, 0), m)
    out.save(OUTDIR / f"{name}.jpg", quality=92); out.resize((1040, 620), Image.LANCZOS).save(OUTDIR / f"{name}_prev.jpg", quality=85)


def gold_button(cx, cy, label, w=176):
    btn = plaque(w, 50, r=25, rim=(255, 244, 200), rim_w=2.2)
    g = Image.new("RGBA", btn.size); gd = ImageDraw.Draw(g)
    for yy in range(btn.height):
        t = yy / btn.height; gd.line((0, yy, btn.width, yy), fill=(int(255 - 30 * t), int(214 - 70 * t), int(96 - 60 * t), 225))
    im2 = Image.new("RGBA", btn.size); mm = Image.new("L", btn.size, 0); ImageDraw.Draw(mm).rounded_rectangle((4 * S, 4 * S, btn.width - 4 * S, btn.height - 4 * S), 21 * S, fill=255)
    im2.paste(g, (0, 0), mm); btn.alpha_composite(im2)
    gl = Image.new("RGBA", btn.size); ImageDraw.Draw(gl).rounded_rectangle((10 * S, 7 * S, btn.width - 10 * S, 20 * S), 8 * S, fill=(255, 255, 255, 80)); btn.alpha_composite(gl)
    put(b, shadow(btn, 4, 4, 200), cx, cy); text(b, cx, cy - 2, label, 18, (52, 34, 8), w=800, shadow=False)


def slate_button(cx, cy, label, w=150):
    put(b, shadow(plaque(w, 44, r=22), 3, 3), cx, cy); text(b, cx, cy - 1, label, 16, w=700)


def deck_pile(cx=70, cy=522, n=13):
    cb = fith(CARDBACK, 104)
    put(b, shadow(cb, 3, 3), cx + 5, cy - 4); put(b, shadow(cb, 3, 3), cx, cy); hexnum(b, cx + 30, cy + 46, HEX_STEEL, n, 34, 15)


def glow_of(im, color=(255, 214, 96), blur=7, reps=2):
    pad = 40 * S; g = Image.new("RGBA", (im.width + 2 * pad, im.height + 2 * pad)); g.paste(color + (255,), (pad, pad), im.split()[3])
    g = g.filter(ImageFilter.GaussianBlur(blur * S)); out = g.copy()
    for _ in range(reps - 1): out.alpha_composite(g)
    return out


def big_card(name, cx, top, scale, glow=False):
    hand_card(b, name, cx, top, scale=scale, glow=glow)


def loot(cx, cy, ic, label=None, hot=False, size=44, rim=(206, 214, 226)):
    fr = plaque(size, size, r=10, rim=(255, 214, 96) if hot else rim, rim_w=2.0, bright=0.7)
    if hot: put(b, glow_of(fr, blur=5), cx, cy)
    put(b, shadow(fr, 3, 3), cx, cy); put(b, icon(ic, size - 8, "square"), cx, cy)
    if label: text(b, cx + size / 2 - 4, cy + size / 2 - 5, label, 15, (255, 214, 96), w=800)


def price(cx, cy, n, ok=True):
    p = plaque(58, 22, r=11, rim=(206, 214, 226) if ok else (255, 130, 120), rim_w=1.4)
    put(b, shadow(p, 2, 2), cx, cy); put(b, icon("INV_Misc_Coin_01", 15), cx - 16, cy)
    text(b, cx + 7, cy - 1, str(n), 13.5, (255, 214, 96) if ok else (255, 130, 120), w=800)


# ================= Récompense
start(scene())
big_card("whip", 410, 150, 1.08); big_card("nova", 700, 150, 1.08); big_card("penance", 555, 128, 1.26, glow=True)
loot(884, 330, "INV_Misc_Bag_10", "15"); loot(940, 338, "INV_Potion_54"); loot(912, 276, "INV_Misc_Bandage_15", hot=True, rim=(67, 178, 79))
deck_pile(); gold_button(916, 522, "Reprendre la route", 206)
text(b, 555, 522, "Une carte au choix, ou aucune.", 15, (190, 200, 216), w=500)
finish("recompense")

# ================= Rencontre
start(scene(NPC))
text(b, 850, 302, "Salma Saldean", 14, w=600)
bub = Image.new("RGBA", (round(400 * S), round(96 * S))); bm = Image.new("L", bub.size, 0)
ImageDraw.Draw(bm).rounded_rectangle((0, 0, bub.width - 1, bub.height - 1), 14 * S, fill=255)
iv = ui("body_ivory").crop((120, 480, 520, 576)).resize(bub.size, Image.LANCZOS); bub.paste(iv, (0, 0), bm)
bd = ImageDraw.Draw(bub); bd.rounded_rectangle((0, 0, bub.width - 1, bub.height - 1), 14 * S, outline=(18, 22, 30, 255), width=S); bd.rounded_rectangle((S, S, bub.width - 1 - S, bub.height - 1 - S), 13 * S, outline=(206, 214, 226, 255), width=2 * S)
tail = Image.new("RGBA", (26 * S, 18 * S)); ImageDraw.Draw(tail).polygon([(0, 0), (26 * S, 0), (20 * S, 18 * S)], fill=(214, 206, 184, 255), outline=(206, 214, 226, 255))
put(b, shadow(tail, 2, 2), 770, 172); put(b, shadow(bub, 4, 4), 600, 118)
for i, ln in enumerate(["Vous avez l'air épuisé, voyageur. Asseyez-vous,", "la soupe est chaude. Ou restez un moment en", "cuisine, je vous montre comment je la fais."]):
    text(b, 418, 96 + i * 22, ln, 14.5, (40, 34, 26), w=600, anchor="lm", shadow=False)
for cx, title, out, col, hot in [(352, "Accepter la soupe", "+10 PV", (120, 230, 130), False), (700, "Apprendre la recette", "Une carte commune parmi 3", (200, 212, 230), True)]:
    p = plaque(320, 118, r=14, rim=(255, 214, 96) if hot else (206, 214, 226), rim_w=2.4 if hot else 2.0, bright=1.25 if hot else 1.0)
    if hot: put(b, glow_of(p, blur=6), cx, 524)
    put(b, shadow(p, 4, 4), cx, 524); text(b, cx, 506, title, 20, w=700); text(b, cx, 540, out, 15.5, col, w=700)
finish("rencontre")

# ================= Parcours
start(None, table=False)
sheet_w, sheet_h = 1000, 540
mp = Image.new("RGBA", (round(sheet_w * S), round(sheet_h * S))); iv = ui("body_ivory")
tile_ = iv.crop((120, 440, 640, 720)).resize((round(sheet_w * S), round(sheet_h * S)), Image.LANCZOS)
mm = Image.new("L", mp.size, 0); ImageDraw.Draw(mm).rounded_rectangle((0, 0, mp.width - 1, mp.height - 1), 12 * S, fill=255); mp.paste(tile_, (0, 0), mm)
md = ImageDraw.Draw(mp); md.rounded_rectangle((0, 0, mp.width - 1, mp.height - 1), 12 * S, outline=(18, 22, 30, 255), width=S); md.rounded_rectangle((S, S, mp.width - 1 - S, mp.height - 1 - S), 11 * S, outline=(206, 214, 226, 255), width=2 * S)
put(b, shadow(mp, 5, 4), 520, 333)
random.seed(4)
KIND = dict(c="Ability_MeleeDamage", e="INV_Misc_Bone_HumanSkull_01", f="INV_Camelot_Camping_WelcomingCampfire", m="INV_Misc_Bag_10", q="INV_Misc_QuestionMark", t="INV_Box_01", b="Achievement_Boss_EdwinVancleef")
cols = ["ccc", "cqc", "qcm", "ect", "cfq", "qce", "fff"]
pos = {}
for i, col in enumerate(cols):
    for j, k in enumerate(col):
        pos[(i, j)] = (120 + i * 112 + random.randint(-12, 12), 170 + j * 150 + random.randint(-22, 22), k)
boss = (930, 330, "b")
edges = []
for i in range(len(cols) - 1):
    for j in range(3):
        for j2 in (j, j + random.choice([-1, 1])):
            if 0 <= j2 < 3: edges.append(((i, j), (i + 1, j2)))
path = [(0, 1), (1, 1), (2, 0)]                       # trajet déjà parcouru ; (2,0) = position actuelle
d = ImageDraw.Draw(b)


def dotted(p, q, col, wd):
    n = int(((p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2) ** .5 / 9)
    for t in range(2, n - 1):
        x = p[0] + (q[0] - p[0]) * t / n; y = p[1] + (q[1] - p[1]) * t / n
        d.ellipse(((x - wd) * S, (y - wd) * S, (x + wd) * S, (y + wd) * S), fill=col)
for a_, c_ in edges:
    done = a_ in path and c_ in path
    nxt = a_ == path[-1]
    dotted(pos[a_], pos[c_], (150, 96, 20, 255) if done else ((60, 52, 40, 255) if nxt else (120, 110, 92, 150)), 2.4 if (done or nxt) else 1.6)
for j in range(3): dotted(pos[(6, j)], boss, (120, 110, 92, 150), 1.6)
for key, (x, y, k) in pos.items():
    cur = key == path[-1]; done = key in path and not cur
    reach = any(a_ == path[-1] and c_ == key for a_, c_ in edges)
    ring = fith(RING, 46 if not cur else 54)
    if cur: put(b, glow_of(ring, blur=6), x, y)
    if reach: put(b, glow_of(ring, (255, 255, 255), blur=4, reps=1), x, y)
    put(b, shadow(ring, 2, 2), x, y)
    ic = icon(KIND[k], 36 if not cur else 42)
    if not (cur or reach or done):
        a_ = ic.split()[3]; ic = ImageOps.grayscale(ic.convert('RGB')).point(lambda v: min(255, int(v * 0.9 + 40))).convert('RGBA'); ic.putalpha(a_)
    if done: ic.putalpha(ic.split()[3].point(lambda v: v * 150 // 255))
    put(b, ic, x, y - 1)
    if done: hexnum(b, x + 16, y + 16, HEX_GREEN, "", 16)
put(b, glow_of(fith(RING, 76), (214, 38, 44), blur=6), *boss[:2]); put(b, shadow(fith(RING, 76), 3, 3), *boss[:2]); put(b, icon(KIND["b"], 60), boss[0], boss[1] - 1)
text(b, boss[0], boss[1] + 52, "Les Mortemines", 14, (40, 34, 26), w=700, shadow=False)
finish("parcours")

# ================= Marchand
start(scene(hero=False))
veil = Image.new("RGBA", (W, 378 * S), (16, 22, 34, 120)); b.alpha_composite(veil, (0, 46 * S))
for i, (n, pr, ok) in enumerate([("smite", 45, True), ("nova", 70, True), ("blast", 55, True), ("spirit", 140, False), ("fire", 45, True)]):
    cx = 150 + i * 150; big_card(n, cx, 84, 0.92, glow=(i == 1)); price(cx, 262, pr, ok)
text(b, 60, 322, "Bibelots", 13, (214, 222, 236), w=600, anchor="lm"); text(b, 420, 322, "Potions", 13, (214, 222, 236), w=600, anchor="lm"); text(b, 760, 322, "Service", 13, (214, 222, 236), w=600, anchor="lm")
for i, (ic, pr, ok) in enumerate([("INV_Misc_Bandage_15", 120, False), ("INV_Misc_Gear_01", 80, True), ("INV_Misc_Gem_Pearl_05", 95, False)]):
    loot(84 + i * 104, 368, ic, size=46); price(84 + i * 104, 406, pr, ok)
for i, (ic, pr, ok) in enumerate([("INV_Potion_54", 30, True), ("INV_Potion_76", 30, True), ("INV_Potion_83", 40, True)]):
    loot(444 + i * 104, 368, ic if ic.lower() in ICON_INDEX else "INV_Potion_54", size=46); price(444 + i * 104, 406, pr, ok)
p = plaque(230, 52, r=12); put(b, shadow(p, 3, 3), 872, 372); put(b, icon("Spell_Fire_Flameshock", 34, "square"), 786, 372)
text(b, 810, 371, "Retirer une carte", 15, w=700, anchor="lm"); price(872, 412, 60, True)
deck_pile(); gold_button(916, 522, "Reprendre la route", 206)
put(b, icon("INV_Misc_Coin_01", 34), 470, 522); text(b, 494, 520, "84", 30, (255, 214, 96), w=800, anchor="lm")
finish("marchand")

# ================= Feu de camp
start(scene(FIRE, night=True))
for cx, ic, title, out, col, hot in [(390, "INV_MISC_NightelfBedroll", "Se reposer", "+19 PV", (120, 230, 130), True), (660, "INV_Misc_Book_09", "S'entraîner", "Améliore une carte", (200, 212, 230), False)]:
    ring = fith(RING, 74)
    if hot: put(b, glow_of(ring, blur=6), cx, 350)
    put(b, shadow(ring, 3, 3), cx, 350); put(b, icon(ic, 58), cx, 349)
    p = plaque(240, 104, r=14, rim=(255, 214, 96) if hot else (206, 214, 226), rim_w=2.4 if hot else 2.0, bright=1.25 if hot else 1.0)
    if hot: put(b, glow_of(p, blur=6), cx - 5 + (0 if cx < 500 else 10), 524)
    put(b, shadow(p, 4, 4), cx - 5 + (0 if cx < 500 else 10), 524)
    text(b, cx - 5 + (0 if cx < 500 else 10), 508, title, 20, w=700); text(b, cx - 5 + (0 if cx < 500 else 10), 540, out, 15.5, col, w=700)
deck_pile()
finish("feu")
