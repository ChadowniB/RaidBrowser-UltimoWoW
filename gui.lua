---@diagnostic disable: undefined-field
RaidBrowser.gui = {}
RaidBrowserClassCache = RaidBrowserClassCache or {}
RaidBrowserGuildCache = RaidBrowserGuildCache or {}
local CLASS_BY_LOCALIZED = {}
do
	if LOCALIZED_CLASS_NAMES_MALE then
		for token, loc in pairs(LOCALIZED_CLASS_NAMES_MALE) do CLASS_BY_LOCALIZED[loc] = token end
	end
	if LOCALIZED_CLASS_NAMES_FEMALE then
		for token, loc in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do CLASS_BY_LOCALIZED[loc] = token end
	end
end

local function short_name(n)
	n = n and tostring(n)
	return n and (n:match("^[^-]+") or n) or nil
end

local function cache_key(n)
	n = short_name(n)
	return n and n:lower() or nil
end

local rbWho = CreateFrame("Frame")
rbWho:RegisterEvent("WHO_LIST_UPDATE")

local WHO_QUEUE, WHO_INFLIGHT, WHO_NEXT_TIME = {}, nil, 0

local function queue_who(name)
	local k = cache_key(name)
	if not k then return end
	
	if (RaidBrowserClassCache[k] and RaidBrowserGuildCache[k]) or WHO_INFLIGHT == k or WHO_QUEUE[k] then return end
	WHO_QUEUE[k] = true
end

local function send_next_who()
	if WHO_INFLIGHT or GetTime() < WHO_NEXT_TIME then return end

	local nextKey
	for k in pairs(WHO_QUEUE) do nextKey = k; break end
	if not nextKey then return end

	WHO_QUEUE[nextKey] = nil
	WHO_INFLIGHT = nextKey
	WHO_NEXT_TIME = GetTime() + 1.2
	SendWho("n-" .. nextKey)
end

rbWho:SetScript("OnEvent", function()
	local inflight = WHO_INFLIGHT
	if not inflight then return end

	for i = 1, GetNumWhoResults() do
		
		local name, guild, _, _, class = GetWhoInfo(i)
		if name then
			local s = short_name(name)
			if s and s:lower() == inflight then
				local tbl = RaidBrowser.lfm_messages

				local token = class and CLASS_BY_LOCALIZED[class]
				if token then
					RaidBrowserClassCache[inflight] = token
					if tbl then
						
						local info = tbl[s] or tbl[name] or tbl[inflight]
						if info then
							info.classToken = token
						else
							
							for sender, info2 in pairs(tbl) do
								if sender and sender:lower() == inflight and info2 then
									info2.classToken = token
									break
								end
							end
						end
					end
				end

				if guild and guild ~= "" then
					RaidBrowserGuildCache[inflight] = guild
					if tbl then
						local info = tbl[s] or tbl[name] or tbl[inflight]
						if info then
							info.guildName = guild
						else
							for sender, info2 in pairs(tbl) do
								if sender and sender:lower() == inflight and info2 then
									info2.guildName = guild
									break
								end
							end
						end
					end
				end

				break
			end
		end
	end

	WHO_INFLIGHT = nil
	if RaidBrowser.gui and RaidBrowser.gui.update_list then
		RaidBrowser.gui.update_list()
	end
end)

rbWho:SetScript("OnUpdate", send_next_who)

local function normalize_class_token(token)
	if not token then return nil end
	token = tostring(token):upper()
	if token == "DK" then token = "DEATHKNIGHT"
	elseif token == "PALA" or token == "PAL" then token = "PALADIN"
	elseif token == "WARR" then token = "WARRIOR"
	elseif token == "LOCK" then token = "WARLOCK"
	elseif token == "SHAM" then token = "SHAMAN"
	end
	return (RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]) and token or nil
end

local function get_class_token(host_name, lfm_info)
	if lfm_info then
		local t = lfm_info.classToken or lfm_info.class or lfm_info.playerClass
		if not t and lfm_info.raid_info then
			t = lfm_info.raid_info.classToken or lfm_info.raid_info.class
		end
		t = normalize_class_token(t)
		if t then return t end
	end
	local k = cache_key(host_name)
	return (k and RaidBrowserClassCache[k]) or nil
end

local function get_guild_name(host_name, lfm_info)
	if lfm_info and lfm_info.guildName and lfm_info.guildName ~= "" then
		return lfm_info.guildName
	end
	local k = cache_key(host_name)
	return (k and RaidBrowserGuildCache[k]) or nil
end

local function set_name_color(button, host_name, lfm_info)
	local rep = RaidBrowser.rep_get(host_name) or 0
	if rep > 0 then button.name:SetTextColor(0, 1, 0); return end
	if rep < 0 then button.name:SetTextColor(1, 0.2, 0.2); return end

	local t = get_class_token(host_name, lfm_info)
	if t and RAID_CLASS_COLORS and RAID_CLASS_COLORS[t] then
		local c = RAID_CLASS_COLORS[t]
		button.name:SetTextColor(c.r, c.g, c.b)
	else
		button.name:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
		queue_who(host_name)
	end
end

local search_button = LFRQueueFrameFindGroupButton
local join_button   = LFRBrowseFrameInviteButton

local name_column     = LFRBrowseFrameColumnHeader1
local gs_list_column  = LFRBrowseFrameColumnHeader2
local raid_list_column= LFRBrowseFrameColumnHeader3

local sort_column, sort_ascending, difficulty_rank = nil, false, nil

local function sl(x)
	x = x and tostring(x) or ""
	return x:lower()
end

local function sn(x)
	x = tonumber(x)
	return x or 0
end

local function sort_function(a, b)

	if a == b then return false end

	a = a or {}; b = b or {}
	local ar = a.raid_info or {}; local br = b.raid_info or {}

	local va, vb

	if sort_column == "name" then
		va, vb = sl(a.sender), sl(b.sender)

	elseif sort_column == "gs" then
		va, vb = sn(a.gs), sn(b.gs)

	elseif sort_column == "instance" then
		va, vb = sl(ar.instance_name or ar.name), sl(br.instance_name or br.name)

	elseif sort_column == "mode" then
		va, vb = sn(a.mode_sort), sn(b.mode_sort)

	elseif sort_column == "rep" then
		va, vb = sn(a.rep_score), sn(b.rep_score)

	else
		va, vb = sn(a.time), sn(b.time)
	end

	if va ~= vb then
		if sort_ascending then return va < vb else return va > vb end
	end

	local sa, sb = sl(a.sender), sl(b.sender)
	if sa ~= sb then return sa < sb end

	local ta, tb = sn(a.time), sn(b.time)
	if ta ~= tb then return ta < tb end

	return false
end

local function set_sort(column)
	if sort_column == column then
		sort_ascending = not sort_ascending
	else
		sort_column = column
	end
	if RaidBrowser.gui then RaidBrowser.gui.update_list() end
end

local function get_sorted_messages()
	local keys = {}
	for _, info in pairs(RaidBrowser.lfm_messages or {}) do
		if info and info.sender and info.raid_info then
			local k = cache_key(info.sender)
			if k then
				local ct = RaidBrowserClassCache[k]
				if ct and not info.classToken then info.classToken = ct end

				local gn = RaidBrowserGuildCache[k]
				if gn and not info.guildName then info.guildName = gn end
			end

			info.rep_score = RaidBrowser.rep_get(info.sender) or 0
			local size = tonumber(info.raid_info.size) or 0
			local dr = (difficulty_rank and difficulty_rank(info.raid_info)) or 0
			info.mode_sort = size * 10 + dr

			if not (RaidBrowserReputationOptions and RaidBrowserReputationOptions.hideBlocked and info.rep_score < 0) then
				keys[#keys + 1] = info
			end
		end
	end

	
	local ok = pcall(table.sort, keys, sort_function)
	if not ok then
		
		table.sort(keys, function(a, b) return sl(a and a.sender) < sl(b and b.sender) end)
	end

	return keys
end

name_column:SetScript("OnClick", function() set_sort("name") end)

gs_list_column:SetText("GS")
gs_list_column:SetScript("OnClick", function() set_sort("gs") end)

raid_list_column:SetText("Instance")
raid_list_column:SetScript("OnClick", function() set_sort("instance") end)

name_column:SetWidth(90)
gs_list_column:SetWidth(35)
raid_list_column:SetWidth(120)

for i = 4, 7 do
	local hdr = _G["LFRBrowseFrameColumnHeader" .. i]
	if hdr then hdr:Hide(); hdr:EnableMouse(false) end
end

difficulty_rank = function(raid_info)
	local n = ((raid_info and raid_info.name) or ""):lower()
	if n:find("hc", 1, true) then return 3 end
	if n:find("nm", 1, true) then return 2 end
	if n:find("rep", 1, true) then return 1 end
	return 0
end

local function get_mode_text(raid_info)
	if not raid_info then return "" end
	local size = raid_info.size or 0
	local r = difficulty_rank(raid_info)
	local diff = (r == 3 and "H") or (r == 2 and "N") or (r == 1 and "Rep") or ""
	return (size and size > 0) and (tostring(size) .. diff) or diff
end

local function on_join()
	local raid_message = RaidBrowser.lfm_messages and RaidBrowser.lfm_messages[LFRBrowseFrame.selectedName]
	if not raid_message or not raid_message.raid_info then return end
	local message = RaidBrowser.stats.build_join_message(raid_message.raid_info.name)
	SendChatMessage(message, "WHISPER", nil, LFRBrowseFrame.selectedName)
end

join_button:SetText("Unirse")
join_button:SetScript("OnClick", on_join)

local thumb_up = CreateFrame("Button", nil, LFRBrowseFrame)
thumb_up:SetSize(40, 40)
thumb_up:SetPoint("BOTTOMRIGHT", LFRBrowseFrameRefreshButton, "TOPRIGHT", 40, 0)
thumb_up.icon = thumb_up:CreateTexture(nil, "ARTWORK")
thumb_up.icon:SetAllPoints()
thumb_up.icon:SetTexture("Interface\\AddOns\\RaidBrowser\\thumbsup.blp")
thumb_up:SetScript("OnClick", function()
	local name = LFRBrowseFrame.selectedName
	if not name then return end
	RaidBrowser.rep_vote(name, 1)
	RaidBrowser.gui.update_list()
end)

local thumb_down = CreateFrame("Button", nil, LFRBrowseFrame)
thumb_down:SetSize(30, 30)
thumb_down:SetPoint("RIGHT", thumb_up, "LEFT", 30, -35)
thumb_down.icon = thumb_down:CreateTexture(nil, "ARTWORK")
thumb_down.icon:SetAllPoints()
thumb_down.icon:SetTexture("Interface\\AddOns\\RaidBrowser\\thumbsdown.blp")
thumb_down:SetScript("OnClick", function()
	local name = LFRBrowseFrame.selectedName
	if not name then return end
	RaidBrowser.rep_vote(name, -1)
	RaidBrowser.gui.update_list()
end)

local hide_blocked = CreateFrame("CheckButton", nil, LFRBrowseFrame, "UICheckButtonTemplate")
hide_blocked:SetPoint("RIGHT", thumb_down, "LEFT", 61, 0)
hide_blocked.text = hide_blocked:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hide_blocked.text:SetPoint("LEFT", hide_blocked, "RIGHT", -10, 1)
hide_blocked.text:SetText("OCULTAR MALA REP")
hide_blocked.text:SetTextColor(1, 0.1, 0.1)
hide_blocked.text:SetWidth(80)
hide_blocked:SetHitRectInsets(0, 0, 0, 0)
hide_blocked:SetChecked(RaidBrowserReputationOptions and RaidBrowserReputationOptions.hideBlocked)
hide_blocked:SetScript("OnClick", function(self)
	RaidBrowserReputationOptions = RaidBrowserReputationOptions or {}
	RaidBrowserReputationOptions.hideBlocked = self:GetChecked() and true or false
	RaidBrowser.gui.update_list()
end)

local function plural(n, one, many) return (n == 1) and one or many end

local function format_seconds(seconds)
	local n = tonumber(seconds) or 0
	if n <= 0 then return "00 seconds" end

	local out = ""

	if n >= 86400 then
		local d = math.floor(n / 86400)
		out = out .. d .. " " .. plural(d, "day ", "days ")
		n = n % 86400
	end
	if n >= 3600 then
		local h = math.floor(n / 3600)
		out = out .. h .. " " .. plural(h, "hr ", "hrs ")
		n = n % 3600
	end
	if n >= 60 then
		local m = math.floor(n / 60)
		out = out .. m .. " " .. plural(m, "min ", "mins ")
	end

	return out
end

LFRBrowseFrameRaidDropDown:Hide()
search_button:SetText("Find Raid")
search_button:SetScript("OnClick", function() end)

local function clear_highlights()
	for i = 1, NUM_LFR_LIST_BUTTONS do
		_G["LFRBrowseFrameListButton" .. i]:UnlockHighlight()
	end
end

local function assign_lfr_button(button, host_name, lfm_info, index)
	if not (button and host_name and lfm_info and lfm_info.raid_info) then return end

	local offset = FauxScrollFrame_GetOffset(LFRBrowseFrameListScrollFrame)
	button.index = index
	index = index - offset

	button.lfm_info = lfm_info
	button.raid_info = lfm_info.raid_info
	button.unitName = host_name

	button.name:SetText(host_name)
	button.level:SetText(button.lfm_info.gs or " ")
	button.class:SetText(button.raid_info.instance_name or button.raid_info.name or " ")

	if not button.modeText then
		button.modeText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		button.modeText:SetPoint("LEFT", button, "LEFT", 280, 0)
	end
	button.modeText:SetText(get_mode_text(button.raid_info))

	button.raid_locked, button.raid_reset_time = RaidBrowser.stats.raid_lock_info(button.raid_info)
	button.type = "party"

	if button.partyIcon then button.partyIcon:Hide() end
	button.tankIcon:Hide(); button.healerIcon:Hide(); button.damageIcon:Hide()

	for _, role in pairs(button.lfm_info.roles or {}) do
		if role == "tank" then button.tankIcon:Show()
		elseif role == "healer" then button.healerIcon:Show()
		elseif role == "melee_dps" or role == "ranged_dps" or role == "dps" then button.damageIcon:Show()
		end
	end

	button:Enable()

	set_name_color(button, host_name, lfm_info)
	button.level:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	button.class:SetTextColor(button.raid_locked and 1 or 0, button.raid_locked and 0 or 1, button.raid_locked and 0 or 1)

	button.tankIcon:SetTexture("Interface\\LFGFrame\\LFGRole")
	button.healerIcon:SetTexture("Interface\\LFGFrame\\LFGRole")
	button.damageIcon:SetTexture("Interface\\LFGFrame\\LFGRole")

	button:SetScript("OnEnter", function(lfr_button)
		GameTooltip:SetOwner(lfr_button, "ANCHOR_RIGHT")
		local now = time()
		local seconds = now - (lfr_button.lfm_info.time or now)

		GameTooltip:AddLine(lfr_button.lfm_info.message or "", 1, 1, 1, true)
		GameTooltip:AddLine(string.format("Last sent: %d seconds ago", seconds))

		local g = get_guild_name(lfr_button.unitName, lfr_button.lfm_info)
		if g and g ~= "" then
			GameTooltip:AddLine("Hermandad: <" .. g .. ">", 0.2, 1, 0.2)
		else
			queue_who(lfr_button.unitName)
		end

		local rep = RaidBrowser.rep_get(lfr_button.unitName) or 0
		if rep ~= 0 then GameTooltip:AddLine(string.format("Reputation: %d", rep)) end

		if lfr_button.raid_locked then
			GameTooltip:AddLine("\nYou are |cffff0000saved|cffffd100 for " .. (lfr_button.raid_info.name or ""))
			GameTooltip:AddLine("Lockout expires in " .. format_seconds(lfr_button.raid_reset_time))
		else
			GameTooltip:AddLine("\nYou are |cff00ffffnot saved|cffffd100 for " .. (lfr_button.raid_info.name or ""))
		end

		GameTooltip:Show()
	end)

	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function insert_lfm_button(button, index)
	local sorted = get_sorted_messages()
	local info = sorted[index]
	if info then assign_lfr_button(button, info.sender, info, index) end
end

local function update_buttons()
	LFRBrowseFrameSendMessageButton:Enable()
	LFRBrowseFrameSendMessageButton:SetText("Envio mesaje")
	LFRBrowseFrameInviteButton:Enable()
end

local function clear_list()
	for i = 1, NUM_LFR_LIST_BUTTONS do
		local b = _G["LFRBrowseFrameListButton" .. i]
		b:Hide(); b:UnlockHighlight()
		if b.partyIcon then b.partyIcon:Hide() end
		if b.modeText then b.modeText:SetText("") end
	end
end

function RaidBrowser.gui.update_list()
	LFRBrowseFrameRefreshButton.timeUntilNextRefresh = LFR_BROWSE_AUTO_REFRESH_TIME
	LFRBrowseFrameRefreshButton:SetText("Actualizar")

	local sorted = get_sorted_messages()
	local numResults = #sorted
	FauxScrollFrame_Update(LFRBrowseFrameListScrollFrame, numResults, NUM_LFR_LIST_BUTTONS, 16)

	local offset = FauxScrollFrame_GetOffset(LFRBrowseFrameListScrollFrame)
	clear_list()

	for i = 1, NUM_LFR_LIST_BUTTONS do
		local b = _G["LFRBrowseFrameListButton" .. i]
		local idx = i + offset
		if idx <= numResults then
			local info = sorted[idx]
			if info then assign_lfr_button(b, info.sender, info, idx) end
			b:Show()
		else
			b:Hide()
		end
	end

	clear_highlights()

	for i = 1, NUM_LFR_LIST_BUTTONS do
		local b = _G["LFRBrowseFrameListButton" .. i]
		if LFRBrowseFrame.selectedName == b.unitName then b:LockHighlight() else b:UnlockHighlight() end
		update_buttons()
	end
end

LFRBrowse_UpdateButtonStates = update_buttons
LFRBrowseFrameList_Update = RaidBrowser.gui.update_list
LFRBrowseFrameListButton_SetData = insert_lfm_button

if LFRBrowseFrame and LFRBrowseFrameTitle then
	LFRBrowseFrameTitle:SetText("Raid's de UltimoWoW")
end

LFRFrame_SetActiveTab(2)
LFRParentFrameTab1:Hide()
LFRParentFrameTab2:Hide()