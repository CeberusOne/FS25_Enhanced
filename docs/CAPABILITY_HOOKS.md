# Capability hooks (Diagnostics / Experimental)

## Results

- `markApplied(id, detail?)` → log `APPLIED`
- `reject(id, reason)` → status REJECTED + log `REJECTED`
- `markSkipped(id, reason)` → log `SKIPPED` (e.g. !expertMode, missing lightId)
- `getLastResult(id)` → `{ status, error, detail, ts }`

## Listeners

```lua
FS25E_CapabilityRegistry.onApply(function(id, payload) end)
FS25E_CapabilityRegistry.onReject(function(id, payload) end)
FS25E_CapabilityRegistry.onSkip(function(id, payload) end)
```

## allowsApply

- `expertMode=false` → **CONFIRMED** only
- `expertMode=true` → also EXPERIMENTAL / GATED / ASSET_DEPENDENT  
  (GATED still needs `getSupports*` at apply site; ASSET needs lightId/asset)

Soft-Apply / autoApply defaults remain **false**.
