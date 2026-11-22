local name, addon = ...
local color = {
    window={0.068,0.091,0.105,1}, panel={0.095,0.132,0.149,1}, row={0.114,0.154,0.172,1},
    selected={0.16,0.34,0.29,1}, mint={0.54,0.89,0.74,1}, amber={0.98,0.76,0.46,1},
    text={0.93,0.96,0.95,1}, muted={0.70,0.77,0.79,1},
}
local categories = {
    {"all","Alle Funde"}, {"inactive","Ohne aktive Quest"}, {"repeatable","Wiederholbar"},
    {"starter","Queststart"}, {"active","Aktiv"}, {"unknown","Unklar"},
}
local status = {
    inactive={"Ohne aktive Quest",color.amber}, repeatable={"Wiederholbare Abgabe",color.mint},
    starter={"Startet eine Quest",color.mint}, active={"Aktive Quest",color.text},
    unknown={"Questbezug unklar",color.amber},
}
local window, refresh
local width, height = 834, 568
local german = GetLocale() == "deDE"
local asked = {}

local function fill(parent, rgba, x, y, w, h)
    local t=parent:CreateTexture(nil,"BACKGROUND")
    if w then t:SetPoint("TOPLEFT",x,-y); t:SetSize(w,h) else t:SetAllPoints() end
    t:SetColorTexture(unpack(rgba))
    return t
end

local function label(parent,x,y,w,text,font,rgba)
    local s=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall")
    s:SetPoint("TOPLEFT",x,-y)
    s:SetWidth(w)
    s:SetJustifyH("LEFT")
    s:SetTextColor(unpack(rgba or color.text))
    s:SetText(text)
    return s
end

local function button(parent,x,y,w,h,text,click)
    local b=CreateFrame("Button",nil,parent)
    b:SetPoint("TOPLEFT",x,-y)
    b:SetSize(w,h)
    b:SetNormalFontObject(GameFontHighlightSmall)
    b:SetDisabledFontObject(GameFontDisableSmall)
    b:SetFontString(b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"))
    b:GetFontString():SetAllPoints()
    b:SetText(text)
    b.bg=fill(b,color.row)
    local hover=b:CreateTexture(nil,"HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(0.54,0.89,0.74,0.15)
    b:SetHighlightTexture(hover)
    b:SetScript("OnClick",click)
    return b
end

local function questTitle(id)
    local title=C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)
    if type(title)=="string" and not (issecretvalue and issecretvalue(title)) and title~="" then return title end
    if not asked[id] and C_QuestLog.RequestLoadQuestByID then
        asked[id]=true
        C_QuestLog.RequestLoadQuestByID(id)
    end
    return "Quest #"..id
end

local function stockStatus(needed, bags, bank, bankStamp, bankLive)
    local missingInBags = math.max(0,needed-bags)
    if missingInBags == 0 then return "Fehlen 0 · genug in den Taschen",color.mint end
    if not bankStamp then return ("In Taschen fehlen %d · Bank unbekannt"):format(missingInBags),color.amber end
    local retrieve = math.min(bank,missingInBags)
    local missing = ("Fehlen %d"):format(missingInBags-retrieve)
    if retrieve > 0 then missing=missing..(" · %d aus Bank holen"):format(retrieve) end
    if not bankLive then missing=missing.." (Bankstand)" end
    return missing,retrieve == missingInBags and color.mint or color.amber
end

local function build()
    local f=CreateFrame("Frame","QuestfundFenster",UIParent)
    f:SetSize(width,height)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:Hide()
    fill(f,color.window)
    fill(f,color.mint,0,0,width,2)
    table.insert(UISpecialFrames,f:GetName())
    local grip=CreateFrame("Frame",nil,f)
    grip:SetPoint("TOPLEFT",0,-4)
    grip:SetSize(710,47)
    grip:EnableMouse(true)
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart",function() f:StartMoving() end)
    grip:SetScript("OnDragStop",function() f:StopMovingOrSizing() end)
    label(grip,16,9,330,"Questfund","GameFontNormalLarge")
    label(grip,16,32,480,"Questgegenstände in Taschen und Bank",nil,color.muted)
    local bankStatus=label(f,540,19,240,"",nil,color.muted)
    bankStatus:SetJustifyH("RIGHT")
    button(f,789,11,29,26,"×",function() f:Hide() end)

    local filter, page, selected = "all", 1
    local filters, rows = {}, {}
    local x=16
    local widths={101,150,118,112,87,99}
    for i, entry in ipairs(categories) do
        local key=entry[1]
        filters[i]=button(f,x,61,widths[i],27,entry[2],function()
            filter,page,selected=key,1,nil
            refresh()
        end)
        x=x+widths[i]+7
    end
    local search=CreateFrame("EditBox",nil,f)
    search:SetPoint("TOPLEFT",16,-102)
    search:SetSize(496,27)
    search:SetFontObject(GameFontHighlightSmall)
    search:SetTextInsets(8,8,0,0)
    search:SetMaxLetters(60)
    search:SetAutoFocus(false)
    fill(search,color.panel)
    local hint=label(search,8,7,460,"Gegenstand oder Item-ID suchen",nil,color.muted)
    search:SetScript("OnEscapePressed",search.ClearFocus)
    search:SetScript("OnEnterPressed",search.ClearFocus)
    search:SetScript("OnTextChanged",function(self)
        hint:SetShown(self:GetText()=="")
        page,selected=1,nil
        if f:IsShown() then refresh() end
    end)

    local empty=label(f,16,149,490,"", "GameFontHighlight", color.muted)
    for i=1,8 do
        local r=button(f,16,142+(i-1)*38,496,35,"",function(self)
            selected=self.entry.id
            refresh()
        end)
        r.icon=r:CreateTexture(nil,"ARTWORK")
        r.icon:SetPoint("LEFT",7,0)
        r.icon:SetSize(23,23)
        r.title=label(r,39,4,307,"")
        r.title:SetMaxLines(1)
        r.status=label(r,39,19,310,"",nil,color.muted)
        r.count=label(r,343,12,146,"",nil,color.muted)
        r.count:SetJustifyH("RIGHT")
        r:SetScript("OnEnter",function(self)
            if self.entry and self.entry.link then
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.entry.link)
                GameTooltip:Show()
            end
        end)
        r:SetScript("OnLeave",function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
        r:SetScript("OnHide",r:GetScript("OnLeave"))
        rows[i]=r
    end
    local prev=button(f,16,458,37,24,"‹",function() page=page-1; refresh() end)
    local nextPage=button(f,475,458,37,24,"›",function() page=page+1; refresh() end)
    local count=label(f,59,463,406,"",nil,color.muted)
    count:SetJustifyH("CENTER")
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel",function(_,delta) page=page+(delta<0 and 1 or -1); refresh() end)

    fill(f,color.panel,524,102,294,430)
    local detailTitle=label(f,537,115,267,"","GameFontNormalLarge")
    detailTitle:SetMaxLines(2)
    local detailStatus=label(f,537,156,267,"","GameFontHighlight",color.mint)
    local detailQuests=label(f,537,185,267,"",nil,color.text)
    detailQuests:SetMaxLines(10)
    local detailPlaces=label(f,537,354,267,"",nil,color.muted)
    detailPlaces:SetMaxLines(8)
    label(f,16,544,802,"„Ohne aktive Quest“ beschreibt dein Questlog. Der Gegenstand kann später noch gebraucht werden.",nil,color.muted)

    local turnInPanel=CreateFrame("Frame",nil,f)
    turnInPanel:SetPoint("TOPLEFT",537,-179)
    turnInPanel:SetSize(267,230)
    local turnIndex, placeIndex, detailItem = 1, 1
    local previousTurn=button(turnInPanel,0,0,28,21,"‹",function() turnIndex=turnIndex-1; placeIndex=1; refresh() end)
    local nextTurn=button(turnInPanel,239,0,28,21,"›",function() turnIndex=turnIndex+1; placeIndex=1; refresh() end)
    local turnCount=label(turnInPanel,33,4,201,"",nil,color.muted)
    turnCount:SetJustifyH("CENTER")
    local title=label(turnInPanel,0,27,267,"","GameFontHighlight",color.mint)
    title:SetMaxLines(2)
    local finisher=label(turnInPanel,0,63,267,"")
    finisher:SetMaxLines(2)
    local location=label(turnInPanel,0,92,211,"",nil,color.muted)
    location:SetMaxLines(1)
    local mapButton=button(turnInPanel,0,108,180,21,"",function(self)
        if not self.destination then return end
        if addon.OpenTurnInMap(self.destination,f) then
            addon.TrackTurnIn(self.destination)
        elseif UIErrorsFrame then
            UIErrorsFrame:AddMessage("Questfund: Weltkarte gerade nicht verfügbar.",1,0.4,0.4)
        end
    end)
    mapButton:GetFontString():SetTextColor(unpack(color.mint))
    local trackButton=button(turnInPanel,187,108,80,21,"Verfolgen",function(self)
        if self.destination and addon.TrackTurnIn(self.destination) then f:Hide() end
    end)
    local previousPlace=button(turnInPanel,211,92,25,22,"‹",function() placeIndex=placeIndex-1; refresh() end)
    local nextPlace=button(turnInPanel,242,92,25,22,"›",function() placeIndex=placeIndex+1; refresh() end)
    local requirement=label(turnInPanel,0,133,267,"","GameFontHighlight")
    local stock=label(turnInPanel,0,154,267,"",nil,color.muted)
    local missing=label(turnInPanel,0,173,267,"")
    missing:SetMaxLines(2)
    local materials=button(turnInPanel,0,203,182,22,"Weitere Materialien",nil)
    local extraMaterials
    materials:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:AddLine("Weitere Materialien für diese Abgabe")
        for _, line in ipairs(extraMaterials or {}) do GameTooltip:AddLine(line,1,1,1,true) end
        GameTooltip:Show()
    end)
    materials:SetScript("OnLeave",function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    materials:SetScript("OnHide",materials:GetScript("OnLeave"))

    local function turnInDetails(entry, entriesByID, bankLive, bankStamp)
        turnIndex=math.min(math.max(1,turnIndex),#entry.repeats)
        local id=entry.repeats[turnIndex]
        local turn=addon.turnIns[id]
        local meta=addon.questMeta[id]
        local level=meta and meta[1]>0 and (" · Ab Stufe %d"):format(meta[1]) or ""
        turnCount:SetText(("Abgabe %d / %d%s"):format(turnIndex,#entry.repeats,level))
        previousTurn:SetEnabled(turnIndex>1)
        nextTurn:SetEnabled(turnIndex<#entry.repeats)
        previousTurn:SetShown(#entry.repeats>1)
        nextTurn:SetShown(#entry.repeats>1)
        local quest=questTitle(id)
        title:SetText(quest)

        local places={}
        for _, target in ipairs(addon.TurnInTargets(id)) do
            for _, point in ipairs(target[4]) do places[#places+1]={target,point} end
            if #target[4]==0 then places[#places+1]={target} end
        end
        placeIndex=math.min(math.max(1,placeIndex),math.max(1,#places))
        previousPlace:SetShown(#places>1)
        nextPlace:SetShown(#places>1)
        previousPlace:SetEnabled(placeIndex>1)
        nextPlace:SetEnabled(placeIndex<#places)
        location:SetWidth(#places>1 and 204 or 267)
        local place=places[placeIndex]
        local destination
        if place then
            local target, point=unpack(place)
            local kind=target[1]==1 and "NPC" or "Objekt"
            local targetName=german and target[5] or target[3]
            local npc=kind.." · "..(targetName~="" and targetName or "#"..target[2])
            finisher:SetText(npc)
            local where="Ort unbekannt"
            if point then
                local map=C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(point[1])
                local coords=("%.1f / %.1f"):format(point[2],point[3]):gsub("%.",",")
                where=map and map.name or "Karte #"..point[1]
                destination={point=point,target=target,questID=id,finisher=npc,quest=quest,coords=coords,zone=where}
            end
            if #places>1 then where=where..(" · %d / %d"):format(placeIndex,#places) end
            location:SetText(where)
        else
            finisher:SetText("Abgabestelle unbekannt")
            location:SetText("")
        end
        mapButton.destination=destination
        trackButton.destination=destination
        mapButton:SetShown(destination~=nil)
        trackButton:SetShown(destination~=nil)
        if destination then mapButton:SetText(destination.coords.." · Karte öffnen") end

        local amount, liveAmount=addon.TurnInAmount(entry,id)
        requirement:SetText(amount and ("Benötigt pro Abgabe · %d"):format(amount) or "Benötigte Menge unbekannt")
        local bank=bankStamp and tostring(entry.bank) or "?"
        local source=amount and (liveAmount and " · Questlog" or " · Classic-Referenz") or ""
        stock:SetText(("Taschen %d · Bank %s%s"):format(entry.bags,bank,source))
        local message, rgba="",color.muted
        if amount then message,rgba=stockStatus(amount,entry.bags,entry.bank,bankStamp,bankLive) end
        missing:SetText(message)
        missing:SetTextColor(unpack(rgba))

        extraMaterials={}
        local otherIDs={}
        for item in pairs(turn.amounts) do if item~=entry.id then otherIDs[#otherIDs+1]=item end end
        table.sort(otherIDs)
        for _, item in ipairs(otherIDs) do
            local other=entriesByID[item]
            local itemName=other and other.name or C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(item)
            local needed=turn.amounts[item]
            local rest=stockStatus(needed,other and other.bags or 0,other and other.bank or 0,bankStamp,bankLive)
            extraMaterials[#extraMaterials+1]=(itemName or ("Gegenstand #"..item))..(" · %d benötigt\n%s"):format(needed,rest)
        end
        materials:SetShown(#extraMaterials>0)
        if #extraMaterials>0 then materials:SetText(("Weitere Materialien (%d)"):format(#extraMaterials)) end
    end

    local function details(entry, entriesByID, bankLive, bankStamp)
        local itemID=entry and entry.id
        if itemID~=detailItem then detailItem,turnIndex,placeIndex=itemID,1,1 end
        local repeated=entry and #entry.repeats>0 or false
        detailTitle:SetText(entry and entry.name or "Gegenstand prüfen")
        detailStatus:SetText(entry and status[entry.status][1] or "")
        detailStatus:SetTextColor(unpack(entry and status[entry.status][2] or color.muted))
        turnInPanel:SetShown(repeated)
        detailQuests:SetShown(not repeated)
        detailPlaces:ClearAllPoints()
        detailPlaces:SetPoint("TOPLEFT",537,repeated and -424 or -354)
        if not entry then detailQuests:SetText(""); detailPlaces:SetText(""); return end
        local questIDs, parts = {}, {}
        if repeated then
            turnInDetails(entry,entriesByID,bankLive,bankStamp)
        else
            for id in pairs(entry.quests) do questIDs[#questIDs+1]=id end
            table.sort(questIDs)
            if #questIDs > 0 then
                parts[1]="Zugeordnete Quests"
                for i=1,math.min(4,#questIDs) do
                    local id=questIDs[i]
                    local meta=addon.questMeta[id]
                    parts[#parts+1]=(meta and meta[1]>0 and ("Stufe %d · "):format(meta[1]) or "")..questTitle(id)
                end
                if #questIDs>4 then parts[#parts+1]=("Weitere: %d"):format(#questIDs-4) end
            else
                parts[1]="Für diesen Gegenstand fehlt eine verlässliche Questzuordnung."
            end
            detailQuests:SetText(table.concat(parts,"\n"))
        end
        local locations={"Fundorte"}
        for i=1,math.min(6,#entry.places) do
            local p=entry.places[i]
            locations[#locations+1]=("%s · Platz %d · %d×"):format(addon.Place(p.bag),p.slot,p.count)
        end
        if #entry.places>6 then locations[#locations+1]=("Weitere Plätze: %d"):format(#entry.places-6) end
        detailPlaces:SetText(table.concat(locations,"\n"))
    end

    function refresh()
        local entries, open, last = addon.Inventory()
        bankStatus:SetText(open and last and "Bank · Live" or last and ("Bank · "..date("%d.%m. %H:%M",last)) or "Bank öffnen zum Einlesen")
        local q=(search:GetText() or ""):lower()
        local found, entriesByID={},{}
        for _, entry in ipairs(entries) do
            entriesByID[entry.id]=entry
            if (filter=="all" or entry.status==filter or filter=="repeatable" and #entry.repeats>0) and
                (q=="" or entry.name:lower():find(q,1,true) or tostring(entry.id)==q) then found[#found+1]=entry end
        end
        local pages=math.max(1,math.ceil(#found/#rows))
        page=math.min(math.max(page,1),pages)
        local first=(page-1)*#rows
        local current
        for i,r in ipairs(rows) do
            local entry=found[first+i]
            r.entry=entry
            r:SetShown(entry~=nil)
            if entry and entry.id==selected then current=entry end
        end
        current=current or found[first+1]
        selected=current and current.id
        for _,r in ipairs(rows) do
            local entry=r.entry
            if entry then
                r.bg:SetColorTexture(unpack(entry==current and color.selected or color.row))
                r.icon:SetTexture(entry.icon or 134400)
                r.title:SetText(entry.name)
                r.status:SetText(status[entry.status][1])
                r.status:SetTextColor(unpack(status[entry.status][2]))
                r.count:SetText(("%d Tasche · %s Bank"):format(entry.bags,last and tostring(entry.bank) or "?"))
            end
        end
        for i,b in ipairs(filters) do b.bg:SetColorTexture(unpack(categories[i][1]==filter and color.selected or color.row)) end
        prev:SetEnabled(page>1)
        nextPage:SetEnabled(page<pages)
        count:SetText(("%d Funde · %d / %d"):format(#found,page,pages))
        empty:SetText(#found==0 and "Keine passenden Gegenstände gefunden." or "")
        details(current,entriesByID,open,last)
    end
    f:SetScript("OnShow",function()
        f:SetScale(math.min(1,UIParent:GetWidth()/(width+20),UIParent:GetHeight()/(height+20)))
        refresh()
    end)
    f:SetScript("OnHide",function() search:ClearFocus() end)
    return f
end

local pending
function addon.InventoryChanged()
    if not window or not window:IsShown() or pending then return end
    pending=true
    C_Timer.After(0,function()
        pending=false
        if window:IsShown() then refresh() end
    end)
end

local function toggle()
    window=window or build()
    window:SetShown(not window:IsShown())
end

SLASH_QUESTFUND1="/questfund"
SlashCmdList.QUESTFUND=toggle

local broker=LibStub and LibStub:GetLibrary("LibDataBroker-1.1",true)
if broker then
    broker:NewDataObject(name,{
        type="launcher",label="Questfund",icon="Interface\\Icons\\INV_Misc_Bag_10",
        OnClick=toggle,
        OnTooltipShow=function(tip)
            tip:AddLine("Questfund")
            tip:AddLine("Taschen und Bank auf Questgegenstände prüfen.")
        end,
    })
end
