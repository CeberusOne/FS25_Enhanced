-- Repeatable session benchmark: render visuals and CPU/GPU attribution require external evidence.
FS25E_BenchmarkManager={}
local M=FS25E_BenchmarkManager
local run,reports=nil,{}
function M.start(label,durationMs)
    if run then return false,'busy' end
    local duration=tonumber(durationMs) or 60000
    if duration<5000 or duration>600000 then return false,'duration-range' end
    run={label=tostring(label or 'Enhanced'),durationMs=duration,elapsedMs=0,frames={},sum=0,sumSq=0,spikes=0,scenes={},
        targetMs=FS25E_PerformanceMonitor and FS25E_PerformanceMonitor.getTargetBudgetMs() or 1000/60}
    return true
end
function M.isRunning() return run~=nil end
function M.finish()
    if not run then return nil end
    local r=run; run=nil; local frames=r.frames; r.frames=nil; local n=#frames
    table.sort(frames); local avg=n>0 and r.sum/n or 0; local worstN=math.max(1,math.ceil(n*.01)); local worst=0
    for i=math.max(1,n-worstN+1),n do worst=worst+frames[i] end
    r.sampleCount=n; r.averageFps=avg>0 and 1000/avg or nil; r.averageFrameMs=avg
    r.onePercentLow=worst>0 and 1000/(worst/worstN) or nil; r.p99Ms=frames[math.max(1,math.ceil(n*.99))]
    r.frameVariance=n>0 and math.max(0,r.sumSq/n-avg*avg) or 0
    r.source='mission-dt-ms'; r.vramBytes=nil; r.bottleneck='UNKNOWN'; r.visualResult='NOT_TESTED'; r.status=n>0 and 'MEASURED' or 'EMPTY'
    reports[#reports+1]=r; if #reports>20 then table.remove(reports,1) end
    return r
end
function M.update(dt,scene)
    if not run or type(dt)~='number' or dt~=dt or dt<=0 or dt>1000 then return end
    local r=run; r.elapsedMs=r.elapsedMs+dt; r.sum=r.sum+dt; r.sumSq=r.sumSq+dt*dt
    r.frames[#r.frames+1]=dt
    if dt>math.max(33.333,r.targetMs*1.8) then r.spikes=r.spikes+1 end
    local key=scene and scene.sceneKey or 'unknown'; r.scenes[key]=(r.scenes[key] or 0)+dt
    if r.elapsedMs>=r.durationMs or #r.frames>=120000 then M.finish() end
end
function M.getReport(index) return reports[index or #reports] end
function M.getReports() return reports end
function M.getStatus() return {running=run~=nil,label=run and run.label,elapsedMs=run and run.elapsedMs,durationMs=run and run.durationMs,reports=#reports} end
function M.compare(a,b)
    if type(a)=='number' then a=reports[a] end; if type(b)=='number' then b=reports[b] end
    if not a or not b or not a.averageFps or not b.averageFps then return nil,'missing-report' end
    return {baseline=a.label,enhanced=b.label,fpsDelta=b.averageFps-a.averageFps,
        frameMsDelta=b.averageFrameMs-a.averageFrameMs,onePercentLowDelta=b.onePercentLow-a.onePercentLow,
        comparableSceneSet=(function() for k in pairs(a.scenes) do if not b.scenes[k] then return false end end; for k in pairs(b.scenes) do if not a.scenes[k] then return false end end; return true end)(),
        visualResult='NOT_TESTED',note='Repeat the same camera path, weather and duration; scene tags alone do not prove equivalence.'}
end
function M.reset() run=nil; reports={} end
