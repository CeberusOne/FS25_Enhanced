-- Scene budgets and visual-value ordering. All millisecond defaults are estimates, not GPU measurements.
FS25E_BudgetAllocator={}
local M=FS25E_BudgetAllocator
local categories={'shadows','lighting','atmosphere','weather','water','reflections','lod','foliage','particles','materials'}
local reduction={irrelevantShadows=1,scattering=2,ies=3,particles=4,farShadows=5,foliage=6,lod=7,terrain=8,water=9,quality=10,drs=11}
local last={}
function M.allocate(performance,scene,preset)
    performance=performance or {}; scene=scene or {}
    local target=performance.targetBudgetMs or 1000/60
    local safety=target*(preset=='Quality' and .06 or preset=='Cinematic' and 0 or .1)
    local measured=performance.frameMsAvg or target
    local available=math.max(0,target-measured-safety)
    local weights={shadows=3,lighting=1,atmosphere=1,weather=.5,water=.5,reflections=1,lod=1.5,foliage=2,particles=.5,materials=1}
    if scene.isDay==false then weights.lighting=4; weights.shadows=4; weights.foliage=.5; weights.lod=.5 end
    if scene.fogActive then weights.lighting=4; weights.atmosphere=3; weights.lod=.3; weights.foliage=.4 end
    if scene.rainActive then weights.weather=3; weights.water=2; weights.reflections=2; weights.particles=1.5; weights.lod=.7 end
    if scene.indoorCab or scene.indoor then weights.materials=2; weights.lod=.4; weights.foliage=.4 end
    local total=0; for _,k in ipairs(categories) do total=total+weights[k] end
    local budgets={}; for _,k in ipairs(categories) do budgets[k]=available*weights[k]/total end
    last={availableMs=available,safetyMs=safety,targetMs=target,measuredMs=measured,weights=weights,budgets=budgets,
        pressure=target>0 and measured/target-1 or 0,source='mission-dt budget estimate',sceneKey=scene.sceneKey}
    return last
end
function M.getSnapshot() return last end
function M.visualValue(action,budget)
    local visibility=math.max(0,math.min(1,action.visibility or 1))
    local benefit=math.max(0,action.visualBenefit or 1)
    local relevance=action.sceneRelevance or ((budget.weights or {})[action.category] or 1)
    local cost=math.max(.02,action.estimatedCostMs or .5)
    return visibility*benefit*relevance/cost
end
function M.rank(actions,budget,reduce)
    local ranked={}
    for _,a in ipairs(actions or {}) do
        if not a.locked and a.available~=false and a.experimental~=true and a.status~='EXPERIMENTAL' then
            local copy={}; for k,v in pairs(a) do copy[k]=v end
            copy.score=M.visualValue(copy,budget or last); ranked[#ranked+1]=copy
        end
    end
    table.sort(ranked,function(a,b)
        if reduce then
            local ar,br=reduction[a.reductionGroup or a.category] or 10,reduction[b.reductionGroup or b.category] or 10
            if ar~=br then return ar<br end
            if a.score~=b.score then return a.score<b.score end
        elseif a.score~=b.score then return a.score>b.score end
        return tostring(a.id)<tostring(b.id)
    end)
    return ranked
end
function M.select(actions,budget,reduce,maxChanges)
    local selected,spent={},0
    for _,a in ipairs(M.rank(actions,budget,reduce)) do
        local cost=math.max(0,a.estimatedCostMs or .5)
        if reduce or spent+cost<=(budget.availableMs or 0) then selected[#selected+1]=a; spent=spent+cost end
        if #selected>=(maxChanges or 1) then break end
    end
    return selected,spent
end
function M.reset() last={} end
