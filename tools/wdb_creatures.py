#!/usr/bin/env python3
"""Lecteur du cache de créatures du client (creaturecache.wdb), en lecture seule.

Usage : python3 -I tools/wdb_creatures.py [--cache FICHIER]... [--id N]... [--display N]... [mot ...]

Sans argument : toutes les créatures du cache (identifiant, nom, sous-titre, affichages).
Avec des mots : celles dont le nom ou le sous-titre contient l'un d'eux (sans casse).
--id / --display : filtrent par identifiant de créature ou d'affichage.
Par défaut, lit les caches enUS et frFR du client Forever.

Format (constaté sur le client Forever, build 71912) : en-tête de 24 octets (« BOMW », build,
langue inversée, trois entiers), puis des enregistrements { identifiant (u32), taille (u32), données }.
Les données sont la réponse du serveur à la requête de créature : longueurs, nom(s) en chaînes
terminées par zéro, drapeaux, puis le bloc des affichages
{ nombre (u32), probabilité totale (f32), nombre × { affichage (u32), échelle (f32), probabilité (f32) } },
puis le sous-titre. Le bloc des affichages est repéré par sa forme (cohérence des flottants), pas
par un décalage fixe : le lecteur reste juste si quelques champs changent de taille.
"""
import argparse
import struct
import sys

FOREVER = "/mnt/Games/World of Warcraft/_forever_/Cache/WDB/"
DEFAULT_CACHES = [FOREVER + "enUS/creaturecache.wdb", FOREVER + "frFR/creaturecache.wdb"]
HEADER = 24


def strings(data, minlen=3):
    """Chaînes imprimables terminées par zéro, avec au moins deux lettres (pas les octets d'un
    flottant comme « @@ ») : liste de (début, fin, texte)."""
    out, start = [], None
    for i, b in enumerate(data):
        printable = 32 <= b < 127 or b >= 0x80  # ASCII ou octets UTF-8 (frFR)
        if printable and start is None:
            start = i
        elif not printable:
            if start is not None and b == 0 and i - start >= minlen:
                try:
                    text = data[start:i].decode("utf-8")
                    if sum(ch.isalpha() for ch in text) >= 2:
                        out.append((start, i, text))
                except UnicodeDecodeError:
                    pass
            start = None
    return out


def displays_at(data, off):
    """Bloc d'affichages à off, ou None s'il n'en a pas la forme."""
    if off + 8 > len(data):
        return None
    n, total = struct.unpack_from("<If", data, off)
    if not 1 <= n <= 8 or not 0.0 <= total <= 1000.0:
        return None
    if off + 8 + 12 * n > len(data):
        return None
    out, psum = [], 0.0
    for k in range(n):
        did, scale, prob = struct.unpack_from("<Iff", data, off + 8 + 12 * k)
        if not 0 < did < 2000000 or not 0.05 <= scale <= 20.0 or not 0.0 <= prob <= 1000.0:
            return None
        out.append((did, round(scale, 3), round(prob, 3)))
        psum += prob
    if abs(psum - total) > 0.01:
        return None
    return out


def parse_record(cid, data):
    strs = strings(data)
    name = strs[0][2] if strs else ""
    after = strs[0][1] if strs else 0
    disp = None
    for off in range(after, len(data) - 8):
        disp = displays_at(data, off)
        if disp:
            after_disp = off + 8 + 12 * len(disp)
            break
    title = ""
    if disp:
        for s, _, t in strs[1:]:
            if s >= after_disp:
                title = t
                break
    return {"id": cid, "name": name, "title": title, "displays": disp or []}


def read_cache(path):
    with open(path, "rb") as fh:
        blob = fh.read()
    if blob[:4] != b"BOMW":
        raise SystemExit(path + " : pas un fichier WDB (magie " + repr(blob[:4]) + ")")
    build = struct.unpack_from("<I", blob, 4)[0]
    locale = blob[8:12][::-1].decode("ascii", "replace")
    out, off = [], HEADER
    while off + 8 <= len(blob):
        cid, size = struct.unpack_from("<II", blob, off)
        if cid == 0 and size == 0:
            break
        data = blob[off + 8:off + 8 + size]
        off += 8 + size
        out.append(parse_record(cid, data))
    return build, locale, out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--cache", action="append", help="fichier creaturecache.wdb (répétable)")
    ap.add_argument("--id", type=int, action="append", default=[])
    ap.add_argument("--display", type=int, action="append", default=[])
    ap.add_argument("words", nargs="*")
    a = ap.parse_args()
    words = [w.lower() for w in a.words]
    for path in a.cache or DEFAULT_CACHES:
        try:
            build, locale, recs = read_cache(path)
        except FileNotFoundError:
            print("# absent : " + path)
            continue
        print("# %s : build %d, %s, %d créatures" % (path, build, locale, len(recs)))
        for r in sorted(recs, key=lambda r: r["id"]):
            text = (r["name"] + " " + r["title"]).lower()
            dids = [d[0] for d in r["displays"]]
            if words and not any(w in text for w in words):
                continue
            if a.id and r["id"] not in a.id:
                continue
            if a.display and not any(d in dids for d in a.display):
                continue
            disp = ", ".join("%d (x%g, p%g)" % d for d in r["displays"]) or "?"
            title = (" <" + r["title"] + ">") if r["title"] else ""
            print("%6d  %s%s : %s" % (r["id"], r["name"], title, disp))


if __name__ == "__main__":
    sys.exit(main())
