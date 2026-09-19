-- Responsive FS25 live graphics panel. All native writes belong to adapters.
FS25E_LiveOverlay = {}
local UI=FS25E_LiveOverlay
local unpack=unpack or table.unpack
local visible,hooks,context=false,false,false
local category,selected,scroll=2,1,0
local boxes,rows={},{}
local drag,edit,hover,message=nil,nil,nil,nil
local cursor=false
local lastNavigation,lastWheel={},-1
local categories={'presets','shadows','lighting','atmosphere','image','environment','weather','water','reflections','materials','foliage','lod','camera','performance'}
-- Panel geometry lives in a fixed 1920x1080 layout space; draw() maps it onto
-- the real back buffer. The user can move and resize it, so nothing below may
-- assume the shipped defaults.
local DEFAULT={x=1040,y=126,w=848,h=868}
local MIN_W,MIN_H,MAX_W,MAX_H=620,420,1900,1060
local LAYOUT={w=1920,h=1080}
local P={x=DEFAULT.x,y=DEFAULT.y,w=DEFAULT.w,h=DEFAULT.h}
-- Vertical budget of the fixed chrome: header block above the list and the
-- status/tooltip/hint block below it.
local LIST_TOP,FOOTER,ROW_H=145,176,108
local pageSize=5
local layoutLoaded=false
local sx,sy=1/1920,1/1080
local colors={panel={.045,.059,.071,.98},side={.035,.044,.05,1},row={.085,.104,.12,1},selected={.115,.145,.16,1},text={.94,.955,.96,1},muted={.58,.65,.69,1},green={.56,.78,.035,1},track={.19,.23,.25,1},warning={1,.69,.26,1}}
local function t(key)
    if FS25E_Localization and FS25E_Localization.t then
        local ok,value=pcall(FS25E_Localization.t,key)
        if ok and value~=nil then return value end
    end
    return key
end
local function rect(x,y,w,h,color) if drawFilledRect then drawFilledRect(x*sx,1-(y+h)*sy,w*sx,h*sy,unpack(color)) end end
local function width(value,size) return getTextWidth and getTextWidth(size*sy,value)/sx or #value*size*.5 end
-- renderText uses global state shared with the HUD. Define the vertical origin
-- explicitly; a font's baseline is not its bounding box's bottom edge.
local function text(x,y,size,value,color,maxWidth,bold)
    value=tostring(value or '')
    setTextBold(bold==true)
    if maxWidth then
        while size>10 and width(value,size)>maxWidth do size=size-.5 end
        if width(value,size)>maxWidth then
            local chars={}; for ch in value:gmatch('[%z\1-\127\194-\244][\128-\191]*') do chars[#chars+1]=ch end
            repeat chars[#chars]=nil; value=table.concat(chars)..'...' until #chars==0 or width(value,size)<=maxWidth
        end
    end
    setTextAlignment(RenderText and RenderText.ALIGN_LEFT or 0); setTextColor(unpack(color or colors.text))
    if setTextVerticalAlignment and RenderText and RenderText.VERTICAL_ALIGN_TOP then
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
        renderText(x*sx,1-y*sy,size*sy,value)
    else
        renderText(x*sx,1-(y+size)*sy,size*sy,value)
    end
end
local function wrap(x,y,size,value,maxWidth,maxLines,color)
    setTextBold(false)
    local line,n='',0
    for ch in tostring(value):gmatch('[%z\1-\127\194-\244][\128-\191]*') do
        if ch=='\n' or width(line..ch,size)>maxWidth then
            text(x,y+n*(size+5),size,line,color,maxWidth); n=n+1; line=''
            if n>=maxLines then return end
        end
        if ch~='\n' then line=line..ch end
    end
    if line~='' then text(x,y+n*(size+5),size,line,color,maxWidth) end
end
local function inside(b,x,y) return x>=b.x and x<=b.x+b.w and y>=b.y and y<=b.y+b.h end
local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
--- Keep the window inside the visible layout area after a move, a resize or a
--- resolution change, and recompute how many rows fit into the new height.
local function clampPanel()
    P.w=clamp(P.w,MIN_W,math.min(MAX_W,LAYOUT.w))
    P.h=clamp(P.h,MIN_H,math.min(MAX_H,LAYOUT.h))
    P.x=clamp(P.x,0,math.max(0,LAYOUT.w-P.w))
    P.y=clamp(P.y,0,math.max(0,LAYOUT.h-P.h))
    pageSize=math.max(1,math.floor((P.h-LIST_TOP-FOOTER)/ROW_H))
end
local function saveLayout()
    if not FS25E_ModSettings or not FS25E_ModSettings.set then return end
    local value=string.format('%d,%d,%d,%d',math.floor(P.x+.5),math.floor(P.y+.5),math.floor(P.w+.5),math.floor(P.h+.5))
    if FS25E_ModSettings.set('liveWindowRect',value) and FS25E_ModSettings.save then pcall(FS25E_ModSettings.save) end
end
local function loadLayout()
    if layoutLoaded then return end
    layoutLoaded=true
    local value=FS25E_ModSettings and FS25E_ModSettings.get and FS25E_ModSettings.get('liveWindowRect')
    if type(value)~='string' then return end
    local x,y,w,h=value:match('^(-?%d+),(-?%d+),(%d+),(%d+)$')
    if not x then return end
    P.x,P.y,P.w,P.h=tonumber(x),tonumber(y),tonumber(w),tonumber(h)
    P.docked=false
    clampPanel()
end
function UI.resetLayout()
    P.x,P.y,P.w,P.h=DEFAULT.x,DEFAULT.y,DEFAULT.w,DEFAULT.h
    P.docked=true
    clampPanel(); saveLayout(); boxes={}
end
local function hit(x,y,w,h,action,data) boxes[#boxes+1]={x=x,y=y,w=w,h=h,action=action,data=data} end
local function button(x,y,w,h,label,action,data,active)
    rect(x,y,w,h,active and colors.green or colors.track)
    text(x+8,y+(h-15)*.5,15,label,active and colors.side or colors.text,w-16,true); hit(x,y,w,h,action,data)
end
local function hideUnavailable()
    return not FS25E_ModSettings or FS25E_ModSettings.get('hideUnavailable')~=false
end
local function refresh()
    rows={}
    local ok,list=pcall(function()
        return FS25E_VisualControls and FS25E_VisualControls.getControls() or {}
    end)
    if not ok or type(list)~='table' then
        selected=1; scroll=0
        return
    end
    for _,c in ipairs(list) do
        if c.category==categories[category] and (not FS25E_LiveSelection or FS25E_LiveSelection.isVisible(c)) then
            local skip=false
            if hideUnavailable() and not c.alwaysShow and c.kind~='action' and not c.runtimeControl and not c.profileSelector then
                local available=true
                if FS25E_VisualControls and FS25E_VisualControls.available then
                    local aok,result=pcall(FS25E_VisualControls.available,c)
                    if aok then available=result==true end
                end
                if not available then skip=true end
            end
            if not skip then rows[#rows+1]=c end
        end
    end
    selected=math.max(1,math.min(#rows,selected)); scroll=math.max(0,math.min(math.max(0,#rows-pageSize),scroll))
end
function UI.currentCategory() return categories[category] end
local function format(c,v)
    if v==nil then return t('FS25E_status_unavailable_short') end
    if c.format then local ok,r=pcall(c.format,v); if ok and r then return r end end
    if c.kind=='bool' then return t(v>=.5 and 'FS25E_value_on' or 'FS25E_value_off') end
    return string.format(c.step<.01 and '%.3f' or (c.step<1 and '%.2f' or '%.0f'),v)
end
local function apply(c,v)
    local ok,err=FS25E_VisualControls.apply(c.id,v)
    message=ok and FS25E_VisualControls.getState(c.id).status or (err or 'FS25E_status_not_applied')
end
local function fine()
    return Input and Input.isKeyPressed and ((Input.KEY_lshift and Input.isKeyPressed(Input.KEY_lshift)) or (Input.KEY_rshift and Input.isKeyPressed(Input.KEY_rshift)))
end
local function nudge(direction)
    local c=rows[selected]; if not c then return end
    local v=FS25E_VisualControls.read(c); if v==nil then return end
    apply(c,v+direction*c.step*(c.step<1 and not fine() and 10 or 1))
end
local function selectCategory(n)
    category=math.max(1,math.min(#categories,n)); selected=1; scroll=0; edit=nil; drag=nil; hover=nil; boxes={}; refresh()
end
function UI.selectCategory(id) if id=='auto' then id='presets' end; for i,v in ipairs(categories) do if v==id then selectCategory(i); return end end end
local function moveSelection(d)
    selected=math.max(1,math.min(#rows,selected+d)); scroll=math.min(scroll,selected-1)
    if selected>scroll+pageSize then scroll=selected-pageSize end
end
local function navigate(kind,value)
    local key=kind..tostring(value); local now=g_time or 0
    -- Native MENU actions and raw keyboard events can represent the same input.
    if lastNavigation[key]==now then return end
    lastNavigation[key]=now
    if kind=='row' then moveSelection(value) else nudge(value) end
end
local function registerController()
    if not g_inputBinding or not InputAction then return end
    if g_inputBinding.setContext then g_inputBinding:setContext('FS25E_LIVE',true,false); context=true end
    local last={}
    local function event(name,callback,continuous)
        if not InputAction[name] or not g_inputBinding.registerActionEvent then return end
        local _,eid=g_inputBinding:registerActionEvent(InputAction[name],UI,function(_,action,v)
            if not visible or edit or math.abs(v or 0)<.25 then return end
            local now=g_time or 0
            if continuous and last[name] and now-last[name]<130 then return end
            last[name]=now; callback(v)
        end,false,true,continuous==true,true)
        if eid and g_inputBinding.setActionEventTextVisibility then g_inputBinding:setActionEventTextVisibility(eid,false) end
    end
    event('MENU_AXIS_UP_DOWN',function(v) navigate('row',v>0 and -1 or 1) end,true)
    event('MENU_AXIS_LEFT_RIGHT',function(v) navigate('value',v>0 and 1 or -1) end,true)
    event('MENU_PAGE_PREV',function() selectCategory(category-1) end)
    event('MENU_PAGE_NEXT',function() selectCategory(category+1) end)
    event('MENU_BACK',function() UI.hide() end)
    event('MENU_ACCEPT',function()
        local c=rows[selected]
        if c and c.kind=='action' then local ok,result,reason=pcall(c.run); message=ok and reason or 'FS25E_status_module_error'
        elseif c and (c.kind=='enum' or c.kind=='bool') then local v=FS25E_VisualControls.read(c); if v then apply(c,v>=c.max and c.min or v+c.step) end end
    end)
end
function UI.canShow() return g_currentMission~=nil end
function UI.gateStatusMessage() return t('FS25E_status_mission_required') end
function UI.isVisible() return visible end
function UI.show(categoryId)
    if not UI.canShow() then return false end
    if visible then if categoryId then UI.selectCategory(categoryId) end; return true end
    visible=true; message=nil; lastNavigation={}; refresh(); if categoryId then UI.selectCategory(categoryId) end
    cursor=false
    if g_inputBinding then
        if g_inputBinding.getShowMouseCursor then
            local ok,shown=pcall(function() return g_inputBinding:getShowMouseCursor() end)
            if ok then cursor=shown==true end
        end
        pcall(registerController)
        if g_inputBinding.setShowMouseCursor then pcall(function() g_inputBinding:setShowMouseCursor(true) end) end
    end
    return true
end
function UI.hide()
    if not visible then return end
    if drag and drag.mode then saveLayout() end
    visible=false; drag=nil; edit=nil; boxes={}
    if g_inputBinding then
        if g_inputBinding.removeActionEventsByTarget then g_inputBinding:removeActionEventsByTarget(UI) end
        if context and g_inputBinding.revertContext then g_inputBinding:revertContext(false) end
        if g_inputBinding.setShowMouseCursor then g_inputBinding:setShowMouseCursor(cursor==true) end
    end
    context=false
end
function UI.toggle(force)
    if force==true then return UI.show() end
    if force==false then UI.hide(); return true end
    if visible then UI.hide(); return true end
    return UI.show()
end
function UI.installListeners() end
local function drawPanel()
    if not visible then return end
    local sw,sh=g_screenWidth or 1920,g_screenHeight or 1080
    local scale=math.min(sw/1920,sh/1080); sx=scale/sw; sy=scale/sh
    LAYOUT.w,LAYOUT.h=sw/scale,sh/scale
    loadLayout()
    -- Until the window is moved for the first time it stays docked to the right
    -- edge, which is where earlier versions always drew it.
    if P.docked~=false then P.x=LAYOUT.w-P.w-32; P.docked=true end
    clampPanel()
    boxes={}; refresh()
    if setTextWrapWidth then setTextWrapWidth(0) end
    if setTextFirstLineIndentation then setTextFirstLineIndentation(0) end
    if setTextLineHeightScale and RenderText then setTextLineHeightScale(RenderText.DEFAULT_LINE_HEIGHT_SCALE) end
    if setTextClipArea then setTextClipArea(0,0,1,1) end
    rect(P.x+5,P.y+6,P.w,P.h,{0,0,0,.35}); rect(P.x,P.y,P.w,P.h,colors.panel); rect(P.x,P.y,P.w,4,colors.green)
    text(P.x+24,P.y+20,25,t('FS25E_menu_live_title'),colors.text,P.w-290,true)
    text(P.x+24,P.y+57,14,t('FS25E_menu_live_subtitle'),colors.muted,P.w-190)
    button(P.x+P.w-57,P.y+20,34,34,'X','close')
    button(P.x+P.w-101,P.y+20,34,34,'[]','resetLayout')
    -- Master switch: MOD applies everything, VANILLA restores the stock look.
    local comparing=FS25E_VisualProfiles and FS25E_VisualProfiles.isComparing and FS25E_VisualProfiles.isComparing()
    button(P.x+P.w-241,P.y+20,132,34,t(comparing and 'FS25E_compare_button_vanilla' or 'FS25E_compare_button_mod'),'compare',nil,not comparing)
    -- Registered after the buttons: the first matching box wins, so the header
    -- strip only starts a move where no button sits.
    hit(P.x,P.y,P.w,93,'move')
    rect(P.x,P.y+93,180,P.h-93,colors.side)
    -- The category strip shrinks with the window so every tab stays reachable.
    local catH=math.min(43,math.max(22,(P.h-125)/math.max(1,#categories)))
    for i,id in ipairs(categories) do
        local y=P.y+109+(i-1)*catH
        local h=catH-6
        if i==category then rect(P.x+10,y,160,h,colors.selected); rect(P.x+10,y,3,h,colors.green) end
        text(P.x+24,y+(h-16)*.5,math.min(16,h-5),t('FS25E_menu_'..id),i==category and colors.green or colors.muted,136,i==category)
        hit(P.x+10,y,160,h,'category',i)
    end
    local x,w=P.x+200,P.w-220
    text(x,P.y+105,19,t('FS25E_menu_'..categories[category]),colors.text,w-220,true)
    button(x+w-210,P.y+102,100,28,t('FS25E_menu_reset_tab'),'resetCategory')
    text(x+w-100,P.y+108,13,string.format('%d / %d',math.min(#rows,scroll+1),#rows),colors.muted,100)
    if #rows==0 then
        local key='FS25E_status_category_unavailable'
        if FS25E_LiveSelection then local _,total=FS25E_LiveSelection.count(categories[category]); if total>0 then key='FS25E_status_selection_empty' end end
        wrap(x,P.y+166,17,t(key),w,6,colors.muted)
    end
    for index=scroll+1,math.min(#rows,scroll+pageSize) do
        local c=rows[index]; local y=P.y+LIST_TOP+(index-scroll-1)*ROW_H
        local available,reason=FS25E_VisualControls.available(c)
        local value=FS25E_VisualControls.read(c); local state=FS25E_VisualControls.getState(c.id) or {}
        rect(x,y,w,99,index==selected and colors.selected or colors.row)
        if index==selected then rect(x,y,3,99,colors.green) end
        if c.kind=='action' then
            text(x+14,y+10,17,t(c.labelKey),colors.text,w-164,true)
            button(x+14,y+53,w-28,32,t('FS25E_menu_execute'),'run',index)
            hit(x,y,w,99,'row',index)
        else
        text(x+14,y+10,17,t(c.labelKey),available and colors.text or colors.muted,w-196,true)
        text(x+14,y+36,12,t('FS25E_cost_'..c.cost)..' / '..t('FS25E_status_live'),c.cost=='extreme' and colors.warning or colors.muted,w-204)
        local rendered=edit and edit.id==c.id and edit.value..'|' or format(c,value)
        rect(x+w-164,y+9,150,35,edit and edit.id==c.id and colors.track or colors.side)
        text(x+w-154,y+17,16,rendered,colors.text,130,true)
        if available and c.kind~='enum' and c.kind~='bool' then hit(x+w-164,y+9,150,35,'edit',index) end
        if available and value~=nil then
            local bx,bw,by=x+50,w-192,y+68
            local ratio=math.max(0,math.min(1,(value-c.min)/math.max(.00001,c.max-c.min)))
            rect(bx,by,bw,5,colors.track); rect(bx,by,bw*ratio,5,colors.green)
            if state.original~=nil then
                local original=math.max(0,math.min(1,(state.original-c.min)/math.max(.00001,c.max-c.min)))
                rect(bx+bw*original-1,by-5,2,15,colors.muted)
            end
            rect(bx+bw*ratio-5,by-6,10,17,colors.text)
            hit(bx-5,by-12,bw+10,28,'slider',{index=index,x=bx,w=bw})
            button(x+14,y+55,28,30,'-','minus',index); button(x+w-134,y+55,28,30,'+','plus',index)
            button(x+w-94,y+55,80,30,t('FS25E_menu_reset'),'reset',index)
        else text(x+14,y+64,13,t(reason or 'FS25E_status_unreadable'),colors.warning,w-28) end
        hit(x,y,w,99,'row',index)
        end
    end
    -- The footer block is anchored to the bottom edge, so it follows a resize.
    local footer=P.y+P.h-FOOTER
    if #rows>pageSize then button(x+w-80,footer,35,28,'<','up'); button(x+w-40,footer,35,28,'>','down') end
    local c=rows[selected]
    if c then
        local state=FS25E_VisualControls.getState(c.id) or {}
        text(x,footer+9,13,t(state.status or 'FS25E_status_ready'),state.error and colors.warning or colors.green,w-100)
        wrap(x,footer+34,14,t(c.tooltipKey),w,3,colors.muted)
    end
    rect(x,footer+102,w,1,colors.track)
    text(x,footer+114,12,t(message or 'FS25E_menu_fine_hint'),colors.muted,w)
    text(x,footer+139,12,t('FS25E_menu_controller_hint')..'   -   '..t('FS25E_menu_window_hint'),colors.muted,w)
    -- Resize grip in the bottom right corner.
    local gs=18
    rect(P.x+P.w-gs-4,P.y+P.h-gs-4,gs,3,colors.track)
    rect(P.x+P.w-gs-4,P.y+P.h-gs+2,gs,3,colors.track)
    rect(P.x+P.w-gs-4,P.y+P.h-gs+8,gs,3,hover and hover.action=='resize' and colors.green or colors.track)
    hit(P.x+P.w-gs-10,P.y+P.h-gs-10,gs+10,gs+10,'resize')
    setTextBold(false); setTextColor(1,1,1,1); setTextAlignment(RenderText and RenderText.ALIGN_LEFT or 0)
    if setTextVerticalAlignment and RenderText then setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE) end
end
function UI.draw()
    local ok,err=pcall(drawPanel)
    if not ok and FS25E_Debug then FS25E_Debug.warning('LiveOverlay','draw failed: '..tostring(err)) end
end
--- Apply a window move or resize for the current pointer position.
local function dragWindow(d,x,y)
    if d.mode=='move' then
        P.x=x-d.offsetX; P.y=y-d.offsetY; P.docked=false
    else
        P.w=d.startW+(x-d.startX); P.h=d.startH+(y-d.startY); P.docked=false
    end
    clampPanel()
    -- Hit boxes were built for the old rectangle.
    boxes={}; hover=nil
    if selected>scroll+pageSize then scroll=math.max(0,selected-pageSize) end
    scroll=math.max(0,math.min(math.max(0,#rows-pageSize),scroll))
end
local function dragValue(d,x)
    local c=rows[d.index]; if not c then return end
    local ratio=math.max(0,math.min(1,(x-d.x)/d.w)); local v=c.min+ratio*(c.max-c.min)
    if fine() and d.startValue then v=d.startValue+(x-d.startX)/d.w*(c.max-c.min)*.1 end
    apply(c,v)
end
function UI.mouseEvent(px,py,isDown,isUp,buttonId)
    if not visible then return false end
    local x,y=px/sx,(1-py)/sy
    if isUp then
        if drag and drag.mode then saveLayout() end
        drag=nil
    end
    if drag and not isDown and not isUp then
        if drag.mode then dragWindow(drag,x,y) else dragValue(drag,x) end
        return true
    end
    hover=nil
    for _,b in ipairs(boxes) do if inside(b,x,y) then
        hover=b
        if Input and Input.isMouseButtonPressed and lastWheel~=(g_time or 0) then
            local up=Input.MOUSE_BUTTON_WHEEL_UP and Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_UP)
            local down=Input.MOUSE_BUTTON_WHEEL_DOWN and Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_DOWN)
            if up or down then lastWheel=g_time or 0; UI.mouseWheel(up and 1 or -1); return true end
        end
        if isDown and (buttonId==1 or buttonId==nil) then
            local a,d=b.action,b.data
            if a=='close' then UI.hide()
            elseif a=='move' then drag={mode='move',offsetX=x-P.x,offsetY=y-P.y}
            elseif a=='resize' then drag={mode='resize',startX=x,startY=y,startW=P.w,startH=P.h}
            elseif a=='resetLayout' then UI.resetLayout()
            elseif a=='resetCategory' then
                if FS25E_VisualControls and FS25E_VisualControls.restoreCategory then
                    local ok=FS25E_VisualControls.restoreCategory(categories[category])
                    message=ok and 'FS25E_status_restored' or 'FS25E_status_restore_failed'
                end
            elseif a=='compare' then
                if FS25E_VisualProfiles and FS25E_VisualProfiles.toggleCompare then
                    local ok,status=FS25E_VisualProfiles.toggleCompare(); message=status; boxes={}
                end
            elseif a=='category' then selectCategory(d)
            elseif a=='up' then scroll=math.max(0,scroll-1); boxes={}; hover=nil; drag=nil
            elseif a=='down' then scroll=math.min(math.max(0,#rows-pageSize),scroll+1); boxes={}; hover=nil; drag=nil
            elseif a=='slider' then selected=d.index; edit=nil; drag={index=d.index,x=d.x,w=d.w,startX=x,startValue=FS25E_VisualControls.read(rows[d.index])}; if not fine() then dragValue(drag,x) end
            else
                selected=d; local c=rows[d]
                if c then
                    if a=='minus' then nudge(-1) elseif a=='plus' then nudge(1)
                    elseif a=='reset' then FS25E_VisualControls.restore(c.id)
                    elseif a=='run' then
                        local ok,result,reason=pcall(c.run)
                        message=ok and reason or 'FS25E_status_module_error'
                        if not message then message=result and 'FS25E_status_configured' or 'FS25E_status_not_applied' end
                    elseif a=='edit' then edit={id=c.id,value=format(c,FS25E_VisualControls.read(c)),replace=true} end
                end
            end
        end
        return true
    end end
    return inside(P,x,y)
end
function UI.mouseWheel(delta)
    if not visible then return false end
    if delta and delta~=0 then
        if hover and hover.action=='slider' then selected=hover.data.index; nudge(delta>0 and 1 or -1)
        else
            scroll=math.max(0,math.min(math.max(0,#rows-pageSize),scroll+(delta>0 and -1 or 1)))
            boxes={}; drag=nil; hover=nil
        end
    end
    return true
end
local function key(sym,name,fallback) return sym==(Input and Input['KEY_'..name] or fallback) end
local function isF9(sym)
    local keyF9=Input and Input.KEY_f9
    return keyF9~=nil and sym==keyF9
end
function UI.keyEvent(unicode,sym,modifier,isDown)
    if not visible then return false end
    if not isDown then return true end
    -- Do not close on F9 here: the appended Input hook toggles. Handling F9
    -- in both places would hide and immediately show again.
    if isF9(sym) then return true end
    if edit then
        if key(sym,'esc',27) then edit=nil
        elseif key(sym,'return',13) then
            local c=FS25E_VisualControls.get(edit.id); local v=tonumber((edit.value:gsub(',','.')))
            if v then apply(c,v); edit=nil else message='FS25E_status_invalid_value' end
        elseif key(sym,'backspace',8) then edit.value=edit.value:sub(1,-2); edit.replace=false
        elseif type(unicode)=='number' and ((unicode>=48 and unicode<=57) or unicode==45 or unicode==46 or unicode==44) then
            if edit.replace then edit.value=''; edit.replace=false end
            if #edit.value<12 then edit.value=edit.value..string.char(unicode) end
        end
        return true
    end
    if key(sym,'esc',27) then UI.hide()
    elseif key(sym,'left',276) or unicode==45 then navigate('value',-1)
    elseif key(sym,'right',275) or unicode==43 then navigate('value',1)
    elseif key(sym,'up',273) then navigate('row',-1)
    elseif key(sym,'down',274) then navigate('row',1)
    elseif key(sym,'pageup',280) then selectCategory(category-1)
    elseif key(sym,'pagedown',281) then selectCategory(category+1)
    elseif key(sym,'r',114) and rows[selected] and rows[selected].kind~='action' then FS25E_VisualControls.restore(rows[selected].id)
    elseif key(sym,'return',13) and rows[selected] then
        local c=rows[selected]
        if c.kind=='action' then local ok,result,reason=pcall(c.run); message=ok and reason or 'FS25E_status_module_error'
        elseif c.kind~='enum' and c.kind~='bool' and FS25E_VisualControls.available(c) then edit={id=c.id,value=format(c,FS25E_VisualControls.read(c)),replace=true} end
    end
    return true
end
function UI.update(dt) end
function UI.registerHooks()
    if hooks then return true end
    if not FS25E_HookManager or not FSBaseMission then return false end
    local H=FS25E_HookManager
    if FSBaseMission.draw then H.register(FSBaseMission,'draw','appended',function() UI.draw() end) end
    if FSBaseMission.mouseEvent then H.register(FSBaseMission,'mouseEvent','overwritten',function(self,super,...) if not UI.mouseEvent(...) then return super(self,...) end end) end
    if FSBaseMission.mouseWheelEvent then H.register(FSBaseMission,'mouseWheelEvent','overwritten',function(self,super,d,...) if not UI.mouseWheel(d) then return super(self,d,...) end end) end
    if FSBaseMission.keyEvent then H.register(FSBaseMission,'keyEvent','overwritten',function(self,super,...) if not UI.keyEvent(...) then return super(self,...) end end) end
    hooks=true; return true
end
function UI.reset() UI.hide(); category=2; selected=1; scroll=0; rows={}; message=nil end
function UI.getLayout() return P,boxes end
