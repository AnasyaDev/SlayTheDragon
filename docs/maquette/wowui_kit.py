#!/usr/bin/env python3
"""Boîte à outils des maquettes « habillage WoW » (Slay the Dragon).

Pièces d'interface de World of Warcraft téléchargées par FileDataID (wago.tools, CASC retail) dans
build/wowui/src, décodées en PNG dans build/wowui/png (tools/topng.py). Ce module :
  - décrit chaque pièce retenue (PIECES : fichier, FileDataID, région, découpe, usage) ;
  - fournit les primitives de composition (neuf tranches, trois tranches, bordure « backdrop »
    classique, textes, icônes, cartes du pack traduites).
Les coordonnées d'atlas viennent de l'index d'atlas du serveur MCP « wow » (build 12.1.5.70783),
c'est-à-dire de la table UiTextureAtlasMember.
"""
import pathlib, re, subprocess, functools
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageOps, ImageChops

REPO = pathlib.Path(__file__).resolve().parents[2]
B = REPO / "build" / "wowui"
PNG = B / "png"
FONTS = {
    "friz": B / "src" / "fonts" / "frizqt.ttf",          # fonts/frizqt__.ttf, FileDataID 615960
    "morpheus": B / "src" / "fonts" / "morpheus.ttf",    # fonts/morpheus.ttf, FileDataID 615962
    "baloo": pathlib.Path.home() / ".local/share/fonts/BalooChettan2.ttf",
}
ICONS = REPO / "build" / "media_png" / "Icons"
BACKS = REPO / "build" / "media_png" / "Backgrounds"
S = 2
W, H = 1040 * S, 620 * S


def P(v): return int(round(v * S))


# ---------------------------------------------------------------- pièces
# name: (fid, box or None, source, slicing, usage)
#   box = (x, y, w, h) dans la texture ; None = toute la texture
#   source = nom d'atlas (SetAtlas) ou chemin du fichier
PIECES = {
    # --- boutons
    "panel_button_up": (130828, (0, 0, 80, 22), "interface/buttons/ui-panel-button-up", "3 tranches (12|56|12)", "bouton rouge classique (UIPanelButtonTemplate 2004-2021)"),
    "panel_button_down": (130825, (0, 0, 80, 22), "interface/buttons/ui-panel-button-down", "3 tranches", "état enfoncé"),
    "panel_button_hl": (130826, (0, 0, 80, 22), "interface/buttons/ui-panel-button-highlight", "3 tranches, ADD", "survol"),
    "dialog_button_gold": (949700, None, "interface/buttons/ui-dialogbox-button-gold-up", "3 tranches", "bouton rouge à liseré d'or classique"),
    "red128_left": (1536801, (391, 911, 114, 128), "128-RedButton-Left", "3 tranches", "bouton rouge HD (UIPanelButtonTemplate depuis Dragonflight)"),
    "red128_center": (1536801, (0, 1, 64, 128), "_128-RedButton-Center", "3 tranches (centre répété)", "id."),
    "red128_right": (1536801, (1, 521, 292, 128), "128-RedButton-Right", "3 tranches", "id."),
    "goldred_left": (3856481, (295, 521, 114, 128), "128-GoldRedButton-Left", "3 tranches", "gros bouton rouge à liseré d'or (Fin du tour)"),
    "goldred_center": (3856481, (0, 1, 64, 128), "_128-GoldRedButton-Center", "3 tranches", "id."),
    "goldred_right": (3856481, (1, 521, 292, 128), "128-GoldRedButton-Right", "3 tranches", "id."),
    "goldred_hl": (3856481, (1, 391, 441, 128), "128-GoldRedButton-Highlight", "3 tranches, ADD", "survol"),
    "redbutton9_up": (6794983, (1, 261, 470, 128), "128-RedButton-Up (9-sliced)", "neuf tranches", "bouton rouge HD d'un seul tenant"),
    "red_exit": (4698972, (39, 1, 36, 38), "RedButton-Exit-2x", "entier", "bouton de fermeture moderne"),
    "minimize_up": (130832, None, "interface/buttons/ui-panel-minimizebutton-up", "entier", "bouton de fermeture classique (X)"),
    # --- cadres et fonds
    "dialog_border": (131072, None, "interface/dialogframe/ui-dialogbox-border", "backdrop (8 segments de 32)", "cadre de fenêtre classique (pierre/métal)"),
    "dialog_gold_border": (131076, None, "interface/dialogframe/ui-dialogbox-gold-border", "backdrop (8 × 32)", "cadre doré classique"),
    "dialog_bg_dark": (312922, None, "interface/dialogframe/ui-dialogbox-background-dark", "tuile 64", "fond sombre classique"),
    "dialog_bg": (131071, None, "interface/dialogframe/ui-dialogbox-background", "tuile 64", "fond gris translucide classique"),
    "dialog_header": (131080, (118, 2, 276, 78), "interface/dialogframe/ui-dialogbox-header", "3 tranches possibles", "plaque de titre classique"),
    "bg_marble": (374154, None, "interface/framegeneral/ui-background-marble", "tuile 256", "fond marbre"),
    "bg_rock": (374155, None, "interface/framegeneral/ui-background-rock", "tuile 1024", "fond roche des fenêtres modernes (ButtonFrameTemplate)"),
    "metal_tl": (2406979, (1, 1, 150, 150), "UI-Frame-Metal-CornerTopLeft-2x", "neuf tranches", "cadre métal moderne (PortraitFrame/ButtonFrame)"),
    "metal_tr": (2406979, (153, 1, 150, 150), "UI-Frame-Metal-CornerTopRight-2x", "neuf tranches", "id."),
    "metal_bl": (2406979, (153, 153, 64, 64), "UI-Frame-Metal-CornerBottomLeft-2x", "neuf tranches", "id."),
    "metal_br": (2406979, (219, 153, 64, 64), "UI-Frame-Metal-CornerBottomRight-2x", "neuf tranches", "id."),
    "metal_top": (2406987, (0, 1, 64, 150), "_UI-Frame-Metal-EdgeTop-2x", "bord répété", "id."),
    "metal_bottom": (2406987, (0, 153, 32, 64), "_UI-Frame-Metal-EdgeBottom-2x", "bord répété", "id."),
    "metal_left": (2406984, (1, 0, 150, 32), "!UI-Frame-Metal-EdgeLeft-2x", "bord répété", "id."),
    "metal_right": (2406984, (153, 0, 150, 32), "!UI-Frame-Metal-EdgeRight-2x", "bord répété", "id."),
    "diamond_tl": (3056750, (1, 521, 128, 128), "UI-Frame-DiamondMetal-CornerTopLeft-2x", "neuf tranches", "cadre des boîtes de dialogue modernes (menu du jeu)"),
    "diamond_tr": (3056750, (1, 651, 128, 128), "UI-Frame-DiamondMetal-CornerTopRight-2x", "neuf tranches", "id."),
    "diamond_bl": (3056750, (1, 261, 128, 128), "UI-Frame-DiamondMetal-CornerBottomLeft-2x", "neuf tranches", "id."),
    "diamond_br": (3056750, (1, 391, 128, 128), "UI-Frame-DiamondMetal-CornerBottomRight-2x", "neuf tranches", "id."),
    "diamond_top": (3056750, (0, 131, 128, 128), "_UI-Frame-DiamondMetal-EdgeTop-2x", "bord répété", "id."),
    "diamond_bottom": (3056750, (0, 1, 128, 128), "_UI-Frame-DiamondMetal-EdgeBottom-2x", "bord répété", "id."),
    "diamond_left": (3056755, (1, 0, 128, 128), "!UI-Frame-DiamondMetal-EdgeLeft-2x", "bord répété", "id."),
    "diamond_right": (3056755, (131, 0, 128, 128), "!UI-Frame-DiamondMetal-EdgeRight-2x", "bord répété", "id."),
    "diamond_hdr_l": (3058483, (1, 159, 128, 156), "UI-Frame-DiamondMetal-Header-CornerLeft-2x", "3 tranches", "en-tête du menu moderne"),
    "diamond_hdr_m": (3058483, (0, 1, 128, 156), "_UI-Frame-DiamondMetal-Header-Tile-2x", "3 tranches", "id."),
    "diamond_hdr_r": (3058483, (1, 317, 128, 156), "UI-Frame-DiamondMetal-Header-CornerRight-2x", "3 tranches", "id."),
    "df_corner_tl": (4699152, (1, 320, 166, 166), "Dragonflight-NineSlice-CornerTopLeft", "neuf tranches", "cadre argent à dragons (Dragonflight)"),
    "df_bg": (4699279, None, "UI-Frame-DragonFlight-BackgroundTile", "tuile 256", "fond pierre sombre Dragonflight"),
    "df_parch_wide": (4699152, (169, 448, 515, 438), "UI-Frame-DragonFlight-CardParchmentWider", "neuf tranches (bords brûlés)", "parchemin"),
    "neutral_corner": (2142239, (1, 593, 166, 166), "UI-Frame-Neutral-Corner", "neuf tranches (coin miroité)", "cadre bois et bronze « Neutral »"),
    "neutral_top": (2142239, (0, 88, 256, 30), "_UI-Frame-Neutral-TileTop", "bord répété", "id."),
    "neutral_bottom": (2142239, (0, 120, 256, 30), "_UI-Frame-Neutral-TileBottom", "bord répété", "id."),
    "neutral_left": (2142370, (1, 0, 30, 256), "!UI-Frame-Neutral-TileLeft", "bord répété", "id."),
    "neutral_right": (2142370, (33, 0, 30, 256), "!UI-Frame-Neutral-TileRight", "bord répété", "id."),
    "neutral_bg": (2142322, None, "UI-Frame-Neutral-BackgroundTile", "tuile 256", "fond planches de bois"),
    "neutral_title_l": (2142239, (1, 761, 202, 85), "UI-Frame-Neutral-TitleLeft", "3 tranches", "bandeau de titre bronze"),
    "neutral_title_m": (2142239, (0, 1, 128, 85), "_UI-Frame-Neutral-TitleMiddle", "3 tranches", "id."),
    "neutral_title_r": (2142239, (774, 263, 202, 85), "UI-Frame-Neutral-TitleRight", "3 tranches", "id."),
    "neutral_parch": (2142239, (1, 152, 254, 439), "UI-Frame-Neutral-CardParchment", "neuf tranches (bords brûlés)", "parchemin des plaques de réponse"),
    "neutral_parch_wide": (2142239, (257, 152, 515, 438), "UI-Frame-Neutral-CardParchmentWider", "neuf tranches (bords brûlés)", "parchemin de la carte des trajets"),
    "neutral_ribbon": (2142239, (649, 592, 281, 84), "UI-Frame-Neutral-Ribbon", "3 tranches", "ruban de titre"),
    "neutral_subtitle": (2142239, (1, 991, 207, 30), "UI-Frame-Neutral-Subtitle", "3 tranches", "plaque de nom"),
    "parch_tile": (1710518, None, "AdventureMap_TileBg_Parchment", "tuile 512", "parchemin de carte"),
    "parch_achiev": (130661, None, "interface/achievementframe/ui-achievement-parchment-horizontal", "étirable", "parchemin classique"),
    "questbg": (530420, None, "interface/questframe/questbg", "entier", "parchemin du journal de quêtes"),
    "quest_tl": (136793, None, "interface/questframe/ui-questgreeting-topleft", "4 quarts (384 × 512)", "fenêtre de PNJ classique (portrait + parchemin)"),
    "quest_tr": (136794, None, "interface/questframe/ui-questgreeting-topright", "4 quarts", "id."),
    "quest_bl": (136791, None, "interface/questframe/ui-questgreeting-botleft", "4 quarts", "id."),
    "quest_br": (136792, None, "interface/questframe/ui-questgreeting-botright", "4 quarts", "id."),
    "taxi_tl": (137041, None, "interface/taxiframe/ui-taxiframe-topleft", "4 quarts", "fenêtre de la carte des trajets classique"),
    "tooltip_border": (137057, None, "interface/tooltips/ui-tooltip-border", "backdrop (8 × 16)", "bordure d'infobulle classique"),
    "tooltip_bg": (137056, None, "interface/tooltips/ui-tooltip-background", "tuile", "fond d'infobulle (teinté)"),
    "tooltip9_corners": (4185447, (0, 0, 32, 64), "Tooltip-NineSlice-Corner*/EdgeTop/Bottom", "neuf tranches (7 px)", "infobulle moderne"),
    "tooltip9_sides": (4185474, None, "!Tooltip-NineSlice-EdgeLeft/Right", "neuf tranches", "id."),
    # --- cases d'icônes
    "quickslot2": (130841, None, "interface/buttons/ui-quickslot2", "entier (icône = 36/64)", "case de barre d'action classique"),
    "quickslot": (130840, None, "interface/buttons/ui-quickslot", "entier", "fond de case vide classique"),
    "emptyslot": (130766, None, "interface/buttons/ui-emptyslot", "entier", "case vide (sac)"),
    "actionbutton_border": (130739, None, "interface/buttons/ui-actionbutton-border", "entier, ADD teinté", "liseré de qualité (vert/bleu/violet)"),
    "whiteiconframe": (651080, None, "interface/common/whiteiconframe", "entier, teinté", "bordure d'objet par qualité"),
    "df_iconframe": (4615764, (359, 649, 92, 90), "UI-HUD-ActionBar-IconFrame-2x", "entier", "case de barre d'action moderne"),
    "df_iconslot": (4615764, (359, 209, 128, 124), "UI-HUD-ActionBar-IconFrame-Slot-2x", "entier", "fond de case moderne"),
    "bag_border": (4691255, (295, 1, 61, 61), "bag-border-2x", "entier", "case de sac moderne"),
    "bag_main": (4691255, (1, 1, 96, 96), "bag-main-2x", "entier", "sac à dos (pioche)"),
    "tracking_border": (136430, (0, 0, 40, 38), "interface/minimap/minimap-trackingborder", "entier", "anneau d'or des boutons de minicarte"),
    # --- étapes du parcours
    "taxi_frame_gray": (1455734, (1, 35, 74, 74), "taxi_frame_gray", "entier", "nœud de vol (botte ailée) : étape future"),
    "taxi_frame_green": (1455734, (1, 111, 74, 74), "taxi_frame_green", "entier", "nœud de vol : étape accessible"),
    "taxi_frame_yellow": (1455734, (1, 187, 74, 74), "taxi_frame_yellow", "entier", "nœud de vol : position actuelle"),
    "taxi_line": (1455735, (1, 0, 32, 32), "!UI-Taxi-Line", "répété", "trait de trajet"),
    "taxi_icon_green": (137033, None, "interface/taxiframe/ui-taxi-icon-green", "entier (16 px)", "pastille d'étape franchie (barre de progression)"),
    "taxi_icon_yellow": (137037, None, "interface/taxiframe/ui-taxi-icon-yellow", "entier (16 px)", "pastille d'étape actuelle"),
    "taxi_icon_gray": (137032, None, "interface/taxiframe/ui-taxi-icon-gray", "entier (16 px)", "pastille d'étape future"),
    "taxi_icon_red": (137035, None, "interface/taxiframe/ui-taxi-icon-red", "entier (16 px)", "pastille du boss"),
    "taxinode_neutral": (1121272, (649, 896, 32, 32), "TaxiNode_Neutral", "entier", "point de vol"),
    "vignettekill": (1121272, (863, 197, 64, 64), "VignetteKill", "entier", "étape combat (épées)"),
    "vignettekillelite": (1121272, (203, 659, 64, 64), "VignetteKillElite", "entier", "étape élite"),
    "vignetteevent": (1121272, (599, 197, 64, 64), "VignetteEvent", "entier", "étape événement"),
    "questnormal": (1121272, (137, 527, 64, 64), "QuestNormal", "entier", "point d'exclamation (événement)"),
    "innkeeper": (1121272, (479, 726, 32, 32), "Innkeeper", "entier", "auberge (feu de camp)"),
    "banker": (1121272, (445, 454, 32, 32), "Banker", "entier", "marchand"),
    "dungeon": (1121272, (269, 385, 50, 50), "Dungeon", "entier", "boss (entrée de donjon)"),
    "questskull": (1121272, (615, 692, 32, 32), "questskull", "entier", "crâne d'élite"),
    "raid_skull": (137009, (192, 64, 64, 64), "interface/targetingframe/ui-raidtargetingicons (crâne)", "entier", "crâne d'élite classique"),
    "elite_gold": (1300837, (1, 1, 80, 80), "nameplates-icon-elite-gold", "entier", "dragon d'or (élite / boss)"),
    "elite_silver": (1300837, (83, 1, 80, 80), "nameplates-icon-elite-silver", "entier", "dragon d'argent (élite)"),
    "talent_circle_yellow": (4556093, (1389, 110, 50, 50), "talents-node-circle-yellow", "entier", "nœud de talent (étape franchie)"),
    "talent_circle_green": (4556093, (219, 621, 50, 50), "talents-node-circle-green", "entier", "nœud de talent (accessible)"),
    "talent_circle_gray": (4556093, (219, 569, 50, 50), "talents-node-circle-gray", "entier", "nœud de talent (future)"),
    "talent_square_yellow": (4556093, (1094, 750, 80, 80), "talents-node-square-yellow", "entier", "nœud carré (élite franchie)"),
    "talent_square_gray": (4556093, (1005, 819, 80, 80), "talents-node-square-gray", "entier", "nœud carré (élite)"),
    "talent_square_green": (4556093, (1005, 901, 80, 80), "talents-node-square-green", "entier", "nœud carré accessible"),
    "talent_choice_gray": (4556093, (759, 793, 116, 104), "talents-node-choice-gray", "entier", "nœud octogonal (événement)"),
    "talent_choice_green": (4556093, (759, 899, 116, 104), "talents-node-choice-green", "entier", "nœud octogonal accessible"),
    "talent_choice_yellow": (4556093, (887, 387, 116, 104), "talents-node-choice-yellow", "entier", "nœud octogonal franchi"),
    "talent_line_yellow": (4636998, (0, 55, 16, 16), "talents-arrow-line-yellow", "répété", "lien franchi"),
    "talent_line_gray": (4636998, (0, 19, 16, 16), "talents-arrow-line-gray", "répété", "lien futur"),
    "talents_bg_disc": (4631348, (1, 1, 1612, 774), "talents-background-priest-discipline", "étirable", "fond de l'arbre de talents"),
    "boss_winged": (4703662, (1, 1, 198, 162), "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold-Winged-2x", "entier", "anneau de boss ailé"),
    "elite_ring_classic": (137015, (150, 0, 106, 100), "interface/targetingframe/ui-targetingframe-elite (portrait)", "entier", "anneau de portrait élite classique (dragon d'or)"),
    # --- barres et cadres d'unité
    "statusbar": (137012, None, "interface/targetingframe/ui-statusbar", "étirable, teinté", "barre de vie/mana classique"),
    "target_frame": (137026, None, "interface/targetingframe/ui-targetingframe", "entier", "cadre de cible / joueur classique"),
    "nameplate_border": (137053, (0, 15, 128, 17), "interface/tooltips/nameplate-border", "3 tranches", "plaque de nom classique"),
    "skills_barborder": (136571, None, "interface/paperdollinfoframe/ui-character-skills-barborder", "3 tranches", "bordure de barre (compétences)"),
    "df_player": (4642466, (1, 171, 396, 142), "UI-HUD-UnitFrame-Player-PortraitOn-2x", "entier", "cadre du joueur moderne"),
    "df_player_hp": (4642466, (889, 415, 248, 40), "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health-2x", "étirable", "barre de vie moderne"),
    "df_player_mana": (4642466, (637, 501, 248, 20), "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana-2x", "étirable", "barre de mana moderne"),
    "df_boss_small": (4703662, (201, 1, 230, 112), "UI-HUD-UnitFrame-Target-Boss-Small-PortraitOff-2x", "entier", "cadre d'ennemi compact (boss) moderne"),
    "df_boss_hp": (4703662, (337, 165, 169, 20), "...-Boss-Small-PortraitOff-Bar-Health-2x", "étirable", "barre de vie compacte"),
    "essence": (4631565, (640, 360, 48, 48), "UF-Essence-Icon-Active-2x", "entier", "pastille de ressource (mana)"),
    "essence_off": (4631565, (640, 310, 48, 48), "UF-Essence-Icon-2x", "entier", "pastille vide"),
    "adv_healthbar": (3463360, (609, 1120, 89, 36), "adventure-healthbar", "3 tranches", "barre de vie de la table de commandement"),
    "adv_enemy_frame": (3463360, (221, 1865, 67, 67), "adventures-enemy-frame", "entier", "cadre rond d'ennemi"),
    # --- menus
    "checkbox_up": (130755, None, "interface/buttons/ui-checkbox-up", "entier", "case à cocher classique"),
    "checkbox_check": (130751, None, "interface/buttons/ui-checkbox-check", "entier", "coche classique"),
    "slider_border": (130859, None, "interface/buttons/ui-sliderbar-border", "backdrop (8 × 8)", "curseur classique"),
    "slider_thumb": (130860, None, "interface/buttons/ui-sliderbar-button-horizontal", "entier", "poignée de curseur classique"),
    "checkbox_min": (4614134, (1, 1, 30, 29), "checkbox-minimal", "entier", "case à cocher moderne"),
    "min_slider_l": (4567914, (14, 41, 11, 17), "Minimal_SliderBar_Left", "3 tranches", "curseur moderne"),
    "min_slider_m": (4567914, (0, 1, 1, 17), "_Minimal_SliderBar_Middle", "3 tranches", "id."),
    "min_slider_r": (4567914, (1, 62, 11, 17), "Minimal_SliderBar_Right", "3 tranches", "id."),
    "min_slider_thumb": (4567914, (1, 20, 20, 19), "Minimal_SliderBar_Button", "entier", "id."),
    "gold_icon": (237618, None, "interface/moneyframe/ui-goldicon", "entier", "pièce d'or (16 px)"),
    "coin_gold": (1667824, (197, 1, 20, 20), "coin-gold-20x20", "entier", "pièce d'or moderne"),
    "gossip_gossip": (132053, None, "interface/gossipframe/gossipgossipicon", "entier", "réponse de dialogue (bulle)"),
    "gossip_quest": (132049, None, "interface/gossipframe/availablequesticon", "entier", "réponse « quête » (!)"),
    "gossip_vendor": (132060, None, "interface/gossipframe/vendorgossipicon", "entier", "réponse « marchand » (sac)"),
    "gossip_binder": (132052, None, "interface/gossipframe/bindergossipicon", "entier", "réponse « auberge »"),
    "gossip_taxi": (132057, None, "interface/gossipframe/taxigossipicon", "entier", "réponse « vol »"),
    "portrait_hero": (135987, None, "interface/icons/spell_holy_wordfortitude", "entier", "portrait du héros (icône de prêtre, provisoire)"),
    "portrait_salma": (236447, None, "interface/icons/achievement_character_human_female", "entier", "portrait de PNJ (provisoire)"),
}


@functools.lru_cache(None)
def tex(fid): return Image.open(PNG / f"{fid}.png").convert("RGBA")


@functools.lru_cache(None)
def piece(name):
    fid, box = PIECES[name][0], PIECES[name][1]
    im = tex(fid)
    if box: im = im.crop((box[0], box[1], box[0] + box[2], box[1] + box[3]))
    return im


def native(name): return piece(name).size


# ---------------------------------------------------------------- polices et textes
@functools.lru_cache(None)
def font(name, px, w=None):
    f = ImageFont.truetype(str(FONTS[name]), max(1, round(px * S)))
    if w:
        try: f.set_variation_by_axes([w])
        except Exception: pass
    return f


def text(dst, x, y, s, px, fill=(255, 255, 255), face="friz", anchor="lm", w=None, shadow=True, outline=0, ocol=(0, 0, 0)):
    f = font(face, px, w); d = ImageDraw.Draw(dst)
    if shadow and not outline:
        d.text((P(x) + max(1, S), P(y) + max(1, S)), s, font=f, fill=(0, 0, 0, 220), anchor=anchor)
    d.text((P(x), P(y)), s, font=f, fill=fill, anchor=anchor, stroke_width=round(outline * S), stroke_fill=ocol)


def tw(s, px, face="friz", w=None):
    return font(face, px, w).getlength(s) / S


def wrap(s, px, width, face="friz", w=None):
    out, line = [], ""
    for word in s.split():
        t = (line + " " + word).strip()
        if tw(t, px, face, w) <= width: line = t
        else: out.append(line); line = word
    if line: out.append(line)
    return out


# ---------------------------------------------------------------- images
def rs(im, w, h): return im.resize((max(1, round(w)), max(1, round(h))), Image.LANCZOS)


def put(dst, im, x, y, anchor="mm"):
    """Colle im (déjà en pixels de sortie) ; x, y logiques."""
    px, py = P(x), P(y)
    if anchor[0] == "m": px -= im.width // 2
    elif anchor[0] == "r": px -= im.width
    if anchor[1] == "m": py -= im.height // 2
    elif anchor[1] == "b": py -= im.height
    dst.alpha_composite(im, (px, py))


def scaled(name, w=None, h=None):
    im = piece(name)
    if w and not h: h = im.height * w / im.width
    if h and not w: w = im.width * h / im.height
    return rs(im, P(w), P(h))


def tile(im, w, h, k=1.0):
    """Pavage de im (mis à l'échelle k) sur w × h pixels de sortie."""
    if k != 1.0: im = rs(im, im.width * k, im.height * k)
    out = Image.new("RGBA", (w, h))
    for y in range(0, h, im.height):
        for x in range(0, w, im.width): out.alpha_composite(im, (x, y))
    return out


def tint(im, rgb, k=1.0):
    r, g, b, a = im.split()
    base = Image.merge("RGB", (r, g, b))
    out = ImageChops.multiply(base, Image.new("RGB", im.size, rgb))
    if k != 1.0: out = out.point(lambda v: min(255, int(v * k)))
    out.putalpha(a); return out


def grey(im, k=0.6):
    r, g, b, a = im.split(); gr = ImageOps.grayscale(Image.merge("RGB", (r, g, b))).point(lambda v: int(v * k)).convert("RGB"); gr.putalpha(a); return gr


def alpha(im, k):
    im = im.copy(); im.putalpha(im.split()[3].point(lambda v: int(v * k))); return im


def add(dst, im, x, y):
    """Mélange additif (couches ADD des textures de surbrillance)."""
    box = (P(x), P(y), P(x) + im.width, P(y) + im.height)
    reg = dst.crop(box); r, g, b, a = im.split()
    lit = Image.merge("RGB", (r, g, b)); lit = ImageChops.multiply(lit, Image.merge("RGB", (a, a, a)))
    out = ImageChops.add(reg.convert("RGB"), lit); out.putalpha(reg.split()[3]); dst.paste(out, box[:2])


def shadow(im, blur=4, dy=3, a=170):
    pad = P(blur * 3); b = Image.new("RGBA", (im.width + 2 * pad, im.height + 2 * pad)); s = Image.new("RGBA", b.size)
    s.paste((0, 0, 0, a), (pad, pad + P(dy)), im.split()[3])
    b.alpha_composite(s.filter(ImageFilter.GaussianBlur(P(blur)))); b.alpha_composite(im, (pad, pad)); return b, pad


def put_sh(dst, im, x, y, blur=3, dy=2, a=170):
    b, pad = shadow(im, blur, dy, a); dst.alpha_composite(b, (P(x) - im.width // 2 - pad, P(y) - im.height // 2 - pad))


def three(l, m, r, w, h, lw=None, rw=None):
    """Trois tranches horizontales, hauteur h (pixels de sortie)."""
    k = h / l.height
    L = rs(l, (lw or l.width) * k if lw is None else lw, h); R = rs(r, r.width * k if rw is None else rw, h)
    out = Image.new("RGBA", (w, h)); mid = w - L.width - R.width
    if mid > 0: out.alpha_composite(rs(m, mid, h), (L.width, 0))
    out.alpha_composite(L, (0, 0)); out.alpha_composite(R, (w - R.width, 0)); return out


def three_cut(im, cl, cr, w, h):
    """Trois tranches prises dans une seule image (cl, cr : largeurs des bouts dans la source)."""
    return three(im.crop((0, 0, cl, im.height)), im.crop((cl, 0, im.width - cr, im.height)), im.crop((im.width - cr, 0, im.width, im.height)), w, h)


def nine_cut(im, l, t, r, b, w, h, k=1.0, center=True):
    """Neuf tranches d'une seule image ; k = pixels de sortie par pixel source pour les bords."""
    W0, H0 = im.size; out = Image.new("RGBA", (w, h))
    L, T, R, Bm = round(l * k), round(t * k), round(r * k), round(b * k)
    def seg(x0, y0, x1, y1, ow, oh):
        if ow <= 0 or oh <= 0: return None
        return rs(im.crop((x0, y0, x1, y1)), ow, oh)
    parts = [
        (seg(0, 0, l, t, L, T), 0, 0), (seg(W0 - r, 0, W0, t, R, T), w - R, 0),
        (seg(0, H0 - b, l, H0, L, Bm), 0, h - Bm), (seg(W0 - r, H0 - b, W0, H0, R, Bm), w - R, h - Bm),
        (seg(l, 0, W0 - r, t, w - L - R, T), L, 0), (seg(l, H0 - b, W0 - r, H0, w - L - R, Bm), L, h - Bm),
        (seg(0, t, l, H0 - b, L, h - T - Bm), 0, T), (seg(W0 - r, t, W0, H0 - b, R, h - T - Bm), w - R, T)]
    if center: parts.insert(0, (seg(l, t, W0 - r, H0 - b, w - L - R, h - T - Bm), L, T))
    for p, x, y in parts:
        if p is not None: out.alpha_composite(p, (x, y))
    return out


def tile_strip(im, length, horizontal=True):
    length = max(1, length)
    out = Image.new("RGBA", (length, im.height) if horizontal else (im.width, length))
    step = im.width if horizontal else im.height
    for i in range(0, length, step): out.alpha_composite(im, (i, 0) if horizontal else (0, i))
    return out


def nine_parts(w, h, tl, tr, bl, br, top, bottom, left, right, k=1.0):
    """Neuf tranches en pièces séparées (atlas NineSlice). k : échelle des pièces."""
    sc = lambda im: rs(im, im.width * k, im.height * k)
    tl, tr, bl, br, top, bottom, left, right = map(sc, (tl, tr, bl, br, top, bottom, left, right))
    out = Image.new("RGBA", (w, h))
    out.alpha_composite(tile_strip(top, w - tl.width - tr.width).crop((0, 0, w - tl.width - tr.width, top.height)), (tl.width, 0))
    out.alpha_composite(tile_strip(bottom, w - bl.width - br.width), (bl.width, h - bottom.height))
    out.alpha_composite(tile_strip(left, h - tl.height - bl.height, False), (0, tl.height))
    out.alpha_composite(tile_strip(right, h - tr.height - br.height, False), (w - right.width, tr.height))
    out.alpha_composite(tl, (0, 0)); out.alpha_composite(tr, (w - tr.width, 0))
    out.alpha_composite(bl, (0, h - bl.height)); out.alpha_composite(br, (w - br.width, h - br.height))
    return out


def backdrop(w, h, edge_name, edge, bg=None, bg_tile=None, inset=None, bgcol=None):
    """Bordure « backdrop » classique : le fichier d'arête contient 8 segments carrés
    (gauche, droite, haut, bas, coins HG, HD, BG, BD) ; haut et bas sont stockés tournés."""
    E = piece(edge_name); s = E.height
    seg = [E.crop((i * s, 0, (i + 1) * s, s)) for i in range(8)]
    e = P(edge); out = Image.new("RGBA", (w, h))
    ins = P(inset if inset is not None else edge / 3)
    if bgcol: ImageDraw.Draw(out).rectangle((ins, ins, w - ins, h - ins), fill=bgcol)
    if bg is not None:
        t = tile(piece(bg), w - 2 * ins, h - 2 * ins, bg_tile or 1.0)
        out.alpha_composite(t, (ins, ins))
    sc = lambda im: rs(im, e, e)
    L, R = sc(seg[0]), sc(seg[1]); T = sc(seg[2]).transpose(Image.ROTATE_270); Bt = sc(seg[3]).transpose(Image.ROTATE_270)
    out.alpha_composite(tile_strip(T, w - 2 * e), (e, 0)); out.alpha_composite(tile_strip(Bt, w - 2 * e), (e, h - e))
    out.alpha_composite(tile_strip(L, h - 2 * e, False), (0, e)); out.alpha_composite(tile_strip(R, h - 2 * e, False), (w - e, e))
    for i, (x, y) in zip(range(4, 8), [(0, 0), (w - e, 0), (0, h - e), (w - e, h - e)]):
        out.alpha_composite(sc(seg[i]), (x, y))
    return out


def icon(name, px, crop=0.07, round_=False, gray=False):
    im = Image.open(ICONS / f"{name.lower()}.png").convert("RGBA")
    k = int(im.width * crop); im = im.crop((k, k, im.width - k, im.height - k))
    im = rs(im, P(px), P(px))
    if gray: im = grey(im, 0.55)
    if round_:
        m = Image.new("L", im.size, 0); ImageDraw.Draw(m).ellipse((0, 0, im.width - 1, im.height - 1), fill=255); im.putalpha(m)
    return im


def disc(im):
    m = Image.new("L", im.size, 0); ImageDraw.Draw(m).ellipse((0, 0, im.width - 1, im.height - 1), fill=255)
    im = im.copy(); im.putalpha(ImageChops.multiply(im.split()[3], m)); return im


def ring(dst, cx, cy, d, gray=False):
    """Anneau d'or de la minicarte (MiniMap-TrackingBorder) autour d'une icône ronde de diamètre d."""
    r = rs(piece("tracking_border"), P(d * 40 / 24.5), P(d * 38 / 24.5))
    if gray: r = grey(r, 0.85)
    put(dst, r, cx + d * 0.01, cy + d * 0.02)


def background(name, y0=46, y1=424, dark=0.0):
    im = Image.open(BACKS / f"{name}.png").convert("RGBA")
    w, h = W, P(y1 - y0); k = max(w / im.width, h / im.height)
    im = rs(im, im.width * k, im.height * k); x = (im.width - w) // 2; y = (im.height - h) // 2
    im = im.crop((x, y, x + w, y + h))
    if dark: im.alpha_composite(Image.new("RGBA", im.size, (0, 0, 0, int(255 * dark))))
    return im


# ---------------------------------------------------------------- silhouettes (emplacements des modèles 3D)
def _vec(src, start, end):
    t = (pathlib.Path(__file__).parent / src).read_text(); return t[t.index(start):t.index(end)]


@functools.lru_cache(None)
def silhouettes():
    ns = {}; exec(_vec("gen_design.py", "HERO = ", "SCENE = "), ns)
    ns2 = {}; exec("ENEMY = " + _vec("gen_design2.py", "ENEMY = ", "def combat()")[8:], ns2)
    out = {}
    B.joinpath("_tmp").mkdir(exist_ok=True)
    items = {"hero": (ns["HERO"].replace('transform="translate(136 124)"', ''), 130, 180)}
    for k, v in ns2["ENEMY"].items(): items[k] = (f"<g>{v}</g>", 120, 150)
    for k, (svg, w, h) in items.items():
        p = B / "_tmp" / f"sil_{k}.svg"
        p.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w * S * 2}" height="{h * S * 2}">{svg}</svg>')
        subprocess.run(["rsvg-convert", str(p), "-o", str(p.with_suffix(".png"))], check=True)
        im = Image.open(p.with_suffix(".png")).convert("RGBA")
        a = im.split()[3]
        body = Image.new("RGBA", im.size, (18, 20, 30, 0)); body.putalpha(a.point(lambda v: int(v * 0.55)).filter(ImageFilter.GaussianBlur(3)))
        out[k] = body
    return out


def sil(dst, kind, cx, foot, height):
    im = silhouettes()[kind]; k = P(height) / im.height
    im = rs(im, im.width * k, im.height * k)
    dst.alpha_composite(im, (P(cx) - im.width // 2, P(foot) - im.height))


# ---------------------------------------------------------------- cartes du pack, traduites
TR = {
    "Forme d'ombre": "Shadowform", "+2 Démence.": "+[w]2[/w] Insanity.", "Ombre : dégâts": "[g]Shadow[/g]: damage",
    "et Douleur +3.": "and [g]Pain[/g] +[w]3[/w].", "Pouvoir": "Power", "Pénitence": "Penance",
    "Inflige 6 trois fois.": "Deal [w]6[/w] three times.", "Expiation :": "[g]Atonement[/g]:",
    "+2 Absorption par": "+[w]2[/w] Absorb per", "coup.": "hit.", "Pas assez de mana.": "Not enough mana.",
    "Esprit de rédemption+": "Spirit of Redemption+", "Dernier souffle :": "[g]Last Breath[/g]:",
    "reste à 1 PV,": "stay at [w]1[/w] HP,", "Récupération 6,": "[g]Recovery[/g] [w]6[/w],", "tour gratuit.": "free turn.",
    "MdP : Réconfort+": "PW: Solace+", "Inflige 8.": "Deal [w]8[/w].", "Expiation : +1 mana.": "[g]Atonement[/g]: +[w]1[/w] mana.",
    "Donne": "Grants", "Expiation": "[g]Atonement[/g]", "Attaque mentale": "Mind Blast", "Inflige 10.": "Deal [w]10[/w].",
    "Recharge 1": "Cooldown 1", "Châtiment": "Smite", "Inflige 6.": "Deal [w]6[/w].",
}
CARD_ORDER = ["shadowform", "penance", "spirit", "solace", "mindblast", "smite"]


def _markup(s):
    s = s.replace("[g]", '<tspan fill="#ffd660">').replace("[w]", '<tspan fill="#ffffff">')
    return "<tspan>" + re.sub(r"\[/[gw]\]", "</tspan>", s) + "</tspan>"


@functools.lru_cache(None)
def cards():
    """Rend les 6 cartes de build/snap/cartes.svg (aperçu du harnais) avec les textes en anglais."""
    src = (REPO / "build" / "snap" / "cartes.svg").read_text().splitlines()
    out = []
    for line in src:
        if line.startswith('<rect width="100%"') or 'fill="#f0f">cartes' in line: continue
        m = re.match(r'(<text [^>]*>)(.*)(</text>)$', line)
        if m:
            plain = re.sub(r"<[^>]+>", "", m.group(2))
            if plain in TR:
                new = TR[plain]; head = m.group(1)
                if plain == "Expiation": head = re.sub(r'x="86[0-9.]+"', lambda q: 'x="%.1f"' % (float(q.group(0)[3:-1]) - 13), head)
                body = re.sub(r"\[/?[gw]\]", "", new) if 'fill="#000"' in head else _markup(new)
                line = head + body + m.group(3)
        out.append(line)
    tmp = B / "_tmp"; tmp.mkdir(exist_ok=True)
    import shutil
    shutil.copytree(REPO / "build" / "snap" / "media", tmp / "media", dirs_exist_ok=True)
    p = tmp / "cartes_en.svg"; p.write_text("\n".join(out))
    subprocess.run(["rsvg-convert", "-z", "2", str(p), "-o", str(tmp / "cartes_en.png")], check=True)
    sheet = Image.open(tmp / "cartes_en.png").convert("RGBA")
    res = {}
    for i, k in enumerate(CARD_ORDER):
        cx = 144 + 252 * i
        im = sheet.crop((2 * (cx - 124), 2 * 18, 2 * (cx + 124), 2 * 404))
        res[k] = im.crop(im.getbbox())
    return res


def card(dst, key, cx, top, width=118, glow=False, lift=0):
    """Carte posée : width = largeur logique de la carte (ruban compris)."""
    im = cards()[key]; k = P(width) / im.width
    im = rs(im, im.width * k, im.height * k)
    x, y = P(cx) - im.width // 2, P(top - lift)
    if glow:
        g = Image.new("RGBA", (im.width + P(40), im.height + P(40))); g.paste((255, 214, 96, 255), (P(20), P(20)), im.split()[3])
        g = g.filter(ImageFilter.GaussianBlur(P(6))); dst.alpha_composite(g, (x - P(20), y - P(20))); dst.alpha_composite(g, (x - P(20), y - P(20)))
    b, pad = shadow(im, 4, 4, 160); dst.alpha_composite(b, (x - pad, y - pad))
    return im.height / S


def finish(img, out, rounded=0):
    out = pathlib.Path(out); out.parent.mkdir(parents=True, exist_ok=True)
    rgb = Image.new("RGB", img.size, (10, 10, 12)); rgb.paste(img.convert("RGB"), (0, 0), img.split()[3])
    rgb.save(out, quality=90)
    return out
