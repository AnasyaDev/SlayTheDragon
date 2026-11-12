"""Petites icônes en ligne du texte des cartes (séquence |T…|t de WoW), dessinées par Pillow.

Usage : build/venv/bin/python -I tools/build_glyphs.py [planche]
(Pillow et numpy suffisent ; `python3 -I` convient s'ils sont installés.)

Écrit Media/hourglass.tga (sablier des durées en tours : « Apply Stunned 1 ⌛ ») : TGA 32 bits non
compressé, origine en bas à gauche, 8 bits d'alpha, toile en puissances de deux, même écriture que
tools/build_media.py (qui n'est ni appelé ni modifié : les textures existantes ne changent pas).
L'icône est BLANCHE (teinte posée par la séquence |T, couleur de sommet r:g:b) sur fond transparent
dont la couleur est saignée (blanc). Toile 64 × 64, dessin centré, marges transparentes SYMÉTRIQUES
(x 11 à 53, y 2 à 62) : l'interface l'affiche entière et carrée (UI/Widgets.lua, W.hourglass), sans
rognage ; la marge de gauche fait la petite espace avant l'icône, celle de droite l'espace après.

Dessin pour 5 à 9 pixels de haut (texte de 7 à 10 unités, fenêtre à 115 %) : silhouette PLEINE,
deux traverses épaisses et deux triangles opposés (pointe contre pointe), sans détail intérieur,
séparés des traverses par un mince jour transparent ; aucun trait plus fin que 8 texels (1 pixel à
8 pixels de haut). Retour du joueur (12/11/2026) : l'ancien dessin (32 × 32, verre en contour de
3 texels, sable, rogné à 28/32) n'était à l'écran qu'une tache floue et rognée.

Aperçu : build/media_png/hourglass.png ; `planche` écrit build/sablier_planche.png : le sablier
avant / après à 6, 7, 8, 10 et 12 pixels de haut sur l'ardoise des cartes, après le chiffre « 1 » de
Baloo Chettan 2 à la taille correspondante, réduit sans mipmap (échantillonnage bilinéaire au centre
des pixels, le pire cas) et avec (moyenne par zone), agrandi ×8 pour juger.
"""
import os
import struct
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIZE = 64          # toile (puissance de deux)
SS = 8             # suréchantillonnage du dessin
K = 0.70           # hauteur de l'icône / taille du texte (W.HOURGLASS_K de UI/Widgets.lua)


def write_tga(im, path):
    """Même écriture que tools/build_media.py : TGA 32 bits non compressé, origine en bas à gauche."""
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


def read_tga(path):
    """TGA 32 bits non compressé (origine en bas à gauche) -> image RGBA."""
    with open(path, "rb") as f:
        d = f.read()
    w, h = d[12] | d[13] << 8, d[14] | d[15] << 8
    im = Image.frombytes("RGBA", (w, h), d[18:18 + w * h * 4])
    b, g, r, a = im.split()
    return Image.merge("RGBA", (r, g, b, a)).transpose(Image.FLIP_TOP_BOTTOM)


def hourglass():
    """Sablier plein 64 × 64 : traverses (y 2–11 et 53–62, x 11–53), triangles opposés (base x 16–48,
    col de 6 texels à y 32), jour de 2 texels entre traverses et triangles."""
    S = SIZE * SS
    m = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(m)

    def P(x, y):
        return (x * SS, y * SS)

    d.rounded_rectangle([P(11, 2), P(53, 10.5)], radius=3 * SS, fill=255)
    d.rounded_rectangle([P(11, 53.5), P(53, 62)], radius=3 * SS, fill=255)
    d.polygon([P(14, 10), P(50, 10), P(50, 15), P(36, 30), P(36, 34), P(50, 49), P(50, 54),
               P(14, 54), P(14, 49), P(28, 34), P(28, 30), P(14, 15)], fill=255)
    alpha = m.resize((SIZE, SIZE), Image.LANCZOS)
    im = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    im.putalpha(alpha)
    return im


def sample_nomip(src, w, h):
    """Réduction comme une texture SANS mipmap : un échantillon bilinéaire au centre de chaque pixel."""
    import numpy as np
    a = np.asarray(src.convert("RGBA"), dtype=np.float32)
    sh, sw = a.shape[:2]
    out = np.zeros((h, w, 4), dtype=np.float32)
    for j in range(h):
        for i in range(w):
            x = (i + 0.5) * sw / w - 0.5
            y = (j + 0.5) * sh / h - 0.5
            x0, y0 = int(np.floor(x)), int(np.floor(y))
            fx, fy = x - x0, y - y0
            def px(xx, yy):
                xx, yy = min(max(xx, 0), sw - 1), min(max(yy, 0), sh - 1)
                return a[yy, xx]
            out[j, i] = (px(x0, y0) * (1 - fx) * (1 - fy) + px(x0 + 1, y0) * fx * (1 - fy)
                         + px(x0, y0 + 1) * (1 - fx) * fy + px(x0 + 1, y0 + 1) * fx * fy)
    return Image.fromarray(out.clip(0, 255).astype("uint8"), "RGBA")


def planche(new, old):
    """build/sablier_planche.png : avant / après, 6 à 12 px, sans et avec mipmap, agrandi ×8."""
    font_path = os.path.join(ROOT, "Media", "Fonts", "BalooChettan2-bold.ttf")
    slate = (32, 37, 48, 255)
    heights = [6, 7, 8, 10, 12]
    Z = 8
    cell_w, cell_h = 26, 18
    rows = [("avant, sans mipmap", "old", False), ("après, sans mipmap", "new", False),
            ("avant, avec mipmap", "old", True), ("après, avec mipmap", "new", True)]
    label_w = 230
    sheet = Image.new("RGBA", (label_w + cell_w * Z * len(heights), 40 + cell_h * Z * len(rows)), (12, 12, 14, 255))
    dl = ImageDraw.Draw(sheet)
    lab = ImageFont.truetype(font_path, 22)
    for ci, hpx in enumerate(heights):
        dl.text((label_w + ci * cell_w * Z + 8, 6), f"icône {hpx} px", font=lab, fill=(220, 220, 220))
    for ri, (name, which, mip) in enumerate(rows):
        dl.text((8, 40 + ri * cell_h * Z + cell_h * Z // 2 - 12), name, font=lab, fill=(220, 220, 220))
        for ci, hpx in enumerate(heights):
            tile = Image.new("RGBA", (cell_w, cell_h), slate)
            if which == "old":
                size = hpx / 0.68           # taille du texte qui donnait cette hauteur
                w = max(4, round(hpx * 28 / 32))
                src = old.crop((0, 0, 28, 32))
            else:
                size = hpx / K
                w = hpx
                src = new
            icon = src.resize((w, hpx), Image.BOX) if mip else sample_nomip(src, w, hpx)
            f = ImageFont.truetype(font_path, max(1, round(size)))
            d = ImageDraw.Draw(tile)
            base = cell_h - 4
            d.text((2, base), "1", font=f, fill=(255, 255, 255), anchor="ls")
            x = 2 + round(d.textlength("1", font=f))
            # icône centrée sur les chiffres (hauteur des chiffres : 0,62 cadratin au-dessus de la ligne de base)
            y = round(base - 0.62 * size / 2 - hpx / 2)
            tile.alpha_composite(icon, (x, y))
            big = tile.resize((cell_w * Z, cell_h * Z), Image.NEAREST)
            sheet.paste(big, (label_w + ci * cell_w * Z, 40 + ri * cell_h * Z))
    p = os.path.join(ROOT, "build", "sablier_planche.png")
    sheet.save(p)
    print("planche", os.path.relpath(p, ROOT))


def main():
    old = None
    old_path = os.path.join(ROOT, "build", "hourglass_avant.tga")
    if os.path.exists(old_path):
        old = read_tga(old_path)
    im = hourglass()
    out = os.path.join(ROOT, "Media", "hourglass.tga")
    write_tga(im, out)
    png = os.path.join(ROOT, "build", "media_png", "hourglass.png")
    os.makedirs(os.path.dirname(png), exist_ok=True)
    im.save(png)
    print("écrit", os.path.relpath(out, ROOT), "et", os.path.relpath(png, ROOT))
    if "planche" in sys.argv[1:]:
        if old is None:
            print("(build/hourglass_avant.tga absent : « git show <commit>:Media/hourglass.tga » pour l'avant ; avant = après)")
            old = im.resize((32, 32), Image.LANCZOS)
        planche(im, old)


if __name__ == "__main__":
    main()
