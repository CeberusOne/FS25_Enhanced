-- FS25_Enhanced / scripts/Lighting/LightDiscovery.lua
-- Central registry of RealLight nodes discovered via Lights / PlaceableLights specs.
-- NO global light registry / blind node class-id scan.
-- Soft-Apply OPTIONAL and OFF by default (autoApply stays false).

FS25E_LightDiscovery = {}

local LOG = "LightDiscovery"

--- Soft-apply of ShadowManager priority/map/soft APIs. Default OFF.
local softApplyEnabled = false

--- Entries keyed by stable handle string.
--- { handle, kind="vehicle"|"placeable", ownerId, node, profile="low"|"high"|nil,
---   groupIndex=number|nil, active=bool, softApplied=bool }
local entries = {}
local byOwner = {} -- ownerKey -> { handle, ... }
local profileSubscribed = false
local consoleRegistered = false
local typeHookRegistered = false

-- PlaceableLights entries may be transform groups. Only LIGHT_SOURCE nodes may
-- be passed to getLight*/setLight*; pcall does not suppress native type errors.
function FS25E_LightDiscovery.isLightSource(node)
    if type(node)~='number' or node==0 or type(entityExists)~='function'
        or type(getHasClassId)~='function' or not ClassIds or ClassIds.LIGHT_SOURCE==nil then return false end
    local ok,alive=pcall(entityExists,node)
    if not ok or not alive then return false end
    local checked,light=pcall(getHasClassId,node,ClassIds.LIGHT_SOURCE)
    return checked and light==true
end

local function resolveSources(entry)
    local declared=entry.realLight and entry.realLight.lightSources
    if type(declared)=='table' then return declared end
    if entry.sourceNodes then return entry.sourceNodes end
    local found,seen={},{}
    local queue={{node=entry.node,depth=0}}; local head=1
    -- Bounded walk of the specialization's own light group, never the scene root.
    while head<=#queue and head<=512 do
        local current=queue[head];head=head+1
        local node=current.node
        if type(node)=='number' and node~=0 and not seen[node] then
            seen[node]=true
            local ok,alive=pcall(entityExists,node)
            if ok and alive then
                if FS25E_LightDiscovery.isLightSource(node) then found[#found+1]=node end
                if current.depth<16 and type(getNumOfChildren)=='function' and type(getChildAt)=='function' then
                    local counted,n=pcall(getNumOfChildren,node)
                    if counted and type(n)=='number' then for index=0,math.min(n,512)-1 do
                        if #queue>=512 then break end
                        local read,child=pcall(getChildAt,node,index)
                        if read and child then queue[#queue+1]={node=child,depth=current.depth+1} end
                    end end
                end
            end
        end
    end
    entry.sourceNodes=found
    return found
end

local function sourceVisible(node,root)
    if type(getVisibility)~='function' then return false end
    local current=node
    for _=1,32 do
        local ok,visible=pcall(getVisibility,current)
        if not ok or visible~=true then return false end
        if current==root then return true end
        if type(getParent)~='function' then return true end
        local read,parent=pcall(getParent,current)
        if not read or not parent or parent==0 or parent==current then return true end
        current=parent
    end
    return false
end

local function ownerKey(kind, owner)
    if owner == nil then
        return nil
    end
    local id = owner.id or owner.rootNode or tostring(owner)
    return tostring(kind) .. ":" .. tostring(id)
end

local function makeHandle(kind, owner, node, profile)
    return string.format("%s:%s:%s:%s",
        tostring(kind),
        tostring(owner and (owner.id or owner.rootNode) or "?"),
        tostring(node),
        tostring(profile or "-"))
end

local function isHighProfilePreferred(owner)
    if owner == nil then
        return false
    end
    local ok, result = pcall(function()
        if owner.getUseHighProfile ~= nil then
            return owner:getUseHighProfile() == true
        end
        return false
    end)
    return ok and result == true
end

local function resolveLightsProfileValue()
    local ok, value = pcall(function()
        if g_gameSettings ~= nil and g_gameSettings.getValue ~= nil and GameSettings ~= nil
            and GameSettings.SETTING ~= nil and GameSettings.SETTING.LIGHTS_PROFILE ~= nil then
            return g_gameSettings:getValue(GameSettings.SETTING.LIGHTS_PROFILE)
        end
        return nil
    end)
    if ok then
        return value
    end
    return nil
end

function FS25E_LightDiscovery.init()
    entries = {}
    byOwner = {}
    softApplyEnabled = false
    FS25E_Debug.info(LOG, "init (read-only discovery; softApply=false; no global scan)")
    FS25E_LightDiscovery.subscribeProfileChanges()
    FS25E_LightDiscovery.registerConsoleCommands()
end

function FS25E_LightDiscovery.reset()
    -- Drop handles; soft-apply restore is per-owner onDelete / restoreSoftForOwner.
    entries = {}
    byOwner = {}
    FS25E_Debug.info(LOG, "reset (registry cleared)")
end

function FS25E_LightDiscovery.setSoftApplyEnabled(enabled)
    -- Legacy persisted flags must never create hidden shadow writes on load.
    -- Explicit user controls/presets use LightTuning's request mask instead.
    softApplyEnabled = false
    FS25E_Debug.info(LOG, "legacy softApply disabled; explicit controls required")
end

function FS25E_LightDiscovery.isSoftApplyEnabled()
    return softApplyEnabled
end

--- Register one discovered RealLight node. Does not apply engine setters unless softApply.
function FS25E_LightDiscovery.registerLight(info)
    if info == nil or info.node == nil then
        return nil
    end
    local kind = info.kind or "unknown"
    local profile = info.profile
    local handle = makeHandle(kind, info.owner, info.node, profile)
    if entries[handle] ~= nil then
        entries[handle].realLight = info.realLight or entries[handle].realLight
        entries[handle].sourceNodes=nil
        return handle
    end
    local high = isHighProfilePreferred(info.owner)
    local active = true
    if profile == "high" then
        active = high
    elseif profile == "low" then
        active = not high
    end

    local entry = {
        handle = handle,
        kind = kind,
        owner = info.owner,
        ownerId = info.owner and (info.owner.id or info.owner.rootNode) or nil,
        node = info.node,
        realLight = info.realLight,
        profile = profile,
        groupIndex = info.groupIndex,
        bucket = info.bucket,
        active = active,
        softApplied = false,
    }
    entries[handle] = entry

    local ok = ownerKey(kind, info.owner)
    if ok ~= nil then
        if byOwner[ok] == nil then
            byOwner[ok] = {}
        end
        byOwner[ok][#byOwner[ok] + 1] = handle
    end

    -- Feed ShadowManager stub list for later manager queries (ids only; no apply).
    if FS25E_LightDiscovery.isLightSource(info.node) and FS25E_ShadowManager ~= nil and FS25E_ShadowManager.registerLightId ~= nil then
        pcall(FS25E_ShadowManager.registerLightId, info.node)
    end

    return handle
end

--- Enumerate vehicle Lights nested realLights.low/high buckets → realLight.node
function FS25E_LightDiscovery.collectFromVehicle(vehicle)
    if vehicle == nil or vehicle.spec_lights == nil then
        return 0
    end
    local spec = vehicle.spec_lights
    local realLights = spec.realLights
    if realLights == nil then
        return 0
    end

    local count = 0
    local ok, err = pcall(function()
        for profileName, profile in pairs(realLights) do
            if type(profile) == "table" and (profileName == "low" or profileName == "high") then
                for bucketName, lights in pairs(profile) do
                    if type(lights) == "table" then
                        for _, realLight in ipairs(lights) do
                            if realLight ~= nil and realLight.node ~= nil then
                                FS25E_LightDiscovery.registerLight({
                                    kind = "vehicle",
                                    owner = vehicle,
                                    node = realLight.node,
                                    realLight = realLight,
                                    profile = profileName,
                                    bucket = bucketName,
                                })
                                count = count + 1
                            end
                        end
                    end
                end
            end
        end
    end)
    if not ok then
        FS25E_Debug.warning(LOG, "collectFromVehicle failed: " .. tostring(err))
        return 0
    end
    -- Per-object discovery runs for every spawned vehicle/placeable. Keep the
    -- per-object trail on the debug channel; totals are in every LiveApply line.
    FS25E_Debug.debug(LOG, string.format("vehicle collected=%d highProfile=%s",
        count, tostring(isHighProfilePreferred(vehicle))))
    return count
end

--- Enumerate placeable PlaceableLights flat arrays {node, groupIndex}
function FS25E_LightDiscovery.collectFromPlaceable(placeable)
    if placeable == nil or placeable.spec_lights == nil then
        return 0
    end
    local spec = placeable.spec_lights
    local realLights = spec.realLights
    if realLights == nil then
        return 0
    end

    local count = 0
    local ok, err = pcall(function()
        for _, profileName in ipairs({ "low", "high" }) do
            local arr = realLights[profileName]
            if type(arr) == "table" then
                for _, realLight in ipairs(arr) do
                    if realLight ~= nil and realLight.node ~= nil then
                        FS25E_LightDiscovery.registerLight({
                            kind = "placeable",
                            owner = placeable,
                            node = realLight.node,
                            realLight = realLight,
                            profile = profileName,
                            groupIndex = realLight.groupIndex,
                        })
                        count = count + 1
                    end
                end
            end
        end
    end)
    if not ok then
        FS25E_Debug.warning(LOG, "collectFromPlaceable failed: " .. tostring(err))
        return 0
    end
    FS25E_Debug.debug(LOG, string.format("placeable collected=%d highProfile=%s",
        count, tostring(isHighProfilePreferred(placeable))))
    return count
end

-- Old save flags and specialization load callbacks never apply rendering settings.
-- Only explicit control/preset requests may reach LightTuning's native writers.
function FS25E_LightDiscovery.trySoftApplyForOwner(kind, owner)
    return 0
end

--- Restore soft-applied caps for an owner via CapabilityApplier / ShadowManager originals.
--- Only restores per-light keys for this owner's nodes (not global restoreAll).
function FS25E_LightDiscovery.restoreSoftForOwner(kind, owner)
    local okKey = ownerKey(kind, owner)
    local handles = okKey and byOwner[okKey] or nil
    if handles == nil then
        return
    end
    local nodes = {}
    local anySoft = false
    for i = 1, #handles do
        local entry = entries[handles[i]]
        if entry ~= nil and entry.softApplied then
            anySoft = true
            entry.softApplied = false
            if entry.node ~= nil then
                nodes[entry.node] = true
            end
        end
    end
    if not anySoft then
        return
    end
    -- Vanilla restore Pflicht: restore only this owner's per-light CapabilityApplier keys.
    FS25E_Debug.pcall(LOG, "restoreSoft CapabilityApplier.restoreOne", function()
        if FS25E_CapabilityApplier == nil or FS25E_CapabilityApplier.getApplied == nil then
            return
        end
        local applied = FS25E_CapabilityApplier.getApplied()
        if applied == nil then
            return
        end
        local keys = {}
        for key, entry in pairs(applied) do
            local prefix = entry and entry.prefixArgs
            local lightId = prefix ~= nil and prefix[1] or nil
            if lightId ~= nil and nodes[lightId] then
                keys[#keys + 1] = key
            end
        end
        for i = 1, #keys do
            if FS25E_CapabilityApplier.restoreOne ~= nil then
                FS25E_CapabilityApplier.restoreOne(keys[i])
            end
        end
    end)
    FS25E_Debug.info(LOG, "restoreSoftForOwner done (per-light CapabilityApplier originals)")
end

--- Drop all handles for an owner (onDelete). Restores soft-apply first if used.
function FS25E_LightDiscovery.unregisterOwner(kind, owner)
    local okKey = ownerKey(kind, owner)
    if okKey == nil then
        return
    end
    FS25E_LightDiscovery.restoreSoftForOwner(kind, owner)
    if FS25E_LightTuning ~= nil then
        FS25E_LightTuning.restoreOwner(owner)
    end
    local handles = byOwner[okKey]
    if handles ~= nil then
        for i = 1, #handles do
            entries[handles[i]] = nil
        end
    end
    byOwner[okKey] = nil
    FS25E_Debug.debug(LOG, "unregisterOwner " .. tostring(okKey))
end

--- Re-resolve active low/high after lights profile change (nodes stay; active flags swap).
function FS25E_LightDiscovery.onLightsProfileChanged()
    local profileValue = resolveLightsProfileValue()
    FS25E_Debug.info(LOG, "onLightsProfileChanged value=" .. tostring(profileValue))
    local n = 0
    for _, entry in pairs(entries) do
        local high = isHighProfilePreferred(entry.owner)
        if entry.profile == "high" then
            entry.active = high
        elseif entry.profile == "low" then
            entry.active = not high
        end
        n = n + 1
    end
    FS25E_Debug.info(LOG, string.format("profile re-resolve entries=%d", n))
end

function FS25E_LightDiscovery.subscribeProfileChanges()
    if profileSubscribed then
        return
    end
    if g_messageCenter == nil or MessageType == nil or MessageType.SETTING_CHANGED == nil then
        FS25E_Debug.warning(LOG, "message center / SETTING_CHANGED unavailable; re-scan on demand only")
        return
    end

    local function subscribeKey(key, label)
        if key == nil then
            return false
        end
        local ok, err = pcall(function()
            local channel = MessageType.SETTING_CHANGED[key]
            if channel == nil then
                -- Placeable research uses string key "lightsProfile" directly as SETTING_CHANGED index.
                channel = MessageType.SETTING_CHANGED[tostring(key)]
            end
            if channel ~= nil then
                g_messageCenter:subscribe(channel, FS25E_LightDiscovery.onLightsProfileChanged, FS25E_LightDiscovery)
                FS25E_Debug.info(LOG, "subscribed profile change via " .. label)
                return
            end
            -- Fallback: some builds expose SETTING_CHANGED as a table keyed by setting name string.
            g_messageCenter:subscribe(MessageType.SETTING_CHANGED, function(settingKey)
                if settingKey == key or settingKey == "lightsProfile"
                    or (GameSettings ~= nil and GameSettings.SETTING ~= nil
                        and settingKey == GameSettings.SETTING.LIGHTS_PROFILE) then
                    FS25E_LightDiscovery.onLightsProfileChanged()
                end
            end, FS25E_LightDiscovery)
            FS25E_Debug.info(LOG, "subscribed SETTING_CHANGED (filtered) for " .. label)
        end)
        if not ok then
            FS25E_Debug.warning(LOG, "subscribe " .. label .. " failed: " .. tostring(err))
            return false
        end
        return true
    end

    local vehicleKey = nil
    if GameSettings ~= nil and GameSettings.SETTING ~= nil then
        vehicleKey = GameSettings.SETTING.LIGHTS_PROFILE
    end
    -- Vehicle Lights: MessageType.SETTING_CHANGED[GameSettings.SETTING.LIGHTS_PROFILE]
    subscribeKey(vehicleKey, "LIGHTS_PROFILE")
    -- PlaceableLights: MessageType.SETTING_CHANGED["lightsProfile"] (CONFIRMED string key)
    subscribeKey("lightsProfile", "lightsProfile(string)")

    profileSubscribed = true
end

function FS25E_LightDiscovery.unsubscribeProfileChanges()
    if not profileSubscribed or g_messageCenter == nil then
        profileSubscribed = false
        return
    end
    pcall(function()
        g_messageCenter:unsubscribeAll(FS25E_LightDiscovery)
    end)
    profileSubscribed = false
    FS25E_Debug.info(LOG, "unsubscribed profile changes")
end

function FS25E_LightDiscovery.getEntries()
    return entries
end

-- Enumerate only light sources owned by the documented specializations. The
-- profile flag alone is not a lamp switch: RealLight:setState uses visibility.
-- Compound child sources inherit the root's effective state.
function FS25E_LightDiscovery.getRuntimeEntries()
    local result, seen = {}, {}
    if type(entityExists)~='function' then return result end
    for _, entry in pairs(entries) do
        local high = isHighProfilePreferred(entry.owner)
        local profileActive = entry.profile == nil or (entry.profile == "high" and high)
            or (entry.profile == "low" and not high)
        local aliveOk,rootAlive=pcall(entityExists,entry.node)
        local rootVisible = aliveOk and rootAlive==true
        if rootVisible and type(getVisibility) == "function" then
            local ok, value = pcall(getVisibility, entry.node)
            rootVisible = ok and value == true
        end
        local sources = resolveSources(entry)
        for _, node in ipairs(sources) do
            local exists = node ~= nil and node ~= 0
            if exists and type(entityExists) == "function" then
                local ok, value = pcall(entityExists, node)
                exists = ok and value == true
            end
            if exists and FS25E_LightDiscovery.isLightSource(node) then
                local item = {}
                for key, value in pairs(entry) do item[key] = value end
                item.node = node
                item.profileActive = profileActive
                item.active = profileActive and rootVisible
                if item.active and type(getVisibility) == "function" then
                    item.active = sourceVisible(node,entry.node)
                end
                local previous=seen[node]
                if not previous then
                    result[#result + 1] = item
                    seen[node]=#result
                elseif item.active and not result[previous].active then
                    -- One native node may be referenced by both quality profiles.
                    -- pairs() order must never let its inactive alias hide it.
                    result[previous]=item
                end
            end
        end
    end
    return result
end

function FS25E_LightDiscovery.getCounts()
    local total, active, vehicle, placeable = 0, 0, 0, 0
    for _, e in pairs(entries) do
        total = total + 1
        if e.active then
            active = active + 1
        end
        if e.kind == "vehicle" then
            vehicle = vehicle + 1
        elseif e.kind == "placeable" then
            placeable = placeable + 1
        end
    end
    return {
        total = total,
        active = active,
        vehicle = vehicle,
        placeable = placeable,
        softApply = softApplyEnabled,
    }
end

local function dumpLine(e)
    return string.format(
        "  lightId=%s node=%s kind=%s profile=%s active=%s bucket=%s group=%s",
        tostring(e.node), tostring(e.node), tostring(e.kind), tostring(e.profile),
        tostring(e.active), tostring(e.bucket), tostring(e.groupIndex)
    )
end

--- Console dump — list discovered counts/nodes; prefer active first; no apply.
function FS25E_LightDiscovery.dump()
    local c = FS25E_LightDiscovery.getCounts()
    local lightsProfile = resolveLightsProfileValue()
    local msg = string.format(
        "lightsDump total=%d active=%d vehicle=%d placeable=%d softApply=%s lightsProfile=%s (read-only; no apply)",
        c.total, c.active, c.vehicle, c.placeable, tostring(c.softApply), tostring(lightsProfile)
    )
    FS25E_Debug.info(LOG, msg)
    if print ~= nil then
        print("[FS25_Enhanced] " .. msg)
    end

    -- Prefer active entries first (still max 64); inactive fill remaining slots.
    local activeList, inactiveList = {}, {}
    for _, e in pairs(entries) do
        if e.active then
            activeList[#activeList + 1] = e
        else
            inactiveList[#inactiveList + 1] = e
        end
    end

    local shown = 0
    local function emit(list)
        for i = 1, #list do
            if shown >= 64 then
                return
            end
            local line = dumpLine(list[i])
            FS25E_Debug.info(LOG, line)
            if print ~= nil then
                print("[FS25_Enhanced] " .. line)
            end
            shown = shown + 1
        end
    end
    emit(activeList)
    emit(inactiveList)

    if c.total > shown then
        local more = string.format("  ... %d more (truncated; active listed first)", c.total - shown)
        FS25E_Debug.info(LOG, more)
        if print ~= nil then
            print("[FS25_Enhanced] " .. more)
        end
    end
end

function FS25E_LightDiscovery.registerConsoleCommands()
    if consoleRegistered then
        return
    end
    if addConsoleCommand == nil then
        FS25E_Debug.info(LOG, "addConsoleCommand unavailable; fs25eLightsDump not registered")
        return
    end
    local ok, err = pcall(function()
        addConsoleCommand("fs25eLightsDump", "Dump discovered RealLight nodes (read-only)", "dump", FS25E_LightDiscovery)
    end)
    if ok then
        consoleRegistered = true
        FS25E_Debug.info(LOG, "console command fs25eLightsDump registered")
    else
        FS25E_Debug.warning(LOG, "addConsoleCommand failed: " .. tostring(err))
    end
end

--- Mileage-pattern injection: prepend TypeManager.finalizeTypes via HookManager.
--- Adds vehicle/placeable specs only when type already has lights specialization.
function FS25E_LightDiscovery.registerTypeInjection()
    if typeHookRegistered then
        return true
    end
    if FS25E_HookManager == nil then
        FS25E_Debug.warning(LOG, "HookManager missing; cannot inject specs")
        return false
    end
    if TypeManager == nil or TypeManager.finalizeTypes == nil then
        FS25E_Debug.warning(LOG, "TypeManager.finalizeTypes unavailable at register time")
        return false
    end

    local modName = g_currentModName or (FS25_Enhanced ~= nil and FS25_Enhanced.modName) or "FS25_Enhanced"
    local vehicleSpec = modName .. ".enhancedLightsProbe"
    local placeableSpec = modName .. ".enhancedPlaceableLightsProbe"

    local hooked = FS25E_HookManager.register(TypeManager, "finalizeTypes", "prepended", function(self)
        local ok, err = pcall(function()
            if self == nil or self.getTypes == nil then
                return
            end
            local typeName = self.typeName
            local types = self:getTypes()
            if types == nil then
                return
            end
            if typeName == "vehicle" then
                for name, typeEntry in pairs(types) do
                    if typeEntry ~= nil and typeEntry.specializationsByName ~= nil
                        and typeEntry.specializationsByName["lights"] ~= nil then
                        local already = typeEntry.specializationsByName["enhancedLightsProbe"] ~= nil
                            or typeEntry.specializationsByName[vehicleSpec] ~= nil
                        if not already then
                            local addOk, addErr = pcall(function()
                                self:addSpecialization(name, vehicleSpec)
                            end)
                            if not addOk then
                                FS25E_Debug.warning(LOG, "addSpecialization vehicle failed: " .. tostring(addErr))
                            end
                        end
                    end
                end
            elseif typeName == "placeable" then
                for name, typeEntry in pairs(types) do
                    if typeEntry ~= nil and typeEntry.specializationsByName ~= nil
                        and typeEntry.specializationsByName["lights"] ~= nil then
                        local already = typeEntry.specializationsByName["enhancedPlaceableLightsProbe"] ~= nil
                            or typeEntry.specializationsByName[placeableSpec] ~= nil
                        if not already then
                            local addOk, addErr = pcall(function()
                                self:addSpecialization(name, placeableSpec)
                            end)
                            if not addOk then
                                FS25E_Debug.warning(LOG, "addSpecialization placeable failed: " .. tostring(addErr))
                            end
                        end
                    end
                end
            end
        end)
        if not ok then
            FS25E_Debug.warning(LOG, "finalizeTypes inject failed: " .. tostring(err))
        end
    end)

    typeHookRegistered = hooked == true
    FS25E_Debug.info(LOG, "TypeManager.finalizeTypes inject registered=" .. tostring(typeHookRegistered))
    return typeHookRegistered
end
