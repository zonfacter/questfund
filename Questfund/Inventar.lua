local _, addon = ...
local container, questLog = C_Container, C_QuestLog
local bankOpen, bankReadable = false, false

local function plain(value)
    return not (issecretvalue and issecretvalue(value))
end

local function number(value)
    return plain(value) and type(value) == "number" and value >= 0 and value < math.huge
end

local function stringValue(value)
    if plain(value) and type(value) == "string" then return value end
end

local function read(fn, ...)
    if not fn then return end
    local ok, result = pcall(fn, ...)
    if ok and plain(result) then return result end
end

local ids = Enum and Enum.BagIndex or {}
local bags, bank = {0}, {ids.Bank or -1}
for i = 1, NUM_BAG_SLOTS or 4 do bags[#bags+1] = i end
if ids.ReagentBag then bags[#bags+1] = ids.ReagentBag end
for i = 0, (NUM_BANKBAGSLOTS or 7)-1 do
    bank[#bank+1] = (ids.BankBag_1 or ((ids.ReagentBag or 4)+1))+i
end
if ids.Reagentbank or ids.ReagentBank then bank[#bank+1] = ids.Reagentbank or ids.ReagentBank end

function addon.Place(bag)
    if bag == 0 then return "Rucksack" end
    if bag == (ids.Bank or -1) then return "Bankfach" end
    if bag == ids.ReagentBag then return "Reagenzientasche" end
    if bag == (ids.Reagentbank or ids.ReagentBank) then return "Reagenzienbank" end
    if bag <= (NUM_BAG_SLOTS or 4) then return "Tasche "..bag end
    return "Banktasche "..(bag-(ids.BankBag_1 or ((ids.ReagentBag or 4)+1))+1)
end

local function scan(containers, isBank)
    local records, slots = {}, 0
    for _, bag in ipairs(containers) do
        local size = read(container.GetContainerNumSlots, bag)
        if number(size) then
            slots = slots+size
            for slot = 1, size do
                local item = read(container.GetContainerItemInfo, bag, slot)
                if type(item) == "table" and (not canaccesstable or canaccesstable(item))
                    and number(item.itemID) and item.itemID > 0 then
                    local quest = read(container.GetContainerItemQuestInfo, bag, slot)
                    local id, marked, active
                    if type(quest) == "table" and (not canaccesstable or canaccesstable(quest)) then
                        id = number(quest.questID) and quest.questID > 0 and quest.questID or nil
                        marked = plain(quest.isQuestItem) and quest.isQuestItem == true
                        active = not isBank and plain(quest.isActive) and quest.isActive == true
                    end
                    local itemID = item.itemID
                    local link = stringValue(item.hyperlink)
                    local name = stringValue(item.itemName)
                    if addon.itemQuests[itemID] or addon.questItems[itemID] or marked or id or active then
                        records[#records+1] = {
                            item=itemID, bag=bag, slot=slot, count=number(item.stackCount) and item.stackCount or 1,
                            id=id, marked=marked, active=active, link=link, name=name,
                            icon=number(item.iconFileID) and item.iconFileID or nil,
                        }
                    end
                end
            end
        end
    end
    return records, slots
end

local function readBank()
    local records, slots = scan(bank, true)
    bankReadable = slots > 0
    if bankReadable then
        QuestfundDB.bank = {items=records, time=time()}
    end
end

local function activeQuests()
    local active = {}
    for i = 1, read(questLog.GetNumQuestLogEntries) or 0 do
        local info = read(questLog.GetInfo, i)
        if type(info) == "table" and (not canaccesstable or canaccesstable(info))
            and number(info.questID) and plain(info.isHeader) and not info.isHeader then
            active[info.questID] = true
        end
    end
    return active
end

local function allowed(mask, id, maximum)
    return not id or id < 1 or id > maximum or mask == 0 or math.floor(mask/2^(id-1))%2 == 1
end

local function playerSide()
    local faction = read(UnitFactionGroup,"player")
    if faction=="Alliance" then return 1 end
    if faction=="Horde" then return 2 end
end

local function matchesSide(mask, side)
    return mask==3 or (side~=nil and mask==side)
end

local function turnInAllowed(turnIn, side)
    if not matchesSide(turnIn.side,side) then return false end
    if #turnIn.targets==0 then return true end
    for _, target in ipairs(turnIn.targets) do
        if matchesSide(target[6],side) then return true end
    end
    return false
end

function addon.TurnInTargets(questID)
    local turnIn, side = addon.turnIns[questID],playerSide()
    local targets={}
    if not turnIn or not matchesSide(turnIn.side,side) then return targets end
    for _, target in ipairs(turnIn.targets) do
        if matchesSide(target[6],side) then targets[#targets+1]=target end
    end
    return targets
end

function addon.CanTrackTurnIn(destination)
    local turnIn = addon.turnIns[destination.questID]
    local side = playerSide()
    return turnIn and matchesSide(turnIn.side,side) and matchesSide(destination.target[6],side)
end

function addon.TurnInAmount(row, questID)
    local turnIn = addon.turnIns[questID]
    if not turnIn then return end
    -- Forever's quest objective API gives quantities without the collected item ID.
    -- A live amount can only be matched when both sources identify one item objective.
    if turnIn.itemCount == 1 and (row.quests[questID] or 0)%2 == 1 and read(questLog.IsOnQuest, questID) == true then
        local objectives = read(questLog.GetQuestObjectives, questID)
        if type(objectives) == "table" and (not canaccesstable or canaccesstable(objectives)) then
            local amount, itemObjectives = nil, 0
            for _, objective in ipairs(objectives) do
                local kind = type(objective) == "table" and (not canaccesstable or canaccesstable(objective))
                    and stringValue(objective.type)
                if not kind then itemObjectives = 0; break end
                if kind == "item" then
                    itemObjectives = itemObjectives+1
                    amount = number(objective.numRequired) and objective.numRequired
                end
            end
            if itemObjectives == 1 and amount and amount > 0 then return amount, true end
        end
    end
    return turnIn.amounts[row.id], false
end

local function classify(row, active, race, class, side)
    local matched, starter, wasStarter = false, false, false
    for _, packed in ipairs(addon.itemQuests[row.id] or {}) do
        local qID, flags = math.floor(packed/8), packed%8
        row.quests[qID] = flags
    end
    row.repeats = {}
    for id, flags in pairs(row.quests) do
        local meta = addon.questMeta[id]
        local turnIn = addon.turnIns[id]
        local onQuest = active[id] or read(questLog.IsOnQuest, id) == true
        if onQuest then row.active = true end
        if (not turnIn or turnInAllowed(turnIn,side)) and (onQuest or not meta or (allowed(meta[2],race,8) and allowed(meta[3],class,11))) then
            matched = true
            if turnIn and (flags%2==1 or turnIn.amounts[row.id]) then row.repeats[#row.repeats+1] = id end
            if math.floor(flags/2)%2==1 then
                wasStarter = true
                if read(questLog.IsQuestFlaggedCompleted,id) == false then starter = true end
            end
        else
            row.quests[id] = nil
        end
    end
    table.sort(row.repeats)
    if row.active then
        row.status = "active"
    elseif #row.repeats > 0 then
        row.status = "repeatable"
    elseif starter then
        row.status = "starter"
    elseif row.marked or row.native or wasStarter or addon.questItems[row.id] then
        row.status = matched and "inactive" or "unknown"
    end
    return row.status ~= nil
end

local order = {inactive=1, repeatable=2, starter=3, unknown=4, active=5}
function addon.Inventory()
    local rows = {}
    local function collect(items, inBank)
        for _, item in ipairs(items) do
            local row = rows[item.item]
            if not row then
                row = {id=item.item, quests={}, places={}, bags=0, bank=0}
                rows[item.item] = row
            end
            row.name = row.name or item.name
            row.link = row.link or item.link
            row.icon = row.icon or item.icon
            row.marked = row.marked or item.marked
            row.active = row.active or item.active
            row.native = row.native or item.id ~= nil
            if item.id and not row.quests[item.id] then row.quests[item.id] = 0 end
            row.places[#row.places+1] = item
            local side = inBank and "bank" or "bags"
            row[side] = row[side] + item.count
        end
    end
    collect(scan(bags),false)
    local snapshot = QuestfundDB.bank
    if snapshot then collect(snapshot.items,true) end
    local active = activeQuests()
    local _, _, race = UnitRace("player")
    local _, _, class = UnitClass("player")
    local side = playerSide()
    local result = {}
    for _, row in pairs(rows) do
        if classify(row,active,race,class,side) then
            row.name = row.name or read(C_Item and C_Item.GetItemNameByID,row.id) or ("Gegenstand #"..row.id)
            result[#result+1] = row
        end
    end
    table.sort(result,function(a,b)
        if a.status ~= b.status then return order[a.status] < order[b.status] end
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    return result, bankOpen and bankReadable, snapshot and snapshot.time
end

local events = CreateFrame("Frame")
for _, event in ipairs({"ADDON_LOADED","BAG_UPDATE","BAG_UPDATE_DELAYED","BANKFRAME_OPENED",
    "BANKFRAME_CLOSED","QUEST_LOG_UPDATE","GET_ITEM_INFO_RECEIVED","QUEST_DATA_LOAD_RESULT"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(self,event,arg)
    if event == "ADDON_LOADED" then
        if arg ~= "Questfund" then return end
        if type(QuestfundDB) ~= "table" then QuestfundDB = {} end
        local snapshot = QuestfundDB.bank
        if type(snapshot) ~= "table" or type(snapshot.items) ~= "table" or type(snapshot.time) ~= "number" then QuestfundDB.bank = nil end
        self:UnregisterEvent(event)
        return
    end
    if event == "BANKFRAME_OPENED" then
        bankOpen = true
        readBank()
    elseif event == "BANKFRAME_CLOSED" then
        bankOpen = false
    elseif event == "BAG_UPDATE" then
        if bankOpen then
            for _, bag in ipairs(bank) do
                if bag == arg then readBank(); break end
            end
        end
        return
    elseif event == "BAG_UPDATE_DELAYED" and bankOpen then
        readBank()
    end
    if addon.InventoryChanged then addon.InventoryChanged() end
end)
