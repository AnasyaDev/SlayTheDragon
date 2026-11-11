"""Petites icônes en ligne du texte des cartes (séquence |T…|t de WoW), dessinées par Pillow.

Usage : build/venv/bin/python -I tools/build_glyphs.py [planche]

Écrit Media/hourglass.tga (sablier des durées en tours : « Donne Expiation 1 ⌛ ») : TGA 32 bits non
compressé, origine en bas à gauche, 8 bits d'alpha, toile en puissances de deux, même écriture que
tools/build_media.py (qui n'est ni appelé ni modifié : les textures existantes ne changent pas).
L'icône est BLANCHE (teinte posée par la séquence |T, couleur de sommet r:g:b) sur fond transparent
dont la couleur est saignée (blanc), centrée dans un carré 32 × 32 (x 5 à 27) ; l'interface n'en montre que x 0 à 28 (la marge de
gauche sert d'espace avant l'icône dans le texte). Aperçu : build/media_png/hourglass.png ; `planche` écrit
aussi build/hourglass_planche.png (rendus à 8, 10, 12, 16 px sur l'ardoise des cartes).
"""
import os
import struct
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIZE = 32          # toile (puissance de deux)
SS = 8             # suréchantillonnage du dessin


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


def hourglass():
    """Sablier plein, formes épaisses (lisible à 10 px) : deux traverses, verre en contour épais,
    sable tombé en bas, filet de sable au col. Coordonnées en unités de la toile 32 × 32."""
    S = SIZE * SS
    m = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(m)

    def P(x, y):
        return (x * SS, y * SS)

    # traverses (haut et bas), coins arrondis
    d.rounded_rectangle([P(5.0, 1.0), P(27.0, 5.2)], radius=1.6 * SS, fill=255)
    d.rounded_rectangle([P(5.0, 26.8), P(27.0, 31.0)], radius=1.6 * SS, fill=255)
    # verre : silhouette extérieure moins l'intérieur (contour d'environ 3 unités)
    outer = [P(7.0, 5.0), P(25.0, 5.0), P(25.0, 8.6), P(19.0, 16.0), P(25.0, 23.4), P(25.0, 27.0),
             P(7.0, 27.0), P(7.0, 23.4), P(13.0, 16.0), P(7.0, 8.6)]
    inner = [P(10.2, 5.0), P(21.8, 5.0), P(21.8, 7.6), P(16.0, 14.4), P(10.2, 7.6)]
    inner2 = [P(16.0, 17.6), P(21.8, 24.4), P(21.8, 27.0), P(10.2, 27.0), P(10.2, 24.4)]
    d.polygon(outer, fill=255)
    d.polygon(inner, fill=0)
    d.polygon(inner2, fill=0)
    # sable : reste en haut, tas en bas
    d.polygon([P(12.0, 9.0), P(20.0, 9.0), P(16.0, 13.6)], fill=255)
    d.polygon([P(16.0, 20.0), P(21.0, 26.0), P(11.0, 26.0)], fill=255)
    alpha = m.resize((SIZE, SIZE), Image.LANCZOS)
    im = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    im.putalpha(alpha)
    return im


def main():
    im = hourglass()
    out = os.path.join(ROOT, "Media", "hourglass.tga")
    write_tga(im, out)
    png = os.path.join(ROOT, "build", "media_png", "hourglass.png")
    os.makedirs(os.path.dirname(png), exist_ok=True)
    im.save(png)
    print("écrit", os.path.relpath(out, ROOT), "et", os.path.relpath(png, ROOT))
    if "planche" in sys.argv[1:]:
        # rendus réduits (bilinéaire, comme une texture sans mipmap) sur l'ardoise, agrandis ×8 pour juger
        sizes = [8, 10, 12, 16]
        cell = 16 * 8
        sheet = Image.new("RGBA", (cell * len(sizes), cell), (32, 37, 48, 255))
        for i, s in enumerate(sizes):
            small = im.resize((s, s), Image.BILINEAR)
            tile = Image.new("RGBA", (16, 16), (32, 37, 48, 255))
            tile.alpha_composite(small, ((16 - s) // 2, (16 - s) // 2))
            sheet.paste(tile.resize((cell, cell), Image.NEAREST), (i * cell, 0))
        p = os.path.join(ROOT, "build", "hourglass_planche.png")
        sheet.save(p)
        print("planche", os.path.relpath(p, ROOT))


if __name__ == "__main__":
    main()
