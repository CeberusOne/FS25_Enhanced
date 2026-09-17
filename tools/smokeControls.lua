-- Offline smoke test: load the mod's control stack against the stub engine
-- and exercise build/read/available/apply/restore for every registered control.
local MOD = os.getenv('MOD_DIR') or '.'
dofile(MOD .. '/tools/engineStub.lua')

-- ---- load the mod ------------------------------------------------------
local files = {
    'scripts/Core/Localization.lua', 'scripts/Core/Debug.lua', 'scripts/Core/HookManager.lua',
    'scripts/Core/CapabilityRegistry.lua', 'scripts/Core/SettingsCache.lua', 'scripts/Core/CapabilityApplier.lua',
    'scripts/Core/RestoreManager.lua', 'scripts/Core/ModSettings.lua', 'scripts/Core/SettingsSchema.lua',
    'scripts/Core/GameSettingsControls.lua', 'scripts/Core/QualityLevels.lua', 'scripts/Core/VisualControls.lua',
}
for _, f in ipairs(files) do
    local chunk, err = loadfile(MOD .. '/' .. f)
    if not chunk then error('load ' .. f .. ': ' .. tostring(err)) end
    chunk()
end

FS25E_CapabilityRegistry.load(MOD .. '/')
FS25E_VisualControls.build()
FS25E_VisualControls.registerProvider(FS25E_GameSettingsControls)
FS25E_VisualControls.registerProvider(FS25E_QualityLevels)

-- ---- exercise every control -------------------------------------------
local controls = FS25E_VisualControls.getControls()
local ok, unavailable, failed = 0, 0, 0
local byCategory = {}
for _, c in ipairs(controls) do
    byCategory[c.category] = (byCategory[c.category] or 0) + 1
    local available = FS25E_VisualControls.available(c)
    if not available then
        unavailable = unavailable + 1
    else
        local before = FS25E_VisualControls.read(c)
        local target = c.kind == 'bool' and (before and before < 0.5 and 1 or 0)
            or math.min(c.max, (before or c.min) + c.step)
        local applied, reason = FS25E_VisualControls.apply(c.id, target)
        if applied then
            ok = ok + 1
            if not FS25E_VisualControls.restore(c.id) then
                failed = failed + 1
                io.write('RESTORE FAILED ', c.id, '\n')
            end
        else
            failed = failed + 1
            io.write('APPLY FAILED ', c.id, ' -> ', tostring(reason), '\n')
        end
    end
end
-- quality level: Ultra must put every available member at its maximum, Off must restore
do
    local okUltra = FS25E_VisualControls.apply('enhancedLevel', 5)
    local atMax, members = 0, 0
    for _, c in ipairs(controls) do
        if c.id ~= 'enhancedLevel' and FS25E_VisualControls.available(c) then
            local st = FS25E_VisualControls.getState(c.id)
            if st and st.original ~= nil then
                members = members + 1
                local v = FS25E_VisualControls.read(c)
                if v and math.abs(v - c.max) < 1e-6 then atMax = atMax + 1 else io.write('   not max: ', c.id, ' = ', tostring(v), ' / ', tostring(c.max), string.char(10)) end
            end
        end
    end
    io.write(string.format('ultra: applied=%s members=%d atMax=%d' .. string.char(10), tostring(okUltra), members, atMax))
    if not okUltra or members == 0 then failed = failed + 1 end
    local okOff = FS25E_VisualControls.apply('enhancedLevel', 0)
    local dirty = 0
    for _, c in ipairs(controls) do
        local st = FS25E_VisualControls.getState(c.id)
        if c.id ~= 'enhancedLevel' and st and st.original ~= nil and st.status ~= 'FS25E_status_restored' then dirty = dirty + 1 end
    end
    io.write(string.format('off: restored=%s stillModified=%d' .. string.char(10), tostring(okOff), dirty))
    if not okOff or dirty > 0 then failed = failed + 1 end
end
local names = {}
for k in pairs(byCategory) do names[#names + 1] = k end
table.sort(names)
io.write('\ncontrols=', #controls, '  applied+restored=', ok, '  unavailable=', unavailable, '  failed=', failed, '\n')
for _, k in ipairs(names) do io.write(string.format('  %-14s %d\n', k, byCategory[k])) end
os.exit(failed == 0 and 0 or 1)
