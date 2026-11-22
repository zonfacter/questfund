from pathlib import Path
import xml.etree.ElementTree as ET

from lupa.luajit21 import LuaRuntime


root = Path(__file__).resolve().parents[1] / "Questfund"
lua = LuaRuntime()
lua.execute(r"""
local frames={}
local methods={}
local noop=function() end
for key in ([[
    SetAllPoints SetColorTexture SetFontString SetWidth SetTextColor
    SetJustifyH SetNormalFontObject SetDisabledFontObject SetHighlightTexture SetFrameStrata
    SetClampedToScreen SetMovable EnableMouse RegisterForDrag SetFontObject SetTextInsets
    SetMaxLetters SetAutoFocus ClearFocus ClearAllPoints SetMaxLines SetTexture EnableMouseWheel SetScale
    SetMouseClickEnabled SetMouseMotionEnabled SetFrameLevel SetAlpha
]]):gmatch("%S+") do methods[key]=noop end
function CreateFrame(kind,name,parent)
    local frame=setmetatable({kind=kind,name=name,parent=parent,shown=true,enabled=true,events={},scripts={}}, {__index=methods})
    frames[#frames+1]=frame
    if name then _G[name]=frame end
    return frame
end
function methods:SetSize(w,h) self.width,self.height=w,h end
function methods:SetHeight(h) self.height=h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:GetFrameLevel() return 2 end
function methods:SetPoint(...) self.anchor={...} end
function methods:SetTexture(asset) self.asset=asset end
function methods:SetTexCoord(...) self.crop={...} end
function methods:GetName() return self.name end
function methods:CreateFontString() return CreateFrame("FontString",nil,self) end
function methods:CreateTexture() return CreateFrame("Texture",nil,self) end
function methods:GetFontString() return self end
function methods:SetText(text) self.text=text end
function methods:GetText() return self.text or "" end
function methods:SetScript(name,fn) self.scripts[name]=fn end
function methods:GetScript(name) return self.scripts[name] end
function methods:RegisterEvent(name) self.events[name]=true end
function methods:UnregisterEvent(name) self.events[name]=nil end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetShown(shown)
    if self.shown==shown then return end
    self.shown=shown
    local script=self.scripts[shown and "OnShow" or "OnHide"]
    if script then script(self) end
end
function methods:Show() self:SetShown(true) end
function methods:Hide() self:SetShown(false) end
function methods:SetEnabled(value) self.enabled=value end
function fire(name,...)
    for _, frame in ipairs(frames) do
        if frame.events[name] then frame.scripts.OnEvent(frame,name,...) end
    end
end
function tick()
    for _,frame in ipairs(frames) do
        if frame:IsVisible() and frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame,0.2) end
    end
end
function find(kind,text,parent)
    for _,f in ipairs(frames) do
        if f.kind==kind and f:IsVisible() and (not parent or f.parent==parent) and f:GetText():find(text,1,true) then return f end
    end
end
function click(text,parent)
    local f=assert(find("Button",text,parent),text)
    assert(f.enabled)
    f.scripts.OnClick(f)
end

local active={}
function setActive(...) active={...} end
function UnitRace() return "Volk","Race",raceID or 8 end
function UnitClass() return "Schamane","SHAMAN",7 end
function UnitFactionGroup() return faction or "Horde" end
function UnitLevel() return 25 end
function GetLocale() return "deDE" end
function item(id,name,count,flag,questID,isActive)
    return {itemID=id,itemName=name,stackCount=count,iconFileID=134400,
        quest={isQuestItem=flag,questID=questID,isActive=isActive}}
end
bags={
    [0]={item(14047,"Runenstoff",10),item(16305,"Queststart",1)},
    [1]={item(999999,"Neue Questbeute",1,true,98989),item(999998,"Unbekannte Questbeute",1,true)},
    [5]={item(14047,"Runenstoff",4)},
}
bank={
    [-1]={item(14047,"Runenstoff",6)},
    [-3]={item(14047,"Runenstoff",12)},
    [6]={item(14047,"Runenstoff",20)},
}
function slots(id)
    return bags[id] or (bankAvailable and bank[id]) or {}
end
C_Container={
    GetContainerNumSlots=function(id) return #slots(id) end,
    GetContainerItemInfo=function(id,slot) return slots(id)[slot] end,
    GetContainerItemQuestInfo=function(id,slot) return slots(id)[slot].quest end,
}
C_QuestLog={
    GetNumQuestLogEntries=function() return #active end,
    GetInfo=function(i) return {questID=active[i],isHeader=false,title=questTitles and questTitles[active[i]]} end,
    IsOnQuest=function(id) for _,i in ipairs(active) do if id==i then return true end end return false end,
    IsQuestFlaggedCompleted=function(id) return id==2 and doneStarter==true or false end,
    GetTitleForQuestID=function(id) if id==7837 then return "Zusätzlicher Runenstoff" end end,
    GetQuestObjectives=function(id) if id==7837 then return liveObjectives end end,
    GetNextWaypoint=function(id) if id==98765 then return 1454,0.25,0.5 end end,
}
function CreateVector2D(x,y) return {GetXY=function() return x,y end} end
playerMap,playerX,playerY=1454,0.35,0.88
C_Map={
    GetMapInfo=function(id)
        local names={[1454]="Orgrimmar",[1440]="Eschental",[1429]="Wald von Elwynn"}
        if names[id] then return {name=names[id]} end
    end,
    GetBestMapForUnit=function() return playerMap end,
    GetPlayerMapPosition=function() return CreateVector2D(playerX,playerY) end,
    GetMapWorldSize=function() return 1000,2000 end,
    GetWorldPosFromMapPos=function(id,pos)
        local x,y=pos:GetXY()
        return id==1457 and 2 or 1,CreateVector2D(-y*2000,-x*1000)
    end,
    GetMapArtLayers=function(id)
        if id==1454 then return {{layerWidth=500,layerHeight=256,tileWidth=256,tileHeight=256}} end
    end,
    GetMapArtLayerTextures=function() return {101,102} end,
}
C_Minimap={GetViewRadius=function() return 100 end}
function GetCVarBool() return rotating end
function GetPlayerFacing() return math.pi/2 end
Enum={BagIndex={Bank=-1,Reagentbag=5,ReagentBag=5,Reagentbank=-3,BankBag_1=6}}
UIParent=CreateFrame("Frame")
UIParent.GetWidth=function() return 1400 end
UIParent.GetHeight=function() return 900 end
Minimap=CreateFrame("Frame","Minimap",UIParent)
Minimap:SetSize(160,160)
UISpecialFrames,SlashCmdList={},{}
GameTooltip={
    IsOwned=function(self,owner) return self.owner==owner end,
    SetOwner=function(self,owner) self.owner=owner; self.lines={} end,
    SetText=function(self,title) self.title=title end,
    AddLine=function(self,line) self.lines[#self.lines+1]=line end,
    Show=noop, Hide=function(self) self.owner=nil end,
}
function Mixin(object,...)
    for i=1,select("#",...) do
        for key,value in pairs(select(i,...)) do object[key]=value end
    end
    return object
end
function CreateFromMixins(...) return Mixin({},...) end
local function loadWorldMap()
    MapCanvasPinMixin={
        UseFrameLevelType=noop,
        SetPosition=function(self,x,y) self.x,self.y=x,y end,
    }
    MapCanvasDataProviderMixin={
        OnAdded=function(self,map) self.map=map end,
        GetMap=function(self) return self.map end,
        OnMapChanged=function(self) self:RefreshAllData() end,
    }
    local map=CreateFrame("Frame","WorldMapFrame")
    map.pinPool,map.activePins={},{}
    map:Hide()
    function map:AddDataProvider(provider)
        assert(not self.provider)
        self.provider=provider
        provider:OnAdded(self)
    end
    function map:GetMapID() return self.mapID end
    function map:SetMapID(id)
        self.mapID=id
        if self.provider then self.provider:OnMapChanged() end
    end
    function map:AcquirePin(template,...)
        assert(template==testPinTemplate)
        local index=#self.activePins+1
        local pin=self.pinPool[index]
        if not pin then
            pin=CreateFrame("Frame",nil,self)
            self.pinPool[index]=pin
            Mixin(pin,_G[testPinMixin])
            pin[testPinInit](pin)
            pin:OnLoad()
        end
        self.activePin=pin
        self.activePins[index]=pin
        pin:OnAcquired(...)
        return pin
    end
    function map:RemoveAllPinsByTemplate(template)
        assert(template==testPinTemplate)
        for _,pin in ipairs(self.activePins) do pin:OnReleased() end
        self.activePins,self.activePin={},nil
    end
    function map:PanTo(x,y) self.panX,self.panY=x,y end
    map:SetScript("OnHide",function(self) if self.provider then self.provider:OnHide() end end)
    WorldMapFrame=map
    function OpenWorldMap(id)
        if blockedMap then return end
        map:Show()
        map:SetMapID(id)
    end
end
C_AddOns={LoadAddOn=function(name) assert(name=="Blizzard_WorldMap"); loadWorldMap() end}
UIErrorsFrame={AddMessage=function(self,message) self.message=message end}
local broker={NewDataObject=function(_,_,object) launcher=object end}
LibStub={GetLibrary=function() return broker end}
C_Timer={After=function(_,fn) fn() end}
function time() return clock or 100 end
function date() return "Testzeit" end
addon={}
""")
load = lua.eval('function(source,file) assert(loadstring(source,"@"..file))("Questfund",addon) end')
for file in (root / "Questfund.toc").read_text(encoding="utf-8").splitlines():
    if file.endswith(".lua"):
        load((root / file).read_text(encoding="utf-8"), file)
    if file.endswith(".xml"):
        ui = {"ui": "http://www.blizzard.com/wow/ui/"}
        frame = ET.parse(root / file).find("ui:Frame", ui)
        assert frame.attrib["virtual"] == "true"
        lua.globals().testPinTemplate = frame.attrib["name"]
        lua.globals().testPinMixin = frame.attrib["mixin"]
        lua.globals().testPinInit = frame.find("ui:Scripts/ui:OnLoad", ui).attrib["method"]

lua.execute(r"""
fire("ADDON_LOADED","Questfund")
local function byID(id)
    for _,found in ipairs(addon.Inventory()) do if found.id==id then return found end end
end
local cloth=assert(byID(14047))
assert(cloth.status=="repeatable" and cloth.bags==14 and cloth.bank==0)
assert(cloth.quests[7837] and not cloth.quests[7802]) -- Troll sees Horde repeatable turn-ins
assert(#addon.TurnInTargets(7837)==1 and #addon.TurnInTargets(7801)==0)
assert(addon.turnIns[8518].side==3 and #addon.TurnInTargets(8518)==0)
assert(addon.turnIns[8543].side==3 and #addon.TurnInTargets(8543)==1)
assert(#addon.TurnInTargets(5508)==1) -- neutral Argent Dawn finisher
assert(addon.TurnInAmount(cloth,7837)==20)
assert(addon.turnIns[5402].targets[1][5]=="Argentumoffizier Pureheart")
assert(addon.turnIns[8242].amounts[4234]==10 and addon.turnIns[8242].amounts[18944]==2)
assert(addon.turnIns[9178].amounts[12643]==120 and addon.turnIns[9178].amounts[22600]==1)
for _, turn in pairs(addon.turnIns) do assert(next(turn.amounts)) end
assert(byID(16305).status=="starter")
doneStarter=true
assert(byID(16305).status=="inactive")
assert(byID(999999).status=="inactive" and byID(999998).status=="unknown")
setActive(98989,7837)
assert(byID(999999).status=="active" and byID(14047).status=="active" and #byID(14047).repeats>0)
liveObjectives={{type="item",numRequired=22}}
local amount, observed=addon.TurnInAmount(byID(14047),7837)
assert(amount==22 and observed)
liveObjectives[2]={type="item",numRequired=5}
assert(addon.TurnInAmount(byID(14047),7837)==20)
liveObjectives=nil
setActive()

launcher.OnClick()
click("Wiederholbar")
local panel=assert(find("FontString","Abgabe 1 / ")).parent
for _=1,#cloth.repeats do
    if find("FontString","NPC · Vehena") then break end
    click("›",panel)
end
assert(find("FontString","Orgrimmar") and find("Button","37,7 / 87,9 · Karte öffnen"))
assert(find("FontString","Benötigt pro Abgabe · 20"))
assert(find("FontString","14 Tasche · ? Bank"))
assert(find("FontString","In Taschen fehlen 6 · Bank unbekannt"))

blockedMap=true
click("37,7 / 87,9 · Karte öffnen",panel)
assert(not WorldMapFrame:IsShown() and UIErrorsFrame.message and panel:IsVisible())
blockedMap=false
click("37,7 / 87,9 · Karte öffnen",panel)
local map=WorldMapFrame
assert(map:IsShown() and map:GetMapID()==1454 and not panel:IsVisible())
local pin=assert(map.activePin)
assert(math.abs(pin.x-0.377)<1e-9 and math.abs(pin.y-0.879)<1e-9)
assert(map.panX==pin.x and map.panY==pin.y)
pin:OnMouseEnter()
assert(GameTooltip.title=="NPC · Vehena" and GameTooltip.lines[1]=="Zusätzlicher Runenstoff")
map:SetMapID(1422)
assert(not map.activePin and not GameTooltip:IsOwned(pin))
map:SetMapID(1454)
assert(map.activePin==pin)
map:Hide()
assert(not map.activePin and panel:IsVisible() and find("Button","37,7 / 87,9 · Karte öffnen"))
assert(QuestfundZielanzeige:IsShown() and QuestfundMinimapZiel:IsShown())
assert(find("FontString","Ost · 27 yd"))
assert(math.abs(QuestfundMinimapZiel.anchor[4]-21.6)<1e-9)
rotating=true
tick()
assert(math.abs(QuestfundMinimapZiel.anchor[5]+21.6)<1e-9)
rotating=false
playerX,playerY=0.05,0.879
tick()
assert(find("FontString","Ost · 327 yd · Kartenrand"))
assert(math.abs(QuestfundMinimapZiel.anchor[4]-71)<1e-9)
QuestfundMinimapZiel.scripts.OnClick(QuestfundMinimapZiel)
local preview=QuestfundKartenvorschau
assert(preview:IsShown() and preview.mapID==1454 and preview.player:IsShown())
assert(#preview.tiles==2 and preview.tiles[2].asset==102 and preview.tiles[2].crop[2]==244/256)
assert(math.abs(preview.finish.anchor[4]-0.377*preview.width)<1e-9)
playerMap,playerX=1411,0.30
tick()
assert(QuestfundMinimapZiel:IsShown() and find("FontString","Ost · 77 yd") and not preview.player:IsShown())
playerMap=1457
tick()
assert(not QuestfundMinimapZiel:IsShown() and find("FontString","Anderer Kartenbereich · Orgrimmar"))
assert(preview:IsShown())
playerMap=1454
click("Stopp",QuestfundZielanzeige)
assert(not preview:IsShown() and not QuestfundMinimapZiel:IsShown() and not QuestfundZielanzeige:IsShown())
click("Verfolgen",panel)
assert(QuestfundZielanzeige:IsShown() and not panel:IsVisible() and not map:IsShown())
launcher.OnClick()
assert(panel:IsVisible())
local target=addon.turnIns[7837].targets[1]
local points=target[4]
target[4]={}
fire("QUEST_LOG_UPDATE")
assert(find("FontString","Ort unbekannt") and not find("Button","Karte öffnen") and not find("Button","Verfolgen"))
target[4]=points
fire("QUEST_LOG_UPDATE")

bankAvailable=true
fire("BANKFRAME_OPENED")
assert(byID(14047).bank==38 and addon.Place(5)=="Reagenzientasche" and addon.Place(6)=="Banktasche 1")
assert(find("FontString","Bank · Live") and find("FontString","Fehlen 0 · 6 aus Bank holen"))
bank[-1][1].stackCount=1
bank[-3][1].stackCount=1
bank[6][1]=nil
fire("BAG_UPDATE_DELAYED")
assert(find("FontString","Fehlen 4 · 2 aus Bank holen"))
bank[-1][1].stackCount=6
bank[-3][1].stackCount=12
clock=120
fire("BAG_UPDATE",6)
assert(byID(14047).bank==18)
bankAvailable=false
fire("BANKFRAME_CLOSED")
local _,live,stamp=addon.Inventory()
assert(not live and stamp==120 and byID(14047).bank==18)
fire("BANKFRAME_OPENED") -- unavailable bank must not look live or erase the old scan
assert(select(2,addon.Inventory())==false and byID(14047).bank==18)
fire("BANKFRAME_CLOSED")

assert(find("FontString","Bank · Testzeit"))
assert(find("FontString","Runenstoff") and find("FontString","14 Tasche · 18 Bank"))
assert(find("FontString","Fehlen 0 · 6 aus Bank holen (Bankstand)"))
click("Ohne aktive Quest")
assert(find("FontString","Neue Questbeute") and not find("FontString","Runenstoff"))
setActive(98989)
fire("QUEST_LOG_UPDATE")
assert(not find("FontString","Neue Questbeute"))
click("Aktiv")
assert(find("FontString","Neue Questbeute"))

bags[1][3]=item(1251,"Leinenverband",20)
bags[1][4]=item(3576,"Zinnbarren",20)
assert(not (byID(1251) and byID(1251).quests[8518]))
assert(byID(3576).quests[8543])
faction,raceID="Alliance",1
tick()
assert(not QuestfundZielanzeige:IsShown() and not QuestfundMinimapZiel:IsShown())
assert(byID(14047).quests[7801] and not byID(14047).quests[7837])
assert(byID(1251).quests[8518] and not (byID(3576) and byID(3576).quests[8543]))
assert(#addon.TurnInTargets(5508)==1)
assert(not addon.TrackTurnIn({questID=7837,target=target,point=points[1]}))

questTitles={[25]="Unruhe im Eschental",[7]="Koboldlager säubern",[98765]="Neue Quest"}
faction,raceID="Horde",8
setActive(25,7) -- questlog view is independent of items and still filters the opposite faction
fire("QUEST_LOG_UPDATE")
click("Questlog")
assert(find("FontString","Unruhe im Eschental") and not find("FontString","Koboldlager säubern"))
local questPanel=assert(find("FontString","Quest 1 / 1")).parent
local goals=addon.QuestStagePlaces(25,2)
local explored=false
for _,goal in ipairs(goals) do if goal.target[1]==4 and goal.point then explored=true end end
assert(explored and #goals>1)
assert(#addon.QuestStagePlaces(25,1)>0 and #addon.QuestStagePlaces(25,3)>0)
click("Karte öffnen",questPanel)
assert(map:IsShown() and not questPanel:IsVisible() and QuestfundZielanzeige:IsShown())
local stages={}
for _,pin in ipairs(map.activePins) do stages[pin.destination.stage]=true end
assert(stages[1] and stages[2] and stages[3] and map.activePin.destination.stage==2)
map:Hide()
assert(questPanel:IsVisible() and QuestfundZielanzeige:IsShown())
local stopButton=assert(find("Button","Stopp",QuestfundZielanzeige))
assert(stopButton.width>=60 and stopButton.height>=40)
assert(QuestfundZielanzeige.title.parent.width+stopButton.width<=QuestfundZielanzeige.width)
click("Stopp",QuestfundZielanzeige)
assert(not QuestfundZielanzeige:IsShown() and not preview:IsShown())
click("Questgeber",questPanel)
assert(find("FontString","Questgeber · "))
click("Abgabe",questPanel)
assert(find("FontString","Abgabe · "))
click("Verfolgen",questPanel)
assert(QuestfundZielanzeige:IsShown() and not map:IsShown())
SlashCmdList.QUESTFUND("stop")
assert(not QuestfundZielanzeige:IsShown())
launcher.OnClick()

faction,raceID="Alliance",1
fire("QUEST_LOG_UPDATE")
assert(find("FontString","Koboldlager säubern") and not find("FontString","Unruhe im Eschental"))
assert(addon.QuestStagePlaces(7,2)[1].target[2]==6)
local head=addon.QuestStagePlaces(6,2)[1]
assert(head.sourceItem==182 and head.target[2]==103 and head.point)
assert(not addon.TrackTurnIn(addon.Destination(goals[1],25,"Unruhe im Eschental")))
setActive(98765)
fire("QUEST_LOG_UPDATE")
assert(find("FontString","Quest-Wegpunkt aus dem Questlog") and find("Button","25,0 / 50,0 · Karte öffnen"))

setActive()
faction,raceID="Horde",8
doneStarter=false
click("Queststart")
assert(find("FontString","Queststart") and find("FontString","Questgeber · "))
assert(addon.QuestStagePlaces(2,1)[1].sourceItem==16305)
""")
print("PASS: inventory, faction filtering, quest log, quest locations, world map, minimap navigation and Stopp.")
