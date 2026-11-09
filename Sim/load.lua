-- Charge l'addon hors du jeu, dans l'ordre exact du TOC, comme le ferait WoW.
-- Usage : local ns = dofile(root .. "/Sim/load.lua")(root)
return function(root)
  root = root or "."
  local ns = {}
  local toc = assert(io.open(root .. "/SlayTheDragon.toc", "r"))
  for line in toc:lines() do
    line = line:gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if line ~= "" and not line:match("^#") and line:match("%.lua$") and not line:match("^UI[\\/]") then
      local path = root .. "/" .. line:gsub("\\", "/")
      local chunk = assert(loadfile(path))
      chunk("SlayTheDragon", ns)
    end
  end
  toc:close()
  -- UI\ est sauté : il appelle l'API WoW (Sim/ui_harness.lua le charge avec des stubs).
  -- Modules réservés à la simulation.
  ns.Bots = dofile(root .. "/Sim/bots.lua")(ns)
  ns.Run = dofile(root .. "/Sim/run.lua")(ns)
  return ns
end
