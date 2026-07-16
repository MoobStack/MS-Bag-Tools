-- MS Bag Tools 1.1.3
-- Designed for the World of Warcraft 1.12.1 client using Interface 11200.

MSBagTools = MSBagTools or {}
local MSB = MSBagTools
-- Temporary compatibility alias for integrations that referenced the former
-- addon table. New integrations should use MSBagTools.
OctoBagTools = MSBagTools
MSB.loadStage = "loading core"

MSB.name = "MSBagTools"
MSB.displayName = "MS Bag Tools"
MSB.publisher = "MoobStack"
MSB.version = "1.1.3"
MSB.prefix = "|cff33ccffMS Bag Tools:|r "
MSB.fontFallback = "Fonts\\FRIZQT__.TTF"
MSB.serverLockWait = 8.0
MSB.serverLockRetry = 0.20
MSB.sellStepDelay = 0.18
MSB.sellVerifyTimeout = 1.50
MSB.sellLockWait = 2.00

-- WoW 1.12.1 embeds Lua 5.0, where the pattern iterator is named
-- string.gfind. Lua 5.1 renamed it to string.gmatch. Keep both paths so
-- this addon can be syntax/runtime checked outside the client as well.
local StringPatternIterator = string.gfind
if not StringPatternIterator then StringPatternIterator = string.gmatch end

MSB.defaults = {
  enabled = 1,
  showToolbar = 1,
  usePFUITheme = 1,
  sortMode = "CATEGORY",
  gridColumns = 12,
  bagOrder = "0,4,3,2,1",
  bankGridColumns = 12,
  bankOrder = "-1,5,6,7,8,9,10,11",
  mergeStacks = 1,
  junkLast = 1,
  qualityDescending = 1,
  protectLockedFromVendor = 1,
  announceJunk = 1,
  blockCombatSort = 1,
  moveDelay = 0.12,
  outlineColor = "GOLD",
  outlineSize = 2,
}

MSB.charDefaults = {
  locked = {},
}

MSB.outlineColors = {
  GOLD = { 1.00, 0.72, 0.10, 1.00 },
  RED = { 1.00, 0.20, 0.20, 1.00 },
  BLUE = { 0.25, 0.65, 1.00, 1.00 },
  GREEN = { 0.25, 1.00, 0.45, 1.00 },
  WHITE = { 0.95, 0.95, 0.95, 1.00 },
}

MSB.sortModeNames = {
  CATEGORY = "Category (organized)",
  QUALITY = "Quality",
  NAME = "Name",
}

MSB.defaultBagOrder = { 0, 4, 3, 2, 1 }
MSB.defaultBankOrder = { -1, 5, 6, 7, 8, 9, 10, 11 }

-- Practical ordering used inside broad item categories. Values are kept
-- deliberately sparse so future client-extension item subclasses can be
-- inserted without changing the saved-variable format.
MSB.equipLocationRanks = {
  INVTYPE_HEAD = 10,
  INVTYPE_NECK = 20,
  INVTYPE_SHOULDER = 30,
  INVTYPE_CLOAK = 40,
  INVTYPE_CHEST = 50,
  INVTYPE_ROBE = 50,
  INVTYPE_BODY = 55,
  INVTYPE_WRIST = 60,
  INVTYPE_HAND = 70,
  INVTYPE_WAIST = 80,
  INVTYPE_LEGS = 90,
  INVTYPE_FEET = 100,
  INVTYPE_FINGER = 110,
  INVTYPE_TRINKET = 120,
  INVTYPE_SHIELD = 130,
  INVTYPE_HOLDABLE = 140,
  INVTYPE_RANGED = 150,
  INVTYPE_RANGEDRIGHT = 150,
  INVTYPE_THROWN = 150,
  INVTYPE_WEAPON = 160,
  INVTYPE_WEAPONMAINHAND = 160,
  INVTYPE_WEAPONOFFHAND = 170,
  INVTYPE_2HWEAPON = 180,
  INVTYPE_TABARD = 190,
  INVTYPE_BAG = 200,
}

local function SafeNumber(value, fallback)
  value = tonumber(value)
  if value == nil then return fallback end
  return value
end

-- Old WoW 1.12.1-compatible clients and extensions are inconsistent about boolean
-- return values. Some return nil/1, some false/true, and some return numeric
-- 0/1. Lua treats numeric 0 as true, so a direct `value and 1 or nil` test can
-- incorrectly mark every unlocked bag item as server-locked.
local function NormalizeBooleanFlag(value)
  if value == nil or value == false then return nil end
  if type(value) == "number" then
    if value == 0 then return nil end
    return 1
  end
  if type(value) == "string" then
    local lowered = string.lower(value)
    if lowered == "" or lowered == "0" or lowered == "false" or
       lowered == "nil" or lowered == "unlocked" or lowered == "no" then
      return nil
    end
  end
  return 1
end

local function Clamp(value, minimum, maximum)
  value = SafeNumber(value, minimum)
  if value < minimum then value = minimum end
  if value > maximum then value = maximum end
  return value
end

local function Lower(value)
  if type(value) ~= "string" then return "" end
  return string.lower(value)
end

local function Contains(text, fragment)
  if type(text) ~= "string" or type(fragment) ~= "string" or fragment == "" then return nil end
  return string.find(text, fragment) and 1 or nil
end

local function ContainsAny(text, fragments)
  if type(text) ~= "string" or type(fragments) ~= "table" then return nil end
  for index = 1, table.getn(fragments) do
    if Contains(text, fragments[index]) then return 1 end
  end
  return nil
end

local function Now()
  if GetTime then return GetTime() end
  return 0
end

local function TableCount(tbl)
  local count = 0
  if type(tbl) ~= "table" then return 0 end
  for _ in pairs(tbl) do count = count + 1 end
  return count
end

local function ApplyDefaults(target, defaults)
  if type(target) ~= "table" then target = {} end
  for key, value in pairs(defaults) do
    if target[key] == nil then
      if type(value) == "table" then
        target[key] = {}
        for childKey, childValue in pairs(value) do
          target[key][childKey] = childValue
        end
      else
        target[key] = value
      end
    end
  end
  return target
end

local function HasTableData(tbl, ignoredKey)
  if type(tbl) ~= "table" then return nil end
  for key in pairs(tbl) do
    if key ~= ignoredKey then return 1 end
  end
  return nil
end

local function DeepCopy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local copy = {}
  seen[value] = copy
  for key, child in pairs(value) do
    copy[DeepCopy(key, seen)] = DeepCopy(child, seen)
  end
  return copy
end

local function CopyMissingKeys(target, source)
  if type(target) ~= "table" or type(source) ~= "table" then return end
  for key, value in pairs(source) do
    if target[key] == nil then
      target[key] = DeepCopy(value)
    elseif type(target[key]) == "table" and type(value) == "table" then
      CopyMissingKeys(target[key], value)
    end
  end
end

local function SafeCall(method, object)
  if type(method) ~= "function" then return nil end
  local ok, result = pcall(method, object)
  if ok then return result end
  return nil
end

function MSB:MigrateLegacySavedVariables()
  local bridge = MSBagToolsLegacyMigration
  local legacyAccount = type(OctoBagToolsDB) == "table" and OctoBagToolsDB or nil
  local legacyCharacter = type(OctoBagToolsCharDB) == "table" and OctoBagToolsCharDB or nil

  if type(bridge) == "table" then
    if type(legacyAccount) ~= "table" and type(bridge.account) == "table" then
      legacyAccount = bridge.account
    end
    if type(legacyCharacter) ~= "table" and type(bridge.character) == "table" then
      legacyCharacter = bridge.character
    end
  end

  if type(MSBagToolsDB) ~= "table" then MSBagToolsDB = {} end
  local accountMarker = MSBagToolsDB._moobStackMigration
  if type(accountMarker) ~= "table" then accountMarker = {} end
  if accountMarker.octoBagTools112 ~= 1 and type(legacyAccount) == "table" then
    if not HasTableData(MSBagToolsDB, "_moobStackMigration") then
      MSBagToolsDB = DeepCopy(legacyAccount)
      if type(MSBagToolsDB) ~= "table" then MSBagToolsDB = {} end
    else
      CopyMissingKeys(MSBagToolsDB, legacyAccount)
    end
    if type(MSBagToolsDB._moobStackMigration) ~= "table" then
      MSBagToolsDB._moobStackMigration = accountMarker
    end
    MSBagToolsDB._moobStackMigration.octoBagTools112 = 1
    MSBagToolsDB._moobStackMigration.completedBy = "MS Bag Tools 1.1.3"
    self.legacyAccountImported = 1
  elseif type(MSBagToolsDB._moobStackMigration) ~= "table" then
    MSBagToolsDB._moobStackMigration = accountMarker
  end

  if type(MSBagToolsCharDB) ~= "table" then MSBagToolsCharDB = {} end
  local characterMarker = MSBagToolsCharDB._moobStackMigration
  if type(characterMarker) ~= "table" then characterMarker = {} end
  if characterMarker.octoBagTools112 ~= 1 and type(legacyCharacter) == "table" then
    if not HasTableData(MSBagToolsCharDB, "_moobStackMigration") then
      MSBagToolsCharDB = DeepCopy(legacyCharacter)
      if type(MSBagToolsCharDB) ~= "table" then MSBagToolsCharDB = {} end
    else
      CopyMissingKeys(MSBagToolsCharDB, legacyCharacter)
    end
    if type(MSBagToolsCharDB._moobStackMigration) ~= "table" then
      MSBagToolsCharDB._moobStackMigration = characterMarker
    end
    MSBagToolsCharDB._moobStackMigration.octoBagTools112 = 1
    MSBagToolsCharDB._moobStackMigration.completedBy = "MS Bag Tools 1.1.3"
    self.legacyCharacterImported = 1
  elseif type(MSBagToolsCharDB._moobStackMigration) ~= "table" then
    MSBagToolsCharDB._moobStackMigration = characterMarker
  end

  self.legacyBridgeLoaded = type(bridge) == "table" and bridge.loaded == 1 and 1 or nil
end

function MSB:GetMigrationStatusText()
  local account = type(MSBagToolsDB) == "table" and MSBagToolsDB._moobStackMigration
  local character = type(MSBagToolsCharDB) == "table" and MSBagToolsCharDB._moobStackMigration
  local accountDone = type(account) == "table" and account.octoBagTools112 == 1
  local characterDone = type(character) == "table" and character.octoBagTools112 == 1
  if self.legacyAccountImported or self.legacyCharacterImported then
    return "legacy settings imported this session"
  end
  if accountDone or characterDone then
    return "legacy migration complete"
  end
  if self.legacyBridgeLoaded then
    return "legacy bridge loaded; no legacy data required import"
  end
  return "native MoobStack profile"
end

function MSB:Print(message)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(self.prefix .. tostring(message or ""))
  end
end

function MSB:GetFont()
  if self.db and self.db.usePFUITheme == 1 and pfUI and pfUI.font_default then
    return pfUI.font_default
  end
  return self.fontFallback
end

function MSB:IsInCombat()
  if UnitAffectingCombat then
    return NormalizeBooleanFlag(UnitAffectingCombat("player"))
  end
  return self.combatState
end

function MSB:IsMerchantOpen()
  if self.merchantOpen then return 1 end
  if MerchantFrame and MerchantFrame.IsShown then
    local ok, shown = pcall(MerchantFrame.IsShown, MerchantFrame)
    if ok and NormalizeBooleanFlag(shown) then return 1 end
  end
  return nil
end

function MSB:HasCursorItem()
  if CursorHasItem then
    local ok, value = pcall(CursorHasItem)
    if ok then return NormalizeBooleanFlag(value) end
  end
  if GetCursorInfo then
    local ok, kind = pcall(GetCursorInfo)
    if ok and kind == "item" then return 1 end
  end
  return nil
end


function MSB:IsBankOpen()
  if self.bankOpen then return 1 end
  if BankFrame and BankFrame.IsShown then
    local ok, shown = pcall(BankFrame.IsShown, BankFrame)
    if ok and NormalizeBooleanFlag(shown) then return 1 end
  end
  if pfUI and pfUI.bag and pfUI.bag.left and pfUI.bag.left.IsShown then
    local ok, shown = pcall(pfUI.bag.left.IsShown, pfUI.bag.left)
    if ok and NormalizeBooleanFlag(shown) then return 1 end
  end
  return nil
end

function MSB:IsInventoryBagID(bag)
  bag = tonumber(bag)
  return bag and bag >= 0 and bag <= 4 and math.floor(bag) == bag and 1 or nil
end

function MSB:IsBankContainerID(bag)
  bag = tonumber(bag)
  if bag == -1 then return 1 end
  return bag and bag >= 5 and bag <= 11 and math.floor(bag) == bag and 1 or nil
end

function MSB:IsSortableContainerID(bag)
  return self:IsInventoryBagID(bag) or self:IsBankContainerID(bag)
end

function MSB:GetScopeForBag(bag)
  if self:IsBankContainerID(bag) then return "BANK" end
  if self:IsInventoryBagID(bag) then return "BAGS" end
  return nil
end

function MSB:NormalizeSortScope(scope)
  scope = string.upper(tostring(scope or "BAGS"))
  if scope == "BANK" or scope == "BANKS" then return "BANK" end
  return "BAGS"
end

function MSB:GetScopeLabel(scope)
  return self:NormalizeSortScope(scope) == "BANK" and "bank" or "bags"
end

function MSB:SlotKey(bag, slot)
  return tostring(bag) .. ":" .. tostring(slot)
end

function MSB:IsUserLocked(bag, slot)
  if not self.charDB or type(self.charDB.locked) ~= "table" then return nil end
  return self.charDB.locked[self:SlotKey(bag, slot)] and 1 or nil
end

function MSB:SetSlotLocked(bag, slot, locked)
  bag = tonumber(bag)
  slot = tonumber(slot)
  if not bag or not slot or slot < 1 or not self:IsSortableContainerID(bag) then
    self:Print("Valid container IDs are bags 0-4, main bank -1, and bank bags 5-11.")
    return
  end
  if self:IsBankContainerID(bag) and not self:IsBankOpen() then
    self:Print("Open the bank before changing a bank-square lock.")
    return
  end
  local maxSlots = self:GetContainerSizeSafe(bag)
  if slot > maxSlots or maxSlots < 1 then
    self:Print("Container " .. bag .. " does not have slot " .. slot .. " available.")
    return
  end
  local key = self:SlotKey(bag, slot)
  if locked then
    self.charDB.locked[key] = 1
  else
    self.charDB.locked[key] = nil
  end
  self.visualsDirty = 1
  self:RefreshSlotVisuals()
  self:RefreshOptionsUI()
end

function MSB:ToggleSlotLock(bag, slot)
  if self.sortJob or self.sellJob then
    self:Print("Wait for the current storage operation to finish.")
    return
  end
  local lock = not self:IsUserLocked(bag, slot)
  self:SetSlotLocked(bag, slot, lock)
  if lock then
    self:Print("Locked container " .. bag .. ", slot " .. slot .. ".")
  else
    self:Print("Unlocked container " .. bag .. ", slot " .. slot .. ".")
  end
end

function MSB:GetLockedCount(scope)
  local count = 0
  local wanted = scope and self:NormalizeSortScope(scope) or nil
  if not self.charDB or type(self.charDB.locked) ~= "table" then return 0 end
  for key, value in pairs(self.charDB.locked) do
    if value then
      local _, _, bagText = string.find(tostring(key), "^(%-?%d+):")
      local bag = tonumber(bagText)
      if not wanted or self:GetScopeForBag(bag) == wanted then count = count + 1 end
    end
  end
  return count
end

function MSB:ClearLocks(silent, scope)
  if not self.charDB then return end
  if scope == nil then
    self.charDB.locked = {}
  else
    local wanted = self:NormalizeSortScope(scope)
    for key in pairs(self.charDB.locked or {}) do
      local _, _, bagText = string.find(tostring(key), "^(%-?%d+):")
      if self:GetScopeForBag(tonumber(bagText)) == wanted then
        self.charDB.locked[key] = nil
      end
    end
  end
  self.visualsDirty = 1
  self:RefreshSlotVisuals()
  self:RefreshOptionsUI()
  if not silent then
    local label = scope and (self:GetScopeLabel(scope) .. " ") or ""
    self:Print("All " .. label .. "square locks cleared.")
  end
end

function MSB:SetLockMode(enabled)
  if enabled then
    self.lockMode = 1
  else
    self.lockMode = nil
  end
  self.visualsDirty = 1
  self:RefreshSlotVisuals()
  self:UpdateToolbar()
  self:RefreshOptionsUI()
  if self.lockMode then
    self:Print("Lock mode enabled. Click inventory or open-bank squares to lock or unlock them.")
  end
end

function MSB:ToggleLockMode()
  self:SetLockMode(not self.lockMode)
end

function MSB:GetOutlineColor()
  local color = self.outlineColors[self.db and self.db.outlineColor or "GOLD"]
  return color or self.outlineColors.GOLD
end

function MSB:CreateSlotVisual(bag, slot, frame)
  if not frame then return nil end
  local key = self:SlotKey(bag, slot)
  local old = self.slotVisuals[key]
  if old and old.frame == frame then return old end
  if old and old.overlay and old.overlay.Hide then old.overlay:Hide() end
  if old and old.edges then
    for _, edge in pairs(old.edges) do if edge and edge.Hide then edge:Hide() end end
  end

  local visual = { frame = frame, bag = bag, slot = slot, edges = {} }
  local edgeNames = { "Top", "Bottom", "Left", "Right" }
  for index = 1, 4 do
    local texture = frame:CreateTexture(nil, "OVERLAY")
    texture:SetTexture(1, 1, 1, 1)
    visual.edges[index] = texture
  end

  local overlay = CreateFrame("Button", nil, frame)
  overlay:SetAllPoints(frame)
  if overlay.SetFrameLevel and frame.GetFrameLevel then
    overlay:SetFrameLevel((frame:GetFrameLevel() or 1) + 8)
  end
  overlay:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  overlay:SetScript("OnClick", function()
    MSB:ToggleSlotLock(bag, slot)
  end)
  overlay:SetScript("OnEnter", function()
    if GameTooltip then
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      if MSB:IsUserLocked(bag, slot) then
        GameTooltip:SetText("Locked bag square")
        GameTooltip:AddLine("Click to unlock this square.", 1, 1, 1)
      else
        GameTooltip:SetText("Unlocked bag square")
        GameTooltip:AddLine("Click to keep this square fixed during sorting.", 1, 1, 1)
      end
      GameTooltip:Show()
    end
  end)
  overlay:SetScript("OnLeave", function()
    if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(this) then GameTooltip:Hide() end
  end)
  overlay:Hide()
  visual.overlay = overlay
  self.slotVisuals[key] = visual
  return visual
end

function MSB:LayoutSlotVisual(visual)
  if not visual or not visual.frame then return end
  if self:IsBankContainerID(visual.bag) and not self:IsBankOpen() then
    if visual.edges then for _, edge in pairs(visual.edges) do if edge then edge:Hide() end end end
    if visual.overlay then visual.overlay:EnableMouse(nil); visual.overlay:Hide() end
    return
  end
  if not self.db or self.db.enabled ~= 1 then
    if visual.edges then for _, edge in pairs(visual.edges) do if edge then edge:Hide() end end end
    if visual.overlay then visual.overlay:EnableMouse(nil); visual.overlay:Hide() end
    return
  end
  local size = Clamp(self.db and self.db.outlineSize or 2, 1, 4)
  local color = self:GetOutlineColor()
  local edges = visual.edges
  if not edges then return end

  edges[1]:ClearAllPoints()
  edges[1]:SetPoint("TOPLEFT", visual.frame, "TOPLEFT", 0, 0)
  edges[1]:SetPoint("TOPRIGHT", visual.frame, "TOPRIGHT", 0, 0)
  edges[1]:SetHeight(size)

  edges[2]:ClearAllPoints()
  edges[2]:SetPoint("BOTTOMLEFT", visual.frame, "BOTTOMLEFT", 0, 0)
  edges[2]:SetPoint("BOTTOMRIGHT", visual.frame, "BOTTOMRIGHT", 0, 0)
  edges[2]:SetHeight(size)

  edges[3]:ClearAllPoints()
  edges[3]:SetPoint("TOPLEFT", visual.frame, "TOPLEFT", 0, 0)
  edges[3]:SetPoint("BOTTOMLEFT", visual.frame, "BOTTOMLEFT", 0, 0)
  edges[3]:SetWidth(size)

  edges[4]:ClearAllPoints()
  edges[4]:SetPoint("TOPRIGHT", visual.frame, "TOPRIGHT", 0, 0)
  edges[4]:SetPoint("BOTTOMRIGHT", visual.frame, "BOTTOMRIGHT", 0, 0)
  edges[4]:SetWidth(size)

  for index = 1, 4 do
    edges[index]:SetVertexColor(color[1], color[2], color[3], color[4])
    if self:IsUserLocked(visual.bag, visual.slot) then edges[index]:Show() else edges[index]:Hide() end
  end

  if self.lockMode then
    visual.overlay:Show()
    visual.overlay:EnableMouse(1)
  else
    visual.overlay:EnableMouse(nil)
    visual.overlay:Hide()
  end
end

function MSB:RefreshPFUISlotVisuals()
  if not (pfUI and pfUI.bags) then return nil end
  local found
  local ids = { 0, 1, 2, 3, 4, -1, 5, 6, 7, 8, 9, 10, 11 }
  for index = 1, table.getn(ids) do
    local bag = ids[index]
    local size = self:GetContainerSizeSafe(bag)
    for slot = 1, size do
      local data = pfUI.bags[bag] and pfUI.bags[bag].slots and pfUI.bags[bag].slots[slot]
      local frame = data and data.frame
      if frame then
        found = 1
        self:LayoutSlotVisual(self:CreateSlotVisual(bag, slot, frame))
      end
    end
  end
  return found
end

function MSB:RefreshDefaultSlotVisuals()
  local found
  for frameIndex = 1, 18 do
    local container = _G["ContainerFrame" .. frameIndex]
    if container and container.GetID then
      local bag = container:GetID()
      if bag and self:IsSortableContainerID(bag) then
        local size = self:GetContainerSizeSafe(bag)
        for buttonIndex = 1, size do
          local button = _G["ContainerFrame" .. frameIndex .. "Item" .. buttonIndex]
          if button and button.GetID then
            local slot = button:GetID()
            if slot and slot >= 1 and slot <= size then
              found = 1
              self:LayoutSlotVisual(self:CreateSlotVisual(bag, slot, button))
            end
          end
        end
      end
    end
  end

  if self:IsBankOpen() then
    local bankSize = self:GetContainerSizeSafe(-1)
    for slot = 1, bankSize do
      local button = _G["BankFrameItem" .. slot]
      if button then
        found = 1
        self:LayoutSlotVisual(self:CreateSlotVisual(-1, slot, button))
      end
    end
  end
  return found
end

function MSB:RefreshSlotVisuals()
  if not self.initialized then return end
  self.visualsDirty = nil
  if not self:RefreshPFUISlotVisuals() then
    self:RefreshDefaultSlotVisuals()
  end
end

function MSB:StyleSmallButton(button, label)
  if not button then return end
  button:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = 1,
    tileSize = 8,
    edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  button:SetBackdropColor(0.04, 0.04, 0.04, 0.95)
  button:SetBackdropBorderColor(0.28, 0.28, 0.28, 1)
  button:SetFont(self:GetFont(), 8, "OUTLINE")
  button:SetText(label)
  button:SetTextColor(0.85, 0.85, 0.85, 1)
  button:SetScript("OnEnter", function()
    this:SetBackdropBorderColor(0.95, 0.78, 0.20, 1)
    this:SetTextColor(1, 1, 1, 1)
    MSB:ShowToolbarTooltip(this)
  end)
  button:SetScript("OnLeave", function()
    this:SetBackdropBorderColor(0.28, 0.28, 0.28, 1)
    MSB:UpdateToolbar()
    if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(this) then GameTooltip:Hide() end
  end)
end

function MSB:ShowToolbarTooltip(button)
  if not GameTooltip then return end
  GameTooltip:SetOwner(button, "ANCHOR_TOP")
  if button == self.toolbarSort then
    GameTooltip:SetText("Sort bags")
    GameTooltip:AddLine("Sorts the backpack and equipped bags while preserving outlined locked squares.", 1, 1, 1, 1)
  elseif button == self.bankToolbarSort then
    GameTooltip:SetText("Sort bank")
    GameTooltip:AddLine("Sorts the main bank and purchased bank-bag containers using the bank order and columns.", 1, 1, 1, 1)
  elseif button == self.toolbarJunk then
    GameTooltip:SetText("Sell junk")
    if self:IsMerchantOpen() then
      local count, value, unknownPrice = self:CountJunk()
      local text = count .. " grey stack(s)"
      if value > 0 then text = text .. ", at least " .. self:FormatMoney(value) end
      if unknownPrice and unknownPrice > 0 then text = text .. "; final value calculated after sale" end
      GameTooltip:AddLine(text, 1, 1, 1, 1)
    else
      GameTooltip:AddLine("Open a merchant, then click to sell grey items.", 1, 1, 1, 1)
    end
  elseif button == self.toolbarLock or button == self.bankToolbarLock then
    GameTooltip:SetText("Lock storage squares")
    GameTooltip:AddLine("Toggle lock mode, then click inventory or bank squares that sorting must leave untouched.", 1, 1, 1, 1)
  elseif button == self.toolbarConfig or button == self.bankToolbarConfig then
    GameTooltip:SetText("MS Bag Tools settings")
  end
  GameTooltip:Show()
end

function MSB:CreateToolbarButton(name, parent, width, label)
  local button = CreateFrame("Button", name, parent)
  button:SetWidth(width)
  button:SetHeight(12)
  self:StyleSmallButton(button, label)
  return button
end

function MSB:RestorePFUISearchAnchor()
  local parent = pfUI and pfUI.bag and pfUI.bag.right
  if not (parent and parent.search and parent.keys) then return end
  parent.search:ClearAllPoints()
  parent.search:SetPoint("TOPLEFT", parent, "TOPLEFT", 2, -2)
  parent.search:SetPoint("TOPRIGHT", parent.keys, "TOPLEFT", -6, -2)
end


function MSB:IsFrameOwnedBy(frame, parent)
  if not frame or not parent then return nil end
  if frame == parent then return 1 end
  if not frame.GetParent then return nil end
  local ok, owner = pcall(frame.GetParent, frame)
  return ok and owner == parent and 1 or nil
end

function MSB:GetPFUIBankHeaderAnchor(parent)
  if not parent then return nil end
  local candidates = {}
  local function Add(frame)
    if frame then table.insert(candidates, frame) end
  end

  -- Prefer pfUI's bag-toggle control because it normally sits immediately to
  -- the left of the close button. Fall back to the close button or common
  -- Common pfUI extension names.
  Add(parent.bags)
  Add(parent.bagButton)
  Add(parent.bankBags)
  Add(parent.bankbags)
  Add(parent.toggleBags)
  Add(parent.close)
  if getglobal then
    Add(getglobal("pfBankBagSlotShow"))
    Add(getglobal("pfBankSlotShow"))
    Add(getglobal("pfBankBags"))
    Add(getglobal("pfBankClose"))
  end

  for index = 1, table.getn(candidates) do
    local frame = candidates[index]
    if self:IsFrameOwnedBy(frame, parent) then return frame end
  end
  return nil
end

function MSB:CaptureFramePoints(frame, key)
  if not frame or not key or self[key] or not frame.GetNumPoints or not frame.GetPoint then return end
  local ok, count = pcall(frame.GetNumPoints, frame)
  if not ok or not count or count < 1 then return end
  local points = {}
  for index = 1, count do
    local success, point, relativeTo, relativePoint, x, y = pcall(frame.GetPoint, frame, index)
    if success and point then
      table.insert(points, { point, relativeTo, relativePoint, x or 0, y or 0 })
    end
  end
  if table.getn(points) > 0 then self[key] = points end
end

function MSB:RestoreCapturedFramePoints(frame, key)
  local points = key and self[key]
  if not frame or type(points) ~= "table" or table.getn(points) < 1 then return nil end
  frame:ClearAllPoints()
  for index = 1, table.getn(points) do
    local point = points[index]
    frame:SetPoint(point[1], point[2], point[3], point[4], point[5])
  end
  return 1
end

function MSB:RestorePFUIBankSearchAnchor()
  local parent = pfUI and pfUI.bag and pfUI.bag.left
  if not (parent and parent.search) then return end
  if self:RestoreCapturedFramePoints(parent.search, "pfUIBankSearchPoints") then return end
  local rightAnchor = self:GetPFUIBankHeaderAnchor(parent)
  parent.search:ClearAllPoints()
  parent.search:SetPoint("TOPLEFT", parent, "TOPLEFT", 2, -2)
  if rightAnchor then
    parent.search:SetPoint("TOPRIGHT", rightAnchor, "TOPLEFT", -6, -2)
  else
    parent.search:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -42, -2)
  end
end

function MSB:AttachBankToolbar()
  local parent = pfUI and pfUI.bag and pfUI.bag.left
  if parent then
    if not self.bankToolbarSort then
      self.bankToolbarSort = self:CreateToolbarButton("MSBagToolsBankSortButton", parent, 15, "S")
      self.bankToolbarLock = self:CreateToolbarButton("MSBagToolsBankLockButton", parent, 15, "L")
      self.bankToolbarConfig = self:CreateToolbarButton("MSBagToolsBankConfigButton", parent, 15, "O")
      self.bankToolbarSort:SetScript("OnClick", function() MSB:StartSort("BANK") end)
      self.bankToolbarLock:SetScript("OnClick", function() MSB:ToggleLockMode() end)
      self.bankToolbarConfig:SetScript("OnClick", function() MSB:ToggleOptions() end)
    else
      self.bankToolbarSort:SetParent(parent)
      self.bankToolbarLock:SetParent(parent)
      self.bankToolbarConfig:SetParent(parent)
    end
    self.bankToolbarSort:SetWidth(15); self.bankToolbarSort:SetHeight(12)
    self.bankToolbarLock:SetWidth(15); self.bankToolbarLock:SetHeight(12)
    self.bankToolbarConfig:SetWidth(15); self.bankToolbarConfig:SetHeight(12)
    local rightAnchor = self:GetPFUIBankHeaderAnchor(parent)
    self.bankToolbarConfig:ClearAllPoints()
    if rightAnchor then
      -- Keep the MS Bag Tools controls immediately to the left of pfUI's own
      -- bag-toggle/close controls instead of covering them.
      self.bankToolbarConfig:SetPoint("TOPRIGHT", rightAnchor, "TOPLEFT", -3, 0)
      self.bankToolbarAnchorName = SafeCall(rightAnchor.GetName, rightAnchor) or "pfUI bank header control"
    else
      -- Reserve enough room for the common 12px close and bag-toggle buttons.
      self.bankToolbarConfig:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -42, -3)
      self.bankToolbarAnchorName = "pfBank reserved top-right"
    end
    self.bankToolbarLock:ClearAllPoints()
    self.bankToolbarLock:SetPoint("TOPRIGHT", self.bankToolbarConfig, "TOPLEFT", -2, 0)
    self.bankToolbarSort:ClearAllPoints()
    self.bankToolbarSort:SetPoint("TOPRIGHT", self.bankToolbarLock, "TOPLEFT", -2, 0)

    if parent.search then
      self:CaptureFramePoints(parent.search, "pfUIBankSearchPoints")
      parent.search:ClearAllPoints()
      parent.search:SetPoint("TOPLEFT", parent, "TOPLEFT", 2, -2)
      parent.search:SetPoint("TOPRIGHT", self.bankToolbarSort, "TOPLEFT", -3, -2)
    end

    self.bankPfAttached = 1
    return 1
  end

  local stockParent = BankFrame
  if stockParent and not self.bankFallbackToolbar then
    local bar = CreateFrame("Frame", "MSBagToolsBankFallbackBar", stockParent)
    bar:SetWidth(64)
    bar:SetHeight(18)
    bar:SetPoint("TOPRIGHT", stockParent, "TOPRIGHT", -34, -18)
    bar:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = 1, tileSize = 8, edgeSize = 8,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    bar:SetBackdropColor(0.03, 0.03, 0.03, 0.95)
    bar:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    self.bankFallbackToolbar = bar
    self.bankToolbarSort = self:CreateToolbarButton("MSBagToolsBankFallbackSort", bar, 18, "S")
    self.bankToolbarLock = self:CreateToolbarButton("MSBagToolsBankFallbackLock", bar, 18, "L")
    self.bankToolbarConfig = self:CreateToolbarButton("MSBagToolsBankFallbackConfig", bar, 18, "O")
    self.bankToolbarSort:SetPoint("LEFT", bar, "LEFT", 3, 0)
    self.bankToolbarLock:SetPoint("LEFT", self.bankToolbarSort, "RIGHT", 1, 0)
    self.bankToolbarConfig:SetPoint("LEFT", self.bankToolbarLock, "RIGHT", 1, 0)
    self.bankToolbarSort:SetScript("OnClick", function() MSB:StartSort("BANK") end)
    self.bankToolbarLock:SetScript("OnClick", function() MSB:ToggleLockMode() end)
    self.bankToolbarConfig:SetScript("OnClick", function() MSB:ToggleOptions() end)
  end
  return nil
end

function MSB:AttachToolbar()
  if not self.initialized then return end
  self:AttachBankToolbar()
  local parent = pfUI and pfUI.bag and pfUI.bag.right
  if parent then
    if not self.toolbarSort then
      self.toolbarSort = self:CreateToolbarButton("MSBagToolsSortButton", parent, 15, "S")
      self.toolbarJunk = self:CreateToolbarButton("MSBagToolsJunkButton", parent, 15, "$")
      self.toolbarLock = self:CreateToolbarButton("MSBagToolsLockButton", parent, 15, "L")
      self.toolbarConfig = self:CreateToolbarButton("MSBagToolsConfigButton", parent, 15, "O")

      self.toolbarSort:SetScript("OnClick", function() MSB:StartSort() end)
      self.toolbarJunk:SetScript("OnClick", function() MSB:StartSellJunk() end)
      self.toolbarLock:SetScript("OnClick", function() MSB:ToggleLockMode() end)
      self.toolbarConfig:SetScript("OnClick", function() MSB:ToggleOptions() end)
    else
      self.toolbarSort:SetParent(parent)
      self.toolbarJunk:SetParent(parent)
      self.toolbarLock:SetParent(parent)
      self.toolbarConfig:SetParent(parent)
    end
    self.toolbarSort:SetWidth(15); self.toolbarSort:SetHeight(12)
    self.toolbarJunk:SetWidth(15); self.toolbarJunk:SetHeight(12)
    self.toolbarLock:SetWidth(15); self.toolbarLock:SetHeight(12)
    self.toolbarConfig:SetWidth(15); self.toolbarConfig:SetHeight(12)

    local rightAnchor = parent.keys or parent.close
    self.toolbarConfig:ClearAllPoints()
    self.toolbarConfig:SetPoint("TOPRIGHT", rightAnchor, "TOPLEFT", -3, 0)
    self.toolbarLock:ClearAllPoints()
    self.toolbarLock:SetPoint("TOPRIGHT", self.toolbarConfig, "TOPLEFT", -2, 0)
    self.toolbarJunk:ClearAllPoints()
    self.toolbarJunk:SetPoint("TOPRIGHT", self.toolbarLock, "TOPLEFT", -2, 0)
    self.toolbarSort:ClearAllPoints()
    self.toolbarSort:SetPoint("TOPRIGHT", self.toolbarJunk, "TOPLEFT", -2, 0)

    if parent.search then
      parent.search:ClearAllPoints()
      parent.search:SetPoint("TOPLEFT", parent, "TOPLEFT", 2, -2)
      parent.search:SetPoint("TOPRIGHT", self.toolbarSort, "TOPLEFT", -3, -2)
    end
    self.pfAttached = 1
    self:UpdateToolbar()
    self:RefreshSlotVisuals()
    return 1
  end

  if not self.fallbackToolbar then
    local bar = CreateFrame("Frame", "MSBagToolsFallbackBar", UIParent)
    bar:SetWidth(82)
    bar:SetHeight(18)
    bar:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -210, -110)
    bar:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = 1, tileSize = 8, edgeSize = 8,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    bar:SetBackdropColor(0.03, 0.03, 0.03, 0.95)
    bar:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    self.fallbackToolbar = bar
    self.toolbarSort = self:CreateToolbarButton("MSBagToolsFallbackSort", bar, 18, "S")
    self.toolbarJunk = self:CreateToolbarButton("MSBagToolsFallbackJunk", bar, 18, "$")
    self.toolbarLock = self:CreateToolbarButton("MSBagToolsFallbackLock", bar, 18, "L")
    self.toolbarConfig = self:CreateToolbarButton("MSBagToolsFallbackConfig", bar, 18, "O")
    self.toolbarSort:SetPoint("LEFT", bar, "LEFT", 3, 0)
    self.toolbarJunk:SetPoint("LEFT", self.toolbarSort, "RIGHT", 1, 0)
    self.toolbarLock:SetPoint("LEFT", self.toolbarJunk, "RIGHT", 1, 0)
    self.toolbarConfig:SetPoint("LEFT", self.toolbarLock, "RIGHT", 1, 0)
    self.toolbarSort:SetScript("OnClick", function() MSB:StartSort() end)
    self.toolbarJunk:SetScript("OnClick", function() MSB:StartSellJunk() end)
    self.toolbarLock:SetScript("OnClick", function() MSB:ToggleLockMode() end)
    self.toolbarConfig:SetScript("OnClick", function() MSB:ToggleOptions() end)
  end
  self:UpdateToolbar()
  return nil
end

function MSB:UpdateToolbar()
  local shown = self.db and self.db.enabled == 1 and self.db.showToolbar == 1
  local buttons = { self.toolbarSort, self.toolbarJunk, self.toolbarLock, self.toolbarConfig }
  for _, button in pairs(buttons) do
    if button then
      if shown then button:Show() else button:Hide() end
      button:SetFont(self:GetFont(), 8, "OUTLINE")
    end
  end
  if self.fallbackToolbar then
    if shown and not self.pfAttached then self.fallbackToolbar:Show() else self.fallbackToolbar:Hide() end
  end
  if not shown and self.pfAttached then self:RestorePFUISearchAnchor() end
  if not shown and self.bankPfAttached then self:RestorePFUIBankSearchAnchor() end

  local bankShown = shown and self:IsBankOpen()
  local bankButtons = { self.bankToolbarSort, self.bankToolbarLock, self.bankToolbarConfig }
  for _, button in pairs(bankButtons) do
    if button then
      if bankShown then button:Show() else button:Hide() end
      button:SetFont(self:GetFont(), 8, "OUTLINE")
    end
  end
  if self.bankFallbackToolbar then
    if bankShown and not self.bankPfAttached then self.bankFallbackToolbar:Show() else self.bankFallbackToolbar:Hide() end
  end

  local lockColor = self.lockMode and { 1, 0.78, 0.15, 1 } or { 0.85, 0.85, 0.85, 1 }
  if self.toolbarLock then
    self.toolbarLock:SetTextColor(lockColor[1], lockColor[2], lockColor[3], lockColor[4])
    if self.lockMode then self.toolbarLock:SetBackdropBorderColor(1, 0.65, 0.10, 1) end
  end
  if self.bankToolbarLock then
    self.bankToolbarLock:SetTextColor(lockColor[1], lockColor[2], lockColor[3], lockColor[4])
    if self.lockMode then self.bankToolbarLock:SetBackdropBorderColor(1, 0.65, 0.10, 1) end
  end
  if self.toolbarJunk then
    if self:IsMerchantOpen() then
      self.toolbarJunk:SetTextColor(0.35, 1.00, 0.40, 1)
    else
      self.toolbarJunk:SetTextColor(0.45, 0.45, 0.45, 1)
    end
  end
  if self.toolbarSort then
    if self.sortJob and self.sortJob.scope == "BAGS" then
      self.toolbarSort:SetTextColor(1, 0.78, 0.15, 1)
    else
      self.toolbarSort:SetTextColor(0.85, 0.85, 0.85, 1)
    end
  end
  if self.bankToolbarSort then
    if self.sortJob and self.sortJob.scope == "BANK" then
      self.bankToolbarSort:SetTextColor(1, 0.78, 0.15, 1)
    else
      self.bankToolbarSort:SetTextColor(0.85, 0.85, 0.85, 1)
    end
  end
end

function MSB:ParseItemID(link)
  if type(link) ~= "string" then return 0 end
  local _, _, id = string.find(link, "item:(%d+)")
  return tonumber(id) or 0
end

-- Container metadata can briefly be unavailable while the old client is
-- rebuilding pfUI's bank. Never let one C-backed API error abort a complete
-- inventory or bank operation.
function MSB:GetContainerSizeSafe(bag)
  if type(GetContainerNumSlots) ~= "function" then return 0 end
  local ok, size = pcall(GetContainerNumSlots, bag)
  if not ok then
    self.containerSizeErrors = SafeNumber(self.containerSizeErrors, 0) + 1
    self.lastContainerSizeError = tostring(size)
    return 0
  end
  size = math.floor(SafeNumber(size, 0))
  if size < 0 then size = 0 end
  return size
end

function MSB:GetBagNameSafe(bag)
  if type(GetBagName) ~= "function" then return nil end
  local ok, name = pcall(GetBagName, bag)
  if ok and type(name) == "string" and name ~= "" then return name end
  return nil
end

-- Resolve an equipped bag link without exposing GetInventoryItemLink to an
-- invalid slot ID. On WoW 1.12.1-compatible clients, bank bag containers are 5-11 and those
-- exact IDs are passed to BankButtonIDToInvSlotID when isBag is true.
function MSB:GetContainerBagLink(bag)
  bag = tonumber(bag)
  if not bag or bag == 0 or bag == -1 or type(GetInventoryItemLink) ~= "function" then return nil end
  if bag >= 5 and bag <= 11 and self:GetContainerSizeSafe(bag) <= 0 then return nil end

  local candidates = {}
  local seen = {}
  local function AddCandidate(value, source)
    value = tonumber(value)
    if value and value > 0 and math.floor(value) == value and not seen[value] then
      seen[value] = 1
      table.insert(candidates, { inventoryID = value, source = source })
    end
  end

  if bag >= 5 and bag <= 11 and type(BankButtonIDToInvSlotID) == "function" then
    local ok, value = pcall(BankButtonIDToInvSlotID, bag, 1)
    if ok then AddCandidate(value, "BankButtonIDToInvSlotID") end
  end

  if bag >= 1 and bag <= 4 and type(ContainerIDToInventoryID) == "function" then
    local ok, value = pcall(ContainerIDToInventoryID, bag)
    if ok then AddCandidate(value, "ContainerIDToInventoryID") end
  end

  if bag >= 1 and bag <= 4 then AddCandidate(19 + bag, "Vanilla carried-bag fallback") end

  local acceptedNil
  local lastError
  for index = 1, table.getn(candidates) do
    local candidate = candidates[index]
    local ok, link = pcall(GetInventoryItemLink, "player", candidate.inventoryID)
    if ok then
      if type(link) == "string" and link ~= "" then
        self.lastBagInventoryLookupError = nil
        return link
      end
      -- A valid but empty/unpurchased equipped-bag slot returns nil.
      acceptedNil = 1
    else
      self.inventoryLinkErrors = SafeNumber(self.inventoryLinkErrors, 0) + 1
      lastError = "container " .. tostring(bag) .. " via " .. tostring(candidate.source) ..
        " returned inventory slot " .. tostring(candidate.inventoryID) .. ": " .. tostring(link)
      self.lastInventoryLinkError = tostring(link)
    end
  end

  if acceptedNil then
    self.lastBagInventoryLookupError = nil
    return nil
  end
  self.lastBagInventoryLookupError = lastError or
    ("no valid inventory-slot resolver for container " .. tostring(bag))
  return nil
end

function MSB:GetBagGroup(bag)
  if bag == 0 or bag == -1 then return "GENERAL" end

  -- Prefer direct family data when the client extension provides it.
  if type(GetBagFamily) == "function" then
    local ok, family = pcall(GetBagFamily, bag)
    if ok and type(family) == "string" then
      local familyUpper = string.upper(family)
      if familyUpper == "QUIVER" or familyUpper == "SOULBAG" or
         familyUpper == "SPECIAL" or familyUpper == "KEYRING" then
        return "SPECIAL:" .. familyUpper
      end
    elseif ok and type(family) == "number" and family > 0 then
      return "FAMILY:" .. family
    end
  end

  -- GetBagName accepts the actual container ID and avoids any bank inventory-
  -- slot translation. Only use the protected inventory-link path as fallback.
  local reference = self:GetBagNameSafe(bag)
  if not reference then reference = self:GetContainerBagLink(bag) end
  if not reference then return "GENERAL" end

  if type(GetItemFamily) == "function" then
    local ok, family = pcall(GetItemFamily, reference)
    if ok and type(family) == "number" and family > 0 then
      return "FAMILY:" .. family
    end
  end

  if type(GetItemInfo) ~= "function" then return "GENERAL" end
  local ok, _, _, _, _, _, itemType, subType = pcall(GetItemInfo, reference)
  if not ok then return "GENERAL" end
  local sub = Lower(subType)
  local kind = Lower(itemType)
  if string.find(sub, "quiver") or string.find(sub, "ammo") or
     string.find(sub, "soul") or string.find(sub, "herb") or
     string.find(sub, "enchant") or string.find(sub, "engineering") or
     kind == "quiver" then
    return "SPECIAL:" .. (sub ~= "" and sub or kind)
  end

  return "GENERAL"
end

function MSB:GetPFUISlotFrame(bag, slot)
  if not (pfUI and pfUI.bags and pfUI.bags[bag] and pfUI.bags[bag].slots) then return nil end
  local data = pfUI.bags[bag].slots[slot]
  if type(data) ~= "table" then return nil end
  local frame = data.frame
  if type(frame) ~= "table" and type(frame) ~= "userdata" then return nil end
  return frame
end

function MSB:GetGridColumns(scope)
  scope = self:NormalizeSortScope(scope)
  local columns
  if scope == "BANK" then
    columns = self.db and self.db.bankGridColumns or 12
  else
    columns = self.db and self.db.gridColumns or 12
  end
  return math.floor(Clamp(columns, 4, 24))
end

function MSB:GetConfiguredPFUIColumns(scope)
  if type(pfUI_config) ~= "table" or type(pfUI_config.appearance) ~= "table" or
     type(pfUI_config.appearance.bags) ~= "table" then
    return nil
  end
  scope = self:NormalizeSortScope(scope)
  local key = scope == "BANK" and "bankrowlength" or "bagrowlength"
  local columns = tonumber(pfUI_config.appearance.bags[key])
  if not columns then return nil end
  return math.floor(Clamp(columns, 4, 24))
end

function MSB:ApplyPFUIGridColumns()
  if type(pfUI_config) ~= "table" then
    self.lastPFUIColumnsApplied = nil
    self.lastPFUIBankColumnsApplied = nil
    return nil
  end
  if type(pfUI_config.appearance) ~= "table" then pfUI_config.appearance = {} end
  if type(pfUI_config.appearance.bags) ~= "table" then pfUI_config.appearance.bags = {} end

  local bagColumns = self:GetGridColumns("BAGS")
  local bankColumns = self:GetGridColumns("BANK")
  local bagText = tostring(bagColumns)
  local bankText = tostring(bankColumns)
  local bagChanged = pfUI_config.appearance.bags.bagrowlength ~= bagText
  local bankChanged = pfUI_config.appearance.bags.bankrowlength ~= bankText
  pfUI_config.appearance.bags.bagrowlength = bagText
  pfUI_config.appearance.bags.bankrowlength = bankText
  self.lastPFUIColumnsApplied = bagColumns
  self.lastPFUIBankColumnsApplied = bankColumns

  if pfUI and pfUI.bag and pfUI.bag.CreateBags then
    if bagChanged then pcall(function() pfUI.bag:CreateBags() end) end
    if bankChanged then pcall(function() pfUI.bag:CreateBags("bank") end) end
  end
  return 1
end

function MSB:CopyDefaultBagOrder()
  local order = {}
  for index = 1, table.getn(self.defaultBagOrder) do
    order[index] = self.defaultBagOrder[index]
  end
  return order
end

-- Validate a five-bag permutation. The setting is stored as a compact string
-- because it is easy to inspect and remains compatible with old saved-variable
-- serializers. Table values are also accepted for migration and UI use.
function MSB:NormalizeBagOrder(value)
  local source = value
  if type(value) == "string" then
    local cleaned = value
    cleaned = string.gsub(cleaned, ",", " ")
    cleaned = string.gsub(cleaned, ">", " ")
    cleaned = string.gsub(cleaned, "%-", " ")
    cleaned = string.gsub(cleaned, "|", " ")
    cleaned = string.gsub(cleaned, "/", " ")
    local _, _, a, b, c, d, e = string.find(cleaned, "^%s*([0-4])%s+([0-4])%s+([0-4])%s+([0-4])%s+([0-4])%s*$")
    if not a then return nil end
    source = { tonumber(a), tonumber(b), tonumber(c), tonumber(d), tonumber(e) }
  end

  if type(source) ~= "table" or table.getn(source) ~= 5 then return nil end
  local order = {}
  local seen = {}
  for index = 1, 5 do
    local bag = tonumber(source[index])
    if not bag or bag < 0 or bag > 4 or math.floor(bag) ~= bag or seen[bag] then
      return nil
    end
    seen[bag] = 1
    order[index] = bag
  end
  for bag = 0, 4 do
    if not seen[bag] then return nil end
  end
  return order
end

function MSB:SerializeBagOrder(value)
  local order = self:NormalizeBagOrder(value)
  if not order then order = self:CopyDefaultBagOrder() end
  return table.concat(order, ",")
end

function MSB:GetMergedBagOrder()
  local order = self:NormalizeBagOrder(self.db and self.db.bagOrder)
  if not order then order = self:CopyDefaultBagOrder() end
  return order
end

function MSB:GetBagOrderText(separator)
  return table.concat(self:GetMergedBagOrder(), separator or " > ")
end

function MSB:SetBagOrder(value, silent)
  if not self.db then return nil end
  local order = self:NormalizeBagOrder(value)
  if not order then return nil end
  self.db.bagOrder = self:SerializeBagOrder(order)
  self.visualsDirty = 1
  self:RefreshOptionsUI()
  if not silent then
    self:Print("Bag fill order set to " .. self:GetBagOrderText(" > ") .. ".")
  end
  return 1
end

function MSB:MoveBagInOrder(bag, direction)
  bag = tonumber(bag)
  direction = tonumber(direction)
  if not bag or bag < 0 or bag > 4 or not direction or direction == 0 then return nil end
  local order = self:GetMergedBagOrder()
  local index
  for position = 1, table.getn(order) do
    if order[position] == bag then index = position break end
  end
  if not index then return nil end
  local target = index + (direction < 0 and -1 or 1)
  if target < 1 or target > table.getn(order) then return nil end
  order[index], order[target] = order[target], order[index]
  return self:SetBagOrder(order, 1)
end


function MSB:CopyDefaultBankOrder()
  local order = {}
  for index = 1, table.getn(self.defaultBankOrder) do order[index] = self.defaultBankOrder[index] end
  return order
end

function MSB:NormalizeBankOrder(value)
  local source = value
  if type(value) == "string" then
    source = {}
    if StringPatternIterator then
      for token in StringPatternIterator(value, "%-?%d+") do
        table.insert(source, tonumber(token))
      end
    else
      -- Extremely defensive fallback for a client with neither standard name.
      local searchAt = 1
      while 1 do
        local first, last, token = string.find(value, "(%-?%d+)", searchAt)
        if not first then break end
        table.insert(source, tonumber(token))
        searchAt = last + 1
      end
    end
  end
  local expected = self.defaultBankOrder
  if type(source) ~= "table" or table.getn(source) ~= table.getn(expected) then return nil end
  local allowed, seen, order = {}, {}, {}
  for index = 1, table.getn(expected) do allowed[expected[index]] = 1 end
  for index = 1, table.getn(source) do
    local bag = tonumber(source[index])
    if not bag or not allowed[bag] or seen[bag] then return nil end
    seen[bag] = 1
    order[index] = bag
  end
  for bag in pairs(allowed) do if not seen[bag] then return nil end end
  return order
end

function MSB:SerializeBankOrder(value)
  local order = self:NormalizeBankOrder(value)
  if not order then order = self:CopyDefaultBankOrder() end
  return table.concat(order, ",")
end

function MSB:GetMergedBankOrder()
  local order = self:NormalizeBankOrder(self.db and self.db.bankOrder)
  if not order then order = self:CopyDefaultBankOrder() end
  return order
end

function MSB:GetBankOrderText(separator)
  return table.concat(self:GetMergedBankOrder(), separator or " > ")
end

function MSB:SetBankOrder(value, silent)
  if not self.db then return nil end
  local order = self:NormalizeBankOrder(value)
  if not order then return nil end
  self.db.bankOrder = self:SerializeBankOrder(order)
  self.visualsDirty = 1
  self:RefreshOptionsUI()
  if not silent then self:Print("Bank fill order set to " .. self:GetBankOrderText(" > ") .. ".") end
  return 1
end

function MSB:MoveBankInOrder(bag, direction)
  bag = tonumber(bag)
  direction = tonumber(direction)
  if not bag or not direction or direction == 0 then return nil end
  local order = self:GetMergedBankOrder()
  local index
  for position = 1, table.getn(order) do if order[position] == bag then index = position break end end
  if not index then return nil end
  local target = index + (direction < 0 and -1 or 1)
  if target < 1 or target > table.getn(order) then return nil end
  order[index], order[target] = order[target], order[index]
  return self:SetBankOrder(order, 1)
end

function MSB:DescribeVisualBagOrder(positions)
  local order = {}
  local seen = {}
  for index = 1, table.getn(positions) do
    local bag = positions[index].bag
    if not seen[bag] then
      seen[bag] = 1
      table.insert(order, tostring(bag))
    end
  end
  if table.getn(order) == 0 then return "none" end
  return table.concat(order, " > ")
end

-- Build a deterministic row-major destination stream using the user-selected
-- physical bag order. The first slot of the first configured bag is the top-left
-- square. Items compact toward the beginning of this stream and empty squares
-- collect at the bottom of pfUI's single inventory block.
-- Live frame coordinates are intentionally ignored because hidden/rebuilt
-- pfUI frames can briefly report stale or reversed positions.
function MSB:BuildVisualSlotOrder(scope)
  scope = self:NormalizeSortScope(scope)
  local positions = {}
  local order = scope == "BANK" and self:GetMergedBankOrder() or self:GetMergedBagOrder()
  local columns = self:GetGridColumns(scope)
  local visualIndex = 0

  for orderIndex = 1, table.getn(order) do
    local bag = order[orderIndex]
    local size = self:GetContainerSizeSafe(bag)
    for slot = 1, size do
      visualIndex = visualIndex + 1
      table.insert(positions, {
        bag = bag,
        slot = slot,
        scope = scope,
        visualIndex = visualIndex,
        visualRow = math.floor((visualIndex - 1) / columns) + 1,
        visualColumn = (visualIndex - 1) - math.floor((visualIndex - 1) / columns) * columns + 1,
      })
    end
  end

  local source = scope == "BANK" and
    (pfUI and "pfUI configured merged bank grid" or "configured bank grid") or
    (pfUI and "pfUI configured merged bag grid" or "configured bag grid")
  local bagOrder = self:DescribeVisualBagOrder(positions)
  local rows = table.getn(positions) > 0 and math.floor((table.getn(positions) + columns - 1) / columns) or 0
  if scope == "BANK" then
    self.lastBankLayoutSource = source
    self.lastBankLayoutBagOrder = bagOrder
    self.lastBankLayoutSlots = table.getn(positions)
    self.lastBankLayoutColumns = columns
    self.lastBankLayoutRows = rows
  else
    self.lastLayoutSource = source
    self.lastLayoutBagOrder = bagOrder
    self.lastLayoutSlots = table.getn(positions)
    self.lastLayoutColumns = columns
    self.lastLayoutRows = rows
  end
  return positions
end

function MSB:BuildSortGroups(excludedSlots, scope)
  scope = self:NormalizeSortScope(scope)
  local groups = {}
  local byKey = {}
  local bagGroups = {}
  local visualSlots = self:BuildVisualSlotOrder(scope)

  -- Classify only containers that contributed real slots. This avoids probing
  -- unavailable or unpurchased bank-bag IDs that remain in the saved order.
  for index = 1, table.getn(visualSlots) do
    local bag = visualSlots[index].bag
    if bagGroups[bag] == nil then bagGroups[bag] = self:GetBagGroup(bag) end
  end

  for index = 1, table.getn(visualSlots) do
    local position = visualSlots[index]
    local slotKey = self:SlotKey(position.bag, position.slot)
    if not self:IsUserLocked(position.bag, position.slot) and
       not (type(excludedSlots) == "table" and excludedSlots[slotKey]) then
      local key = bagGroups[position.bag] or "GENERAL"
      local group = byKey[key]
      if not group then
        group = { key = key, slots = {}, firstVisualIndex = position.visualIndex, scope = scope }
        byKey[key] = group
        table.insert(groups, group)
      end
      table.insert(group.slots, position)
    end
  end

  table.sort(groups, function(a, b)
    return SafeNumber(a.firstVisualIndex, 9999) < SafeNumber(b.firstVisualIndex, 9999)
  end)
  return groups
end

function MSB:BuildMergeGroup(excludedSlots, scope)
  scope = self:NormalizeSortScope(scope)
  local group = { key = "ALL_STACKS", slots = {}, firstVisualIndex = 1, scope = scope }
  local visualSlots = self:BuildVisualSlotOrder(scope)
  for index = 1, table.getn(visualSlots) do
    local position = visualSlots[index]
    local slotKey = self:SlotKey(position.bag, position.slot)
    if not self:IsUserLocked(position.bag, position.slot) and
       not (type(excludedSlots) == "table" and excludedSlots[slotKey]) then
      table.insert(group.slots, position)
    end
  end
  return group
end

function MSB:GetItemInfoRecord(link, itemID)
  self.itemInfoCache = self.itemInfoCache or {}
  local key
  if SafeNumber(itemID, 0) > 0 then
    key = "ID:" .. tostring(itemID)
  else
    key = "LINK:" .. Lower(link or "")
  end

  local record = self.itemInfoCache[key] or {}

  local function Capture(query)
    if not GetItemInfo or query == nil then return end
    local ok, name, itemLink, quality, itemLevel, requiredLevel, itemType,
      subType, maxStack, equipLoc, texture, sellPrice = pcall(GetItemInfo, query)
    if not ok then return end
    if name ~= nil then record.name = name end
    if itemLink ~= nil then record.itemLink = itemLink end
    if quality ~= nil then record.quality = quality end
    if itemLevel ~= nil then record.itemLevel = itemLevel end
    if requiredLevel ~= nil then record.requiredLevel = requiredLevel end
    if itemType ~= nil then record.itemType = itemType end
    if subType ~= nil then record.subType = subType end
    if maxStack ~= nil then record.maxStack = maxStack end
    if equipLoc ~= nil then record.equipLoc = equipLoc end
    if texture ~= nil then record.texture = texture end
    -- The stock 1.12 GetItemInfo result does not consistently expose a vendor
    -- value on every community-maintained 1.12.1 client. Preserve whether the value was
    -- actually supplied so grey items with an unknown price are still offered
    -- to the merchant instead of being silently excluded from Sell Junk.
    if sellPrice ~= nil then
      record.sellPrice = SafeNumber(sellPrice, 0)
      record.sellPriceKnown = 1
    end
  end

  if link then Capture(link) end
  if (not record.name or not record.maxStack or not record.itemType) and SafeNumber(itemID, 0) > 0 then
    Capture(itemID)
  end

  self.itemInfoCache[key] = record
  return record
end

function MSB:GuessStackLimit(observedCount)
  observedCount = math.max(1, math.floor(SafeNumber(observedCount, 1)))
  local commonLimits = { 5, 10, 20, 50, 100, 200, 250, 500, 1000 }
  for index = 1, table.getn(commonLimits) do
    if observedCount <= commonLimits[index] then return commonLimits[index] end
  end
  return observedCount
end

function MSB:GetStackLimitKey(itemID, name, texture)
  if SafeNumber(itemID, 0) > 0 then return "ID:" .. tostring(itemID) end
  return "FALLBACK:" .. Lower(name or "") .. "|" .. Lower(texture or "")
end

function MSB:ResolveStackLimit(itemID, reportedLimit, count, name, texture)
  self.stackLimitCache = self.stackLimitCache or {}
  local key = self:GetStackLimitKey(itemID, name, texture)
  local cached = self.stackLimitCache[key] or { observed = 0, limit = 1, reported = nil }
  count = math.max(1, math.floor(SafeNumber(count, 1)))
  if count > cached.observed then cached.observed = count end

  reportedLimit = math.floor(SafeNumber(reportedLimit, 1))
  if reportedLimit > 1 then
    cached.limit = reportedLimit
    cached.reported = 1
  elseif not cached.reported then
    local guessed = self:GuessStackLimit(cached.observed)
    if guessed > cached.limit then cached.limit = guessed end
  end

  self.stackLimitCache[key] = cached
  return math.max(1, SafeNumber(cached.limit, 1)), cached.reported and nil or 1
end

-- Stackable item instances can carry different unique/random fields in their
-- hyperlink payload even though the client permits them to stack. Item ID is
-- therefore the authoritative merge identity. Randomized equipment is not
-- affected because it is non-stackable (maximum stack size 1).
function MSB:GetStackKey(item)
  if not item then return nil end
  if SafeNumber(item.maxStack, 1) <= 1 and SafeNumber(item.count, 1) <= 1 then return nil end
  if SafeNumber(item.itemID, 0) > 0 then return "ITEM:" .. tostring(item.itemID) end
  if type(item.link) == "string" then
    local _, _, id = string.find(item.link, "item:(%d+)")
    if id then return "ITEM:" .. tostring(id) end
  end
  local name = item.nameLower or Lower(item.name or "")
  local texture = Lower(item.texture or "")
  if name ~= "" or texture ~= "" then return "FALLBACK:" .. name .. "|" .. texture end
  return nil
end

function MSB:ReadItem(position)
  if not position then return nil end
  local texture, count, apiLocked, containerQuality = GetContainerItemInfo(position.bag, position.slot)
  if apiLocked == 0 or apiLocked == "0" then self.numericZeroLockSeen = 1 end
  local normalizedAPILock = NormalizeBooleanFlag(apiLocked)
  local link = GetContainerItemLink(position.bag, position.slot)
  if not texture and not link then return nil end

  local itemID = self:ParseItemID(link)
  local info = self:GetItemInfoRecord(link, itemID)
  local name = info.name
  local quality = info.quality
  local itemLevel = info.itemLevel
  local requiredLevel = info.requiredLevel
  local itemType = info.itemType
  local subType = info.subType
  local maxStack = info.maxStack
  local equipLoc = info.equipLoc
  local itemTexture = info.texture
  local sellPrice = info.sellPrice

  local normalizedCount = math.max(1, math.floor(SafeNumber(count, 1)))
  local resolvedLimit, inferredLimit = self:ResolveStackLimit(
    itemID, maxStack, normalizedCount, name or link, texture or itemTexture)
  local identity = link or texture or (tostring(position.bag) .. ":" .. tostring(position.slot))
  local record = {
    bag = position.bag,
    slot = position.slot,
    position = position,
    texture = texture or itemTexture,
    count = normalizedCount,
    apiLocked = normalizedAPILock,
    rawAPILocked = apiLocked,
    containerQuality = SafeNumber(containerQuality, -1),
    name = name or link or "Unknown item",
    nameLower = Lower(name or link or ""),
    quality = SafeNumber(quality, SafeNumber(containerQuality, -1)),
    itemLevel = SafeNumber(itemLevel, 0),
    requiredLevel = SafeNumber(requiredLevel, 0),
    itemType = itemType or "",
    itemTypeLower = Lower(itemType),
    subType = subType or "",
    subTypeLower = Lower(subType),
    maxStack = resolvedLimit,
    maxStackInferred = inferredLimit,
    equipLoc = equipLoc or "",
    sellPrice = SafeNumber(sellPrice, 0),
    sellPriceKnown = info.sellPriceKnown and 1 or nil,
    identity = identity,
    itemID = itemID,
    link = link,
  }
  record.stackKey = self:GetStackKey(record)
  return record
end

function MSB:GetItemSearchText(item)
  if not item then return "" end
  return table.concat({
    item.nameLower or "",
    item.itemTypeLower or "",
    item.subTypeLower or "",
    Lower(item.texture or ""),
  }, " ")
end

function MSB:IsDrinkItem(item)
  if not item then return nil end
  local name = item.nameLower or ""
  local texture = Lower(item.texture or "")
  if ContainsAny(texture, { "inv_drink", "drink_", "water_", "milk_" }) then return 1 end
  if ContainsAny(name, {
    "water", "juice", "milk", "tea", "coffee", "nectar", "lemonade",
    "ale", "beer", "rum", "wine", "grog", "cider", "mead", "brew",
  }) then return 1 end
  return nil
end

function MSB:IsFoodItem(item)
  if not item then return nil end
  local name = item.nameLower or ""
  local texture = Lower(item.texture or "")
  if ContainsAny(texture, { "inv_misc_food", "food_", "meat_", "fish_" }) then return 1 end
  if ContainsAny(name, {
    "bread", "meat", "steak", "fish", "cheese", "fruit", "apple", "banana",
    "mushroom", "soup", "stew", "roast", "cake", "pie", "cookie", "egg",
    "sausage", "chop", "ribs", "clam", "lobster", "chowder",
  }) then return 1 end
  return nil
end

function MSB:IsMaterialItem(item)
  if not item then return nil end
  local itemType = item.itemTypeLower or ""
  local text = self:GetItemSearchText(item)
  if Contains(itemType, "trade") or Contains(itemType, "reagent") then return 1 end
  -- Do not let an equipment subclass such as Cloth or Leather turn armor into
  -- a material. Heuristic texture/name matching is used only for unclassified
  -- or miscellaneous custom items.
  if ContainsAny(itemType, {
    "armor", "weapon", "consumable", "recipe", "container", "projectile",
    "quiver", "quest", "key",
  }) then return nil end
  if itemType ~= "" and not Contains(itemType, "misc") then return nil end
  if ContainsAny(text, {
    "herb", "cloth", "fabric", "leather", "hide", "pelt", " ore", "ingot",
    "gem", "jewel", "enchant", "elemental", "engineering", "metal & stone",
  }) then return 1 end
  return nil
end

function MSB:GetCategoryRank(item)
  if not item then return 999 end
  if self.db.junkLast == 1 and item.quality == 0 then return 900 end
  local itemType = item.itemTypeLower or ""
  local subType = item.subTypeLower or ""
  local text = self:GetItemSearchText(item)

  if Contains(itemType, "quest") or Contains(subType, "quest") then return 10 end
  if Contains(itemType, "consumable") then return 20 end
  -- An explicit Trade Goods/Reagent classification outranks every name,
  -- subtype, and icon heuristic. Some materials reuse potion/food metadata
  -- (for example elemental waters and cooking ingredients) but must remain in
  -- the continuous Materials section.
  if self:IsMaterialItem(item) then return 30 end
  if itemType == "" or Contains(itemType, "misc") then
    if ContainsAny(subType, {
      "food", "drink", "bandage", "potion", "elixir", "flask", "scroll",
    }) or ContainsAny(text, {
      "inv_potion", "inv_drink", "inv_misc_food", "inv_misc_bandage",
    }) then return 20 end
  end
  if Contains(itemType, "recipe") then return 40 end
  -- All usable gear occupies one continuous Equipment section. The subgroup
  -- function below then divides it into weapons, armor, jewelry, off-hands,
  -- and ammunition without allowing unrelated categories between them.
  if Contains(itemType, "armor") or Contains(itemType, "weapon") or
     Contains(itemType, "projectile") or Contains(itemType, "quiver") or
     ((item.equipLoc or "") ~= "" and (item.equipLoc or "") ~= "INVTYPE_BAG") then
    return 50
  end
  if Contains(itemType, "container") then return 60 end
  if Contains(itemType, "key") then return 70 end
  if Contains(itemType, "misc") then return 100 end
  return 200
end

function MSB:GetConsumableSubgroup(item)
  local subType = item.subTypeLower or ""
  local text = self:GetItemSearchText(item)

  -- User-facing order: food, drinks, bandages, potions, then longer-duration
  -- and utility consumables. Food/drink checks intentionally run before the
  -- generic potion-texture fallback because many old-client items reuse bottle
  -- artwork even when their actual subclass is Food & Drink or Elixir.
  if ContainsAny(subType, { "food", "drink" }) or self:IsDrinkItem(item) or self:IsFoodItem(item) then
    if self:IsDrinkItem(item) then return 20, "drinks" end
    return 10, "food"
  end
  if Contains(subType, "bandage") or Contains(text, "bandage") then return 30, "bandages" end
  if Contains(subType, "potion") or Contains(item.nameLower or "", "potion") then return 40, "potions" end
  if Contains(subType, "elixir") or Contains(item.nameLower or "", "elixir") then return 50, "elixirs" end
  if Contains(subType, "flask") or Contains(item.nameLower or "", "flask") then return 60, "flasks" end
  if Contains(text, "inv_potion") then return 40, "potions" end
  if Contains(subType, "scroll") or Contains(text, "scroll") then return 70, "scrolls" end
  if Contains(subType, "enhance") or ContainsAny(text, { "sharpening", "weightstone", "wizard oil", "mana oil" }) then
    return 80, "item enhancements"
  end
  if ContainsAny(text, { "bomb", "grenade", "dynamite", "explosive" }) then return 90, "combat utility" end
  return 500, subType ~= "" and subType or "other consumables"
end

function MSB:GetWeaponSubgroupRank(subType)
  subType = Lower(subType or "")
  if Contains(subType, "dagger") then return 10, "daggers" end
  if Contains(subType, "fist") then return 20, "fist weapons" end
  if Contains(subType, "one-handed axe") then return 30, "one-handed axes" end
  if Contains(subType, "two-handed axe") then return 40, "two-handed axes" end
  if Contains(subType, "axe") then return 45, subType end
  if Contains(subType, "one-handed mace") then return 50, "one-handed maces" end
  if Contains(subType, "two-handed mace") then return 60, "two-handed maces" end
  if Contains(subType, "mace") then return 65, subType end
  if Contains(subType, "one-handed sword") then return 70, "one-handed swords" end
  if Contains(subType, "two-handed sword") then return 80, "two-handed swords" end
  if Contains(subType, "sword") then return 85, subType end
  if Contains(subType, "polearm") then return 90, "polearms" end
  if Contains(subType, "staff") then return 100, "staves" end
  if Contains(subType, "bow") then return 110, "bows" end
  if Contains(subType, "crossbow") then return 120, "crossbows" end
  if Contains(subType, "gun") then return 130, "guns" end
  if Contains(subType, "thrown") then return 140, "thrown weapons" end
  if Contains(subType, "wand") then return 150, "wands" end
  if Contains(subType, "fishing") then return 160, "fishing poles" end
  return 500, subType ~= "" and subType or "other weapons"
end

function MSB:GetEquipmentSubgroup(item)
  local itemType = item.itemTypeLower or ""
  local subType = item.subTypeLower or ""
  local equipLoc = item.equipLoc or ""

  -- 1xxx: weapons, ordered by practical weapon family.
  if Contains(itemType, "weapon") then
    local rank, key = self:GetWeaponSubgroupRank(subType)
    return 1000 + rank, "weapons | " .. key
  end

  -- 2xxx: wearable armor, primarily ordered by equipment slot. Material type
  -- is retained as the tie-break key so cloth, leather, mail, and plate remain
  -- together inside the same slot group.
  if Contains(itemType, "armor") then
    if equipLoc == "INVTYPE_NECK" then return 3000, "jewelry | neck" end
    if equipLoc == "INVTYPE_FINGER" then return 3010, "jewelry | rings" end
    if equipLoc == "INVTYPE_TRINKET" then return 3020, "jewelry | trinkets" end
    if equipLoc == "INVTYPE_SHIELD" then return 4000, "off-hands | shields" end
    if equipLoc == "INVTYPE_HOLDABLE" then return 4010, "off-hands | held in off-hand" end
    if equipLoc == "INVTYPE_BODY" then return 5000, "cosmetic | shirts" end
    if equipLoc == "INVTYPE_TABARD" then return 5010, "cosmetic | tabards" end

    local slotRank = self.equipLocationRanks[equipLoc] or 500
    local slotName = Lower(equipLoc)
    if slotName == "" then slotName = "other armor" end
    local material = subType ~= "" and subType or "armor"
    return 2000 + slotRank, "armor | " .. slotName .. " | " .. material
  end

  -- 6xxx: ammunition and its storage equipment.
  if Contains(itemType, "projectile") or Contains(itemType, "quiver") then
    if Contains(subType, "arrow") then return 6000, "ammunition | arrows" end
    if Contains(subType, "bullet") then return 6010, "ammunition | bullets" end
    if Contains(subType, "quiver") then return 6020, "ammunition | quivers" end
    if Contains(subType, "ammo") then return 6030, "ammunition | pouches" end
    return 6500, "ammunition | " .. (subType ~= "" and subType or "other")
  end

  return 9000, subType ~= "" and subType or "other equipment"
end

function MSB:GetMaterialSubgroup(item)
  local itemType = item.itemTypeLower or ""
  local subType = item.subTypeLower or ""
  local name = item.nameLower or ""
  local texture = Lower(item.texture or "")
  local text = self:GetItemSearchText(item)

  if Contains(subType, "herb") or Contains(texture, "herb") then return 10, "herbs" end
  if Contains(subType, "cloth") or Contains(texture, "fabric") or ContainsAny(name, {
    "linen cloth", "wool cloth", "silk cloth", "mageweave", "runecloth", "mooncloth", "felcloth",
  }) then return 20, "cloth" end
  if ContainsAny(subType, { "leather", "hide" }) or ContainsAny(texture, { "leather", "pelt" }) or
     ContainsAny(name, { "leather", " hide", "pelt", "dragonscale", "scorpid scale" }) then
    return 30, "leather, hides, and scales"
  end
  if Contains(name, " ore") or Contains(texture, "ore_") or Contains(texture, "inv_ore") then return 40, "ore" end
  if Contains(name, " bar") or Contains(name, "ingot") or Contains(texture, "ingot") then return 50, "metal bars" end
  if Contains(subType, "stone") or Contains(name, " stone") or Contains(texture, "stone_") then return 60, "stone" end
  if Contains(subType, "gem") or Contains(subType, "jewel") or Contains(texture, "gem") or ContainsAny(name, {
    "pearl", "agate", "citrine", "jade", "ruby", "sapphire", "diamond", "emerald", "opal",
  }) then return 70, "gems" end
  if Contains(subType, "element") or ContainsAny(name, {
    "elemental ", "essence of ", "heart of ", "core of ", "globe of ", "breath of ",
  }) then return 80, "elemental materials" end
  if Contains(subType, "enchant") or Contains(texture, "enchant") or ContainsAny(name, {
    "dust", "shard", "nexus crystal", "strange dust", "illusion dust", "dream dust",
    "greater eternal essence", "lesser eternal essence", "greater nether essence", "lesser nether essence",
  }) then return 90, "enchanting materials" end
  if ContainsAny(subType, { "part", "device", "explosive", "engineer" }) or ContainsAny(text, {
    "engineering", "gyro", "blasting powder", "fuse", "casing", "widget", "gear", "scope",
  }) then return 100, "engineering materials" end
  if ContainsAny(subType, { "meat", "fish", "cook" }) or ContainsAny(name, {
    "raw ", "meat", "fish", "egg", "clam", "spice", "flour",
  }) then return 110, "cooking ingredients" end
  if ContainsAny(name, { "vial", "alchemist", "phial" }) then return 120, "alchemy supplies" end
  if Contains(itemType, "reagent") then return 130, "spell and class reagents" end
  return 500, subType ~= "" and subType or "other materials"
end

function MSB:GetCategorySubgroup(item)
  if not item then return 999, "" end
  local category = self:GetCategoryRank(item)
  local itemType = item.itemTypeLower or ""
  local subType = item.subTypeLower or ""

  if category == 20 then return self:GetConsumableSubgroup(item) end
  if category == 30 then return self:GetMaterialSubgroup(item) end
  if category == 50 then return self:GetEquipmentSubgroup(item) end

  if Contains(itemType, "recipe") then
    if Contains(subType, "alchemy") then return 10, "alchemy" end
    if Contains(subType, "blacksmith") then return 20, "blacksmithing" end
    if Contains(subType, "cook") then return 30, "cooking" end
    if Contains(subType, "enchant") then return 40, "enchanting" end
    if Contains(subType, "engineer") then return 50, "engineering" end
    if Contains(subType, "first aid") then return 60, "first aid" end
    if Contains(subType, "leather") then return 70, "leatherworking" end
    if Contains(subType, "tailor") then return 80, "tailoring" end
    return 500, subType ~= "" and subType or "recipes"
  end

  if Contains(itemType, "container") then
    if Contains(subType, "herb") then return 10, "herb bags" end
    if Contains(subType, "enchant") then return 20, "enchanting bags" end
    if Contains(subType, "engineer") then return 30, "engineering bags" end
    if Contains(subType, "soul") then return 40, "soul bags" end
    if Contains(subType, "ammo") or Contains(subType, "quiver") then return 50, "ammunition bags" end
    return 500, subType ~= "" and subType or "containers"
  end

  return 500, subType ~= "" and subType or itemType
end

function MSB:GetQualitySortValue(item)
  local quality = SafeNumber(item and item.quality, -1)
  if self.db.qualityDescending == 1 then return -quality end
  return quality
end

function MSB:IsItemBetter(a, b)
  if a and not b then return 1 end
  if not a then return nil end
  if not b then return 1 end

  local mode = self.db.sortMode or "CATEGORY"
  local aCategory = self:GetCategoryRank(a)
  local bCategory = self:GetCategoryRank(b)
  local aSubgroup, aSubgroupKey = self:GetCategorySubgroup(a)
  local bSubgroup, bSubgroupKey = self:GetCategorySubgroup(b)
  local aQuality = self:GetQualitySortValue(a)
  local bQuality = self:GetQualitySortValue(b)
  local aIdentity = Lower(a.identity or a.link or "")
  local bIdentity = Lower(b.identity or b.link or "")

  if mode == "QUALITY" then
    if aQuality ~= bQuality then return aQuality < bQuality and 1 or nil end
    if aCategory ~= bCategory then return aCategory < bCategory and 1 or nil end
    if aSubgroup ~= bSubgroup then return aSubgroup < bSubgroup and 1 or nil end
    if aSubgroupKey ~= bSubgroupKey then return aSubgroupKey < bSubgroupKey and 1 or nil end
  elseif mode == "NAME" then
    if a.nameLower ~= b.nameLower then return a.nameLower < b.nameLower and 1 or nil end
    if a.itemID ~= b.itemID then return a.itemID < b.itemID and 1 or nil end
    if a.stackKey and a.stackKey == b.stackKey then
      if a.count ~= b.count then return a.count > b.count and 1 or nil end
      return nil
    end
    if aIdentity ~= bIdentity then return aIdentity < bIdentity and 1 or nil end
    if aQuality ~= bQuality then return aQuality < bQuality and 1 or nil end
    if aCategory ~= bCategory then return aCategory < bCategory and 1 or nil end
  else
    -- Category mode: broad section -> practical subgroup -> rarity -> item.
    -- Consumables are ordered food, drinks, bandages, potions, and utility.
    -- Reagents and trade goods share one Materials section split into herbs,
    -- cloth, leather, ore, bars, stone, gems, enchanting, elemental, and more.
    -- Weapons, armor, jewelry, off-hands, and ammunition then occupy one
    -- continuous Equipment section with stable practical subgroups.
    if aCategory ~= bCategory then return aCategory < bCategory and 1 or nil end
    if aSubgroup ~= bSubgroup then return aSubgroup < bSubgroup and 1 or nil end
    if aSubgroupKey ~= bSubgroupKey then return aSubgroupKey < bSubgroupKey and 1 or nil end
    if aQuality ~= bQuality then return aQuality < bQuality and 1 or nil end
  end

  if a.nameLower ~= b.nameLower then return a.nameLower < b.nameLower and 1 or nil end
  if a.itemID ~= b.itemID then return a.itemID < b.itemID and 1 or nil end
  -- Matching stacks are adjacent and the fullest stack is always first. Do
  -- this before comparing the unique hyperlink payload, because two stacks of
  -- one item can have different instance fields on community-maintained 1.12.1 clients.
  if a.stackKey and a.stackKey == b.stackKey then
    if a.count ~= b.count then return a.count > b.count and 1 or nil end
    return nil
  end
  if a.itemTypeLower ~= b.itemTypeLower then return a.itemTypeLower < b.itemTypeLower and 1 or nil end
  if a.subTypeLower ~= b.subTypeLower then return a.subTypeLower < b.subTypeLower and 1 or nil end
  if aIdentity ~= bIdentity then return aIdentity < bIdentity and 1 or nil end
  return nil
end

function MSB:FindMergeMove(group)
  if not group or type(group.slots) ~= "table" then return nil end
  local buckets = {}
  local bucketOrder = {}
  local records = {}

  -- First read the entire stream. This lets fallback stack-limit inference see
  -- the largest observed stack before any individual record is classified.
  for index = 1, table.getn(group.slots) do
    local position = group.slots[index]
    local item = self:ReadItem(position)
    if item and not item.apiLocked and item.stackKey and item.count > 0 then
      table.insert(records, item)
    end
  end

  for index = 1, table.getn(records) do
    local item = records[index]
    item.maxStack = self:ResolveStackLimit(
      item.itemID, item.maxStackInferred and nil or item.maxStack,
      item.count, item.name, item.texture)
    if item.maxStack > 1 then
      local bucket = buckets[item.stackKey]
      if not bucket then
        bucket = {}
        buckets[item.stackKey] = bucket
        table.insert(bucketOrder, bucket)
      end
      table.insert(bucket, item)
    end
  end

  -- Fill the earliest stack from the latest matching stack. Full later stacks
  -- are valid donors: splitting from them moves the single partial stack to the
  -- end of the item's run without creating an extra partial stack.
  for bucketIndex = 1, table.getn(bucketOrder) do
    local bucket = bucketOrder[bucketIndex]
    local bucketCount = table.getn(bucket)
    if bucketCount > 1 then
      for destinationIndex = 1, bucketCount - 1 do
        local destination = bucket[destinationIndex]
        local space = destination.maxStack - destination.count
        if space > 0 then
          for sourceIndex = bucketCount, destinationIndex + 1, -1 do
            local source = bucket[sourceIndex]
            if source.count > 0 then
              local transfer = math.min(space, source.count)
              if transfer > 0 then
                return source.position, destination.position, transfer
              end
            end
          end
        end
      end
    end
  end
  return nil
end

function MSB:GetGroupAPILocks(group)
  local count = 0
  local positions = {}
  if not group or type(group.slots) ~= "table" then return count, positions end
  for index = 1, table.getn(group.slots) do
    local position = group.slots[index]
    local item = self:ReadItem(position)
    if item and item.apiLocked then
      count = count + 1
      table.insert(positions, position)
    end
  end
  return count, positions
end

function MSB:GroupHasAPILock(group)
  local count = self:GetGroupAPILocks(group)
  return count > 0 and 1 or nil
end

-- A genuinely locked item should not prevent every other bag square from
-- being sorted. After a bounded wait, preserve those squares in place and
-- rebuild the destination stream around them. A later manual sort can include
-- them once the server releases the lock.
function MSB:SkipGroupAPILocks(job, group)
  if not job then return 0 end
  local count, positions = self:GetGroupAPILocks(group)
  if count <= 0 then return 0 end
  job.serverBlocked = job.serverBlocked or {}
  local added = 0
  for index = 1, table.getn(positions) do
    local position = positions[index]
    local key = self:SlotKey(position.bag, position.slot)
    if not job.serverBlocked[key] then
      job.serverBlocked[key] = 1
      added = added + 1
    end
  end
  job.skippedServerLocked = SafeNumber(job.skippedServerLocked, 0) + added
  return added
end

function MSB:RestartSortPhaseAroundLocks(job, now)
  local phase = job.phase
  job.groups = self:BuildSortGroups(job.serverBlocked, job.scope)
  job.mergeGroup = self:BuildMergeGroup(job.serverBlocked, job.scope)
  job.groupIndex = 1
  job.positionIndex = 1
  job.waitStarted = nil
  job.waitLockedCount = nil
  job.nextAt = now + self.serverLockRetry
  job.phase = phase
end

function MSB:FindSortMove(job, group)
  local count = table.getn(group.slots)
  while job.positionIndex <= count do
    local destination = group.slots[job.positionIndex]
    local bestPosition = destination
    local bestItem = self:ReadItem(destination)
    for index = job.positionIndex + 1, count do
      local candidatePosition = group.slots[index]
      local candidateItem = self:ReadItem(candidatePosition)
      if self:IsItemBetter(candidateItem, bestItem) then
        bestItem = candidateItem
        bestPosition = candidatePosition
      end
    end
    if bestPosition.bag == destination.bag and bestPosition.slot == destination.slot then
      job.positionIndex = job.positionIndex + 1
    else
      return bestPosition, destination
    end
  end
  return nil
end

function MSB:PositionSignature(position)
  local item = self:ReadItem(position)
  if not item then return "EMPTY" end
  return tostring(item.identity) .. "#" .. tostring(item.count)
end

function MSB:BeginMove(source, destination, transferCount)
  if not source or not destination then return nil end
  if self:IsUserLocked(source.bag, source.slot) or self:IsUserLocked(destination.bag, destination.slot) then
    return nil
  end
  local sourceItem = self:ReadItem(source)
  local destinationItem = self:ReadItem(destination)
  if not sourceItem or sourceItem.apiLocked or (destinationItem and destinationItem.apiLocked) then return nil end
  if self:HasCursorItem() then
    self:AbortSort("An item is already on the cursor.")
    return nil
  end

  local phase = self.sortJob and self.sortJob.phase or "SORT"
  local kind = (phase == "MERGE" or phase == "FINAL_MERGE") and "MERGE" or "SORT"
  transferCount = math.floor(SafeNumber(transferCount, sourceItem.count))
  if transferCount < 1 then return nil end
  if transferCount > sourceItem.count then transferCount = sourceItem.count end

  if kind == "MERGE" then
    if not destinationItem or sourceItem.stackKey ~= destinationItem.stackKey then return nil end
    local space = destinationItem.maxStack - destinationItem.count
    if space < 1 then return nil end
    if transferCount > space then transferCount = space end
  end

  local transaction = {
    source = source,
    destination = destination,
    stage = 1,
    nextAt = Now() + self.db.moveDelay,
    retries = 0,
    kind = kind,
    phase = phase,
    transferCount = transferCount,
    beforeSourceCount = sourceItem.count,
    beforeDestinationCount = destinationItem and destinationItem.count or 0,
    beforeSource = self:PositionSignature(source),
    beforeDestination = self:PositionSignature(destination),
  }

  local ok
  -- Split exactly the amount needed to fill the leading stack. For a 17-stack
  -- plus a 5-stack with a 20 limit, this lifts three, producing 20 and 2 with
  -- no ambiguous remainder exchange. Full-source moves retain the pickup path.
  if kind == "MERGE" and transferCount < sourceItem.count and SplitContainerItem then
    ok = pcall(SplitContainerItem, source.bag, source.slot, transferCount)
    transaction.usedSplit = 1
  else
    ok = pcall(PickupContainerItem, source.bag, source.slot)
  end
  if not ok then return nil end
  self.sortTransaction = transaction
  return 1
end

function MSB:CompleteTransaction(transaction)
  self.sortTransaction = nil
  local afterSource = self:PositionSignature(transaction.source)
  local afterDestination = self:PositionSignature(transaction.destination)
  if afterSource == transaction.beforeSource and afterDestination == transaction.beforeDestination then
    local key = self:SlotKey(transaction.source.bag, transaction.source.slot) .. ">" .. self:SlotKey(transaction.destination.bag, transaction.destination.slot)
    self.sortJob.failedMoves[key] = SafeNumber(self.sortJob.failedMoves[key], 0) + 1
    if self.sortJob.failedMoves[key] >= 3 then
      self:AbortSort("A bag move was rejected three times. Specialized bag restrictions may be involved.")
      return
    end
  else
    self.sortJob.moves = self.sortJob.moves + 1
    if transaction.kind == "MERGE" then
      self.sortJob.mergeMoves = SafeNumber(self.sortJob.mergeMoves, 0) + 1
      if transaction.phase == "FINAL_MERGE" then
        self.sortJob.finalMergeMoves = SafeNumber(self.sortJob.finalMergeMoves, 0) + 1
      end
      local destinationItem = self:ReadItem(transaction.destination)
      local moved = destinationItem and (destinationItem.count - SafeNumber(transaction.beforeDestinationCount, 0)) or 0
      if moved > 0 then
        self.sortJob.mergeItems = SafeNumber(self.sortJob.mergeItems, 0) + moved
      end
      if afterSource == "EMPTY" and transaction.beforeSource ~= "EMPTY" then
        self.sortJob.stacksFreed = SafeNumber(self.sortJob.stacksFreed, 0) + 1
      end
    end
  end
  self.sortJob.nextAt = Now() + self.db.moveDelay
  self.visualsDirty = 1
end

function MSB:ProcessTransaction(now)
  local transaction = self.sortTransaction
  if not transaction or now < transaction.nextAt then return end
  local delay = self.db.moveDelay
  if transaction.stage == 1 then
    if not self:HasCursorItem() then
      self.sortTransaction = nil
      self.sortJob.nextAt = now + delay
      return
    end
    local ok = pcall(PickupContainerItem, transaction.destination.bag, transaction.destination.slot)
    if not ok then
      if ClearCursor then pcall(ClearCursor) end
      self:AbortSort("The destination bag square rejected the item.")
      return
    end
    transaction.stage = 2
    transaction.nextAt = now + delay
  elseif transaction.stage == 2 then
    if self:HasCursorItem() then
      pcall(PickupContainerItem, transaction.source.bag, transaction.source.slot)
      transaction.stage = 3
      transaction.nextAt = now + delay
    else
      self:CompleteTransaction(transaction)
    end
  elseif transaction.stage == 3 then
    if self:HasCursorItem() then
      transaction.retries = transaction.retries + 1
      if transaction.retries > 5 then
        if ClearCursor then pcall(ClearCursor) end
        self:AbortSort("The cursor could not return an exchanged item to its source square.")
        return
      end
      pcall(PickupContainerItem, transaction.source.bag, transaction.source.slot)
      transaction.nextAt = now + delay
    else
      self:CompleteTransaction(transaction)
    end
  end
end

function MSB:StartSort(scope)
  if not self.initialized or self.db.enabled ~= 1 then return end
  scope = self:NormalizeSortScope(scope)
  if self.sortJob then
    self:Print("Sorting is already in progress.")
    return
  end
  if self.sellJob then
    self:Print("Wait for junk selling to finish.")
    return
  end
  if scope == "BANK" and not self:IsBankOpen() then
    self:Print("Open the bank before sorting bank storage.")
    return
  end
  if self.db.blockCombatSort == 1 and self:IsInCombat() then
    self:Print("Sorting is blocked during combat. This can be changed in settings.")
    return
  end
  if self:HasCursorItem() then
    self:Print("Clear the cursor before sorting.")
    return
  end

  local groups = self:BuildSortGroups(nil, scope)
  if table.getn(groups) == 0 then
    self:Print(scope == "BANK" and "No available bank squares were found." or "No available bag squares were found.")
    return
  end
  self:SetLockMode(nil)
  self.sortJob = {
    scope = scope,
    phase = self.db.mergeStacks == 1 and "MERGE" or "SORT",
    groups = groups,
    mergeGroup = self:BuildMergeGroup(nil, scope),
    groupIndex = 1,
    positionIndex = 1,
    nextAt = Now(),
    startedAt = Now(),
    moves = 0,
    moveLimit = scope == "BANK" and 1800 or 750,
    mergeMoves = 0,
    mergeItems = 0,
    finalMergeMoves = 0,
    stacksFreed = 0,
    finalMergeStarted = nil,
    waitStarted = nil,
    failedMoves = {},
    mergeBlocked = {},
    serverBlocked = {},
    skippedServerLocked = 0,
    waitLockedCount = 0,
  }
  self:UpdateToolbar()
  self:RefreshOptionsUI()
  local orderText = scope == "BANK" and self:GetBankOrderText(" > ") or self:GetBagOrderText(" > ")
  local subject = scope == "BANK" and "merged bank grid" or "merged bag grid"
  self:Print("Sorting the " .. self:GetGridColumns(scope) .. "-column " .. subject .. " in order " .. orderText .. ". Empty squares will be moved to the bottom.")
  if self.db.mergeStacks == 1 then
    self:Print("Fully consolidating matching partial stacks before final placement.")
  end
end

function MSB:FinishSort()
  local job = self.sortJob
  self.sortJob = nil
  self.sortTransaction = nil
  self.visualsDirty = 1
  self:UpdateToolbar()
  self:RefreshOptionsUI()
  if job then
    self.lastSortScope = job.scope
    self.lastSortSkippedLocks = SafeNumber(job.skippedServerLocked, 0)
    self.lastMergeMoves = SafeNumber(job.mergeMoves, 0)
    self.lastMergeItems = SafeNumber(job.mergeItems, 0)
    self.lastStacksFreed = SafeNumber(job.stacksFreed, 0)
    local label = job.scope == "BANK" and "Bank sort" or "Bag sort"
    self:Print(label .. " complete: " .. job.moves .. " move(s) in " .. string.format("%.1f", Now() - job.startedAt) .. " seconds.")
    if self.db.mergeStacks == 1 then
      self:Print("Stack consolidation: " .. tostring(self.lastMergeMoves) .. " merge(s), " .. tostring(self.lastMergeItems) .. " item(s) transferred, " .. tostring(self.lastStacksFreed) .. " storage square(s) freed.")
    end
    if self.lastSortSkippedLocks > 0 then
      self:Print(tostring(self.lastSortSkippedLocks) .. " genuinely server-locked square(s) were left untouched. Sort again after they unlock.")
    end
  end
end

function MSB:AbortSort(reason)
  self.sortJob = nil
  self.sortTransaction = nil
  if self:HasCursorItem() and ClearCursor then pcall(ClearCursor) end
  self:UpdateToolbar()
  self:RefreshOptionsUI()
  if reason then self:Print("Sort stopped: " .. reason) end
end

function MSB:ProcessSort(now)
  local job = self.sortJob
  if not job then return end
  if self.sortTransaction then
    self:ProcessTransaction(now)
    return
  end
  if now < job.nextAt then return end
  if job.scope == "BANK" and not self:IsBankOpen() then
    self:AbortSort("bank closed")
    return
  end
  if self.db.blockCombatSort == 1 and self:IsInCombat() then
    self:AbortSort("combat started")
    return
  end
  if job.moves > SafeNumber(job.moveLimit, 750) then
    self:AbortSort("safety move limit reached")
    return
  end

  local phase = job.phase
  local isMergePhase = phase == "MERGE" or phase == "FINAL_MERGE"
  local group
  if isMergePhase then
    group = job.mergeGroup
  else
    group = job.groups[job.groupIndex]
  end

  -- A normal sort pass is followed by one verification merge. If that final
  -- verification frees any squares, a compacting sort pass runs once more so
  -- the newly empty squares end up at the bottom of the configured bag stream.
  if not group then
    if phase == "SORT" and self.db.mergeStacks == 1 and not job.finalMergeStarted then
      job.finalMergeStarted = 1
      job.finalMergeMoves = 0
      job.phase = "FINAL_MERGE"
      job.mergeGroup = self:BuildMergeGroup(job.serverBlocked, job.scope)
      job.groupIndex = 1
      job.positionIndex = 1
      job.nextAt = now + self.db.moveDelay
      return
    end
    self:FinishSort()
    return
  end

  local lockedCount = self:GetGroupAPILocks(group)
  if lockedCount > 0 then
    if not job.waitStarted then
      job.waitStarted = now
      job.waitLockedCount = lockedCount
    else
      job.waitLockedCount = lockedCount
    end
    if now - job.waitStarted > self.serverLockWait then
      local skipped = self:SkipGroupAPILocks(job, group)
      if skipped > 0 then
        if not job.lockSkipNotice then
          self:Print("Continuing around item squares that are still genuinely server-locked.")
          job.lockSkipNotice = 1
        end
        self:RestartSortPhaseAroundLocks(job, now)
      else
        job.nextAt = now + self.serverLockRetry
      end
    else
      job.nextAt = now + self.serverLockRetry
    end
    return
  end
  job.waitStarted = nil
  job.waitLockedCount = 0

  if isMergePhase then
    local source, destination, transferCount = self:FindMergeMove(group)
    if source then
      if not self:BeginMove(source, destination, transferCount) then job.nextAt = now + 0.15 end
      return
    end

    if phase == "MERGE" then
      job.phase = "SORT"
      job.groupIndex = 1
      job.positionIndex = 1
      job.nextAt = now + self.db.moveDelay
    elseif SafeNumber(job.finalMergeMoves, 0) > 0 then
      job.phase = "COMPACT"
      job.groups = self:BuildSortGroups(job.serverBlocked, job.scope)
      job.groupIndex = 1
      job.positionIndex = 1
      job.nextAt = now + self.db.moveDelay
    else
      self:FinishSort()
    end
    return
  end

  local source, destination = self:FindSortMove(job, group)
  if source then
    if not self:BeginMove(source, destination) then job.nextAt = now + 0.15 end
  else
    job.groupIndex = job.groupIndex + 1
    job.positionIndex = 1
    job.nextAt = now
  end
end

function MSB:BuildJunkQueue()
  local queue = {}
  local knownValue = 0
  local unknownPrice = 0
  for bag = 0, 4 do
    local size = self:GetContainerSizeSafe(bag)
    for slot = 1, size do
      if self.db.protectLockedFromVendor ~= 1 or not self:IsUserLocked(bag, slot) then
        local item = self:ReadItem({ bag = bag, slot = slot })
        -- Quality is the authoritative junk test. A missing sell-price return
        -- must not make a grey item invisible to the queue on an old client.
        if item and item.quality == 0 and
           (not item.sellPriceKnown or item.sellPrice > 0) then
          local value = item.sellPriceKnown and (item.sellPrice * item.count) or 0
          table.insert(queue, {
            bag = bag,
            slot = slot,
            link = item.link,
            identity = item.identity,
            itemID = item.itemID,
            count = item.count,
            value = value,
            valueKnown = item.sellPriceKnown and 1 or nil,
          })
          knownValue = knownValue + value
          if not item.sellPriceKnown then unknownPrice = unknownPrice + 1 end
        end
      end
    end
  end
  return queue, knownValue, unknownPrice
end

function MSB:CountJunk()
  local queue, value, unknownPrice = self:BuildJunkQueue()
  return table.getn(queue), value, unknownPrice
end

function MSB:StartSellJunk()
  if not self.initialized or self.db.enabled ~= 1 then return end
  if self.sellJob then
    self:Print("Junk selling is already in progress.")
    return
  end
  if self.sortJob then
    self:Print("Wait for sorting to finish.")
    return
  end
  if not self:IsMerchantOpen() then
    self:Print("Open a merchant before selling junk.")
    return
  end
  if self:HasCursorItem() then
    self:Print("Clear the cursor before selling junk.")
    return
  end

  local queue, knownValue, unknownPrice = self:BuildJunkQueue()
  if table.getn(queue) == 0 then
    self:Print("No sellable grey items were found.")
    return
  end

  local moneyBefore
  if GetMoney then
    local ok, value = pcall(GetMoney)
    if ok and type(value) == "number" then moneyBefore = value end
  end

  self.sellJob = {
    queue = queue,
    index = 1,
    expectedKnownValue = knownValue,
    unknownPrice = unknownPrice,
    soldValueEstimate = 0,
    soldStacks = 0,
    skippedStacks = 0,
    failedCalls = 0,
    pending = nil,
    moneyBefore = moneyBefore,
    nextAt = Now(),
  }
  self:UpdateToolbar()
  self:RefreshOptionsUI()
  self:Print("Selling " .. table.getn(queue) .. " grey stack(s).")
end

function MSB:GetSellMoneyDelta(job)
  if not job or type(job.moneyBefore) ~= "number" or not GetMoney then return nil end
  local ok, current = pcall(GetMoney)
  if not ok or type(current) ~= "number" then return nil end
  local delta = current - job.moneyBefore
  if delta < 0 then return nil end
  return delta
end

function MSB:FinishSellJunk(cancelled)
  local job = self.sellJob
  self.sellJob = nil
  self:UpdateToolbar()
  self:RefreshOptionsUI()
  if not job then return end
  if cancelled then
    self:Print("Junk sale stopped because the merchant closed.")
    return
  end

  local exactValue = self:GetSellMoneyDelta(job)
  local value = exactValue or job.soldValueEstimate or 0
  self.lastSoldStacks = SafeNumber(job.soldStacks, 0)
  self.lastSoldValue = SafeNumber(value, 0)
  self.lastSellValueExact = exactValue ~= nil and 1 or nil
  self.lastSellSkipped = SafeNumber(job.skippedStacks, 0)
  if self.db.announceJunk == 1 then
    local valueText = exactValue and self:FormatMoney(value) or ("approximately " .. self:FormatMoney(value))
    self:Print("Sold " .. job.soldStacks .. " grey stack(s) for " .. valueText .. ".")
    if job.skippedStacks > 0 then
      self:Print(tostring(job.skippedStacks) .. " grey stack(s) were left because the merchant did not accept them or the item stayed locked.")
    end
  end
end

function MSB:IsQueuedSellItem(item, record)
  if not item or not record then return nil end
  if item.quality ~= 0 then return nil end
  if SafeNumber(record.itemID, 0) > 0 and SafeNumber(item.itemID, 0) > 0 then
    return record.itemID == item.itemID and 1 or nil
  end
  return item.identity == record.identity and 1 or nil
end

function MSB:AdvanceSellJob(job, now)
  job.pending = nil
  job.index = job.index + 1
  job.nextAt = now + self.sellStepDelay
end

function MSB:ProcessPendingSale(job, now)
  local pending = job.pending
  if not pending then return nil end
  local record = pending.record
  local current = self:ReadItem({ bag = record.bag, slot = record.slot })

  -- A successful merchant sale removes the stack from this square. The slot
  -- may also contain a different item if another addon immediately refreshed
  -- the bag, so identity or count changes are accepted as confirmation.
  local changed = not current or not self:IsQueuedSellItem(current, record) or current.count < record.count
  if changed then
    job.soldStacks = job.soldStacks + 1
    if record.valueKnown then
      job.soldValueEstimate = job.soldValueEstimate + SafeNumber(record.value, 0)
    end
    self:AdvanceSellJob(job, now)
    return 1
  end

  if now - pending.startedAt >= self.sellVerifyTimeout then
    job.skippedStacks = job.skippedStacks + 1
    self:AdvanceSellJob(job, now)
    return 1
  end

  job.nextAt = now + 0.10
  return 1
end

function MSB:ProcessSell(now)
  local job = self.sellJob
  if not job or now < job.nextAt then return end
  if not self:IsMerchantOpen() then
    self:FinishSellJunk(1)
    return
  end

  if job.pending then
    self:ProcessPendingSale(job, now)
    return
  end

  local record = job.queue[job.index]
  if not record then
    self:FinishSellJunk(nil)
    return
  end

  if self.db.protectLockedFromVendor == 1 and self:IsUserLocked(record.bag, record.slot) then
    job.skippedStacks = job.skippedStacks + 1
    self:AdvanceSellJob(job, now)
    return
  end

  local item = self:ReadItem({ bag = record.bag, slot = record.slot })
  if not self:IsQueuedSellItem(item, record) then
    -- The square changed after the queue was built. Do not sell the replacement.
    self:AdvanceSellJob(job, now)
    return
  end

  if item.apiLocked then
    record.lockStarted = record.lockStarted or now
    if now - record.lockStarted >= self.sellLockWait then
      job.skippedStacks = job.skippedStacks + 1
      self:AdvanceSellJob(job, now)
    else
      job.nextAt = now + 0.10
    end
    return
  end

  if item.sellPriceKnown and item.sellPrice <= 0 then
    job.skippedStacks = job.skippedStacks + 1
    self:AdvanceSellJob(job, now)
    return
  end

  if type(UseContainerItem) ~= "function" then
    self:Print("UseContainerItem is unavailable on this client.")
    self:FinishSellJunk(nil)
    return
  end

  local ok = pcall(UseContainerItem, record.bag, record.slot)
  if not ok then
    job.failedCalls = job.failedCalls + 1
    job.skippedStacks = job.skippedStacks + 1
    self:AdvanceSellJob(job, now)
    return
  end

  job.pending = { record = record, startedAt = now }
  job.nextAt = now + self.sellStepDelay
end

function MSB:FormatMoney(copper)
  copper = math.floor(SafeNumber(copper, 0))
  local gold = math.floor(copper / 10000)
  local silver = math.floor((copper - gold * 10000) / 100)
  local copperOnly = copper - gold * 10000 - silver * 100
  if gold > 0 then return gold .. "g " .. silver .. "s " .. copperOnly .. "c" end
  if silver > 0 then return silver .. "s " .. copperOnly .. "c" end
  return copperOnly .. "c"
end

function MSB:ResetSettings()
  local migrationMarker
  if type(MSBagToolsDB) == "table" and type(MSBagToolsDB._moobStackMigration) == "table" then
    migrationMarker = DeepCopy(MSBagToolsDB._moobStackMigration)
  end
  MSBagToolsDB = {}
  if migrationMarker then MSBagToolsDB._moobStackMigration = migrationMarker end
  self.db = ApplyDefaults(MSBagToolsDB, self.defaults)
  self.db.gridColumns = self:GetGridColumns("BAGS")
  self.db.bankGridColumns = self:GetGridColumns("BANK")
  self.db.bagOrder = self:SerializeBagOrder(self.defaultBagOrder)
  self.db.bankOrder = self:SerializeBankOrder(self.defaultBankOrder)
  self:ApplyPFUIGridColumns()
  self.visualsDirty = 1
  self:AttachToolbar()
  self:RefreshSlotVisuals()
  self:RefreshOptionsUI()
  self:Print("Settings reset. Inventory and bank square locks were preserved.")
end

function MSB:SetOption(key, value)
  if not self.db or self.defaults[key] == nil then return end
  if key == "bagOrder" then return self:SetBagOrder(value) end
  if key == "bankOrder" then return self:SetBankOrder(value) end
  self.db[key] = value
  if key == "moveDelay" then self.db.moveDelay = Clamp(value, 0.10, 0.30) end
  if key == "outlineSize" then self.db.outlineSize = Clamp(value, 1, 4) end
  if key == "gridColumns" then
    self.db.gridColumns = math.floor(Clamp(value, 4, 24))
    self:ApplyPFUIGridColumns()
  elseif key == "bankGridColumns" then
    self.db.bankGridColumns = math.floor(Clamp(value, 4, 24))
    self:ApplyPFUIGridColumns()
  end
  self.visualsDirty = 1
  self:AttachToolbar()
  self:RefreshSlotVisuals()
  self:RefreshOptionsUI()
end

function MSB:Status()
  local pfState = self.pfAttached and "connected" or "not connected"
  local bankState = self:IsBankOpen() and "open" or "closed"
  local merchant = self:IsMerchantOpen() and "open" or "closed"
  local state = self.sortJob and ("sorting " .. string.lower(self.sortJob.scope or "bags")) or (self.sellJob and "selling junk" or "idle")
  self:Print(self.displayName .. " v" .. self.version .. " by " .. self.publisher .. " | pfUI: " .. pfState .. " | bank: " .. bankState .. " | merchant: " .. merchant .. ".")
  self:Print("Saved data: " .. self:GetMigrationStatusText() .. " | account: MSBagToolsDB | character: MSBagToolsCharDB.")
  self:Print("State: " .. state .. " | inventory locks: " .. self:GetLockedCount("BAGS") .. " | bank locks: " .. self:GetLockedCount("BANK") .. " | lock mode: " .. (self.lockMode and "on" or "off") .. ".")
  self:Print("Sort: " .. (self.sortModeNames[self.db.sortMode] or self.db.sortMode) .. " | merge stacks: " .. (self.db.mergeStacks == 1 and "on" or "off") .. " | junk last: " .. (self.db.junkLast == 1 and "on" or "off") .. ".")
  self:BuildVisualSlotOrder("BAGS")
  self:Print("Bags: " .. (self.lastLayoutSource or "unknown") .. " | flow: " .. (self.lastLayoutBagOrder or "unknown") .. " | grid: " .. tostring(self.lastLayoutColumns or self:GetGridColumns("BAGS")) .. " columns x " .. tostring(self.lastLayoutRows or 0) .. " rows | slots: " .. tostring(self.lastLayoutSlots or 0) .. ".")
  if self:IsBankOpen() then self:BuildVisualSlotOrder("BANK") end
  self:Print("Bank: flow " .. self:GetBankOrderText(" > ") .. " | grid: " .. self:GetGridColumns("BANK") .. " columns | accessible slots: " .. tostring(self.lastBankLayoutSlots or 0) .. " | toolbar anchor: " .. tostring(self.bankToolbarAnchorName or "not attached") .. ".")
  self:Print("Bank metadata safety: inventory-link errors isolated: " .. tostring(self.inventoryLinkErrors or 0) .. " | container-size errors isolated: " .. tostring(self.containerSizeErrors or 0) .. ".")
  self:Print("Server-lock compatibility: numeric zero is treated as unlocked" .. (self.numericZeroLockSeen and " (observed on this client)" or "") .. " | last sort skipped: " .. tostring(self.lastSortSkippedLocks or 0) .. ".")
  if self.lastBagInventoryLookupError then
    self:Print("Last bank-bag link fallback: " .. tostring(self.lastBagInventoryLookupError) .. ".")
  end
  self:Print("Category order: Consumables | Materials | Recipes | Equipment (weapons > armor > jewelry > off-hands > ammunition) | Containers | Miscellaneous.")
  self:Print("Last consolidation: " .. tostring(self.lastMergeMoves or 0) .. " merge(s) | items transferred: " .. tostring(self.lastMergeItems or 0) .. " | squares freed: " .. tostring(self.lastStacksFreed or 0) .. " | scope: " .. string.lower(self.lastSortScope or "none") .. ".")
  self:Print("Last junk sale: " .. tostring(self.lastSoldStacks or 0) .. " stack(s) | value: " .. self:FormatMoney(self.lastSoldValue or 0) .. (self.lastSellValueExact and " exact" or " estimated") .. " | skipped: " .. tostring(self.lastSellSkipped or 0) .. ".")
end

function MSB:ShowHelp()
  self:Print("Commands (legacy aliases: /obag, /octobags, /octobagtools):")
  self:Print("/msbag - open settings")
  self:Print("/msbag sort [bags|bank] | sortbank - sort carried bags or open bank")
  self:Print("/msbag sell - sell grey items at an open merchant")
  self:Print("/msbag lockmode - toggle click-to-lock mode")
  self:Print("/msbag lock <container> <slot> | unlock <container> <slot>")
  self:Print("/msbag clearlocks [bags|bank] - remove saved square locks")
  self:Print("/msbag mode category|quality|name")
  self:Print("/msbag columns 4-24 | bankcolumns 4-24")
  self:Print("/msbag order [0 4 3 2 1] | bankorder [-1 5 6 7 8 9 10 11]")
  self:Print("/msbag movebag <0-4> left|right | movebank <-1|5-11> left|right")
  self:Print("/msbag enable|disable | buttons on|off")
  self:Print("/msbag stacks on|off | junklast on|off | quality on|off")
  self:Print("/msbag protect on|off | announce on|off | combat on|off | theme on|off")
  self:Print("/msbag outline gold|red|blue|green|white | thickness 1-4 | delay 0.10-0.30")
  self:Print("/msbag status | reset | help")
end

function MSB:ParseOnOff(value)
  value = Lower(value)
  if value == "on" or value == "1" or value == "yes" then return 1 end
  if value == "off" or value == "0" or value == "no" then return 0 end
  return nil
end

function MSB:Slash(message)
  if not self.initialized and self.TryInitialize then
    if not self:TryInitialize("slash command") then
      self:Print("Initialization is incomplete. Stage: " .. tostring(self.loadStage or "unknown") ..
        (self.initializeError and (" | Error: " .. tostring(self.initializeError)) or ""))
      return
    end
  end
  message = message or ""
  local _, _, command, remainder = string.find(message, "^%s*(%S*)%s*(.-)%s*$")
  command = Lower(command)
  remainder = remainder or ""
  if command == "" or command == "config" or command == "options" then
    self:ToggleOptions()
  elseif command == "sort" then
    local target = Lower(remainder)
    self:StartSort((target == "bank" or target == "banks") and "BANK" or "BAGS")
  elseif command == "sortbank" or command == "banksort" then
    self:StartSort("BANK")
  elseif command == "sell" or command == "junk" or command == "selljunk" then
    self:StartSellJunk()
  elseif command == "lockmode" or command == "locks" then
    self:ToggleLockMode()
  elseif command == "lock" or command == "unlock" then
    local _, _, bag, slot = string.find(remainder, "^(%-?%d+)%s+(%d+)$")
    if bag and slot then
      self:SetSlotLocked(tonumber(bag), tonumber(slot), command == "lock")
    else
      self:Print("Usage: /msbag " .. command .. " <container -1,0-11> <slot>")
    end
  elseif command == "clearlocks" then
    local target = Lower(remainder)
    if target == "bags" or target == "inventory" then self:ClearLocks(nil, "BAGS")
    elseif target == "bank" then self:ClearLocks(nil, "BANK")
    else self:ClearLocks(nil) end
  elseif command == "mode" then
    local mode = string.upper(remainder)
    if mode == "CATEGORY" or mode == "QUALITY" or mode == "NAME" then
      self:SetOption("sortMode", mode)
      self:Print("Sort mode set to " .. self.sortModeNames[mode] .. ".")
    else
      self:Print("Usage: /msbag mode category|quality|name")
    end
  elseif command == "columns" or command == "cols" or command == "rowwidth" or command == "row" then
    local value = tonumber(remainder)
    if remainder == "" then
      self:Print("Merged bag grid width: " .. self:GetGridColumns("BAGS") .. " columns.")
    elseif value and value >= 4 and value <= 24 then
      value = math.floor(value)
      self:SetOption("gridColumns", value)
      self:Print("Merged bag grid width set to " .. value .. " columns. pfUI was updated when available.")
    else
      self:Print("Usage: /msbag columns 4-24")
    end
  elseif command == "bankcolumns" or command == "bankcols" or command == "bankrow" then
    local value = tonumber(remainder)
    if remainder == "" then
      self:Print("Merged bank grid width: " .. self:GetGridColumns("BANK") .. " columns.")
    elseif value and value >= 4 and value <= 24 then
      value = math.floor(value)
      self:SetOption("bankGridColumns", value)
      self:Print("Merged bank grid width set to " .. value .. " columns. pfUI was updated when available.")
    else
      self:Print("Usage: /msbag bankcolumns 4-24")
    end
  elseif command == "order" or command == "bagorder" or command == "fillorder" then
    local lowered = Lower(remainder)
    if remainder == "" then
      self:Print("Bag fill order: " .. self:GetBagOrderText(" > ") .. ".")
    elseif lowered == "reset" or lowered == "default" then
      self:SetBagOrder(self.defaultBagOrder)
    elseif not self:SetBagOrder(remainder) then
      self:Print("Usage: /msbag order 0 4 3 2 1  (use every bag ID exactly once)")
    end
  elseif command == "bankorder" then
    local lowered = Lower(remainder)
    if remainder == "" then
      self:Print("Bank fill order: " .. self:GetBankOrderText(" > ") .. ".")
    elseif lowered == "reset" or lowered == "default" then
      self:SetBankOrder(self.defaultBankOrder)
    elseif not self:SetBankOrder(remainder) then
      self:Print("Usage: /msbag bankorder -1 5 6 7 8 9 10 11")
    end
  elseif command == "movebag" then
    local _, _, bag, direction = string.find(remainder, "^%s*([0-4])%s+(%S+)%s*$")
    direction = Lower(direction)
    local delta = direction == "left" and -1 or (direction == "right" and 1 or nil)
    if bag and delta then
      if self:MoveBagInOrder(tonumber(bag), delta) then
        self:Print("Bag fill order: " .. self:GetBagOrderText(" > ") .. ".")
      else
        self:Print("Bag " .. tostring(bag) .. " is already at that end of the fill order.")
      end
    else
      self:Print("Usage: /msbag movebag <0-4> left|right")
    end
  elseif command == "movebank" then
    local _, _, bag, direction = string.find(remainder, "^%s*(%-?%d+)%s+(%S+)%s*$")
    direction = Lower(direction)
    local delta = direction == "left" and -1 or (direction == "right" and 1 or nil)
    if bag and delta and self:MoveBankInOrder(tonumber(bag), delta) then
      self:Print("Bank fill order: " .. self:GetBankOrderText(" > ") .. ".")
    else
      self:Print("Usage: /msbag movebank <-1|5-11> left|right")
    end
  elseif command == "enable" then
    self:SetOption("enabled", 1)
  elseif command == "disable" then
    self:SetOption("enabled", 0)
    self:SetLockMode(nil)
  elseif command == "stacks" or command == "junklast" or command == "buttons" or
         command == "quality" or command == "protect" or command == "announce" or
         command == "combat" or command == "theme" then
    local value = self:ParseOnOff(remainder)
    if value == nil then
      self:Print("Usage: /msbag " .. command .. " on|off")
      return
    end
    if command == "stacks" then self:SetOption("mergeStacks", value)
    elseif command == "junklast" then self:SetOption("junkLast", value)
    elseif command == "buttons" then self:SetOption("showToolbar", value)
    elseif command == "quality" then self:SetOption("qualityDescending", value)
    elseif command == "protect" then self:SetOption("protectLockedFromVendor", value)
    elseif command == "announce" then self:SetOption("announceJunk", value)
    elseif command == "combat" then self:SetOption("blockCombatSort", value)
    elseif command == "theme" then self:SetOption("usePFUITheme", value) end
  elseif command == "outline" then
    local color = string.upper(remainder)
    if self.outlineColors[color] then
      self:SetOption("outlineColor", color)
    else
      self:Print("Usage: /msbag outline gold|red|blue|green|white")
    end
  elseif command == "thickness" then
    local value = tonumber(remainder)
    if value and value >= 1 and value <= 4 then
      self:SetOption("outlineSize", value)
    else
      self:Print("Usage: /msbag thickness 1-4")
    end
  elseif command == "delay" then
    local value = tonumber(remainder)
    if value and value >= 0.10 and value <= 0.30 then
      self:SetOption("moveDelay", value)
    else
      self:Print("Usage: /msbag delay 0.10-0.30")
    end
  elseif command == "status" then
    self:Status()
  elseif command == "reset" then
    self:ResetSettings()
  elseif command == "help" then
    self:ShowHelp()
  else
    self:ShowHelp()
  end
end

function MSB:Initialize()
  if self.initialized then return 1 end
  self.loadStage = "migrating legacy saved settings"
  self:MigrateLegacySavedVariables()
  self.loadStage = "reading saved settings"
  local existingColumns, existingBankColumns
  if type(MSBagToolsDB) ~= "table" or MSBagToolsDB.gridColumns == nil then
    existingColumns = self:GetConfiguredPFUIColumns("BAGS")
  end
  if type(MSBagToolsDB) ~= "table" or MSBagToolsDB.bankGridColumns == nil then
    existingBankColumns = self:GetConfiguredPFUIColumns("BANK")
  end
  MSBagToolsDB = ApplyDefaults(MSBagToolsDB, self.defaults)
  if existingColumns then MSBagToolsDB.gridColumns = existingColumns end
  if existingBankColumns then MSBagToolsDB.bankGridColumns = existingBankColumns end
  MSBagToolsCharDB = ApplyDefaults(MSBagToolsCharDB, self.charDefaults)
  MSBagToolsCharDB.locked = MSBagToolsCharDB.locked or {}
  self.db = MSBagToolsDB
  self.charDB = MSBagToolsCharDB
  self.db.moveDelay = Clamp(self.db.moveDelay, 0.10, 0.30)
  self.db.outlineSize = Clamp(self.db.outlineSize, 1, 4)
  self.db.gridColumns = math.floor(Clamp(self.db.gridColumns, 4, 24))
  self.db.bankGridColumns = math.floor(Clamp(self.db.bankGridColumns, 4, 24))
  self.loadStage = "normalizing inventory order"
  local normalizedBagOrder = self:NormalizeBagOrder(self.db.bagOrder)
  if not normalizedBagOrder then normalizedBagOrder = self:CopyDefaultBagOrder() end
  self.db.bagOrder = self:SerializeBagOrder(normalizedBagOrder)
  self.loadStage = "normalizing bank order"
  local normalizedBankOrder = self:NormalizeBankOrder(self.db.bankOrder)
  if not normalizedBankOrder then normalizedBankOrder = self:CopyDefaultBankOrder() end
  self.db.bankOrder = self:SerializeBankOrder(normalizedBankOrder)
  if self.db.sortMode ~= "CATEGORY" and self.db.sortMode ~= "QUALITY" and self.db.sortMode ~= "NAME" then
    self.db.sortMode = "CATEGORY"
  end
  if not self.outlineColors[self.db.outlineColor] then self.db.outlineColor = "GOLD" end
  if type(self.charDB.locked) ~= "table" then self.charDB.locked = {} end
  self.slotVisuals = {}
  self.itemInfoCache = {}
  self.stackLimitCache = {}
  self.loadStage = "applying pfUI layout"
  self.initialized = 1
  self:ApplyPFUIGridColumns()
  self.attachAt = Now() + 0.5
  self.visualsDirty = 1
  self.loadStage = "ready"
  self.initializeError = nil
  self:Print(self.displayName .. " v" .. self.version .. " loaded by " .. self.publisher .. ". Type /msbag for settings.")
  if self.legacyAccountImported or self.legacyCharacterImported then
    self:Print("Legacy OctoBagTools settings were copied into the new MoobStack saved variables.")
  end
  return 1
end

function MSB:TryInitialize(reason)
  if self.initialized then return 1 end
  self.initializeAttempts = SafeNumber(self.initializeAttempts, 0) + 1
  self.loadStage = "initializing from " .. tostring(reason or "unknown")
  local ok, result = pcall(function() return self:Initialize() end)
  if ok and self.initialized then
    self.initializeError = nil
    self.loadStage = "ready"
    return 1
  end
  if ok then
    self.initializeError = "Initialize returned without completing"
  else
    self.initializeError = tostring(result)
  end
  self.loadStage = "initialization failed"
  if self.lastPrintedInitializeError ~= self.initializeError then
    self.lastPrintedInitializeError = self.initializeError
    self:Print("Initialization failed: " .. tostring(self.initializeError))
  end
  return nil
end

function MSB:OnEvent(eventName, firstArgument)
  if eventName == "ADDON_LOADED" then
    if firstArgument == self.name then self:TryInitialize("ADDON_LOADED") end
    if self.initialized and firstArgument == "pfUI" then
      self:ApplyPFUIGridColumns()
      self.attachAt = Now() + 0.5
    end
    return
  end
  if (eventName == "PLAYER_LOGIN" or eventName == "PLAYER_ENTERING_WORLD") and not self.initialized then
    self:TryInitialize(eventName)
  end
  if not self.initialized then return end

  if eventName == "PLAYER_ENTERING_WORLD" then
    self:ApplyPFUIGridColumns()
    self.attachAt = Now() + 0.8
    self.visualsDirty = 1
  elseif eventName == "BANKFRAME_OPENED" then
    self.bankOpen = 1
    self.attachAt = Now() + 0.10
    self.visualsDirty = 1
    self:UpdateToolbar()
    self:RefreshOptionsUI()
  elseif eventName == "BANKFRAME_CLOSED" then
    self.bankOpen = nil
    if self.sortJob and self.sortJob.scope == "BANK" then self:AbortSort("bank closed") end
    self.visualsDirty = 1
    self:UpdateToolbar()
    self:RefreshOptionsUI()
  elseif eventName == "BAG_UPDATE" or eventName == "ITEM_LOCK_CHANGED" or
         eventName == "PLAYERBANKSLOTS_CHANGED" or eventName == "PLAYERBANKBAGSLOTS_CHANGED" then
    self.visualsDirty = 1
    if self.sortJob then self.sortJob.nextAt = Now() end
    if self.sellJob then self.sellJob.nextAt = Now() end
  elseif eventName == "MERCHANT_SHOW" then
    self.merchantOpen = 1
    self:UpdateToolbar()
    self:RefreshOptionsUI()
  elseif eventName == "MERCHANT_CLOSED" then
    self.merchantOpen = nil
    if self.sellJob then self:FinishSellJunk(1) end
    self:UpdateToolbar()
    self:RefreshOptionsUI()
  elseif eventName == "PLAYER_REGEN_DISABLED" then
    self.combatState = 1
  elseif eventName == "PLAYER_REGEN_ENABLED" then
    self.combatState = nil
  end
end

function MSB:OnUpdate(elapsed)
  if not self.initialized then return end
  local now = Now()
  if self.attachAt and now >= self.attachAt then
    self.attachAt = nil
    self.attachAttempts = SafeNumber(self.attachAttempts, 0) + 1
    local attached = self:AttachToolbar()
    self:RefreshSlotVisuals()
    if not attached and pfUI and not self.pfAttached and self.attachAttempts < 30 then
      self.attachAt = now + 0.50
    end
  end
  if self.visualsDirty and (not self.nextVisualRefresh or now >= self.nextVisualRefresh) then
    self.nextVisualRefresh = now + 0.10
    self:RefreshSlotVisuals()
  end
  if self.sortJob then self:ProcessSort(now) end
  if self.sellJob then self:ProcessSell(now) end
end

-- UI functions are replaced by MSBagTools_UI.lua.
function MSB:ToggleOptions()
  self:Print("The options UI did not finish loading.")
end
function MSB:RefreshOptionsUI() end

SLASH_MSBAGTOOLS1 = "/msbag"
SLASH_MSBAGTOOLS2 = "/msbags"
SLASH_MSBAGTOOLS3 = "/msbagtools"
SLASH_MSBAGTOOLS4 = "/obag"
SLASH_MSBAGTOOLS5 = "/octobags"
SLASH_MSBAGTOOLS6 = "/octobagtools"
if type(MSBagTools_CommandDispatch) ~= "function" then
  function MSBagTools_CommandDispatch(message)
    MSB:Slash(message)
  end
end
OctoBagTools_CommandDispatch = MSBagTools_CommandDispatch
SlashCmdList["MSBAGTOOLS"] = MSBagTools_CommandDispatch

MSB.coreLoaded = 1
if not MSB.initialized then MSB.loadStage = "core loaded; awaiting initialization" end
MSB.eventFrame = CreateFrame("Frame", "MSBagToolsEventFrame", UIParent)
MSB.eventFrame:RegisterEvent("ADDON_LOADED")
MSB.eventFrame:RegisterEvent("PLAYER_LOGIN")
MSB.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
MSB.eventFrame:RegisterEvent("BAG_UPDATE")
MSB.eventFrame:RegisterEvent("ITEM_LOCK_CHANGED")
MSB.eventFrame:RegisterEvent("BANKFRAME_OPENED")
MSB.eventFrame:RegisterEvent("BANKFRAME_CLOSED")
MSB.eventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
MSB.eventFrame:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
MSB.eventFrame:RegisterEvent("MERCHANT_SHOW")
MSB.eventFrame:RegisterEvent("MERCHANT_CLOSED")
MSB.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
MSB.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
MSB.eventFrame:SetScript("OnEvent", function()
  MSB:OnEvent(event, arg1)
end)
MSB.eventFrame:SetScript("OnUpdate", function()
  MSB:OnUpdate(arg1)
end)
