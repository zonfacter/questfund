local _, addon = ...
local preview
local maxWidth, maxHeight = 285, 190

local function build(anchor)
    local frame=CreateFrame("Frame","QuestfundKartenvorschau",UIParent)
    frame:SetPoint("TOPRIGHT",anchor,"BOTTOMRIGHT",0,-7)
    frame:SetSize(maxWidth+20,maxHeight+63)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    table.insert(UISpecialFrames,frame:GetName())
    local background=frame:CreateTexture(nil,"BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.07,0.10,0.12,0.97)

    frame.title=frame:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    frame.title:SetPoint("TOPLEFT",10,-10)
    frame.title:SetWidth(maxWidth-18)
    frame.title:SetJustifyH("LEFT")
    frame.title:SetMaxLines(1)
    frame.title:SetTextColor(0.54,0.89,0.74)
    local close=CreateFrame("Button",nil,frame)
    close:SetSize(22,24)
    close:SetPoint("TOPRIGHT",-5,-3)
    close:SetNormalFontObject(GameFontHighlight)
    close:SetText("×")
    close:SetScript("OnClick",function() frame:Hide() end)

    frame.canvas=CreateFrame("Frame",nil,frame)
    frame.canvas:SetPoint("TOP",0,-34)
    frame.tiles={}
    frame.finish=CreateFrame("Frame",nil,frame.canvas)
    frame.finish:SetSize(14,14)
    addon.DrawTurnInMarker(frame.finish,0.7)
    frame.player=frame.canvas:CreateTexture(nil,"OVERLAY")
    frame.player:SetSize(6,6)
    frame.player:SetColorTexture(0.90,0.96,1)
    frame.caption=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    frame.caption:SetPoint("BOTTOMLEFT",10,9)
    frame.caption:SetWidth(maxWidth)
    frame.caption:SetJustifyH("LEFT")
    frame.caption:SetMaxLines(1)
    frame:Hide()
    return frame
end

function addon.CloseTurnInPreview()
    if preview then preview:Hide() end
end

function addon.ToggleTurnInPreview(destination, anchor)
    preview=preview or build(anchor)
    if preview:IsShown() then preview:Hide(); return end

    local mapID=destination.point[1]
    local layers=C_Map and C_Map.GetMapArtLayers and C_Map.GetMapArtLayers(mapID)
    local layer=layers and layers[1]
    local art=layer and C_Map.GetMapArtLayerTextures and C_Map.GetMapArtLayerTextures(mapID,1)
    preview.title:SetText(destination.zone)
    preview.player:Hide()
    for _, texture in ipairs(preview.tiles) do texture:Hide() end
    preview.mapID=nil
    if not art or #art==0 or layer.layerWidth<=0 or layer.layerHeight<=0 or layer.tileWidth<=0 or layer.tileHeight<=0 then
        preview.canvas:Hide()
        preview:SetHeight(64)
        preview.caption:SetText("Kartenvorschau nicht verfügbar · "..destination.coords)
        preview:Show()
        return
    end

    local width,height=layer.layerWidth,layer.layerHeight
    local tw,th=layer.tileWidth,layer.tileHeight
    local scale=math.min(maxWidth/width,maxHeight/height)
    local columns,rows=math.ceil(width/tw),math.ceil(height/th)
    for i=1,math.min(#art,columns*rows) do
        local left,top=((i-1)%columns)*tw,math.floor((i-1)/columns)*th
        local tileWidth,tileHeight=math.min(tw,width-left),math.min(th,height-top)
        local texture=preview.tiles[i] or preview.canvas:CreateTexture(nil,"ARTWORK")
        preview.tiles[i]=texture
        texture:SetTexture(art[i])
        texture:ClearAllPoints()
        texture:SetPoint("TOPLEFT",left*scale,-top*scale)
        texture:SetSize(tileWidth*scale,tileHeight*scale)
        texture:SetTexCoord(0,tileWidth/tw,0,tileHeight/th)
        texture:Show()
    end
    preview.mapID,preview.width,preview.height=mapID,width*scale,height*scale
    preview.canvas:SetSize(preview.width,preview.height)
    preview.finish:ClearAllPoints()
    preview.finish:SetPoint("CENTER",preview.canvas,"TOPLEFT",destination.point[2]*preview.width/100,-destination.point[3]*preview.height/100)
    preview.canvas:Show()
    preview:SetHeight(preview.height+63)
    preview.caption:SetText(destination.finisher.." · "..destination.coords)
    preview:Show()
end

function addon.UpdateTurnInPreview(mapID,x,y)
    if not preview or not preview:IsShown() or not preview.mapID then return end
    local visible=mapID==preview.mapID and x and y
    preview.player:SetShown(not not visible)
    if visible then
        preview.player:ClearAllPoints()
        preview.player:SetPoint("CENTER",preview.canvas,"TOPLEFT",x*preview.width,-y*preview.height)
    end
end
