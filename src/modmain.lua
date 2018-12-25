GLOBAL.CHEATS_ENABLED = true
GLOBAL.require('debugkeys')

-- Detect Don't Starve Together
local is_dst = GLOBAL.TheSim:GetGameID() == "DST"

-- DS globals
local CreateEntity = GLOBAL.CreateEntity
local SpawnPrefab = GLOBAL.SpawnPrefab

local state = {
  inventory = nil,

  hud = {
    inventorybar = nil
  },

  -- true for all cases except when connected to a remote host in DST
  is_master = true
}

local fn = {}

function fn.IsMaster()
  if not is_dst then
    return true
  end

  if GLOBAL.TheWorld then
    return not not GLOBAL.TheWorld.ismastersim
  else
    return true
  end
end

-- entity to run tasks with, necessary to gain access to DoTaskInTime()
local tasker = CreateEntity()

-- Runs the given function on the next processing cycle,
-- after all current threads have finished or yielded
function fn.OnNextCycle(onNextCycle)
  tasker:DoTaskInTime(0, onNextCycle)
end

function fn.RevealMap()
  local minimap = TheSim:FindFirstEntityWithTag("minimap")
  minimap.MiniMap:ShowArea(0,0,0, 10000)
end

if not is_dst then
  AddSimPostInit(function()
    fn.OnNextCycle(fn.RevealMap)
  end)
end

function fn.GetPlayer()
  if is_dst then
    -- It is renamed and a variable in DST
    return GLOBAL.ThePlayer
  else
    return GLOBAL.GetPlayer()
  end
end

function fn.GetComponent(o, component_name)
  if o then
    if state.is_master then
      return o.components and o.components[component_name]
    else
      -- if not master you can only interact with the replica
      return o.replica and o.replica[component_name]
    end
  end
end

function fn.GetPlayerInventory()
  local player = fn.GetPlayer()
  local inventory = fn.GetComponent(player, "inventory")
  return fn.MakeInventory(inventory, state.is_master)
end

function fn.MakeInventory(inventory, is_master)
  local classified = inventory.classified



  local function MoveBlockingItem(blocking_item, item)
    return

  end

  local interface = {
    Move = function(from, to) end,
    Equip = function(slot) end,
    Unequip = function(eslot) end,
    GetItem = function(slot) end,
    GetFreeSlot = function() end,
    CanEquip = function(item) end,
    ResolveBlock = function(blocking_item, target_slot) end
  }

  -- ResolveBlock does not have any interface specific logic,
  -- but utilities specific interface functions like MoveItem()
  function interface.ResolveBlock(blocking_item, target_slot)
    local blocking_item = interface.GetItem(target_slot)

    if not blocking_item or blocking_item == OCCUPIED then
      return true
    end

    local equip_blocking_item =
      config.allow_equip_for_space and
      interface.CanEquip(blocking_item)

    local move_blocking_item =
      not equip_blocking_item and
      not blocking_item.prefab == item.prefab and
      fn.IsFiniteUses(item) and
      fn.GetRemainingUses(item) < fn.GetRemainingUses(blocking_item)

    if equip_blocking_item then
      interface.Equip(target_slot)
    elseif move_blocking_item then
      interface.Move(target_slot)
    else
      -- Not resolved
      return false
    end

    -- Ending up here means the block was resolved
    return true
  end

  if is_master then
    -- TODO
  else if classified then
    function interface.Move(from, to)
      fn.debug("classified.Move")
      classified:TakeActiveItemFromAllOfSlot(from)
      classified._busy = false
      classified:PutAllOfActiveItemInSlot(to)
    end

    function interface.GetItem(slot)
      return classified:GetItemInSlot(slot)
    end
  else
    -- Replica
  end

  return interface
end

function fn.debug(msg)
  local prefix = "SaveEquipmentSlots | "
  print(prefix .. msg)
end

function fn.callOrValue(v)
  return type(v) == "function" and v() or v
end

function fn.IfHasComponent(o, component_name, ifFn, ifNot)
  local component = fn.GetComponent(o, component_name)

  if component then
    return type(ifFn) == "function" and ifFn(component) or component
  else
    return fn.callOrValue(ifNot)
  end
end

-- Specifies if item is equipment
function fn.IsEquipment(item)
  return fn.IfHasComponent(item, "equippable", true, false)
end

function fn.Inventory_OnItemGet(inst, data)
  local item = data.item
  local slot = data.slot

  if not fn.IsEquipment(item) then
    return
  end

  local inventory = fn.GetComponent(inst, "inventory")
  if not inventory then
    return
  end
end

function fn.InitInventory(inventory)
  state.inventory = inventory

  inventory.inst:ListenForEvent("itemget", fn.Inventory_OnItemGet)

  if not state.is_master and inventory.classified then
    fn.debug("HAS CLASSIFIED")

    inventory.classified.Move = function(inst, from, to)
      inst:TakeActiveItemFromAllOfSlot(from)
      inst._busy = false
      inst:PutAllOfActiveItemInSlot(to)
    end


    local ofn = inventory.classified.TakeActiveItemFromAllOfSlot
    inventory.classified.TakeActiveItemFromAllOfSlot = function(inst, slot)
      fn.debug("TakeActiveItemFromAllOfSlot | IsBusy = "..tostring(inst._busy))
      return ofn(inst, slot)
    end

    local ofn2 = inventory.classified.PutAllOfActiveItemInSlot
    inventory.classified.PutAllOfActiveItemInSlot = function(inst, slot)
      fn.debug("PutAllOfActiveItemInSlot | IsBusy = "..tostring(inst._busy))
      return ofn2(inst, slot)
    end
  end
end

function fn.InitDev()
  AddSimPostInit(function()
    state.is_master = fn.IsMaster()
    fn.debug("IS MASTER = "..tostring(state.is_master))
  end)

  AddPlayerPostInit(function(player)
    fn.OnNextCycle(function()
      if player == fn.GetPlayer() then
        -- Only initialize for the current player
        fn.IfHasComponent(player, "inventory", fn.InitInventory)
      end
    end)
  end)
end

function fn.delay(toDelay)
  tasker:DoTaskInTime(1, toDelay)
end

function GLOBAL._mv(from, to)
  fn.delay(function()
    fn.MoveSlot(from, to)
  end)
end

function GLOBAL._eq(slot)
  fn.delay(function()
    fn.Equip(slot)
  end)
end

function GLOBAL._uneq(slot)
  fn.delay(function()
    fn.Unequip(slot)
  end)
end


function fn.MoveSlot(from, to)
  fn.debug("MoveSlot("..from..","..to..")")
  fn.GetPlayerInventory().Move(from, to)

--
  -- -- Grab it
  -- inv:TakeActiveItemFromAllOfSlot(from)
--
  -- -- Put
  -- inv:PutAllOfActiveItemInSlot(to)
--
  -- -- Put again
  -- tasker:DoTaskInTime(2, function()
  --   inv:PutAllOfActiveItemInSlot(to)
  -- end)
end

function fn.Equip(slot)
  fn.debug("Equip("..slot..")")

  local inv = fn.GetPlayerInventory()

  -- Grab it
  local item = inv:GetItemInSlot(slot)
  if item then
    -- Equip
    inv:ControllerUseItemOnSelfFromInvTile(item)
  end
end

function fn.Unequip(eslot)
  fn.debug("Unequip("..eslot..")")

  local inv = fn.GetPlayerInventory()

  -- Grab it
  local item = inv:GetEquippedItem(eslot)
  if item then
    -- Unequip
    inv:ControllerUseItemOnSelfFromInvTile(item)
  end
end


fn.InitDev()
