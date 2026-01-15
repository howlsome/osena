local ADDON_NAME = ...
local Osena = {}
_G.Osena = Osena

-- Safe addon load helpers
local function isAddonLoaded(name)
  if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) end
  if _G.IsAddOnLoaded then return _G.IsAddOnLoaded(name) end
  return false
end
local function loadAddon(name)
  if C_AddOns and C_AddOns.LoadAddOn then return C_AddOns.LoadAddOn(name) end
  if _G.LoadAddOn then return _G.LoadAddOn(name) end
  return false
end

-- Presets (no Custom)
local PRESETS = {
  Small  = { label = "Small (18px)",  chat = 18, quest = 18, all = 18 },
  Medium = { label = "Medium (20px)", chat = 20, quest = 20, all = 20 },
  Large  = { label = "Large (24px)",  chat = 24, quest = 24, all = 24 },
  XL     = { label = "XL (28px)",     chat = 28, quest = 28, all = 28 },
  XXL    = { label = "XXL (32px)",    chat = 32, quest = 32, all = 32 },
}
local PRESET_ORDER = { "Small", "Medium", "Large", "XL", "XXL" }

OsenaDB = OsenaDB or {}
local defaults = {
  profile = {
    chatFontSize = 18,
    questFontSize = 18,
    activePreset = "Small",
    showLoginMessage = true,
    autoApplyOnLogin = true,
  },
  originalFonts = {}, -- Blizzard defaults snapshot
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
  "GameTooltipHeader", "GameTooltipText", "GameTooltipTextSmall",
}

-- Inlined discovery
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
  if not PRESETS[OsenaDB.profile.activePreset] then
    OsenaDB.profile.activePreset = "Small"
    OsenaDB.profile.chatFontSize = PRESETS.Small.chat
    OsenaDB.profile.questFontSize = PRESETS.Small.quest
  end
end

local function resetToDefaults()
  OsenaDB.profile = deepcopy(defaults.profile)
  if Osena.ApplyPresetToAll then Osena.ApplyPresetToAll(Osena:GetActivePreset(), true) end
  if Osena.RescaleUIForPreset then Osena.RescaleUIForPreset(Osena:GetActivePreset()) end
  print("|cff66ccffOsena|r: Settings reset to defaults.")
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

function Osena.RestoreBlizzardFonts()
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
  print("|cff66ccffOsena|r: Restored Blizzard font defaults.")
end

-- Apply font size to a font object
function Osena:SetFontObjectSize(fontObjName, size)
  if type(fontObjName) ~= "string" or type(size) ~= "number" then return end
  local fo = _G[fontObjName]; if not fo or not fo.GetFont then return end
  local ok, path, _, flags = pcall(fo.GetFont, fo)
  if not ok or not path then return end
  safeSetFont(fo, path, size, flags)
end

function Osena:GetPresets() return PRESETS end
function Osena:GetActivePreset()
  local p = OsenaDB.profile.activePreset
  if not p or not PRESETS[p] then return "Small" end
  return p
end
local function applyPresetToProfile(name)
  local p = PRESETS[name]; if not p then return end
  OsenaDB.profile.activePreset = name
  OsenaDB.profile.chatFontSize = p.chat
  OsenaDB.profile.questFontSize = p.quest
  if Osena.RescaleUIForPreset then Osena.RescaleUIForPreset(name) end
end

-- Apply preset to base fonts and discovered fonts
local function applyBaseFonts(preset)
  for _, fontName in ipairs(BASE_FONTS) do
    Osena:SetFontObjectSize(fontName, preset.all)
  end
  if ChatFontNormal then
    local ok, path, _, flags = pcall(ChatFontNormal.GetFont, ChatFontNormal)
    if ok and path then safeSetFont(ChatFontNormal, path, preset.chat or preset.all, flags) end
  end
end

function Osena.ApplyPresetToAll(presetName, silent)
  local preset = PRESETS[presetName]
  if not preset or not preset.all then
    if not silent then print("|cff66ccffOsena|r: Active preset is invalid.") end
    return
  end
  applyBaseFonts(preset)
  runDiscovery()
  for _, fontName in ipairs(discoveredList) do
    Osena:SetFontObjectSize(fontName, preset.all)
  end
  if not silent then
    print(string.format("|cff66ccffOsena|r: Applied '%s' (%d) to %d fonts.", preset.label or presetName, preset.all, #discoveredList))
  end
end

-- Button autoscale registry
local buttonRegistry = {}
local function RegisterButton(btn)
  if not btn then return end
  buttonRegistry[#buttonRegistry + 1] = { btn = btn, w = btn:GetWidth(), h = btn:GetHeight(), fs = btn:GetFontString() }
end
function Osena.RescaleUIForPreset(presetName)
  local preset = PRESETS[presetName]; local size = preset and preset.all or 20
  local dh = (size - 20) * 0.7; local dw = (size - 20) * 5.0
  for _, entry in ipairs(buttonRegistry) do
    local bw = math.max(120, entry.w + dw)
    local bh = math.max(22, entry.h + dh)
    entry.btn:SetSize(bw, bh)
    if entry.fs then entry.fs:SetWordWrap(false) end
  end
end

-- Forward declarations
Osena.settingsPanel, Osena.settingsCategoryID, Osena.legacyPanel = nil, nil, nil

-- Build modern Settings panel
function Osena.BuildSettingsPanel()
  if Osena.settingsPanel or not Settings then return end
  if not isAddonLoaded("Blizzard_UIDropDownMenu") then loadAddon("Blizzard_UIDropDownMenu") end

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

  addText("Osena", "GameFontNormalLarge"); y = y - 22
  addText("Choose a preset and apply it to the entire UI.", "GameFontHighlightSmall", 0.9, 0.9, 0.9); y = y - 32

  addText("Preset", "GameFontNormal", 1, 0.95, 0.75); y = y - 22
  local presetDD = CreateFrame("Frame", nil, panel, "UIDropDownMenuTemplate")
  presetDD:SetPoint("TOPLEFT", 8, y)
  local function presetInit(self, level)
    for _, name in ipairs(PRESET_ORDER) do
      local info = UIDropDownMenu_CreateInfo()
      info.text  = PRESETS[name].label or name
      info.value = name
      info.func = function(selfBtn)
        local val = selfBtn.value
        UIDropDownMenu_SetSelectedValue(presetDD, val)
        applyPresetToProfile(val)
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end
  UIDropDownMenu_SetWidth(presetDD, 200)
  UIDropDownMenu_Initialize(presetDD, presetInit)
  UIDropDownMenu_SetSelectedValue(presetDD, Osena:GetActivePreset())

  local applyPresetAllBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  applyPresetAllBtn:SetSize(120, 24)
  applyPresetAllBtn:SetPoint("LEFT", presetDD, "RIGHT", 12, 0)
  applyPresetAllBtn:SetText("Apply All")
  applyPresetAllBtn:GetFontString():SetWordWrap(false)
  applyPresetAllBtn:SetScript("OnClick", function()
    local p = Osena:GetActivePreset()
    UIDropDownMenu_SetSelectedValue(presetDD, p)
    Osena.ApplyPresetToAll(p, false)
  end)
  RegisterButton(applyPresetAllBtn)

  y = y - 52

  addText("Auto-apply on login/reload", "GameFontNormal", 1, 0.95, 0.75); y = y - 22
  local autoCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  autoCheck.text:SetText("Auto-apply preset on login/reload")
  autoCheck:SetPoint("TOPLEFT", 16, y)
  autoCheck:SetChecked(OsenaDB.profile.autoApplyOnLogin)
  autoCheck:SetScript("OnClick", function(self)
    OsenaDB.profile.autoApplyOnLogin = self:GetChecked() and true or false
  end)
  y = y - 32

  addText("Login Message", "GameFontNormal", 1, 0.95, 0.75); y = y - 22
  local loginCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  loginCheck.text:SetText("Show login message")
  loginCheck:SetPoint("TOPLEFT", 16, y)
  loginCheck:SetChecked(OsenaDB.profile.showLoginMessage)
  loginCheck:SetScript("OnClick", function(self)
    OsenaDB.profile.showLoginMessage = self:GetChecked() and true or false
  end)
  y = y - 30

  local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  resetBtn:SetSize(100, 24)
  resetBtn:SetPoint("TOPLEFT", 16, y)
  resetBtn:SetText("Reset")
  resetBtn:GetFontString():SetWordWrap(false)
  resetBtn:SetScript("OnClick", function()
    resetToDefaults()
    loginCheck:SetChecked(OsenaDB.profile.showLoginMessage)
    autoCheck:SetChecked(OsenaDB.profile.autoApplyOnLogin)
    UIDropDownMenu_SetSelectedValue(presetDD, Osena:GetActivePreset())
  end)
  RegisterButton(resetBtn)

  local blizzBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  blizzBtn:SetSize(120, 24)
  blizzBtn:SetPoint("LEFT", resetBtn, "RIGHT", 10, 0)
  blizzBtn:SetText("Default Blizz")
  blizzBtn:GetFontString():SetWordWrap(false)
  blizzBtn:SetScript("OnClick", function()
    Osena.RestoreBlizzardFonts()
    UIDropDownMenu_SetSelectedValue(presetDD, Osena:GetActivePreset())
  end)
  RegisterButton(blizzBtn)

  y = y - 32
  Osena.RescaleUIForPreset(Osena:GetActivePreset())
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
  note:SetText("Use /osena to open settings and apply presets or restore Blizzard fonts. (Legacy panel)")
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

-- Slash
SLASH_OSENA1 = "/osena"
SlashCmdList.OSENA = function(msg)
  msg = msg and msg:lower() or ""
  if msg == "scan" then
    runDiscovery()
    print(string.format("|cff66ccffOsena|r: Discovered %d font objects. Apply a preset to affect them.", #discoveredList))
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
  if OsenaDB.profile.autoApplyOnLogin then
    Osena.ApplyPresetToAll(Osena:GetActivePreset(), true)
  end
  if OsenaDB.profile.showLoginMessage then
    print("|cff66ccffOsena|r loaded. Use Esc > Options > AddOns > Osena or /osena.")
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
