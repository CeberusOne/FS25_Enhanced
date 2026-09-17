-- Current FS25 language -> English master. Never display GIANTS missing-key text.
FS25E_Localization={master={},localTexts={},language='en',missing={}}
local L=FS25E_Localization
local function readFile(path)
    local out={}
    if not loadXMLFile or not getXMLString then return out end
    if fileExists and not fileExists(path) then return out end
    local ok,xml=pcall(loadXMLFile,'FS25E_locale',path)
    if not ok or xml==nil or xml==0 then return out end
    local i=0
    while true do
        local key='l10n.texts.text('..i..')'
        local name=getXMLString(xml,key..'#name')
        if not name then break end
        local value=getXMLString(xml,key..'#text')
        if type(value)=='string' and value~='' then out[name]=value end
        i=i+1
    end
    if deleteXMLFile then deleteXMLFile(xml) elseif delete then delete(xml) end
    return out
end
--- The game language, unless the mod setting pins German or English.
function L.resolveLanguage()
    local pinned=FS25E_ModSettings and FS25E_ModSettings.get and FS25E_ModSettings.get('uiLanguage')
    if pinned=='de' or pinned=='en' then return pinned end
    return tostring(g_languageShort or (g_i18n and g_i18n.currentLanguageShort) or 'en'):lower()
end
function L.init(directory)
    L.directory=directory
    L.language=L.resolveLanguage()
    L.master=readFile(directory..'l10n/l10n_en.xml')
    L.localTexts=readFile(directory..'l10n/l10n_'..L.language..'.xml')
    -- The engine's language table, when exposed, is the authoritative inventory.
    L.availableLanguages=g_availableLanguagesTable or {}
    L.availableLanguageNames=g_availableLanguageNamesTable or {}
end
--- Switch every mod text at runtime. 'auto' follows the game language.
function L.setLanguage(code)
    code=tostring(code or 'auto'):lower()
    if code~='de' and code~='en' then code='auto' end
    if FS25E_ModSettings and FS25E_ModSettings.set then
        FS25E_ModSettings.set('uiLanguage',code)
        if FS25E_ModSettings.save then pcall(FS25E_ModSettings.save) end
    end
    if not L.directory then return false end
    L.language=L.resolveLanguage()
    L.localTexts=readFile(L.directory..'l10n/l10n_'..L.language..'.xml')
    L.missing={}
    return true
end
function L.getLanguageSetting()
    local pinned=FS25E_ModSettings and FS25E_ModSettings.get and FS25E_ModSettings.get('uiLanguage')
    if pinned=='de' or pinned=='en' then return pinned end
    return 'auto'
end
local function usable(v,key)
    return type(v)=='string' and v~='' and v~=key and not v:match('^Missing')
end
function L.t(key,fallback)
    if not key then return fallback or '' end
    if L.localTexts[key] then return L.localTexts[key] end
    if L.getLanguageSetting()=='auto' and g_i18n and g_i18n.getText and g_i18n.hasText and g_i18n:hasText(key) then
        local ok,v=pcall(g_i18n.getText,g_i18n,key)
        if ok and usable(v,key) then return v end
    end
    if L.master[key] then return L.master[key] end
    if fallback and usable(fallback,key) then return fallback end
    L.missing[key]=true
    return L.localTexts.FS25E_status_information_unavailable or L.master.FS25E_status_information_unavailable or '—'
end
