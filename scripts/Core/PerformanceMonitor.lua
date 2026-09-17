-- Mission dt is milliseconds, including fractional milliseconds. It is not a GPU timer.
FS25E_PerformanceMonitor = {}
local M = FS25E_PerformanceMonitor
local samples, first, last, elapsed, enabled, target = {}, 1, 0, 0, true, 1000/60
local belowMs, aboveMs, ignored, generation, cached, cacheGeneration = 0, 0, 0, 0, nil, -1
local MAX_SAMPLES, LONG_MS = 8192, 30000
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
function M.reset()
    samples, first, last, elapsed = {}, 1, 0, 0
    belowMs, aboveMs, ignored, generation, cached, cacheGeneration = 0,0,0,0,nil,-1
end
function M.init(fps) M.reset(); enabled=true; target=1000/60; M.setTargetFps(fps) end
function M.setEnabled(v) enabled=v==true end
function M.setTargetFps(fps) if finite(fps) and fps>=15 and fps<=1000 then target=1000/fps; cacheGeneration=-1 end end
function M.getTargetBudgetMs() return target end
function M.update(dt)
    if not enabled then return end
    if not finite(dt) or dt<=0 or dt>1000 then ignored=ignored+1; return end
    elapsed=elapsed+dt; last=last+1; generation=generation+1
    samples[last]={ms=dt,time=elapsed}
    if dt>target then belowMs=belowMs+dt else aboveMs=aboveMs+dt end
    while first<last and (elapsed-samples[first].time>LONG_MS or last-first+1>MAX_SAMPLES) do samples[first]=nil; first=first+1 end
    if first>MAX_SAMPLES*2 then
        local compact={}; for i=first,last do compact[#compact+1]=samples[i] end
        samples=compact; first=1; last=#compact
    end
end
local function summarize(window)
    local n,sum,sq,max,spikes,values=0,0,0,0,0,{}
    for i=last,first,-1 do
        local e=samples[i]; if elapsed-e.time>window then break end
        n=n+1; sum=sum+e.ms; sq=sq+e.ms*e.ms; max=math.max(max,e.ms); values[n]=e.ms
        if e.ms>math.max(target*1.8,33.333) then spikes=spikes+1 end
    end
    local avg=n>0 and sum/n or 0
    table.sort(values)
    local worstCount=math.max(1,math.ceil(n*.01)); local worstSum=0
    for i=math.max(1,n-worstCount+1),n do worstSum=worstSum+values[i] end
    return {samples=n,frameMsAvg=avg,fpsAvg=avg>0 and 1000/avg or nil,
        variance=n>0 and math.max(0,sq/n-avg*avg) or 0,maxMs=max,spikes=spikes,
        p99Ms=values[math.max(1,math.ceil(n*.99))],onePercentLow=worstSum>0 and 1000/(worstSum/worstCount) or nil}
end
function M.getSnapshot()
    if cached and cacheGeneration>=0 and elapsed-(cached.elapsedMs or 0)<250 then return cached end
    local short,medium,long=summarize(1000),summarize(5000),summarize(30000)
    local lastMs=samples[last] and samples[last].ms or 0
    cached={source='mission-dt-ms',status='CONFIRMED',frameMsLast=lastMs,frameMsAvg=medium.frameMsAvg,
        fpsLast=lastMs>0 and 1000/lastMs or nil,fpsAvg=medium.fpsAvg,variance=medium.variance,
        overBudget=medium.frameMsAvg>target,spike=lastMs>math.max(target*1.8,33.333),targetBudgetMs=target,
        samples=medium.samples,short=short,medium=medium,long=long,p99Ms=long.p99Ms,onePercentLow=long.onePercentLow,
        belowTargetMs=belowMs,aboveTargetMs=aboveMs,trendMs=short.frameMsAvg-long.frameMsAvg,
        elapsedMs=elapsed,ignoredSamples=ignored,ready=elapsed>=2000 and medium.samples>=30,
        cpuMs=nil,gpuMs=nil,vramBytes=nil,bottleneck='UNKNOWN'}
    cacheGeneration=generation; return cached
end
function M.getLastFrameMs() return samples[last] and samples[last].ms or 0 end
function M.getAverageMs() return M.getSnapshot().frameMsAvg end
function M.getVariance() return M.getSnapshot().variance end
function M.isSpike() return M.getSnapshot().spike end
function M.isOverBudget() return M.getAverageMs()>target end
function M.getSampleCount() return last-first+1 end
