#!/usr/bin/env python3
"""Deuxième passe du design précis : icônes du jeu, formes épaisses et tactiles.
Usage : gen2.py <dossier project> <dossier des icônes .jpg>"""
import sys, base64, pathlib

HERE = pathlib.Path(__file__).parent
ICONS = pathlib.Path(sys.argv[2])
src = (HERE / "gen.py").read_text()
exec(src[:src.index('(OUT / "CombatFinal')])  # reprend DEFS, SCENE, HERO, page, table, pile, relic…

FT = "font-family=\"Vollkorn, serif\" font-weight=\"800\""
FT6 = "font-family=\"Vollkorn, serif\" font-weight=\"700\""
OUTL = 'stroke="#140c07" stroke-linejoin="round" paint-order="stroke"'
page_v1 = page


def page(title, body):
    return page_v1(title, body).replace("family=Cinzel:wght@600;700", "family=Vollkorn:wght@700;800")


def icon_defs():
    out = []
    for f in sorted(ICONS.glob("*.jpg")):
        b = base64.b64encode(f.read_bytes()).decode()
        out.append(f'<image id="ic_{f.stem}" width="56" height="56" preserveAspectRatio="none" href="data:image/jpeg;base64,{b}"/>')
    return "\n".join(out)


EXTRA = """
<clipPath id="cArch"><path d="M25 87 V49 A37 37 0 0 1 99 49 V87Z"/></clipPath>
<clipPath id="cTok"><circle r="10.5"/></clipPath>
<clipPath id="cInt"><circle r="10"/></clipPath>
<clipPath id="cSq"><rect x="3" y="3" width="22" height="22" rx="3.5"/></clipPath>
<path id="namePath" d="M10 100.5 Q62 91.5 114 100.5"/>
<linearGradient id="stone" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f7f1e0"/><stop offset="0.5" stop-color="#ddd3ba"/><stop offset="1" stop-color="#b3a78c"/></linearGradient>
<linearGradient id="banner" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8a5a34"/><stop offset="0.5" stop-color="#6a4226"/><stop offset="1" stop-color="#3e2413"/></linearGradient>
<linearGradient id="textbox" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#e2cc98"/><stop offset="0.15" stop-color="#f5e6bf"/><stop offset="1" stop-color="#ead7a6"/></linearGradient>
<linearGradient id="crystal" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#9fd6ff"/><stop offset="0.45" stop-color="#2f7fe0"/><stop offset="1" stop-color="#0f2f78"/></linearGradient>
<linearGradient id="crystalOff" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffb3a3"/><stop offset="0.45" stop-color="#b53a28"/><stop offset="1" stop-color="#4a120a"/></linearGradient>
<linearGradient id="crystalEmpty" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#4a4f5c"/><stop offset="1" stop-color="#1a1d26"/></linearGradient>
<linearGradient id="crystalVoid" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#e6c8ff"/><stop offset="0.45" stop-color="#8a50c8"/><stop offset="1" stop-color="#2e1552"/></linearGradient>
<radialGradient id="blood" cx="0.38" cy="0.32" r="0.8"><stop offset="0" stop-color="#ff9a84"/><stop offset="0.4" stop-color="#d2331f"/><stop offset="1" stop-color="#5a0f08"/></radialGradient>
<radialGradient id="steel" cx="0.38" cy="0.3" r="0.8"><stop offset="0" stop-color="#f2f6fb"/><stop offset="0.45" stop-color="#8fa3ba"/><stop offset="1" stop-color="#37465a"/></radialGradient>
<linearGradient id="btn" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffe98a"/><stop offset="0.55" stop-color="#f5bd2e"/><stop offset="1" stop-color="#d98e12"/></linearGradient>
<linearGradient id="btnHot" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff7c8"/><stop offset="0.55" stop-color="#ffd24a"/><stop offset="1" stop-color="#f0a520"/></linearGradient>
<linearGradient id="btnOff" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8d8573"/><stop offset="1" stop-color="#5c5546"/></linearGradient>
"""
DEFS = DEFS.replace("</defs>", EXTRA + icon_defs() + "\n</defs>")

HEX = "0,-16 13.9,-8 13.9,8 0,16 -13.9,8 -13.9,-8"


def crystal(cx, cy, s, fill, label=None, fs=19):
    """Cristal hexagonal facetté (coût, mana, Démence)."""
    g = [f'<g transform="translate({cx} {cy}) scale({s})">',
         f'<polygon points="{HEX}" fill="#140c07" stroke="#140c07" stroke-width="5" stroke-linejoin="round"/>',
         f'<polygon points="{HEX}" fill="url(#{fill})" stroke="url(#gold)" stroke-width="2.2" stroke-linejoin="round"/>',
         '<polygon points="0,-16 13.9,-8 0,-2 -13.9,-8" fill="#ffffff" opacity="0.28"/>',
         '<polygon points="-13.9,-8 0,-2 0,16 -13.9,8" fill="#ffffff" opacity="0.08"/>',
         '<polygon points="13.9,-8 0,-2 0,16 13.9,8" fill="#000000" opacity="0.18"/>']
    if label is not None:
        g.append(f'<text x="0" y="{fs * 0.34:.1f}" text-anchor="middle" {FT} font-size="{fs}" fill="#ffffff" stroke-width="3.2" {OUTL}>{label}</text>')
    g.append('</g>')
    return "".join(g)


def card(x, y, title, cost, rarity, icon, lines, scale=1.0, tag=None, state=None, tsize=12, up=False):
    col = RARITY[rarity]
    g = [f'<g transform="translate({x} {y}) scale({scale})">']
    g.append('<g filter="url(#glow)">' if state == "hover" else '<g filter="url(#shadowSm)">')
    if state == "hover":
        g.append('<rect x="-3" y="-3" width="130" height="182" rx="13" fill="none" stroke="url(#goldHot)" stroke-width="3.5"/>')
    g.append('<g filter="url(#grey)">' if state == "off" else '<g>')
    # corps
    g.append('<rect x="0" y="0" width="124" height="176" rx="11" fill="#140c07"/>')
    g.append('<rect x="2.5" y="2.5" width="119" height="171" rx="9" fill="url(#stone)"/>')
    g.append('<rect x="2.5" y="2.5" width="119" height="171" rx="9" filter="url(#grainPaper)" opacity="0.35"/>')
    g.append('<path d="M5 12 Q5 5 12 5 H112 Q119 5 119 12" fill="none" stroke="#ffffff" stroke-width="1.6" opacity="0.8"/>')
    g.append(f'<rect x="5.5" y="5.5" width="113" height="165" rx="6.5" fill="none" stroke="{col}" stroke-width="2"/>')
    # fenêtre de l'illustration : l'icône du sort
    g.append('<path d="M25 87 V49 A37 37 0 0 1 99 49 V87Z" fill="#140c07" stroke="#140c07" stroke-width="9" stroke-linejoin="round"/>')
    g.append(f'<g clip-path="url(#cArch)"><use href="#ic_{icon}" transform="translate(22 10) scale(1.4286)"/><rect x="22" y="10" width="80" height="26" fill="url(#gloss)" opacity="0.5"/></g>')
    g.append('<path d="M25 87 V49 A37 37 0 0 1 99 49 V87Z" fill="none" stroke="url(#gold)" stroke-width="4" stroke-linejoin="round"/>')
    g.append('<path d="M27.5 86 V49 A34.5 34.5 0 0 1 96.5 49 V86" fill="none" stroke="#140c07" stroke-opacity="0.55" stroke-width="1"/>')
    # bandeau du nom
    g.append('<path d="M2 88 Q62 77 122 88 V106 Q62 95 2 106Z" fill="url(#banner)" stroke="#140c07" stroke-width="2.2" stroke-linejoin="round"/>')
    g.append('<path d="M5 90.5 Q62 80 119 90.5" fill="none" stroke="#e2b877" stroke-width="1.2" opacity="0.8"/>')
    tcol = "#b8f59a" if up else "#ffffff"
    g.append(f'<text {FT} font-size="{tsize}" fill="{tcol}" stroke-width="2.6" {OUTL} text-anchor="middle" x="62" y="99.5">{title}{"+" if up else ""}</text>')
    # texte
    g.append('<rect x="10" y="111" width="104" height="57" rx="5" fill="#140c07"/><rect x="11.5" y="112.5" width="101" height="54" rx="4" fill="url(#textbox)"/>')
    n = len(lines)
    size = 11.8 if n <= 2 else 10.4
    step = 14 if n <= 2 else 12.4
    y0 = 142.5 - (n - 1) * step / 2 + size * 0.34 + 2
    for i, ln in enumerate(lines):
        g.append(f'<text xml:space="preserve" x="62" y="{y0 + i * step:.1f}" text-anchor="middle" {FB} font-size="{size}" fill="#2b1c10">{rich(ln)}</text>')
    # gemme de rareté
    g.append(f'<path d="M62 104 l7.500000000000001 7 l-7.500000000000001 7 l-7.500000000000001 -7z" fill="#140c07" stroke="#140c07" stroke-width="3" stroke-linejoin="round"/><path d="M62 104 l7.500000000000001 7 l-7.500000000000001 7 l-7.500000000000001 -7z" fill="{col}" stroke="url(#gold)" stroke-width="1.4"/><path d="M62 104 l7.500000000000001 7 h-15z" fill="#ffffff" opacity="0.45"/>')
    g.append('</g>')
    g.append(crystal(9, 11, 1.02, "crystalOff" if state == "off" else "crystal", cost))
    if tag:
        w = 6.6 * len(tag) + 18
        fill, tc = ("#9c2c1c", "#fff3ec") if state == "off" else ("#3e2413", "#ffe9a8")
        g.append(f'<rect x="{62 - w / 2:.1f}" y="159" width="{w:.1f}" height="18" rx="9" fill="{fill}" stroke="#140c07" stroke-width="2"/>')
        g.append(f'<text x="62" y="172" text-anchor="middle" {FB} font-weight="800" font-size="11.5" fill="{tc}">{tag}</text>')
    g.append('</g></g>')
    return "\n".join(g)


def drop(cx, cy, n, r=15):
    return (f'<g transform="translate({cx} {cy})"><path d="M0 {-r * 1.35:.1f} C{r * .5:.1f} {-r * .6:.1f} {r} {-r * .15:.1f} {r} {r * .25:.1f} A{r} {r} 0 0 1 {-r} {r * .25:.1f} C{-r} {-r * .15:.1f} {-r * .5:.1f} {-r * .6:.1f} 0 {-r * 1.35:.1f}Z" fill="url(#blood)" stroke="#140c07" stroke-width="2.6" stroke-linejoin="round"/>'
            f'<ellipse cx="{-r * .35:.1f}" cy="{-r * .05:.1f}" rx="{r * .28:.1f}" ry="{r * .42:.1f}" fill="#ffffff" opacity="0.3" transform="rotate(20)"/>'
            f'<text x="0" y="{r * .62:.1f}" text-anchor="middle" {FT} font-size="{r * 1.25:.1f}" fill="#ffffff" stroke-width="3" {OUTL}>{n}</text></g>')


def shieldgem(cx, cy, n, r=14):
    return (f'<g transform="translate({cx} {cy})"><path d="M0 {-r} L{r} {-r * .62:.1f} V{r * .15:.1f} C{r} {r * .75:.1f} {r * .5:.1f} {r * 1.1:.1f} 0 {r * 1.3:.1f} C{-r * .5:.1f} {r * 1.1:.1f} {-r} {r * .75:.1f} {-r} {r * .15:.1f} V{-r * .62:.1f}Z" fill="url(#steel)" stroke="#140c07" stroke-width="2.6" stroke-linejoin="round"/>'
            f'<text x="0" y="{r * .55:.1f}" text-anchor="middle" {FT} font-size="{r * 1.25:.1f}" fill="#ffffff" stroke-width="3" {OUTL}>{n}</text></g>')


def hpbar(x, y, w, cur, mx, h=14, flash=None):
    """Goutte de sang portant les PV, prolongée d'une jauge sans chiffres."""
    r = h / 2
    fw = max(8, (w - 4) * cur / mx)
    s = [f'<g transform="translate({x} {y})" filter="url(#shadowSm)">',
         f'<rect x="0" y="0" width="{w}" height="{h}" rx="{r}" fill="#140c07"/>',
         f'<rect x="2" y="2" width="{w - 4}" height="{h - 4}" rx="{r - 2}" fill="#3a2418"/>']
    if flash:
        s.append(f'<rect x="2" y="2" width="{(w - 4) * flash / mx:.1f}" height="{h - 4}" rx="{r - 2}" fill="#ffe9a8"/>')
    s.append(f'<rect x="2" y="2" width="{fw:.1f}" height="{h - 4}" rx="{r - 2}" fill="url(#hp)"/>')
    s.append(f'<rect x="6" y="3" width="{max(fw - 8, 2):.1f}" height="3" rx="1.5" fill="#ffffff" opacity="0.35"/>')
    s.append(drop(0, r - 1, cur))
    s.append('</g>')
    return "\n".join(s)


def token(cx, cy, color, icon, n, r=12.5):
    return (f'<g transform="translate({cx} {cy})" filter="url(#shadowSm)"><circle r="{r + 1.5}" fill="#140c07"/>'
            f'<g clip-path="url(#cTok)"><use href="#ic_{icon}" transform="translate(-11.5 -11.5) scale(0.41)"/></g>'
            f'<circle r="{r - 1}" fill="none" stroke="{color}" stroke-width="2.2"/>'
            f'<text x="{r - 2}" y="{r + 2}" text-anchor="middle" {FT} font-size="13.5" fill="#ffffff" stroke-width="3" {OUTL}>{n}</text></g>')


def intent(cx, y, color, light, icon, label, w=None):
    big = len(str(label)) <= 2
    w = w or (62 if big else 44 + 8.4 * len(str(label)))
    return (f'<g transform="translate({cx} {y})" filter="url(#shadowSm)">'
            f'<path d="M-8 28 L0 39 L8 28Z" fill="#2b1b11" stroke="#140c07" stroke-width="2.4" stroke-linejoin="round"/>'
            f'<rect x="{-w / 2}" y="0" width="{w}" height="30" rx="15" fill="#140c07"/>'
            f'<rect x="{-w / 2 + 2}" y="2" width="{w - 4}" height="26" rx="13" fill="url(#plaque)" stroke="{color}" stroke-width="2"/>'
            f'<path d="M-6 28.5 L0 36.5 L6 28.5Z" fill="#241710"/>'
            f'<g transform="translate({-w / 2 + 16} 15)"><circle r="11.5" fill="#140c07"/><g clip-path="url(#cInt)"><use href="#ic_{icon}" transform="translate(-11 -11) scale(0.393)"/></g><circle r="10.5" fill="none" stroke="{color}" stroke-width="1.6"/></g>'
            f'<text x="{-w / 2 + 32}" y="{22.5 if big else 20.5}" {FT} font-size="{20 if big else 14}" fill="{light if not big else "#ffffff"}" stroke-width="3" {OUTL}>{label}</text></g>')


def button(x, y, w, h, label, kind="gold", size=18):
    fill = {"gold": "btn", "hot": "btnHot", "down": "btn", "off": "btnOff"}[kind]
    lip = 0 if kind == "down" else 5
    tc = "#3c372d" if kind == "off" else "#4a2c0a"
    f = 'filter="url(#glow)"' if kind == "hot" else 'filter="url(#shadowSm)"'
    r = h / 2
    return (f'<g transform="translate({x} {y + (5 - lip)})" {f}>'
            f'<rect x="0" y="0" width="{w}" height="{h + lip}" rx="{r}" fill="#140c07"/>'
            f'<rect x="2.5" y="{2.5 + lip}" width="{w - 5}" height="{h - 5}" rx="{r - 2.5}" fill="{"#8a5a0c" if kind != "off" else "#3c372d"}"/>'
            f'<rect x="2.5" y="2.5" width="{w - 5}" height="{h - 5}" rx="{r - 2.5}" fill="url(#{fill})"/>'
            + (f'<rect x="2.5" y="2.5" width="{w - 5}" height="{h - 5}" rx="{r - 2.5}" fill="#000000" opacity="0.14"/>' if kind == "down" else
               f'<rect x="10" y="5.500000000000001" width="{w - 20}" height="{h * 0.3:.1f}" rx="{h * 0.15:.1f}" fill="#ffffff" opacity="0.4"/>')
            + f'<text x="{w / 2}" y="{h / 2 + size * 0.34:.1f}" text-anchor="middle" {FT} font-size="{size}" fill="{tc}">{label}</text></g>')


def relic(x, y, color, icon):
    return (f'<g transform="translate({x} {y})"><rect width="28" height="28" rx="6" fill="#140c07"/>'
            f'<g clip-path="url(#cSq)"><use href="#ic_{icon}" transform="translate(3 3) scale(0.393)"/></g>'
            f'<rect x="2" y="2" width="24" height="24" rx="4.5" fill="none" stroke="{color}" stroke-width="2"/></g>')


def pile(x, y, n, faded=False):
    op = ' opacity="0.55"' if faded else ""
    return (f'<g transform="translate({x} {y})"><g filter="url(#shadowSm)"{op}>'
            + ("" if faded else '<use href="#cardBack" x="3" y="-3" width="36" height="51"/>')
            + '<use href="#cardBack" width="36" height="51"/></g>'
            f'<text x="18" y="33" text-anchor="middle" {FT} font-size="19" fill="#ffffff" stroke-width="3.4" {OUTL}>{n}</text></g>')


FRAME = '''<rect x="3" y="3" width="1034" height="614" rx="8" fill="none" stroke="#140c07" stroke-width="6"/>
<rect x="3" y="3" width="1034" height="614" rx="8" fill="none" stroke="#7a5229" stroke-width="3.5"/>
<rect x="5.5" y="5.5" width="1029" height="609" rx="6" fill="none" stroke="#f0c75e" stroke-opacity="0.55" stroke-width="1"/>
<g fill="url(#gold)" stroke="#140c07" stroke-width="1.6"><circle cx="11" cy="11" r="5.500000000000001"/><circle cx="1029" cy="11" r="5.500000000000001"/><circle cx="11" cy="609" r="5.500000000000001"/><circle cx="1029" cy="609" r="5.500000000000001"/></g>'''


def topbar():
    s = ['<rect x="0" y="0" width="1040" height="46" fill="url(#bar)"/>',
         '<rect x="0" y="0" width="1040" height="46" filter="url(#grainWood)" opacity="0.5"/>',
         '<rect x="0" y="43" width="1040" height="3.5" fill="#140c07"/><rect x="0" y="42" width="1040" height="2.4" fill="url(#gold)"/><rect x="0" y="46" width="1040" height="7" fill="url(#lipShade)"/>',
         f'<text x="22" y="29" {FT} font-size="18" fill="#ffd76a" stroke-width="3" {OUTL}>Prêtre</text>',
         drop(116, 23, "", r=9),
         f'<text x="131" y="29" {FT} font-size="17" fill="#ffffff" stroke-width="3" {OUTL}>52<tspan font-size="13" fill="#e8cfc6">/65</tspan></text>',
         '<g transform="translate(206 22)"><circle r="11" fill="#140c07"/><g clip-path="url(#cInt)"><use href="#ic_inv_misc_coin_01" transform="translate(-11 -11) scale(0.393)"/></g><circle r="10" fill="none" stroke="url(#gold)" stroke-width="1.6"/></g>',
         f'<text x="222" y="29" {FT} font-size="17" fill="#ffd76a" stroke-width="3" {OUTL}>84</text>',
         '<g transform="translate(270 9)"><use href="#cardBack" width="20" height="28"/></g>',
         f'<text x="295" y="29" {FT} font-size="17" fill="#ffffff" stroke-width="3" {OUTL}>13</text>',
         f'<text x="520" y="18" text-anchor="middle" {FT6} font-size="13.5" letter-spacing="0.4" fill="#f3e6c8" stroke-width="2.4" {OUTL}>Marche de l\'Ouest</text>',
         '<path d="M443 32 H597" stroke="#140c07" stroke-width="5" stroke-linecap="round"/><path d="M443 32 H597" stroke="#5a4630" stroke-width="2"/><path d="M443 32 H487" stroke="#ffd76a" stroke-width="2"/>']
    for i in range(8):
        x = 443 + 22 * i
        if i < 2:
            s.append(f'<circle cx="{x}" cy="32" r="4.500000000000001" fill="#ffd76a" stroke="#140c07" stroke-width="1.6"/>')
        elif i == 2:
            s.append(f'<circle cx="{x}" cy="32" r="6.500000000000001" fill="#fff7d6" stroke="#ffd76a" stroke-width="2.2" filter="url(#glow)"/>')
        elif i < 7:
            s.append(f'<circle cx="{x}" cy="32" r="4" fill="#2b1b11" stroke="#140c07" stroke-width="1.6"/><circle cx="{x}" cy="32" r="2.6" fill="none" stroke="#7a6248"/>')
        else:
            s.append(f'<path d="M{x} 24 l8 8 l-8 8 l-8 -8z" fill="#d2331f" stroke="#140c07" stroke-width="2"/>')
    s.append(crystal(740, 23, 0.9, "crystalVoid", "+2", fs=13))
    s.append(relic(768, 9, "#43b24f", "inv_misc_herb_01"))
    s.append(relic(801, 9, "#d9cfb4", "inv_misc_gear_01"))
    s.append('<rect x="839" y="11" width="2" height="24" rx="1" fill="#140c07"/>')
    s.append(relic(850, 9, "#f3e6c8", "inv_potion_54"))
    s.append(relic(883, 9, "#f3e6c8", "inv_potion_76"))
    s.append('<rect x="918" y="11" width="24" height="24" rx="4.500000000000001" fill="#140c07" fill-opacity="0.5" stroke="#8a7350" stroke-width="1.6" stroke-dasharray="4 3"/>')
    s.append('<g transform="translate(970 23)"><circle r="14" fill="#140c07"/><circle r="11.5" fill="url(#banner)" stroke="#e2b877" stroke-width="1.4"/><path d="M-5.500000000000001-4h11M-5.500000000000001 0h11M-5.500000000000001 4h11" stroke="#fff3cf" stroke-width="2" stroke-linecap="round"/></g>')
    s.append('<g transform="translate(1008 23)"><circle r="14" fill="#140c07"/><circle r="11.5" fill="url(#blood)" stroke="#ffb3a3" stroke-width="1.4"/><path d="M-4-4l8 8M4-4l-8 8" stroke="#ffffff" stroke-width="2.6" stroke-linecap="round"/></g>')
    return "\n".join(s)


def name(cx, y, t):
    return f'<text x="{cx}" y="{y}" text-anchor="middle" {FT6} font-size="14" fill="#ffffff" stroke-width="3" {OUTL}>{t}</text>'


def manaBlock(cx, cy):
    s = ['<g filter="url(#shadow)">', crystal(cx, cy, 2.7, "crystal"), '</g>',
         f'<text x="{cx}" y="{cy + 13}" text-anchor="middle" {FT} font-size="40" fill="#ffffff" stroke-width="5" {OUTL}>2<tspan font-size="24" dy="-2">/3</tspan></text>']
    for i, f in enumerate(["crystal", "crystal", "crystalEmpty"]):
        s.append(crystal(cx - 22 + i * 22, cy + 58, 0.6, f))
    s.append(crystal(cx + 40, cy - 30, 1.05, "crystalVoid", 3, fs=17))
    return "\n".join(s)


CARDS = dict(
    smite=("Châtiment", 1, "common", "spell_holy_holysmite", ["Inflige **6**."]),
    penance=("Pénitence", 2, "uncommon", "spell_holy_penance", ["Inflige **6** trois fois.", "Sous **Expiation** :", "**2** Absorption par coup."]),
    blast=("Attaque mentale", 1, "common", "spell_shadow_unholyfrenzy", ["Inflige **9**.", "**+2 Démence**."]),
    fire=("Feu intérieur", 1, "common", "spell_holy_innerfire", ["Gagne **5** Absorption."]),
    spirit=("Esprit de rédemption", 3, "rare", "spell_holy_greaterheal", ["Une fois par combat,", "survit à **1 PV**."]),
    nova=("Nova sacrée", 1, "uncommon", "spell_holy_holynova", ["Inflige **3** à tous.", "**Récupération 3**."]),
)


def C(key, x, y, **kw):
    t, cost, rar, ic, lines = CARDS[key]
    if key == "spirit":
        kw.setdefault("tsize", 9.6)
    if "lines" in kw:
        lines = kw.pop("lines")
    return card(x, y, t, cost, rar, ic, lines, **kw)


ENEMY = {
 "gnoll": '''<ellipse cx="60" cy="138" rx="46" ry="8" fill="#2b1b0c" opacity="0.5"/><path d="M32 136 C28 96 36 62 60 56 C84 62 92 96 88 136Z" fill="#8a6a3a" stroke="#4a3220" stroke-width="2"/><path d="M40 30 L34 8 L50 22 M80 30 L86 8 L70 22" fill="#8a6a3a" stroke="#4a3220" stroke-width="2"/><ellipse cx="60" cy="40" rx="24" ry="20" fill="#a07c48" stroke="#4a3220" stroke-width="2"/><path d="M92 60 L112 30" stroke="#6b6b6b" stroke-width="6"/>''',
 "mystic": '''<ellipse cx="60" cy="138" rx="46" ry="8" fill="#2b1b0c" opacity="0.5"/><path d="M30 136 C30 100 40 64 60 58 C80 64 90 100 90 136Z" fill="#5d4a7a" stroke="#2f2440" stroke-width="2"/><path d="M40 30 L34 8 L50 22 M80 30 L86 8 L70 22" fill="#8a6a3a" stroke="#4a3220" stroke-width="2"/><ellipse cx="60" cy="40" rx="22" ry="19" fill="#a07c48" stroke="#4a3220" stroke-width="2"/><path d="M22 140 V40" stroke="#6b4a22" stroke-width="5"/><circle cx="22" cy="34" r="9" fill="#c58cf0"/>''',
 "bandit": '''<ellipse cx="60" cy="138" rx="46" ry="8" fill="#2b1b0c" opacity="0.5"/><path d="M34 136 C32 100 40 66 60 60 C80 66 88 100 86 136Z" fill="#3a3a44" stroke="#1c1c22" stroke-width="2"/><circle cx="60" cy="38" r="20" fill="#e8c9a0" stroke="#4a3220" stroke-width="2"/><path d="M40 42 H80 V54 L60 62 L40 54Z" fill="#b3402e" stroke="#6b1e14" stroke-width="2"/><path d="M90 96 L112 70" stroke="#9a9a9a" stroke-width="5"/>''',
}


def combat():
    b = ['<g clip-path="url(#win)">', SCENE.replace('y="44"', 'y="46"'), topbar()]
    b.append('<g transform="translate(101 82)" filter="url(#shadowSm)"><rect width="190" height="34" rx="17" fill="#140c07"/><rect x="2" y="2" width="186" height="30" rx="15" fill="url(#plaque)" stroke="url(#gold)" stroke-width="1.6"/>'
             '<g transform="translate(17 17)"><circle r="12.5" fill="#140c07"/><g clip-path="url(#cInt)"><use href="#ic_spell_holy_searinglight" transform="translate(-11 -11) scale(0.393)"/></g><circle r="10.5" fill="none" stroke="url(#gold)" stroke-width="1.6"/></g>'
             f'<text x="36" y="15" {FB} font-weight="800" font-size="12" fill="#ffffff">Flammes sacrées</text>'
             '<rect x="35" y="20" width="142" height="7" rx="3.5" fill="#0f0906"/><rect x="36" y="21" width="88" height="5" rx="2.5" fill="url(#castFill)"/></g>')
    b.append(HERO)
    b.append(hpbar(132, 306, 150, 52, 65))
    b.append(shieldgem(296, 311, 8))
    b.append(token(182, 346, "#ffd76a", "ability_priest_atonement", 2))
    b.append(token(216, 346, "#7fd08a", "spell_holy_renew", 3))
    # ennemis
    b.append(intent(595, 86, "#e2634c", "#ffb3a3", "ability_meleedamage", 6))
    b.append('<ellipse cx="595" cy="268" rx="60" ry="13" fill="none" stroke="#140c07" stroke-width="6"/><ellipse cx="595" cy="268" rx="60" ry="13" fill="none" stroke="url(#goldHot)" stroke-width="3" filter="url(#glow)"/>')
    b.append(f'<g transform="translate(535 130)">{ENEMY["gnoll"]}</g>')
    b.append(f'<text x="644" y="170" text-anchor="middle" {FT} font-size="36" fill="#ffffff" stroke="#8f1d10" stroke-width="7" stroke-linejoin="round" paint-order="stroke" filter="url(#txt)">−9</text>')
    b.append(hpbar(540, 290, 124, 5, 14, flash=14))
    b.append(name(598, 326, "Gnoll Rivepatte"))
    b.append(token(598, 346, "#c79bf2", "spell_shadow_shadowwordpain", 4))
    b.append(intent(765, 114, "#b77bea", "#e3c6ff", "spell_shadow_evileye", "Guette"))
    b.append(f'<g transform="translate(711 158) scale(0.9)">{ENEMY["mystic"]}</g>')
    b.append(hpbar(712, 302, 118, 12, 12))
    b.append(name(768, 338, "Mystique Rivepatte"))
    b.append(intent(935, 90, "#7fb6e8", "#cfe5ff", "inv_shield_04", 6))
    b.append(f'<g transform="translate(875 134)">{ENEMY["bandit"]}</g>')
    b.append(hpbar(880, 294, 124, 13, 18))
    b.append(name(938, 330, "Bandit défias"))
    # plateau
    b.append(table())
    b.append(manaBlock(84, 486))
    b.append(pile(30, 566, 7))
    b.append(pile(118, 566, 3, faded=True))
    b.append(C("smite", 196, 454))
    b.append(C("penance", 326, 440))
    b.append(C("fire", 598, 440))
    b.append(C("spirit", 728, 454, state="off", tag="Mana insuffisant", lines=[]))
    b.append(C("blast", 448, 366, scale=1.18, state="hover", tag="Recharge 1"))
    for i, (n, ic) in enumerate([(2, "spell_holy_powerwordshield"), (1, "spell_holy_holynova")]):
        x = 896 + i * 54
        b.append(f'<g transform="translate({x} 448)" filter="url(#shadowSm)"><rect width="44" height="44" rx="8" fill="#140c07"/><g filter="url(#grey)"><use href="#ic_{ic}" transform="translate(3 3) scale(0.679)"/></g>'
                 '<rect x="3" y="3" width="38" height="38" rx="5" fill="#140c07" opacity="0.45"/><rect x="2.5" y="2.5" width="39" height="39" rx="5.500000000000001" fill="none" stroke="#8a7350" stroke-width="1.6"/>'
                 f'<text x="22" y="31" text-anchor="middle" {FT} font-size="24" fill="#ffffff" stroke-width="4" {OUTL}>{n}</text></g>')
    b.append(button(868, 522, 152, 50, "Fin du tour"))
    b.append('</g>')
    b.append(FRAME)
    return page("Combat — design précis", "\n".join(b))


def kit():
    def label(x, y, t):
        return f'<text x="{x}" y="{y}" {FT6} font-size="12" letter-spacing="1.6" fill="#d9b877">{t.upper()}</text><path d="M{x} {y + 6} h{len(t) * 9.5:.0f}" stroke="#7a5229" stroke-width="1.4"/>'

    def cap(x, y, t):
        return f'<text x="{x}" y="{y}" text-anchor="middle" {FB} font-size="12.5" fill="#d9c8a0">{t}</text>'
    b = ['<g clip-path="url(#win)">', '<rect width="1040" height="620" fill="url(#table)"/><rect width="1040" height="620" filter="url(#grainWood)" opacity="0.7"/>']
    b.append(label(34, 38, "La carte"))
    b.append(C("penance", 44, 70, scale=2.2))
    b.append(f'<text x="34" y="496" {FB} font-size="13.5" fill="#d9c8a0"><tspan x="34" dy="0">Corps de pierre claire, fenêtre en arche avec</tspan><tspan x="34" dy="18">l\'icône du sort, bandeau du nom, gemme de</tspan><tspan x="34" dy="18">rareté, cristal de coût. Chiffres blancs cernés</tspan><tspan x="34" dy="18">de noir, lisibles sur tous les fonds.</tspan></text>')
    b.append(label(350, 38, "Raretés"))
    b.append(C("smite", 352, 58, scale=0.92))
    b.append(C("nova", 480, 58, scale=0.92))
    b.append(C("spirit", 608, 58, scale=0.92))
    b.append(label(742, 38, "États"))
    b.append(C("blast", 748, 62, scale=0.92, state="hover", tag="Recharge 1"))
    b.append(C("smite", 884, 58, scale=0.92, up=True, lines=["Inflige **9**."]))
    b.append(cap(805, 246, "survolée") + cap(941, 246, "améliorée"))
    b.append(C("fire", 352, 266, scale=0.92, state="off", tag="Mana insuffisant", lines=[]))
    b.append('<g transform="translate(480 266) scale(0.92)" filter="url(#shadowSm)"><use href="#cardBack" width="124" height="176"/></g>')
    b.append(cap(409, 452, "injouable") + cap(537, 452, "dos"))
    b.append(label(620, 276, "Boutons"))
    for (x, y, k, t) in [(620, 294, "gold", "repos"), (800, 294, "hot", "survol"), (620, 376, "down", "enfoncé"), (800, 376, "off", "inactif")]:
        b.append(button(x, y, 152, 46, "Fin du tour", kind=k))
        b.append(cap(x + 76, y + 70, t))
    b.append(label(350, 480, "Intentions"))
    b.append(intent(386, 498, "#e2634c", "#ffb3a3", "ability_meleedamage", 6))
    b.append(intent(460, 498, "#7fb6e8", "#cfe5ff", "inv_shield_04", 6))
    b.append(intent(552, 498, "#b77bea", "#e3c6ff", "spell_shadow_evileye", "Guette"))
    b.append(label(640, 480, "États des personnages"))
    for i, (c, ic, n) in enumerate([("#ffd76a", "ability_priest_atonement", 2), ("#7fd08a", "spell_holy_renew", 3), ("#c79bf2", "spell_shadow_shadowwordpain", 4), ("#e2634c", "ability_warrior_sunder", 2)]):
        b.append(token(658 + i * 40, 514, c, ic, n))
    b.append(f'<text x="826" y="511" {FB} font-size="12.5" fill="#d9c8a0"><tspan x="826" dy="0">Icône du sort et valeur ;</tspan><tspan x="826" dy="16">nom et règle au survol.</tspan></text>')
    b.append(label(350, 560, "Vie, mana et réserves"))
    b.append(hpbar(366, 586, 130, 52, 65))
    b.append(shieldgem(520, 590, 8))
    b.append(hpbar(566, 586, 110, 5, 14, flash=14))
    b.append(crystal(716, 592, 1.15, "crystal", 2) + crystal(752, 592, 1.15, "crystalEmpty") + crystal(792, 592, 1.15, "crystalVoid", 3))
    b.append(relic(828, 578, "#43b24f", "inv_misc_herb_01") + relic(862, 578, "#f3e6c8", "inv_potion_54"))
    b.append(pile(912, 562, 7))
    b.append(pile(966, 562, 3, faded=True))
    b.append('</g>')
    b.append(FRAME)
    return page("Éléments — design précis", "\n".join(b))


(OUT / "CombatFinal.dc.html").write_text(combat())
(OUT / "Kit.dc.html").write_text(kit())
for n, f in (("CombatFinal", combat), ("Kit", kit)):
    html = f()
    svg = html[html.index("<svg"):html.index("</svg>") + 6].replace("<svg ", '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" ', 1)
    (OUT.parent / f"{n}.svg").write_text(svg)
