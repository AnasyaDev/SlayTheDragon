-- Rendu approximatif en SVG des cadres du faux client (Sim/ui_harness.lua) : résout les ancres,
-- tailles, échelles, couleurs, disques et textes pour vérifier une mise en page sans le jeu.
-- Usage (depuis le harnais) : R.svg(H, cadre, "build/x.svg"). Les textures de Media/ sont dessinées
-- d'après leurs aperçus PNG (tools/build_media.py → build/media_png, copiés dans <dossier>/media) avec
-- coordonnées de texture, couleur de sommet, désaturation, masque et rotation ; textes en Baloo
-- Chettan 2 (police installée) avec ombre et couleurs |c. Icônes du jeu = carrés bleus, modèles 3D =
-- silhouettes en pointillés, illustrations = aplat. Textes mesurés comme le faux client du harnais
-- (avances des glyphes de Baloo Chettan 2, ligne de 1,47 cadratin, retours explicites puis par mots) ;
-- sans harnais, estimation à 0,5 cadratin par caractère.
local R = {}

local CIRCLE = 130924
local WHITE = "Interface\\Buttons\\WHITE8X8"

local POINTS = {
  TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 },
  RIGHT = { 1, 0.5 }, BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 },
}
local LAYERS = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4, HIGHLIGHT = 5 }

-- Largeur d'un texte (sans codes) à la taille size, police de o (faux client si disponible).
function R.textWidth(text, size, o)
  if R.H and R.H.textWidth and o then return R.H.textWidth(o, text, size) end
  local n = 0
  for _ in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do n = n + 1 end
  return n * size * 0.5
end
local function lineHeight(size) return size * ((R.H and R.H.metrics and R.H.metrics.lineHeight) or 1.15) end
local ASC = 1.078 / 1.47 -- position de la ligne de base dans la ligne (Baloo Chettan 2)

local function escale(o)
  local s = 1
  while o do s = s * (rawget(o, "_scale") or 1) o = rawget(o, "_parent") end
  return s
end

-- Rectangle résolu {l, b, r, t} en unités d'écran (y vers le haut), ou nil.
local function rect(o, memo, depth)
  memo = memo or {}
  if memo[o] ~= nil then return memo[o] or nil end
  depth = (depth or 0) + 1
  if depth > 60 then return nil end
  memo[o] = false
  local name = rawget(o, "_name")
  if name == "UIParent" then
    local r = { 0, 0, 1600, 1000 }
    memo[o] = r
    return r
  end
  local pts = rawget(o, "_points") or {}
  local s = escale(o)
  local w, h = (rawget(o, "_w") or 0) * s, (rawget(o, "_h") or 0) * s
  local parent = rawget(o, "_parent")
  if rawget(o, "_kind") == "FontString" then
    -- taille d'un texte sans largeur imposée : estimée (0,5 em par caractère)
    local text = tostring(rawget(o, "_text") or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local size = (rawget(o, "_fontSize") or 12) * s
    local natural = 0
    for para in (text .. "\n"):gmatch("(.-)\n") do natural = math.max(natural, R.textWidth(para, size, o)) end
    if w == 0 then w = natural end
    if h == 0 then
      local n = (R.H and R.H.wrapLines) and #(R.H.wrapLines(o)) or math.ceil(natural / math.max(1, w))
      h = lineHeight(size) * math.max(1, n)
    end
    if text == "" then w, h = 0, 0 end
  end
  if pts[1] and pts[1][1] == "ALL" then
    local r = parent and rect(parent, memo, depth)
    memo[o] = r or false
    return r
  end
  local xs, ys = {}, {}
  for _, pt in ipairs(pts) do
    local p, rel, rp, x, y = pt[1], pt[2], pt[3], pt[4], pt[5]
    rel = rel or parent
    local rr = rel and rect(rel, memo, depth)
    if rr then
      local a, b = POINTS[rp] or POINTS.CENTER, POINTS[p] or POINTS.CENTER
      local ax = rr[1] + (rr[3] - rr[1]) * a[1] + (x or 0) * s
      local ay = rr[2] + (rr[4] - rr[2]) * a[2] + (y or 0) * s
      xs[#xs + 1] = { b[1], ax }
      ys[#ys + 1] = { b[2], ay }
    end
  end
  if #xs == 0 then return nil end
  local function axis(list, size)
    local lo, hi
    for _, v in ipairs(list) do
      if v[1] == 0 then lo = v[2] elseif v[1] == 1 then hi = v[2] end
    end
    if lo and hi then return lo, hi end
    if lo then return lo, lo + size end
    if hi then return hi - size, hi end
    local c = list[1][2]
    return c - size / 2, c + size / 2
  end
  local l, r = axis(xs, w)
  local b, t = axis(ys, h)
  local res = { l, b, r, t }
  memo[o] = res
  return res
end
R.rect = rect

-- Animations d'échelle (faux client : R.H.visualScale) : la mise en page (rect) les ignore, comme dans
-- le jeu ; le rendu les applique autour du centre du cadre animé. Cadres dont l'animation s'applique à
-- la région o, du plus proche au plus lointain : son parent et ses ancêtres ; avec regionsOnly
-- (hypothèse prudente : une animation Scale ne porte que sur les régions du cadre animé, pas sur ses
-- cadres enfants), le seul parent direct.
local function animated(o, regionsOnly)
  local out = {}
  local kind = rawget(o, "_kind")
  local a = (kind == "Texture" or kind == "FontString" or kind == "Line" or kind == "MaskTexture")
    and rawget(o, "_parent") or o
  while a and rawget(a, "_name") ~= "UIParent" do
    local k = (R.H and R.H.visualScale and rawget(a, "_kids")) and R.H.visualScale(a) or 1
    if k ~= 1 then out[#out + 1] = { a, k } end
    if regionsOnly then break end
    a = rawget(a, "_parent")
  end
  return out
end

-- Rectangle affiché {l, b, r, t} (animations d'échelle comprises).
function R.vrect(o, regionsOnly)
  local r = rect(o)
  if not r then return nil end
  local l, b, rr, t = r[1], r[2], r[3], r[4]
  for _, e in ipairs(animated(o, regionsOnly)) do
    local c = rect(e[1])
    if c then
      local cx, cy, k = (c[1] + c[3]) / 2, (c[2] + c[4]) / 2, e[2]
      l, rr = cx + (l - cx) * k, cx + (rr - cx) * k
      b, t = cy + (b - cy) * k, cy + (t - cy) * k
    end
  end
  return { l, b, rr, t }
end

-- Facteur d'échelle affiché d'une région dû aux animations (1 sans animation).
function R.vfactor(o, regionsOnly)
  local k = 1
  for _, e in ipairs(animated(o, regionsOnly)) do k = k * e[2] end
  return k
end

local function visible(o)
  while o do
    if not rawget(o, "_shown") then return false end
    o = rawget(o, "_parent")
  end
  return true
end

local function alpha(o)
  local a = 1
  while o do
    local c = rawget(o, "_calls")
    if c and c.SetAlpha then a = a * (c.SetAlpha[1] or 1) end
    o = rawget(o, "_parent")
  end
  return a
end

-- Niveau effectif : un enfant passe toujours au-dessus de son parent (comme dans le jeu).
local function flevel(f)
  if not f then return 0 end
  local p = rawget(f, "_parent")
  local own = rawget(f, "_level") or 0
  if p and rawget(p, "_name") ~= "UIParent" then return math.max(own, flevel(p) + 1) end
  return own
end

local function level(o)
  local f = o
  if rawget(o, "_kind") == "Texture" or rawget(o, "_kind") == "FontString" or rawget(o, "_kind") == "Line" then
    f = rawget(o, "_parent")
  end
  return flevel(f)
end

local function col(c)
  local r, g, b = c[1] or 1, c[2] or 1, c[3] or 1
  return string.format("#%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function esc(t)
  return (t:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

-- Textures de l'addon (Media/) : aperçus PNG de tools/build_media.py, copiés à côté des SVG
-- (R.media = préfixe relatif, ex. "media/") ; coordonnées de texture (répétées comprises), couleur de
-- sommet, désaturation, masque (disque ou carré arrondi), rotation, alpha.
local MEDIA = "Interface\\AddOns\\SlayTheDragon\\Media\\"
R.media = "media/"

local function mediaHref(tex)
  if type(tex) ~= "string" or tex:sub(1, #MEDIA) ~= MEDIA then return nil end
  return R.media .. tex:sub(#MEDIA + 1):gsub("\\", "/"):gsub("%.tga$", ".png")
end

-- Taille d'un aperçu PNG (en-tête IHDR), mémorisée.
local pngSize = {}
function R.pngSize(dir, href)
  if pngSize[href] then return pngSize[href][1], pngSize[href][2] end
  local f = io.open(dir .. "/" .. href, "rb")
  if not f then return nil end
  local h = f:read(24)
  f:close()
  local function be(i) return h:byte(i) * 16777216 + h:byte(i + 1) * 65536 + h:byte(i + 2) * 256 + h:byte(i + 3) end
  pngSize[href] = { be(17), be(21) }
  return be(17), be(21)
end

-- Morceaux colorés d'un texte (codes |cffRRGGBB … |r) : { { mot, couleur | nil, espace avant } }.
local function words(text)
  local out, color = {}, nil
  local i, n = 1, #text
  local cur, space = "", false
  local function push()
    if cur ~= "" then out[#out + 1] = { cur, color, space } cur = "" space = false end
  end
  while i <= n do
    local c = text:sub(i, i)
    if c == "|" and text:sub(i + 1, i + 1) == "c" then
      push()
      color = "#" .. text:sub(i + 4, i + 9)
      i = i + 10
    elseif c == "|" and text:sub(i + 1, i + 1) == "r" then
      push()
      color = nil
      i = i + 2
    elseif c == "\n" then
      push()
      out[#out + 1] = { "\n" }
      space = false
      i = i + 1
    elseif c == " " then
      push()
      space = true
      i = i + 1
    else
      cur = cur .. c
      i = i + 1
    end
  end
  push()
  return out
end

function R.svg(H, root, path, label)
  R.H = H
  local rr = rect(root)
  if not rr then return false end
  local dir = path:match("^(.*)/") or "."
  local W, Hh = rr[3] - rr[1], rr[4] - rr[2]
  local function X(x) return x - rr[1] end
  local function Y(y) return rr[4] - y end
  local items = {}
  for idx, o in ipairs(H.objects) do
    local kind = rawget(o, "_kind")
    if (kind == "Texture" or kind == "FontString" or kind == "PlayerModel" or kind == "Line") and visible(o) then
      -- descendant de la racine ?
      local p, inside = o, false
      while p do if p == root then inside = true break end p = rawget(p, "_parent") end
      if inside then
        local layer = LAYERS[rawget(o, "_layer") or ""] or 3
        items[#items + 1] = { o = o, kind = kind, key = level(o) * 1000 + layer * 100 + (rawget(o, "_sub") or 0) * 5 + idx / 100000 }
      end
    end
  end
  table.sort(items, function(a, b) return a.key < b.key end)
  local out = { string.format('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">',
    W, Hh, W, Hh), '<rect width="100%" height="100%" fill="#000"/>' }
  local defs, nid = {}, 0
  local filters = {}
  local function newId(p) nid = nid + 1 return p .. nid end
  -- filtre couleur de sommet (et désaturation), mémorisé
  local function filter(vc, desat)
    local r, g, b, a = vc[1] or 1, vc[2] or 1, vc[3] or 1, vc[4] or 1
    if not desat and r == 1 and g == 1 and b == 1 and a == 1 then return "" end
    local key = string.format("%.3f,%.3f,%.3f,%.3f,%s", r, g, b, a, tostring(desat))
    if not filters[key] then
      local id = newId("f")
      filters[key] = id
      local m
      if desat then
        m = string.format("%f %f %f 0 0 %f %f %f 0 0 %f %f %f 0 0 0 0 0 %f 0", 0.299 * r, 0.587 * r, 0.114 * r,
          0.299 * g, 0.587 * g, 0.114 * g, 0.299 * b, 0.587 * b, 0.114 * b, a)
      else
        m = string.format("%f 0 0 0 0 0 %f 0 0 0 0 0 %f 0 0 0 0 0 %f 0", r, g, b, a)
      end
      defs[#defs + 1] = string.format('<filter id="%s" color-interpolation-filters="sRGB"><feColorMatrix type="matrix" values="%s"/></filter>', id, m)
    end
    return string.format(' filter="url(#%s)"', filters[key])
  end
  for _, it in ipairs(items) do
    local o = it.o
    local r = R.vrect(o)
    local vk = R.vfactor(o)
    local calls = rawget(o, "_calls")
    local a = alpha(o)
    if it.kind == "Line" and a > 0.01 and calls.SetStartPoint and calls.SetEndPoint then
      local function pt(c)
        local rel = c[2] and rect(c[2])
        if not rel then return nil end
        local an = POINTS[c[1]] or POINTS.CENTER
        return X(rel[1] + (rel[3] - rel[1]) * an[1] + (c[3] or 0)), Y(rel[2] + (rel[4] - rel[2]) * an[2] + (c[4] or 0))
      end
      local x1, y1 = pt(calls.SetStartPoint)
      local x2, y2 = pt(calls.SetEndPoint)
      local cc = calls.SetColorTexture or { 1, 1, 1, 1 }
      if x1 and x2 then
        out[#out + 1] = string.format('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="%.1f"/>',
          x1, y1, x2, y2, col(cc), calls.SetThickness and calls.SetThickness[1] or 2)
      end
    end
    if r and a > 0.01 and it.kind ~= "Line" then
      local x, y, w, h = X(r[1]), Y(r[4]), r[3] - r[1], r[4] - r[2]
      local rot = calls.SetRotation and calls.SetRotation[1]
      local tf = (rot and rot ~= 0) and string.format(' transform="rotate(%.2f %.1f %.1f)"', -rot * 180 / math.pi, x + w / 2, y + h / 2) or ""
      if it.kind == "Texture" then
        local tex = rawget(o, "_texture")
        local vc = calls.SetVertexColor or { 1, 1, 1, 1 }
        local cc = calls.SetColorTexture
        local href = mediaHref(tex)
        local iw, ih = href and R.pngSize(dir, href)
        if href and iw and w > 0.1 and h > 0.1 then
          -- texture de Media : motif de l'image entière, cadré par les coordonnées de texture
          local tc = calls.SetTexCoord or { 0, 1, 0, 1 }
          local u0, u1, v0, v1 = tc[1], tc[2], tc[3], tc[4]
          if u1 == u0 then u1 = u0 + 1 end
          if v1 == v0 then v1 = v0 + 1 end
          local tw, th = w / (u1 - u0), h / (v1 - v0)
          local pid = newId("p")
          defs[#defs + 1] = string.format('<pattern id="%s" patternUnits="userSpaceOnUse" x="%.2f" y="%.2f" width="%.2f" height="%.2f"><image width="%.2f" height="%.2f" preserveAspectRatio="none" href="%s"/></pattern>',
            pid, x - u0 * tw, y - v0 * th, tw, th, tw, th, href)
          local clip = ""
          local mask = calls.AddMaskTexture and calls.AddMaskTexture[1]
          if mask then
            local cid = newId("c")
            local mt = tostring(rawget(mask, "_texture") or "")
            if mt:find("mask_roundsq", 1, true) then
              defs[#defs + 1] = string.format('<clipPath id="%s"><rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="%.1f"/></clipPath>',
                cid, x, y, w, h, w * 0.19)
            else
              defs[#defs + 1] = string.format('<clipPath id="%s"><ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f"/></clipPath>',
                cid, x + w / 2, y + h / 2, w / 2, h / 2)
            end
            clip = string.format(' clip-path="url(#%s)"', cid)
          end
          local desat = calls.SetDesaturated and calls.SetDesaturated[1]
          out[#out + 1] = string.format('<g%s%s opacity="%.2f"><rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" fill="url(#%s)"%s/></g>',
            clip, filter(vc, desat), a, x, y, w, h, pid, tf)
        elseif tex == CIRCLE then
          local fill, fa = col(vc), (vc[4] or 1) * a
          local tc = calls.SetTexCoord
          if tc and (tc[2] - tc[1]) < 0.9 then
            -- quart de disque (coins des rectangles arrondis)
            local cx = tc[1] == 0 and x + w or x
            local cy = tc[3] == 0 and y + h or y
            local sx = tc[1] == 0 and -1 or 1
            local sy = tc[3] == 0 and -1 or 1
            out[#out + 1] = string.format('<path d="M%.1f %.1f L%.1f %.1f A%.1f %.1f 0 0 %d %.1f %.1f Z" fill="%s" fill-opacity="%.2f"/>',
              cx, cy, cx + sx * w, cy, w, h, (sx * sy > 0) and 1 or 0, cx, cy + sy * h, fill, fa)
          else
            out[#out + 1] = string.format('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" fill-opacity="%.2f"%s/>',
              x + w / 2, y + h / 2, w / 2, h / 2, fill, fa, tf)
          end
        elseif cc and (tex == nil or tex == WHITE) then
          out[#out + 1] = string.format('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" fill-opacity="%.2f"%s/>',
            x, y, w, h, col(cc), (cc[4] or 1) * a, tf)
        elseif tex == WHITE and calls.SetGradient then
          out[#out + 1] = string.format('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="#fff" fill-opacity="%.2f"/>',
            x, y, w, h, 0.04 * a)
        elseif tex ~= nil then
          local desat = calls.SetDesaturated and calls.SetDesaturated[1]
          local big = w * h > 60000
          local fill = big and "#6a5a40" or (desat and "#777" or "#5a7aa0")
          out[#out + 1] = string.format('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" fill-opacity="%.2f" stroke="#cde" stroke-opacity="%.2f" stroke-width="0.5"%s/>',
            x, y, w, h, fill, (big and 0.5 or 0.9) * a, big and 0 or 0.5, tf)
        end
      elseif it.kind == "PlayerModel" then
        out[#out + 1] = string.format('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="none" stroke="#9fd" stroke-dasharray="4 4" stroke-opacity="%.2f"/>', x, y, w, h, 0.6 * a)
        out[#out + 1] = string.format('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="#9fd" fill-opacity="%.2f"/>', x + w / 2, y + h * 0.55, w * 0.18, h * 0.38, 0.35 * a)
      elseif it.kind == "FontString" then
        local text = rawget(o, "_text")
        if text and text ~= "" then
          local size = (rawget(o, "_fontSize") or 12) * escale(o) * vk
          local tc = calls.SetTextColor or { 1, 1, 1 }
          local jh = calls.SetJustifyH and calls.SetJustifyH[1] or "CENTER"
          local ww = (rawget(o, "_w") or 0) * escale(o) * vk
          local fpath = tostring(rawget(o, "_fontPath") or "")
          local weight = fpath:find("heavy") and 800 or (fpath:find("bold") and 700 or 500)
          local family = fpath:find("Baloo") and "'Baloo Chettan 2'" or (rawget(o, "_fontFile") == "title" and "serif" or "sans-serif")
          -- césure par mots (largeur estimée), couleurs des codes |c conservées par mot
          local ws = words(tostring(text))
          local maxW = ww > 0 and ww or 1e9
          local lines, cur, curW = {}, {}, 0
          local es = escale(o) * vk
          for _, wd in ipairs(ws) do
            if wd[1] == "\n" then
              lines[#lines + 1] = cur cur, curW = {}, 0
            else
              local wl = R.textWidth(wd[1], size / es, o) * es
              local add = (#cur > 0 and wd[3]) and R.textWidth(" ", size / es, o) * es or 0
              if #cur > 0 and wd[3] and curW + add + wl > maxW + 0.01 then
                lines[#lines + 1] = cur cur, curW = {}, 0 add = 0
              end
              cur[#cur + 1] = { wd[1], wd[2], #cur > 0 and wd[3] }
              curW = curW + add + wl
            end
          end
          if #cur > 0 then lines[#lines + 1] = cur end
          local anchor, tx = "middle", x + w / 2
          if ww > 0 and jh == "LEFT" then anchor, tx = "start", x elseif ww > 0 and jh == "RIGHT" then anchor, tx = "end", x + w end
          if w == 0 then
            local pt = rawget(o, "_points")[1]
            local p = pt and pt[1] or "CENTER"
            if p:find("LEFT") then anchor = "start" elseif p:find("RIGHT") then anchor = "end" end
          end
          local lh = lineHeight(size) + (calls.SetSpacing and calls.SetSpacing[1] or 0)
          local ty
          if h > 0 then ty = y + (h - lh * #lines) / 2 + lh * ASC else ty = y - lh * #lines / 2 + lh * ASC end
          local pt = rawget(o, "_points")[1]
          if pt and pt[1] and pt[1]:find("TOP") and h == 0 then ty = y + lh * ASC end
          local so = calls.SetShadowOffset
          local shadow = so and ((so[1] or 0) ~= 0 or (so[2] or 0) ~= 0)
          local base = col(tc)
          local ttf = (rot and rot ~= 0) and string.format(' transform="rotate(%.2f %.1f %.1f)"', -rot * 180 / math.pi, x + w / 2, y + h / 2) or ""
          for li, line in ipairs(lines) do
            local function spans()
              local s = {}
              for _, wd in ipairs(line) do
                s[#s + 1] = string.format('<tspan%s>%s%s</tspan>', wd[2] and (' fill="' .. wd[2] .. '"') or "",
                  wd[3] and " " or "", esc(wd[1]))
              end
              return table.concat(s)
            end
            local yy = ty + (li - 1) * lh
            if shadow then
              out[#out + 1] = string.format('<text x="%.1f" y="%.1f" font-family="%s" font-weight="%d" font-size="%.1f" fill="#000" fill-opacity="%.2f" text-anchor="%s" xml:space="preserve"%s>%s</text>',
                tx + 1, yy + 1, family, weight, size, 0.8 * a, anchor, ttf, esc(table.concat((function()
                  local t = {} for k, wd in ipairs(line) do t[#t + 1] = (wd[3] and " " or "") .. wd[1] end return t end)())))
            end
            out[#out + 1] = string.format('<text x="%.1f" y="%.1f" font-family="%s" font-weight="%d" font-size="%.1f" fill="%s" fill-opacity="%.2f" text-anchor="%s" xml:space="preserve"%s>%s</text>',
              tx, yy, family, weight, size, base, a, anchor, ttf, spans())
          end
        end
      end
    end
  end
  if #defs > 0 then out[2] = "<defs>" .. table.concat(defs, "\n") .. "</defs>\n" .. out[2] end
  if label then
    out[#out + 1] = string.format('<text x="6" y="%d" font-size="11" fill="#f0f">%s</text>', Hh - 4, esc(label))
  end
  out[#out + 1] = "</svg>"
  local f = assert(io.open(path, "w"))
  f:write(table.concat(out, "\n"))
  f:close()
  return true
end

return R
