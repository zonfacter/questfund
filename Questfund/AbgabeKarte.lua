local _, addon = ...
local template = "QuestfundAbgabePinTemplate"
local provider

function addon.DrawTurnInMarker(frame, scale)
    local accents={}
    for i, size in ipairs({20, 16, 11, 5}) do
        local texture = frame:CreateTexture(nil, "ARTWORK", nil, i)
        texture:SetSize(size*scale, size*scale)
        texture:SetPoint("CENTER")
        if i%2 == 0 then
            texture:SetColorTexture(0.54, 0.89, 0.74)
            accents[#accents+1]=texture
        else
            texture:SetColorTexture(0.07, 0.10, 0.12)
        end
    end
    return accents
end

local pin = {}

function pin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    self.accents=addon.DrawTurnInMarker(self,1)
end

function addon.ShowTurnInTooltip(owner, destination, hint)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText(destination.finisher)
    GameTooltip:AddLine(destination.quest, 1, 1, 1, true)
    GameTooltip:AddLine(destination.coords)
    if hint then GameTooltip:AddLine(hint,0.54,0.89,0.74) end
    GameTooltip:Show()
end

function addon.HideTurnInTooltip(owner)
    if GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
end

function pin:OnAcquired(destination, primary)
    self.destination = destination
    for _, texture in ipairs(self.accents) do texture:SetColorTexture(unpack(addon.questStageColors[destination.stage or 3])) end
    self:SetAlpha(primary and 1 or 0.8)
    self:SetPosition(destination.point[2]/100, destination.point[3]/100)
end

function pin:OnMouseEnter()
    if self.destination then addon.ShowTurnInTooltip(self,self.destination) end
end

function pin:OnMouseLeave()
    addon.HideTurnInTooltip(self)
end

function pin:OnReleased()
    self:OnMouseLeave()
    self.destination = nil
end

-- The base mixin is loaded with Blizzard's world map. The virtual frame
-- is only instantiated once that map acquires a Questfund pin.
QuestfundAbgabePinMixin = {}

function QuestfundAbgabePinMixin:Initialize()
    Mixin(self, MapCanvasPinMixin, pin)
    self:SetMouseClickEnabled(false)
    self:SetMouseMotionEnabled(true)
end

local mapData = {}

function mapData:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate(template)
end

function mapData:RefreshAllData()
    self:RemoveAllData()
    local map, destination = self:GetMap(), self.destination
    if not destination or not addon.CanTrackDestination(destination) then return end
    local mapID=map:GetMapID()
    if not mapID then return end
    local point=destination.point
    if destination.stage then
        local others=self.markers[mapID] or addon.QuestMapMarkers(destination.questID,destination.quest,mapID)
        self.markers[mapID]=others
        for _, marker in ipairs(others) do
            local other=marker.point
            if (mapID~=point[1] or other[2]~=point[2] or other[3]~=point[3]) and addon.CanTrackDestination(marker) then
                map:AcquirePin(template,marker,false)
            end
        end
    end
    if mapID==point[1] then map:AcquirePin(template,destination,true) end
end

function mapData:OnHide()
    local map, window = self:GetMap(), self.returnWindow
    self.destination, self.returnWindow, self.markers = nil, nil, nil
    self:RemoveAllData()
    if window then
        C_Timer.After(0, function()
            if not map:IsShown() then window:Show() end
        end)
    end
end

function addon.OpenTurnInMap(destination, window)
    if not addon.CanTrackDestination(destination) then return false end
    if not OpenWorldMap and C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_WorldMap") end
    if not OpenWorldMap or not MapCanvasDataProviderMixin then return false end

    local mapID = destination.point[1]
    OpenWorldMap(mapID)
    local map = WorldMapFrame
    if not map or not map:IsShown() or map:GetMapID() ~= mapID then return false end

    if not provider then
        provider = CreateFromMixins(MapCanvasDataProviderMixin, mapData)
        map:AddDataProvider(provider)
    end
    provider.destination, provider.returnWindow, provider.markers = destination, window, {}
    provider:RefreshAllData()
    map:PanTo(destination.point[2]/100, destination.point[3]/100)
    window:Hide()
    return true
end
