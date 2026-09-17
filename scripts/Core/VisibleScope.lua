-- Camera-frustum + adjustable local radius. Not a pixel occlusion or GPU-budget API.
FS25E_VisibleScope={}
local S=FS25E_VisibleScope
local cache,stamp=nil,nil
local lod={['view-distance-coeff']=true,['lod-distance-coeff']=true,['terrain-lod-distance-coeff']=true,
 ['foliage-view-distance-coeff']=true,['foliage-lod-distance-coeff']=true}
local localProviders={FS25E_LightTuning=true,FS25E_MaterialManager=true,FS25E_FoliageManager=true}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function call(name,...)
 if type(_G[name])~='function' then return nil end
 local ok,a,b,c=pcall(_G[name],...);if ok then return a,b,c end
end
local function valid(n) return type(n)=='number' and n~=0 and call('entityExists',n)==true end
function S.getRadius()
 local raw=FS25E_ModSettings and FS25E_ModSettings.get('visibleRadius')
 local radius=tonumber(raw);if not finite(radius) then radius=80 end
 return math.max(5,math.min(300,radius))
end
local function camera()
 if g_time~=nil and stamp==g_time then return cache end
 stamp=g_time;cache=nil
 local n=call('getCamera')
 if not valid(n) then return nil end
 if ClassIds and ClassIds.CAMERA and call('getHasClassId',n,ClassIds.CAMERA)~=true then return nil end
 local fov=call('getFovY',n)
 if not finite(fov) or fov<=0 or fov>=math.pi then return nil end
 if call('getIsOrthographic',n)==true then return nil end
 local aspect=(tonumber(g_screenWidth) or 1920)/(tonumber(g_screenHeight) or 1080)
 if not finite(aspect) or aspect<=0 then return nil end
 cache={node=n,tanY=math.tan(fov*.5),aspect=aspect}
 return cache
end
local function locate(node)
 if not valid(node) then return nil end
 local c=camera();if not c then return nil end
 local x,y,z=call('getWorldTranslation',node)
 if not finite(x) or not finite(y) or not finite(z) then return nil end
 x,y,z=call('worldToLocal',c.node,x,y,z)
 if not finite(x) or not finite(y) or not finite(z) then return nil end
 return c,x,y,-z,math.sqrt(x*x+y*y+z*z)
end
-- The margin conservatively retains sources whose light/shape can reach the view.
-- Radial cutoff uses the source origin. Large surfaces/particles can cross this boundary.
function S.containsNode(node,boundsRadius)
 local c,x,y,depth,distance=locate(node);if not c or distance>S.getRadius() then return false end
 local margin=finite(boundsRadius) and math.max(0,math.min(200,boundsRadius)) or 0
 if depth+margin<0 then return false end
 local extent=math.max(0,depth)
 return math.abs(x)<=extent*c.tanY*c.aspect+margin and math.abs(y)<=extent*c.tanY+margin
end
function S.containsFootprint(node,boundsRadius)
 local c,x,y,depth,distance=locate(node);if not c then return false end
 local margin=finite(boundsRadius) and math.max(0,boundsRadius) or 0
 return distance+margin<=S.getRadius() and S.containsNode(node,margin)
end
function S.weight(node)
 local c,x,y,depth,distance=locate(node);if not c or depth<=0 then return 0 end
 local radius=S.getRadius();if distance>=radius then return 0 end
 local horizontal=math.abs(x)/(depth*c.tanY*c.aspect)
 local vertical=math.abs(y)/(depth*c.tanY)
 local edge=math.max(horizontal,vertical)
 if edge>=1 then return 0 end
 return math.min(1,(radius-distance)/math.max(1,radius*.15),(1-edge)/.1)
end
function S.allowsCapability(id) return lod[id]==true end
function S.allowsControl(c)
 if not c then return false end
 if c.runtimeControl or c.kind=='action' or c.id=='enhanced-visible-radius' then return true end
 if lod[c.id] then return true end
 local provider=c.provider
 if provider then
  for name in pairs(localProviders) do if provider==_G[name] then return true end end
 end
 return false
end
function S.setRadius(value)
 if not finite(value) then return false,'FS25E_status_invalid_value' end
 value=math.max(5,math.min(300,math.floor(value+.5)))
 if not FS25E_ModSettings or not FS25E_ModSettings.set('visibleRadius',tostring(value)) then return false,'FS25E_status_profile_unavailable' end
 cache=nil;stamp=nil
 if FS25E_ModSettings.save then FS25E_ModSettings.save() end
 return true
end
function S.reset() cache=nil;stamp=nil;return true end
function S.getControls()
 return {{id='enhanced-visible-radius',category='auto',min=5,max=300,step=1,cost='high',runtimeControl=true,
  labelKey='FS25E_setting_visibleRadius',tooltipKey='FS25E_tooltip_visibleRadius',verification='configuration',
  read=S.getRadius,write=S.setRadius,restore=function()return S.setRadius(80)end,
  format=function(v)return string.format('%.0f m',v)end,available=function()return true end}}
end
