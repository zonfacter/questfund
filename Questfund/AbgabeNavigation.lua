local _, addon = ...
local destination, projection, zoneWidth, zoneHeight
local tracker, minimapPin
local headings={"Nord","Nordost","Ost","Südost","Süd","Südwest","West","Nordwest"}

local function number(value)
    return not (issecretvalue and issecretvalue(value)) and type(value)=="number" and math.abs(value)<math.huge
end

local function vectorXY(value)
    if (issecretvalue and issecretvalue(value)) or not value then return end
    if type(value)=="table" and canaccesstable and not canaccesstable(value) then return end
    local x,y=value:GetXY()
    if number(x) and number(y) then return x,y end
end

local function worldPosition(mapID, position)
    if not (C_Map and C_Map.GetWorldPosFromMapPos and position) then return end
    local ok,world,vector=pcall(C_Map.GetWorldPosFromMapPos,mapID,position)
    if not ok or not number(world) then return end
    local x,y=vectorXY(vector)
    if x then return world,x,y end
end

local function projectTarget(point)
    if not CreateVector2D then return end
    local mapID=point[1]
    local world,x,y=worldPosition(mapID,CreateVector2D(point[2]/100,point[3]/100))
    if not world then return end
    -- Derive map east and north from the map transform, independent of world-axis order.
    local origin,ox,oy=worldPosition(mapID,CreateVector2D(0,0))
    local east,ex,ey=worldPosition(mapID,CreateVector2D(1,0))
    local south,sx,sy=worldPosition(mapID,CreateVector2D(0,1))
    if origin~=world or east~=world or south~=world then return end
    ex,ey,sx,sy=ex-ox,ey-oy,ox-sx,oy-sy
    local ew,ns=math.sqrt(ex*ex+ey*ey),math.sqrt(sx*sx+sy*sy)
    if ew<=0 or ns<=0 then return end
    return {world=world,x=x,y=y,ex=ex/ew,ey=ey/ew,nx=sx/ns,ny=sy/ns}
end

local function playerPosition()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return end
    local mapID=C_Map.GetBestMapForUnit("player")
    if not number(mapID) or mapID<=0 then return end
    local position=C_Map.GetPlayerMapPosition(mapID,"player")
    local x,y=vectorXY(position)
    if not x then return end
    return mapID,x,y,position
end

local function offset(mapID,x,y,position)
    if mapID==destination.point[1] and zoneWidth then
        return (destination.point[2]/100-x)*zoneWidth,(y-destination.point[3]/100)*zoneHeight
    end
    if not mapID or not projection then return end
    local world,px,py=worldPosition(mapID,position)
    if not world then return end
    if world~=projection.world then return nil,nil,true end
    local dx,dy=projection.x-px,projection.y-py
    return dx*projection.ex+dy*projection.ey,dx*projection.nx+dy*projection.ny
end

local function stop()
    destination,projection=nil,nil
    tracker:Hide()
    if minimapPin then minimapPin:Hide() end
    addon.CloseTurnInPreview()
end

local function placeMinimapPin(east,north)
    if not minimapPin then return false end
    local radius=C_Minimap and C_Minimap.GetViewRadius and C_Minimap.GetViewRadius()
    if not number(radius) or radius<=0 then minimapPin:Hide(); return false end
    local cvar=GetCVarBool or (C_CVar and C_CVar.GetCVarBool)
    local rotates=cvar and cvar("rotateMinimap") and not (C_Minimap.IsRotateMinimapIgnored and C_Minimap.IsRotateMinimapIgnored())
    if rotates then
        local facing=GetPlayerFacing and GetPlayerFacing()
        if not number(facing) then minimapPin:Hide(); return false end
        local sine,cosine=math.sin(facing),math.cos(facing)
        east,north=east*cosine+north*sine,north*cosine-east*sine
    end
    local x,y=east/radius,north/radius
    local square=GetMinimapShape and GetMinimapShape()=="SQUARE"
    local magnitude=square and math.max(math.abs(x),math.abs(y)) or math.sqrt(x*x+y*y)
    local halfWidth,halfHeight=Minimap:GetWidth()/2,Minimap:GetHeight()/2
    local margin=1-9/math.max(10,math.min(halfWidth,halfHeight))
    local factor=magnitude>margin and margin/magnitude or 1
    minimapPin:ClearAllPoints()
    minimapPin:SetPoint("CENTER",Minimap,"CENTER",x*halfWidth*factor,y*halfHeight*factor)
    minimapPin:Show()
    return magnitude>1
end

local function update()
    if not destination then return end
    if not addon.CanTrackTurnIn(destination) then stop(); return end
    local mapID,x,y,position=playerPosition()
    addon.UpdateTurnInPreview(mapID,x,y)
    local east,north,remote=offset(mapID,x,y,position)
    if not east then
        if minimapPin then minimapPin:Hide() end
        tracker.info:SetText(remote and "Anderer Kartenbereich · "..destination.zone or "Entfernung gerade unbekannt")
        return
    end
    local distance=math.sqrt(east*east+north*north)
    local angle=math.atan2(east,north)
    local direction=headings[math.floor((angle/(math.pi/4))+0.5)%8+1]
    local edge=placeMinimapPin(east,north)
    local travel=distance<1 and "Am Zielpunkt" or ("%s · %d yd"):format(direction,math.floor(distance+0.5))
    tracker.info:SetText(travel..(edge and " · Kartenrand" or ""))
end

local function togglePreview()
    if destination then
        addon.ToggleTurnInPreview(destination,tracker)
        update()
    end
end

local function build()
    tracker=CreateFrame("Frame","QuestfundZielanzeige",UIParent)
    tracker:SetSize(236,47)
    if Minimap then tracker:SetPoint("TOPRIGHT",Minimap,"TOPLEFT",-12,-4)
    else tracker:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-20,-30) end
    tracker:SetFrameStrata("HIGH")
    tracker:SetClampedToScreen(true)

    local body=CreateFrame("Button",nil,tracker)
    body:SetAllPoints()
    local background=body:CreateTexture(nil,"BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.07,0.10,0.12,0.96)
    body:SetScript("OnClick",togglePreview)
    tracker.title=body:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    tracker.title:SetPoint("TOPLEFT",10,-8)
    tracker.title:SetWidth(196)
    tracker.title:SetJustifyH("LEFT")
    tracker.title:SetMaxLines(1)
    tracker.title:SetTextColor(0.54,0.89,0.74)
    tracker.info=body:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    tracker.info:SetPoint("TOPLEFT",10,-26)
    tracker.info:SetWidth(221)
    tracker.info:SetJustifyH("LEFT")
    tracker.info:SetMaxLines(1)

    local close=CreateFrame("Button",nil,tracker)
    close:SetSize(23,23)
    close:SetPoint("TOPRIGHT",-3,-2)
    close:SetNormalFontObject(GameFontHighlight)
    close:SetText("×")
    close:SetScript("OnClick",stop)

    if Minimap then
        minimapPin=CreateFrame("Button","QuestfundMinimapZiel",Minimap)
        minimapPin:SetSize(18,18)
        minimapPin:SetFrameLevel(Minimap:GetFrameLevel()+12)
        addon.DrawTurnInMarker(minimapPin,0.9)
        minimapPin:SetScript("OnClick",togglePreview)
        minimapPin:Hide()
    end
    for _, button in ipairs({body,minimapPin}) do
        button:SetScript("OnEnter",function(self)
            if destination then addon.ShowTurnInTooltip(self,destination,"Klick · Kartenvorschau") end
        end)
        button:SetScript("OnLeave",addon.HideTurnInTooltip)
        button:SetScript("OnHide",addon.HideTurnInTooltip)
    end

    local elapsed=0
    tracker:SetScript("OnUpdate",function(_,dt)
        elapsed=elapsed+dt
        if elapsed<0.15 then return end
        elapsed=0
        update()
    end)
end

function addon.TrackTurnIn(target)
    if not addon.CanTrackTurnIn(target) then return false end
    if not tracker then build() end
    addon.CloseTurnInPreview()
    destination=target
    projection=projectTarget(target.point)
    zoneWidth,zoneHeight=nil,nil
    if C_Map and C_Map.GetMapWorldSize then
        local ok,width,height=pcall(C_Map.GetMapWorldSize,target.point[1])
        if ok and number(width) and number(height) and width>0 and height>0 then zoneWidth,zoneHeight=width,height end
    end
    tracker.title:SetText(target.finisher)
    tracker:Show()
    update()
    return true
end
