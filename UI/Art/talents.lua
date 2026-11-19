-- Art des arbres de talents (docs/talents.md, § 11 et § 17.7) : icône de chaque nœud et de chaque voie du nœud
-- Specialization. Ordre : Art.talentIcons[classe][id] (remplacement posé ici, facultatif), puis le champ `icon` du
-- nœud ou de la voie (nom d'un fichier de Media/Icons, sans extension : Data/Talents/<classe>.lua), puis l'icône du
-- nœud pour une voie sans icône, puis l'icône de la classe (Art.class). Une icône absente de Media/Icons passe par
-- le chemin du client (`Interface\Icons\<nom>`), sinon le point d'interrogation (W.setIcon).
local _, ns = ...

local Art = ns.Art

-- Remplacements par classe : { [classe] = { [id du nœud ou de la voie] = "nom_d_icone" } } (vide : les fiches
-- portent leurs icônes, toutes embarquées pour le Warrior et les nœuds génériques).
Art.talentIcons = Art.talentIcons or {}

local function entry(name)
  return { tga = name, icon = "Interface\\Icons\\" .. name:lower() }
end

-- Entrée d'icône (W.setIcon) d'un nœud ou d'une voie : class, id, icône de la fiche, icône du nœud parent (voie).
function Art.talentIcon(class, id, icon, parentIcon)
  local over = Art.talentIcons[class]
  local name = (over and id and over[id]) or icon or parentIcon
  if type(name) == "string" and name ~= "" then return entry(name) end
  return Art.class(class)
end
