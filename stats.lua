RaidBrowser.stats = {};

local raid_translations
if GetLocale() ~= "enUS" then
	raid_translations = LibStub("LibBabble-Zone-3.0")
end

local raid_achievements = {
	icc = {
		4531, -- Storming the Citadel 10-man
		4604, -- Storming the Citadel 25-man
		4628, -- Storming the Citadel 10-man HC
		4632, -- Storming the Citadel 25-man HC
		4528, -- The Plagueworks 10-man
		4605, -- The Plagueworks 25-man
		4629, -- The Plagueworks 10-man HC
		4633, -- The Plagueworks 25-man HC
		4529, -- The Crimson Hall 10-man
		4606, -- The Crimson Hall 25-man
		4630, -- The Crimson Hall 10-man HC
		4634, -- The Crimson Hall 25-man HC
		4527, -- The Frostwing Halls 10-man
		4607, -- The Frostwing Halls 25-man
		4631, -- The Frostwing Halls 10-man HC
		4635, -- The Frostwing Halls 25-man HC
		4530, -- The Frozen Throne (LK10 NM)
		4597, -- The Frozen Throne (LK25 NM)
		4583, -- Bane of the Fallen King (LK10 HC)
		4584, -- The Light of Dawn (LK25 HC)
	},

	toc = {
		3917, -- Call of the Crusade 10-man
		3916, -- Call of the Crusade 25-man
		3918, -- Call of the Grand Crusade (10 HC)
		3812, -- Call of the Grand Crusade (25 HC)
	},

	rs = {
		4817, -- The Twilight Destroyer 10
		4815, -- The Twilight Destroyer 25
		4818, -- The Twilight Destroyer 10 HC
		4816, -- The Twilight Destroyer 25 HC
	},
};

-- Spanish spec names (values only; keys MUST stay the same)
local spec_names = {
	full = {
		-- Warrior
		WarriorArms = "Guerrero Armas",
		WarriorFury = "Guerrero Furia",
		WarriorProtection = "Guerrero Protección",

		-- Paladin
		PaladinHoly = "Paladín Sagrado",
		PaladinProtection = "Paladín Protección",
		PaladinCombat = "Paladín Reprensión",

		-- Hunter
		HunterBeastMastery = "Cazador Bestias",
		HunterMarksmanship = "Cazador Puntería",
		HunterSurvival = "Cazador Supervivencia",

		-- Rogue
		RogueAssassination = "Pícaro Asesinato",
		RogueCombat = "Pícaro Combate",
		RogueSubtlety = "Pícaro Sutileza",

		-- Priest
		PriestDiscipline = "Sacerdote Disciplina",
		PriestHoly = "Sacerdote Sagrado",
		PriestShadow = "Sacerdote Sombras",

		-- DK
		DeathKnightBlood = "Caballero de la Muerte Sangre",
		DeathKnightFrost = "Caballero de la Muerte Escarcha",
		DeathKnightUnholy = "Caballero de la Muerte Profano",

		-- Shaman
		ShamanElementalCombat = "Chamán Elemental",
		ShamanEnhancement = "Chamán Mejora",
		ShamanRestoration = "Chamán Restauración",

		-- Mage
		MageArcane = "Mago Arcano",
		MageFire = "Mago Fuego",
		MageFrost = "Mago Escarcha",

		-- Warlock
		WarlockCurses = "Brujo Aflicción",
		WarlockSummoning = "Brujo Demonología",
		WarlockDestruction = "Brujo Destrucción",

		-- Druid
		DruidBalance = "Druida Equilibrio",
		DruidFeralCombat = "Druida Feral",
		DruidRestoration = "Druida Restauración"
	},

	short = {
		WarriorArms = "Armas",
		WarriorFury = "Furia",
		WarriorProtection = "Prot",

		PaladinHoly = "Sagrado",
		PaladinProtection = "Prot",
		PaladinCombat = "Repr",

		HunterBeastMastery = "Bestias",
		HunterMarksmanship = "Puntería",
		HunterSurvival = "Superv",

		RogueAssassination = "Ases",
		RogueCombat = "Comb",
		RogueSubtlety = "Sutil",

		PriestDiscipline = "Disc",
		PriestHoly = "Sagrado",
		PriestShadow = "Sombras",

		DeathKnightBlood = "Sangre",
		DeathKnightFrost = "Escarcha",
		DeathKnightUnholy = "Profano",

		ShamanElementalCombat = "Ele",
		ShamanEnhancement = "Mejora",
		ShamanRestoration = "Resto",

		MageArcane = "Arc",
		MageFire = "Fuego",
		MageFrost = "Esc",

		WarlockCurses = "Afl",
		WarlockSummoning = "Demo",
		WarlockDestruction = "Destro",

		DruidBalance = "Balan",
		DruidFeralCombat = "Feral",
		DruidRestoration = "Resto"
	}
}

-- Turn internal raid keys into short tags for display (DO NOT use this for lockout matching!)
local RAID_SHORT = {
	icc = "ICC",
	toc = "TOC",
	rs = "RS",
	voa = "VOA",
	ulduar = "ULDU",
	os = "OS",
	naxx = "NAXX",
	eoe = "EOE",
	onyxia = "ONY",
	hyjal = "HYJAL",
	["zul'aman"] = "ZA",
	["tempest keep"] = "TK",
	karazhan = "KARA",
	["mag's lair"] = "MAG",
	["gruul's lair"] = "GRUUL",
	bwl = "BWL",
	["molten core"] = "MC",
	["black temple"] = "BT",
	sunwell = "SWP",
	ssc = "SSC",
	aq40 = "AQ40",
	aq20 = "AQ20",
}

local function raid_short_name(internalRaid)
	if not internalRaid then return "" end
	local r = tostring(internalRaid):lower()

	-- Most important first
	if r:find("icc", 1, true) then return "ICC" end
	if r:find("toc", 1, true) or r:find("togc", 1, true) then return "TOC" end
	if r:find("rs", 1, true) then return "RS" end
	if r:find("voa", 1, true) then return "VOA" end
	if r:find("uldu", 1, true) then return "ULDU" end
	if r:find("naxx", 1, true) then return "NAXX" end
	if r:find("os", 1, true) then return "OS" end
	if r:find("eoe", 1, true) or r:find("maly", 1, true) then return "EOE" end
	if r:find("ony", 1, true) then return "ONY" end
	if r:find("hyjal", 1, true) then return "HYJAL" end
	if r:find("ssc", 1, true) then return "SSC" end
	if r:find("swp", 1, true) or r:find("sunwell", 1, true) then return "SWP" end
	if r:find("bt", 1, true) or r:find("black temple", 1, true) then return "BT" end
	if r:find("kz", 1, true) or r:find("kara", 1, true) then return "KARA" end
	if r:find("tk", 1, true) then return "TK" end
	if r:find("za", 1, true) then return "ZA" end
	if r:find("bwl", 1, true) then return "BWL" end
	if r:find("mc", 1, true) then return "MC" end
	if r:find("aq40", 1, true) then return "AQ40" end
	if r:find("aq20", 1, true) then return "AQ20" end

	-- fallback: keep whatever it is
	return tostring(internalRaid)
end

---@param raid string The name of the achievement ids table
---@nodiscard
local function find_best_achievement(raid)
	local ids = raid_achievements[raid];
	if not ids then
		return nil;
	end

	local max_achievement = nil;

	for i, id in ipairs(ids) do
		local _, _, _, completed = GetAchievementInfo(id);
		if completed and (not max_achievement or max_achievement[1] <= i) then
			max_achievement = { i, id };
		end
	end

	for i, id in ipairs(ids) do
		for j = 1, GetAchievementNumCriteria(id) do
			local _, _, completed = GetAchievementCriteriaInfo(id, j)
			if completed and (not max_achievement or max_achievement[1] <= i) then
				max_achievement = { i, id };
			end
		end
	end

	if max_achievement then
		return max_achievement[2];
	else
		return nil;
	end
end

local function GetTalentTabPoints(i)
	local _, _, pts = GetTalentTabInfo(i)
	return pts;
end

function RaidBrowser.stats.active_spec_index()
	local indices = std.algorithm.transform({ 1, 2, 3 }, GetTalentTabPoints)
	local i, _ = std.algorithm.max_of(indices);
	return i;
end

---@return string
---@nodiscard
function RaidBrowser.stats.active_spec()
	local active_tab = RaidBrowser.stats.active_spec_index()
	local _, _, _, spec_name = GetTalentTabInfo(active_tab);

	-- feral druid: distinguish bear/cat
	if spec_name == 'DruidFeralCombat' then
		local protector_of_pack_talent = 22;
		local _, _, _, _, points = GetTalentInfo(active_tab, protector_of_pack_talent)
		if points > 0 then
			return 'Druida Feral (Oso)'
		else
			return 'Druida Feral (Gato)'
		end
	end

	return spec_names["full"][spec_name] or spec_name;
end

---Return if the given raid is locked, and if so its reset time left (in seconds)
---@param raid_info any
---@return boolean, integer | nil
---@nodiscard
function RaidBrowser.stats.raid_lock_info(raid_info)
	local instance_name = raid_info.instance_name
	if raid_translations then
		instance_name = raid_translations:GetUnstrictLookupTable()[raid_info.instance_name] or raid_info.instance_name
	end

	-- IMPORTANT: This MUST remain the real instance name for matching saved instances.
	if instance_name == nil or raid_info.size == nil then return false, nil end

	for i = 1, GetNumSavedInstances() do
		local saved_name, _, reset, _, locked, _, _, _, saved_size = GetSavedInstanceInfo(i);
		if saved_name ~= nil then
			if string.lower(saved_name) == string.lower(instance_name) and saved_size == raid_info.size and locked then
				return true, reset;
			end
		end
	end

	return false, nil;
end

---Returns for the currently active raidset, the spec name and its gearscore.
---@return string, integer
---@nodiscard
function RaidBrowser.stats.get_active_raidset()
	local spec = nil;
	local gs = nil;

	if GearScore_GetScore then
		gs = GearScore_GetScore(UnitName('player'), 'player');

		if gs == nil and GS_Data then
			if GS_Data[GetRealmName()] and GS_Data[GetRealmName()].Players[UnitName("player")] then
				gs = GS_Data[GetRealmName()].Players[UnitName("player")]["GearScore"]
			end
		end
	end

	spec = RaidBrowser.stats.active_spec();
	return spec, gs;
end

---@param set 'Primary'|'Secondary'
---@return string?, integer?
---@nodiscard
function RaidBrowser.stats.get_raidset(set)
	local raidset = RaidBrowserCharacterRaidsets[set];
	if not raidset then return end
	return raidset.spec, raidset.gs;
end

---@return string?, integer?
function RaidBrowser.stats.current_raidset()
	if RaidBrowserCharacterCurrentRaidset == 'Active' then
		return RaidBrowser.stats.get_active_raidset();
	end

	return RaidBrowser.stats.get_raidset(RaidBrowserCharacterCurrentRaidset);
end

---@param set 'Active' | 'Primary' | 'Secondary'
function RaidBrowser.stats.select_current_raidset(set)
	RaidBrowserCharacterCurrentRaidset = set;
end

function RaidBrowser.stats.save_primary_raidset()
	local spec, gs = RaidBrowser.stats.get_active_raidset();
	RaidBrowserCharacterRaidsets['Primary'] = { spec = spec, gs = gs };
end

function RaidBrowser.stats.save_secondary_raidset()
	local spec, gs = RaidBrowser.stats.get_active_raidset();
	RaidBrowserCharacterRaidsets['Secondary'] = { spec = spec, gs = gs };
end

---Returns join message string
---@param raid_name string
---@return string
---@nodiscard
function RaidBrowser.stats.build_join_message(raid_name)
	local spec, gs = RaidBrowser.stats.current_raidset();
	gs = gs or "" -- avoid "nilgs"

	-- raid_name coming here is usually internal like "icc10hc" etc.
	-- Use your existing helper to normalize (defined elsewhere), then shorten for display.
	local base = RaidBrowser.get_short_raid_name(raid_name) or raid_name
	local raidTag = raid_short_name(base)

	-- Spanish join message (keep "inv" because people use it a lot)
	local message = 'inv para ' .. raidTag .. " - " .. gs .. 'gs ' .. (spec or "")

	-- Achievements: only for icc/toc/rs tables (based on base key)
	local achieve_id = find_best_achievement(base);
	if achieve_id then
		message = message .. ' ' .. GetAchievementLink(achieve_id);
	end

	return message;
end