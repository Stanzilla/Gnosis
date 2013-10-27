local UnitCastingInfo = UnitCastingInfo;
local UnitChannelInfo = UnitChannelInfo;
local GetItemInfo = GetItemInfo;
local GetSpellInfo = GetSpellInfo;
local GetSpellCooldown = GetSpellCooldown;
local GetTime = GetTime;
local UnitAura = UnitAura;
local GetItemCooldown = GetItemCooldown;
local GetRuneCooldown = GetRuneCooldown;
local GetRuneType = GetRuneType;
local GetTotemInfo = GetTotemInfo;
local GetWeaponEnchantInfo = GetWeaponEnchantInfo;
local GetInventoryItemTexture = GetInventoryItemTexture;
local UnitExists = UnitExists;
local UnitPower = UnitPower;
local UnitPowerMax = UnitPowerMax;
local UnitHealth = UnitHealth;
local UnitHealthMax = UnitHealthMax;
local UnitAlternatePowerInfo = UnitAlternatePowerInfo;
local UnitAlternatePowerTextureInfo = UnitAlternatePowerTextureInfo;
local UnitGetIncomingHeals = UnitGetIncomingHeals;
local select = select;
local pairs = pairs;
local ipairs = ipairs;
local wipe = wipe;
local tonumber = tonumber;
local string_find = string.find;
local string_match = string.match;
local string_gmatch = string.gmatch;
local string_trim = strtrim;
local string_gsub = string.gsub;
local string_len = strlenutf8;
local string_lower = string.lower;
local strconcat = strconcat;
local table_insert = table.insert;

-- local variables
local _;

local function in_value_range(cur_val, cur_val_perc, range_tab)
	--[[ range_tab structure
		[1] == value lower bound (>=)
		[2] == value upper bound (<=)
		[3] == stacks lower bound (>=)
		[4] == stacks upper bound (<=)
		[5] == value lower bound is in percent (true, nil)
		[6] == value upper bound is in percent (true, nil) ]]

	if(range_tab[1]) then
		if(range_tab[5]) then
			if(cur_val_perc < range_tab[1]) then
				return false;
			end
		elseif(cur_val < range_tab[1]) then
			return false;
		end
	end

	if(range_tab[2]) then
		if(range_tab[6]) then
			if(cur_val_perc > range_tab[2]) then
				return false;
			end
		elseif(cur_val > range_tab[2]) then
			return false;
		end
	end

	return true;
end

local function in_stacks_range(stacks, range_tab)
	if(range_tab[3]) then
		if(not stacks or stacks < range_tab[3]) then
			return false;
		end
	end

	if(range_tab[4]) then
		if(not stacks or stacks > range_tab[4]) then
			return false;
		end
	end

	return true;
end

local function set_not(ti)
	ti.bChannel = true;
	ti.dur = 1;
	ti.fin = 1;
	ti.bSpecial = true;
	ti.valIsStatic = true;
	ti.ok = true;
end

local function set_times(timer, ti, dur, fin, ischannel)
	if(ti.ok) then
		if(timer.bNot) then
			ti.ok = nil;
		else
			if(ti.valIsStatic or timer.bExists) then
				set_not(ti);
			else
				ti.bChannel = ischannel;
				ti.dur = dur;
				ti.fin = fin;
			end
		end
	elseif(timer.bNot) then
		set_not(ti);
	end
end

function Gnosis:Timers_Spell(bar, timer, ti)
	-- cast
	local spell, _, _, icon, s, d = UnitCastingInfo(timer.unit);
	if(d and d > 0) then
		if(timer.spell == "all" or timer.spell == "any" or timer.spell == spell) then
			ti.cname = spell;
			ti.icon = icon;
			ti.unit = timer.unit;
			local dur, fin = d-s, d;
			if(timer.brange) then
				local rem = fin/1000-GetTime();
				ti.ok = in_value_range(rem, rem*100000/dur, timer.range_tab);
			else
				ti.ok = true;
			end
			set_times(timer, ti, dur, fin, false);
		end
	else
		spell, _, _, icon, s, d = UnitChannelInfo(timer.unit);
		if(d and d > 0) then
			if(timer.spell == "all" or timer.spell == "any" or timer.spell == spell) then
				ti.cname = spell;
				ti.icon = icon;
				ti.unit = timer.unit;
				local dur, fin = d-s, d;
				if(timer.brange) then
					local rem = fin/1000-GetTime();
					ti.ok = in_value_range(rem, rem*100000/dur, timer.range_tab);
				else
					ti.ok = true;
				end
				set_times(timer, ti, dur, fin, true);
			end
		end
	end
end

function Gnosis:Timers_SpellCD(bar, timer, ti)
	-- cooldown, player only
	ti.unit = "player";
	local s, d = GetSpellCooldown(timer.spell);
	if(d and d > 1.5) then	-- duration greater than global cd
		ti.cname = timer.spell;
		ti.icon = timer.icon or select(3, GetSpellInfo(timer.spell));
		local dur, fin = d, s+d;
		if(timer.brange) then
			local rem = fin - GetTime();
			ti.ok = in_value_range(rem, rem*100/dur, timer.range_tab);
		else
			ti.ok = true;
		end
		set_times(timer, ti, dur*1000, fin*1000, true);
	elseif(timer.bNot) then
		ti.cname = timer.spell;
		ti.icon = timer.icon or select(3, GetSpellInfo(timer.spell));
		set_not(ti);
	end
end

function Gnosis:Timers_Aura(bar, timer, ti)
	-- aura == buff or debuff (== hot or dot)
	ti.unit = timer.unit;
	local _, _, ic, sta, _, d, s, _, _, _, _, _, _, _, effect = UnitAura(timer.unit, timer.spell, nil, timer.filter);
	
	if (s) then
		ti.cname = timer.spell;
		ti.stacks = (sta and sta > 0) and sta or nil;
		ti.effect = effect;	
		ti.icon = ic;
		
		local rem = 0;		
		if (s > 0) then
			rem = s - GetTime();
		end
		
		if (rem > 0) then
			-- dynamic aura
			if (timer.brange) then
				if (in_value_range(rem, rem*100/d, timer.range_tab) and
						in_stacks_range(sta, timer.range_tab)) then
					ti.ok = true;
				end
			else
				ti.ok = true;
			end
			set_times(timer, ti, d * 1000, s * 1000, true);
		elseif (s == 0 and d == 0 and not timer.bNot) then
			-- static aura
			if (timer.brange) then
				if (in_stacks_range(sta, timer.range_tab)) then
					ti.ok = true;
				end
			else
				ti.ok = true;
			end
			ti.valIsStatic = true;
			set_times(timer, ti);
		end
	elseif (timer.bNot) then
		ti.cname = timer.spell;
		ti.icon = timer.icon or select(3, GetSpellInfo(timer.spell));
		set_not(ti);
	end
end

function Gnosis:Timers_GroupAura(bar, timer, ti)
	ti.unit = nil;
	
	-- scan current group for aura, also scan existing pets
	local _, ic, sta, d, s, effect;
	local n = GetNumGroupMembers();
	if (IsInRaid() and n >= 2) then
		-- scan raid
		for i = 1, n do
			local curunit = "raid" .. i;
			_, _, ic, sta, _, d, s, _, _, _, _, _, _, _, effect = UnitAura(curunit, timer.spell, nil, timer.filter);
			
			if (s) then
				ti.unit = curunit;
				break;
			end
			
			curunit = "raidpet" .. i;
			if (UnitExists(curunit)) then
				_, _, ic, sta, _, d, s, _, _, _, _, _, _, _, effect = UnitAura(curunit, timer.spell, nil, timer.filter);
			
				if (s) then
					ti.unit = curunit;
					break;
				end
			end
		end
	elseif (n >= 2) then
		-- scan player and group members
		_, _, ic, sta, _, d, s, _, _, _, _, _, _, _, effect = UnitAura("player", timer.spell, nil, timer.filter);
		
		if (s) then
			ti.unit = "player";
		else
			if (UnitExists("playerpet")) then
				_, _, ic, sta, _, d, s, _, _, _, _, _, _, _, effect = UnitAura("playerpet", timer.spell, nil, timer.filter);
			end
			
			if (s) then
				ti.unit = "playerpet";
			else
				for i = 1, (n - 1) do
					local curunit = "party" .. i;
					_, _, ic, sta, _, d, s, _, _, _, _, _, _, _, effect = UnitAura(curunit, timer.spell, nil, timer.filter);
					
					if (s) then
						ti.unit = curunit;
						break;
					end
					
					curunit = "partypet" .. i;
					if (UnitExists(curunit)) then
						_, _, ic, sta, _, d, s, _, _, _, _, _, _, _, effect = UnitAura(curunit, timer.spell, nil, timer.filter);
					
						if (s) then
							ti.unit = curunit;
							break;
						end
					end
				end
			end
		end
	else
		-- scan player (player not in group)
		_, _, ic, sta, _, d, s, _, _, _, _, _, _, _, effect = UnitAura("player", timer.spell, nil, timer.filter);
		
		if (s) then
			ti.unit = "player";
		else
			if (UnitExists("playerpet")) then
				_, _, ic, sta, _, d, s, _, _, _, _, _, _, _, effect = UnitAura("playerpet", timer.spell, nil, timer.filter);
				
				if (s) then
					ti.unit = "playerpet";
				end
			end
		end
	end
	
	if (ti.unit) then
		ti.cname = timer.spell;
		ti.stacks = (sta and sta > 0) and sta or nil;
		ti.effect = effect;	
		ti.icon = ic;
		
		local rem = 0;		
		if (s > 0) then
			rem = s - GetTime();
		end
		
		if (rem > 0) then
			-- dynamic aura
			if (timer.brange) then
				if (in_value_range(rem, rem*100/d, timer.range_tab) and
						in_stacks_range(sta, timer.range_tab)) then
					ti.ok = true;
				end
			else
				ti.ok = true;
			end
			set_times(timer, ti, d * 1000, s * 1000, true);
		elseif (s == 0 and d == 0 and not timer.bNot) then
			-- static aura
			if (timer.brange) then
				if (in_stacks_range(sta, timer.range_tab)) then
					ti.ok = true;
				end
			else
				ti.ok = true;
			end
			ti.valIsStatic = true;
			set_times(timer, ti);
		end
	elseif (timer.bNot) then
		ti.unit = timer.unit;
		ti.cname = timer.spell;
		ti.icon = timer.icon or select(3, GetSpellInfo(timer.spell));
		set_not(ti);
	end
end

function Gnosis:Timers_ItemCD(bar, timer, ti)
	-- itemcd, player only
	if (not timer.iid) then
		local itemname, link, _, _, _, _, _, _, _, itex = GetItemInfo(timer.spell);
		if (link) then
			timer.iid = string_match(link, "|Hitem:(%d+):");
			timer.itex = itex;
			timer.iname = itemname;
		end
	end

	if (timer.iid) then
		ti.unit = "player";
		local s, d = GetItemCooldown(timer.iid);
		if (d and d > 1.5) then	-- duration greater than global cd
			ti.cname = timer.iname;
			ti.icon = timer.itex;
			local dur, fin = d, s+d;
			if (timer.brange) then
				local rem = fin - GetTime();
				ti.ok = in_value_range(rem, rem*100/dur, timer.range_tab);
			else
				ti.ok = true;
			end
			set_times(timer, ti, dur*1000, fin*1000, true);
		elseif (timer.bNot) then
			ti.cname = timer.iname;
			ti.icon = timer.itex;
			set_not(ti);
		end
	end
end

function Gnosis:Timers_ItemEquipped(bar, timer, ti)
	-- item equipped? player only	
	if (not timer.iid) then
		local itemname, link, _, _, _, _, _, _, _, itex = GetItemInfo(timer.spell);
		if (link) then
			timer.iid = string_match(link, "|Hitem:(%d+):");
			timer.itex = itex;
			timer.iname = itemname;
		end
	end
	
	if (timer.iname) then
		ti.unit = "player";
		if (IsEquippedItem(timer.iname)) then
			ti.cname = timer.iname;
			ti.icon = timer.itex;
			ti.ok = true;
			ti.valIsStatic = true;
			set_times(timer, ti);
		elseif (timer.bNot) then
			ti.cname = timer.iname;
			ti.icon = timer.itex;
			set_not(ti);
		end
	end
end

function Gnosis:Timers_RuneCD(bar, timer, ti)
	-- rune cooldown, player only
	ti.unit = "player";
	local s, d, rdy = GetRuneCooldown(timer.spell);
	if(s and s > 0) then
		local rune = GetRuneType(timer.spell);
		if(rune) then
			ti.cname = Gnosis.tRuneName[rune];
			ti.icon = Gnosis.tRuneTexture[rune];
		else
			ti.cname = "";
			ti.icon = nil;
		end
		local dur, fin = d, s+d;
		if(timer.brange) then
			local rem = fin - GetTime();
			ti.ok = in_value_range(rem, rem*100/dur, timer.range_tab);
		else
			ti.ok = true;
		end
		set_times(timer, ti, dur*1000, fin*1000, true);
	elseif(timer.bNot and rdy) then
		local rune = GetRuneType(timer.spell);
		if(rune) then
			ti.cname = Gnosis.tRuneName[rune];
			ti.icon = Gnosis.tRuneTexture[rune];
		else
			ti.cname = "";
			ti.icon = nil;
		end
		set_not(ti);
	end
end

function Gnosis:Timers_TotemDuration(bar, timer, ti)
	-- totem duration
	ti.unit = "player";
	local bExist, name, s, d, icon = GetTotemInfo(timer.spell);
	if(bExist and name and s and s > 0) then
		ti.cname = name;
		ti.icon = icon;
		local dur, fin = d, s+d;
		if(timer.brange) then
			local rem = fin - GetTime();
			ti.ok = in_value_range(rem, rem*100/dur, timer.range_tab);
		else
			ti.ok = true;
		end
		set_times(timer, ti, dur*1000, fin*1000, true);
	elseif(timer.bNot) then
		ti.cname = "";
		ti.icon = nil;
		set_not(ti);
	end
end

function Gnosis:Timers_InnerCD(bar, timer, ti)
	ti.unit = "player";
	local bExist = false;
	if (Gnosis.ti_icd_active[timer.spell]) then
		if (GetTime() * 1000 >= Gnosis.ti_icd_active[timer.spell]) then
			-- inner cd expired
			Gnosis.ti_icd_active[timer.spell] = nil;
		else
			bExist = true;
		end
	end
	
	if (bExist) then
		ti.cname = timer.spell;
		ti.icon = timer.icon;
		local dur, fin = Gnosis.ti_icd[timer.spell].duration, Gnosis.ti_icd_active[timer.spell];
		if(timer.brange) then
			local rem = fin / 1000 - GetTime();
			ti.ok = in_value_range(rem, rem*100000/dur, timer.range_tab);
		else
			ti.ok = true;
		end
		set_times(timer, ti, dur, fin, true);
	elseif (timer.bNot) then
		ti.cname = timer.spell;
		ti.icon = timer.icon;
		set_not(ti);
	end
end

function Gnosis:Timers_WeaponEnchant(bar, timer, ti, exists, expires, charges)
	-- weapon enchant (player only)
	if(exists) then
		ti.cname = timer.spell;
		local dur = expires;
		local fin = expires + GetTime()*1000;
		local bardur = (bar.dur or bar.duration);
		if(timer.spell == bar.castname and bardur and bardur > dur) then
			dur = bardur;
		end
		if(timer.brange) then
			local rem = expires;
			ti.ok = in_value_range(rem/1000, rem*100/dur, timer.range_tab);
		else
			ti.ok = true;
		end
		set_times(timer, ti, dur, fin, true);
	end
end

function Gnosis:Timers_WeaponEnchantMain(bar, timer, ti)
	ti.unit = "player";
	local exists, expires, charges = select(1, GetWeaponEnchantInfo());
	if(exists) then
		local tt = Gnosis.tooltip;

		tt:ClearLines();
		tt:SetInventoryItem("player", 16);

		local num = tt:NumLines();
		for i = 1, num do
			if(string_find(_G["GnosisGameTooltipTextLeft"..i]:GetText(), timer.spell)) then
				ti.icon = GetInventoryItemTexture("player", 16);
				Gnosis:Timers_WeaponEnchant(bar, timer, ti, exists, expires, charges);
			end
		end
	elseif(timer.bNot) then
		ti.cname = timer.spell;
		ti.icon = GetInventoryItemTexture("player", 16);
		set_not(ti);
	end
end

function Gnosis:Timers_WeaponEnchantOff(bar, timer, ti)
	ti.unit = "player";
	local exists, expires, charges = select(4, GetWeaponEnchantInfo());
	if(exists) then
		local tt = Gnosis.tooltip;
		tt:ClearLines();
		tt:SetInventoryItem("player", 17);

		local num = tt:NumLines();
		for i = 1, num do
			if(string_find(_G["GnosisGameTooltipTextLeft"..i]:GetText(), timer.spell)) then
				ti.icon = GetInventoryItemTexture("player", 17);
				Gnosis:Timers_WeaponEnchant(bar, timer, ti, exists, expires, charges);
			end
		end
	elseif(timer.bNot) then
		ti.cname = timer.spell;
		ti.icon = GetInventoryItemTexture("player", 17);
		set_not(ti);
	end
end

function Gnosis:Timers_ComboPoints(bar, timer, ti)
	-- rogue or feral cat combo points
	local s, d = nil, nil;
	if(UnitExists(timer.unit)) then
		s, d = GetComboPoints("player", timer.unit), 5;
	end
	
	if(s) then
		ti.unit = timer.unit;
		ti.bSpecial = true;
		if(timer.brange) then
			ti.ok = in_value_range(s, s*100/d, timer.range_tab);
		else
			ti.ok = true;
		end
		set_times(timer, ti, d, s, true);
	elseif(timer.bNot) then
		ti.cname = "";
		ti.icon = nil;
		ti.unit = timer.unit;
		set_not(ti);
	end
end

function Gnosis:Timers_Range(bar, timer, ti)
	-- range between player and selected unit
	local minRange, maxRange;
	
	if(UnitExists(timer.unit)) then
		minRange, maxRange = Gnosis.range:GetRange(timer.unit);
	end
	
	if(minRange) then
		ti.unit = timer.unit;
		ti.bSpecial = true;
		if(timer.brange) then
			--[[ range_tab structure
				[1] == value lower bound (>=)
				[2] == value upper bound (<=)
				[3] == stacks lower bound (>=)
				[4] == stacks upper bound (<=)
				[5] == value lower bound is in percent (true, nil)
				[6] == value upper bound is in percent (true, nil) ]]
			
			if(timer.range_tab[5] or timer.range_tab[6]) then
				-- percentages of what??? (not allowed)
				ti.ok = false;
			else
				if(minRange <= (timer.range_tab[2] or 10000) and
					maxRange >= (timer.range_tab[1] or 0)) then
					ti.ok = true;
				end
			end
		else
			ti.ok = true;
		end
		set_times(timer, ti, maxRange, minRange, true);
	elseif(timer.bNot) then
		ti.cname = "";
		ti.icon = nil;
		ti.unit = timer.unit;
		set_not(ti);
	end
end

function Gnosis:Timers_Power(bar, timer, ti)
	-- mana, rage, focus, energy
	local s, d = UnitPower(timer.unit), UnitPowerMax(timer.unit);
	if(d and d > 0) then
		local pts = select(2, UnitPowerType(timer.unit));
		ti.cname = pts and _G[pts] or "";
		ti.unit = timer.unit;
		ti.bSpecial = true;
		if(timer.brange) then
			ti.ok = in_value_range(s, s*100/d, timer.range_tab);
		else
			ti.ok = true;
		end
		set_times(timer, ti, d, s, true);
	elseif(timer.bNot) then
		ti.cname = "";
		ti.icon = nil;
		ti.unit = timer.unit;
		set_not(ti);
	end
end

function Gnosis:Timers_PowerGeneric(bar, timer, ti)
	-- soul shards, eclipse, holy power, dark force, light force (chi)
	-- shadow orbs, burning embers and demonic fury
	local idx = timer.type - 2000;
	local s, d = UnitPower(timer.unit, idx), UnitPowerMax(timer.unit, idx);
	if(d and d > 0) then
		if(not ti.cname or ti.cname == "") then
			ti.cname =
					(idx == 7 and _G["SOUL_SHARDS"]) or
					(idx == 8 and _G["ECLIPSE"]) or
					(idx == 9 and _G["HOLY_POWER"]) or
					(idx == 12 and _G["LIGHT_FORCE"]) or
					(idx == 13 and _G["SHADOW_ORBS"]) or
					(idx == 14 and _G["BURNING_EMBERS"]) or
					(idx == 15 and _G["DEMONIC_FURY"]) or
				"";
			ti.icon = select(3, GetSpellInfo(
					(idx == 7 and 117198) or	-- soul shards
					(idx == 8 and 79577) or		-- eclipse
					(idx == 9 and 85247) or		-- holy power
					(idx == 12 and 97272) or	-- chi???
					(idx == 13 and 95740) or	-- shadow orbs
					(idx == 14 and 108647) or	-- burning embers
					(idx == 15 and 104315) or	-- demonic fury
					nil
				)); 
		end
		ti.unit = timer.unit;
		ti.bSpecial = true;
		if(timer.brange) then
			ti.ok = in_value_range(s, s*100/d, timer.range_tab);
		else
			ti.ok = true;
		end
		set_times(timer, ti, d, s, true);
	elseif(timer.bNot) then
		ti.cname = "";
		ti.icon = nil;
		ti.unit = timer.unit;
		set_not(ti);
	end
end

function Gnosis:Timers_Experience(bar, timer, ti)
	local xp = UnitXP("player");
	local xpmax = UnitXPMax("player");
	
	if (xp and xpmax) then
		ti.icon = nil;
		ti.unit = "player";
		ti.bSpecial = true;
		if (timer.brange) then
			ti.ok = in_value_range(xp, xp*100/xpmax, timer.range_tab);
		else
			ti.ok = true;
		end
		set_times(timer, ti, xpmax, xp, true);
	end
end

function Gnosis:Timers_RestedXP(bar, timer, ti)
	local rested = GetXPExhaustion();
	local xpmax = UnitXPMax("player");
	
	if (rested and xpmax) then
		ti.icon = nil;
		ti.unit = "player";
		ti.bSpecial = true;
		if (timer.brange) then
			ti.ok = in_value_range(rested, min(rested*100/xpmax, 100), timer.range_tab);
		else
			ti.ok = true;
		end
		set_times(timer, ti, xpmax, rested, true); 
	end
end

function Gnosis:Timers_Health(bar, timer, ti)
	local s, d = UnitHealth(timer.unit), UnitHealthMax(timer.unit);
	if(d and d > 0) then
		ti.cname = _G["HEALTH"];
		ti.unit = timer.unit;
		ti.bSpecial = true;
		if(timer.brange) then
			ti.ok = in_value_range(s, s*100/d, timer.range_tab);
		else
			ti.ok = true;
		end
		set_times(timer, ti, d, s, true);
	elseif(timer.bNot) then
		ti.cname = "";
		ti.icon = nil;
		ti.unit = timer.unit;
		set_not(ti);
	end
end

function Gnosis:Timers_PowerAlternate(bar, timer, ti)
	local s, d = UnitPower(timer.unit, ALTERNATE_POWER_INDEX), UnitPowerMax(timer.unit, ALTERNATE_POWER_INDEX);
	if(d and d > 0) then
		ti.cname = select(10, UnitAlternatePowerInfo(timer.unit));
		ti.icon = UnitAlternatePowerTextureInfo(timer.unit, 2);
		ti.unit = timer.unit;
		ti.bSpecial = true;
		if(timer.brange) then
			ti.ok = in_value_range(s, s*100/d, timer.range_tab);
		else
			ti.ok = true;
		end
		set_times(timer, ti, d, s, true);
	elseif(timer.bNot) then
		ti.cname = "";
		ti.icon = nil;
		ti.unit = timer.unit;
		set_not(ti);
	end
end

function Gnosis:Timers_IncomingHealth(bar, timer, ti)
	local s, d = UnitGetIncomingHeals(timer.unit), UnitHealthMax(timer.unit);
	if(s and d and d > 0) then
		ti.cname = "";
		ti.unit = timer.unit;
		ti.bSpecial = true;
		if(timer.brange) then
			ti.ok = in_value_range(s, s*100/d, timer.range_tab);
		else
			ti.ok = true;
		end
		set_times(timer, ti, d, s, true);
	elseif(timer.bNot) then
		ti.cname = "";
		ti.icon = nil;
		ti.unit = timer.unit;
		set_not(ti);
	end
end

function Gnosis:Timers_TargetThreat(bar, timer, ti)
	local _, status, pct, _, val = UnitDetailedThreatSituation(timer.unit, "target");
	if(status and pct > 0) then
		val = val / 100;
		ti.cname = "";
		ti.unit = timer.unit;
		ti.bSpecial = true;
		ti.stacks = status;
		if(timer.brange) then
			if(in_value_range(val, pct, timer.range_tab) and
					in_stacks_range(status, timer.range_tab)) then
				ti.ok = true;
			end
		else
			ti.ok = true;
		end
		set_times(timer, ti, val * 100 / pct, val, true);
	elseif(timer.bNot) then
		ti.cname = "";
		ti.icon = nil;
		ti.unit = timer.unit;
		set_not(ti);
	end
end

function Gnosis:Timers_Fixed(bar, timer, ti)
	-- show fixed bar (pass text in nfs)
	ti.unit = "player";
	ti.cname = "";
	ti.icon = timer.icon or select(3, GetSpellInfo(timer.spell));
	set_not(ti);
end

function Gnosis:Timers_SpellKnown(bar, timer, ti)
	ti.unit = "player";
	if (GetSpellLink(timer.spell)) then
		ti.cname = timer.spell;
		ti.icon = timer.icon or select(3, GetSpellInfo(timer.spell));
		ti.ok = true;
		ti.valIsStatic = true;
		set_times(timer, ti);
	elseif (timer.bNot) then
		ti.cname = timer.spell;
		ti.icon = timer.icon or select(3, GetSpellInfo(timer.spell));
		set_not(ti);
	end
end

function Gnosis:Timers_UnitName(bar, timer, ti)
	local n = UnitName(timer.unit);
	
	if (n and (timer.spell == "any" or n == timer.spell)) then
		ti.cname = n;
		ti.unit = timer.unit;
		ti.ok = true;
		ti.valIsStatic = true;
		set_times(timer, ti);	
	elseif (timer.bNot) then
		ti.cname = timer.spell;
		ti.unit = timer.unit;
		set_not(ti);
	end
end

function Gnosis:Timers_GlobalCD(bar, timer, ti)
	local gcd = Gnosis.current_gcd;
	local rem = gcd and (gcd.finish - GetTime()) or 0;
	
	if (rem > 0 and (timer.spell == "any" or gcd.spell == timer.spell)) then
		ti.cname = gcd.spell;
		ti.unit = "player";
		ti.icon = timer.icon or select(3, GetSpellInfo(gcd.spell));
		if (timer.brange) then
			ti.ok = in_value_range(rem, rem*100/gcd.cd, timer.range_tab);			
		else
			ti.ok = true;
		end
		set_times(timer, ti, gcd.cd*1000, gcd.finish*1000);
	elseif (timer.bNot) then
		ti.cname = timer.spell;
		ti.unit = "player";
		ti.icon = timer.icon or select(3, GetSpellInfo(timer.spell));
		set_not(ti);
	end
end

function Gnosis:ExtractRegex(str, regex_a, regex_b, dotrim)
	local res = string_match(str, regex_a);
	if (res) then
		if (dotrim) then
			res = string_trim(res);
		end
		return res, string_gsub(str, regex_a, "");
	elseif (regex_b) then
		res = string_match(str, regex_b);
		if (res) then
			if (dotrim) then
				res = string_trim(res);
			end
			return res, string_gsub(str, regex_b, "");
		else
			return nil, str;
		end
	else
		return nil, str;
	end
end

-- local functions
local function validate_value(val, isperc)
   if(val and tonumber(val)) then
      val = tonumber(val);
      if(isperc) then
         if(val > 100) then
            return 100;
         elseif(val < 0) then
            return 0;
         else
            return val;
         end
      elseif(val < 0) then
         return 0;
      else
         return val;
      end
   end

   return nil;
end

local function validate_value(val, isperc)
	if(val and tonumber(val)) then
		val = tonumber(val);
		if(isperc) then
			if(val > 100) then
				return 100;
			elseif(val < 0) then
				return 0;
			else
				return val;
			end
		elseif(val < 0) then
			return 0;
		else
			return val;
		end
	end

	return nil;
end

local function get_valid_range_table(spell_string)
	local res, str = Gnosis:ExtractRegex(spell_string, "<([^>]*)>", nil, true);
	str = string_trim(str);

	local cnt = 1;
	if(res) then
		res = strconcat(res, ",,,");
		local low_val, up_val, low_st, up_st, blow_val_perc, bup_val_perc;
		low_val, up_val, low_st, up_st = string_match(res, "([^,]*),([^,]*),([^,]*),([^,]*)");

		low_st = tonumber(low_st);
		up_st = tonumber(up_st);

		low_val, cnt = string_gsub(low_val, "%%", "");
		if(cnt > 0) then
			blow_val_perc = true;
		end
		up_val, cnt = string_gsub(up_val, "%%", "");
		if(cnt > 0) then
			bup_val_perc = true;
		end

		-- values valid?
		low_val = validate_value(low_val, blow_val_perc);
		up_val = validate_value(up_val, bup_val_perc);
		low_st = validate_value(low_st);
		up_st = validate_value(up_st);

		if(low_val or up_val or low_st or up_st) then
			local t = { low_val, up_val, low_st, up_st, blow_val_perc, bup_val_perc };
			return str, true, t;
		end
	end

	return str, nil, nil;
end

local TimerInfo = {
};

local SelectedTimerInfo = {
};

function Gnosis:CreateSingleTimerTable()
	wipe(self.ti_fl);
	wipe(self.ti_icd);

	for key, value in pairs(self.castbars) do
		local conf = Gnosis.s.cbconf[key];
		local timer_id = 0;

		if(conf.bEn and conf.bartype == "ti" and (conf.spec == 0 or conf.spec == self.iCurSpec)) then
			value.timers = {};
			value.iTimerSort = nil;

			for k, v in ipairs(conf.bnwlist) do
				-- timer id
				timer_id = timer_id + 1;

				-- copy of timer command string
				local str = v;
				
				-- comment
				if(string_find(str, "^%s*[-][-]")) then
					str = "";
				end

				local unit, recast, staticdur, zoom, spec, iconoverride, portraitunit, shown, hidden, plays, playm, playf;

				-- extract commands from current line
				unit, str = self:ExtractRegex(str, "unit=(%w+)", "unit=\"([^\"]+)\"", true);
				iconoverride, str = self:ExtractRegex(str, "icon=(%w+)", "icon=\"([^\"]+)\"", true);
				shown, str = self:ExtractRegex(str, "shown=(%w+)", "shown=\"([^\"]+)\"", true);
				hidden, str = self:ExtractRegex(str, "hidden=(%w+)", "hidden=\"([^\"]+)\"", true);
				portraitunit, str = self:ExtractRegex(str, "portrait=(%w+)", "portrait=\"([^\"]+)\"", true);
				plays, str = self:ExtractRegex(str, "plays=\"([^\"]+)\"", nil, true);
				playm, str = self:ExtractRegex(str, "playm=\"([^\"]+)\"", nil, true);
				playf, str = self:ExtractRegex(str, "playf=\"([^\"]+)\"", nil, true);
				recast, str = self:ExtractRegex(str, "recast=([+-]?[0-9]*%.?[0-9]*)", "recast=\"([+-]?[0-9]*%.?[0-9]*)\"");	-- floating point regex
				staticdur, str = self:ExtractRegex(str, "staticdur=([+-]?[0-9]*%.?[0-9]*)", "staticdur=\"([+-]?[0-9]*%.?[0-9]*)\"");
				zoom, str = self:ExtractRegex(str, "zoom=([+-]?[0-9]*%.?[0-9]*)", "zoom=\"([+-]?[0-9]*%.?[0-9]*)\"");
				spec, str = self:ExtractRegex(str, "spec=(%d+)", "spec=\"(%d+)\"");
				recast, staticdur, zoom, spec =
					recast and (tonumber(recast) * 1000),
					staticdur and (tonumber(staticdur) * 1000),
					zoom and (tonumber(zoom) * 1000),
					spec and tonumber(spec);
				
				-- get play interval time
				local playinterval;
				if (plays) then
					local s, f;
					s, f, playinterval, plays = string_find(plays, "([+-]?[0-9]*%.?[0-9]*)%-(.+)");
					if (playinterval) then playinterval = tonumber(playinterval); end
					playm = nil; playf = nil;
				elseif (playm) then
					s, f, playinterval, playm = string_find(playm, "([+-]?[0-9]*%.?[0-9]*)%-(.+)");
					if (playinterval) then playinterval = tonumber(playinterval); end
					plays = nil; playf = nil;
				elseif (playf) then
					s, f, playinterval, playf = string_find(playf, "([+-]?[0-9]*%.?[0-9]*)%-(.+)");
					if (playinterval) then playinterval = tonumber(playinterval); end
					plays = nil; playm = nil;
				end
				
				-- check if playinterval is too short or too long
				if (playinterval and (playinterval < 0.5 or playinterval > 600)) then
					playinterval = nil;
				end

				local fplay, tplay, toplay;
				if (playinterval) then
					if (plays) then
						fplay = PlaySound;
						tplay = self.played.s;
						toplay = plays;
					elseif (playm and self.lsm:Fetch("sound", playm)) then
						fplay = PlaySoundFile;
						tplay = self.played.m;
						toplay = self.lsm:Fetch("sound", playm);
					elseif (playf) then
						fplay = PlaySoundFile;
						tplay = self.played.f;
						toplay = playf;
					end
				end
				
				-- icon override, portrait unit
				local iconoverride = select(3, GetSpellInfo(iconoverride));
				local ptun = portraitunit;
				
				local nfs, tfs, colstr, tsbcol;
				-- name format string
				nfs, str = self:ExtractRegex(str, "nfs=\"([^\"]*)\"", "nfs=(%w+)");
				-- time format string
				tfs, str = self:ExtractRegex(str, "tfs=\"([^\"]*)\"", "tfs=(%w+)");
				-- status bar color
				colstr, str = self:ExtractRegex(str, "sbcol=\"([^\"]+)\"");
				if(colstr) then
					local r,g,b,a = self:GetColorsFromString(colstr);
					if(r) then
						tsbcol = { r, g, b, a };
					end
				end
				-- command and spellname
				local tiType, bSelf, bHarm, bHelp, bShowLag, bShowCasttime, iSort, bExists, bNot, bHideSpark, bHideIcon, cfinit, brange, range_tab, icon__;
				local norefresh = false;
				local boolop = 0;
				local cmd, spell = string_match(str, "(.-):(.+)");
				if(spell) then
					spell, brange, range_tab = get_valid_range_table(spell);
				end
				cmd = cmd and string_trim(cmd);
				if(cmd and string_len(cmd) > 0 and spell and string_len(spell) > 0) then
					for w in string_gmatch(cmd, "%w+") do
						w = string_lower(w);

						if (w == "cast") then
							tiType = 0;
							cfinit = Gnosis.Timers_Spell;
						elseif (w == "cd") then
							tiType = 1;
							unit = "player";
							cfinit = Gnosis.Timers_SpellCD;
						elseif (w == "dot" or w == "debuff") then
							bHarm = true;
							tiType = 2;
							cfinit = Gnosis.Timers_Aura;
						elseif (w == "hot" or w == "buff") then
							bHelp = true;
							tiType = 2;
							cfinit = Gnosis.Timers_Aura;
						elseif (w == "aura") then
							tiType = 2;
							cfinit = Gnosis.Timers_Aura;
						elseif (w == "itemcd") then
							tiType = 3;
							unit = "player";
							cfinit = Gnosis.Timers_ItemCD;
						elseif (w == "runecd") then
							unit = "player";
							if (tonumber(spell) and tonumber(spell) > 0 and tonumber(spell) <= 6) then
								tiType = 4;
								cfinit = Gnosis.Timers_RuneCD;
							end
						elseif (w == "totemdur") then
							unit = "player";
							if(tonumber(spell) and tonumber(spell) > 0 and tonumber(spell) <= MAX_TOTEMS) then
								tiType = 5;
								cfinit = Gnosis.Timers_TotemDuration;
							end
						elseif (w == "enchmh") then
							tiType = 6;
							unit = "player";
							cfinit = Gnosis.Timers_WeaponEnchantMain;
						elseif (w == "enchoh") then
							tiType = 7;
							unit = "player";
							cfinit = Gnosis.Timers_WeaponEnchantOff;
						elseif (w == "icd" or w == "innercd" or w == "proc") then
							-- valid spell or spell id given? (name of spell passed for icd does not
							-- necessarily have to be a valid spell)
							local spell_, _, icon_ = GetSpellInfo(spell);
							if(spell_) then
								spell = spell_;
								icon__ = icon_;
							end							
							-- staticdur given? otherwise set duration to 5s
							if(spell) then
								tiType = 8;
								cfinit = Gnosis.Timers_InnerCD;
							
								self.ti_icd[spell] = {
									duration = staticdur or 5.0,
									norefresh = false
								};
							end
							unit = "player";
						elseif (w == "fixed") then
							tiType = 10;
							unit = "player";
							cfinit = Gnosis.Timers_Fixed;
						elseif (w == "spellknown") then
							tiType = 11;
							unit = "player";
							cfinit = Gnosis.Timers_SpellKnown;
						elseif (w == "unitname") then
							tiType = 12;
							cfinit = Gnosis.Timers_UnitName;
						elseif (w == "gcd") then
							tiType = 13;
							unit = "player";
							cfinit = Gnosis.Timers_GlobalCD;
						elseif (w == "equipped") then
							tiType = 14;
							unit = "player";
							cfinit = Gnosis.Timers_ItemEquipped;
						elseif (w == "groupdot" or w == "groupdebuff") then
							bHarm = true;
							tiType = 21;
							cfinit = Gnosis.Timers_GroupAura;
						elseif (w == "grouphot" or w == "groupbuff") then
							bHelp = true;
							tiType = 21;
							cfinit = Gnosis.Timers_GroupAura;
						elseif (w == "groupaura") then
							tiType = 21;
							cfinit = Gnosis.Timers_GroupAura;
						elseif (w == "resource") then
							if (spell == "power") then
								tiType = 1000;
								cfinit = Gnosis.Timers_Power;
							elseif (spell == "health") then
								tiType = 1001;
								cfinit = Gnosis.Timers_Health;
							elseif (spell == "altpower") then
								tiType = 1002;
								cfinit = Gnosis.Timers_PowerAlternate;
							elseif (spell == "heal") then
								tiType = 1003;
								cfinit = Gnosis.Timers_IncomingHealth;
							elseif (spell == "threat") then
								tiType = 1004;
								cfinit = Gnosis.Timers_TargetThreat;
							elseif (spell == "combopoints") then
								tiType = 1005;
								cfinit = Gnosis.Timers_ComboPoints;
							elseif (spell == "range") then
								tiType = 1006;
								cfinit = Gnosis.Timers_Range;
							elseif (spell == "soulshards") then
								tiType = 2007;
								cfinit = Gnosis.Timers_PowerGeneric;
							elseif (spell == "eclipse") then
								tiType = 2008;
								cfinit = Gnosis.Timers_PowerGeneric;
							elseif (spell == "holypower") then
								tiType = 2009;
								cfinit = Gnosis.Timers_PowerGeneric;
							elseif (spell == "chi") then
								tiType = 2012;
								cfinit = Gnosis.Timers_PowerGeneric;
							elseif (spell == "shadoworbs") then
								tiType = 2013;
								cfinit = Gnosis.Timers_PowerGeneric;
							elseif (spell == "burningembers") then
								tiType = 2014;
								cfinit = Gnosis.Timers_PowerGeneric;
							elseif (spell == "demonicfury") then
								tiType = 2015;
								cfinit = Gnosis.Timers_PowerGeneric;
							elseif (spell == "xp" or spell == "experience") then
								tiType = 2016;
								cfinit = Gnosis.Timers_Experience;
							elseif (spell == "rested" or spell == "restedxp") then
								tiType = 2017;
								cfinit = Gnosis.Timers_RestedXP;
							end
						elseif (w == "mine") then
							bSelf = true;
						elseif (w == "helpful" or w == "help") then
							bHelp = true;
						elseif (w == "harmful" or w == "harm") then
							bHarm = true;
						elseif (w == "lag") then
							bShowLag = true;
						elseif (w == "casttime") then
							bShowCasttime = true;
						elseif (w == "exists") then
							bExists = true;
						elseif (w == "not") then
							bNot = true;
						elseif (w == "hidespark") then
							bHideSpark = true;
						elseif (w == "hideicon") then
							bHideIcon = true;
						elseif (w == "and") then
							boolop = 1;
						elseif (w == "or") then
							boolop = 2;
						elseif (w == "sort") then
							if (spell == "minrem") then
								iSort = 1;
							elseif (spell == "maxrem") then
								iSort = 2;
							elseif (spell == "mindur") then
								iSort = 3;
							elseif (spell == "maxdur") then
								iSort = 4;
							elseif (spell == "first") then
								iSort = 5;
							end
						elseif (w == "norefresh") then
							norefresh = true;
						end
					end
				end

				local strFilter = "";
				strFilter = strFilter .. (bSelf and "PLAYER" or "");
				strFilter = strFilter .. (bHarm and (string_len(strFilter) > 0 and "|HARMFUL" or "HARMFUL") or "");
				strFilter = strFilter .. (bHelp and (string_len(strFilter) > 0 and "|HELPFUL" or "HELPFUL") or "");

				if(not spec or spec == self.iCurSpec) then
					if(tiType) then
						local tTimer = {
							type = tiType,
							filter = strFilter,
							spell = spell,
							showlag = bShowLag,
							showcasttime = bShowCasttime,
							nfs = nfs,
							tfs = tfs,
							recast = recast,
							staticdur = staticdur,
							zoom = zoom,
							bExists = bExists,
							bNot = bNot,
							cfinit = cfinit,
							sbcolor = tsbcol,
							cbs = not bHideSpark and conf.bShowCBS or false,
							hideicon = bHideIcon,
							id = timer_id,
							brange = brange,
							range_tab = range_tab,
							boolop = boolop,
							icon = icon__,
							icov = iconoverride,
							ptun = portraitunit,
							shown = shown,
							hidden = hidden,
							playinterval = playinterval,
							fplay = fplay,
							tplay = tplay,
							toplay = toplay,
						};
						-- targeted unit
						tTimer.unit = unit and unit or conf.unit;

						-- get name and icon if cast/aura and passed as spellid
						if((tiType <= 2 or tiType == 10 or tiType == 11 or tiType == 21) and tonumber(spell)) then
							local name_, _, icon_ = GetSpellInfo(tonumber(spell));
							if(name_ and icon_) then
								tTimer.spell = name_;
								tTimer.icon = icon_;
							end
						end

						-- if itemcd try to get item id and texture
						if(tiType == 3 or tiType == 14) then
							local itemname, link, _, _, _, _, _, _, _, itex = GetItemInfo(spell);
							if(link) then
								tTimer.iid = string.match(link, "|Hitem:(%d+):");
								tTimer.itex = itex;
								tTimer.iname = itemname;
							end
						end
						
						-- inner cooldown/proc (norefresh command)
						if(tiType == 8) then
							self.ti_icd[spell].norefresh = norefresh;
						end
						
						-- insert entry
						table_insert(value.timers, tTimer);
					elseif(iSort) then
						-- sorting criterion
						value.iTimerSort = iSort;
					end
				end
			end

			if(#value.timers > 0) then
				table_insert(self.ti_fl, value);
			end
		end
	end
end

function Gnosis:InjectTimer(barname, text, cnt, spell, isCast)
	local fCurTime = GetTime() * 1000;
	if (self.castbars and self.castbars[barname]) then
		local cb = self.castbars[barname];
		local cfg = cb.conf;
		
		-- castbar values
		cb.channel = not isCast;
		cb.icon:SetTexture(nil);
		cb.id = 0;
		
		if (spell) then
			local name, _, icon = GetSpellInfo(spell);
			if (name and icon) then
				cb.castname = name;
				cb.icon:SetTexture(icon);
			end
		end	

		-- show castbar text
		cb.ctext:SetText(text);
		cb.castname = nil;
		
		cb.duration = cnt * 1000;
		cb.endTime = fCurTime + cb.duration;

		-- set statusbar value
		local val = (cb.endTime - fCurTime) / (cb.duration);
		val = (cb.channel and (not cfg.bChanAsNorm)) and val or (1 - val);
		cb.bar:SetValue(val);
		cb:SetAlpha(cfg.alpha);
		cb:Show();
		
		-- castbar spark
		if(cfg.bShowCBS) then
			cb.cbs:SetPoint("CENTER", cb.bar, "LEFT", val * cb.barwidth, 0);
			cb.cbs:Show();
		end
		
		-- pushback (also vital for clipping test)
		cb.pushback = 0;

		-- set bar active
		cb.bActive = true;
		self.activebars[barname] = cb;
	else
		self:Print("bar " .. barname .. "unknown");
	end
end

function Gnosis:ScanTimerbar(bar, fCurTime)
	local bUpdateText = false;
	local bDelayedShow = false;

	-- hide bar in/out of combat
	if (bar.conf.incombatsel == 1 or bar.conf.incombatsel == self.curincombattype or bar.conf.bUnlocked) then
		if (bar.bBarHidden) then
			bDelayedShow = true;
		end
	else
		if (not bar.bBarHidden) then
			bar:Hide();
			bar.bBarHidden = true;
		end
		return;
	end

		-- valid group layout?
	if (not self:CheckGroupLayout(bar.conf)) then
		if(not bar.bBarHidden) then
			bar:Hide();
			bar.bBarHidden = true;
		end
		return;
	end

	local boolop_complete;
	SelectedTimerInfo.duration = nil;
	for k, v in ipairs(bar.timers) do
		if (boolop_complete) then
			-- search for first timer entry without boolop
			if(v.boolop == 0) then
				boolop_complete = nil;
			end
		else
			wipe(TimerInfo);
			
			-- pre checks
			local checkentry = true;
			
			-- selected unit exists?
			if (not UnitExists(v.unit)) then
				checkentry = false;
			end
			
			-- "shown" command? is given bar actually shown?
			if (v.shown and Gnosis.castbars[v.shown] and not Gnosis.castbars[v.shown].bActive) then
				checkentry = false;
			end
			-- "hidden" command? is given bar actually hidden?
			if (v.hidden and Gnosis.castbars[v.hidden] and Gnosis.castbars[v.hidden].bActive) then
				checkentry = false;
			end
			
			-- check entry
			if (checkentry) then
				-- call related timer function (Timers.lua)
				v:cfinit(bar, v, TimerInfo);

				if (TimerInfo.ok and self:UnitRelationSelect(bar.conf.relationsel, TimerInfo.unit)) then
					-- boolop?
					if (v.boolop == 1) then
						-- timer is condition for next one(s), next please
					else
						if (v.boolop == 2) then
							boolop_complete = true;
						end

						-- check if cooldown is gcd
						local bTakeover = false;
						if (TimerInfo.bSpecial) then
							bTakeover = true;
							SelectedTimerInfo.bSpecial = TimerInfo.bSpecial;
							SelectedTimerInfo.valIsStatic = TimerInfo.valIsStatic;
						else
							-- sorting
							SelectedTimerInfo.bSpecial = false;
							if (not bar.iTimerSort or not SelectedTimerInfo.duration) then
								bTakeover = true;
							elseif (bar.iTimerSort == 1 and SelectedTimerInfo.endTime > TimerInfo.fin) then	-- min remaining
								bTakeover = true;
							elseif (bar.iTimerSort == 2 and SelectedTimerInfo.endTime < TimerInfo.fin) then	-- max remaining
								bTakeover = true;
							elseif (bar.iTimerSort == 3 and SelectedTimerInfo.duration > TimerInfo.dur) then	-- min duration
								bTakeover = true;
							elseif (bar.iTimerSort == 4 and SelectedTimerInfo.duration < TimerInfo.dur) then	-- max duration
								bTakeover = true;
							end
						end

						if (bTakeover) then
							SelectedTimerInfo.castname = TimerInfo.cname;
							SelectedTimerInfo.endTime = TimerInfo.fin;
							SelectedTimerInfo.duration = TimerInfo.dur;
							SelectedTimerInfo.icon = TimerInfo.icon;
							SelectedTimerInfo.stacks = TimerInfo.stacks;
							SelectedTimerInfo.effect = TimerInfo.effect;
							SelectedTimerInfo.tiunit = TimerInfo.unit;
							SelectedTimerInfo.bChannel = TimerInfo.bChannel;
							SelectedTimerInfo.curtimer = v;							
						end

						if (SelectedTimerInfo.bSpecial or not bar.iTimerSort) then
							-- break if no sorting criterion given or if bar was durationless,
							-- i.e. it couldn't be sorted anyway
							break;
						end
					end
				elseif (v.boolop == 1) then
					-- and but invalid entry, skip to next combined and/or block
					boolop_complete = true;
				end
			elseif (v.boolop == 1) then
				-- and but invalid entry, skip to next combined and/or block
				boolop_complete = true;
			end
		end
	end

	if (SelectedTimerInfo.duration) then
		if (bDelayedShow) then
			bar.bBarHidden = nil;
			bar:Show();
		end

		-- play sound/music/file
		local playinterval = SelectedTimerInfo.curtimer.playinterval;
		if (playinterval) then
			local fplay = SelectedTimerInfo.curtimer.fplay;
			local tplay = SelectedTimerInfo.curtimer.tplay;
			local toplay = SelectedTimerInfo.curtimer.toplay;
			
			if (not tplay[bar.name]) then
				tplay[bar.name] = {};
			end
			
			local tp = tplay[bar.name];
			if ((not tp[toplay]) or tp[toplay].timer <= GetTime()) then
				if (tp[toplay] and tp[toplay].handle) then
					StopSound(tp[toplay].handle);
				end
				
				local willPlay, handle = fplay(toplay, self.s.ct.channel and self.tSoundChannels[self.s.ct.channel] or self.tSoundChannels[1]);
									
				if (willPlay) then
					if (tp[toplay]) then
						tp[toplay].handle = handle;
						tp[toplay].timer = GetTime() + playinterval;
					else
						tp[toplay] = {
							["handle"] = handle,
							["timer"] = GetTime() + playinterval,
						};
					end
				else
					if (tp[toplay]) then
						wipe(tp[toplay]);
					end
					tp[toplay] = nil;
				end
			end
		end
		
		-- only minor changes to bar necessary?
		if (bar.bActive and bar.timer_id == SelectedTimerInfo.curtimer.id and bar.castname == SelectedTimerInfo.castname) then
			local dur = bar.dur and bar.dur or bar.duration;
			local bRecalcTick = (dur ~= SelectedTimerInfo.duration);

			-- redo name text
				-- stacks; effect value and name of targeted unit (added in 4.01)
			if (bar.stacks ~= SelectedTimerInfo.stacks or bar.effect ~= SelectedTimerInfo.effect or SelectedTimerInfo.tiunit ~= bar.tiUnit or bar.tiUnitName ~= UnitName(bar.tiUnit)) then
				bar.stacks = SelectedTimerInfo.stacks;
				bar.effect = SelectedTimerInfo.effect;
				bar.tiUnit = SelectedTimerInfo.tiunit;
				bar.tiUnitName = UnitName(bar.tiUnit);
				bar.ctext:SetText(self:CreateCastname(bar, bar.conf, SelectedTimerInfo.castname, ""));
			end
			
			if (SelectedTimerInfo.bSpecial) then
				if (not SelectedTimerInfo.valIsStatic) then
					-- power
					self:SetPowerbarValue(bar, SelectedTimerInfo.endTime, SelectedTimerInfo.duration, SelectedTimerInfo.curtimer.cbs);
				end

				return;
			end

			-- zoom?
			local bZoom = SelectedTimerInfo.curtimer.zoom and (SelectedTimerInfo.curtimer.zoom >= (SelectedTimerInfo.endTime - fCurTime));
			-- staticdur?
			local bStatic = SelectedTimerInfo.curtimer.staticdur and true;

			bar.dur = (bStatic or bZoom) and SelectedTimerInfo.duration or nil;
			bar.duration = bZoom and SelectedTimerInfo.curtimer.zoom or (bStatic and SelectedTimerInfo.curtimer.staticdur or SelectedTimerInfo.duration);
			bar.endTime = SelectedTimerInfo.endTime;

			if (bar.cbs_check) then
				local bShowCBS = bar.duration >= (bar.endTime - fCurTime);
				if (bShowCBS) then
					if (bar.cbs_hidden) then
						bar.cbs:Show();
						bar.cbs_hidden = false;
					end
				else
					if (not bar.cbs_hidden) then
						bar.cbs:Hide();
						bar.cbs_hidden = true;
					end
				end
			end

			self:SetupTimerLagBox(bar, SelectedTimerInfo.curtimer.showlag,
				SelectedTimerInfo.curtimer.showcasttime, SelectedTimerInfo.castname,
				SelectedTimerInfo.curtimer.recast, bRecalcTick);
		else	-- create bar
			-- id
			bar.timer_id = SelectedTimerInfo.curtimer.id;

			-- name and time format strings
			bar.nfs = SelectedTimerInfo.curtimer.nfs and SelectedTimerInfo.curtimer.nfs or bar.conf.strNameFormat;
			bar.tfs = SelectedTimerInfo.curtimer.tfs and SelectedTimerInfo.curtimer.tfs or bar.conf.strTimeFormat;

			if (SelectedTimerInfo.bSpecial) then
				bar.bSpecial = true;
				self:SetupPowerbar(bar, SelectedTimerInfo);
			else
				bar.bSpecial = false;
				self:SetupTimerbar(bar, fCurTime, SelectedTimerInfo);
			end
		end
	elseif (self.activebars[bar.name] or bar.forcecleanup) then
		local conf = bar.conf;
		-- bar active, fadeout or cleanup
		if (conf.bUnlocked or conf.bShowWNC or bDelayedShow) then
			self:CleanupCastbar(bar);
			bar.forcecleanup = false;
		else
			self:PrepareCastbarForFadeout(bar, fCurTime, bar.forcecleanup);
			bar.forcecleanup = false;
		end
	end
end
