-- local functions
local GetTime = GetTime;
local UnitChannelInfo = UnitChannelInfo;
local UnitCastingInfo = UnitCastingInfo;
local UnitDamage = UnitDamage;
local UnitName = UnitName;
local UnitClass = UnitClass;
local UnitIsPlayer = UnitIsPlayer;
local pairs = pairs;
local ipairs = ipairs;
local unpack = unpack;
local min = min;
local abs = abs;

-- local variables
local _;

-- init OnUpdate handler, anchoring bars
function Gnosis:OnUpdate()
	-- initial bar anchoring
	Gnosis:AnchorAllBars();

	Gnosis.OnUpdate = Gnosis.Update;
end

-- OnUpdate handler
function Gnosis:Update()
	local fCurTime = GetTime() * 1000;

	-- update bars
	for key, value in pairs(self.activebars) do
		local conf = value.conf;
		local rem = value.endTime - fCurTime;
		if(rem >= 0) then
			if(conf.incombatsel == 1 or conf.incombatsel == self.curincombattype or conf.bUnlocked) then
				local val = min(rem/value.duration, 1);
				value.rtext:SetText(self:GenerateTime(value,
					(value.endTime - fCurTime) / 1000,
					(value.dur or value.duration) / 1000,
					value.pushback and (value.pushback / 1000))
				);
				val = (value.channel and (not conf.bChanAsNorm)) and val or (1 - val);
				value.bar:SetValue(val);
				if(conf.orient == 2) then
					if(conf.bInvDir) then
						value.cbs:SetPoint("CENTER", value.bar, "TOP", 0, -val * value.barheight);
					else
						value.cbs:SetPoint("CENTER", value.bar, "BOTTOM", 0, val * value.barheight);
					end
				else
					if(conf.bInvDir) then
						value.cbs:SetPoint("CENTER", value.bar, "RIGHT", -val * value.barwidth, 0);
					else
						value.cbs:SetPoint("CENTER", value.bar, "LEFT", val * value.barwidth, 0);
					end
				end

				if(value.reanchor) then
					self:ReAnchorBar(value);
				end

				-- timer bars use different code to show/hide castbars
				if(value.bBarHidden and not value.tiType) then
					value.bBarHidden = nil;
					value:Show();
				end
			elseif(not value.tiType) then
				value:Hide();
				value.bBarHidden = true;
			end
		else
			-- cleanup/fade out gcd castbars
			if(conf.bUnlocked or conf.bShowWNC) then
				self:CleanupCastbar(value);
			else
				self:PrepareCastbarForFadeout(value, fCurTime);
			end
		end
	end

	for key, value in pairs(self.fadeoutbars) do
		local val = (value.endTime - fCurTime) / (value.duration);
		if(val >= 0.0) then
			value:SetAlpha(val * value.alpha);
		else
			value:Hide();
			self:CleanupCastbar(value);
		end
	end

	-- clip test
	self:ClipTest(fCurTime);

	-- scan units for whom no events will be generated by client
	if(self.bScan) then
		for key, value in pairs(self.scan) do
			self:ScanUnit(key, value);
		end
	end

	-- timers
	if((fCurTime - self.lastTimerScan) > self.s.iTimerScanEvery) then
		self.lastTimerScan = fCurTime;

		for key, value in ipairs(self.ti_fl) do
			self:ScanTimerbar(value, fCurTime);
		end
	end
end

-- events
function Gnosis:UNIT_SPELLCAST_SUCCEEDED(event, unit, spell, rank)
	local cb;
	if(unit == "player") then
		local fCurTime = GetTime() * 1000.0;
		self:FindGCDBars(spell, rank, fCurTime);
		if(self.iSwing == 2) then
			if(spell == self.strAutoShot) then
				self:FindSwingTimers("sr", spell, self.iconAutoShot, fCurTime, false);
				self:FindSwingTimers("smr", spell, self.iconAutoShot, fCurTime, false);
			elseif(spell == self.strShootWand) then
				self:FindSwingTimers("sr", spell, self.iconShootWand, fCurTime, false);
				self:FindSwingTimers("smr", spell, self.iconShootWand, fCurTime, false);
			end
		end
	end
end

function Gnosis:CalcLag(fCurTime)
	self.lag = fCurTime - self.lastSpellSent;
end

function Gnosis:UNIT_SPELLCAST_START(event, unit, spell, rank)
	local cb = self:FindCB(unit);
	if(cb) then
		local fCurTime = GetTime() * 1000.0;
		self:CalcLag(fCurTime);
		repeat
			self:SetupCastbar(cb, false, fCurTime);
			cb = self:FindCBNext(unit);
		until cb == nil;
	end

	if(unit == "player") then
		local fCurTime = GetTime() * 1000.0;
		self:FindGCDBars(spell, rank, fCurTime);

		if(self.iLastTradeSkillCnt) then
			self.iLastTradeSkillCnt = self.iLastTradeSkillCnt - 1;
			self.bNewTradeSkill = nil;
		end
	end
end

function Gnosis:UNIT_SPELLCAST_CHANNEL_START(event, unit, spell)
	local cb = self:FindCB(unit);
	if(cb) then
		local fCurTime = GetTime() * 1000.0;
		self:CalcLag(fCurTime);
		repeat
			self:SetupCastbar(cb, true, fCurTime);
			cb = self:FindCBNext(unit);
		until cb == nil;
	end

	-- clip test
	if(unit == "player") then
		-- generate new clip test data
		self:SetupChannelData();
	end
end

function Gnosis:UNIT_SPELLCAST_STOP(event, unit, spell)
	local cb = self:FindCB(unit);
	if(cb) then
		local fCurTime = GetTime() * 1000.0;
		repeat
			if(cb.bActive) then
				local conf = cb.conf;
				if((conf.bUnlocked or conf.bShowWNC) and not (cb.bIsTrade and cb.tscnt > 1)) then
					self:CleanupCastbar(cb);
				elseif(not (cb.bIsTrade and cb.tscnt > 1)) then
					self:PrepareCastbarForFadeout(cb, fCurTime);
					if(conf.bColSuc) then
						cb.cbs:Hide();
						cb.bar:SetStatusBarColor(unpack(conf.colSuccess));
						cb.bar:SetValue(1.0);
					end
				end
			end
			cb = self:FindCBNext(unit);
		until cb == nil;
	end
end

function Gnosis:UNIT_SPELLCAST_CHANNEL_STOP(event, unit, spell)
	local cb = self:FindCB(unit);
	if(cb) then
		local fCurTime = GetTime() * 1000.0;
		repeat
			if(cb.bActive) then
				local conf = cb.conf;
				if(conf.bUnlocked or conf.bShowWNC) then
					self:CleanupCastbar(cb);
				else
					self:PrepareCastbarForFadeout(cb, fCurTime);
				end
			end
			cb = self:FindCBNext(unit);
		until cb == nil;
	end

	-- clip test
	if(unit == "player") then
		-- request unintentional clipping test
		self:RequestClipTest();
	end
end

function Gnosis:UNIT_SPELLCAST_CHANNEL_UPDATE(event, unit)
	local cb = self:FindCB(unit);
	if(cb) then
		repeat
			if(cb.bActive) then
				local spell, _, _, _, startTime, endTime = UnitChannelInfo(unit);
				if(spell) then
					self:UpdateCastbar(cb, startTime, endTime, spell);
				end
			end
			cb = self:FindCBNext(unit);
		until cb == nil;
	end

	-- clip test
	if(unit == "player") then
		-- update clipping test
		self:UpdateClipTest();
	end
end

function Gnosis:UNIT_SPELLCAST_DELAYED(event, unit)
	local cb = self:FindCB(unit);
	if(cb) then
		repeat
			if(cb.bActive) then
				local spell, _, _, _, startTime, endTime = UnitCastingInfo(unit);
				if(spell) then
					self:UpdateCastbar(cb, startTime, endTime, spell);
				end
			end
			cb = self:FindCBNext(unit);
		until cb == nil;
	end
end

function Gnosis:UNIT_SPELLCAST_INTERRUPTIBLE(event, unit)
	local cb = self:FindCB(unit);
	if(cb) then
		repeat
			if(cb.bActive) then
				cb.bar:SetStatusBarColor(unpack(cb.conf.colBar));
				self:SetBorderColor(cb, cb.conf.colBorder, cb.conf.colBarBg);
				cb.sicon:Hide();
			end
			cb = self:FindCBNext(unit);
		until cb == nil;
	end
end

function Gnosis:UNIT_SPELLCAST_NOT_INTERRUPTIBLE(event, unit)
	local cb = self:FindCB(unit);
	if(cb) then
		repeat
			if(cb.bActive) then
				cb.bar:SetStatusBarColor(unpack(cb.conf.colBarNI));
				self:SetBorderColor(cb, cb.conf.colBorderNI, cb.conf.colBarBg);
				if(cb.conf.bShowShield) then
					cb.sicon:Show();
				else
					cb.sicon:Hide();
				end
			end
			cb = self:FindCBNext(unit);
		until cb == nil;
	end
end

function Gnosis:UNIT_SPELLCAST_INTERRUPTED(event, unit, spell, rank, id)
	local cb = self:FindCB(unit);
	if(cb) then
		local fCurTime = GetTime() * 1000.0;
		repeat
			if(cb.bActive) then
				local conf = cb.conf;
				cb.bar:SetValue(cb.channel and 0 or 1.0);
				if(cb.channel) then
					cb.bar:SetStatusBarColor(unpack(conf.colInterrupted));
				end

				if(cb.bIsTrade) then
					-- tradeskill interrupted
					cb.bIsTrade = nil;
				end

				if(conf.bUnlocked or conf.bShowWNC) then
					self:CleanupCastbar(cb);
				else
					self:PrepareCastbarForFadeout(cb, fCurTime);
					cb.cbs:Hide();
					if(not cb.channel) then cb.bar:SetStatusBarColor(unpack(conf.colInterrupted)); end
					cb.bar:SetValue(cb.channel and 0 or 1.0);
				end
			end
			cb = self:FindCBNext(unit);
		until cb == nil;
	end
end

function Gnosis:UNIT_SPELLCAST_FAILED(event, unit, spell, rank, id)
	local cb = self:FindCB(unit);
	if(cb) then
		local fCurTime = GetTime() * 1000.0;
		repeat
			if(cb.bActive) then
				local conf = cb.conf;
				if(cb.id and cb.id == id) then
					cb.bar:SetValue(cb.channel and 0 or 1.0);
					if(cb.channel) then cb.bar:SetStatusBarColor(unpack(conf.colFailed)); end

					if(conf.bUnlocked or conf.bShowWNC) then
						self:CleanupCastbar(cb);
					else
						self:PrepareCastbarForFadeout(cb, fCurTime);
						cb.cbs:Hide();
						if(not cb.channel) then cb.bar:SetStatusBarColor(unpack(conf.colFailed)); end
						cb.bar:SetValue(cb.channel and 0 or 1.0);
					end
				end
			end
			cb = self:FindCBNext(unit);
		until cb == nil;
	end
end

Gnosis.UNIT_SPELLCAST_FAILED_QUIET = Gnosis.UNIT_SPELLCAST_FAILED;

function Gnosis:PLAYER_REGEN_DISABLED()
	self.curincombattype = 2;	-- in combat "flag"
end

function Gnosis:PLAYER_REGEN_ENABLED()
	self.curincombattype = 3;	-- out of combat "flag"
end

function Gnosis:COMBAT_LOG_EVENT_UNFILTERED(_, ts, event, _, sguid, _, _, _, dguid, dname, _, _, sid, spellname, _, dmg, oh, _, bcritheal, _, _, bcrit)
	if(sguid == self.guid) then	-- player
		local fCurTime = GetTime() * 1000;

		if(event == "SPELL_DAMAGE" or event == "SPELL_MISSED" or event == "SPELL_PERIODIC_DAMAGE" or event == "SPELL_PERIODIC_MISSED" or event == "SPELL_HEAL") then
			-- ticks from channeled spell?
			local cc, nc = self.curchannel, self.nextchannel;
			local selcc = (cc and cc.spell == spellname) and cc or ((nc and nc.spell == spellname) and nc or nil);
			local selccnext = (cc and cc.spell == spellname) and false or ((nc and nc.spell == spellname) and true or false);

			if(selcc) then
				-- tick
				local dmgdone = (event == "SPELL_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE" or event == "SPELL_HEAL") and dmg or 0;
				selcc.type = (event == "SPELL_HEAL");
				selcc.dmg = selcc.dmg + dmgdone;
				selcc.eh = selcc.eh + (event == "SPELL_HEAL" and (dmg - oh) or 0);
				selcc.oh = selcc.oh + (event == "SPELL_HEAL" and oh or 0);

				if(not selcc.baeo and selcc.lastticktime and (GetTime() * 1000) - selcc.lastticktime < 100) then
					-- mastery tick
					selcc.mastery = selcc.mastery + 1;
				else
					-- non mastery tick
					selcc.ticks = selcc.ticks + 1;
					
					if(selcc.bticksound) then
						self:PlaySounds();
					end
				end

				selcc.lastticktime = GetTime() * 1000;
				selcc.hits = (bcrit or (event == "SPELL_MISSED" or event == "SPELL_PERIODIC_MISSED")) and selcc.hits or (selcc.hits + 1);
				selcc.crits = (bcrit and (event == "SPELL_DAMAGE" or event == "SPELL_PERIODIC_DAMAGE")) and (selcc.crits + 1) or selcc.crits;
				selcc.crits = (bcritheal and event == "SPELL_HEAL") and (selcc.crits + 1) or selcc.crits;
				
				-- cliptest enable and non aoe spell?
				if(selcc.bcliptest and not selcc.baeo) then
					if((not selccnext and (cc and nc)) or selcc.ticks >= selcc.maxticks) then
						-- max ticks or last tick for current channel
						-- check channeled spell out at once
						selcc.freqtest = selcc.freqtest and min(selcc.freqtest,fCurTime) or fCurTime;
						selcc.fforcedtest = selcc.fforcedtest and min(selcc.fforcedtest,fCurTime) or fCurTime;
					end
				end
			end
		elseif(self.bSwingBar and self.iSwing == 1) then
			if(event == "SPELL_EXTRA_ATTACKS") then
				self.iExtraSwings = dmg;	-- amount of extra swings, cannot use arg12 with cataclysm
				self.bNextSwingNotExtra = true;
			elseif(event == "SWING_DAMAGE" or event == "SWING_MISSED") then
				if(self.iExtraSwings > 0 and not self.bNextSwingNotExtra) then
					self.iExtraSwings = self.iExtraSwings - 1;
				else
					self.bNextSwingNotExtra = false;
					_, _, self.iconAutoAttack = GetSpellInfo(6603);
					self:FindSwingTimers("sm", self.strAutoAttack, self.iconAutoAttack, fCurTime, true);
					self:FindSwingTimers("smr", self.strAutoAttack, self.iconAutoAttack, fCurTime, true);
				end
			end
		end
		
		if (self.ti_icd[spellname] and event ~= "SPELL_CAST_FAILED") then
			--print("player", spellname, self.ti_icd[spellname].duration, event);
			
			if (self.ti_icd_active[spellname] == nil or not self.ti_icd[spellname].norefresh) then
				self.ti_icd_active[spellname] = fCurTime + self.ti_icd[spellname].duration;
			end
		end
	elseif(dguid == self.guid) then	-- player is target
		if(event == "SWING_MISSED" and sid == "PARRY") then
			local fCurTime = GetTime() * 1000;
			-- parry haste
			Gnosis:FindSwingTimersParry("sm", fCurTime);
			Gnosis:FindSwingTimersParry("smr", fCurTime);
		end
		
		if (self.ti_icd[spellname] and event ~= "SPELL_CAST_FAILED") then
			--print("is target", spellname, self.ti_icd[spellname].duration, event);
			
			if (self.ti_icd_active[spellname] == nil or not self.ti_icd[spellname].norefresh) then
				self.ti_icd_active[spellname] = GetTime() * 1000 + self.ti_icd[spellname].duration;
			end
		end
	end
end

function Gnosis:UNIT_SPELLCAST_SENT(event, unit, _, _, target)
	-- latency estimation
	self.lastSpellSent = GetTime() * 1000;
	self.strLastTarget = (target and target ~= "") and target or nil;

	-- grab unit class of target if possible
	if(self.strLastTarget) then
		local _, class = UnitClass(target);
		local guid = nil;

		if(class) then
			self.strLastTargetClass = class;
		else
			-- try to get class from target and mouseover
			local unit_ = (UnitName("target") == target) and "target" or
				((UnitName("mouseover") == target) and "mouseover" or nil);

			if(unit_ and UnitIsPlayer(unit_)) then
				_, self.strLastTargetClass = UnitClass(unit_);
			else
				self.strLastTargetClass = nil;
			end
		end
	else
		self.strLastTargetClass = nil;
	end
end

function Gnosis:MIRROR_TIMER_START(event, timer, curval, maxval, scale, paused, label)
	local cb = self:FindCB("mirror");
	if(cb) then
		local fCurTime = GetTime() * 1000;
		repeat
			self:SetupMirrorbar(cb, label, scale < 0 and true or false, curval / (abs(scale)) , maxval / (abs(scale)), fCurTime, timer);
			cb = self:FindCBNext("mirror");
		until cb == nil;
	end
end

function Gnosis:MIRROR_TIMER_STOP(event, timer)
	local cb = self:FindCB("mirror");
	if(cb) then
		local fCurTime = GetTime() * 1000;
		repeat
			if(cb.bActive) then
				local conf = cb.conf;
				if(cb.castname == timer) then
					for i = 1,3 do
						local timer, init, maxval, scale, paused, label = GetMirrorTimerInfo(i);
						if(timer and timer ~= cb.castname and init ~= 0 and maxval ~= 0) then
							local curval = GetMirrorTimerProgress(timer);

							if(self:SetupMirrorbar(cb, label, scale < 0 and true or false, curval / (abs(scale)) , maxval / (abs(scale)), fCurTime, timer)) then
								return;
							end
						end
					end

					if(conf.bUnlocked or conf.bShowWNC) then
						self:CleanupCastbar(cb);
					else
						self:PrepareCastbarForFadeout(cb, fCurTime);
					end
				end
			end
			cb = self:FindCBNext("mirror");
		until cb == nil;
	end
end

function Gnosis:PLAYER_UNGHOST()
	self:MIRROR_TIMER_STOP();
end

function Gnosis:PLAYER_ALIVE()
	self:MIRROR_TIMER_STOP();
end

function Gnosis:PLAYER_ENTERING_WORLD()
	-- create spellcasting events for focus/target when entering world
	if(UnitCastingInfo("focus")) then
		Gnosis:UNIT_SPELLCAST_START("UNIT_SPELLCAST_START", "focus");
	elseif(UnitChannelInfo("focus")) then
		Gnosis:UNIT_SPELLCAST_CHANNEL_START("UNIT_SPELLCAST_CHANNEL_START", "focus");
	else
		Gnosis:UNIT_SPELLCAST_CHANNEL_STOP("UNIT_SPELLCAST_CHANNEL_STOP", "focus");
	end

	if(UnitCastingInfo("target")) then
		Gnosis:UNIT_SPELLCAST_START("UNIT_SPELLCAST_START", "target");
	elseif(UnitChannelInfo("target")) then
		Gnosis:UNIT_SPELLCAST_CHANNEL_START("UNIT_SPELLCAST_CHANNEL_START", "target");
	else
		Gnosis:UNIT_SPELLCAST_CHANNEL_STOP("UNIT_SPELLCAST_CHANNEL_STOP", "target");
	end
end

function Gnosis:PLAYER_FOCUS_CHANGED()
	-- create spellcasting events for focus unit when changing focus target
	if(UnitCastingInfo("focus")) then
		Gnosis:UNIT_SPELLCAST_START("UNIT_SPELLCAST_START", "focus");
	elseif(UnitChannelInfo("focus")) then
		Gnosis:UNIT_SPELLCAST_CHANNEL_START("UNIT_SPELLCAST_CHANNEL_START", "focus");
	else
		Gnosis:UNIT_SPELLCAST_CHANNEL_STOP("UNIT_SPELLCAST_CHANNEL_STOP", "focus");
	end
end

function Gnosis:PLAYER_TARGET_CHANGED()
	-- create spellcasting events for target unit when changing target
	if(UnitCastingInfo("target")) then
		Gnosis:UNIT_SPELLCAST_START("UNIT_SPELLCAST_START", "target");
	elseif(UnitChannelInfo("target")) then
		Gnosis:UNIT_SPELLCAST_CHANNEL_START("UNIT_SPELLCAST_CHANNEL_START", "target");
	else
		Gnosis:UNIT_SPELLCAST_CHANNEL_STOP("UNIT_SPELLCAST_CHANNEL_STOP", "target");
	end
end

-- swing timer events
function Gnosis:PLAYER_ENTER_COMBAT(event)
	local _, _, offlowDmg, offhiDmg = UnitDamage("player");

	-- dual wielding? if yes don't show timer
	if(offlowDmg and not self.bIsDruid and abs(offhiDmg-offlowDmg) > 0.1) then
		self.bSwingBar = false;
		return;
	else
		self.iSwing = 1;
	end

	for key, value in pairs(self.castbars) do
		local conf = Gnosis.s.cbconf[key];
		if(conf.bEn and (conf.unit == "sm" or conf.unit == "smr")) then
			self.bSwingBar = true;
			self.iExtraSwings = 0;
			self.bNextSwingNotExtra = false;
			return;
		end
	end
end

function Gnosis:PLAYER_LEAVE_COMBAT(event)
	if(self.iSwing == 1) then
		self.iSwing = 0;
		self.bSwingBar = false;
	end
end

function Gnosis:START_AUTOREPEAT_SPELL(event)
	self.iSwing = 2;

	for key, value in pairs(self.castbars) do
		local conf = Gnosis.s.cbconf[key];
		if(conf.bEn and (conf.unit == "sr" or conf.unit == "smr")) then
			self.bSwingBar = true;
			return;
		end
	end
end

function Gnosis:STOP_AUTOREPEAT_SPELL(event)
	if(self.iSwing == 2) then
		self.iSwing = 0;
		self.bSwingBar = false;
	end
end

function Gnosis:DISPLAY_SIZE_CHANGED()
end

function Gnosis:PLAYER_TALENT_UPDATE()
	self.iCurSpec = GetActiveSpecGroup();

	for key, value in pairs(self.castbars) do
		local conf = Gnosis.s.cbconf[key];
		if(conf.bEn and conf.spec > 0) then
			self:SetBarParams(value.name)
		end
	end

	self:CreateCBTables();
end
