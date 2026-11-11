"""Ombre de contact des personnages (sous les pieds des modèles des scènes), dessinée par Pillow.

Usage : build/venv/bin/python -I tools/build_shadow.py [planche]

Écrit Media/shadow_soft.tga : disque BLANC (teinté en noir par UI/Scene.lua, couleur de sommet) dont
l'alpha suit un dégradé radial doux, 255 au centre, 1 - smoothstep(r) vers le bord, nul à partir du
rayon 62 px (toute la bordure de la toile 128 × 128 est à alpha 0 : aucun rectangle ne se voit, même
étiré et filtré). TGA 32 bits non compressé, origine en bas à gauche, 8 bits d'alpha, même écriture que
tools/build_media.py (qui n'est ni appelé ni modifié : les textures existantes ne changent pas).
La texture est carrée ; l'interface l'aplatit (rapport 3,5:1). Aperçu : build/media_png/shadow_soft.png ;
`planche` écrit aussi build/shadow_planche.png (ombre en deux couches, aplatie, sur fonds clair et sombre).
"""
import os
import struct
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIZE = 128         # toile (puissance de deux)
RADIUS = 62.0      # alpha nul au-delà (centres des pixels du bord à 63,5 du centre)


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


def shadow():
    """Alpha(r) = 1 - smoothstep(0, 1, r), r = distance au centre / RADIUS (pente nulle au centre et au
    bord : ni pointe, ni lisière)."""
    c = (SIZE - 1) / 2
    alpha = Image.new("L", (SIZE, SIZE), 0)
    px = alpha.load()
    for y in range(SIZE):
        for x in range(SIZE):
            r = ((x - c) ** 2 + (y - c) ** 2) ** 0.5 / RADIUS
            if r < 1:
                px[x, y] = int(round(255 * (1 - r * r * (3 - 2 * r))))
    im = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    im.putalpha(alpha)
    border = [alpha.getpixel((i, j)) for i in range(SIZE) for j in (0, SIZE - 1)]
    border += [alpha.getpixel((j, i)) for i in range(SIZE) for j in (0, SIZE - 1)]
    assert max(border) == 0, "bord de la toile non transparent"
    return im


def planche(im):
    """Ombre en deux couches comme UI/Scene.lua (pénombre 0,74 × 0,25, cœur 0,46 × 0,44, rapport
    3,5:1) pour un cadre de 150 unités, agrandie ×3, sur un fond clair puis sombre."""
    w = 150
    layers = [(0.74, 0.25), (0.46, 0.44)]
    k = 3
    tiles = []
    for bg in ((196, 178, 140), (52, 58, 46)):
        tile = Image.new("RGBA", (w * k, 60 * k), bg + (255,))
        for frac, a in layers:
            lw = int(w * frac * k)
            lh = int(lw / 3.5)
            lay = im.resize((lw, lh), Image.BILINEAR)
            black = Image.new("RGBA", lay.size, (0, 0, 0, 0))
            black.putalpha(lay.getchannel("A").point(lambda v: int(v * a)))
            tile.alpha_composite(black, ((w * k - lw) // 2, (60 * k - lh) // 2))
        tiles.append(tile)
    sheet = Image.new("RGBA", (w * k * 2, 60 * k))
    for i, t in enumerate(tiles):
        sheet.paste(t, (i * w * k, 0))
    return sheet


def main():
    im = shadow()
    out = os.path.join(ROOT, "Media", "shadow_soft.tga")
    write_tga(im, out)
    png = os.path.join(ROOT, "build", "media_png", "shadow_soft.png")
    os.makedirs(os.path.dirname(png), exist_ok=True)
    im.save(png)
    print("écrit", os.path.relpath(out, ROOT), "et", os.path.relpath(png, ROOT))
    if "planche" in sys.argv[1:]:
        p = os.path.join(ROOT, "build", "shadow_planche.png")
        planche(im).save(p)
        print("planche", os.path.relpath(p, ROOT))


if __name__ == "__main__":
    main()
