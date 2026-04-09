local ADDON_NAME = ...
local Osena = {}
_G.Osena = Osena

local FONT_SIZE = 18


OsenaDB = OsenaDB or {}
local defaults = {
  profile = {
    applied = true,
    showLoginMessage = true,
    autoApplyOnLogin = true,
  },
  originalFonts = {},
}

-- Base fonts (always apply)
local BASE_FONTS = {
  "GameFontNormal", "GameFontHighlight", "GameFontDisable",
  "GameFontNormalLarge", "GameFontNormalHuge",
  "NumberFontNormal", "NumberFontNormalLarge",
  "QuestFont", "QuestTitleFont", "QuestFont_Large", "QuestFont_Huge",
  "SystemFont_Tiny", "SystemFont_Small", "SystemFont_Shadow_Small",
  "SystemFont_Shadow_Med1", "SystemFont_Shadow_Med2",
  "SystemFont_Shadow_Med3", "SystemFont_Shadow_Large",
  "SystemFont_Shadow_Huge1", "SystemFont_Shadow_Huge2",
}

-- Font discovery
local discoveredFonts, discoveredList = {}, {}
local function addName(name)
  if name and name ~= "" and not discoveredFonts[name] then
    discoveredFonts[name] = true
    table.insert(discoveredList, name)
  end
end
local function runDiscovery()
  wipe(discoveredFonts); wipe(discoveredList)
  for k, v in pairs(_G) do
    if type(v) == "table" or type(v) == "userdata" then
      local ok, t = pcall(function() return v:GetObjectType() end)
      if ok and t == "Font" then addName(k) end
    end
  end
  local f = EnumerateFrames()
  while f do
    local isFS = false
    if f.GetObjectType then
      local ok, t = pcall(f.GetObjectType, f)
      if ok and t == "FontString" then isFS = true end
    end
    if isFS and f.GetFontObject then
      local fo = f:GetFontObject()
      if fo and fo.GetName then
        local ok, nm = pcall(fo.GetName, fo)
        if ok then addName(nm) end
      end
    end
    f = EnumerateFrames(f)
  end
  table.sort(discoveredList)
end

-- Utils
local function deepcopy(src)
  if type(src) ~= "table" then return src end
  local t = {}
  for k, v in pairs(src) do t[k] = deepcopy(v) end
  return t
end

local function ensureProfileDefaults()
  OsenaDB = OsenaDB or {}
  OsenaDB.profile = OsenaDB.profile or {}
  OsenaDB.originalFonts = OsenaDB.originalFonts or {}
  for k, v in pairs(defaults.profile) do
    if OsenaDB.profile[k] == nil then
      OsenaDB.profile[k] = deepcopy(v)
    end
  end
  -- Migration: clear out old preset fields
  OsenaDB.profile.activePreset = nil
  OsenaDB.profile.chatFontSize = nil
  OsenaDB.profile.questFontSize = nil
end

-- Safe font setter
local function safeSetFont(fontObj, path, size, flags)
  if not fontObj or not path or type(path) ~= "string" or type(size) ~= "number" then return end
  if type(flags) ~= "string" then flags = nil end
  pcall(fontObj.SetFont, fontObj, path, size, flags)
end

local function captureFont(name, store)
  local fo = _G[name]; if not fo or not fo.GetFont then return end
  local ok, path, size, flags = pcall(fo.GetFont, fo)
  if ok and path and size then
    store[name] = { path = path, size = size, flags = flags }
  end
end

local function snapshotBlizzardFonts()
  local store = OsenaDB.originalFonts
  for _, n in ipairs(BASE_FONTS) do
    if not store[n] then captureFont(n, store) end
  end
  if not store.ChatFontNormal then captureFont("ChatFontNormal", store) end
  runDiscovery()
  for _, n in ipairs(discoveredList) do
    if not store[n] then captureFont(n, store) end
  end
end

-- Apply 18px to all fonts
function Osena.ApplyFonts(silent)
  runDiscovery()
  for _, fontName in ipairs(BASE_FONTS) do
    Osena:SetFontObjectSize(fontName, FONT_SIZE)
  end
  if ChatFontNormal then
    local ok, path, _, flags = pcall(ChatFontNormal.GetFont, ChatFontNormal)
    if ok and path then safeSetFont(ChatFontNormal, path, FONT_SIZE, flags) end
  end
  for _, fontName in ipairs(discoveredList) do
    Osena:SetFontObjectSize(fontName, FONT_SIZE)
  end
  OsenaDB.profile.applied = true
  Osena:UpdateStatusText()
  if not silent then
    print(string.format("|cff66ccffOsena|r: Applied %dpx to %d fonts.", FONT_SIZE, #discoveredList))
  end
end

-- Restore Blizzard defaults
function Osena.RestoreBlizzardFonts(silent)
  local store = OsenaDB.originalFonts
  if not store or next(store) == nil then
    print("|cff66ccffOsena|r: Blizzard defaults were not captured yet.")
    return
  end
  for name, data in pairs(store) do
    local fo = _G[name]
    if fo then
      safeSetFont(fo, data.path, data.size, data.flags)
    end
  end
  OsenaDB.profile.applied = false
  Osena:UpdateStatusText()
  if not silent then
    print("|cff66ccffOsena|r: Restored Blizzard font defaults.")
  end
end

-- Set font size on a named font object
function Osena:SetFontObjectSize(fontObjName, size)
  if type(fontObjName) ~= "string" or type(size) ~= "number" then return end
  local fo = _G[fontObjName]; if not fo or not fo.GetFont then return end
  local ok, path, _, flags = pcall(fo.GetFont, fo)
  if not ok or not path then return end
  safeSetFont(fo, path, size, flags)
end

-- Status text management
local statusText = nil
function Osena:UpdateStatusText()
  if not statusText then return end
  if OsenaDB.profile.applied then
    statusText:SetText(string.format("Currently set to |cff00ff00%dpx|r for all UI text.", FONT_SIZE))
  else
    statusText:SetText("Currently |cffffcc00reset to Blizzard defaults|r.")
  end
end

-- Reset settings to defaults
local function resetToDefaults()
  OsenaDB.profile = deepcopy(defaults.profile)
  Osena.ApplyFonts(true)
  print("|cff66ccffOsena|r: Settings reset to defaults.")
end

-- Forward declarations
Osena.settingsPanel, Osena.settingsCategoryID, Osena.legacyPanel = nil, nil, nil

-- Build modern Settings panel
function Osena.BuildSettingsPanel()
  if Osena.settingsPanel or not Settings then return end

  local panel = CreateFrame("Frame", nil, UIParent)
  panel.name = "Osena"; panel:Hide()
  Osena.settingsPanel = panel

  local category = Settings.RegisterCanvasLayoutCategory(panel, "Osena")
  Osena.settingsCategoryID = category:GetID()
  Settings.RegisterAddOnCategory(category)

  local y = -20

  local function addText(text, template, r, g, b, x)
    local fs = panel:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
    fs:SetTextColor(r or 1, g or 0.82, b or 0)
    fs:SetPoint("TOPLEFT", x or 16, y)
    fs:SetText(text)
    return fs
  end

  -- Title
  addText("Osena", "GameFontNormalLarge"); y = y - 22
  addText(string.format("Sets all UI text to %dpx for improved readability.", FONT_SIZE), "GameFontHighlightSmall", 0.9, 0.9, 0.9); y = y - 32

  -- Status
  addText("Status", "GameFontNormal", 1, 0.95, 0.75); y = y - 22
  statusText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  statusText:SetPoint("TOPLEFT", 16, y)
  Osena:UpdateStatusText()
  y = y - 32

  -- Apply / Restore buttons
  local applyBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  applyBtn:SetSize(140, 26)
  applyBtn:SetPoint("TOPLEFT", 16, y)
  applyBtn:SetText(string.format("Apply %dpx", FONT_SIZE))
  applyBtn:GetFontString():SetWordWrap(false)
  applyBtn:SetScript("OnClick", function()
    Osena.ApplyFonts(false)
  end)

  local restoreBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  restoreBtn:SetSize(180, 26)
  restoreBtn:SetPoint("LEFT", applyBtn, "RIGHT", 10, 0)
  restoreBtn:SetText("Restore Blizzard Defaults")
  restoreBtn:GetFontString():SetWordWrap(false)
  restoreBtn:SetScript("OnClick", function()
    Osena.RestoreBlizzardFonts(false)
  end)

  y = y - 44

  -- Options
  addText("Options", "GameFontNormal", 1, 0.95, 0.75); y = y - 24

  local autoCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  autoCheck.text:SetText("Auto-apply on login and reload")
  autoCheck:SetPoint("TOPLEFT", 16, y)
  autoCheck:SetChecked(OsenaDB.profile.autoApplyOnLogin)
  autoCheck:SetScript("OnClick", function(self)
    OsenaDB.profile.autoApplyOnLogin = self:GetChecked() and true or false
  end)
  y = y - 28

  local loginCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  loginCheck.text:SetText("Show login message")
  loginCheck:SetPoint("TOPLEFT", 16, y)
  loginCheck:SetChecked(OsenaDB.profile.showLoginMessage)
  loginCheck:SetScript("OnClick", function(self)
    OsenaDB.profile.showLoginMessage = self:GetChecked() and true or false
  end)
  y = y - 36

  -- Reset
  local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  resetBtn:SetSize(120, 26)
  resetBtn:SetPoint("TOPLEFT", 16, y)
  resetBtn:SetText("Reset Settings")
  resetBtn:GetFontString():SetWordWrap(false)
  resetBtn:SetScript("OnClick", function()
    resetToDefaults()
    autoCheck:SetChecked(OsenaDB.profile.autoApplyOnLogin)
    loginCheck:SetChecked(OsenaDB.profile.showLoginMessage)
  end)
end

-- Legacy fallback panel
function Osena.BuildLegacyPanel()
  if Osena.legacyPanel then return end
  local panel = CreateFrame("Frame", nil, InterfaceOptionsFramePanelContainer)
  panel.name = "Osena"; panel:Hide()
  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16); title:SetText("Osena - Font Accessibility")
  local note = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  note:SetPoint("TOPLEFT", 16, -40); note:SetWidth(500); note:SetJustifyH("LEFT")
  note:SetText("Use /osena to open settings and apply fonts or restore Blizzard defaults. (Legacy panel)")
  InterfaceOptions_AddCategory(panel)
  Osena.legacyPanel = panel
end

local function EnsurePanel()
  if Settings then
    if not Osena.settingsPanel then Osena.BuildSettingsPanel() end
    return "modern"
  else
    if not Osena.legacyPanel then Osena.BuildLegacyPanel() end
    return "legacy"
  end
end

-- Slash commands
SLASH_OSENA1 = "/osena"
SlashCmdList.OSENA = function(msg)
  msg = msg and msg:lower():match("^%s*(.-)%s*$") or ""
  if msg == "apply" then
    Osena.ApplyFonts(false)
    return
  elseif msg == "reset" then
    Osena.RestoreBlizzardFonts(false)
    return
  elseif msg == "status" then
    if OsenaDB.profile.applied then
      print(string.format("|cff66ccffOsena|r: Currently set to |cff00ff00%dpx|r.", FONT_SIZE))
    else
      print("|cff66ccffOsena|r: Currently |cffffcc00reset to Blizzard defaults|r.")
    end
    return
  elseif msg == "scan" then
    runDiscovery()
    print(string.format("|cff66ccffOsena|r: Discovered %d font objects.", #discoveredList))
    return
  end
  local mode = EnsurePanel()
  if mode == "modern" and Settings and Osena.settingsCategoryID then
    Settings.OpenToCategory(Osena.settingsCategoryID)
  elseif mode == "legacy" and InterfaceOptionsFrame then
    InterfaceOptionsFrame_Show()
    InterfaceOptionsFrame_OpenToCategory(Osena.legacyPanel)
  else
    print("|cff66ccffOsena|r: Options not available.")
  end
end

-- Events
local function initAddon()
  ensureProfileDefaults()
  snapshotBlizzardFonts()
  if OsenaDB.profile.autoApplyOnLogin and OsenaDB.profile.applied then
    Osena.ApplyFonts(true)
  end
  if OsenaDB.profile.showLoginMessage then
    if OsenaDB.profile.applied then
      print(string.format("|cff66ccffOsena|r loaded — %dpx applied. Type /osena for options.", FONT_SIZE))
    else
      print("|cff66ccffOsena|r loaded — Blizzard defaults active. Type /osena for options.")
    end
  end
  EnsurePanel()
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    self:UnregisterEvent("ADDON_LOADED")
    self:RegisterEvent("PLAYER_LOGIN")
  elseif event == "PLAYER_LOGIN" then
    self:UnregisterEvent("PLAYER_LOGIN")
    initAddon()
  end
end)
