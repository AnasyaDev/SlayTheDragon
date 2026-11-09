-- Charge l'addon hors du jeu, dans l'ordre exact du TOC, comme le ferait WoW.
-- Usage : local ns = dofile(root .. "/Sim/load.lua")(root)
return function(root)
  root = root or "."
  local ns = {}
  local toc = assert(io.open(root .. "/SlayTheDragon.toc", "r"))
  for line in toc:lines() do
    line = line:gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if line ~= "" and not line:match("^#") and line:match("%.lua$") then
      local path = root .. "/" .. line:gsub("\\", "/")
      local chunk = assert(loadfile(path))
      chunk("SlayTheDragon", ns)
    end
  end
  toc:close()
  -- Modules réservés à la simulation.
  ns.Bots = dofile(root .. "/Sim/bots.lua")(ns)
  ns.Run = dofile(root .. "/Sim/run.lua")(ns)
  ns.SimExpedition = dofile(root .. "/Sim/expedition.lua")(ns)
  return ns
end
