GLOBAL.CHEATS_ENABLED = true
GLOBAL.require('debugkeys')

local TheSim = GLOBAL.TheSim
local SpawnPrefab = GLOBAL.SpawnPrefab
local Ents = GLOBAL.Ents
local Prefabs = GLOBAL.Prefabs
local unpack = GLOBAL.unpack

local state = {
  -- Set on SimPostInit
  is_mastersim = true,
  -- Detect Don't Starve Together
  is_dst = GLOBAL.TheSim:GetGameID() == "DST",
  inventorybar = nil
}

local net_entity = state.is_dst and GLOBAL.net_entity or nil

local fn = {}

function fn.GetPlayer()
  if state.is_dst then
    return GLOBAL.ThePlayer
  else
    return GLOBAL.GetPlayer()
  end
end

function fn.IsMasterSim()
  if not state.is_dst then
    return true
  end

  if GLOBAL.TheWorld then
    return not not GLOBAL.TheWorld.ismastersim
  else
    return true
  end
end

function fn.CallOrValue(v, ...)
  return type(v) == "function" and v(...) or v
end

function fn.GetComponent(o, component_name, get_replica)
  if o then
    if state.is_mastersim and not get_replica then
      return o.components and o.components[component_name]
    else
      return o.replica and o.replica[component_name]
    end
  end
end

function fn.IfHasComponent(o, component_name, ifFn, ifNot)
  local component = fn.GetComponent(o, component_name)

  if component then
    return type(ifFn) == "function" and ifFn(component) or component
  else
    return fn.CallOrValue(ifNot)
  end
end

function fn.RevealMap()
  local minimap = TheSim:FindFirstEntityWithTag("minimap")
  minimap.MiniMap:ShowArea(0,0,0, 10000)
end

function fn.GodMode()
  local max = 1

  if state.is_mastersim then
    GLOBAL.c_sethealth(max)
    GLOBAL.c_setsanity(max)
    GLOBAL.c_sethunger(max)

    if state.is_dst then
      GLOBAL.c_setbeaverness(max)
    end

    GLOBAL.c_godmode()
  else
    GLOBAL.c_remote("c_sethealth("..max..")")
    GLOBAL.c_remote("c_setsanity("..max..")")
    GLOBAL.c_remote("c_sethunger("..max..")")
    GLOBAL.c_remote("c_setbeaverness("..max..")")
    GLOBAL.c_remote("c_godmode()")
  end
end

function fn.Debug(msg)
  local prefix = "DEV | "
  print(prefix .. msg)
end

function fn.DumpTable(tbl, levels, prefix)
  if type(tbl) ~= "table" then
    print(tostring(tbl))
    return
  end

  local levels = levels or 2

  if levels < 1 then
    -- prevent endless loops on recursive tables
    return
  end

  for k,v in pairs(tbl) do
    local key = (prefix or "")..tostring(k)

    if type(v) == "table" and levels > 1 then
      fn.DumpTable(v, levels - 1, key..".")
    else
      print(key.." = "..tostring(v))
    end
  end
end

function fn.GetInventory()
  local player = fn.GetPlayer()
  if player then
    return fn.IfHasComponent(player, "inventory")
  end
end

function fn.NextDay()
  if state.is_dst then
    if state.is_mastersim then
      GLOBAL.TheWorld:PushEvent("ms_nextcycle")
    else
      GLOBAL.c_remote('TheWorld:PushEvent("ms_nextcycle")')
    end
  else
    GLOBAL.GetClock():MakeNextDay()
  end
end

function fn.DropAll()
  if state.is_dst then
    print("Not implemented for DST")
  else
    local inv = fn.GetInventory()
    if inv then
      inv:DropEverything()
    end
  end
end

function fn.SkipDays(days)
  if state.is_dst then
    print("SkipDays not implemented for DST")
  else
    for i = 1, days do
      fn.NextDay()
    end
  end
end

function fn.GetPlayerPosition()
  local player = fn.GetPlayer()
  return player and player:GetPosition()
end

function fn.CelestialPortalWithMoonRock()
  if not state.is_dst then
    print("DST only")
  elseif state.is_mastersim then
    GLOBAL.c_spawn("multiplayer_portal_moonrock")
    GLOBAL.c_spawn("moonrockidol", 5)
  else
    GLOBAL.c_remote('c_spawn("multiplayer_portal_moonrock")')
    GLOBAL.c_remote('c_spawn("moonrockidol", 5)')
  end
end

function fn.SpawnIconItems()
  local items = { "heatrock", "wheeler_tracker", "cutlichen", "boat_lantern", "boat_torch", "roc_robin_egg", "telescope", "trusty_shooter" }
  fn.SpawnPrefabs(items)
end

function fn.SpawnEquipment()
  local equipment = { "spear", "axe", "goldenaxe", "goldenshovel", "pickaxe", "goldenpickaxe", "hammer", "armorwood" }
  fn.SpawnPrefabs(equipment, 3)
end

function fn.SpawnPrefabs(prefabs, amount)
  local n = amount or 1
  for i=1, n do
    for _, prefab in ipairs(prefabs) do
      if state.is_mastersim then
        GLOBAL.c_spawn(prefab, 1)
      else
        GLOBAL.c_remote('c_spawn("'..prefab..'", 1)')
      end
    end
  end
end

function fn.AtlasImage(prefab, n)
  for i = 1, (n or 1) do
    fn.AsMasterSim(function()
      local spawn = fn.Spawn(prefab)

      local inventoryitem = fn.GetComponent(spawn, "inventoryitem", state.is_dst)

      if inventoryitem then
        atlas = inventoryitem:GetAtlas()
        image = inventoryitem:GetImage()
        print("atlas", tostring(atlas))
        print("image", tostring(image))
        spawn:Remove()
      else
        print("no inventoryitem!")
      end
    end)
  end
end

function fn.AsMasterSim(func)
  if state.is_mastersim then
    return func()
  else
    GLOBAL.TheWorld.ismastersim = true
    local result = {func()}
    GLOBAL.TheWorld.ismastersim = false
    return unpack(result)
  end
end

function fn.Spawn(prefab)
  local guid = TheSim:SpawnPrefab(prefab)
  local spawn = Ents[guid]
  return spawn
end

function fn.BeaverMode()
  local player = fn.GetPlayer()
  local beaverness = fn.GetComponent(player, "beaverness")
  if not beaverness then return end

  if state.is_dst then
    local is_beaver = beaverness:GetPercent() == 0

    if is_beaver then
      beaverness:SetPercent(1)
    else
      beaverness:SetPercent(0)
    end
  else
    local is_beaver = beaverness:IsBeaver()
    if is_beaver then
      beaverness:SetPercent(0)
    else
      beaverness:SetPercent(1)
    end
  end
end

function fn.GetInventorybar()
  return state.inventorybar
end

GLOBAL._reveal = fn.RevealMap
GLOBAL._god = fn.GodMode
GLOBAL._dump = fn.DumpTable
GLOBAL._inv = fn.GetInventory
GLOBAL._nd = fn.NextDay
GLOBAL._portal = fn.CelestialPortalWithMoonRock
GLOBAL._pos = fn.GetPlayerPosition
GLOBAL._eq = fn.SpawnEquipment
GLOBAL._icons = fn.SpawnIconItems
GLOBAL._beaver = fn.BeaverMode
GLOBAL._skip = fn.SkipDays
GLOBAL._inventorybar = fn.GetInventorybar
GLOBAL._prefabs = Prefabs
GLOBAL._player = fn.GetPlayer
GLOBAL._drop = fn.DropAll
GLOBAL._spawn = fn.Spawn
GLOBAL._atlasimage = fn.AtlasImage
GLOBAL._thesim = TheSim
GLOBAL._netent = net_entity

AddSimPostInit(function()
  state.is_mastersim = fn.IsMasterSim()
end)

AddClassPostConstruct("widgets/inventorybar", function(inventorybar)
  state.inventorybar = inventorybar
end)
