-- MS Bag Tools 1.1.3 configuration UI by MoobStack

local MSB = MSBagTools
if not MSB then return end

local function CreateBackdrop(frame, alpha)
  frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = 1,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  frame:SetBackdropColor(0.035, 0.035, 0.035, alpha or 0.96)
  frame:SetBackdropBorderColor(0.24, 0.24, 0.24, 1)
end

local function MakeText(parent, name, size, text, r, g, b)
  local label = parent:CreateFontString(name, "OVERLAY")
  label:SetFont(MSB:GetFont(), size, "OUTLINE")
  label:SetText(text or "")
  label:SetTextColor(r or 0.9, g or 0.9, b or 0.9, 1)
  label:SetJustifyH("LEFT")
  return label
end

local function MakeButton(parent, name, width, height, text)
  local button = CreateFrame("Button", name, parent)
  button:SetWidth(width)
  button:SetHeight(height)
  CreateBackdrop(button, 0.94)
  button:SetFont(MSB:GetFont(), 10, "OUTLINE")
  button:SetText(text or "")
  button:SetTextColor(0.88, 0.88, 0.88, 1)
  button:SetScript("OnEnter", function()
    this:SetBackdropBorderColor(0.95, 0.76, 0.18, 1)
    this:SetTextColor(1, 1, 1, 1)
  end)
  button:SetScript("OnLeave", function()
    this:SetBackdropBorderColor(0.24, 0.24, 0.24, 1)
    this:SetTextColor(0.88, 0.88, 0.88, 1)
  end)
  return button
end

local function MakeToggle(parent, name, width, labelText, optionKey)
  local row = CreateFrame("Button", name, parent)
  row:SetWidth(width)
  row:SetHeight(22)

  row.box = CreateFrame("Frame", name .. "Box", row)
  row.box:SetWidth(16)
  row.box:SetHeight(16)
  row.box:SetPoint("LEFT", row, "LEFT", 0, 0)
  CreateBackdrop(row.box, 0.95)

  row.mark = MakeText(row.box, name .. "Mark", 12, "x", 1, 0.78, 0.18)
  row.mark:SetPoint("CENTER", row.box, "CENTER", 0, 0)

  row.label = MakeText(row, name .. "Label", 10, labelText, 0.88, 0.88, 0.88)
  row.label:SetPoint("LEFT", row.box, "RIGHT", 8, 0)
  row.label:SetPoint("RIGHT", row, "RIGHT", 0, 0)

  row.optionKey = optionKey
  row:SetScript("OnClick", function()
    local value = MSB.db[this.optionKey] == 1 and 0 or 1
    MSB:SetOption(this.optionKey, value)
  end)
  row:SetScript("OnEnter", function()
    this.label:SetTextColor(1, 1, 1, 1)
    this.box:SetBackdropBorderColor(0.95, 0.76, 0.18, 1)
  end)
  row:SetScript("OnLeave", function()
    this.label:SetTextColor(0.88, 0.88, 0.88, 1)
    this.box:SetBackdropBorderColor(0.24, 0.24, 0.24, 1)
  end)
  row.Refresh = function(self)
    if MSB.db[self.optionKey] == 1 then self.mark:Show() else self.mark:Hide() end
  end
  return row
end

local function NextValue(values, current)
  local count = table.getn(values)
  for index = 1, count do
    if values[index] == current then
      if index >= count then return values[1] end
      return values[index + 1]
    end
  end
  return values[1]
end

function MSB:CreateOptionsUI()
  if self.optionsFrame then return self.optionsFrame end

  local frame = CreateFrame("Frame", "MSBagToolsOptions", UIParent)
  frame:SetWidth(720)
  frame:SetHeight(650)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
  frame:SetFrameStrata("DIALOG")
  frame:SetMovable(1)
  frame:EnableMouse(1)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function() this:StartMoving() end)
  frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  CreateBackdrop(frame, 0.98)

  local title = MakeText(frame, "MSBagToolsOptionsTitle", 16, "MS Bag Tools", 0.25, 0.82, 1.00)
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -15)
  local version = MakeText(frame, "MSBagToolsOptionsVersion", 9, "v" .. self.version, 0.55, 0.55, 0.55)
  version:SetPoint("LEFT", title, "RIGHT", 8, -1)

  local subtitle = MakeText(frame, "MSBagToolsOptionsSubtitle", 10,
    "Organized sorting, bank storage, junk sales, stack consolidation, and persistent locked squares.",
    0.72, 0.72, 0.72)
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -7)

  local close = MakeButton(frame, "MSBagToolsOptionsClose", 24, 20, "X")
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -12)
  close:SetScript("OnClick", function() frame:Hide() end)

  local divider = frame:CreateTexture("MSBagToolsOptionsDivider", "ARTWORK")
  divider:SetTexture(1, 1, 1, 1)
  divider:SetVertexColor(0.18, 0.18, 0.18, 1)
  divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -63)
  divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -63)
  divider:SetHeight(1)

  local bagTitle = MakeText(frame, "MSBagToolsBagSortingTitle", 12, "Inventory sorting", 1, 0.78, 0.18)
  bagTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -82)
  local bankTitle = MakeText(frame, "MSBagToolsBankSortingTitle", 12, "Bank sorting", 1, 0.78, 0.18)
  bankTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 255, -82)
  local behaviorTitle = MakeText(frame, "MSBagToolsBehaviorTitle", 12, "Behavior and locks", 1, 0.78, 0.18)
  behaviorTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 486, -82)

  local modeButton = MakeButton(frame, "MSBagToolsSortMode", 210, 25, "")
  modeButton:SetPoint("TOPLEFT", bagTitle, "BOTTOMLEFT", 0, -12)
  modeButton:SetScript("OnClick", function()
    local modes = { "CATEGORY", "QUALITY", "NAME" }
    MSB:SetOption("sortMode", NextValue(modes, MSB.db.sortMode))
  end)
  frame.modeButton = modeButton

  local columnsMinus = MakeButton(frame, "MSBagToolsColumnsMinus", 34, 25, "-")
  columnsMinus:SetPoint("TOPLEFT", modeButton, "BOTTOMLEFT", 0, -7)
  columnsMinus:SetScript("OnClick", function() MSB:SetOption("gridColumns", MSB:GetGridColumns("BAGS") - 1) end)
  frame.columnsMinus = columnsMinus
  local columnsButton = MakeButton(frame, "MSBagToolsGridColumns", 134, 25, "")
  columnsButton:SetPoint("LEFT", columnsMinus, "RIGHT", 4, 0)
  columnsButton:SetScript("OnClick", function()
    local value = MSB:GetGridColumns("BAGS") + 1
    if value > 24 then value = 4 end
    MSB:SetOption("gridColumns", value)
  end)
  frame.columnsButton = columnsButton
  local columnsPlus = MakeButton(frame, "MSBagToolsColumnsPlus", 34, 25, "+")
  columnsPlus:SetPoint("LEFT", columnsButton, "RIGHT", 4, 0)
  columnsPlus:SetScript("OnClick", function() MSB:SetOption("gridColumns", MSB:GetGridColumns("BAGS") + 1) end)
  frame.columnsPlus = columnsPlus

  local orderLabel = MakeText(frame, "MSBagToolsBagOrderLabel", 9, "Inventory fill order", 0.72, 0.72, 0.72)
  orderLabel:SetPoint("TOPLEFT", columnsMinus, "BOTTOMLEFT", 0, -10)
  frame.orderLabel = orderLabel
  frame.orderButtons = {}
  for position = 1, 5 do
    local button = MakeButton(frame, "MSBagToolsOrderBag" .. position, 38, 24, "")
    if position == 1 then button:SetPoint("TOPLEFT", orderLabel, "BOTTOMLEFT", 0, -5)
    else button:SetPoint("LEFT", frame.orderButtons[position - 1], "RIGHT", 5, 0) end
    button.orderPosition = position
    button:SetScript("OnClick", function()
      local order = MSB:GetMergedBagOrder()
      MSB.selectedOrderBag = order[this.orderPosition]
      MSB:RefreshOptionsUI()
    end)
    button:SetScript("OnLeave", function() MSB:RefreshOptionsUI() end)
    frame.orderButtons[position] = button
  end
  local orderLeft = MakeButton(frame, "MSBagToolsOrderLeft", 64, 24, "< Move")
  orderLeft:SetPoint("TOPLEFT", frame.orderButtons[1], "BOTTOMLEFT", 0, -5)
  orderLeft:SetScript("OnClick", function()
    local bag = MSB.selectedOrderBag
    if bag == nil then bag = MSB:GetMergedBagOrder()[1] end
    MSB:MoveBagInOrder(bag, -1); MSB:RefreshOptionsUI()
  end)
  frame.orderLeft = orderLeft
  local orderRight = MakeButton(frame, "MSBagToolsOrderRight", 64, 24, "Move >")
  orderRight:SetPoint("LEFT", orderLeft, "RIGHT", 5, 0)
  orderRight:SetScript("OnClick", function()
    local bag = MSB.selectedOrderBag
    if bag == nil then bag = MSB:GetMergedBagOrder()[1] end
    MSB:MoveBagInOrder(bag, 1); MSB:RefreshOptionsUI()
  end)
  frame.orderRight = orderRight
  local orderReset = MakeButton(frame, "MSBagToolsOrderReset", 72, 24, "Default")
  orderReset:SetPoint("LEFT", orderRight, "RIGHT", 5, 0)
  orderReset:SetScript("OnClick", function()
    MSB:SetBagOrder(MSB.defaultBagOrder, 1); MSB.selectedOrderBag = 0; MSB:RefreshOptionsUI()
  end)
  frame.orderReset = orderReset

  local bagHelp = MakeText(frame, "MSBagToolsBagHelp", 9,
    "Backpack and equipped bags. Empty compatible squares compact toward the end of this order.",
    0.58, 0.58, 0.58)
  bagHelp:SetWidth(210); bagHelp:SetJustifyH("LEFT")
  bagHelp:SetPoint("TOPLEFT", orderLeft, "BOTTOMLEFT", 0, -12)

  local bankColumnsMinus = MakeButton(frame, "MSBagToolsBankColumnsMinus", 34, 25, "-")
  bankColumnsMinus:SetPoint("TOPLEFT", bankTitle, "BOTTOMLEFT", 0, -12)
  bankColumnsMinus:SetScript("OnClick", function() MSB:SetOption("bankGridColumns", MSB:GetGridColumns("BANK") - 1) end)
  frame.bankColumnsMinus = bankColumnsMinus
  local bankColumnsButton = MakeButton(frame, "MSBagToolsBankGridColumns", 134, 25, "")
  bankColumnsButton:SetPoint("LEFT", bankColumnsMinus, "RIGHT", 4, 0)
  bankColumnsButton:SetScript("OnClick", function()
    local value = MSB:GetGridColumns("BANK") + 1
    if value > 24 then value = 4 end
    MSB:SetOption("bankGridColumns", value)
  end)
  frame.bankColumnsButton = bankColumnsButton
  local bankColumnsPlus = MakeButton(frame, "MSBagToolsBankColumnsPlus", 34, 25, "+")
  bankColumnsPlus:SetPoint("LEFT", bankColumnsButton, "RIGHT", 4, 0)
  bankColumnsPlus:SetScript("OnClick", function() MSB:SetOption("bankGridColumns", MSB:GetGridColumns("BANK") + 1) end)
  frame.bankColumnsPlus = bankColumnsPlus

  local bankOrderLabel = MakeText(frame, "MSBagToolsBankOrderLabel", 9, "Bank fill order", 0.72, 0.72, 0.72)
  bankOrderLabel:SetPoint("TOPLEFT", bankColumnsMinus, "BOTTOMLEFT", 0, -10)
  frame.bankOrderLabel = bankOrderLabel
  frame.bankOrderButtons = {}
  for position = 1, 8 do
    local button = MakeButton(frame, "MSBagToolsOrderBank" .. position, 48, 24, "")
    local row = position <= 4 and 1 or 2
    local col = row == 1 and position or position - 4
    if col == 1 then
      if row == 1 then button:SetPoint("TOPLEFT", bankOrderLabel, "BOTTOMLEFT", 0, -5)
      else button:SetPoint("TOPLEFT", frame.bankOrderButtons[1], "BOTTOMLEFT", 0, -5) end
    else
      button:SetPoint("LEFT", frame.bankOrderButtons[position - 1], "RIGHT", 6, 0)
    end
    button.orderPosition = position
    button:SetScript("OnClick", function()
      local order = MSB:GetMergedBankOrder()
      MSB.selectedBankOrderBag = order[this.orderPosition]
      MSB:RefreshOptionsUI()
    end)
    button:SetScript("OnLeave", function() MSB:RefreshOptionsUI() end)
    frame.bankOrderButtons[position] = button
  end
  local bankOrderLeft = MakeButton(frame, "MSBagToolsBankOrderLeft", 64, 24, "< Move")
  bankOrderLeft:SetPoint("TOPLEFT", frame.bankOrderButtons[5], "BOTTOMLEFT", 0, -5)
  bankOrderLeft:SetScript("OnClick", function()
    local bag = MSB.selectedBankOrderBag
    if bag == nil then bag = MSB:GetMergedBankOrder()[1] end
    MSB:MoveBankInOrder(bag, -1); MSB:RefreshOptionsUI()
  end)
  frame.bankOrderLeft = bankOrderLeft
  local bankOrderRight = MakeButton(frame, "MSBagToolsBankOrderRight", 64, 24, "Move >")
  bankOrderRight:SetPoint("LEFT", bankOrderLeft, "RIGHT", 5, 0)
  bankOrderRight:SetScript("OnClick", function()
    local bag = MSB.selectedBankOrderBag
    if bag == nil then bag = MSB:GetMergedBankOrder()[1] end
    MSB:MoveBankInOrder(bag, 1); MSB:RefreshOptionsUI()
  end)
  frame.bankOrderRight = bankOrderRight
  local bankOrderReset = MakeButton(frame, "MSBagToolsBankOrderReset", 72, 24, "Default")
  bankOrderReset:SetPoint("LEFT", bankOrderRight, "RIGHT", 5, 0)
  bankOrderReset:SetScript("OnClick", function()
    MSB:SetBankOrder(MSB.defaultBankOrder, 1); MSB.selectedBankOrderBag = -1; MSB:RefreshOptionsUI()
  end)
  frame.bankOrderReset = bankOrderReset

  local bankHelp = MakeText(frame, "MSBagToolsBankHelp", 9,
    "Main bank (-1), then purchased bank bags 5-11. The bank must remain open for the complete operation.",
    0.58, 0.58, 0.58)
  bankHelp:SetWidth(210); bankHelp:SetJustifyH("LEFT")
  bankHelp:SetPoint("TOPLEFT", bankOrderLeft, "BOTTOMLEFT", 0, -12)

  local toggles = {
    MakeToggle(frame, "MSBagToolsEnabled", 210, "Enable MS Bag Tools", "enabled"),
    MakeToggle(frame, "MSBagToolsMergeStacks", 210, "Fully consolidate partial stacks", "mergeStacks"),
    MakeToggle(frame, "MSBagToolsJunkLast", 210, "Place poor-quality items last", "junkLast"),
    MakeToggle(frame, "MSBagToolsQualityDescending", 210, "Higher-quality items first", "qualityDescending"),
    MakeToggle(frame, "MSBagToolsBlockCombat", 210, "Block sorting during combat", "blockCombatSort"),
    MakeToggle(frame, "MSBagToolsShowToolbar", 210, "Show bag and bank header controls", "showToolbar"),
    MakeToggle(frame, "MSBagToolsProtectLocked", 210, "Protect locked junk from selling", "protectLockedFromVendor"),
    MakeToggle(frame, "MSBagToolsAnnounceJunk", 210, "Print a junk-sale summary", "announceJunk"),
    MakeToggle(frame, "MSBagToolsPFUITheme", 210, "Use the active pfUI font", "usePFUITheme"),
  }
  toggles[1]:SetPoint("TOPLEFT", behaviorTitle, "BOTTOMLEFT", 0, -12)
  for index = 2, table.getn(toggles) do toggles[index]:SetPoint("TOPLEFT", toggles[index - 1], "BOTTOMLEFT", 0, -3) end
  frame.toggles = toggles

  local colorButton = MakeButton(frame, "MSBagToolsOutlineColor", 210, 25, "")
  colorButton:SetPoint("TOPLEFT", toggles[9], "BOTTOMLEFT", 0, -9)
  colorButton:SetScript("OnClick", function()
    local colors = { "GOLD", "RED", "BLUE", "GREEN", "WHITE" }
    MSB:SetOption("outlineColor", NextValue(colors, MSB.db.outlineColor))
  end)
  frame.colorButton = colorButton
  local sizeButton = MakeButton(frame, "MSBagToolsOutlineSize", 210, 25, "")
  sizeButton:SetPoint("TOPLEFT", colorButton, "BOTTOMLEFT", 0, -7)
  sizeButton:SetScript("OnClick", function()
    local size = tonumber(MSB.db.outlineSize) or 2
    size = size + 1; if size > 4 then size = 1 end
    MSB:SetOption("outlineSize", size)
  end)
  frame.sizeButton = sizeButton
  local delayButton = MakeButton(frame, "MSBagToolsMoveDelay", 210, 25, "")
  delayButton:SetPoint("TOPLEFT", sizeButton, "BOTTOMLEFT", 0, -7)
  delayButton:SetScript("OnClick", function()
    local delays = { 0.10, 0.12, 0.15, 0.20, 0.25, 0.30 }
    MSB:SetOption("moveDelay", NextValue(delays, MSB.db.moveDelay))
  end)
  frame.delayButton = delayButton

  local lockHelp = MakeText(frame, "MSBagToolsLockHelp", 9,
    "Lock mode works in carried bags and the open bank. Outlined squares retain both their item and exact position.",
    0.58, 0.58, 0.58)
  lockHelp:SetWidth(210); lockHelp:SetJustifyH("LEFT")
  lockHelp:SetPoint("TOPLEFT", delayButton, "BOTTOMLEFT", 0, -12)

  local actionDivider = frame:CreateTexture("MSBagToolsActionDivider", "ARTWORK")
  actionDivider:SetTexture(1, 1, 1, 1)
  actionDivider:SetVertexColor(0.18, 0.18, 0.18, 1)
  actionDivider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 124)
  actionDivider:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 124)
  actionDivider:SetHeight(1)

  local sortNow = MakeButton(frame, "MSBagToolsSortNow", 104, 28, "Sort bags")
  sortNow:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 76)
  sortNow:SetScript("OnClick", function() MSB:StartSort("BAGS") end)
  frame.sortNow = sortNow
  local sortBank = MakeButton(frame, "MSBagToolsSortBankNow", 104, 28, "Sort bank")
  sortBank:SetPoint("LEFT", sortNow, "RIGHT", 8, 0)
  sortBank:SetScript("OnClick", function() MSB:StartSort("BANK") end)
  frame.sortBank = sortBank
  local sellNow = MakeButton(frame, "MSBagToolsSellNow", 104, 28, "Sell junk")
  sellNow:SetPoint("LEFT", sortBank, "RIGHT", 8, 0)
  sellNow:SetScript("OnClick", function() MSB:StartSellJunk() end)
  frame.sellNow = sellNow
  local lockMode = MakeButton(frame, "MSBagToolsLockMode", 104, 28, "Lock mode")
  lockMode:SetPoint("LEFT", sellNow, "RIGHT", 8, 0)
  lockMode:SetScript("OnClick", function() MSB:ToggleLockMode() end)
  frame.lockMode = lockMode
  local clearLocks = MakeButton(frame, "MSBagToolsClearLocks", 104, 28, "Clear locks")
  clearLocks:SetPoint("LEFT", lockMode, "RIGHT", 8, 0)
  clearLocks:SetScript("OnClick", function() MSB:ClearLocks(nil) end)
  frame.clearLocks = clearLocks
  local reset = MakeButton(frame, "MSBagToolsReset", 104, 28, "Defaults")
  reset:SetPoint("LEFT", clearLocks, "RIGHT", 8, 0)
  reset:SetScript("OnClick", function() MSB:ResetSettings() end)
  frame.reset = reset

  local status = MakeText(frame, "MSBagToolsOptionsStatus", 9, "", 0.75, 0.75, 0.75)
  status:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 42)
  status:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 42)
  status:SetJustifyH("CENTER")
  frame.status = status

  local note = MakeText(frame, "MSBagToolsOptionsNote", 9,
    "Inventory and bank sorts are independent. Bank operations require the bank to stay open; closing it stops safely. Sell Junk remains inventory-only.",
    0.52, 0.52, 0.52)
  note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 18)
  note:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 18)
  note:SetJustifyH("CENTER")

  frame:SetScript("OnShow", function() MSB:RefreshOptionsUI() end)
  frame:Hide()
  self.optionsFrame = frame
  if UISpecialFrames then table.insert(UISpecialFrames, "MSBagToolsOptions") end
  return frame
end

function MSB:RefreshOptionsUI()
  local frame = self.optionsFrame
  if not frame or not self.db then return end
  local font = self:GetFont()

  frame.modeButton:SetFont(font, 10, "OUTLINE")
  frame.modeButton:SetText("Shared sort order: " .. (self.sortModeNames[self.db.sortMode] or self.db.sortMode))
  frame.columnsMinus:SetFont(font, 12, "OUTLINE")
  frame.columnsButton:SetFont(font, 10, "OUTLINE")
  frame.columnsButton:SetText("Bag columns: " .. self:GetGridColumns("BAGS"))
  frame.columnsPlus:SetFont(font, 12, "OUTLINE")
  frame.bankColumnsMinus:SetFont(font, 12, "OUTLINE")
  frame.bankColumnsButton:SetFont(font, 10, "OUTLINE")
  frame.bankColumnsButton:SetText("Bank columns: " .. self:GetGridColumns("BANK"))
  frame.bankColumnsPlus:SetFont(font, 12, "OUTLINE")

  local order = self:GetMergedBagOrder()
  if self.selectedOrderBag == nil then self.selectedOrderBag = order[1] end
  local selectedExists
  for position = 1, 5 do
    local bag = order[position]
    local button = frame.orderButtons[position]
    button:SetFont(font, 10, "OUTLINE")
    button:SetText("Bag " .. tostring(bag))
    if bag == self.selectedOrderBag then
      selectedExists = 1
      button:SetBackdropBorderColor(0.95, 0.76, 0.18, 1)
      button:SetTextColor(1, 0.82, 0.22, 1)
    else
      button:SetBackdropBorderColor(0.24, 0.24, 0.24, 1)
      button:SetTextColor(0.88, 0.88, 0.88, 1)
    end
  end
  if not selectedExists then self.selectedOrderBag = order[1] end

  local bankOrder = self:GetMergedBankOrder()
  if self.selectedBankOrderBag == nil then self.selectedBankOrderBag = bankOrder[1] end
  local selectedBankExists
  for position = 1, table.getn(bankOrder) do
    local bag = bankOrder[position]
    local button = frame.bankOrderButtons[position]
    button:SetFont(font, 9, "OUTLINE")
    button:SetText(bag == -1 and "Main" or ("Bag " .. tostring(bag)))
    if bag == self.selectedBankOrderBag then
      selectedBankExists = 1
      button:SetBackdropBorderColor(0.95, 0.76, 0.18, 1)
      button:SetTextColor(1, 0.82, 0.22, 1)
    else
      button:SetBackdropBorderColor(0.24, 0.24, 0.24, 1)
      button:SetTextColor(0.88, 0.88, 0.88, 1)
    end
  end
  if not selectedBankExists then self.selectedBankOrderBag = bankOrder[1] end

  local allOrderButtons = { frame.orderLeft, frame.orderRight, frame.orderReset,
    frame.bankOrderLeft, frame.bankOrderRight, frame.bankOrderReset }
  for _, button in pairs(allOrderButtons) do button:SetFont(font, 10, "OUTLINE") end

  frame.colorButton:SetFont(font, 10, "OUTLINE")
  frame.colorButton:SetText("Locked outline: " .. string.lower(self.db.outlineColor or "GOLD"))
  frame.sizeButton:SetFont(font, 10, "OUTLINE")
  frame.sizeButton:SetText("Outline thickness: " .. tostring(self.db.outlineSize or 2) .. " px")
  frame.delayButton:SetFont(font, 10, "OUTLINE")
  frame.delayButton:SetText("Move delay: " .. string.format("%.2f", self.db.moveDelay or 0.12) .. " sec")

  for _, toggle in pairs(frame.toggles or {}) do
    toggle.label:SetFont(font, 10, "OUTLINE")
    toggle.mark:SetFont(font, 12, "OUTLINE")
    toggle:Refresh()
  end

  if self.lockMode then
    frame.lockMode:SetText("Lock mode: ON")
    frame.lockMode:SetTextColor(1, 0.78, 0.15, 1)
  else
    frame.lockMode:SetText("Lock mode")
    frame.lockMode:SetTextColor(0.88, 0.88, 0.88, 1)
  end

  if self:IsBankOpen() then
    frame.sortBank:SetTextColor(0.88, 0.88, 0.88, 1)
  else
    frame.sortBank:SetTextColor(0.45, 0.45, 0.45, 1)
  end

  local operation = self.sortJob and ("sorting " .. string.lower(self.sortJob.scope or "bags")) or (self.sellJob and "selling junk" or "idle")
  local pfState = self.pfAttached and "pfUI connected" or "default/fallback UI"
  local bank = self:IsBankOpen() and "bank open" or "bank closed"
  frame.status:SetText("Status: " .. operation .. "  |  " .. pfState .. "  |  " .. bank ..
    "  |  bag " .. self:GetBagOrderText(">") .. " / " .. self:GetGridColumns("BAGS") .. " cols" ..
    "  |  bank " .. self:GetBankOrderText(">") .. " / " .. self:GetGridColumns("BANK") .. " cols" ..
    "  |  locks " .. self:GetLockedCount("BAGS") .. "+" .. self:GetLockedCount("BANK"))
end

function MSB:ToggleOptions()
  if not self.initialized and self.TryInitialize then self:TryInitialize("options window") end
  if not self.initialized then
    self:Print("The options window cannot open because initialization did not complete. Stage: " ..
      tostring(self.loadStage or "unknown") ..
      (self.initializeError and (" | Error: " .. tostring(self.initializeError)) or ""))
    return
  end
  local frame = self:CreateOptionsUI()
  if frame:IsShown() then
    frame:Hide()
  else
    frame:Show()
    self:RefreshOptionsUI()
  end
end
