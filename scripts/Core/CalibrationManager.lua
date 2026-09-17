-- Reversible one-feature experiments; samples are scene-correlated dt, not causal GPU timings.
FS25E_CalibrationManager={}
local M=FS25E_CalibrationManager
local model,trial,state,lastError,dirty={},nil,'IDLE',nil,false
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function key(feature,context) return tostring(context or 'unknown')..'|'..tostring(feature) end
local function stats(samples)
    local sum,sq=0,0; for _,v in ipairs(samples) do sum=sum+v; sq=sq+v*v end
    local n=#samples; local avg=n>0 and sum/n or 0
    return avg,n>0 and math.max(0,sq/n-avg*avg) or 0,n
end
local function context(scene)
    scene=scene or {}
    -- No guessed GPU identity: context records map, output size and measured budget.
    local budget=FS25E_PerformanceMonitor and FS25E_PerformanceMonitor.getTargetBudgetMs() or 0
    return table.concat({tostring(scene.hardwareProfile or 'hardware-unknown'),tostring(scene.graphicsProfile or 'profile-unknown'),tostring(scene.upscaler or 'upscaler-unknown'),tostring(scene.mapId or 'unknown-map'),tostring(scene.renderWidth or '?')..'x'..tostring(scene.renderHeight or '?'),string.format('%.2fms',budget)},':')
end
function M.getContext(scene) return context(scene) end
function M.observe(feature,beforeValue,afterValue,beforeMs,afterMs,sceneKey,sampleCount,contextKey,variance)
    if not finite(beforeMs) or not finite(afterMs) or not finite(beforeValue) or not finite(afterValue) or beforeValue==afterValue then return false end
    local delta=(afterMs-beforeMs)/(afterValue-beforeValue)
    local k=key(feature,contextKey); local e=model[k] or {feature=feature,context=contextKey,samples=0,observations=0,mean=0,m2=0}
    e.observations=e.observations+1; local diff=delta-e.mean; e.mean=e.mean+diff/e.observations; e.m2=e.m2+diff*(delta-e.mean)
    e.samples=e.samples+(sampleCount or 0); e.before=beforeValue; e.after=afterValue; e.deltaMs=afterMs-beforeMs; e.scene=sceneKey
    e.variance=variance or 0; e.confidence=math.min(.95,e.observations/10)*math.min(1,e.samples/600)/(1+math.sqrt(math.max(0,e.variance))/math.max(1,beforeMs))
    e.status='MEASURED_CORRELATION'; model[k]=e; dirty=true; return true
end
function M.estimate(feature,deltaValue,contextKey,fallback)
    local e=model[key(feature,contextKey)]
    if e and e.confidence>=.25 then return math.max(.02,math.abs(e.mean*deltaValue)),e.confidence,'LEARNED' end
    return fallback or .5,e and e.confidence or 0,'ESTIMATE'
end
function M.getModel() return model end
function M.getStatus() return {state=state,error=lastError,feature=trial and trial.control.id,phaseMs=trial and trial.elapsed or 0,dirty=dirty} end
function M.isRunning() return trial~=nil end
local function current(control)
    local ok,value=pcall(control.read); if ok and finite(value) then return value end
end
local function recordWrite(control,value,before)
    local api=FS25E_VisualControls
    local entry=api and api.getState and api.getState(control.id)
    if entry then
        if entry.original==nil then entry.original=before end
        entry.current=value; entry.requested=value; entry.error=nil
    end
    if FS25E_CompatibilityManager and FS25E_CompatibilityManager.noteWrite then FS25E_CompatibilityManager.noteWrite(control.id,value) end
end
local function restoreTrial()
    if not trial or not trial.applied then return true end
    local value=current(trial.control)
    -- Another writer/user owns a changed value: do not overwrite it with our baseline.
    if value==nil or math.abs(value-trial.after)>.00001 then return false,'external-change' end
    local ok,result=pcall(trial.control.write,trial.before)
    if not ok or result~=true then return false,'restore-failed' end
    value=current(trial.control)
    local restored=value~=nil and math.abs(value-trial.before)<.00001
    if restored then recordWrite(trial.control,value,trial.before) end
    return restored,'restore-readback'
end
function M.cancel(reason)
    local ok,err=restoreTrial(); trial=nil; state=ok and 'CANCELLED' or 'RESTORE_CONFLICT'; lastError=ok and reason or err
    return ok,err
end
function M.start(control,scene,options)
    options=options or {}; if trial then return false,'busy' end
    if FS25E_GraphicsGovernor and FS25E_GraphicsGovernor.getCinematicStatus and FS25E_GraphicsGovernor.getCinematicStatus().active then return false,'cinematic-active' end
    if FS25E_VisualProfiles and FS25E_VisualProfiles.isComparing and FS25E_VisualProfiles.isComparing() then return false,'comparison-active' end
    if not control or not control.id or type(control.read)~='function' or type(control.write)~='function' then return false,'invalid-control' end
    if control.experimental or control.status=='EXPERIMENTAL' or control.restartRequired then return false,'not-live-stable' end
    if FS25E_VisualControls and FS25E_VisualControls.isLocked(control.id) then return false,'locked' end
    if control.available then local ok,value=pcall(control.available); if not ok or not value then return false,'unavailable' end end
    local value=current(control); if value==nil then return false,'unreadable' end
    local step=tonumber(control.step); if not step or step<=0 then return false,'not-continuous' end
    local amount=options.delta or step
    amount=math.max(step,math.min(amount,step*5))
    amount=math.max(step,math.floor(amount/step+.5)*step)
    local target=math.min(control.max or value,value+amount)
    if target==value then target=math.max(control.min or value,value-amount) end
    if target==value then return false,'no-range' end
    trial={control=control,before=value,after=target,sceneKey=scene and scene.sceneKey,context=context(scene),elapsed=0,
        baseline={},changed={},baselineMs=options.baselineMs or 6000,settleMs=options.settleMs or 2000,measureMs=options.measureMs or 6000,applied=false}
    state='BASELINE'; lastError=nil; return true
end
function M.update(dt,scene)
    if not trial or not finite(dt) or dt<=0 then return end
    if dt>1000 then M.cancel('suspended'); return end
    if scene and trial.sceneKey~=scene.sceneKey then M.cancel('scene-changed'); return end
    if scene and ((scene.cameraSpeedMps or 0)>1 or (scene.cameraTurnRadians or 0)>.05) then M.cancel('camera-moving'); return end
    if FS25E_VisualControls and FS25E_VisualControls.isLocked(trial.control.id) then M.cancel('locked'); return end
    trial.elapsed=trial.elapsed+dt
    if state=='BASELINE' then
        trial.baseline[#trial.baseline+1]=dt
        if trial.elapsed>=trial.baselineMs then
            local avg,var,n=stats(trial.baseline)
            if n<30 or math.sqrt(var)>math.max(1,avg*.15) then M.cancel('unstable-baseline'); return end
            if current(trial.control)~=trial.before then M.cancel('external-change'); return end
            local ok,result=pcall(trial.control.write,trial.after)
            local actual=current(trial.control)
            trial.applied=actual~=nil and math.abs(actual-trial.after)<.00001
            if not ok or result~=true then M.cancel('apply-failed'); return end
            if not actual or math.abs(actual-trial.after)>.00001 then M.cancel('readback-mismatch'); return end
            recordWrite(trial.control,actual,trial.before)
            state='SETTLING'; trial.elapsed=0
        end
    elseif state=='SETTLING' then if trial.elapsed>=trial.settleMs then state='MEASURING'; trial.elapsed=0 end
    elseif state=='MEASURING' then
        trial.changed[#trial.changed+1]=dt
        if trial.elapsed>=trial.measureMs then
            local before,bvar,bn=stats(trial.baseline); local after,avar,an=stats(trial.changed)
            local finished=trial; local ok,err=restoreTrial(); trial=nil
            if not ok then state='RESTORE_CONFLICT'; lastError=err; return end
            if an<30 or math.sqrt(avar)>math.max(1,after*.15) then state='CANCELLED'; lastError='unstable-measurement'; return end
            M.observe(finished.control.id,finished.before,finished.after,before,after,finished.sceneKey,bn+an,finished.context,bvar+avar)
            state='COMPLETE'; M.save()
        end
    end
end
local function path()
    if FS25E_ModSettings and FS25E_ModSettings.getFilePath then return FS25E_ModSettings.getFilePath('learnedCosts.xml') end
end
function M.save()
    local p=path(); if not dirty or not p or not createXMLFile or not setXMLString or not saveXMLFile then return false end
    local xml; local ok,err=pcall(function()
        xml=createXMLFile('FS25E_learnedCosts',p,'costs'); if not xml or xml==0 then error('create failed') end
        local i=0
        for _,e in pairs(model) do
            local base=string.format('costs.entry(%d)',i)
            for _,field in ipairs({'feature','context','samples','observations','mean','m2','before','after','deltaMs','scene','variance','confidence'}) do
                if e[field]~=nil then setXMLString(xml,base..'#'..field,tostring(e[field])) end
            end
            i=i+1
        end
        saveXMLFile(xml)
    end)
    if xml and deleteXMLFile then pcall(deleteXMLFile,xml) end
    if ok then dirty=false else lastError='save: '..tostring(err) end
    return ok
end
function M.load()
    local p=path(); if not p or not fileExists or not fileExists(p) or not loadXMLFile or not getXMLString then return false end
    local xml; local ok=pcall(function()
        xml=loadXMLFile('FS25E_learnedCosts',p); if not xml or xml==0 then error('load failed') end
        for i=0,511 do
            local base=string.format('costs.entry(%d)',i); local feature=getXMLString(xml,base..'#feature'); if not feature then break end
            local e={feature=feature,context=getXMLString(xml,base..'#context'),scene=getXMLString(xml,base..'#scene'),status='MEASURED_CORRELATION'}
            for _,field in ipairs({'samples','observations','mean','m2','before','after','deltaMs','variance','confidence'}) do e[field]=tonumber(getXMLString(xml,base..'#'..field)) or 0 end
            if finite(e.mean) and finite(e.samples) and finite(e.observations) and e.observations>0 then model[key(feature,e.context)]=e end
        end
    end)
    if xml and deleteXMLFile then pcall(deleteXMLFile,xml) end
    return ok
end
function M.init() model={}; trial=nil; state='IDLE'; lastError=nil; dirty=false; M.load() end
function M.reset() if trial then M.cancel('mission-end') end; M.save(); model={}; trial=nil; state='IDLE' end
