#!/usr/bin/env python3
"""Génère les planches « design précis » de la maquette (SVG dans des .dc.html)."""
import re, sys, pathlib

OUT = pathlib.Path(sys.argv[1])

RARITY = {"common": "#d9cfb4", "uncommon": "#43b24f", "rare": "#3f8be0", "epic": "#b77bea"}

DEFS = """
<defs>
<clipPath id="win"><rect x="1.5" y="1.5" width="1037" height="617" rx="9"/></clipPath>
<filter id="grainWood" x="0" y="0" width="100%" height="100%"><feTurbulence type="fractalNoise" baseFrequency="0.008 0.55" numOctaves="3" seed="7"/><feColorMatrix values="0 0 0 0 0.07  0 0 0 0 0.04  0 0 0 0 0.02  0 0 0 -1.5 1.05"/></filter>
<filter id="grainPaper" x="0" y="0" width="100%" height="100%"><feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" seed="3"/><feColorMatrix values="0 0 0 0 0.42  0 0 0 0 0.29  0 0 0 0 0.12  0 0 0 -0.9 0.5"/></filter>
<filter id="shadow" x="-30%" y="-30%" width="160%" height="170%"><feDropShadow dx="0" dy="5" stdDeviation="5" flood-color="#0d0805" flood-opacity="0.6"/></filter>
<filter id="shadowSm" x="-30%" y="-30%" width="160%" height="170%"><feDropShadow dx="0" dy="2" stdDeviation="2" flood-color="#0d0805" flood-opacity="0.65"/></filter>
<filter id="glow" x="-40%" y="-40%" width="180%" height="180%"><feDropShadow dx="0" dy="0" stdDeviation="6" flood-color="#ffd76a" flood-opacity="0.95"/></filter>
<filter id="txt" x="-20%" y="-30%" width="140%" height="170%"><feDropShadow dx="0" dy="1" stdDeviation="1" flood-color="#0d0805" flood-opacity="0.9"/></filter>
<filter id="grey"><feColorMatrix type="saturate" values="0.15"/><feComponentTransfer><feFuncR type="linear" slope="0.72"/><feFuncG type="linear" slope="0.72"/><feFuncB type="linear" slope="0.72"/></feComponentTransfer></filter>
<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f6e2a2"/><stop offset="0.45" stop-color="#eec873"/><stop offset="1" stop-color="#d9a44c"/></linearGradient>
<radialGradient id="sun" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#fff6d2"/><stop offset="0.35" stop-color="#fbe9ae" stop-opacity="0.9"/><stop offset="1" stop-color="#fbe9ae" stop-opacity="0"/></radialGradient>
<linearGradient id="vign" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1c130d" stop-opacity="0.35"/><stop offset="0.25" stop-color="#1c130d" stop-opacity="0"/><stop offset="0.8" stop-color="#1c130d" stop-opacity="0"/><stop offset="1" stop-color="#1c130d" stop-opacity="0.55"/></linearGradient>
<linearGradient id="bar" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3b281b"/><stop offset="1" stop-color="#21150e"/></linearGradient>
<linearGradient id="table" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#523420"/><stop offset="1" stop-color="#2c1b11"/></linearGradient>
<linearGradient id="lip" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#a87a44"/><stop offset="0.5" stop-color="#7a5229"/><stop offset="1" stop-color="#4a2f18"/></linearGradient>
<linearGradient id="lipShade" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0d0805" stop-opacity="0.6"/><stop offset="1" stop-color="#0d0805" stop-opacity="0"/></linearGradient>
<linearGradient id="gold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff3c4"/><stop offset="0.45" stop-color="#f0c75e"/><stop offset="1" stop-color="#9c6e22"/></linearGradient>
<linearGradient id="goldFlat" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffe08a"/><stop offset="0.5" stop-color="#eebd4e"/><stop offset="1" stop-color="#c08c2c"/></linearGradient>
<linearGradient id="goldHot" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff0b8"/><stop offset="0.5" stop-color="#ffd76a"/><stop offset="1" stop-color="#d9a23a"/></linearGradient>
<linearGradient id="plaque" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#35241a"/><stop offset="1" stop-color="#1e140d"/></linearGradient>
<linearGradient id="parch" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fbf0d0"/><stop offset="0.6" stop-color="#f1dfb3"/><stop offset="1" stop-color="#dfc893"/></linearGradient>
<linearGradient id="ribbon" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#5a3a22"/><stop offset="1" stop-color="#3a2416"/></linearGradient>
<linearGradient id="hp" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f08a6e"/><stop offset="0.45" stop-color="#c8402c"/><stop offset="1" stop-color="#7c2015"/></linearGradient>
<linearGradient id="trough" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0f0906"/><stop offset="1" stop-color="#2a1b12"/></linearGradient>
<linearGradient id="castFill" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#c08c2c"/><stop offset="1" stop-color="#ffe08a"/></linearGradient>
<radialGradient id="mana" cx="0.36" cy="0.3" r="0.8"><stop offset="0" stop-color="#bfe2ff"/><stop offset="0.35" stop-color="#3f86dc"/><stop offset="1" stop-color="#12306a"/></radialGradient>
<radialGradient id="manaOff" cx="0.36" cy="0.3" r="0.8"><stop offset="0" stop-color="#f0b3a6"/><stop offset="0.4" stop-color="#a23a2a"/><stop offset="1" stop-color="#4a140c"/></radialGradient>
<radialGradient id="void" cx="0.36" cy="0.3" r="0.8"><stop offset="0" stop-color="#e6c8ff"/><stop offset="0.4" stop-color="#8a50c8"/><stop offset="1" stop-color="#2e1552"/></radialGradient>
<radialGradient id="mHoly" cx="0.5" cy="0.4" r="0.7"><stop offset="0" stop-color="#fff2bd"/><stop offset="0.55" stop-color="#e7b740"/><stop offset="1" stop-color="#8f5f17"/></radialGradient>
<radialGradient id="mShadow" cx="0.5" cy="0.4" r="0.7"><stop offset="0" stop-color="#c9a2f0"/><stop offset="0.55" stop-color="#6d3fa8"/><stop offset="1" stop-color="#27123f"/></radialGradient>
<radialGradient id="mWard" cx="0.5" cy="0.4" r="0.7"><stop offset="0" stop-color="#dff0ff"/><stop offset="0.55" stop-color="#6aa8dc"/><stop offset="1" stop-color="#1f4a78"/></radialGradient>
<linearGradient id="back" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#3c5f8a"/><stop offset="1" stop-color="#1a2c47"/></linearGradient>
<linearGradient id="slot" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1a110b"/><stop offset="1" stop-color="#3a281a"/></linearGradient>
<linearGradient id="gloss" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff" stop-opacity="0.45"/><stop offset="1" stop-color="#ffffff" stop-opacity="0"/></linearGradient>

<!-- pictogrammes des médaillons (boîte 48, centrés) -->
<symbol id="gSun" viewBox="0 0 48 48"><circle cx="24" cy="24" r="8" fill="#fffbe6"/><path d="M24 3v9M24 36v9M3 24h9M36 24h9M9 9l6.5 6.5M32.5 32.5L39 39M39 9l-6.5 6.5M15.5 32.5L9 39" stroke="#fffbe6" stroke-width="3.4" stroke-linecap="round"/></symbol>
<symbol id="gStars" viewBox="0 0 48 48"><path d="M24 4l3.6 9.4L37 17l-9.4 3.6L24 30l-3.6-9.4L11 17l9.4-3.6zM11 28l2.2 5.8L19 36l-5.8 2.2L11 44l-2.2-5.8L3 36l5.8-2.2zM37 28l2.2 5.8L45 36l-5.8 2.2L37 44l-2.2-5.8L29 36l5.8-2.2z" fill="#fffbe6"/></symbol>
<symbol id="gMind" viewBox="0 0 48 48"><path d="M4 24s8-13 20-13 20 13 20 13-8 13-20 13S4 24 4 24z" fill="none" stroke="#f3e1ff" stroke-width="3.2"/><circle cx="24" cy="24" r="7" fill="#f3e1ff"/><circle cx="24" cy="24" r="3" fill="#27123f"/></symbol>
<symbol id="gFlame" viewBox="0 0 48 48"><path d="M24 4c3 9 12 12 12 23a12 12 0 0 1-24 0c0-6 4-8 5-13 3 2 4 5 4 8 3-4 4-10 3-18z" fill="#f4faff"/></symbol>
<symbol id="gWings" viewBox="0 0 48 48"><circle cx="24" cy="13" r="5" fill="#fffbe6"/><path d="M24 19v22M21 22C12 14 6 16 3 22c5 0 7 3 9 7 3-1 6-1 9 1zM27 22c9-8 15-6 18 0-5 0-7 3-9 7-3-1-6-1-9 1z" fill="#fffbe6" stroke="#fffbe6" stroke-width="2.4" stroke-linejoin="round"/></symbol>
<symbol id="gNova" viewBox="0 0 48 48"><circle cx="24" cy="24" r="6" fill="#fffbe6"/><circle cx="24" cy="24" r="13" fill="none" stroke="#fffbe6" stroke-width="3"/><circle cx="24" cy="24" r="20" fill="none" stroke="#fffbe6" stroke-width="2" stroke-dasharray="4 5"/></symbol>

<!-- châssis commun d'une carte 124 × 176 ; la couleur de rareté passe par « color » -->
<symbol id="card" viewBox="0 0 124 176" overflow="visible">
<rect x="0.75" y="0.75" width="122.5" height="174.5" rx="9" fill="#2b1b11" stroke="#120b07" stroke-width="1.5"/>
<rect x="3.5" y="3.5" width="117" height="169" rx="7" fill="none" stroke="currentColor" stroke-width="2.6"/>
<rect x="6.5" y="6.5" width="111" height="163" rx="5" fill="url(#parch)"/>
<rect x="6.5" y="6.5" width="111" height="163" rx="5" filter="url(#grainPaper)" opacity="0.5"/>
<rect x="6.5" y="6.5" width="111" height="163" rx="5" fill="none" stroke="#8a6a3a" stroke-width="1"/>
<path d="M10 14 H114 V30 Q62 37 10 30Z" fill="url(#ribbon)" stroke="#1c110a" stroke-width="1"/>
<path d="M11.5 15.5 H112.5" stroke="#8a6238" stroke-width="1"/>
<circle cx="62" cy="71" r="30" fill="#2b1b11"/>
<circle cx="62" cy="71" r="28.5" fill="none" stroke="url(#gold)" stroke-width="3.4"/>
<path d="M14 110 H50 M74 110 H110" stroke="#a8875060" stroke-width="1"/>
<path d="M14 110 H50 M74 110 H110" stroke="#8a6a3a" stroke-width="1" opacity="0.7"/>
<path d="M62 105 l5 5 l-5 5 l-5 -5z" fill="currentColor" stroke="#2b1b11" stroke-width="1"/>
</symbol>

<symbol id="cardBack" viewBox="0 0 124 176" overflow="visible">
<rect x="0.75" y="0.75" width="122.5" height="174.5" rx="9" fill="#2b1b11" stroke="#120b07" stroke-width="1.5"/>
<rect x="4" y="4" width="116" height="168" rx="7" fill="url(#back)" stroke="url(#gold)" stroke-width="2.4"/>
<rect x="11" y="11" width="102" height="154" rx="4" fill="none" stroke="#f0c75e" stroke-width="1" opacity="0.6"/>
<path d="M62 52 l22 36 l-22 36 l-22 -36z" fill="none" stroke="url(#gold)" stroke-width="3"/>
<path d="M62 68 l12 20 l-12 20 l-12 -20z" fill="url(#gold)"/>
</symbol>

<symbol id="flask" viewBox="0 0 24 30" overflow="visible">
<path d="M9 2h6v2h-1v7c5 2 7 6 7 10a9 9 0 0 1-18 0c0-4 2-8 7-10V4H9z" fill="#1c120b" stroke="#f3e6c8" stroke-width="1.6" stroke-linejoin="round"/>
<path d="M5 20a7 7 0 0 0 14 0c0-1.4-.3-2.6-.9-3.6H5.900000000000001C5.3 17.4 5 18.600000000000001 5 20z" fill="currentColor"/>
<path d="M7.500000000000001 19c0-2 1-3.500000000000001 2.5-4.5" stroke="#ffffff" stroke-opacity="0.6" stroke-width="1.4" fill="none" stroke-linecap="round"/>
<rect x="8.5" y="0.5" width="7" height="3" rx="1" fill="#8a5f33" stroke="#1c120b" stroke-width="0.8"/>
</symbol>
<symbol id="flaskEmpty" viewBox="0 0 24 30" overflow="visible">
<path d="M9 2h6v2h-1v7c5 2 7 6 7 10a9 9 0 0 1-18 0c0-4 2-8 7-10V4H9z" fill="#1c120b" fill-opacity="0.5" stroke="#8a7350" stroke-width="1.4" stroke-dasharray="3 2.5" stroke-linejoin="round"/>
</symbol>
<symbol id="iSword" viewBox="0 0 24 24"><path d="M19.5 2.5l2 2L10 16l-2.5.5L8 14zM5 15l4 4M4.500000000000001 21.5l-2-2 3-3 2 2z" fill="currentColor" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round" stroke-linecap="round"/></symbol>
<symbol id="iEye" viewBox="0 0 24 24"><path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z" fill="none" stroke="currentColor" stroke-width="2.2"/><circle cx="12" cy="12" r="3.2" fill="currentColor"/></symbol>
<symbol id="iShield" viewBox="0 0 24 24"><path d="M12 2.5l8.5 3v6.500000000000001c0 5-3.6 8.5-8.5 9.5-4.9-1-8.5-4.500000000000001-8.5-9.5V5.500000000000001z" fill="currentColor" fill-opacity="0.3" stroke="currentColor" stroke-width="2.2" stroke-linejoin="round"/></symbol>
<symbol id="iHeart" viewBox="0 0 24 24"><path d="M12 21C5 15.5 2 12 2 8a5 5 0 0 1 10-1.500000000000001A5 5 0 0 1 22 8c0 4-3 7.500000000000001-10 13z" fill="currentColor"/></symbol>
</defs>
"""

FT = "font-family=\"Cinzel, serif\" font-weight=\"700\""
FT6 = "font-family=\"Cinzel, serif\" font-weight=\"600\""
FB = "font-family=\"'Alegreya Sans', sans-serif\""


def rich(line):
    out, bold = [], False
    for part in re.split(r"(\*\*)", line):
        if part == "**":
            bold = not bold
        elif part:
            out.append(f'<tspan font-weight="{800 if bold else 500}">{part}</tspan>')
    return "".join(out)


def card(x, y, title, cost, rarity, school, glyph, lines, scale=1.0, tag=None, state=None, tsize=11.5, up=False):
    """state : None | 'hover' | 'off' (injouable)."""
    col = RARITY[rarity]
    g = [f'<g transform="translate({x} {y}) scale({scale})">']
    outer = 'filter="url(#glow)"' if state == "hover" else 'filter="url(#shadowSm)"'
    g.append(f'<g {outer}>')
    if state == "hover":
        g.append('<rect x="-2.5" y="-2.5" width="129" height="181" rx="11" fill="none" stroke="url(#goldHot)" stroke-width="3"/>')
    body = 'filter="url(#grey)"' if state == "off" else ""
    g.append(f'<g {body}>')
    g.append(f'<use href="#card" width="124" height="176" style="color:{col}"/>')
    g.append(f'<circle cx="62" cy="71" r="26.5" fill="url(#{school})"/>')
    g.append(f'<use href="#{glyph}" x="42" y="51" width="40" height="40" opacity="0.95"/>')
    g.append('<path d="M38 62a26.5 26.5 0 0 1 48 0a40 30 0 0 0-48 0z" fill="#ffffff" opacity="0.22"/>')
    tcol = "#bff0a8" if up else "#fbeecb"
    g.append(f'<text x="66" y="27" text-anchor="middle" {FT} font-size="{tsize}" fill="{tcol}">{title}{"+" if up else ""}</text>')
    y0 = 127 if len(lines) <= 2 else 123
    step = 14.5 if len(lines) <= 2 else 12.6
    size = 11.6 if len(lines) <= 2 else 10.4
    y0 += (3 - max(len(lines), 2)) * 4
    for i, ln in enumerate(lines):
        g.append(f'<text xml:space="preserve" x="62" y="{y0 + i * step:.1f}" text-anchor="middle" {FB} font-size="{size}" fill="#2b1c10">{rich(ln)}</text>')
    g.append('</g>')
    # gemme de coût
    gem = "manaOff" if state == "off" else "mana"
    g.append('<circle cx="8" cy="8" r="15.5" fill="#1c110a"/>')
    g.append('<circle cx="8" cy="8" r="14" fill="none" stroke="url(#gold)" stroke-width="2.6"/>')
    g.append(f'<circle cx="8" cy="8" r="12" fill="url(#{gem})"/>')
    g.append('<ellipse cx="5" cy="3" rx="6.5" ry="3.6" fill="#ffffff" opacity="0.35"/>')
    g.append(f'<text x="8" y="14" text-anchor="middle" {FT} font-size="17" fill="#ffffff" filter="url(#txt)">{cost}</text>')
    if tag:
        w = 7.0 * len(tag) + 16
        fill, stroke, tc = ("#7a2a1e", "#f0b3a6", "#fff3ec") if state == "off" else ("#2b1b11", "#a8782a", "#f3e6c8")
        g.append(f'<rect x="{62 - w / 2:.1f}" y="157" width="{w:.1f}" height="17" rx="8.5" fill="{fill}" stroke="{stroke}" stroke-width="1.2"/>')
        g.append(f'<text x="62" y="169.5" text-anchor="middle" {FB} font-weight="700" font-size="11.5" fill="{tc}">{tag}</text>')
    g.append('</g></g>')
    return "\n".join(g)


def hpbar(x, y, w, cur, mx, h=16, flash=None):
    r = h / 2
    fw = max(r * 2, (w - 4) * cur / mx)
    s = [f'<g transform="translate({x} {y})">',
         f'<rect x="-1.5" y="-1.5" width="{w + 3}" height="{h + 3}" rx="{r + 1.5}" fill="#120b07"/>',
         f'<rect width="{w}" height="{h}" rx="{r}" fill="url(#trough)" stroke="#6b4a22" stroke-width="1.2"/>']
    if flash:
        s.append(f'<rect x="2" y="2" width="{(w - 4) * flash / mx:.1f}" height="{h - 4}" rx="{r - 2}" fill="#ffe9a8"/>')
    s.append(f'<rect x="2" y="2" width="{fw:.1f}" height="{h - 4}" rx="{r - 2}" fill="url(#hp)"/>')
    s.append(f'<rect x="4" y="3" width="{max(fw - 4, 2):.1f}" height="{(h - 4) * 0.38:.1f}" rx="2" fill="url(#gloss)"/>')
    s.append(f'<text x="{w / 2}" y="{h / 2 + 4.3:.1f}" text-anchor="middle" {FB} font-weight="800" font-size="{12.5 if h < 18 else 13.5}" fill="#ffffff" filter="url(#txt)">{cur} / {mx}</text>')
    s.append('</g>')
    return "\n".join(s)


def token(cx, cy, color, glyph, n, r=12):
    """Jeton d'état : pictogramme + valeur. Le nom reste dans l'infobulle."""
    return (f'<g transform="translate({cx} {cy})" filter="url(#shadowSm)">'
            f'<circle r="{r}" fill="#1e140d" stroke="{color}" stroke-width="1.8"/>'
            f'<g color="{color}">{glyph}</g>'
            f'<circle cx="{r - 2}" cy="{r - 3}" r="7" fill="#120b07" stroke="{color}" stroke-width="1"/>'
            f'<text x="{r - 2}" y="{r + 1}" text-anchor="middle" {FB} font-weight="800" font-size="10.5" fill="#ffffff">{n}</text></g>')


G_ATONE = '<circle r="3.4" fill="currentColor"/><path d="M0-8v3M0 5v3M-8 0h3M5 0h3M-5.600000000000001-5.600000000000001l2 2M3.6 3.6l2 2M5.600000000000001-5.600000000000001l-2 2M-3.6 3.6l-2 2" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>'
G_REGEN = '<path d="M-2-7h4v5h5v4h-5v5h-4v-5h-5v-4h5z" fill="currentColor"/>'
G_PAIN = '<path d="M0-8c2 5 6 6 6 10a6 6 0 0 1-12 0c0-4 4-5 6-10z" fill="currentColor"/>'
G_BREAK = '<path d="M0-8l7 2.5v5c0 4-3 7-7 8-4-1-7-4-7-8v-5z" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M1-6l-3 5 3 2-2 5" fill="none" stroke="currentColor" stroke-width="1.6"/>'


def intent(cx, y, color, light, icon, label, w=None):
    w = w or (58 if len(str(label)) <= 2 else 16 + 26 + 8.2 * len(str(label)))
    big = len(str(label)) <= 2
    return (f'<g transform="translate({cx} {y})" filter="url(#shadowSm)">'
            f'<path d="M-7 27 L0 36 L7 27Z" fill="#1e140d" stroke="{color}" stroke-width="1.8"/>'
            f'<rect x="{-w / 2}" y="0" width="{w}" height="28" rx="14" fill="url(#plaque)" stroke="{color}" stroke-width="1.8"/>'
            f'<path d="M-6 27.200000000000003 H6" stroke="#1e140d" stroke-width="2.4"/>'
            f'<use href="#{icon}" x="{-w / 2 + 9}" y="5" width="18" height="18" style="color:{light}"/>'
            f'<text x="{-w / 2 + 32}" y="{20.5 if big else 19}" {FB} font-weight="800" font-size="{19 if big else 13.5}" fill="{light}">{label}</text></g>')


def button(x, y, w, h, label, kind="gold", size=16):
    if kind == "gold":
        fill, edge, hi, tc = "url(#goldFlat)", "#6e4a14", "#fff3c4", "#2b1c10"
    elif kind == "hot":
        fill, edge, hi, tc = "url(#goldHot)", "#6e4a14", "#ffffff", "#2b1c10"
    elif kind == "down":
        fill, edge, hi, tc = "#c08c2c", "#4a3210", "#d9a23a", "#2b1c10"
    else:
        fill, edge, hi, tc = "#5a4a38", "#2b1b11", "#7a6a55", "#a89878"
    f = 'filter="url(#glow)"' if kind == "hot" else 'filter="url(#shadowSm)"'
    dy = 1.5 if kind == "down" else 0
    return (f'<g transform="translate({x} {y + dy})" {f}>'
            f'<rect width="{w}" height="{h}" rx="8" fill="#1c110a"/>'
            f'<rect x="2" y="2" width="{w - 4}" height="{h - 4}" rx="6.5" fill="{fill}" stroke="{edge}" stroke-width="1.4"/>'
            f'<rect x="4.5" y="4.5" width="{w - 9}" height="{h - 9}" rx="4.5" fill="none" stroke="{hi}" stroke-width="1" opacity="0.8"/>'
            f'<path d="M12 {h / 2} l4 -4 l4 4 l-4 4z M{w - 12} {h / 2} l-4 -4 l-4 4 l4 4z" fill="{edge}" opacity="0.75"/>'
            f'<text x="{w / 2}" y="{h / 2 + size * 0.36:.1f}" text-anchor="middle" {FT} font-size="{size}" fill="{tc}">{label}</text></g>')


def pile(x, y, n, faded=False):
    op = ' opacity="0.55"' if faded else ""
    return (f'<g transform="translate({x} {y})">'
            f'<g filter="url(#shadowSm)"{op}>'
            + ("" if faded else '<use href="#cardBack" x="3" y="-3" width="36" height="51"/>')
            + '<use href="#cardBack" width="36" height="51"/></g>'
            f'<circle cx="34" cy="46" r="11" fill="#1c110a" stroke="url(#gold)" stroke-width="1.6"/>'
            f'<text x="34" y="50.5" text-anchor="middle" {FT} font-size="12.5" fill="#fff3cf">{n}</text></g>')


def relic(x, y, color, inner):
    return (f'<g transform="translate({x} {y})"><rect width="28" height="28" rx="6" fill="url(#slot)" stroke="{color}" stroke-width="1.8"/>'
            f'<rect x="2.5" y="2.5" width="23" height="23" rx="4" fill="none" stroke="#000000" stroke-opacity="0.5"/>{inner}</g>')


HERO = '''<g transform="translate(136 124)"><ellipse cx="60" cy="160" rx="54" ry="9" fill="#2b1b0c" opacity="0.5"/>
<path d="M60 44 C30 60 26 120 22 156 H98 C94 120 90 60 60 44Z" fill="#f4efe2" stroke="#8a7350" stroke-width="2"/>
<path d="M60 52 V150" stroke="#c9a227" stroke-width="5"/><circle cx="60" cy="28" r="18" fill="#e8c9a0" stroke="#8a7350" stroke-width="2"/>
<path d="M100 20 V150" stroke="#6b4a22" stroke-width="5"/><circle cx="100" cy="16" r="9" fill="#f0c75e"/></g>'''

SCENE = '''<rect x="0" y="44" width="1040" height="380" fill="url(#sky)"/>
<circle cx="820" cy="136" r="150" fill="url(#sun)"/><circle cx="820" cy="136" r="40" fill="#fff6d6"/>
<path d="M0 222 Q120 176 250 204 T520 196 T800 190 T1040 214 V424 H0Z" fill="#dfb260" opacity="0.8"/>
<path d="M0 240 Q180 196 360 236 T720 222 T1040 242 V424 H0Z" fill="#c9973f"/>
<g fill="#7a5524"><path d="M604 232 l8 -70 h10 l8 70z"/><path d="M617 168 l-40 -18 l4 -8z M617 168 l40 -18 l-4 -8z M617 168 l-18 40 l-8 -4z M617 168 l18 40 l8 -4z"/></g>
<path d="M0 284 Q260 244 520 282 T1040 270 V424 H0Z" fill="#b07d2c"/>
<path d="M0 330 Q300 300 560 326 T1040 316 V424 H0Z" fill="#8a5f22"/>
<path d="M0 366 Q400 350 1040 362 V424 H0Z" fill="#6f4a1b"/>
<g stroke="#d9a94a" stroke-width="2.4" stroke-linecap="round" opacity="0.9"><path d="M36 368v-26M52 366v-20M70 368v-30M96 366v-24M128 368v-32M470 364v-20M494 366v-26M522 364v-22M886 366v-28M912 364v-22M944 366v-30M982 364v-26M1010 366v-20"/></g>
<rect x="0" y="44" width="1040" height="380" fill="url(#vign)"/>'''


def page(title, body):
    return f'''<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<title>{title}</title>
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Cinzel:wght@600;700&family=Alegreya+Sans:wght@400;500;700;800&display=swap">
<style>
body{{margin:0}}
</style>
</helmet>
<div style="width: 1040px; height: 620px; position: relative; overflow: hidden; background: #1c130d; border-radius: 10px">
<svg role="img" aria-label="{title}" viewBox="0 0 1040 620" style="position: absolute; left: 0; top: 0; width: 1040px; height: 620px">
{DEFS}
{body}
</svg>
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{{"$preview":{{"width":1040,"height":620}}}}'>
class Component extends DCLogic {{
renderVals() {{
return {{}};
}}
}}
</script>
</body>
</html>
'''


FRAME = '''<rect x="1.5" y="1.5" width="1037" height="617" rx="9" fill="none" stroke="#6b4a22" stroke-width="3"/>
<rect x="4" y="4" width="1032" height="612" rx="7" fill="none" stroke="#f0c75e" stroke-opacity="0.35" stroke-width="1"/>'''


def topbar(key=True):
    s = ['<rect x="0" y="0" width="1040" height="44" fill="url(#bar)"/>',
         '<rect x="0" y="0" width="1040" height="44" filter="url(#grainWood)" opacity="0.5"/>',
         '<rect x="0" y="42" width="1040" height="2" fill="#a8782a"/><rect x="0" y="41" width="1040" height="1" fill="#f0c75e" opacity="0.6"/><rect x="0" y="44" width="1040" height="6" fill="url(#lipShade)"/>',
         '<path d="M16 11h16v11c0 6-4 9.5-8 11-4-1.500000000000001-8-5-8-11z" fill="url(#gold)" stroke="#5a3c10" stroke-width="1"/><path d="M24 15v12M19.5 19.5h9" stroke="#5a3c10" stroke-width="2.4"/>',
         f'<text x="42" y="28" {FT} font-size="16" fill="#f0c75e" filter="url(#txt)">Prêtre</text>',
         '<use href="#iHeart" x="122" y="13" width="18" height="18" style="color:#e2634c"/>',
         f'<text x="145" y="27.5" {FB} font-weight="800" font-size="15" fill="#ffb3a3">52 / 65</text>',
         '<circle cx="216" cy="22" r="8.5" fill="url(#gold)" stroke="#5a3c10" stroke-width="1"/><circle cx="216" cy="22" r="5" fill="none" stroke="#5a3c10" stroke-opacity="0.6"/>',
         f'<text x="230" y="27.5" {FB} font-weight="800" font-size="15" fill="#f0c75e">84</text>',
         f'<text x="520" y="17" text-anchor="middle" {FT6} font-size="12.5" letter-spacing="0.6" fill="#f3e6c8">Marche de l\'Ouest</text>',
         '<path d="M443 31 H597" stroke="#5a4630" stroke-width="2"/><path d="M443 31 H487" stroke="#f0c75e" stroke-width="2"/>']
    xs = [443 + 22 * i for i in range(8)]
    for i, x in enumerate(xs):
        if i < 2:
            s.append(f'<circle cx="{x}" cy="31" r="4" fill="#f0c75e" stroke="#5a3c10"/>')
        elif i == 2:
            s.append(f'<circle cx="{x}" cy="31" r="6" fill="#fff3cf" stroke="#f0c75e" stroke-width="2" filter="url(#glow)"/>')
        elif i < 7:
            s.append(f'<circle cx="{x}" cy="31" r="3.6" fill="#231710" stroke="#7a6248" stroke-width="1.4"/>')
        else:
            s.append(f'<path d="M{x} 24 l7 7 l-7 7 l-7 -7z" fill="#b3402e" stroke="#f0b3a6" stroke-width="1.2"/>')
    if key:
        s.append('<g transform="translate(726 9)"><path d="M13 0 L26 9 L21 26 H5 L0 9Z" fill="url(#void)" stroke="#e6c8ff" stroke-width="1.4"/>'
                 f'<text x="13" y="19" text-anchor="middle" {FT} font-size="11.5" fill="#ffffff" filter="url(#txt)">+2</text></g>')
    s.append(relic(766, 8, "#43b24f", '<path d="M8 20c0-8 4-12 12-12-1 8-5 12-12 12z" fill="#7fd08a"/>'))
    s.append(relic(800, 8, "#d9cfb4", '<circle cx="14" cy="14" r="6.5" fill="none" stroke="#d9cfb4" stroke-width="2.4"/><circle cx="14" cy="14" r="2" fill="#d9cfb4"/>'))
    s.append('<rect x="839" y="10" width="1.5" height="24" fill="#6b4a22"/>')
    s.append('<use href="#flask" x="852" y="7" width="24" height="30" style="color:#d8472f"/>')
    s.append('<use href="#flask" x="882" y="7" width="24" height="30" style="color:#3f8be0"/>')
    s.append('<use href="#flaskEmpty" x="912" y="7" width="24" height="30"/>')
    s.append('<g transform="translate(962 22)"><circle r="13" fill="url(#slot)" stroke="#8a7350" stroke-width="1.6"/><path d="M-6-4.500000000000001h12M-6 0h12M-6 4.500000000000001h12" stroke="#f3e6c8" stroke-width="2" stroke-linecap="round"/></g>')
    s.append('<g transform="translate(1008 22)"><circle r="13" fill="#7a2a1e" stroke="#d99a80" stroke-width="1.6"/><path d="M-4.500000000000001-4.500000000000001l9 9M4.500000000000001-4.500000000000001l-9 9" stroke="#fff3cf" stroke-width="2.4" stroke-linecap="round"/></g>')
    return "\n".join(s)


def table():
    return '''<rect x="0" y="424" width="1040" height="196" fill="url(#table)"/>
<rect x="0" y="424" width="1040" height="196" filter="url(#grainWood)" opacity="0.75"/>
<path d="M0 492 H1040 M0 560 H1040" stroke="#170e08" stroke-width="1.6" opacity="0.7"/><path d="M0 493.5 H1040 M0 561.5 H1040" stroke="#7a5229" stroke-width="1" opacity="0.35"/>
<rect x="0" y="424" width="1040" height="9" fill="url(#lip)"/><rect x="0" y="424" width="1040" height="1.2" fill="#e2bd7a" opacity="0.8"/>
<rect x="0" y="433" width="1040" height="16" fill="url(#lipShade)"/>'''


def combat():
    b = ['<g clip-path="url(#win)">', SCENE, topbar()]
    # --- héros
    b.append('<g transform="translate(101 80)" filter="url(#shadowSm)"><rect width="190" height="36" rx="6" fill="url(#plaque)" stroke="url(#gold)" stroke-width="1.6"/>'
             f'<text x="10" y="15.5" {FB} font-weight="700" font-size="12.5" fill="#f3e6c8">Flammes sacrées</text>'
             f'<text x="180" y="15.5" text-anchor="end" {FB} font-weight="700" font-size="11.5" fill="#f0c75e">1 tour</text>'
             '<rect x="9" y="22" width="172" height="7" rx="3.5" fill="#0f0906"/><rect x="10" y="23" width="106" height="5" rx="2.5" fill="url(#castFill)"/></g>')
    b.append(HERO)
    b.append('<g transform="translate(104 300)" filter="url(#shadowSm)"><use href="#iShield" x="0" y="-4" width="34" height="34" style="color:#9fd0ff"/>'
             f'<text x="17" y="18" text-anchor="middle" {FB} font-weight="800" font-size="15" fill="#ffffff" filter="url(#txt)">8</text></g>')
    b.append(hpbar(142, 304, 148, 52, 65, h=20))
    b.append(token(170, 346, "#f0c75e", G_ATONE, 2))
    b.append(token(204, 346, "#7fd08a", G_REGEN, 3))
    # --- ennemi 1 (ciblé, touché)
    b.append(intent(595, 88, "#e2634c", "#ffb3a3", "iSword", 6))
    b.append('<ellipse cx="595" cy="268" rx="58" ry="12" fill="none" stroke="url(#goldHot)" stroke-width="3" filter="url(#glow)"/>')
    b.append('''<g transform="translate(535 130)"><ellipse cx="60" cy="138" rx="46" ry="8" fill="#2b1b0c" opacity="0.5"/>
<path d="M32 136 C28 96 36 62 60 56 C84 62 92 96 88 136Z" fill="#8a6a3a" stroke="#4a3220" stroke-width="2"/>
<path d="M40 30 L34 8 L50 22 M80 30 L86 8 L70 22" fill="#8a6a3a" stroke="#4a3220" stroke-width="2"/>
<ellipse cx="60" cy="40" rx="24" ry="20" fill="#a07c48" stroke="#4a3220" stroke-width="2"/><path d="M92 60 L112 30" stroke="#6b6b6b" stroke-width="6"/></g>''')
    b.append(f'<text x="640" y="168" text-anchor="middle" {FT} font-size="32" fill="#ffffff" stroke="#7a2a1e" stroke-width="5" paint-order="stroke" filter="url(#txt)">−9</text>')
    b.append(hpbar(527, 288, 136, 5, 14, flash=14))
    b.append(f'<text x="595" y="322" text-anchor="middle" {FB} font-weight="700" font-size="13.5" fill="#f3e6c8" filter="url(#txt)">Gnoll Rivepatte</text>')
    b.append(token(595, 342, "#c79bf2", G_PAIN, 4))
    # --- ennemi 2 (guette)
    b.append(intent(765, 116, "#b77bea", "#e3c6ff", "iEye", "Guette"))
    b.append('''<g transform="translate(711 158) scale(0.9)"><ellipse cx="60" cy="138" rx="46" ry="8" fill="#2b1b0c" opacity="0.5"/>
<path d="M30 136 C30 100 40 64 60 58 C80 64 90 100 90 136Z" fill="#5d4a7a" stroke="#2f2440" stroke-width="2"/>
<path d="M40 30 L34 8 L50 22 M80 30 L86 8 L70 22" fill="#8a6a3a" stroke="#4a3220" stroke-width="2"/>
<ellipse cx="60" cy="40" rx="22" ry="19" fill="#a07c48" stroke="#4a3220" stroke-width="2"/><path d="M22 140 V40" stroke="#6b4a22" stroke-width="5"/><circle cx="22" cy="34" r="9" fill="#c58cf0"/></g>''')
    b.append(hpbar(701, 300, 128, 12, 12))
    b.append(f'<text x="765" y="334" text-anchor="middle" {FB} font-weight="700" font-size="13.5" fill="#f3e6c8" filter="url(#txt)">Mystique Rivepatte</text>')
    # --- ennemi 3 (se défend)
    b.append(intent(935, 92, "#7fb6e8", "#cfe5ff", "iShield", 6))
    b.append('''<g transform="translate(875 134)"><ellipse cx="60" cy="138" rx="46" ry="8" fill="#2b1b0c" opacity="0.5"/>
<path d="M34 136 C32 100 40 66 60 60 C80 66 88 100 86 136Z" fill="#3a3a44" stroke="#1c1c22" stroke-width="2"/>
<circle cx="60" cy="38" r="20" fill="#e8c9a0" stroke="#4a3220" stroke-width="2"/><path d="M40 42 H80 V54 L60 62 L40 54Z" fill="#b3402e" stroke="#6b1e14" stroke-width="2"/>
<path d="M90 96 L112 70" stroke="#9a9a9a" stroke-width="5"/></g>''')
    b.append(hpbar(867, 292, 136, 13, 18))
    b.append(f'<text x="935" y="326" text-anchor="middle" {FB} font-weight="700" font-size="13.5" fill="#f3e6c8" filter="url(#txt)">Bandit défias</text>')
    # --- plateau
    b.append(table())
    b.append('<g transform="translate(92 492)"><circle r="47" fill="#120b07" filter="url(#shadow)"/><circle r="44" fill="none" stroke="url(#gold)" stroke-width="5"/><circle r="40.5" fill="url(#mana)"/>'
             '<ellipse cx="-10" cy="-20" rx="22" ry="11" fill="#ffffff" opacity="0.28"/><circle r="40.5" fill="none" stroke="#0d1f44" stroke-opacity="0.6" stroke-width="1.5"/>'
             f'<text x="0" y="11" text-anchor="middle" {FT} font-size="30" fill="#ffffff" filter="url(#txt)">2/3</text>'
             '<g transform="translate(36 30)"><circle r="16.5" fill="#120b07"/><circle r="15" fill="url(#void)" stroke="#e6c8ff" stroke-width="1.5"/>'
             f'<text x="0" y="5.5" text-anchor="middle" {FT} font-size="15" fill="#ffffff" filter="url(#txt)">3</text></g></g>')
    b.append(pile(44, 552, 7))
    b.append(pile(104, 552, 3, faded=True))
    b.append(card(196, 452, "Châtiment", 1, "common", "mHoly", "gSun", ["Inflige **6**."]))
    b.append(card(326, 438, "Pénitence", 2, "uncommon", "mHoly", "gStars", ["Inflige **6** trois fois.", "Sous **Expiation** :", "**2** Absorption par coup."]))
    b.append(card(598, 438, "Feu intérieur", 1, "common", "mWard", "gFlame", ["Gagne **5** Absorption."]))
    b.append(card(728, 452, "Esprit de rédemption", 3, "rare", "mHoly", "gWings", [], state="off", tag="Mana insuffisant", tsize=8.6))
    b.append(card(448, 368, "Attaque mentale", 1, "common", "mShadow", "gMind", ["Inflige **9**.", "**+2 Démence**."], scale=1.17, state="hover", tag="Recharge 1", tsize=10.6))
    # recharges
    for i, (n, col) in enumerate([(2, "#d9cfb4"), (1, "#43b24f")]):
        x = 890 + i * 56
        b.append(f'<g transform="translate({x} 446)" filter="url(#shadowSm)"><g filter="url(#grey)"><use href="#cardBack" width="42" height="60"/></g>'
                 f'<rect x="1.5" y="1.5" width="39" height="57" rx="4" fill="none" stroke="{col}" stroke-width="1.6"/>'
                 f'<circle cx="21" cy="30" r="13" fill="#120b07" fill-opacity="0.85" stroke="#d9cfb4" stroke-width="1.2"/>'
                 f'<text x="21" y="36" text-anchor="middle" {FT} font-size="17" fill="#fff3cf">{n}</text></g>')
    b.append(button(866, 528, 156, 52, "Fin du tour"))
    b.append('</g>')
    b.append(FRAME)
    return page("Combat — design précis", "\n".join(b))


def kit():
    def label(x, y, t):
        return f'<text x="{x}" y="{y}" {FT6} font-size="11.5" letter-spacing="1.6" fill="#b89a66">{t.upper()}</text><path d="M{x} {y + 6} h{len(t) * 9.5:.0f}" stroke="#6b4a22" stroke-width="1"/>'
    b = ['<g clip-path="url(#win)">', '<rect width="1040" height="620" fill="url(#table)"/><rect width="1040" height="620" filter="url(#grainWood)" opacity="0.7"/>']
    b.append(label(34, 38, "La carte"))
    b.append(card(40, 66, "Pénitence", 2, "uncommon", "mHoly", "gStars", ["Inflige **6** trois fois.", "Sous **Expiation** :", "**2** Absorption par coup."], scale=2.25))
    b.append(f'<text x="34" y="492" {FB} font-size="13.5" fill="#d9c8a0"><tspan x="34" dy="0">Châssis de bois, liseré à la couleur de la</tspan><tspan x="34" dy="18">rareté, bandeau du titre, médaillon cerclé</tspan><tspan x="34" dy="18">d\'or portant l\'icône du sort, gemme de coût.</tspan><tspan x="34" dy="18">L\'école se lit à la couleur du médaillon.</tspan></text>')
    b.append(label(350, 38, "Raretés"))
    b.append(card(350, 56, "Châtiment", 1, "common", "mHoly", "gSun", ["Inflige **6**."], scale=0.92))
    b.append(card(476, 56, "Nova sacrée", 1, "uncommon", "mHoly", "gNova", ["Inflige **3** à tous.", "**Récupération 3**."], scale=0.92))
    b.append(card(602, 56, "Esprit de rédemption", 3, "rare", "mHoly", "gWings", ["Une fois par combat,", "survit à **1 PV**."], scale=0.92, tsize=8.6))
    b.append(label(742, 38, "États"))
    b.append(card(746, 60, "Attaque mentale", 1, "common", "mShadow", "gMind", ["Inflige **9**.", "**+2 Démence**."], scale=0.92, state="hover", tag="Recharge 1", tsize=10.6))
    b.append(card(880, 56, "Châtiment", 1, "common", "mHoly", "gSun", ["Inflige **9**."], scale=0.92, up=True))
    b.append(f'<text x="803" y="242" text-anchor="middle" {FB} font-size="12.5" fill="#d9c8a0">survolée</text><text x="937" y="242" text-anchor="middle" {FB} font-size="12.5" fill="#d9c8a0">améliorée</text>')
    b.append(card(350, 262, "Feu intérieur", 3, "common", "mWard", "gFlame", [], scale=0.92, state="off", tag="Mana insuffisant"))
    b.append(f'<g transform="translate(476 262) scale(0.92)" filter="url(#shadowSm)"><use href="#cardBack" width="124" height="176"/></g>')
    b.append(f'<text x="407" y="446" text-anchor="middle" {FB} font-size="12.5" fill="#d9c8a0">injouable</text><text x="533" y="446" text-anchor="middle" {FB} font-size="12.5" fill="#d9c8a0">dos</text>')
    b.append(label(620, 276, "Boutons"))
    b.append(button(620, 296, 150, 48, "Fin du tour"))
    b.append(button(790, 296, 150, 48, "Fin du tour", kind="hot"))
    b.append(button(620, 364, 150, 48, "Fin du tour", kind="down"))
    b.append(button(790, 364, 150, 48, "Fin du tour", kind="off"))
    for x, y, t in [(695, 358, "repos"), (865, 358, "survol"), (695, 426, "enfoncé"), (865, 426, "inactif")]:
        b.append(f'<text x="{x}" y="{y}" text-anchor="middle" {FB} font-size="12" fill="#d9c8a0">{t}</text>')
    b.append(label(350, 478, "Intentions"))
    b.append(intent(382, 496, "#e2634c", "#ffb3a3", "iSword", 6))
    b.append(intent(452, 496, "#7fb6e8", "#cfe5ff", "iShield", 6))
    b.append(intent(540, 496, "#b77bea", "#e3c6ff", "iEye", "Guette"))
    b.append(label(620, 478, "Jetons d'état"))
    for i, (c, g, n) in enumerate([("#f0c75e", G_ATONE, 2), ("#7fd08a", G_REGEN, 3), ("#c79bf2", G_PAIN, 4), ("#e2634c", G_BREAK, 2)]):
        b.append(token(636 + i * 38, 512, c, g, n))
    b.append(f'<text x="620" y="548" {FB} font-size="12.5" fill="#d9c8a0">Pictogramme et valeur ; le nom et la règle au survol.</text>')
    b.append(label(350, 560, "Barres et réserves"))
    b.append(hpbar(350, 580, 150, 52, 65, h=20))
    b.append(hpbar(520, 582, 130, 5, 14, flash=14))
    b.append('<use href="#flask" x="676" y="570" width="24" height="30" style="color:#d8472f"/><use href="#flask" x="706" y="570" width="24" height="30" style="color:#3f8be0"/><use href="#flaskEmpty" x="736" y="570" width="24" height="30"/>')
    b.append('<g transform="translate(812 586)"><circle r="20" fill="#120b07"/><circle r="18.5" fill="none" stroke="url(#gold)" stroke-width="2.6"/><circle r="16.5" fill="url(#mana)"/>'
             f'<text x="0" y="6" text-anchor="middle" {FT} font-size="15" fill="#ffffff" filter="url(#txt)">2/3</text></g>')
    b.append('<g transform="translate(862 586)"><circle r="16.5" fill="#120b07"/><circle r="15" fill="url(#void)" stroke="#e6c8ff" stroke-width="1.5"/>'
             f'<text x="0" y="5.5" text-anchor="middle" {FT} font-size="15" fill="#ffffff" filter="url(#txt)">3</text></g>')
    b.append(pile(900, 560, 7))
    b.append(pile(956, 560, 3, faded=True))
    b.append('</g>')
    b.append(FRAME)
    return page("Éléments — design précis", "\n".join(b))


(OUT / "CombatFinal.dc.html").write_text(combat())
(OUT / "Kit.dc.html").write_text(kit())
# aperçus bruts
for n, f in (("CombatFinal", combat), ("Kit", kit)):
    html = f()
    svg = html[html.index("<svg"):html.index("</svg>") + 6].replace("<svg ", '<svg xmlns="http://www.w3.org/2000/svg" ', 1)
    (OUT.parent / f"{n}.svg").write_text(svg)
