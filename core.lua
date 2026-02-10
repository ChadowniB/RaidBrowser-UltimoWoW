-- Register addon
RaidBrowser = LibStub('AceAddon-3.0'):NewAddon('RaidBrowser', 'AceConsole-3.0')

--[[ Reputation system (per-character) ]]--
RaidBrowserReputationDB = RaidBrowserReputationDB or { scores = {} }  -- sender -> integer score
RaidBrowserReputationOptions = RaidBrowserReputationOptions or { hideBlocked = false }

function RaidBrowser.rep_get(name)
    if not name then return 0 end
    local scores = RaidBrowserReputationDB and RaidBrowserReputationDB.scores
    if not scores then return 0 end
    return scores[name] or 0
end

function RaidBrowser.rep_set(name, score)
    if not name then return end
    RaidBrowserReputationDB = RaidBrowserReputationDB or { scores = {} }
    RaidBrowserReputationDB.scores = RaidBrowserReputationDB.scores or {}
    RaidBrowserReputationDB.scores[name] = score
end

function RaidBrowser.rep_vote(name, delta)
    if not name then return end
    local current = RaidBrowser.rep_get(name)
    RaidBrowser.rep_set(name, current + (delta or 0))
end

function RaidBrowser.rep_is_blocked(name)
    return RaidBrowserReputationOptions and RaidBrowserReputationOptions.hideBlocked and (RaidBrowser.rep_get(name) < 0)
end


--[[ Parsing and pattern matching ]] --
-- Separator characters
local sep_chars = '%s-_,.<>%*)(/#+&x'

-- Whitespace separator
local sep = '[' .. sep_chars .. ']';

local role_sep = '[' .. sep_chars .. 'x\\/' .. ']';

-- Kleene closure of sep.
local csep = sep .. '*';

-- Positive closure of sep.
local psep = sep .. '+';

-- Separator characters + any text
---@diagnostic disable-next-line: unused-local
local wtext = '[%w' .. sep_chars .. ']*'

local meta_char = '¿';

local meta_or_sep = '[^' .. meta_char .. ']?' .. '[' .. sep .. ']?';

local non_meta = '[^' .. meta_char .. ']*';

local lfm = 'l[fm]%d*[fm]?'

local function make_meta(text)
	return meta_char .. text .. meta_char;
end

-- Not needed?
---@diagnostic disable-next-line: unused-function, unused-local
local function meta_raid_n(n)
	return make_meta('raid' .. n);
end

local meta_role = make_meta('role');
---@diagnostic disable-next-line: unused-local
local meta_roles = make_meta('roles');
local meta_raid = make_meta('raid');
local meta_gs = make_meta('gs');
local meta_guild = make_meta('guild');

-- Raid patterns template for a raid with 2 difficulties and 2 sizes
local raid_patterns_template = {
	hc = {
		'<raid>' .. csep .. '<size>' .. csep .. 'm?a?n?' .. csep .. 'f?u?l?l?' .. csep .. 'hc?',
		sep .. 'hc?' .. csep .. '<raid>' .. csep .. '<size>',
		'<raid>' .. csep .. 'hc?' .. csep .. '<size>',
		sep .. '<size>' .. csep .. 'ma?n?' .. csep .. '<raid>' .. csep .. 'hc?'.. sep,

		'^<size>' .. csep .. '<raid>' .. csep .. 'hc?'.. sep,
	},

	nm = {
		'<raid>' .. csep .. '<size>' .. csep .. 'm?a?n?' .. csep .. 'f?u?l?l?' .. csep .. 'n?m?' .. sep,
		sep .. 'nm?' .. csep .. '<raid>' .. csep .. '<size>',
		'<raid>' .. csep .. 'n?m?' .. csep .. '<size>',
		sep .. '<size>' .. csep .. 'ma?n?' .. csep .. '<raid>' .. sep,

		'^<size>' .. csep .. '<raid>' .. sep,
	},

	simple = {
		'<raid>' .. csep .. '<size>' .. csep .. 'm[an][an]' .. csep .. 'f?u?l?l?',
		'<raid>' .. csep .. '<size>' .. csep .. 'f?u?l?l?',
		'^<size>' .. csep .. 'm?a?n?' .. csep .. 'f?u?l?l?' .. csep .. '<raid>' .. sep,
		sep .. '<size>' .. csep .. 'm?a?n?' .. csep .. '<raid>' .. sep,
	},
};

---@param raid_name_pattern string
---@param size integer
---@param difficulty string|nil
---@return table
---@nodiscard
local function create_pattern_from_template(raid_name_pattern, size, difficulty)

	local size_pattern = '1[0Op]+'
	if size == 25 then
		size_pattern = '2[5p]+';
	elseif size == 40 then
		size_pattern = '4[0Op]+';
	elseif size == 5 then
		size_pattern = '5+'; -- dungeons (FoS/PoS/HoR/ToC5)
	end

	if not difficulty then
		difficulty = 'nm'
	end

	-- Replace placeholders with the specified raid info
	return std.algorithm.transform(raid_patterns_template[difficulty], function(pattern)
		pattern = pattern:gsub('<raid>', raid_name_pattern);
		pattern = pattern:gsub('<size>', size_pattern);
		return pattern;
	end);
end

local function create_achievement_pattern(achievement_id)
	return "achievement:" .. tostring(achievement_id) .. ".+%]"
end

local function create_quest_pattern(quest_id)
	return "quest:" .. tostring(quest_id) .. ".+%]"
end

local raid_list = {
	-- Note: The order of each raid is deliberate.
	-- Heroic raids are checked first, since NM raids will have the default 'icc10' pattern.
	-- Be careful about changing the order of the raids below
	{
		name = 'icc25rep',
		instance_name = 'ICC',
		size = 25,
		patterns = {
			'icc' .. csep .. '25' .. csep .. 'm?a?n?' .. csep .. 'repu?t?a?t?i?o?n?' .. csep .. '',
			'icc' .. csep .. 'repu?t?a?t?i?o?n?' .. csep .. '25' .. csep .. 'm?a?n?',
			'icc' .. csep .. '25' .. csep .. 'nm?' .. csep .. 'farm',
			'rep' .. csep .. 'farm' .. csep .. 'icc' .. csep .. 25,
		}
	},

	{
		name = 'icc10rep',
		instance_name = 'ICC',
		size = 10,
		patterns = {
			'icc' .. csep .. '10' .. csep .. 'm?a?n?' .. csep .. 'repu?t?a?t?i?o?n?' .. csep,
			'icc' .. csep .. 'repu?t?a?t?i?o?n?' .. csep .. '10',
			'icc' .. csep .. '10' .. csep .. 'nm?' .. csep .. 'farm',
			'icc' .. csep .. 'nm?' .. csep .. 'farm',
			'icc' .. csep .. 'repu?t?a?t?i?o?n?',
			'rep' .. csep .. 'farm' .. csep .. 'icc' .. csep .. 10,
			-- Todo: rep farm icc 10, etc combinations
		}
	},

	{
		name = 'icc10hc',
		instance_name = 'ICC',
		size = 10,
		patterns = std.algorithm.copy_back(
			create_pattern_from_template('icc', 10, 'hc'),
			{
				'Heroic: Storming the Citadel %(10 player%)',
				create_achievement_pattern(4628),
				'Bane of the Fallen King',
				'[^a-z]Bane[^a-z]',
				create_achievement_pattern(4583),
				'Heroic: Fall of the Lich King %(10 player%)',
				create_achievement_pattern(4636),
			}
		)
	},

	{
		name = 'icc25hc',
		instance_name = 'ICC',
		size = 25,
		patterns = std.algorithm.copy_back(
			create_pattern_from_template('icc', 25, 'hc'),
			{
				'Heroic: Storming the Citadel %(25 player%)',
				create_achievement_pattern(4632),
				'The Light of Dawn',
				'[^a-z]LoD[^a-z]',
				create_achievement_pattern(4584),
				'Heroic: Fall of the Lich King %(25 player%)',
				create_achievement_pattern(4637),
			}
		)
	},

	{
		name = 'icc10nm',
		instance_name = 'ICC',
		size = 10,
		patterns = std.algorithm.copy_back(
			create_pattern_from_template('icc', 10, 'nm'),
			{
				'Storming the Citadel %(10 player%)',
				create_achievement_pattern(4531),
				'The Frozen Throne %(10 player%)',
				create_achievement_pattern(4530),
				'Fall of the Lich King %(10 player%)',
				create_achievement_pattern(4532),
			}
		)
	},

	{
		name = 'icc25nm',
		instance_name = 'ICC',
		size = 25,
		patterns = std.algorithm.copy_back(
			create_pattern_from_template('icc', 25, 'nm'),
			{
				'Storming the Citadel %(25 player%)',
				create_achievement_pattern(4604),
				'The Frozen Throne %(25 player%)',
				create_achievement_pattern(4597),
				'Fall of the Lich King %(25 player%)',
				create_achievement_pattern(4608),
			}
		)
	},

	{
		name = 'icc10wq',
		prioritized = true,
		instance_name = 'ICC',
		size = 10,
		patterns = {
			'icc1?0?' .. csep .. 'weekly',
			'Lord Marrowgar' .. wtext .. '[!%]]',
			create_quest_pattern(24590),
		},
	},

	{
		name = 'toc10hc',
		instance_name = 'TOC',
		size = 10,
		patterns = std.algorithm.copy_back(
			create_pattern_from_template('toc', 10, 'hc'),
			{
				'togc' .. csep .. '10',
				'Call of the Grand Crusade %(10 player%)',
				create_achievement_pattern(3918),
			}-- Trial of the grand crusader (togc) refers to heroic toc
		),
	},

	{
		name = 'toc25hc',
		instance_name = 'TOC',
		size = 25,
		patterns = std.algorithm.copy_back(
			create_pattern_from_template('toc', 25, 'hc'),
			{
				'togc' .. csep .. '25',
				'Call of the Grand Crusade %(25 player%)',
				create_achievement_pattern(3812),
			}-- Trial of the grand crusader (togc) refers to heroic toc
		),
	},

	{
		name = 'toc10nm',
		instance_name = 'TOC',
		size = 10,
		patterns = std.algorithm.copy_back(
			create_pattern_from_template('toc', 10, 'nm'),
			{
				'Call of the Crusade %(10 player%)',
				create_achievement_pattern(3917),
			}
		),
	},

	{
		name = 'toc25nm',
		instance_name = 'TOC',
		size = 25,
		patterns = std.algorithm.copy_back(
			create_pattern_from_template('toc', 25, 'nm'),
			{
				'Call of the Crusade %(25 player%)',
				create_achievement_pattern(3916),
			}
		),
	},

	{
		name = 'toc10wq',
		prioritized = true,
		instance_name = 'TOC',
		size = 10,
		patterns = {
			'tog?c1?0?' .. csep .. 'weekly',
			'Lord Jaraxxus' .. wtext .. '[!%]]',
			create_quest_pattern(24589),
		},
	},

	-- =========================
	-- DUNGEONS WOTLK (5 man)
	-- =========================
	{
		name = 'fos5',
		instance_name = 'FOSO',
		size = 5,
		patterns = {
			'fos' .. sep,
			'fo?s' .. csep .. '5',
			'foso' .. csep .. 'de' .. csep .. 'saron',
			'pit' .. csep .. 'of' .. csep .. 'saron',
			'saron' .. sep,
			'farm' .. sep,
			'farme?o' .. sep,
		}
	},

	{
		name = 'forja5',
		instance_name = 'FORJA',
		size = 5,
		patterns = {
			'forja' .. csep .. 'de' .. csep .. 'almas',
			'forge' .. csep .. 'of' .. csep .. 'souls',
			'fds' .. sep,
			'forja' .. sep,
			'almas' .. sep,
			'farm' .. sep,
			'farme?o' .. sep,
		}
	},

	{
		name = 'camara5',
		instance_name = 'CAMARA',
		size = 5,
		patterns = {
			'camara' .. csep .. 'de' .. csep .. 'refle?x?i[oó]n',
			'halls' .. csep .. 'of' .. csep .. 'reflection',
			'hor' .. sep,
			'refle?x?i[oó]n' .. sep,
			'reflection' .. sep,
			'farm' .. sep,
			'farme?o' .. sep,
		}
	},

	{
		name = 'toc5_abalorio',
		instance_name = 'TOC 5',
		size = 5,
		patterns = {
			'toc' .. csep .. '5',
			'toc5',
			'trial' .. csep .. 'of' .. csep .. 'the' .. csep .. 'champion',
			'prueba' .. csep .. 'del' .. csep .. 'campe[oó]n',
			'campe[oó]n' .. csep .. '5',
			'abalorios?' .. csep .. 'farm',
			'farm' .. csep .. 'abalorios?',
			'trinkets?' .. csep .. 'farm',
			'farm' .. csep .. 'trinkets?',
			'abalorios?',
			'trinkets?',
		}
	},

	{
		name = 'rs10hc',
		instance_name = 'SR',
		size = 10,
		patterns = std.algorithm.copy_back(
			create_pattern_from_template('rs', 10, 'hc'),
			{
				-- allow people to write SR too
				'sr' .. sep,
				'ruby' .. csep .. 'sanctum' .. csep .. '10' .. wtext .. 'hc',
				'Heroic: The Twilight Destroyer %(10 player%)',
				create_achievement_pattern(4818),
			}
		),
	},

	{
		name = 'rs25hc',
		instance_name = 'SR',
		size = 25,
		patterns = std.algorithm.copy_back(
			create_pattern_from_template('rs', 25, 'hc'),
			{
				'sr' .. sep,
				'ruby' .. csep .. 'sanctum' .. csep .. '25' .. wtext .. 'hc',
				'Heroic: The Twilight Destroyer %(25 player%)',
				create_achievement_pattern(4816),
			}
		),
	},

	{
		name = 'rs10nm',
		instance_name = 'SR',
		size = 10,
		patterns = std.algorithm.copy_back(
			create_pattern_from_template('rs', 10, 'nm'),
			{
				'sr' .. sep,
				'ruby' .. csep .. 'sanctum' .. csep .. '10',
				'The Twilight Destroyer %(10 player%)',
				create_achievement_pattern(4817),
			}
		),
	},

	{
		name = 'rs25nm',
		instance_name = 'SR',
		size = 25,
		patterns = std.algorithm.copy_back(
			create_pattern_from_template('rs', 25, 'nm'),
			{
				'sr' .. sep,
				'ruby' .. csep .. 'sanctum' .. csep .. '25',
				'The Twilight Destroyer %(25 player%)',
				create_achievement_pattern(4815),
			}
		)
	},

	{
		name = 'voa10',
		instance_name = 'VOA',
		size = 10,
		patterns = create_pattern_from_template('voa', 10, 'simple')
	},

	{
		name = 'voa25',
		instance_name = 'VOA',
		size = 25,
		patterns = std.algorithm.copy_back(
			create_pattern_from_template('voa', 25, 'simple'),
			{
				'voa' .. sep
			})
	},

	{
		name = 'ulduar10',
		instance_name = 'ULD',
		size = 10,
		patterns = {
			'ull?a?d[au]?[au]?r?' .. csep .. '10',
			'The Siege of Ulduar %(10 player%)',
			create_achievement_pattern(2886),
		},
	},

	{
		name = 'ulduar25',
		instance_name = 'ULD',
		size = 25,
		patterns = {
			'ull?a?d[au]?[au]?r?' .. csep .. '25',
			'The Siege of Ulduar %(25 player%)',
			create_achievement_pattern(2887),
		}
	},

	{
		name = 'ulduar10wq',
		prioritized = true,
		instance_name = 'ULD',
		size = 10,
		patterns = {
			'ull?a?d[au]?[au]?r?1?0?' .. csep .. 'weekly',
			'Flame Leviathan' .. wtext .. '[!%]]',
			create_quest_pattern(24585),
			'Ignis' .. wtext .. '[!%]]',
			create_quest_pattern(24587),
			'Razorscale' .. wtext .. '[!%]]',
			create_quest_pattern(24586),
			'XT-002' .. wtext .. '[!%]]',
			create_quest_pattern(24588),
		},
	},

	{
		name = 'os10',
		instance_name = 'SO',
		size = 10,
		patterns = std.algorithm.copy_back(
			create_pattern_from_template('os', 10, 'simple'),
			{
				'Besting the Black Dragonflight %(10 player%)',
				create_achievement_pattern(1876),
			}
		),
	},

	{
		name = 'os25',
		instance_name = 'SO',
		size = 25,
		patterns = std.algorithm.copy_back(
			create_pattern_from_template('os', 25, 'simple'),
			{
				'Besting the Black Dragonflight %(25 player%)',
				create_achievement_pattern(625),
			}
		)
	},

	{
		name = 'os10wq',
		prioritized = true,
		instance_name = 'SO',
		size = 10,
		patterns = {
			'os1?0?' .. csep .. 'weekly',
			'Sartharion' .. wtext .. '[!%]]',
			create_quest_pattern(24579),
		}
	},

	{
		name = 'naxx10',
		instance_name = 'NAXX',
		size = 10,
		patterns = {
			'The Fall of Naxxramas %(10 player%)',
			create_achievement_pattern(576),
			'naxx?ramm?as' .. csep .. '10',
			'naxx?' .. csep .. '10',
		},
	},

	{
		name = 'naxx25',
		instance_name = 'NAXX',
		size = 25,
		patterns = {
			'The Fall of Naxxramas %(25 player%)',
			create_achievement_pattern(577),
			'naxx?ramm?as' .. csep .. '25',
			'naxx?' .. csep .. '25',
		},
	},

	{
		name = 'naxx10wq',
		prioritized = true,
		instance_name = 'NAXX',
		size = 10,
		patterns = {
			'naxx?1?0?' .. csep .. 'weekly',
			'Anub\'Rekhan' .. wtext .. '[!%]]',
			create_quest_pattern(24580),
			'Noth' .. wtext .. '[!%]]',
			create_quest_pattern(24581),
			'Razuvious' .. wtext .. '[!%]]',
			create_quest_pattern(24582),
			'Patchwerk' .. wtext .. '[!%]]',
			create_quest_pattern(24583),
		},
	},

	{
		name = 'eoe25',
		instance_name = 'EOE',
		size = 25,
		patterns = std.algorithm.copy_back(
			create_pattern_from_template('eoe', 25, 'simple'),
			{
				'malygo?s' .. csep .. '25',
				'eoe' .. csep .. '25',
				'A Poke In The Eye %(25 player%)',
				create_achievement_pattern(1870),
			}
		),
	},

	{
		name = 'eoe10',
		instance_name = 'EOE',
		size = 10,
		patterns = std.algorithm.copy_back(
			create_pattern_from_template('eoe', 10, 'simple'),
			{
				'malygo?s',
				'eoe',
				'A Poke In The Eye %(10 player%)',
				create_achievement_pattern(1869),
			}
		),
	},

	{
		name = 'eoe10wq',
		prioritized = true,
		instance_name = 'EOE',
		size = 10,
		patterns = {
			'eoe1?0?' .. csep .. 'weekly',
			'Malygos' .. wtext .. '[!%]]',
			create_quest_pattern(24584),
		},
	},

	{
		name = 'onyxia25',
		instance_name = 'ONY',
		size = 25,
		patterns = {
			'onyx?i?a?' .. csep .. '25',
			'Onyxia\'s Lair %(25 player%)',
			create_achievement_pattern(4397),
		},
	},

	{
		name = 'onyxia10',
		instance_name = 'ONY',
		size = 10,
		patterns = {
			'onyx?i?a?' .. csep .. '10',
			'Onyxia\'s Lair %(10 player%)',
			create_achievement_pattern(4396),
		},
	},

	{
		name = 'hyjal25',
		instace_name = 'HYJAL',
		size = 25,
		patterns = {
			'mount' .. csep .. 'hyjal',
			'the' .. csep .. 'battle' .. csep .. 'for' .. csep .. 'mount' .. csep .. 'hyjal',
			create_achievement_pattern(695),
		},
	},

	{
		name = 'zul\'aman10',
		instance_name = 'ZA',
		size = 10,
		patterns = {
			'zul' .. csep .. '\'?' .. csep .. 'aman',
			create_achievement_pattern(691),
		},
	},

	{
		name = 'tempest keep25',
		instance_name = 'TK',
		size = 25,
		patterns = {
			'te*mpe*st' .. csep .. 'ke+p',
			sep .. 'tk',
			'tk' .. sep,
			create_achievement_pattern(696),
		},
	},

	{
		name = 'karazhan10',
		instance_name = 'KZ',
		size = 10,
		patterns = {
			'karaz?h?a?n?' .. csep .. '1?0?', -- karazhan
			'^kz' .. csep .. '10',
			sep .. 'kz' .. csep .. '10',
			create_achievement_pattern(690),
		},
	},

	{
		name = 'mag\'s lair25',
		instance_name = 'MAG',
		size = 25,
		patterns = {
			'magt?h?e?r?i?d?o?n?\'*s*' .. csep .. 'lai?r',
			create_achievement_pattern(693),
		},
	},

	{
		name = 'gruul\'s lair25',
		instance_name = 'GRUUL',
		size = 25,
		patterns = {
			'gruul\'*s*' .. csep .. 'l?a?i?r?',
			create_achievement_pattern(692),
		},
	},

	{
		name = 'bwl40',
		instance_name = 'BWL',
		size = 40,
		patterns = {
			sep .. 'bwl4?0?',
			'blackwing' .. csep .. 'l?a?i?r?',
			'blackwi?n?g?' .. csep .. 'la?i?r?',
			create_achievement_pattern(685),
		},
	},

	{
		name = 'molten core40',
		instance_name = 'MC',
		size = 40,
		patterns = {
			'molte?n' .. csep .. 'core?',
			sep .. 'mc' .. csep .. '4?0?' .. sep,
			create_achievement_pattern(686),
		},
	},

	{
		name = 'black temple25',
		instance_name = 'BT',
		size = 25,
		patterns = {
			'black' .. csep .. 'temple',
			'[%s-_,.]+bt' .. csep .. '25[%s-_,.]+',
			create_achievement_pattern(697),
		},
	},

	{
		name = 'sunwell25',
		instance_name = 'SWP',
		size = 25,
		patterns = {
			'sunwell' .. csep .. 'plateau',
			'swp' .. sep,
			sep .. 'swp',
			create_achievement_pattern(698),
		},
	},

	{
		name = 'ssc25',
		instance_name = 'SSC',
		size = 25,
		patterns = {
			'^ssc',
			sep .. 'ssc',
			'ssc' .. sep,
			'ssc' .. csep .. '$',
			'serpent' .. csep .. 'shrine' .. csep .. 'cavern',
			create_achievement_pattern(694),
		},
	},

	{
		name = 'aq40',
		instance_name = 'AQ40',
		size = 40,
		patterns = {
			'temple?' .. csep .. 'of?' .. csep .. 'ahn\'?' .. csep .. 'qiraj',
			sep .. '*aq' .. csep .. '40' .. csep .. '',
			create_achievement_pattern(687),
		},
	},

	{
		name = 'aq20',
		instance_name = 'AQ20',
		size = 20,
		patterns = {
			'ruins?' .. csep .. 'of?' .. csep .. 'ahn\'?' .. csep .. 'qiraj',
			'aq' .. csep .. '20',
			create_achievement_pattern(689),
		},
	},
}

local role_patterns = {
	dps = {

		're?t?r?i?b?u?t?i?o?n?' .. csep .. 'pal[al]?[dy]?i?n?',
		'fury',

		'sh?a?d?o?w?' .. csep .. 'pri?e?st',
		'pri?e?st' .. csep .. 'dps',
		'[^a-z]sp[^a-z]',

		'elem?e?n?t?a?l?' .. csep .. 'shamm?[iy]?',
		'mage[^a-z]',

		'boo?mm?[iy]?',
		'boo?mm?ki?n',
		'owl[^a-z]',
		'ba?l?a?n?c?e?' .. csep .. 'd[ru][ud][iu]d?',

		'rogu?e?' .. meta_or_sep,
		'roug?e?' .. meta_or_sep,

		'kitt?y',
		'cat[^a-z]',
		'feral' .. csep .. 'cat' .. sep,
		'feral' .. csep .. 'd?p?s?',

		'w?a?r?lock',
		'demol?i?t?i?o?n?',

		'hunte?r?s?',

		-- Español clases comunes DPS (añadido)
		'mago[s]?' .. meta_or_sep,
		'brujo[s]?' .. meta_or_sep,
		'cazador(?:es)?' .. meta_or_sep,
		'p[ií]caro[s]?' .. meta_or_sep,
		'sacerdote' .. csep .. 'sombra?' .. meta_or_sep,
		'sombra?' .. meta_or_sep,
		'cham[aá]n' .. csep .. 'elemental' .. meta_or_sep,
		'druida' .. csep .. 'balance' .. meta_or_sep,
		'druida' .. csep .. 'feral' .. meta_or_sep,

		-- Generic DPS keywords (EN/ES) even when people don't write "dps"
		role_sep .. 'melee' .. role_sep,
		'^melee' .. role_sep,
		role_sep .. 'mdps' .. role_sep,
		role_sep .. 'm' .. csep .. 'dps' .. role_sep,

		role_sep .. 'range' .. role_sep,     -- avoid "strange" via role_sep boundaries
		role_sep .. 'ranged' .. role_sep,
		'^ranged' .. role_sep,
		role_sep .. 'rdps' .. role_sep,
		role_sep .. 'r' .. csep .. 'dps' .. role_sep,

		role_sep .. 'caster' .. role_sep,
		role_sep .. 'casters' .. role_sep,
		role_sep .. 'cast' .. role_sep,

		-- Spanish common
		role_sep .. 'mel[eé]' .. role_sep,              -- "mele"/"melé"
		role_sep .. 'cuerpo' .. csep .. 'a' .. csep .. 'cuerpo' .. role_sep, -- "cuerpo a cuerpo"
		role_sep .. 'rango' .. role_sep,
		role_sep .. 'dist' .. csep .. 'ancia' .. role_sep, -- distancia
		role_sep .. 'distancia' .. role_sep,
		role_sep .. 'rango' .. csep .. 'dps' .. role_sep,
		role_sep .. 'magos?' .. role_sep,               -- sometimes "mago" used as role request
		role_sep .. 'caz?a' .. role_sep,                -- "caza" (hunter) shorthand

		-- Original short forms
		'm[dp][dp]s' .. meta_or_sep,
		'r[dp][dp]s',
		'dps',
	},

	healer = {
		-- Generic healer keywords (EN/ES)
		'he?a?l+e?r?s?' .. meta_or_sep, -- healer / healers
		'he?a?l+z?' .. meta_or_sep,     -- healz
		role_sep .. 'heal' .. role_sep,
		'^heal' .. role_sep,
		'heler',

		-- Spanish healer words
		role_sep .. 'healear' .. role_sep,
		role_sep .. 'curas?' .. role_sep,          -- cura/curas
		role_sep .. 'curar' .. role_sep,
		role_sep .. 'curandero' .. role_sep,
		role_sep .. 'sanador' .. role_sep,
		role_sep .. 'sanadores' .. role_sep,
		role_sep .. 'sana' .. role_sep,

		-- Español healers (añadido)
		'sanador(?:es)?' .. meta_or_sep,
		'curandero(?:s)?' .. meta_or_sep,
		'sacerdote' .. meta_or_sep,
		'sacerdote' .. csep .. 'sagrado' .. meta_or_sep,
		'sacerdote' .. csep .. 'disciplina' .. meta_or_sep,
		'palad[ií]n' .. csep .. 'sagrado' .. meta_or_sep,
		'druida' .. csep .. 'restauraci[oó]n' .. meta_or_sep,
		'cham[aá]n' .. csep .. 'restauraci[oó]n' .. meta_or_sep,

		-- Resto Druid
		're?s?t?o?' .. csep .. 'd[ru][ud][iu]d?', -- LF rdruid/rdudu
		meta_or_sep .. 'r' .. csep .. 'd[ru][ud][iu]d?', -- LF rdruid/rdudu
		'tree', -- LF tree

		-- Resto Shaman
		're?s?t?o?' .. csep .. 'shamm?y?', -- LF rsham
		meta_or_sep .. 'r' .. csep .. 'shamm?y?', -- LF rsham

		-- Priest heals
		'disco?[^a-z]',
		'dpri?e?st[^a-z]', -- disc priest
		meta_or_sep .. 'd' .. csep .. 'pri?e?st', -- disc priest
		role_sep .. 'hpri?e?st' .. role_sep,
		role_sep .. 'holy' .. csep .. 'pri?e?st' .. role_sep,

		-- Holy Paladin
		'ho?l?l?y?' .. csep .. 'pala?d?i?n?', -- LF holy pala
		meta_or_sep .. 'h' .. csep .. 'pala?d?i?n?', -- LF hpala

		-- Common shorthand people use on Spanish servers
		role_sep .. 'hpala' .. role_sep,
		role_sep .. 'hpal' .. role_sep,
		role_sep .. 'rsham' .. role_sep,
		role_sep .. 'rdruid' .. role_sep,
		role_sep .. 'rdudu' .. role_sep,
		role_sep .. 'disc' .. role_sep,
	},

	tank = {
		role_sep .. '[mo]t' .. role_sep, -- Need MT/OT
		role_sep .. '[mo]t' .. csep .. '$', -- Need MT/OT
		'ta*n+a?k+s?', -- NEED TANKS
		'b[ea][ea]+rs?',
		'prote?c?t?i?o?n?', -- NEED PROT PALA/WARRI
	},
}
local gearscore_patterns = {
	'[1-6].?[0-9]?kgs',
	'[1-6]' .. csep .. 'k[0-9]+',
	'[1-6][.,][0-9]',
	'[1-6]' .. csep .. 'k' .. csep .. '%+',
	'[1-6]' .. csep .. 'k' .. sep,
	'%+?' .. csep .. '[1-6]' .. csep .. 'k' .. sep,
	'[1-6][0-9][0-9][0-9]',
	'[1-6]%+',
}

local guild_recruitment_patterns = {
	'recrui?ti?n?g?',
	'we' .. csep .. 'raid',
	'we' .. csep .. 'are' .. csep .. 'raidi?n?g?',
	'[<({-][%a%s]+[-})>]' .. csep .. 'is' .. csep .. 'a?', -- (<GuildName> is a) pve guild looking for
	'is' .. csep .. '[%a%s]*playe?rs?',
	'[0-9][0-9][pa]m' .. csep .. 'st', -- we raid (12pm set)
	'autorecruit',
	'raid' .. csep .. 'time',
	'active' .. csep .. 'raiders?',
	'is' .. csep .. 'a' .. csep .. '[%a]*' .. csep .. '[pvep][pvep][pvep]' .. csep .. 'guild',
	'lf' .. sep .. 'members',
	-- Spanish guild recruitment keywords
	'hermandad',
	'gremio',
	'recluta',
	'reclutando',
	'busc' .. csep .. 'miembros',
	'buscamos' .. csep .. 'jugadores?',
	'busca' .. csep .. 'jugadores?',
	'para' .. csep .. 'raids?',
	'raids?' .. csep .. 'fijas?',
	'horari?os?',
	'progres[oi]',
	'progress',
};

local trade_message_patterns = {
	'wts' .. sep,
	'wtb' .. sep,
	'selling' .. sep,
	'buying' .. sep,
};

local rolelist_patterns = {
	meta_role .. non_meta .. 'and' .. non_meta .. meta_role,
	meta_role .. non_meta .. 'or' .. non_meta .. meta_role,
	meta_role .. non_meta .. meta_role,
};

local lfm_patterns = {
	lfm .. non_meta .. meta_role .. non_meta .. meta_raid,

	meta_raid .. non_meta .. sep .. '[0-9]+' .. non_meta .. meta_role,

	lfm .. csep .. '[0-9]*' .. csep .. meta_role .. non_meta .. meta_gs .. '.*' .. meta_raid,
	lfm .. csep .. 'all' .. non_meta .. meta_raid,
	'nee?d' .. csep .. 'all' .. non_meta .. meta_raid,
	'seek' .. csep .. 'all' .. non_meta .. meta_raid,

	meta_raid .. non_meta .. lfm .. csep .. 'all',
	meta_raid .. non_meta .. 'nee?d' .. csep .. 'all',
	meta_raid .. non_meta .. meta_gs .. non_meta .. 'lf' .. csep .. 'all',
	meta_raid .. non_meta .. meta_gs .. non_meta .. 'seek' .. csep .. 'all',
	meta_raid .. non_meta .. meta_gs .. non_meta .. 'nee?d' .. csep .. 'all',

	meta_raid .. non_meta .. meta_role .. non_meta .. meta_gs,
	meta_raid .. non_meta .. 'nee?d' .. non_meta .. meta_role,
	meta_raid .. non_meta .. 'seek' .. non_meta .. meta_role,

	meta_raid .. non_meta .. lfm .. non_meta .. meta_role,
	meta_raid .. non_meta .. 'looki?ng' .. csep .. 'for' .. non_meta .. meta_role,

	meta_raid .. non_meta .. 'nee?d' .. csep .. 'all',

	meta_raid .. non_meta .. meta_gs .. non_meta .. meta_role,

	meta_role .. non_meta .. 'for' .. non_meta .. meta_raid,

	meta_raid .. non_meta .. sep .. 'loot' .. sep .. non_meta .. 'wh?i?s?p?e?r?' .. csep .. 'me',

	meta_raid .. non_meta .. meta_gs .. non_meta .. 'wh?i?s?p?e?r?' .. csep .. 'me',
	meta_raid .. non_meta .. meta_gs .. non_meta .. 'wh?i?s?p?e?r?' .. csep .. '[A-Z][a-z]+',

	meta_raid .. non_meta .. non_meta .. 'wh?i?s?p?e?r?' .. csep .. 'me' .. non_meta .. meta_gs,
	meta_raid .. non_meta .. non_meta .. 'wh?i?s?p?e?r?' .. csep .. '[A-Z][a-z]+' .. non_meta .. meta_gs,

	meta_raid .. non_meta .. 'run' .. non_meta .. meta_gs,

	'[0-9]' .. non_meta .. meta_role .. non_meta .. meta_raid,

	meta_raid .. non_meta .. 'reserved',

	lfm .. non_meta .. meta_raid,

	meta_raid .. non_meta .. meta_role,
	'new' .. csep .. 'run' .. meta_raid,
}

local guild_recruitment_metapatterns = {
	meta_guild .. non_meta .. meta_raid,
};

local guild_patterns = {
	'^guild' .. psep .. '[a-z]+[%s][a-z]*' .. psep,
	'^guild' .. sep .. '[a-z]+[%s][a-z]*',
};

local lfg_patterns = {
	'^' .. csep .. 'lfg' .. non_meta .. meta_raid,
	'^' .. csep .. meta_gs .. non_meta .. meta_role .. non_meta .. 'looking' .. csep .. 'for' .. non_meta .. meta_raid,
	meta_role .. non_meta .. meta_gs .. non_meta .. 'looking' .. csep .. 'for' .. non_meta .. meta_raid,

	'^' .. csep .. meta_gs .. non_meta .. meta_role .. non_meta .. 'lf' .. non_meta .. meta_raid,
	meta_role .. non_meta .. meta_gs .. non_meta .. 'lf' .. non_meta .. meta_raid,
};

---@param message string
---@param patterns table
---@return boolean
---@nodiscard
local function matches_any_pattern(message, patterns, debug)
	return std.algorithm.find_if(patterns, function(pattern)
		local result = message:find(pattern)
		if debug and result then
			RaidBrowser:Print("Pattern matched: " .. pattern)
		end
		return result;
	end) ~= nil;
end

---@param message string
---@return boolean
---@nodiscard
local function is_lfm_message(message, debug)
	return matches_any_pattern(message, lfm_patterns, debug);
end

---@param message string
---@return boolean
---@nodiscard
local function is_guild_recruitment(message, debug)
	-- Detect guild recruitment / progression spam (EN+ES)
	if not matches_any_pattern(message, guild_recruitment_patterns, debug) then
		return false
	end

	-- If the message clearly looks like someone forming a group (LFM/LFG), do NOT treat it as recruitment.
	-- This prevents false negatives like: "Guild run LFM ICC 25H need heal"
	local lfm_intent_patterns = {
		'lfm' .. sep,
		'lf' .. sep,          -- "lf tank"
		'need' .. sep,
		'looking' .. csep .. 'for',
		'busc' .. sep,        -- "busco/buscamos"
		'necesit' .. sep,     -- "necesito/necesitamos"
		'falta' .. sep,       -- "falta/faltan"
		'faltan' .. sep,
		'inv' .. sep,         -- invite
		'invite' .. sep,
		'invita' .. sep,      -- Spanish invite
		'para' .. csep .. meta_raid, -- "para icc"
	}
	if matches_any_pattern(message, lfm_intent_patterns, false) then
		return false
	end

	return true
end

---@param message string
---@return boolean
---@nodiscard
local function is_lfg_message(message, debug)
	return matches_any_pattern(message, lfg_patterns, debug);
end

---@param message string
---@return boolean
---@nodiscard
local function is_trade_message(message, debug)
	return matches_any_pattern(message, trade_message_patterns, debug);
end

-- Basic http pattern matching for streaming sites and etc.
---@param message string
---@return string, integer?
---@nodiscard
local function remove_http_links(message)
	local http_pattern = 'https?://*[%a]*.[%a]*.[%a]*/?[%a%-%%0-9_]*/?';
	return message:gsub(http_pattern, '');
end

---@param message string
---@return string, integer?
---@nodiscard
local function lex_achievements(message)
	local achievement_pattern = '\124cffffff00\124h.*\124h(%[.*%])\124h\124r';
	return message:gsub(achievement_pattern, '%1');
end

---@param message string
---@return string
---@nodiscard
local function lex_guild_recruitments(message)
	for _, pattern in ipairs(guild_patterns) do
		message = message:gsub(pattern, meta_guild);
	end

	return message;
end

---@param roles table
---@param message string
---@param role "healer"|"dps"|"tank"
---@return table, string
---@nodiscard
local function lex_roles(roles, message, role, debug)
	local found = false;

	for _, pattern in ipairs(role_patterns[role]) do
		local m, result = message:gsub(pattern, meta_role);

		if result > 0 then
			if debug then
				RaidBrowser:Print('Role pattern found for '.. role .. ': ' .. pattern)
			end
			message = m;
			found = true;
		end
	end

	if found then table.insert(roles, role) end
	return roles, message;
end

---@param gs_str string
---@return string
---@nodiscard
local function format_gs_string(gs_str)
	local formatted = gs_str:gsub(sep .. '*%+?', ''); -- Trim whitespace
	formatted = formatted:gsub('[kgs]', '')
	formatted = formatted:gsub(sep, '.');
	local gs = tonumber(formatted);

	-- Convert ex: 5800 into 5.8 for display
	if gs > 1000 then
		gs = gs / 1000;

		-- Convert 57.0 into 5.7
	elseif gs > 100 then
		gs = gs / 100;

		-- Convert 57.0 into 5.7
	elseif gs > 10 then
		gs = gs / 10;
	end

	return string.format('%.1f', gs);
end

---@param message string
---@return string?, string, integer?
---@nodiscard
local function lex_gs_req(message)
	for _, pattern in pairs(gearscore_patterns) do
		local gs_text = message:match(pattern);
		if gs_text then
			-- Extract gs and replace it with the gearscore nonterminal
			return format_gs_string(gs_text),
				-- TODO: Check for valid pattern
				message:gsub(gs_text, meta_gs)
		end
	end

	return nil, message;
end

---@param message string
---@return table?, string?, integer?
---@nodiscard
function RaidBrowser.lex_raid_info(message, debug)

	local raid;
	local num_unique_raids = 0;
	local raid_pattern_index;
	for _, r in ipairs(raid_list) do
		local message_index;
		local index = std.algorithm.find_if(r.patterns, function(pattern)
			pattern = pattern:lower();
			message_index = message:find(pattern);

			if message_index ~= nil then
				local m, result = message:gsub(pattern, meta_raid);

				if result > 0 then
					if debug then
						RaidBrowser:Print("Raid found! " .. r.name .. ": " .. pattern);
					end
					message = m;
					return true;
				end
			end

			return false;
		end);

		if index then
			-- only count as new unique raid, if previously found raid was a different zone
			if not raid or (RaidBrowser.get_short_raid_name(r.name) ~= RaidBrowser.get_short_raid_name(raid.name)) then
				num_unique_raids = num_unique_raids + 1;
				if debug and raid then
					RaidBrowser:Print("Mutliple raids found! " .. r.name .. " - " .. raid.name)
				end
			end

			-- overwrite raid choice only if new raid is prioritized or found earlier in message (as people post hc achievements after declaring nm)
			if (raid_pattern_index == nil or (raid and r.prioritized and not raid.prioritized) or raid_pattern_index > message_index) then
				raid_pattern_index = message_index
				raid = r;
			end
		end
	end

	if not raid then return end
	return raid, message, num_unique_raids;
end

---@param message string
---@return boolean
---@nodiscard
local function has_guild_recruitment_production(message)
	return matches_any_pattern(message, guild_recruitment_metapatterns)
end

---@param message string
---@return string
---@nodiscard
local function reduce_rolelists(message)
	local sub_count = 0;

	repeat
		local results = std.algorithm.transform(rolelist_patterns, function(pattern)
			local t = { message:gsub(pattern, meta_role) };
			message = t[1];
			return t[2];
		end
		);

		sub_count = std.algorithm.find_if(results, function(x) return x > 0 end) or 0;
	until sub_count == 0

	return message;
end

---@param message any
---@return string?, table?, table?, string?
---@nodiscard
function RaidBrowser.lex_and_extract(message, debug)
	if not message then return end
	message = message:lower();
	message = remove_http_links(message);

	-- Stop if it's a guild recruit/wts message
	if is_guild_recruitment(message) or is_trade_message(message) then
		return;
	end

	-- Remove any instances of the meta character
	message = message:gsub(meta_char, '');

	message = lex_guild_recruitments(message);

	-- Get the raid_info from the message
	local raid_info, raid_lexed_message, num_unique_raids = RaidBrowser.lex_raid_info(message, debug);
	if not raid_info or not raid_lexed_message or not num_unique_raids then return end

	if has_guild_recruitment_production(raid_lexed_message) then return end

	-- If there are multiple distinct raids, then it is most likely a recruitment message.
	if num_unique_raids > 1 then return end

	raid_lexed_message = lex_achievements(raid_lexed_message);

	-- Get any roles that are needed
	local roles = {};

	if not raid_lexed_message:find('lfm? all ') and not raid_lexed_message:find('nee?d all ') then
		roles, raid_lexed_message = lex_roles(roles, raid_lexed_message, 'dps', debug);
		roles, raid_lexed_message = lex_roles(roles, raid_lexed_message, 'tank', debug);
		roles, raid_lexed_message = lex_roles(roles, raid_lexed_message, 'healer', debug);
	end

	-- If there is only an LFM message, then it is assumed that all roles are needed
	if #roles == 0 then
		roles = { 'dps', 'tank', 'healer' }
	end

	-- Search for a gearscore requirement.
	local gs, gs_lexed_message = lex_gs_req(raid_lexed_message);
	gs_lexed_message = reduce_rolelists(gs_lexed_message);

	return gs_lexed_message, raid_info, roles, gs or ' ';
end

---@param message string
---@return table?, table?, string?
---@nodiscard
function RaidBrowser.raid_info(message, debug)
	local lexed_message, raid_info, roles, gs = RaidBrowser.lex_and_extract(message, debug);

	if not lexed_message then return end

	-- Any message that is lexed out to be an lfg is excluded (unfortunately near the end).
	if is_lfg_message(lexed_message, debug) then return end

	-- Parse symbols to determine if the message is valid
	if not is_lfm_message(lexed_message, debug) then return end

	return raid_info, roles, gs or ' ';
end

function RaidBrowser.get_short_raid_name(raid_name)
	return string.gsub(raid_name, '[1|2][0|5](%w*)', '');
end

--[[ Event handlers and listeners ]] --
RaidBrowserLfmChannelListeners = {
	['CHAT_MSG_CHANNEL'] = {},
	['CHAT_MSG_YELL'] = {},
};

local channel_listeners = {};

---@param channel string
---@return boolean
---@nodiscard
local function is_lfm_channel(channel)
	return channel == 'CHAT_MSG_CHANNEL' or channel == 'CHAT_MSG_YELL';
end

---@diagnostic disable-next-line: unused-local
---@param self any
---@param event string
---@param message string
---@param sender string
local function event_handler(self, event, message, sender)
	if is_lfm_channel(event) then
		local raid_info, roles, gs = RaidBrowser.raid_info(message)
		if raid_info and roles and gs then

			-- Put the sender in the table of active raids
			RaidBrowser.lfm_messages[sender] = {
				raid_info = raid_info,
				roles = roles,
				gs = gs,
				time = time(),
				message = message,
				sender = sender
			};

			RaidBrowser.gui.update_list();
		end
	end
end

local function refresh_lfm_messages()
	-- Requesting lock info each time a tooltip is produced creates a lot of lag.
	-- This is a better alternative
	RequestRaidInfo();

	for name, info in pairs(RaidBrowser.lfm_messages) do
		-- If the last message from the sender was too long ago, then
		-- remove his raid from lfm_messages.
		if time() - info.time > RaidBrowser.expiry_time then
			RaidBrowser.lfm_messages[name] = nil;
		end
	end
end

function RaidBrowser:OnEnable()
	---@diagnostic disable-next-line: undefined-field
	RaidBrowser:Print('loaded. Type /rb to toggle the raid browser.')

	if not RaidBrowserCharacterCurrentRaidset then
		RaidBrowserCharacterCurrentRaidset = 'Active';
	end

	if not RaidBrowserCharacterRaidsets then
		RaidBrowserCharacterRaidsets = {
			Primary = {},
			Secondary = {},
		};
	end

	-- LFM messages expire after 60 seconds
	RaidBrowser.expiry_time = 60;

	RaidBrowser.lfm_messages = {}
	RaidBrowser.timer = RaidBrowser.set_timer(10, refresh_lfm_messages, true)
	for channel, _ in pairs(RaidBrowserLfmChannelListeners) do
		table.insert(channel_listeners, RaidBrowser.add_event_listener(channel, event_handler))
	end

	RaidBrowser.gui.raidset.initialize();
end

function RaidBrowser:OnDisable()
	for channel, listener in pairs(RaidBrowserLfmChannelListeners) do
		RaidBrowser.remove_event_listener(channel, listener)
	end

	RaidBrowser.kill_timer(RaidBrowser.timer)
end
