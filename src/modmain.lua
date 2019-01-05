GLOBAL.CHEATS_ENABLED = true
GLOBAL.require('debugkeys')

local state = {
  -- Set on SimPostInit
  is_mastersim = true,
  -- Detect Don't Starve Together
  is_dst = GLOBAL.TheSim:GetGameID() == "DST"
}

local fn = {}

function fn.GetPlayer()
  if is_dst then
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

function fn.GetComponent(o, component_name)
  if o then
    if state.is_mastersim then
      return o.components and o.components[component_name]
    else
      -- non mastersims only interact with the replica
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
  local max = is_dst and 1 or 100

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
      TheWorld:PushEvent("ms_nextcycle")
    else
      GLOBAL.c_remote('TheWorld:PushEvent("ms_nextcycle")')
    end
  else
    GLOBAL.GetClock():MakeNextDay()
  end
end

GLOBAL._reveal = fn.RevealMap
GLOBAL._god = fn.GodMode
GLOBAL._dump = fn.DumpTable
GLOBAL._inv = fn.GetInventory
GLOBAL._nextday = fn.NextDay

AddSimPostInit(function()
  state.is_mastersim = fn.IsMasterSim()
end)
