#!/usr/bin/env python3
"""Maquettes « habillage WoW » de Slay the Dragon : trois directions (A classique, B moderne, C carte de vol),
appliquées au combat, au parcours, à une rencontre et au menu / options. Textes en anglais.
Usage : python3 -I docs/maquette/gen_wowui.py [A B C]   → build/wowui/direction_<X>_<écran>.jpg + comparatif.jpg
Prérequis : textures décodées dans build/wowui/png (voir wowui_kit.py), aperçu du harnais dans build/snap."""
import sys, json, math, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent))
import wowui_kit as K
from wowui_kit import P, S, W, H, put, put_sh, rs, text, tw, wrap, icon, piece, scaled
from PIL import Image, ImageDraw, ImageFilter

USED = {}
_piece = K.piece


def track(d):
    def f(name):
        USED.setdefault(d, set()).add(name); return _piece(name)
    return f


GOLD = (255, 209, 0)          # NORMAL_FONT_COLOR de l'interface
WHITE = (255, 255, 255)
GREY = (190, 190, 190)
GREEN = (30, 255, 32)
RED = (255, 32, 32)
INK = (58, 34, 14)

# ------------------------------------------------------------------ contenus partagés
HAND = [("smite", 276), ("mindblast", 398), ("solace", 520), ("penance", 642), ("shadowform", 764)]
ENEMIES = [  # nom, silhouette, x, pied, pv, max, intention (icône, valeur), débuffs
    ("Riverpaw Gnoll", "gnoll", 600, 330, 5, 14, ("ability_meleedamage", "6"), [("spell_shadow_shadowwordpain", 4)]),
    ("Riverpaw Mystic", "mystic", 772, 312, 12, 12, ("spell_shadow_evileye", ""), []),
    ("Defias Bandit", "bandit", 944, 330, 13, 18, ("inv_shield_04", "6"), []),
]
TRINKETS = ["inv_jewelry_talisman_07", "inv_misc_rune_01"]
POTIONS = ["inv_potion_51", "inv_potion_76", None]
COLS = [118, 226, 334, 442, 550, 658, 766]
NODES = {  # id: (col, y, type, état)  états : done, here, next, open, far
    "a0": (0, 254, "combat", "done"), "b0": (0, 432, "combat", "far"),
    "a1": (1, 254, "combat", "done"), "b1": (1, 432, "combat", "far"),
    "a2": (2, 254, "combat", "here"), "b2": (2, 432, "combat", "far"),
    "a3": (3, 208, "combat", "next"), "m3": (3, 340, "merchant", "next"), "b3": (3, 460, "combat", "far"),
    "a4": (4, 254, "event", "open"), "b4": (4, 432, "event", "far"),
    "a5": (5, 254, "elite", "open"), "b5": (5, 432, "elite", "far"),
    "a6": (6, 208, "camp", "open"), "m6": (6, 340, "camp", "open"), "b6": (6, 460, "camp", "far"),
}
EDGES = [("a0", "a1"), ("b0", "b1"), ("a1", "a2"), ("b1", "b2"), ("a2", "a3"), ("a2", "m3"), ("b2", "m3"), ("b2", "b3"),
         ("a3", "a4"), ("m3", "a4"), ("m3", "b4"), ("b3", "b4"), ("a4", "a5"), ("b4", "a5"), ("b4", "b5"),
         ("a5", "a6"), ("a5", "m6"), ("b5", "m6"), ("b5", "b6"), ("a6", "boss"), ("m6", "boss"), ("b6", "boss")]
BOSS = (896, 340)
NODE_ICON = {"combat": "ability_meleedamage", "merchant": "inv_misc_bag_10", "event": "inv_misc_questionmark",
             "elite": "inv_misc_bone_humanskull_01", "camp": "inv_camelot_camping_welcomingcampfire"}


def node_xy(n):
    if n == "boss": return BOSS
    c, y, *_ = NODES[n]; return (COLS[c], y)


def edge_state(a, b):
    sa = NODES[a][3]; sb = NODES[b][3] if b != "boss" else "open"
    if sa in ("done", "here") and sb in ("done", "here"): return "done"
    if sa == "here": return "next"
    if "far" in (sa, sb): return "far"
    return "open"


def new_canvas(col=(12, 12, 14, 255)): return Image.new("RGBA", (W, H), col)


def save(img, d, screen):
    return K.finish(img, K.B / f"direction_{d}_{screen}.jpg")


def dim(img, a=0.62):
    img.alpha_composite(Image.new("RGBA", img.size, (0, 0, 0, int(255 * a))))


def bar_fill(w, h, rgb, tex="statusbar"):
    im = rs(K.piece(tex), w, h); return K.tint(im, rgb, 1.25) if tex == "statusbar" else im


def ellipse_ring(img, cx, cy, rx, ry, col, width=3, blur=2.5):
    g = Image.new("RGBA", img.size); ImageDraw.Draw(g).ellipse((P(cx - rx), P(cy - ry), P(cx + rx), P(cy + ry)), outline=col, width=P(width))
    img.alpha_composite(g.filter(ImageFilter.GaussianBlur(P(blur)))); img.alpha_composite(g)


def float_text(img, x, y, s, px, face, fill, ocol):
    text(img, x, y, s, px, fill=fill, face=face, anchor="mm", outline=2.2, ocol=ocol)


def line_pts(a, b, step):
    (x0, y0), (x1, y1) = a, b; L = math.hypot(x1 - x0, y1 - y0); n = max(1, int(L / step))
    return [(x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n) for i in range(n + 1)]


def strip_along(img, a, b, strip, width, inset=0):
    """Pose une texture répétée (strip, verticale) le long du segment a→b."""
    (x0, y0), (x1, y1) = a, b; L = math.hypot(x1 - x0, y1 - y0) - 2 * inset
    if L <= 0: return
    s = rs(strip, P(width), P(width) * strip.height / strip.width)
    col = K.tile_strip(s, P(L), False)
    ang = math.degrees(math.atan2(y1 - y0, x1 - x0))
    r = col.rotate(90 - ang, expand=True, resample=Image.BICUBIC)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    img.alpha_composite(r, (P(cx) - r.width // 2, P(cy) - r.height // 2))


def aura(img, x, y, ic, n, size, face, border=(0, 0, 0), debuff=False):
    """Icône d'aura (buff / débuff) avec compteur, façon cadre d'unité."""
    d = ImageDraw.Draw(img)
    col = (204, 0, 0) if debuff else border
    d.rectangle((P(x - size / 2) - S, P(y - size / 2) - S, P(x + size / 2) + S - 1, P(y + size / 2) + S - 1), fill=col)
    put(img, icon(ic, size), x, y)
    if n != "" and n is not None:
        text(img, x + size / 2 + 1, y + size / 2 + 1, str(n), size * 0.5, fill=WHITE, face=face, anchor="rb", outline=1.4)


def nameplate(img, x, y, w, hp, mx, rgb, face, label=None):
    """Plaque de nom classique (128 × 17) : barre intérieure x 4..104, y 4..13 ; case de niveau à droite."""
    h = w * 17 / 128; x0 = x - w / 2; y0 = y - h / 2
    ix0, ix1, iy0, iy1 = x0 + w * 4 / 128, x0 + w * 104 / 128, y0 + h * 4 / 17, y0 + h * 13 / 17
    ImageDraw.Draw(img).rectangle((P(ix0), P(iy0), P(ix1), P(iy1)), fill=(0, 0, 0, 200))
    f = bar_fill(P(ix1 - ix0), P(iy1 - iy0), rgb)
    img.alpha_composite(f.crop((0, 0, max(1, round(f.width * hp / mx)), f.height)), (P(ix0), P(iy0)))
    put(img, rs(K.piece("nameplate_border"), P(w), P(h)), x, y)
    text(img, (ix0 + ix1) / 2, (iy0 + iy1) / 2 + 0.3, label or f"{hp} / {mx}", 9.5 * w / 112, fill=WHITE, face=face, anchor="mm", outline=1.2)


# ================================================================== DIRECTION A : classique 2004-2010
class A:
    key = "A"; face = "friz"; title_face = "friz"
    label = "A · Classique 2004-2010"

    def frame(self, img, sections=(50, 424)):
        b = K.backdrop(W, H, "dialog_border", 26)
        for y in sections:
            if y is None: continue
            seg = K.piece("dialog_border").crop((64, 0, 96, 32)).transpose(Image.ROTATE_270)
            s = K.tile_strip(rs(seg, P(26), P(26)), W - P(18))
            img.alpha_composite(s, (P(9), P(y - 13)))
        img.alpha_composite(b)

    def bg_dark(self, img, y0, y1):
        t = K.tile(K.piece("dialog_bg_dark"), W, P(y1 - y0), 1.0 * S)
        img.alpha_composite(t, (0, P(y0)))
        img.alpha_composite(Image.new("RGBA", t.size, (12, 12, 14, 120)), (0, P(y0)))

    def slot(self, img, cx, cy, size, ic=None, n=None, gray=False):
        q = scaled("quickslot2", size * 64 / 36)
        if ic: put(img, icon(ic, size, gray=gray), cx, cy)
        else: put(img, scaled("quickslot", size * 64 / 36), cx, cy)
        put(img, q, cx, cy)
        if n is not None: text(img, cx + size / 2 - 2, cy + size / 2 - 2, str(n), 12, fill=WHITE, face=self.face, anchor="rb", outline=1.4)

    def button(self, img, cx, cy, w, h, label, px=12, big=False):
        if big:
            b = K.three(K.piece("red128_left"), K.piece("red128_center"), K.piece("red128_right"), P(w), P(h))
        else:
            b = K.three_cut(K.piece("panel_button_up"), 12, 12, P(w), P(h))
        put(img, b, cx, cy)
        text(img, cx, cy + (0 if big else 0.5), label, px, fill=GOLD, face=self.face, anchor="mm", shadow=True)

    def header(self, img, cx, y, w, title, px=14):
        hd = K.three_cut(K.piece("dialog_header"), 40, 40, P(w), P(w * 78 / 276 * 0.82))
        put(img, hd, cx, y)
        text(img, cx, y - 1, title, px, fill=GOLD, face=self.title_face, anchor="mm")

    def topbar(self, img, title, progress=True):
        self.bg_dark(img, 0, 50)
        text(img, 24, 26, "Priest", 15, fill=GOLD, face=self.face)
        # vie : barre classique dans une plaque de nom
        nameplate(img, 146, 26, 120, 52, 65, (0, 220, 0), self.face)
        put(img, scaled("gold_icon", 14), 224, 26); text(img, 234, 26, "84", 13, fill=WHITE, face=self.face)
        self.slot(img, 280, 26, 22, "inv_misc_book_09"); text(img, 296, 26, "13", 13, fill=WHITE, face=self.face)
        self.header(img, 520, 24, 250, title)
        if progress:
            for i in range(8):
                f = "green" if i < 2 else ("yellow" if i == 2 else ("red" if i == 7 else "gray"))
                put(img, scaled("taxi_icon_" + f, 13), 469 + i * 14.5, 37)
        for i, ic in enumerate(TRINKETS): self.slot(img, 704 + i * 30, 26, 24, ic)
        for i, ic in enumerate(POTIONS): self.slot(img, 776 + i * 30, 26, 24, ic)
        self.button(img, 918, 26, 66, 22, "Menu", 11)
        put(img, scaled("minimize_up", 30), 1004, 25)

    def table(self, img):
        t = K.tile(K.piece("bg_marble"), W, P(196), 0.5 * S)
        img.alpha_composite(t, (0, P(424)))
        img.alpha_composite(Image.new("RGBA", t.size, (0, 0, 0, 70)), (0, P(424)))

    def mana(self, img, cx, cy):
        put(img, icon("inv_elemental_mote_mana", 52, round_=True), cx, cy - 4)
        K.ring(img, cx, cy - 4, 52)
        text(img, cx, cy - 4, "2/3", 22, fill=WHITE, face=self.face, anchor="mm", outline=2.2)
        text(img, cx, cy + 40, "Mana", 11, fill=GOLD, face=self.face, anchor="mm")

    def piles(self, img):
        for cx, ic, n, lab in [(140, "inv_misc_book_09", 7, "Draw"), (186, "inv_misc_bag_10", 3, "Discard")]:
            self.slot(img, cx, 562, 34, ic, n); text(img, cx, 590, lab, 10, fill=GOLD, face=self.face, anchor="mm")

    def unit_hero(self, img):
        tf = K.piece("target_frame").transpose(Image.FLIP_LEFT_RIGHT)
        k = 1.05; x0, y0 = 4, 50
        # barres (sous le cadre) : coordonnées mesurées dans la texture miroir (256 - x)
        img.alpha_composite(bar_fill(P(117 * k), P(9 * k), (0, 220, 0)).crop((0, 0, P(117 * k * 52 / 65), P(9 * k))), (P(x0 + 108 * k), P(y0 + 42 * k)))
        img.alpha_composite(bar_fill(P(117 * k), P(9 * k), (0, 80, 255)).crop((0, 0, P(117 * k * 2 / 3), P(9 * k))), (P(x0 + 108 * k), P(y0 + 53 * k)))
        ImageDraw.Draw(img).rectangle((P(x0 + 108 * k), P(y0 + 23 * k), P(x0 + 225 * k), P(y0 + 40 * k)), fill=(0, 0, 0, 150))
        put(img, K.disc(rs(K.piece("portrait_hero"), P(54 * k), P(54 * k))), x0 + 74 * k, y0 + 41 * k)
        put(img, rs(tf, P(256 * k), P(128 * k)), x0 + 128 * k, y0 + 64 * k)
        text(img, x0 + 166 * k, y0 + 32 * k, "Priest", 11, fill=GOLD, face=self.face, anchor="mm")
        text(img, x0 + 166 * k, y0 + 47 * k, "52 / 65", 9, fill=WHITE, face=self.face, anchor="mm", outline=1)
        text(img, x0 + 166 * k, y0 + 58 * k, "2 / 3", 9, fill=WHITE, face=self.face, anchor="mm", outline=1)
        for i, (ic, n) in enumerate([("spell_holy_powerwordshield", 8), ("ability_priest_atonement", 2), ("spell_holy_renew", 3)]):
            aura(img, x0 + 117 + i * 27, y0 + 80, ic, n, 22, self.face)
        K.sil(img, "hero", 190, 330, 190)
        ellipse_ring(img, 190, 330, 52, 11, (40, 220, 40, 230))

    def unit_enemy(self, img, e, target=False):
        name, kind, x, foot, hp, mx, (ic, val), debuffs = e
        if target: ellipse_ring(img, x, foot, 58, 12, (255, 220, 0, 240))
        K.sil(img, kind, x, foot, 158)
        top = foot - 150
        nameplate(img, x + 7, top + 8, 128, hp, mx, (255, 0, 0), self.face)
        text(img, x, top - 9, name, 11.5, fill=(255, 240, 0) if target else WHITE, face=self.face, anchor="mm", outline=1.3)
        # intention : icône posée dans une case de barre d'action, valeur en gros
        self.slot(img, x - 12, top - 40, 26, ic)
        if val: text(img, x + 8, top - 40, val, 18, fill=(255, 80, 60) if ic == "ability_meleedamage" else (120, 190, 255), face=self.face, anchor="lm", outline=2)
        else: text(img, x + 8, top - 40, "?", 18, fill=(200, 150, 255), face=self.face, anchor="lm", outline=2)
        for i, (dic, n) in enumerate(debuffs): aura(img, x - 44 + i * 24, top + 30, dic, n, 18, self.face, debuff=True)

    def end_turn(self, img):
        self.button(img, 930, 556, 166, 44, "End Turn", 17, big=True)

    def tooltip(self, img, x, y, w, title, lines, tcol=WHITE):
        h = 24 + 16 * len(lines)
        tb = K.backdrop(P(w), P(h), "tooltip_border", 14, bgcol=(9, 9, 22, 236), inset=3)
        img.alpha_composite(tb, (P(x), P(y)))
        text(img, x + 10, y + 14, title, 13, fill=tcol, face=self.face)
        for i, l in enumerate(lines): text(img, x + 10, y + 31 + 16 * i, l, 11, fill=GOLD if i == 0 else WHITE, face=self.face)

    # ---------------- écrans
    def combat(self):
        img = new_canvas(); img.alpha_composite(K.background("elwynn", 50, 424, 0.12), (0, P(50)))
        self.unit_hero(img)
        for i, e in enumerate(ENEMIES): self.unit_enemy(img, e, target=(i == 0))
        float_text(img, 648, 210, "-9", 30, self.face, (255, 255, 0), (110, 0, 0))
        self.table(img); self.topbar(img, "Westfall")
        self.mana(img, 70, 484); self.piles(img)
        for key, cx in HAND:
            K.card(img, key, cx, 442, 108, glow=(key == "solace"), lift=26 if key == "solace" else 0)
        self.end_turn(img)
        self.frame(img)
        self.tooltip(img, 580, 350, 230, "Atonement", ["Lasts 1 turn.", "Your Atonement cards trigger", "their bonus while it lasts."], GOLD)
        return save(img, self.key, "combat")

    def path_bg(self, img):
        par = rs(K.piece("parch_achiev"), P(1000), P(548))
        img.alpha_composite(par, (P(20), P(62)))
        img.alpha_composite(K.backdrop(P(1012), P(560), "dialog_gold_border", 22), (P(14), P(56)))

    def path_node(self, img, n, x, y, typ, st):
        size = 30
        ic = icon(NODE_ICON[typ], size, round_=True, gray=(st in ("done", "far")))
        if typ == "elite":
            ic = K.disc(rs(K.piece("raid_skull"), P(size), P(size)))
            bg = Image.new("RGBA", ic.size, (40, 20, 20, 255)); bg = K.disc(bg); bg.alpha_composite(ic); ic = bg
            if st == "far": ic = K.grey(ic, 0.6)
        if st == "here":
            g = Image.new("RGBA", (P(80), P(80))); ImageDraw.Draw(g).ellipse((P(14), P(14), P(66), P(66)), fill=(255, 220, 80, 220))
            put(img, g.filter(ImageFilter.GaussianBlur(P(7))), x, y)
        put(img, ic, x, y)
        K.ring(img, x, y, size, gray=(st == "far"))

    def path(self):
        img = new_canvas(); self.bg_dark(img, 0, 620)
        self.path_bg(img)
        # traits à l'encre
        ink = Image.new("RGBA", img.size); d = ImageDraw.Draw(ink)
        for a, b in EDGES:
            st = edge_state(a, b); col = (90, 50, 20, 230) if st in ("done", "next") else (90, 60, 30, 120)
            for i, (px, py) in enumerate(line_pts(node_xy(a), node_xy(b), 9)[1:-1]):
                r = 2.6 if st in ("done", "next") else 2
                d.ellipse((P(px - r), P(py - r), P(px + r), P(py + r)), fill=col)
        img.alpha_composite(ink)
        for n, (c, y, typ, st) in NODES.items(): self.path_node(img, n, COLS[c], y, typ, st)
        # boss : anneau élite classique (dragon d'or) autour du portrait
        bx, by = BOSS
        put(img, K.disc(icon("achievement_boss_edwinvancleef", 58)), bx - 9, by + 1)
        put(img, rs(K.piece("elite_ring_classic"), P(106 * 1.05), P(100 * 1.05)), bx + 4, by + 5)
        text(img, bx - 6, by + 56, "Edwin VanCleef", 13, fill=GOLD, face=self.face, anchor="mm", outline=1.2)
        text(img, 70, 560, "Stop 3 of 9  ·  pick your next landing", 12.5, fill=(40, 22, 8), face=self.face, shadow=False)
        self.topbar(img, "Act 1 · Westfall", progress=False)
        self.frame(img, sections=(50,))
        self.tooltip(img, 470, 70, 250, "Elite: Riverpaw Taskmaster", ["Elite fight", "Harder than a normal fight.", "Reward: a trinket."], (163, 53, 238))
        return save(img, self.key, "parcours")

    def encounter(self):
        img = new_canvas(); img.alpha_composite(K.background("farm", 50, 620, 0.05), (0, P(50)))
        K.sil(img, "hero", 170, 560, 220)
        K.sil(img, "mystic", 900, 540, 200)
        text(img, 900, 316, "Salma Saldean", 12, fill=(255, 255, 0), face=self.face, anchor="mm", outline=1.3)
        # fenêtre de PNJ classique : 4 quarts (384 × 512), échelle 1.08
        k = 1.08; x0, y0 = 300, 58
        Q = Image.new("RGBA", (384, 512)); Q.alpha_composite(K.piece("quest_tl"), (0, 0)); Q.alpha_composite(K.piece("quest_tr"), (256, 0))
        Q.alpha_composite(K.piece("quest_bl"), (0, 256)); Q.alpha_composite(K.piece("quest_br"), (256, 256))
        Q = Q.crop((0, 0, 352, 440))
        put(img, K.disc(rs(K.piece("portrait_salma"), P(60 * k), P(60 * k))), x0 + 35 * k, y0 + 35 * k)
        put(img, rs(Q, P(352 * k), P(440 * k)), x0 + 176 * k, y0 + 220 * k)
        text(img, x0 + 205 * k, y0 + 26 * k, "The Saldean Farm", 13, fill=GOLD, face=self.face, anchor="mm")
        put(img, scaled("minimize_up", 30), x0 + 330 * k, y0 + 24 * k)
        body = "“You look starved, traveler. Come in, there's stew left! And if you have a moment, my husband could use help in the fields.”"
        y = y0 + 98 * k
        for l in wrap(body, 12.5, 270 * k, self.face):
            text(img, x0 + 36 * k, y, l, 12.5, fill=INK, face=self.face, shadow=False); y += 19
        y += 16
        opts = [("gossip_gossip", "Eat the stew", "+10 HP", (0, 120, 0)), ("gossip_quest", "Learn her recipe", "Choose 1 of 3 common cards", INK),
                ("gossip_binder", "Help farmer Saldean", "-5 HP, then +5 max HP", (150, 20, 10))]
        for i, (gi, lab, eff, ecol) in enumerate(opts):
            if i == 1:
                hl = Image.new("RGBA", (P(300 * k), P(36)), (255, 210, 60, 70)); img.alpha_composite(hl.filter(ImageFilter.GaussianBlur(P(2))), (P(x0 + 22 * k), P(y - 10)))
            put(img, scaled("gossip_" + gi.split("_")[1], 16), x0 + 44 * k, y)
            text(img, x0 + 58 * k, y, lab, 13, fill=(0, 0, 0), face=self.face, shadow=False)
            text(img, x0 + 58 * k, y + 16, eff, 11, fill=ecol, face=self.face, shadow=False)
            y += 44
        self.button(img, x0 + 270 * k, y0 + 412 * k, 96, 22, "Goodbye", 11)
        self.topbar(img, "Westfall")
        self.frame(img, sections=(50,))
        return save(img, self.key, "rencontre")

    def dialog(self, img, x, y, w, h, title):
        img.alpha_composite(K.backdrop(P(w), P(h), "dialog_border", 26, bg="dialog_bg_dark", bg_tile=S, bgcol=(6, 6, 8, 240)), (P(x), P(y)))
        self.header(img, x + w / 2, y + 4, max(170, tw(title, 14, self.face) + 120), title)

    def checkbox(self, img, x, y, label, on):
        put(img, scaled("checkbox_up", 26), x, y)
        if on: put(img, scaled("checkbox_check", 26), x, y)
        text(img, x + 16, y, label, 12, fill=WHITE if on else GREY, face=self.face)

    def slider(self, img, x, y, w, label, v, val):
        text(img, x, y - 16, label, 12, fill=GOLD, face=self.face)
        img.alpha_composite(K.backdrop(P(w), P(18), "slider_border", 8, bgcol=(0, 0, 0, 160), inset=3), (P(x), P(y - 9)))
        put(img, scaled("slider_thumb", 30), x + 8 + (w - 16) * v, y)
        text(img, x + w + 12, y, val, 12, fill=WHITE, face=self.face)

    def menu(self):
        img = Image.open(K.B / f"direction_{self.key}_combat.jpg").convert("RGBA"); dim(img)
        self.dialog(img, 196, 150, 236, 304, "Game Menu")
        for i, lab in enumerate(["Resume", "View Deck (24)", "Options", "How to Play", "Abandon Expedition"]):
            self.button(img, 314, 206 + i * 34, 184, 26, lab, 12)
        text(img, 314, 418, "Lands in 1:42 (Sentinel Hill)", 10.5, fill=GREY, face=self.face, anchor="mm")
        self.dialog(img, 470, 112, 380, 380, "Options")
        put(img, scaled("minimize_up", 30), 470 + 380 - 18, 112 + 18)
        for i, (lab, on) in enumerate([("Show keyword tooltips", True), ("Fast animations", True), ("Pause the run when the flight lands", False), ("Open automatically on takeoff", True)]):
            self.checkbox(img, 506, 160 + i * 32, lab, on)
        self.slider(img, 500, 320, 250, "Window scale", 0.5, "115%")
        self.slider(img, 500, 372, 250, "Card animation speed", 0.7, "Fast")
        self.button(img, 600, 448, 110, 24, "Defaults", 11); self.button(img, 730, 448, 110, 24, "Okay", 11)
        return save(img, self.key, "menu")


# ================================================================== DIRECTION B : moderne (Dragonflight / Midnight)
class B_(A):
    key = "B"; face = "baloo"; title_face = "baloo"
    label = "B · Moderne Dragonflight / Midnight"

    def metal(self, w, h):
        k = 0.5 * S
        return K.nine_parts(P(w), P(h), K.piece("metal_tl"), K.piece("metal_tr"), K.piece("metal_bl"), K.piece("metal_br"),
                            K.piece("metal_top"), K.piece("metal_bottom"), K.piece("metal_left"), K.piece("metal_right"), k)

    def frame(self, img, sections=(424,)):
        m = self.metal(1040 + 12, 620 + 8)        # bord gauche et haut transparents dans les coins métal (12 et ~16 points)
        img.alpha_composite(m.crop((P(12), P(8), P(12) + W, P(8) + H)))

    def bg_dark(self, img, y0, y1):
        t = K.tile(K.piece("bg_rock"), W, P(y1 - y0), 0.5 * S)
        img.alpha_composite(t, (0, P(y0)))

    def slot(self, img, cx, cy, size, ic=None, n=None, gray=False):
        put(img, rs(K.piece("df_iconslot"), P(size * 128 / 82), P(size * 124 / 82)), cx, cy)
        if ic: put(img, icon(ic, size * 0.9, gray=gray), cx, cy)
        put(img, rs(K.piece("df_iconframe"), P(size * 92 / 80), P(size * 90 / 80)), cx + size * 0.02, cy + size * 0.01)
        if n is not None: text(img, cx + size / 2 - 3, cy + size / 2 - 3, str(n), size * 0.42, fill=WHITE, face=self.face, anchor="rb", outline=1.4, w=800)

    def button(self, img, cx, cy, w, h, label, px=12, big=False):
        if big:
            b = K.three(K.piece("goldred_left"), K.piece("goldred_center"), K.piece("goldred_right"), P(w), P(h))
        else:
            b = K.three(K.piece("red128_left"), K.piece("red128_center"), K.piece("red128_right"), P(w), P(h))
        put(img, b, cx, cy)
        text(img, cx, cy + 0.5, label, px * 1.12, fill=GOLD, face=self.face, anchor="mm", w=700)

    def topbar(self, img, title, progress=True):
        """Barre de titre du cadre métal (dessinée après le cadre) : y ≈ 9..31."""
        ty = 20
        text(img, 520 if not progress else 470, ty, title, 14, fill=GOLD, face=self.face, anchor="mm", w=700)
        if progress:
            for i in range(8):
                put(img, scaled("essence" if i < 3 else "essence_off", 15 if i == 2 else 12), 530 + i * 15, ty)
        put(img, scaled("coin_gold", 14), 30, ty); text(img, 40, ty, "84", 13, fill=WHITE, face=self.face, w=700)
        put(img, icon("inv_misc_book_09", 15), 84, ty); text(img, 95, ty, "13", 13, fill=WHITE, face=self.face, w=700)
        put(img, scaled("red_exit", 22), 1018, ty - 1)
        self.button(img, 966, ty, 66, 20, "Menu", 10.5)

    def table(self, img):
        t = K.tile(K.piece("df_bg"), W, P(196), 0.5 * S)
        img.alpha_composite(t, (0, P(424)))
        bar = K.tile_strip(rs(K.piece("metal_bottom"), P(16), P(32)), W)
        img.alpha_composite(bar, (0, P(424 - 14)))

    def mana(self, img, cx, cy):
        g = Image.new("RGBA", (P(110), P(80))); ImageDraw.Draw(g).ellipse((P(20), P(10), P(90), P(70)), fill=(40, 120, 255, 150))
        put(img, g.filter(ImageFilter.GaussianBlur(P(12))), cx, cy - 6)
        text(img, cx - 6, cy - 6, "2", 40, fill=WHITE, face=self.face, anchor="mm", w=800, outline=2, ocol=(10, 30, 80))
        text(img, cx + 18, cy + 2, "/3", 18, fill=(200, 225, 255), face=self.face, anchor="mm", w=800, outline=1.5, ocol=(10, 30, 80))
        for i in range(3):
            put(img, scaled("essence" if i < 2 else "essence_off", 22), cx - 24 + i * 24, cy + 32)

    def piles(self, img):
        for cx, ic, n, lab in [(146, "inv_misc_book_09", 7, "Draw"), (194, "inv_misc_bag_10", 3, "Discard")]:
            self.slot(img, cx, 560, 38, ic, n); text(img, cx, 590, lab, 11, fill=GOLD, face=self.face, anchor="mm", w=700)

    def unit_hero(self, img):
        k = 0.5; x0, y0 = 14, 56
        fr = rs(K.piece("df_player"), P(396 * k), P(142 * k))
        hp = rs(K.piece("df_player_hp"), P(248 * k), P(40 * k)); mana = rs(K.piece("df_player_mana"), P(248 * k), P(20 * k))
        ImageDraw.Draw(img).rectangle((P(x0 + 64 * k), P(y0 + 22 * k), P(x0 + 386 * k), P(y0 + 117 * k)), fill=(0, 0, 0, 170))
        img.alpha_composite(hp.crop((0, 0, round(hp.width * 52 / 65), hp.height)), (P(x0 + 135 * k), P(y0 + 52 * k)))
        img.alpha_composite(mana.crop((0, 0, round(mana.width * 2 / 3), mana.height)), (P(x0 + 135 * k), P(y0 + 94 * k)))
        put(img, K.disc(rs(K.piece("portrait_hero"), P(98 * k), P(98 * k))), x0 + 72 * k, y0 + 68 * k)
        img.alpha_composite(fr, (P(x0), P(y0)))
        text(img, x0 + 150 * k, y0 + 35 * k, "Priest", 11, fill=GOLD, face=self.face, w=700)
        text(img, x0 + 260 * k, y0 + 72 * k, "52 / 65", 10, fill=WHITE, face=self.face, anchor="mm", outline=1, w=700)
        text(img, x0 + 260 * k, y0 + 105 * k, "2 / 3", 8.5, fill=WHITE, face=self.face, anchor="mm", outline=1, w=700)
        for i, (ic, n) in enumerate([("spell_holy_powerwordshield", 8), ("ability_priest_atonement", 2), ("spell_holy_renew", 3)]):
            aura(img, x0 + 82 + i * 26, y0 + 82, ic, n, 21, self.face)
        K.sil(img, "hero", 190, 330, 190)
        ellipse_ring(img, 190, 330, 52, 11, (40, 220, 40, 230))

    def unit_enemy(self, img, e, target=False):
        name, kind, x, foot, hp, mx, (ic, val), debuffs = e
        if target: ellipse_ring(img, x, foot, 58, 12, (255, 220, 0, 240))
        K.sil(img, kind, x, foot, 158)
        k = 0.5 * 1.0; fw, fh = 230 * k, 112 * k
        fx, fy = x - 46, foot - 214
        fr = rs(K.piece("df_boss_small"), P(fw), P(fh))
        bar = rs(K.piece("df_boss_hp"), P(170 * k), P(20 * k))
        ImageDraw.Draw(img).rectangle((P(fx + 5 * k), P(fy + 18 * k), P(fx + 176 * k), P(fy + 87 * k)), fill=(0, 0, 0, 170))
        img.alpha_composite(bar.crop((0, 0, max(1, round(bar.width * hp / mx)), bar.height)), (P(fx + 5 * k), P(fy + 47 * k)))
        img.alpha_composite(fr, (P(fx), P(fy)))
        text(img, fx + 90 * k, fy + 32 * k, name, 10.5, fill=(255, 240, 0) if target else WHITE, face=self.face, anchor="mm", w=700)
        text(img, fx + 90 * k, fy + 57.5 * k, f"{hp} / {mx}", 8.5, fill=WHITE, face=self.face, anchor="mm", outline=1, w=700)
        self.slot(img, fx + 20, fy + 70, 24, ic)
        col = (255, 80, 60) if ic == "ability_meleedamage" else ((120, 190, 255) if val else (200, 150, 255))
        text(img, fx + 38, fy + 70, val or "?", 19, fill=col, face=self.face, anchor="lm", outline=2, w=800)
        for i, (dic, n) in enumerate(debuffs): aura(img, x - 40 + i * 24, foot + 18, dic, n, 20, self.face, debuff=True)

    def tooltip(self, img, x, y, w, title, lines, tcol=WHITE):
        h = 26 + 16 * len(lines)
        c = K.piece("tooltip9_corners"); s = K.piece("tooltip9_sides")
        tl = c.crop((0, 0, 8, 8)); bg = Image.new("RGBA", (P(w), P(h))); ImageDraw.Draw(bg).rounded_rectangle((P(2), P(2), P(w) - P(2), P(h) - P(2)), P(3), fill=(8, 10, 14, 240))
        img.alpha_composite(bg, (P(x), P(y)))
        nine = K.nine_cut(c.crop((0, 0, 16, 16)), 7, 7, 7, 7, P(w), P(h), k=S, center=False) if False else None
        d = ImageDraw.Draw(img); d.rounded_rectangle((P(x), P(y), P(x + w), P(y + h)), P(4), outline=(120, 120, 128, 255), width=P(1.2))
        text(img, x + 10, y + 15, title, 13.5, fill=tcol, face=self.face, w=700)
        for i, l in enumerate(lines): text(img, x + 10, y + 33 + 16 * i, l, 11.5, fill=GOLD if i == 0 else WHITE, face=self.face, w=600)
        USED.setdefault("B", set()).update({"tooltip9_corners", "tooltip9_sides"})

    def end_turn(self, img):
        self.button(img, 928, 556, 176, 46, "End Turn", 17, big=True)

    def combat(self):
        img = new_canvas(); self.bg_dark(img, 0, 620); img.alpha_composite(K.background("elwynn", 30, 424, 0.12), (0, P(30)))
        self.unit_hero(img)
        for i, e in enumerate(ENEMIES): self.unit_enemy(img, e, target=(i == 0))
        float_text(img, 648, 214, "-9", 32, self.face, (255, 255, 0), (110, 0, 0))
        for i, ic in enumerate(TRINKETS): self.slot(img, 820 + i * 34, 64, 28, ic)
        for i, ic in enumerate(POTIONS): self.slot(img, 906 + i * 34, 64, 28, ic)
        self.table(img)
        self.mana(img, 70, 486); self.piles(img)
        for key, cx in HAND:
            K.card(img, key, cx, 442, 108, glow=(key == "solace"), lift=26 if key == "solace" else 0)
        self.end_turn(img)
        self.frame(img); self.topbar(img, "Westfall")
        self.tooltip(img, 580, 350, 230, "Atonement", ["Lasts 1 turn.", "Your Atonement cards trigger", "their bonus while it lasts."], GOLD)
        return save(img, self.key, "combat")

    def path_node(self, img, n, x, y, typ, st):
        fam = {"elite": "square", "event": "choice"}.get(typ, "circle")
        colr = {"done": "yellow", "here": "yellow", "next": "green", "open": "gray", "far": "gray"}[st]
        size = {"circle": 38, "square": 40, "choice": 42}[fam]
        ic = icon(NODE_ICON[typ], size * 0.78, round_=(fam == "circle"), gray=(st == "far"))
        if fam == "choice":
            m = Image.new("L", ic.size, 0); w_ = ic.width; c = w_ * 0.29
            ImageDraw.Draw(m).polygon([(c, 0), (w_ - c, 0), (w_, c), (w_, w_ - c), (w_ - c, w_), (c, w_), (0, w_ - c), (0, c)], fill=255); ic.putalpha(m)
        if st == "here":
            g = Image.new("RGBA", (P(90), P(90))); ImageDraw.Draw(g).ellipse((P(16), P(16), P(74), P(74)), fill=(255, 200, 60, 230))
            put(img, g.filter(ImageFilter.GaussianBlur(P(8))), x, y)
        put(img, ic, x, y)
        fr = scaled(f"talent_{fam}_{colr}", size * (1.32 if fam == "choice" else 1.16))
        if st == "far": fr = K.alpha(fr, 0.55)
        put(img, fr, x, y)

    def path(self):
        img = new_canvas()
        bg = rs(K.piece("talents_bg_disc"), P(1230), P(1230 * 774 / 1612))
        img.alpha_composite(bg.crop((P(150), 0, P(150) + W, P(590))), (0, P(30)))
        img.alpha_composite(Image.new("RGBA", (W, P(590)), (0, 0, 0, 60)), (0, P(30)))
        for a, b in EDGES:
            st = edge_state(a, b)
            strip = K.piece("talent_line_yellow" if st in ("done", "next") else "talent_line_gray").transpose(Image.ROTATE_90)
            if st == "far": strip = K.alpha(strip, 0.45)
            strip_along(img, node_xy(a), node_xy(b), strip, 9 if st in ("done", "next") else 7)
        for n, (c, y, typ, st) in NODES.items(): self.path_node(img, n, COLS[c], y, typ, st)
        bx, by = BOSS
        put(img, K.disc(icon("achievement_boss_edwinvancleef", 64)), bx, by + 6)
        put(img, rs(K.piece("boss_winged"), P(198 * 0.5), P(162 * 0.5)), bx + 6, by)
        text(img, bx, by + 58, "Edwin VanCleef", 14, fill=GOLD, face=self.face, anchor="mm", w=700, outline=1.2)
        self.frame(img); self.topbar(img, "Act 1 · Westfall", progress=False)
        self.tooltip(img, 470, 76, 250, "Elite: Riverpaw Taskmaster", ["Elite fight", "Harder than a normal fight.", "Reward: a trinket."], (163, 53, 238))
        return save(img, self.key, "parcours")

    def encounter(self):
        img = new_canvas(); self.bg_dark(img, 0, 620); img.alpha_composite(K.background("farm", 30, 424, 0.05), (0, P(30)))
        K.sil(img, "hero", 190, 360, 210)
        K.sil(img, "mystic", 860, 350, 190)
        text(img, 860, 140, "Salma Saldean", 12, fill=(255, 255, 0), face=self.face, anchor="mm", outline=1.3, w=700)
        # bulle : parchemin Dragonflight en neuf tranches
        par = K.nine_cut(K.piece("df_parch_wide"), 60, 50, 60, 50, P(440), P(118), k=0.45 * S)
        put_sh(img, par, 520, 140)
        text(img, 520, 100, "The Saldean Farm", 15, fill=INK, face=self.face, anchor="mm", w=800, shadow=False)
        body = "“You look starved, traveler. Come in, there's stew left! And if you have a moment, my husband could use help in the fields.”"
        y = 126
        for l in wrap(body, 12.5, 370, self.face, 600):
            text(img, 520, y, l, 12.5, fill=INK, face=self.face, anchor="mm", shadow=False, w=600); y += 18
        self.table(img)
        opts = [("Eat the stew", "+10 HP", (30, 255, 32)), ("Learn her recipe", "Choose 1 of 3 common cards", WHITE),
                ("Help farmer Saldean", "-5 HP, then +5 max HP", (255, 120, 100))]
        for i, (lab, eff, ecol) in enumerate(opts):
            cx = 200 + i * 320
            self.button(img, cx, 492, 270, 52, lab, 15, big=(i == 1))
            text(img, cx, 532, eff, 13, fill=ecol, face=self.face, anchor="mm", w=700)
        self.frame(img); self.topbar(img, "Westfall")
        return save(img, self.key, "rencontre")

    def dialog(self, img, x, y, w, h, title):
        k = 0.5 * S
        bg = K.tile(K.piece("bg_rock"), P(w - 12), P(h - 12), 0.5 * S); img.alpha_composite(bg, (P(x + 6), P(y + 6)))
        fr = K.nine_parts(P(w), P(h), K.piece("diamond_tl"), K.piece("diamond_tr"), K.piece("diamond_bl"), K.piece("diamond_br"),
                          K.piece("diamond_top"), K.piece("diamond_bottom"), K.piece("diamond_left"), K.piece("diamond_right"), 0.25 * S)
        img.alpha_composite(fr, (P(x), P(y)))
        hw = max(180, tw(title, 14, self.face, 700) + 90)
        hd = K.three(K.piece("diamond_hdr_l"), K.piece("diamond_hdr_m"), K.piece("diamond_hdr_r"), P(hw), P(39))
        put(img, hd, x + w / 2, y + 2)
        text(img, x + w / 2, y + 1, title, 14, fill=GOLD, face=self.face, anchor="mm", w=700)

    def checkbox(self, img, x, y, label, on):
        put(img, scaled("checkbox_min", 24), x, y)
        if on: put(img, scaled("checkbox_check", 24), x + 1, y - 1)
        text(img, x + 18, y, label, 12.5, fill=WHITE if on else GREY, face=self.face, w=600)

    def slider(self, img, x, y, w, label, v, val):
        text(img, x, y - 16, label, 12.5, fill=GOLD, face=self.face, w=700)
        put(img, K.three(K.piece("min_slider_l"), K.piece("min_slider_m"), K.piece("min_slider_r"), P(w), P(17)), x + w / 2, y)
        put(img, scaled("min_slider_thumb", 20), x + 8 + (w - 16) * v, y)
        text(img, x + w + 12, y, val, 12.5, fill=WHITE, face=self.face, w=700)

    def menu(self):
        img = Image.open(K.B / f"direction_{self.key}_combat.jpg").convert("RGBA"); dim(img)
        self.dialog(img, 196, 150, 236, 304, "Game Menu")
        for i, lab in enumerate(["Resume", "View Deck (24)", "Options", "How to Play", "Abandon Expedition"]):
            self.button(img, 314, 206 + i * 34, 190, 28, lab, 12)
        text(img, 314, 420, "Lands in 1:42 (Sentinel Hill)", 11, fill=GREY, face=self.face, anchor="mm", w=600)
        self.dialog(img, 470, 112, 380, 380, "Options")
        put(img, scaled("red_exit", 22), 470 + 380 - 22, 112 + 22)
        for i, (lab, on) in enumerate([("Show keyword tooltips", True), ("Fast animations", True), ("Pause the run when the flight lands", False), ("Open automatically on takeoff", True)]):
            self.checkbox(img, 506, 166 + i * 32, lab, on)
        self.slider(img, 500, 326, 250, "Window scale", 0.5, "115%")
        self.slider(img, 500, 378, 250, "Card animation speed", 0.7, "Fast")
        self.button(img, 600, 448, 110, 26, "Defaults", 11); self.button(img, 730, 448, 110, 26, "Okay", 11)
        return save(img, self.key, "menu")


# ================================================================== DIRECTION C : carte de vol (bois, bronze, parchemin)
class C_(A):
    key = "C"; face = "friz"; title_face = "morpheus"
    label = "C · Carte de vol (bois, bronze, parchemin)"

    def neutral(self, w, h, k=0.36):
        c = K.piece("neutral_corner")
        return K.nine_parts(P(w), P(h), c, c.transpose(Image.FLIP_LEFT_RIGHT), c.transpose(Image.FLIP_TOP_BOTTOM), c.transpose(Image.ROTATE_180),
                            K.piece("neutral_top"), K.piece("neutral_bottom"), K.piece("neutral_left"), K.piece("neutral_right"), k * S)

    def frame(self, img, sections=(50, 424)):
        for y in sections:
            if y is None: continue
            strip = K.tile_strip(rs(K.piece("neutral_top"), P(256 * 0.36), P(30 * 0.36)), W)
            img.alpha_composite(strip, (0, P(y - 5)))
        img.alpha_composite(self.neutral(1040, 620))

    def bg_dark(self, img, y0, y1):
        t = K.tile(K.piece("neutral_bg"), W, P(y1 - y0), 0.5 * S)
        img.alpha_composite(t, (0, P(y0)))

    def slot(self, img, cx, cy, size, ic=None, n=None, gray=False):
        if ic: put(img, icon(ic, size * 0.86, round_=True, gray=gray), cx, cy)
        else:
            g = Image.new("RGBA", (P(size), P(size))); ImageDraw.Draw(g).ellipse((0, 0, P(size) - 1, P(size) - 1), fill=(20, 12, 6, 200)); put(img, g, cx, cy)
        K.ring(img, cx, cy, size * 0.9)
        if n is not None: text(img, cx + size / 2, cy + size / 2, str(n), 12, fill=WHITE, face=self.face, anchor="rb", outline=1.4)

    def button(self, img, cx, cy, w, h, label, px=12, big=False):
        b = K.three(K.piece("goldred_left"), K.piece("goldred_center"), K.piece("goldred_right"), P(w), P(h))
        put(img, b, cx, cy)
        text(img, cx, cy + 0.5, label, px, fill=GOLD, face=self.face, anchor="mm")

    def header(self, img, cx, y, w, title, px=16):
        hd = K.three(K.piece("neutral_title_l"), K.piece("neutral_title_m"), K.piece("neutral_title_r"), P(w), P(46))
        put(img, hd, cx, y + 4)
        text(img, cx, y - 1, title, px, fill=GOLD, face=self.title_face, anchor="mm")

    def topbar(self, img, title, progress=True):
        self.bg_dark(img, 0, 50)
        img.alpha_composite(Image.new("RGBA", (W, P(50)), (0, 0, 0, 60)))
        text(img, 26, 26, "Priest", 15, fill=GOLD, face=self.face)
        text(img, 88, 26, "HP", 12, fill=GOLD, face=self.face); text(img, 110, 26, "52/65", 13, fill=(255, 120, 110), face=self.face)
        put(img, scaled("gold_icon", 14), 168, 26); text(img, 178, 26, "84", 13, fill=WHITE, face=self.face)
        self.slot(img, 222, 26, 20, "inv_misc_book_09"); text(img, 236, 26, "13", 13, fill=WHITE, face=self.face)
        self.header(img, 520, 20 if progress else 22, 280, title)
        if progress:
            # mini-trajet : bottes ailées et pointillés de taxi
            for i in range(8):
                x = 456 + i * 18.3
                nm = "taxi_frame_green" if i < 2 else ("taxi_frame_yellow" if i == 2 else "taxi_frame_gray")
                put(img, scaled(nm, 13 if i != 2 else 16), x, 34)
        for i, ic in enumerate(TRINKETS): self.slot(img, 708 + i * 32, 26, 24, ic)
        for i, ic in enumerate(POTIONS): self.slot(img, 782 + i * 32, 26, 24, ic)
        self.button(img, 916, 26, 70, 24, "Menu", 11)
        put(img, scaled("minimize_up", 30), 1006, 25)

    def table(self, img):
        t = K.tile(K.piece("neutral_bg"), W, P(196), 0.5 * S)
        img.alpha_composite(t, (0, P(424)))

    def mana(self, img, cx, cy):
        put(img, icon("inv_elemental_mote_mana", 54, round_=True), cx, cy - 4)
        K.ring(img, cx, cy - 4, 54)
        text(img, cx, cy - 4, "2/3", 22, fill=WHITE, face=self.face, anchor="mm", outline=2.2)
        put(img, K.three_cut(K.piece("neutral_subtitle"), 40, 40, P(70), P(16)), cx, cy + 40)
        text(img, cx, cy + 40, "Mana", 11, fill=GOLD, face=self.face, anchor="mm")

    def piles(self, img):
        for cx, ic, n, lab in [(146, "inv_misc_book_09", 7, "Draw"), (194, "inv_misc_bag_10", 3, "Discard")]:
            self.slot(img, cx, 560, 34, ic, n); text(img, cx, 590, lab, 10, fill=GOLD, face=self.face, anchor="mm")

    def plate(self, img, x, y, w, name, hp, mx, target=False, rgb=(220, 30, 20), bar=True):
        """Plaque de nom bronze + barre de vie de la table de commandement."""
        put(img, K.three_cut(K.piece("neutral_subtitle"), 40, 40, P(w), P(20)), x, y)
        text(img, x, y + 0.5, name, 11, fill=(255, 240, 0) if target else WHITE, face=self.face, anchor="mm")
        if not bar: return
        hb = K.piece("adv_healthbar")
        frame = K.three_cut(hb, 22, 22, P(w - 12), P(18))
        fill = bar_fill(P(w - 34), P(8), rgb)
        img.alpha_composite(fill.crop((0, 0, max(1, round(fill.width * hp / mx)), fill.height)), (P(x - (w - 34) / 2), P(y + 18)))
        put(img, frame, x, y + 22)
        text(img, x, y + 22, f"{hp} / {mx}", 9.5, fill=WHITE, face=self.face, anchor="mm", outline=1.2)

    def unit_hero(self, img):
        K.sil(img, "hero", 190, 330, 190)
        ellipse_ring(img, 190, 330, 52, 11, (40, 220, 40, 230))
        self.plate(img, 190, 352, 150, "Priest", 52, 65, rgb=(40, 200, 40))
        for i, (ic, n) in enumerate([("spell_holy_powerwordshield", 8), ("ability_priest_atonement", 2), ("spell_holy_renew", 3)]):
            self.slot(img, 150 + i * 40, 402, 22, ic); text(img, 150 + i * 40 + 13, 410, str(n), 11, fill=WHITE, face=self.face, anchor="mm", outline=1.4)

    def unit_enemy(self, img, e, target=False):
        name, kind, x, foot, hp, mx, (ic, val), debuffs = e
        if target: ellipse_ring(img, x, foot, 58, 12, (255, 220, 0, 240))
        K.sil(img, kind, x, foot, 158)
        self.plate(img, x, foot + 22, 140, name, hp, mx, target)
        top = foot - 150
        self.slot(img, x - 12, top - 14, 28, ic)
        col = (255, 80, 60) if ic == "ability_meleedamage" else ((120, 190, 255) if val else (200, 150, 255))
        text(img, x + 10, top - 14, val or "?", 19, fill=col, face=self.face, anchor="lm", outline=2)
        for i, (dic, n) in enumerate(debuffs):
            self.slot(img, x + 86, foot + 24, 20, dic); text(img, x + 96, foot + 32, str(n), 10, fill=WHITE, face=self.face, anchor="mm", outline=1.3)

    def tooltip(self, img, x, y, w, title, lines, tcol=WHITE):
        h = 30 + 16 * len(lines)
        par = K.nine_cut(K.piece("neutral_parch"), 40, 40, 40, 40, P(w), P(h), k=0.35 * S)
        put_sh(img, par, x + w / 2, y + h / 2, 3, 2)
        text(img, x + 14, y + 17, title, 14, fill=INK, face=self.title_face, shadow=False)
        for i, l in enumerate(lines): text(img, x + 14, y + 34 + 16 * i, l, 11, fill=(120, 70, 10) if i == 0 else INK, face=self.face, shadow=False)

    def end_turn(self, img):
        self.button(img, 930, 556, 170, 46, "End Turn", 17, big=True)

    def combat(self):
        img = new_canvas(); img.alpha_composite(K.background("elwynn", 50, 424, 0.12), (0, P(50)))
        self.unit_hero(img)
        for i, e in enumerate(ENEMIES): self.unit_enemy(img, e, target=(i == 0))
        float_text(img, 648, 210, "-9", 30, self.face, (255, 255, 0), (110, 0, 0))
        self.table(img); self.topbar(img, "Westfall")
        self.mana(img, 70, 486); self.piles(img)
        for key, cx in HAND:
            K.card(img, key, cx, 442, 108, glow=(key == "solace"), lift=26 if key == "solace" else 0)
        self.end_turn(img)
        self.frame(img)
        self.tooltip(img, 300, 250, 236, "Atonement", ["Lasts 1 turn.", "Your Atonement cards trigger", "their bonus while it lasts."], (120, 40, 140))
        return save(img, self.key, "combat")

    def path_node(self, img, n, x, y, typ, st):
        if typ == "elite":
            im = scaled("vignettekillelite", 50)
        else:
            im = Image.new("RGBA", (P(50), P(50))); K.ring(im, 25, 25, 30)
            im.alpha_composite(icon(NODE_ICON[typ], 30, round_=True), (P(10), P(10))); K.ring(im, 25, 25, 30)
        if st in ("done",): im = K.grey(im, 0.75)
        if st == "far": im = K.alpha(K.grey(im, 0.7), 0.6)
        put(img, im, x, y)
        if st == "here":
            put_sh(img, scaled("taxi_frame_yellow", 44), x + 2, y - 34, 2, 2)

    def path(self):
        img = new_canvas(); self.bg_dark(img, 0, 620)
        par = K.nine_cut(K.piece("neutral_parch_wide"), 70, 60, 70, 60, P(1000), P(548), k=0.5 * S)
        img.alpha_composite(par, (P(20), P(60)))
        for a, b in EDGES:
            st = edge_state(a, b)
            strip = K.piece("taxi_line")
            if st == "far": strip = K.alpha(strip, 0.4)
            elif st == "open": strip = K.alpha(strip, 0.75)
            strip_along(img, node_xy(a), node_xy(b), strip, 34 if st in ("done", "next") else 26, inset=0)
        for n, (c, y, typ, st) in NODES.items(): self.path_node(img, n, COLS[c], y, typ, st)
        bx, by = BOSS
        put(img, K.disc(icon("achievement_boss_edwinvancleef", 62)), bx, by)
        K.ring(img, bx, by, 62)
        put(img, scaled("elite_gold", 50), bx + 34, by - 30)
        put(img, K.three_cut(K.piece("neutral_ribbon"), 70, 70, P(180), P(54)), bx, by + 62)
        text(img, bx, by + 58, "Edwin VanCleef", 14, fill=INK, face=self.title_face, anchor="mm", shadow=False)
        text(img, 60, 586, "Flight path: Westfall  ·  3 of 9 stops", 12, fill=INK, face=self.face, shadow=False)
        self.topbar(img, "Act 1 · Westfall", progress=False)
        self.frame(img, sections=(50,))
        self.tooltip(img, 470, 70, 250, "Elite: Riverpaw Taskmaster", ["Elite fight", "Harder than a normal fight.", "Reward: a trinket."], (120, 40, 140))
        return save(img, self.key, "parcours")

    def encounter(self):
        img = new_canvas(); img.alpha_composite(K.background("farm", 50, 424, 0.05), (0, P(50)))
        K.sil(img, "hero", 190, 360, 210)
        K.sil(img, "mystic", 860, 350, 190)
        self.plate(img, 860, 372, 150, "Salma Saldean", 1, 1, bar=False)
        par = K.nine_cut(K.piece("neutral_parch_wide"), 70, 60, 70, 60, P(440), P(124), k=0.36 * S)
        put_sh(img, par, 520, 146)
        put(img, K.three_cut(K.piece("neutral_ribbon"), 70, 70, P(250), P(60)), 520, 88)
        text(img, 520, 84, "The Saldean Farm", 16, fill=INK, face=self.title_face, anchor="mm", shadow=False)
        body = "“You look starved, traveler. Come in, there's stew left! And if you have a moment, my husband could use help in the fields.”"
        y = 130
        for l in wrap(body, 12.5, 370, self.face):
            text(img, 520, y, l, 12.5, fill=INK, face=self.face, anchor="mm", shadow=False); y += 19
        self.table(img); self.topbar(img, "Westfall")
        opts = [("gossip_gossip", "Eat the stew", "+10 HP", (0, 110, 0)), ("gossip_quest", "Learn her recipe", "Choose 1 of 3 common cards", INK),
                ("gossip_binder", "Help farmer Saldean", "-5 HP, then +5 max HP", (150, 20, 10))]
        for i, (gi, lab, eff, ecol) in enumerate(opts):
            cx = 190 + i * 330
            par = K.nine_cut(K.piece("neutral_parch_wide"), 70, 60, 70, 60, P(300), P(110), k=0.3 * S)
            put_sh(img, par, cx, 512)
            if i == 1:
                g = Image.new("RGBA", (P(320), P(128))); ImageDraw.Draw(g).rounded_rectangle((P(8), P(8), P(312), P(120)), P(14), outline=(255, 214, 80, 255), width=P(4))
                put(img, g.filter(ImageFilter.GaussianBlur(P(3))), cx, 512)
            put(img, scaled(gi, 18), cx - tw(lab, 15, self.face) / 2 - 14, 496)
            text(img, cx + 6, 496, lab, 15, fill=(30, 18, 6), face=self.face, anchor="mm", shadow=False)
            text(img, cx, 524, eff, 12.5, fill=ecol, face=self.face, anchor="mm", shadow=False)
        self.frame(img)
        return save(img, self.key, "rencontre")

    def dialog(self, img, x, y, w, h, title):
        bg = K.tile(K.piece("neutral_bg"), P(w - 10), P(h - 10), 0.5 * S); img.alpha_composite(bg, (P(x + 5), P(y + 5)))
        img.alpha_composite(self.neutral(w, h, 0.3), (P(x), P(y)))
        self.header(img, x + w / 2, y + 2, max(190, tw(title, 16, self.title_face) + 120), title)

    def checkbox(self, img, x, y, label, on):
        put(img, scaled("checkbox_up", 26), x, y)
        if on: put(img, scaled("checkbox_check", 26), x, y)
        text(img, x + 16, y, label, 12, fill=WHITE if on else GREY, face=self.face)

    def menu(self):
        img = Image.open(K.B / f"direction_{self.key}_parcours.jpg").convert("RGBA"); dim(img)
        self.dialog(img, 196, 150, 236, 304, "Game Menu")
        for i, lab in enumerate(["Resume", "View Deck (24)", "Options", "How to Play", "Abandon Expedition"]):
            self.button(img, 314, 210 + i * 34, 184, 28, lab, 12)
        text(img, 314, 424, "Lands in 1:42 (Sentinel Hill)", 10.5, fill=GREY, face=self.face, anchor="mm")
        self.dialog(img, 470, 112, 380, 380, "Options")
        put(img, scaled("minimize_up", 30), 470 + 380 - 22, 112 + 22)
        for i, (lab, on) in enumerate([("Show keyword tooltips", True), ("Fast animations", True), ("Pause the run when the flight lands", False), ("Open automatically on takeoff", True)]):
            self.checkbox(img, 506, 166 + i * 32, lab, on)
        self.slider(img, 500, 326, 250, "Window scale", 0.5, "115%")
        self.slider(img, 500, 378, 250, "Card animation speed", 0.7, "Fast")
        self.button(img, 600, 448, 110, 26, "Defaults", 11); self.button(img, 730, 448, 110, 26, "Okay", 11)
        return save(img, self.key, "menu")


THEMES = {"A": A, "B": B_, "C": C_}


def comparatif(keys):
    from PIL import ImageFont
    cw = 760; ch = round(cw * 620 / 1040); pad = 24
    screens = ["combat", "parcours", "rencontre", "menu"]
    out = Image.new("RGB", (pad + len(keys) * (cw + pad), 70 + len(screens) * (ch + pad) + 90), (24, 26, 30))
    d = ImageDraw.Draw(out)
    ft = ImageFont.truetype(str(K.FONTS["friz"]), 30); fs = ImageFont.truetype(str(K.FONTS["friz"]), 17)
    notes = {
        "A": ["Cadres pierre (DialogBox), boutons rouges, cases de barre d'action, plaques de nom,",
              "fenêtre de PNJ parchemin. Friz Quadrata. Textures 2004 : petites, à garder à l'échelle 1."],
        "B": ["Cadre métal des fenêtres actuelles, cadres d'unité Dragonflight, arbre de talents",
              "pour le parcours, boutons rouges HD. Baloo (police de l'addon). Atlas -2x : nets."],
        "C": ["Bois et bronze « Neutral », parchemins brûlés, bottes ailées et pointillés de taxi,",
              "pastilles de carte, traits de taxi. Friz + Morpheus. Le plus « vol », le plus chargé."],
    }
    for i, k in enumerate(keys):
        x = pad + i * (cw + pad)
        d.text((x, 18), THEMES[k].label, font=ft, fill=(255, 209, 0))
        for j, s in enumerate(screens):
            p = K.B / f"direction_{k}_{s}.jpg"
            if p.exists(): out.paste(Image.open(p).convert("RGB").resize((cw, ch), Image.LANCZOS), (x, 70 + j * (ch + pad)))
        yb = 70 + len(screens) * (ch + pad)
        for li, l in enumerate(notes[k]): d.text((x, yb + li * 24), l, font=fs, fill=(220, 224, 230))
    out.save(K.B / "comparatif.jpg", quality=86)


def main():
    keys = [a for a in sys.argv[1:] if a in THEMES] or list(THEMES)
    for k in keys:
        K.piece = track(k)
        t = THEMES[k]()
        for s in ("combat", "path", "encounter", "menu"):
            p = getattr(t, s)(); print(p)
        K.piece = _piece
    up = K.B / "used.json"
    old = json.loads(up.read_text()) if up.exists() else {}
    old.update({k: sorted(v) for k, v in USED.items()})
    up.write_text(json.dumps(old, indent=1))
    comparatif([k for k in THEMES if (K.B / f"direction_{k}_combat.jpg").exists()])


if __name__ == "__main__":
    main()
