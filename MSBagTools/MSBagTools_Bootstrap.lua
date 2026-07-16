-- MS Bag Tools 1.1.3 early command bootstrap
-- Loaded before the core so slash commands remain available for diagnostics.

MSBagTools = MSBagTools or {}
local MSB = MSBagTools
-- Temporary runtime compatibility alias for the former addon table.
OctoBagTools = MSBagTools
MSB.bootstrapLoaded = 1
if not MSB.loadStage then MSB.loadStage = "bootstrap loaded" end

local function BootstrapPrint(message)
  local prefix = "|cff33ccffMS Bag Tools:|r "
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. tostring(message or ""))
  end
end

function MSBagTools_CommandDispatch(message)
  local addon = MSBagTools
  if addon and not addon.initialized and type(addon.TryInitialize) == "function" then
    addon:TryInitialize("slash bootstrap")
  end
  if addon and type(addon.Slash) == "function" then
    addon:Slash(message or "")
    return
  end

  BootstrapPrint("The command bootstrap loaded, but the core did not finish loading.")
  BootstrapPrint("Stage: " .. tostring(addon and addon.loadStage or "core file unavailable"))
  if addon and addon.initializeError then
    BootstrapPrint("Error: " .. tostring(addon.initializeError))
  else
    BootstrapPrint("Enable script errors with /console scriptErrors 1, then /reload.")
  end
end

SLASH_MSBAGTOOLS1 = "/msbag"
SLASH_MSBAGTOOLS2 = "/msbags"
SLASH_MSBAGTOOLS3 = "/msbagtools"
SLASH_MSBAGTOOLS4 = "/obag"
SLASH_MSBAGTOOLS5 = "/octobags"
SLASH_MSBAGTOOLS6 = "/octobagtools"
OctoBagTools_CommandDispatch = MSBagTools_CommandDispatch
SlashCmdList["MSBAGTOOLS"] = MSBagTools_CommandDispatch
