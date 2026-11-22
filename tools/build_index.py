"""Build the Forever quest index and match legacy turn-in amounts by quest and item ID."""

import gzip
import json
from pathlib import Path
import re

from lupa.lua54 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / ".data-cache"
PIN = "9b8b82ecd85bfe504a2d2c8a020dedde100230ca"
CLASSIC_PIN = "13e933726f386399d9820138fbd1123e7cda86c8"
lua = LuaRuntime(register_eval=False, register_builtins=False)
load_table = lua.eval("""function(code)
    local loader = assert(load(code, "QuestieDB data", "t", {}))
    debug.sethook(function() error("Expected a static table") end, "", 10000000)
    local ok, rows = pcall(loader)
    debug.sethook()
    assert(ok, rows)
    return rows
end""")


def read(kind):
    source = (CACHE / f"forever{kind.title()}DB.lua").read_text("utf-8-sig")
    fields = dict((key, int(value)) for key, value in re.findall(r"^    \['(\w+)'\] = (\d+),", source, re.M))
    match = re.search(rf"QuestieDB\.{kind}Data = \[\[(.*?)\]\]", source, re.S)
    if not fields or not match:
        raise ValueError("Unknown QuestieDB table format")
    return fields, load_table(match[1])


def entries(table):
    return table.values() if table is not None else ()


def legacy_requirements():
    """Read only numeric item requirements from the SQL dump."""
    fields, by_quest = [], {}
    in_schema = False
    insert = 'INSERT INTO `quest_template` VALUES '
    tokens = re.compile(r"'(?:[^'\\]|\\.)*'|[^,()']+|[()]")
    with gzip.open(CACHE / "ClassicDB_1_12_1_z2815.sql.gz", "rt", encoding="utf-8") as dump:
        for line in dump:
            if line.startswith('CREATE TABLE `quest_template` ('):
                in_schema = True
            elif in_schema and line.startswith(")"):
                in_schema = False
                index = {column: i for i, column in enumerate(fields)}
                pairs = [(index[f"ReqItemId{i}"], index[f"ReqItemCount{i}"]) for i in range(1, 5)]
            elif in_schema and line.startswith("  `"):
                fields.append(line.split("`")[1])
            elif line.startswith(insert):
                for match in tokens.finditer(line, len(insert)):
                    token = match[0]
                    if token == "(":
                        row = []
                    elif token == ")":
                        if len(row) != len(fields):
                            raise ValueError("Unexpected ClassicDB quest row")
                        items = {}
                        for item_pos, value_pos in pairs:
                            item, value = int(row[item_pos]), int(row[value_pos])
                            if item > 0 and value > 0:
                                items[item] = items.get(item, 0) + value
                        if items:
                            by_quest[int(row[index["entry"]])] = items
                    elif token != ";\n":
                        row.append(token)
    if not by_quest:
        raise ValueError("ClassicDB quest requirements were not found")
    return by_quest


def map_lookup():
    source = (CACHE / "areaIdToUiMapId.lua").read_text(encoding="utf-8")
    tables = re.findall(r"\[\[(return \{.*?\})\]\]", source, re.S)
    if len(tables) != 2:
        raise ValueError("Unexpected QuestieDB area map format")
    overrides, base = (dict(load_table(table).items()) for table in tables)
    return base | overrides


def lua_string(value):
    return json.dumps(value, ensure_ascii=False)


def german_names(kind):
    source = (CACHE / f"lookup{kind}-deDE.lua").read_text(encoding="utf-8")
    match = re.search(r"loadstring\(\[\[(return \{.*?\})\]\]\)", source, re.S)
    if not match:
        raise ValueError(f"Unknown German lookup format: {kind}")
    names = load_table(match[1])
    return {key: (value[1] if kind == "Npcs" else value) for key, value in names.items()}


quest_keys, quests = read("quest")
item_keys, items = read("item")
index, used = {}, set()


def relate(item, quest, flag):
    if isinstance(item, int) and item > 0 and isinstance(quest, int) and quest > 0 and quests[quest] is not None:
        references = index.setdefault(item, {})
        references[quest] = references.get(quest, 0) | flag
        used.add(quest)


for quest, row in quests.items():
    starts = row[quest_keys["startedBy"]]
    for item in entries(starts[3] if starts else None):
        relate(item, quest, 2)
    relate(row[quest_keys["sourceItemId"]], quest, 4)
    for item in entries(row[quest_keys["requiredSourceItems"]]):
        relate(item, quest, 4)
    objectives = row[quest_keys["objectives"]]
    if objectives is not None:
        for goal in entries(objectives[3]):
            relate(goal[1], quest, 1)
        for goal in entries(objectives[6]):
            relate(goal[3], quest, 4)

quest_items = {}
for item, row in items.items():
    relate(item, row[item_keys["startQuest"]], 2)
    if row[item_keys["class"]] == 12:
        quest_items[item] = True

out = ROOT / "Questfund" / "QuestIndex.lua"
with out.open("w", encoding="utf-8", newline="\n") as f:
    f.write(f"-- Forever base data derived from QuestieDB {PIN}. See DATA-SOURCES.md and UPSTREAM-LICENSE.md.\n")
    f.write("local _, addon = ...\naddon.itemQuests = {\n")
    for item, references in sorted(index.items()):
        packed = ",".join(str(quest * 8 + flag) for quest, flag in sorted(references.items()))
        f.write(f"    [{item}]={{{packed}}},\n")
    f.write("}\naddon.questMeta = {\n")
    for quest in sorted(used):
        row = quests[quest]
        level = max(row[quest_keys["requiredLevel"]] or 0, 0)
        races = row[quest_keys["requiredRaces"]] or 0
        classes = row[quest_keys["requiredClasses"]] or 0
        repeatable = (row[quest_keys["specialFlags"]] or 0) & 1
        if level or races or classes or repeatable:
            f.write(f"    [{quest}]={{{level},{races},{classes},{repeatable}}},\n")
    f.write("}\naddon.questItems = {\n")
    for item in sorted(quest_items):
        f.write(f"    [{item}]=true,\n")
    f.write("}\n")
print(f"{len(index)} indexed items, {len(used)} referenced quests, {len(quest_items)} quest-class items.")

classic = legacy_requirements()
maps = map_lookup()
targets_by_kind = [read("npc"), read("object")]
german_by_kind = [german_names("Npcs"), german_names("Objects")]


def quest_side(quest):
    races = quest[quest_keys["requiredRaces"]] or 0
    alliance, horde = bool(races & 0x4D), bool(races & 0xB2)
    return 1 if alliance and not horde else 2 if horde and not alliance else 3


def turn_in_targets(quest):
    finishers = quest[quest_keys["finishedBy"]]
    if finishers is None:
        return []
    targets = []
    for kind, (keys, rows) in enumerate(targets_by_kind, 1):
        for target_id in entries(finishers[kind]):
            row = rows[target_id]
            name = row[keys["name"]] if row else None
            spawns = row[keys["spawns"]] if row else None
            places = set()
            for area, coords in spawns.items() if spawns is not None else ():
                map_id = maps.get(area, 0)
                if map_id > 0:
                    for point in entries(coords):
                        x, y = point[1], point[2]
                        if 0 <= x <= 100 and 0 <= y <= 100 and (x or y):
                            places.add((map_id, round(x, 1), round(y, 1)))
            # Only use the quest zone to order real spawns. An unmapped spawn
            # cannot establish that the finisher is in the quest's zone.
            quest_map = maps.get(quest[quest_keys["zoneOrSort"]], 0)
            ordered = sorted(places, key=lambda place: (place[0] != quest_map, *place))
            points = ",".join(f"{{{m},{x:g},{y:g}}}" for m, x, y in ordered)
            german = german_by_kind[kind-1].get(target_id)
            localized = lua_string(german) if german and german != name else "nil"
            if kind == 1:
                friendly = row[keys["friendlyToFaction"]] if row else None
                side = {"A": 1, "H": 2, "AH": 3}.get(friendly, 0)
            else:
                side = row[keys["factionID"]] if row else None
                side = side if side in (1, 2) else 3
            targets.append(f"{{{kind},{target_id},{lua_string(name or '')},{{{points}}},{localized},{side}}}")
    return targets


repeatable_count, amount_count, located_count = 0, 0, 0
with (ROOT / "Questfund" / "AbgabeIndex.lua").open("w", encoding="utf-8", newline="\n") as f:
    f.write(f"-- QuestieDB Forever {PIN}; reference counts from CMaNGOS ClassicDB {CLASSIC_PIN}.\n")
    f.write("-- See DATA-SOURCES.md and UPSTREAM-LICENSE.md.\nlocal _, addon = ...\naddon.turnIns = {\n")
    for quest_id in sorted(used):
        quest = quests[quest_id]
        objectives = quest[quest_keys["objectives"]]
        items = {goal[1] for goal in entries(objectives[3] if objectives else None) if goal[1]}
        if not items or not ((quest[quest_keys["specialFlags"]] or 0) & 1):
            continue
        amounts = classic.get(quest_id, {})
        # Some quests consume their starting object (e.g. a Craftsman's Writ).
        # Accept that extra requirement only if it is also the Forever source item.
        source = quest[quest_keys["sourceItemId"]]
        starters = quest[quest_keys["startedBy"]]
        starting_items = set(entries(starters[3] if starters else None))
        allowed_extra = {source} & starting_items
        quantities = amounts if items <= amounts.keys() <= items | allowed_extra else {}
        packed_counts = ",".join(f"[{item}]={count}" for item, count in sorted(quantities.items()))
        targets = turn_in_targets(quest)
        f.write(f"    [{quest_id}]={{itemCount={len(items)},side={quest_side(quest)},amounts={{{packed_counts}}},targets={{{','.join(targets)}}}}},\n")
        repeatable_count += 1
        amount_count += bool(quantities)
        located_count += bool(targets)
    f.write("}\n")
print(f"{repeatable_count} repeatable item quests, {located_count} with finishers, {amount_count} with reference amounts.")
