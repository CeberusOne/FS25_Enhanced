-- Keeps the game's own graphics settings strictly separate from this mod.
--
-- The engine has one state. The vanilla settings page reads it when it opens
-- (SettingsModel:refresh), writes it when the player applies, and persists it
-- through saveHardwareScalability() / GameSettings:save(). Without a guard the
-- page would show and save whatever this mod had pushed into the engine.
--
-- The guard wraps exactly those moments: every mod value is restored before
-- the page reads or the game saves, and applied again right after. The page
-- therefore only ever sees, edits and stores the player's own settings, while
-- the live window keeps full range over the engine in between.
FS25E_VanillaGuard={depth=0,installed=false}
local M=FS25E_VanillaGuard
local unpackValues=table.unpack or unpack
local function nativeEnvironment()
 local owner=I3DManager or g_i3DManager
 local source=owner and owner.loadI3DFile
 if type(source)=='function' and type(getfenv)=='function' then
  local ok,env=pcall(getfenv,source)
  if ok and type(env)=='table' then return env end
 end
 return _G
end
--- Enter the vanilla state (nested calls are counted, not repeated).
function M.enter(reason)
 M.depth=M.depth+1
 if M.depth>1 then return end
 local profiles=FS25E_VisualProfiles
 if not profiles or not profiles.isComparing or profiles.isComparing() then M.owned=false; return end
 M.owned=true
 local ok,status=profiles.toggleCompare()
 if FS25E_Debug then FS25E_Debug.debug('VanillaGuard','enter '..tostring(reason)..' ok='..tostring(ok)..' '..tostring(status)) end
end
--- Leave the vanilla state; the mod's values are applied again on top of
--- whatever the player just changed, which becomes the new baseline.
function M.leave(reason)
 M.depth=math.max(0,M.depth-1)
 if M.depth>0 then return end
 if not M.owned then return end
 M.owned=false
 local profiles=FS25E_VisualProfiles
 if profiles and profiles.isComparing and profiles.isComparing() then
  local ok,status=profiles.toggleCompare()
  if FS25E_Debug then FS25E_Debug.debug('VanillaGuard','leave '..tostring(reason)..' ok='..tostring(ok)..' '..tostring(status)) end
 end
end
local function guarded(reason,fn)
 return function(...)
  M.enter(reason)
  local results={pcall(fn,...)}
  M.leave(reason)
  if not results[1] then error(results[2],0) end
  return unpackValues(results,2)
 end
end
local function wrapMethod(class,name,reason)
 if type(class)~='table' or type(class[name])~='function' then return false end
 if M.originals[class] and M.originals[class][name] then return true end
 M.originals[class]=M.originals[class] or {}
 M.originals[class][name]=class[name]
 class[name]=guarded(reason,M.originals[class][name])
 return true
end
function M.install()
 if M.installed or g_dedicatedServer~=nil then return true end
 M.originals={}
 local n=0
 -- The vanilla page reading the engine, applying edits and resetting them.
 for _,name in ipairs({'refresh','refreshChangedValue','applyChanges','applyCustomSettings','reset'}) do
  if wrapMethod(SettingsModel,name,'SettingsModel.'..name) then n=n+1 end
 end
 -- Persisting: engine quality settings (game.xml) and gameplay settings.
 local env=nativeEnvironment()
 for _,e in ipairs({env,_G}) do
  if type(e.saveHardwareScalability)=='function' and not (M.originals[e] and M.originals[e].saveHardwareScalability) then
   if wrapMethod(e,'saveHardwareScalability','saveHardwareScalability') then n=n+1 end
  end
 end
 if wrapMethod(GameSettings,'save','GameSettings.save') then n=n+1 end
 if wrapMethod(GameSettings,'saveToXMLFile','GameSettings.saveToXMLFile') then n=n+1 end
 M.installed=true
 if FS25E_Debug then FS25E_Debug.info('VanillaGuard','installed '..n..' guards (vanilla page and saves never see mod values)') end
 return true
end
function M.uninstall()
 for class,names in pairs(M.originals or {}) do
  for name,original in pairs(names) do if type(class)=='table' then class[name]=original end end
 end
 M.originals={}; M.installed=false; M.depth=0; M.owned=false
end
function M.getStatus() return {installed=M.installed,depth=M.depth,active=M.owned==true} end
