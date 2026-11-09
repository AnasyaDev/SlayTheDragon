-- Événements du client : chargement de la sauvegarde, vols en taxi, combat réel.
--
-- Vol : aucun événement « décollage » fiable n'est documenté pour Forever 12.1.5. On combine
--   PLAYER_CONTROL_LOST / PLAYER_CONTROL_GAINED / TAXIMAP_CLOSED / PLAYER_ENTERING_WORLD
--   (vérifiés dans l'API Forever par le MCP « wow ») et une vérification UnitOnTaxi("player")
--   retardée (C_Timer), plus un sondage lent de secours. Seule la transition de UnitOnTaxi
--   décide : ouverture au passage à vrai, fermeture au passage à faux.
local addonName, ns = ...
if not CreateFrame then return end -- hors du jeu (Sim/load.lua) : pas d'interface

local UI, Controller, Persist = ns.UI, ns.Controller, ns.Persist

local F = {}
ns.Flight = F

F.onTaxi = nil         -- dernier état connu (nil = pas encore lu)
F.hiddenByCombat = false
F.POLL = 2.0           -- secondes, filet de sécurité
F.CHECK_DELAYS = { 0.3, 1.0, 2.5 }

local function opts() return Persist.options() end

function F.isOnTaxi()
  return UnitOnTaxi and UnitOnTaxi("player") and true or false
end

function F.takeoff()
  if opts().autoOpen and not (InCombatLockdown and InCombatLockdown()) then UI.open("flight") end
end

function F.landing()
  if opts().autoClose and UI.isShown() then UI.close("landing") end
end

-- Compare l'état du taxi au dernier connu et réagit aux transitions.
function F.check()
  local on = F.isOnTaxi()
  local was = F.onTaxi
  F.onTaxi = on
  if on and was ~= true then
    F.takeoff()
  elseif not on and was == true then
    F.landing()
  end
end

function F.scheduleChecks()
  F.check()
  if C_Timer and C_Timer.After then
    for i = 1, #F.CHECK_DELAYS do C_Timer.After(F.CHECK_DELAYS[i], F.check) end
  end
end

function F.startPolling()
  if F.ticker or not (C_Timer and C_Timer.NewTicker) then return end
  F.ticker = C_Timer.NewTicker(F.POLL, F.check)
end

---------------------------------------------------------------------------
-- Cadre d'événements
---------------------------------------------------------------------------

local ev = CreateFrame("Frame")
F.eventFrame = ev

-- Un événement inconnu du client lève une erreur à l'enregistrement (constaté sur Forever) :
-- on enregistre un par un sous pcall.
local function register(name)
  local ok = pcall(ev.RegisterEvent, ev, name)
  if not ok then F.missingEvents = (F.missingEvents or "") .. name .. " " end
  return ok
end

for _, name in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT",
  "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
  "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "TAXIMAP_CLOSED" }) do
  register(name)
end

local handlers = {}

function handlers.ADDON_LOADED(name)
  if name ~= addonName then return end
  Persist.init()
  local ok, err = pcall(Controller.restore)
  if not ok then
    -- Dernier rempart : une sauvegarde qui fait planter la reprise est archivée, pas rejouée.
    Persist.archive({ result = "abandon", reason = "erreur à la reprise : " .. tostring(err) })
    Persist.store(nil)
    Controller.live = nil
  end
  F.loaded = true
end

function handlers.PLAYER_LOGIN()
  UI.createMinimapButton()
  F.startPolling()
end

function handlers.PLAYER_ENTERING_WORLD()
  F.scheduleChecks()
end

function handlers.PLAYER_LOGOUT()
  -- L'état est déjà recopié après chaque action ; on le réécrit par sécurité.
  if F.loaded then Controller.persist() end
end

function handlers.PLAYER_REGEN_DISABLED()
  if UI.isShown() then
    F.hiddenByCombat = true
    UI.close("combat")
  end
end

function handlers.PLAYER_REGEN_ENABLED()
  if F.hiddenByCombat then
    F.hiddenByCombat = false
    if F.isOnTaxi() and opts().autoOpen then UI.open("flight") end
  end
end

handlers.PLAYER_CONTROL_LOST = F.scheduleChecks
handlers.PLAYER_CONTROL_GAINED = F.scheduleChecks
handlers.TAXIMAP_CLOSED = F.scheduleChecks

ev:SetScript("OnEvent", function(_, event, ...)
  local h = handlers[event]
  if h then h(...) end
end)
