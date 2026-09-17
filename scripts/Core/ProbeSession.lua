-- Explicit, bounded read-only recording. No automatic startup or render writes.
FS25E_ProbeSession={}
local M=FS25E_ProbeSession
local run,sequence=nil,0
local categories={all=true,environment=true,lighting=true,weather=true,materials=true,render=true}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function logger() return Logging and type(Logging.info)=='function' end
local function clean(v) return tostring(v):gsub('[%c]',' '):sub(1,320) end
local function log(line)
 if not logger() then return false end
 return pcall(Logging.info,'%s','[FS25E_PROBE] '..line)
end
local function collect(category)
 local p=FS25E_RuntimeProbe
 if not p or type(p.collect)~='function' then return nil end
 local ok,map,summary=pcall(p.collect,category)
 if not ok or type(map)~='table' then return nil end
 return map,summary or {}
end
local function keys(map)
 local out={}
 for k in pairs(map) do if type(k)=='string' and k:sub(1,5)~='meta.' then out[#out+1]=k end end
 table.sort(out);return out
end
function M.snapshot(category)
 category=category or 'all'
 if not categories[category] or not logger() or not g_currentMission or g_dedicatedServer~=nil then return false,'FS25E_status_probe_unavailable' end
 if not FS25E_RuntimeProbe or not FS25E_RuntimeProbe.emitSnapshot then return false,'FS25E_status_probe_unavailable' end
 local ok,result=pcall(FS25E_RuntimeProbe.emitSnapshot,category)
 ok=ok and type(result)=='table' and result.ok==true
 return ok,ok and 'FS25E_status_probe_written' or 'FS25E_status_probe_unavailable'
end
function M.isRunning() return run~=nil end
function M.stop(reason)
 local r=run;run=nil
 if r then log('WATCH_END run='..r.id..' category='..r.category..' reason='..clean(reason or 'user')..' samples='..r.samples..' lines='..r.lines..' elapsedMs='..math.floor(r.elapsed)) end
 return true,'FS25E_status_probe_stopped'
end
function M.start(seconds,category)
 category=category or 'all';seconds=seconds==nil and 60 or tonumber(seconds)
 if not finite(seconds) or seconds<2 or seconds>300 or not categories[category] or not logger() or g_dedicatedServer~=nil or not g_currentMission then
  return false,'FS25E_status_probe_unavailable'
 end
 local map,summary=collect(category);if not map then return false,'FS25E_status_probe_unavailable' end
 M.stop('replaced');sequence=sequence+1
 local r={id=sequence,category=category,mission=g_currentMission,limit=seconds*1000,elapsed=0,since=0,samples=1,lines=0,previous=map}
 run=r
 if not log('WATCH_BEGIN schema=1 run='..r.id..' version='..clean(FS25_Enhanced and FS25_Enhanced.VERSION or '?')..' origin='..clean(summary.nativeEnvironment or 'unknown')..' category='..category..' seconds='..seconds..' intervalMs=2000 maxLines=2000 readOnly=true truncated='..clean(summary.truncated)) then run=nil;return false,'FS25E_status_probe_unavailable' end
 for _,key in ipairs(keys(map)) do
  if r.lines>=700 then log('WATCH_TRUNCATED run='..r.id..' phase=baseline');break end
  if not log('BASE run='..r.id..' path='..clean(key)..' value='..clean(map[key])) then M.stop('logger_error');return false,'FS25E_status_probe_unavailable' end
  r.lines=r.lines+1
 end
 return true,'FS25E_status_probe_started'
end
function M.update(dt)
 local r=run;if not r then return end
 if r.mission~=g_currentMission then M.stop('mission_changed');return end
 if not finite(dt) or dt<0 then return end
 r.elapsed=r.elapsed+dt;r.since=r.since+dt
 if r.since<2000 and r.elapsed<r.limit then return end
 r.since=0 -- Never catch up in a burst after a long frame/pause.
 local map,summary=collect(r.category)
 if not map then M.stop('capture_error');return end
 r.samples=r.samples+1
 local union={};for _,key in ipairs(keys(r.previous)) do union[key]=true end;for _,key in ipairs(keys(map)) do union[key]=true end
 local changed=0
 for _,key in ipairs(keys(union)) do
  if r.previous[key]~=map[key] then
   changed=changed+1
   if changed>120 or r.lines>=2000 then
    log('WATCH_TRUNCATED run='..r.id..' phase=changes sample='..r.samples)
    M.stop('log_budget');return
   end
   if not log('CHANGE run='..r.id..' sample='..r.samples..' elapsedMs='..math.floor(r.elapsed)..' path='..clean(key)..' old='..clean(r.previous[key] or '<absent>')..' new='..clean(map[key] or '<absent>')) then M.stop('logger_error');return end
   r.lines=r.lines+1
  end
 end
 if summary.truncated then log('WATCH_NOTE run='..r.id..' sample='..r.samples..' captureTruncated=true') end
 r.previous=map
 if r.elapsed>=r.limit then M.stop('duration') end
end
function M.reset() return M.stop('mission_end') end
function M.getControls()
 local out={}
 for _,item in ipairs({{'debugSnapshot',function()return M.snapshot('all')end},{'debugWatch',function()if M.isRunning() then return M.stop('user') end;return M.start(60,'all')end}}) do
  local d=item
  out[#out+1]={id=d[1],category='performance',kind='action',cost='low',runtimeControl=true,noGlobalRestore=true,noCinematic=true,
   labelKey='FS25E_setting_'..d[1],tooltipKey='FS25E_tooltip_'..d[1],run=d[2],
   available=function()return logger() and g_currentMission~=nil and g_dedicatedServer==nil,'FS25E_status_probe_unavailable'end}
 end
 return out
end
