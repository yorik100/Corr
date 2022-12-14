-- This script is designed to show Lua beginners how to create there own scripts and using Corrupt API.
-- There will be alot of comments in this script, so please read it carefully and try to understand what each line is doing.
-- This script should define the baseline quality of a script what we expect to be released at Corrupt.
-- If you have any questions, please ask on discord or on the forum.

-- Small usefull functions which were needed to find buff names, object names, etc.
-- These functions are not needed for the script to work, but they are nice to have.

-- Gets all buff that the unit has and prints them to the console.
-- function Debug_FindBuff(unit)
--     for index, value in ipairs(unit.buffs) do
--         print(value.name .. " Counter: " .. value.counter .. " Stacks: " .. value.stacks)
--     end
-- end
local JSON = require("jsonLib")
-- This callback is called when the script is loaded.
cb.add(cb.load, function()

	if menu.delete('open_Xerath') then return end
	-- Check if the current champion is Annie. If not, don't load the script
	if player.skinName ~= "Xerath" then return end
	print("[OpenXerath] Open Xerath loaded")

	local data = "https://raw.githubusercontent.com/yorik100/Corr/main/OpenXerath/data.json"
	local main = "https://raw.githubusercontent.com/yorik100/Corr/main/OpenXerath/main.lua"
	local version = nil
	local scriptName = "OpenXerath"
	_G.net.getAsync(data, function(response)
		if not response then
			return chat.showChat("<font color=\"#FF0000\">[" .. self.scriptName .. "]</font> <font color=\"#FFFFFF\">An error has occurred: no response</font>")
		end

		if response.status ~= 200 then
			return chat.showChat("<font color=\"#FF0000\">[" .. self.scriptName .. "]</font> <font color=\"#FFFFFF\">An error has occurred: " .. response.status .. "</font>")
		end
		local json = JSON.decode(response.text)

		version = json["Version"]
		_G.net.autoUpdateDirect(data, main, function(success)
			if success then
				chat.showChat("<font color=\"#1E90FF\">[" .. scriptName .. "]</font> <font color=\"#FFFFFF\">Update completed successfully, please press F5 to refresh! (v" .. version .. ")</font>")
			else
				chat.showChat("<font color=\"#1E90FF\">[" .. scriptName .. "]</font> <font color=\"#FFFFFF\">Welcome " .. user.data.name .. ", " .. scriptName .." is up to date ! (v" .. version .. " or higher)</font>")
			end
		end)
	end)
	fileList = fs.getFiles(fs.scriptPath .. scriptName)
	local tempText = ""
	local shouldPrint = false
	for key, value in ipairs(fileList) do
		local realPath = string.gsub((fs.scriptPath .. scriptName .. "\\"), "\\", "/")
		local fileName = tostring(string.gsub(value, realPath, ""))
		local fileList = {"data.json", "main.lua", "jsonLib.lua"}
		local tempFlag = false
		for key, value in ipairs(fileList) do
			if fileName == value then
				tempFlag = true
			end
		end
		if not tempFlag then
			tempText = tempText .. " " .. fileName
			shouldPrint = true
		end
	end
	if shouldPrint then
		chat.showChat("<font color=\"#1E90FF\">[" .. scriptName .. "]</font> <font color=\"#FFFFFF\">Unused file(s) found in " .. scriptName .. " folder :" .. tempText)
	end

	-- Create a 'class/table' where all the functions will be stored
	-- Thanks Torb
	local HitchanceMenu = { [0] = HitChance.Low, HitChance.Medium, HitChance.High, HitChance.VeryHigh, HitChance.DashingMidAir }
	local buffToCheck = {"MorganaE", "Highlander", "PantheonE", "KayleR", "TaricR", "SivirE", "FioraW", "NocturneShroudofDarkness", "kindredrnodeathbuff", "YuumiWAttach", "UndyingRage", "ChronoShift", "itemmagekillerveil", "bansheesveil", "malzaharpassiveshield", "XinZhaoRRangedImmunity", "ChronoRevive", "bardrstasis", "ZhonyasRingShield", "gwenwmissilecatcher", "fizzeicon", "LissandraRSelf", "zedrtargetmark", "UdyrE2Activation"}
	local selfBuffToCheck = {"XerathArcanopulseChargeUp", "xerathrshots", "xerathascended2onhit", "SRX_DragonSoulBuffHextech", "srx_dragonsoulbuffhextech_cd", "SRX_DragonSoulBuffInfernal", "SRX_DragonSoulBuffInfernal_Cooldown", "ASSETS/Perks/Styles/Inspiration/FirstStrike/FirstStrike.lua", "ASSETS/Perks/Styles/Inspiration/FirstStrike/FirstStrikeAvailable.lua", "ASSETS/Perks/Styles/Domination/DarkHarvest/DarkHarvest.lua", "ASSETS/Perks/Styles/Domination/DarkHarvest/DarkHarvestCooldown.lua", "ElderDragonBuff", "4628marker"}
	local Xerath = {}
	local buffs = {}
	local flaggingFlag = false
	local flaggingPos = nil
	local flaggingTime = 0
	local rshots = 0
	local particleWList = {}
	local particleRList = {}
	local particleEList = {}
	local particleGwenList = {}
	local targetList = {}
	local particleFlag = false
	local disappearedE = 0
	local disappearedRTime = 0
	local disappearedRObject = {}
	local oldValue = nil
	local oldXValue = nil
	local oldYValue = nil
	local instantQCast = {}
	local isUlting = nil
	local QTarget = nil
	local RTarget = nil
	local debugList = {}
	local changedList = nil
	local listChanged = nil
	local changed = nil
	local changeTime = nil
	local drawRDamage = {}
	local RKillable = {}
	local drawRValue = {}
	local killList = {}
	local casting = {}
	local particleCastList = {}
	local rBuff = nil
	local qBuff = nil
	local ElderBuff = nil
	local hasCasted = false
	local allyREkkoCast = nil
	local allyREveCast = nil
	local teleportOwner = nil

	-- Creating a debug print function, so the developer can easily check the output and if someone
	-- wants to play with the simple script can disable the debug prints in the console
	function Xerath:DebugPrint(...)
		if not self.XerathMenu.debug_print:get() then return end
		print("[OpenXerath] ".. ...)
	end

	-- This will be our initialization function, we call it to load the script and all its variables and functions inside
	function Xerath:__init()

		self.castTime = {0.005,0.25,0.25,0,0.5}
		self.castTimeClock = {0,0,0,0,0}

		-- tables with spell data for prediction
		self.eData = {
			delay = 0.25,
			speed = 1400,
			range = 1065,
			radius = 60,
			collision = { -- if not defined -> no collision calcs
				hero = SpellCollisionType.Hard,
				-- Hard = Collides with object and stops on collision
				minion = SpellCollisionType.Hard,
				-- Soft = Collides with object and passes through them.
				tower = SpellCollisionType.None,
				-- None = Doesn't collide with object. Also default if not defined
				extraRadius = 10,
				-- if not defined -> default = 0
				-- if not defined -> default = CollisionFlags.None
				flags = bit.bor(CollisionFlags.Windwall, CollisionFlags.Samira, CollisionFlags.Braum)
			},
			type = spellType.linear,
			rangeType = 1,
			boundingRadiusMod = true
		}
		self.eCollideData = {
			delay = 0,
			speed = 1400,
			range = 1065,
			radius = 60,
			collision = { -- if not defined -> no collision calcs
				hero = SpellCollisionType.Hard,
				-- Hard = Collides with object and stops on collision
				minion = SpellCollisionType.Hard,
				-- Soft = Collides with object and passes through them.
				tower = SpellCollisionType.None,
				-- None = Doesn't collide with object. Also default if not defined
				extraRadius = 10,
				-- if not defined -> default = 0
				-- if not defined -> default = CollisionFlags.None
				flags = bit.bor(CollisionFlags.Windwall, CollisionFlags.Samira, CollisionFlags.Braum)
			},
			type = spellType.linear,
			rangeType = 1,
			boundingRadiusMod = true
		}
		self.qData = {
			delay = 0.5,
			speed = math.huge,
			range = 750,
			radius = 70,
			type = spellType.linear,
			rangeType = 1,
			boundingRadiusMod = true
		}
		self.qChargeData = {
			delay = 0.5,
			speed = 1000,
			range = 1500,
			radius = 70,
			type = spellType.linear,
			rangeType = 1,
			from = player.pos,
			boundingRadiusMod = true
		}
		self.wData = {
			delay = 0.75,
			speed = math.huge,
			range = 1000,
			radius = 275,
			type = spellType.circular,
			rangeType = 0,
			boundingRadiusMod = true
		}
		self.w2Data = {
			delay = 0.75,
			speed = math.huge,
			range = 1000,
			radius = 125,
			type = spellType.circular,
			rangeType = 0,
			boundingRadiusMod = true
		}
		self.rData = {
			delay = 0.6,
			speed = math.huge,
			range = 5000,
			radius = 200,
			type = spellType.circular,
			rangeType = 0,
			boundingRadiusMod = true
		}

		-- self.AnnieMenu will store all the menu data which got returned from the Annie:CreateMenu function
		self.XerathMenu = self:CreateMenu()
		for _, hero in pairs(objManager.heroes.list) do
			for _, buff in pairs(hero.buffs) do
				if buff and buff.valid then
					-- print(buff.name)
					for i, name in ipairs(buffToCheck) do
						if not buff.caster or buff.caster.handle == player.handle then break end
						if buff.name == name then
							self:DebugPrint(hero.skinName .. " -> Buff added (" .. tostring(buff.name) .. ")" .. (buff.caster and (" from " .. buff.caster.name) or ""))
							buffs[hero.handle .. buff.name] = buff
							break
						end
					end
					for i, name in ipairs(selfBuffToCheck) do
						if buff.caster and buff.caster.handle ~= player.handle then break end
						if buff.name == name then
							self:DebugPrint(hero.skinName .. " -> Buff added (" .. tostring(buff.name) .. ")" .. " from " .. buff.caster.name)
							buffs[hero.handle .. buff.name] = buff
							break
						end
					end
				end
			end
		end

		-- Adding all callbacks that will be used in the script, the triple dots (...) means that the function will
		-- take the return value of the function before it, so we can use it in our function
		cb.add(cb.tick,function(...) self:OnTick(...) end)
		cb.add(cb.draw,function(...) self:OnDraw(...) end)
		cb.add(cb.buff,function(...) self:OnBuff(...) end)
		cb.add(cb.glow,function(...) self:OnGlow(...) end)
		cb.add(cb.create,function(...) self:OnCreate(...) end)
		cb.add(cb.delete,function(...) self:OnDelete(...) end)
		cb.add(cb.processSpell,function(...) self:OnCastSpell(...) end)
		cb.add(cb.basicAttack,function(...) self:OnBasicAttack(...) end)
	end

	-- This function will create the menu and return it to the Annie:__init function and store it in self.AnnieMenu
	function Xerath:CreateMenu()
		-- Create the main menu
		local mm = menu.create('open_Xerath', 'OpenXerath')
		-- Create a submenu inside the main menu
		mm:header('combo', 'Combo Mode')
		-- Create On/Off option inside the combo submenu
		mm.combo:boolean('use_q', 'Use Q', true)
		mm.combo:boolean('use_w', 'Use W', true)
		mm.combo:boolean('use_e', 'Use E', true)
		-- Create slider option inside the combo submenu
		-- mm.combo:slider('multi_r', 'Multi target R', 2, 3, 5, 1)
		-- mm.combo:boolean('block_spells', 'Save spells for stun (E -> Q / W)', true)
		mm:header('harass', 'Harass Mode')
		mm.harass:boolean('use_q', 'Use Q', true)
		mm.harass:boolean('use_w', 'Use W', true)        -- mm.harass:boolean('block_spells', 'Save spells for stun (E -> Q / W)', true)
		-- mm:header('killsteal', 'KillSteal')
		-- mm.killsteal:boolean('use_r', 'Use R', true)
		-- TODO
		-- mm:header('lasthit', 'LastHit')
		-- mm.lasthit:boolean('use_w', 'Use W', true)
		-- mm:header('laneclear', 'LaneClear')
		-- mm.laneclear:boolean('use_w', 'Use W', true)
		-- mm:header('jungleclear', 'JungleClear')
		-- mm.jungleclear:boolean('use_w', 'Use W', true)
		mm:header('drawings', 'Drawings')
		mm.drawings:boolean('draw_q_range', 'Draw Q Range', true)
		mm.drawings:boolean('draw_w_range', 'Draw W Range', true)
		mm.drawings:boolean('draw_e_range', 'Draw E Range', true)
		mm.drawings:boolean('draw_r_range', 'Draw R Range', true)
		mm.drawings:boolean('draw_r_range_minimap', 'Draw R Range on minimap', true)
		mm.drawings:boolean('draw_near_mouse_r_range', 'Draw R2 near mouse range', true)
		mm.drawings:boolean('draw_r_damage', 'Draw R Damage', true)
		mm.drawings:boolean('draw_r_damage_text', 'Draw R Damage Text', true)
		mm.drawings:boolean('draw_r_list', 'Draw R Killable List', true)
		mm.drawings:slider('draw_r_list_x', 'X Position of list', 1400, 0, 1500, 10)
		mm.drawings:slider('draw_r_list_y', 'Y Position of list', 50, 0, 1000, 10)
		mm.drawings:boolean('draw_r_target', 'Draw R Target', true)
		mm.drawings:boolean('draw_q_target', 'Draw Q Target', true)
		mm.drawings:boolean('draw_debug_w', 'Draw W Hitbox', true)
		mm.drawings:boolean('draw_debug_e', 'Draw E Trajectory', true)
		mm.drawings:boolean('draw_debug_r', 'Draw R Hitbox', true)
		mm:header('misc', 'Misc')
		mm.misc:boolean('e_dash', 'Auto E on dashes', true)
		mm.misc:boolean('w_dash', 'Auto W on dashes', true)
		mm.misc:boolean('q_dash', 'Auto Q release on dashes', true)
		mm.misc:boolean('e_channel', 'Auto E on channels', true)
		mm.misc:boolean('w_channel', 'Auto W on channels', true)
		mm.misc:boolean('e_stun', 'Auto E on stuns', true)
		mm.misc:boolean('w_stun', 'Auto W on stuns', true)
		mm.misc:boolean('e_stasis', 'Auto E on stasis', true)
		mm.misc:boolean('w_stasis', 'Auto W on stasis', true)
		mm.misc:boolean('q_stasis', 'Auto Q release on stasis', true)
		mm.misc:boolean('e_casting', 'Auto E on spellcast/attack', true)
		mm.misc:boolean('w_casting', 'Auto W on spellcast/attack', true)
		mm.misc:boolean('q_casting', 'Auto Q release on spellcast/attack', true)
		mm.misc:boolean('e_particle', 'Auto E on particles', true)
		mm.misc:boolean('w_particle', 'Auto W on particles', true)
		mm.misc:boolean('q_particle', 'Auto W release on particles', true)
		mm.misc:boolean('w_center_logic', 'Try to W center', true)
		mm.misc:boolean('auto_r', 'Auto R2', false)
		mm.misc:keybind('manual_r', 'Manual R', 0x54, false, false)
		mm.misc:boolean('manual_r_dont_r1', 'Manual R only if ulting', true)
		mm.misc:slider('near_mouse_r', 'R2 near mouse range', 750, 0, 1500, 10)
		mm.misc:keybind('manual_e', 'Manual E', 0x4A, false, false)
		mm.misc:boolean('w_before_e', 'Use W before firing manual E', false)
		mm.misc:boolean('shield_logic', 'Avoid targeting shielded players', true)
		mm:header('prediction', 'Hitchance')
		mm.prediction:list('q_hitchance', 'Q Hitchance', { 'Low', 'Medium', 'High', 'Very High', 'Undodgeable' }, 2)
		mm.prediction:list('w_hitchance', 'W Hitchance', { 'Low', 'Medium', 'High', 'Very High', 'Undodgeable' }, 3)
		mm.prediction:list('e_hitchance', 'E Hitchance', { 'Low', 'Medium', 'High', 'Very High', 'Undodgeable' }, 3)
		mm.prediction:list('r_hitchance', 'R Hitchance', { 'Low', 'Medium', 'High', 'Very High', 'Undodgeable' }, 2)
		-- Create On/Off option inside the main menu
		mm:boolean('debug_print', 'Debug Print', true)
		mm:boolean('debug_print_buffs', 'Debug Print Buffs', false)
		-- Return menu data
		return mm
	end

	-- Function to get a specific buff on an entity
	local gameObject = _G.gameObject
	function gameObject:getBuff(name)
		table.insert(debugList, "GetBuff " .. name)
		local buff = buffs[self.handle .. name]
		if buff then
			if buff.valid then
				table.remove(debugList, #debugList)
				return buff
			else
				buffs[self.handle .. name] = nil
			end
		end
		table.remove(debugList, #debugList)
	end

	function Xerath:debugFlush()
		if debugList[1] then
			local debugText = ""
			for key,value in ipairs(debugList) do
				debugText = debugText .. " " .. value
			end
			print("[OpenDebug] Error found in" .. debugText)
			debugList = {}
		end
	end

	function Xerath:gwenWParticlePos(target)
		local particle = particleGwenList[target.handle]
		if particle then
			return particle.pos
		end
	end

	-- To know the remaining time of someone's invulnerable or spellshielded
	function Xerath:godBuffTime(target)
		local buffTime = 0
		local buffList = {"KayleR", "TaricR", "SivirE", "FioraW", "PantheonE", "NocturneShroudofDarkness", "kindredrnodeathbuff", "XinZhaoRRangedImmunity", "gwenwmissilecatcher", "fizzeicon"}
		for i, name in ipairs(buffList) do
			local buff = target:getBuff(name)
			if buff and buffTime < buff.remainingTime and (buff.name ~= "PantheonE" or self:IsFacingPlayer(target)) and (buff.name ~= "XinZhaoRRangedImmunity" or player.pos:distance2D(target.pos) > 450) and (buff.name ~= "gwenwmissilecatcher" or player.pos:distance2D(self:gwenWParticlePos(target)) > 440) then
				buffTime = buff.remainingTime
				if buff.name == "PantheonE" then
					buffTime = buffTime + 0.2
				end
			end
		end
		local godBuffTime = (buffs["GodBuffTime" .. target.handle] and buffs["GodBuffTime" .. target.handle] - game.time or 0)
		if godBuffTime and buffTime < godBuffTime then
			buffTime = godBuffTime
		end
		return buffTime
	end

	function Xerath:noKillBuffTime(target)
		local buffTime = 0
		local buffList = {"UndyingRage", "ChronoShift"}
		for i, name in ipairs(buffList) do
			local buff = target:getBuff(name)
			if buff and buffTime < buff.remainingTime then
				buffTime = buff.remainingTime
			end
		end
		return buffTime
	end

	function Xerath:getStasisTime(target)
		local buffTime = 0
		local buffList = {"ChronoRevive", "BardRStasis", "ZhonyasRingShield", "LissandraRSelf"}
		for i, name in ipairs(buffList) do
			local buff = target:getBuff(name)
			if buff and buffTime < buff.remainingTime then
				buffTime = buff.remainingTime
			end
		end
		local GATime = ((target.characterState.statusFlags == 65537 and buffs["Time" .. target.handle]) and buffs["Time" .. target.handle] - game.time or 0)
		if GATime and buffTime < GATime then
			buffTime = GATime
		end
		return buffTime
	end

	function Xerath:invisibleValid(target, distance)
		return (target.isValid and target.pos and target.pos:distance2D(player.pos) <= distance and target.isRecalling and navMesh.isInFOW(target.pos) and not target.isDead and not target.isInvulnerable and target.isTargetableToTeamFlags and target.isTargetable)
	end

	function Xerath:WillGetHitByW(target)
		if not target then return false end
		for key,value in ipairs(particleWList) do
			if value.obj and (target.path and pred.positionAfterTime(target, math.max(0, (value.time + 0.7 - game.time))):distance2D(value.obj.pos) <= self.wData.radius or target.pos:distance2D(value.obj.pos) <= self.wData.radius) then
				return true
			end
		end
		return false
	end

	function Xerath:WillGetHitByR(target)
		if not target then return false end
		if disappearedRObject.obj and disappearedRObject.time and disappearedRObject.time + 0.099 > game.time then
			local value = disappearedRObject.obj
			if value and target.pos:distance2D(value.pos) and target.pos:distance2D(value.pos) <= self.rData.radius then
				return true
			end
		end
		for key,value in ipairs(particleRList) do
			if value.obj and (target.path and pred.positionAfterTime(target, math.max(0, (value.time + 0.55 - game.time))):distance2D(value.obj.pos) <= self.rData.radius or target.pos:distance2D(value.obj.pos) <= self.rData.radius) then
				return true
			end
		end
		return false
	end

	function Xerath:MissileE(target)
		for key, value in ipairs(particleEList) do
			local endPos = value.obj.endPosition
			local missingLivingTime = game.time - value.time
			local traveledDistance = missingLivingTime * value.obj.missileSpeed
			local startPos = value.obj.startPosition:extend(value.obj.endPosition, traveledDistance)
			local speed = value.obj.missileSpeed
			local timeToReach = startPos:distance2D(endPos)/speed
			self.eCollideData.delay = -game.latency/1000
			local totalRadius = target.boundingRadius + self.eData.radius
			if startPos:distance2D(target.pos) > totalRadius then
				self.eCollideData.from = player.pos:extend(target.pos, totalRadius)
			else
				self.eCollideData.from = target.pos
			end
			self.eCollideData.range = 1065 + target.boundingRadius
			local collisionTable = pred.findSpellCollisions(nil, self.eCollideData, startPos, endPos, timeToReach)
			local collisionTarget = collisionTable[1]
			if collisionTarget and collisionTarget.handle == target.handle then
				return true
			end
		end
	end

	-- All the charging stuff is strongly inspired from BGX charging range calcs
	function Xerath:GetChargePercentage(spell_charge_duration)
		local buff = qBuff

		if buff and buff.valid then
			return math.max(0, math.min(1, (game.time - buff.startTime + game.latency/1000) /  spell_charge_duration))
		end
		return 0
	end

	function Xerath:GetTrueChargePercentage(spell_charge_duration)
		local buff = qBuff

		if buff and buff.valid then
			return math.max(0, math.min(1, (game.time - buff.startTime) /  spell_charge_duration))
		end
		return 0
	end

	function Xerath:IsCharging()
		local buff = qBuff
		return buff and buff.valid
	end

	function Xerath:GetChargeRange(max_range, min_range, duration)
		if self:IsCharging() then
			return min_range + math.min(max_range - min_range, (max_range - min_range) * self:GetChargePercentage(duration))
		end
		return min_range
	end

	function Xerath:GetTrueChargeRange(max_range, min_range, duration)
		if self:IsCharging() then
			return min_range + math.min(max_range - min_range, (max_range - min_range) * self:GetTrueChargePercentage(duration))
		end
		return min_range
	end

	-- Thanks seidhr
	function Xerath:IsFacingPlayer(entity)
		local skillshotDirection = (entity.pos - player.pos):normalized()
		local direction = entity.direction
		local facing = skillshotDirection:dot(direction)
		return facing < 0
	end
	
	--Thanks seidhr again
	
	function Xerath:prediSlowXer(duration)
		local speedList = {}
		local slowValue = (duration/1.5)*0.4
		slowValue = slowValue - (slowValue % 0.05)
		local updatedSpeed = player.characterIntermediate.moveSpeed
		if slowValue < 0.1 then
			table.insert(speedList, updatedSpeed)
			table.insert(speedList, updatedSpeed)
		end
		for i = 0.1 - slowValue, 0.4 - slowValue, 0.05 do 
			local finalSpeed = updatedSpeed * (1 - i)
			if finalSpeed < 220 then
				finalSpeed = (finalSpeed * 0.5) + 110;
			end
			table.insert(speedList, finalSpeed)
		end
		
		totalSpeed = 0
		for key, value in pairs(speedList) do
			totalSpeed = totalSpeed + value
		end
		totalSpeed = totalSpeed / #speedList

		return totalSpeed;
	end

	function Xerath:GetExtraDamage(target, shots, predictedHealth, damageDealt, isCC, firstShot)
		local damage = 0
		local buff3 = myHero:getBuff("ASSETS/Perks/Styles/Inspiration/FirstStrike/FirstStrikeAvailable.lua")
		local buff4 = myHero:getBuff("ASSETS/Perks/Styles/Inspiration/FirstStrike/FirstStrike.lua")
		if shots <= 0 then
			local buff1 = myHero:getBuff("ASSETS/Perks/Styles/Domination/DarkHarvest/DarkHarvest.lua")
			local buff2 = myHero:getBuff("ASSETS/Perks/Styles/Domination/DarkHarvest/DarkHarvestCooldown.lua")
			local buff5 = myHero:getBuff("SRX_DragonSoulBuffInfernal_Cooldown")
			local buff6 = myHero:getBuff("SRX_DragonSoulBuffInfernal")
			local buff7 = myHero:getBuff("SRX_DragonSoulBuffHextech")
			local buff8 = myHero:getBuff("srx_dragonsoulbuffhextech_cd")
			local buff9 = myHero:getBuff("ElderDragonBuff")
			if buff1 and not buff2 and predictedHealth/target.maxHealth < 0.5 then
				damage = damage + damageLib.magical(player, target, 20 + 40 / 17 * (myHero.level - 1) + player.totalAbilityPower*0.15 + player.totalBonusAttackDamage*0.25 + buff1.stacks*5)
			end
			if buff6 and not buff5 then
				damage = damage + damageLib.magical(player, target, 80 + player.totalBonusAttackDamage*0.225 + player.totalAbilityPower*0.15 + player.bonusHealth*0.0275)
			end
			if buff7 and not buff8 then
				damage = damage + 25 + 25 / 17 * (myHero.level - 1)
			end
			if buff9 then
				local amountOfMins = math.floor(game.time/60)
				-- print(amountOfMins)
				local extraDamage = ((amountOfMins < 27) and 75 or (amountOfMins < 45 and (75 + ((amountOfMins-25)/2)*15) or 225))
				-- print(extraDamage)
				damage = damage + extraDamage
			end
		end
		local ludenSlot = nil
		local alternatorSlot = nil
		local hasLiandry = false
		local hasDemonic = false
		local hasHorizonFocus = false
		local hasRylai = false
		for i = 11, 6, -1 do
			if player:getItemID(i) == 6655 then
				ludenSlot = i
			elseif player:getItemID(i) == 3145 then
				alternatorSlot = i
			elseif player:getItemID(i) == 6653 then
				hasLiandry = true
			elseif player:getItemID(i) == 4637 then
				hasDemonic = true
			elseif player:getItemID(i) == 4628 then
				hasHorizonFocus = true
			elseif player:getItemID(i) == 3116 then
				hasRylai = true
			end
			-- print(player:getItemID(i))
			-- print(player:spellSlot(i).state)
		end
		if firstShot and alternatorSlot then
			if player:spellSlot(alternatorSlot).cooldown <= 0 then
				damage = damage + damageLib.magical(player, target, 50 + 75 / 17 * (myHero.level - 1))
			end
		end
		if firstShot and ludenSlot then
			if player:spellSlot(ludenSlot).cooldown <= 0 then
				damage = damage + damageLib.magical(player, target, 100 + player.totalAbilityPower*0.1)
			end
		end
		if shots <= 0 then
			if hasLiandry then
				damage = damage + damageLib.magical(player, target, 50+(player.totalAbilityPower*0.06)+(target.maxHealth*0.04))
			end
			if hasDemonic then
				damage = damage + damageLib.magical(player, target, target.maxHealth*0.04)
			end
		end
		if hasHorizonFocus and (isCC or hasRylai or player.pos:distance2D(target.pos) > 700 or target:getBuff("4628marker")) then
			damage = damage + (damageDealt)*0.1
		end
		if buff3 or buff4 then
			damage = damage + (damage + damageDealt)*0.09
		end
		-- print(damage)
		return damage
	end
	-- Calculates the damage of a spell on a target, if spell is on cooldown it will return 0.
	-- The time variable will be a buffer for the spell cooldown. ( If time is set to 0.5 it will ignore the cooldown of the spell if the cooldown is 0.5 seconds or less )
	function Xerath:GetDamageQ(target, time)
		local spell = player:spellSlot(SpellSlot.Q)
		if spell.level == 0 then return 0 end
		local time = time or 0
		if spell.state ~= 0 and spell.cooldown > time then return 0 end
		local damage = 30 + spell.level * 40 + player.totalAbilityPower*0.85
		local damageLibDamage = damageLib.magical(player, target, damage)
		return damageLibDamage + self:GetExtraDamage(target, 0, target.health, damageLibDamage, false, true)
	end

	function Xerath:GetDamageW(target, time)
		local spell = player:spellSlot(SpellSlot.W)
		if spell.level == 0 then return 0 end
		local time = time or 0
		if spell.state ~= 0 and spell.cooldown > time then return 0 end
		local damage = 25 + 35 * spell.level + player.totalAbilityPower*0.6
		local damageLibDamage = damageLib.magical(player, target, damage)
		return damageLibDamage + self:GetExtraDamage(target, 0, target.health, damageLibDamage, true, true)
	end

	function Xerath:GetDamageW2(target, time)
		local spell = player:spellSlot(SpellSlot.W)
		if spell.level == 0 then return 0 end
		local time = time or 0
		if spell.state ~= 0 and spell.cooldown > time then return 0 end
		local damage = (25 + 35 * spell.level + player.totalAbilityPower*0.6)*1.667
		local damageLibDamage = damageLib.magical(player, target, damage)
		return damageLibDamage + self:GetExtraDamage(target, 0, target.health, damageLibDamage, true, true)
	end

	function Xerath:GetDamageW2Alternative(target, time)
		local spell = player:spellSlot(SpellSlot.W)
		if spell.level == 0 then return 0 end
		local time = time or 0
		if spell.state ~= 0 and spell.cooldown > time then return 0 end
		local damage = (25 + 35 * spell.level + player.totalAbilityPower*0.6)*1.667
		local damageLibDamage = damageLib.magical(player, target, damage)
		return damageLibDamage + self:GetExtraDamage(target, 0, target.health, damageLibDamage, true, false)
	end

	function Xerath:GetDamageE(target, time)
		local spell = player:spellSlot(SpellSlot.E)
		if spell.level == 0 then return 0 end
		local time = time or 0
		if spell.state ~= 0 and spell.cooldown > time then return 0 end
		local damage = 50 + 30 * spell.level + player.totalAbilityPower*0.45
		local damageLibDamage = damageLib.magical(player, target, damage)
		return damageLibDamage + self:GetExtraDamage(target, 0, target.health, damageLibDamage, true, true)
	end

	function Xerath:GetDamageEAlternative(target, time)
		local spell = player:spellSlot(SpellSlot.E)
		if spell.level == 0 then return 0 end
		local time = time or 0
		if spell.state ~= 0 and spell.cooldown > time then return 0 end
		local damage = 50 + 30 * spell.level + player.totalAbilityPower*0.45
		local damageLibDamage = damageLib.magical(player, target, damage)
		return damageLibDamage + self:GetExtraDamage(target, 0, target.health, damageLibDamage, true, false)
	end

	function Xerath:GetDamageR(target, time, shots, predictedHealth, firstShot)
		local spell = player:spellSlot(SpellSlot.R)
		if spell.level == 0 then return 0 end
		local time = time or 0
		if spell.state ~= 0 and spell.cooldown > ((particleRList[1] or rBuff) and 999 or time) then return 0 end
		local damage = (150 + 50 * spell.level + player.totalAbilityPower*0.45)
		local damageLibDamage = damageLib.magical(player, target, damage)
		return damageLibDamage + self:GetExtraDamage(target, shots, predictedHealth, damageLibDamage, false, firstShot)
	end

	function Xerath:OnGlow()
		self:debugFlush()
		table.insert(debugList, "Glow")
		if self.XerathMenu.drawings.draw_q_target:get() and QTarget then
			if QTarget.isValid and not QTarget.isDead then
				QTarget:addGlow(graphics.argb(255, 255, 127, 0), ((5*-game.time) % 1) + 2, 0)
			end
		end
		if self.XerathMenu.drawings.draw_r_target:get() and RTarget then
			if RTarget.isValid and not RTarget.isDead then
				RTarget:addGlow(graphics.argb(255, 255, 0, 0), ((5*-game.time) % 1) + 2, 0)
			end
		end
		table.remove(debugList, #debugList)
	end

	function Xerath:OnCreate(object)
		table.insert(debugList, "Create")
		local particleOwner = nil
		if particleOwner then print(object.name .. " - " .. particleOwner.name) end
		if string.find(object.name, "_R_aoe_reticle_green") and string.find(object.name, "Xerath_") then
			table.insert(particleRList, {obj = object, time = game.time})
			self:DebugPrint("Added particle R")
		elseif string.find(object.name, "_W_aoe_green") and string.find(object.name, "Xerath_") then
			table.insert(particleWList, {obj = object, time = game.time})
			self:DebugPrint("Added particle W")
		elseif object.name == "XerathMageSpearMissile" and object.caster.isAlly then
			table.insert(particleEList, {obj = object, time = game.time})
			self:DebugPrint("Added missile E")
		elseif string.find(object.name, "_W_MistArea") and object.isEffectEmitter and object.asEffectEmitter.attachment.object then
			local owner = object.asEffectEmitter.attachment.object
			local owner2 = owner.asAttackableUnit.owner
			particleGwenList[owner2.handle] = object
			self:DebugPrint("Added particle Gwen")
		elseif string.find(object.name, "Twisted") and string.find(object.name, "_R_Gatemarker_Red") and object.isEffectEmitter then
			table.insert(particleCastList, {obj = object, time = game.time, castTime = 1.5, castingPos = object.pos, bounding = 65, speed = 330})
			self:DebugPrint("Added cast particle " .. object.name)
		elseif string.find(object.name, "Ekko_") and string.find(object.name, "_R_ChargeIndicator") and object.isEffectEmitter and (not allyREkkoCast or allyREkkoCast <= game.time - 0.35) then
			table.insert(particleCastList, {obj = object, time = game.time, castTime = 0.5, castingPos = object.pos, bounding = 65, speed = 340})
			self:DebugPrint("Added cast particle " .. object.name)
		elseif string.find(object.name, "Pantheon_") and string.find(object.name, "_R_Update_Indicator_Enemy") and not string.find(object.name, "PreJump") and object.isEffectEmitter then
			castPos = object.pos + object.asEffectEmitter.animationComponent.forward*1350
			table.insert(particleCastList, {obj = object, time = game.time, castTime = 2.2, castingPos = castPos, bounding = 65, speed = 345})
			self:DebugPrint("Added cast particle " .. object.name)
		elseif string.find(object.name, "Galio_") and string.find(object.name, "_R_Tar_Ground_Enemy") and object.isEffectEmitter then
			table.insert(particleCastList, {obj = object, time = game.time, castTime = 2.75, castingPos = object.pos, bounding = 80, speed = 335})
			self:DebugPrint("Added cast particle " .. object.name)
		elseif string.find(object.name, "Evelynn_") and string.find(object.name, "_R_Landing") and object.isEffectEmitter and (not allyREveCast or allyREveCast <= game.time - 0.15) then
			table.insert(particleCastList, {obj = object, time = game.time, castTime = 0.85, castingPos = object.pos, bounding = 65, speed = 335})
			self:DebugPrint("Added cast particle " .. object.name)
		elseif string.find(object.name, "Tahm")  and string.find(object.name, "W_ImpactWarning_Enemy") and object.isEffectEmitter then
			table.insert(particleCastList, {obj = object, time = game.time, castTime = 0.65, castingPos = object.pos, bounding = 80, speed = 335})
			self:DebugPrint("Added cast particle " .. object.name)
		elseif string.find(object.name, "Zed") and string.find(object.name, "_R_tar_TargetMarker") and object.isEffectEmitter and object.asEffectEmitter.attachment.object and object.asEffectEmitter.attachment.object.handle == player.handle then
			target = object.asEffectEmitter.attachment.object
			deathBuff = target:getBuff("zedrtargetmark")
			if deathBuff then
				owner = deathBuff.caster
			end
			table.insert(particleCastList, {obj = object, time = game.time, castTime = 0.95, owner = owner, target = target, castingPos = nil, bounding = 65, speed = 345, zedR = true})
			self:DebugPrint("Added cast particle " .. object.name)
		elseif object.name == "global_ss_teleport_red.troy" and object.isEffectEmitter then
			teleportOwner = object.asEffectEmitter.attachment.object
		elseif object.name == "global_ss_teleport_turret_red.troy" and object.isEffectEmitter then
			target = object.asEffectEmitter.attachment.object
			local nexusPos = nil
			for key, value in pairs(objManager.buildings.enemies.list) do
				if value.isNexus then
					nexusPos = value.pos
					break
				end
			end
			table.insert(particleCastList, {obj = object, time = game.time, castTime = 4, owner = teleportOwner, target = target, castingPos = nil, nexusPos = nexusPos, teleport = true})
			self:DebugPrint("Added cast particle " .. object.name)
		elseif object.name == "global_ss_teleport_target_red.troy" and object.isEffectEmitter then
			target = object.asEffectEmitter.targetAttachment.object
			for key, value in pairs(objManager.buildings.enemies.list) do
				if value.isNexus then
					nexusPos = value.pos
					break
				end
			end
			table.insert(particleCastList, {obj = object, time = game.time, castTime = 4, owner = teleportOwner, target = target, castingPos = nil, nexusPos = nexusPos, teleport = true})
			self:DebugPrint("Added cast particle " .. object.name)
		end
		table.remove(debugList, #debugList)
		-- if (object.isEffectEmitter) then
			-- print(object.name)
			-- print(object.asEffectEmitter.attachment.object and object.asEffectEmitter.attachment.object.name or "")
			-- print(object.asEffectEmitter.targetAttachment.object and object.asEffectEmitter.targetAttachment.object.name or "")
			-- print("---------------------")
		-- end
	end

	function Xerath:OnDelete(object)
		self:debugFlush()
		table.insert(debugList, "Delete")
		if object.name == "XerathMageSpearMissile" then
			for key,value in ipairs(particleEList) do
				if value.obj.handle == object.handle then
					table.remove(particleEList, key)
					disappearedE = game.time
					self:DebugPrint("Removed missile E")
					break
				end
			end
		elseif object.name == "XerathLocusPulse" then
			for key,value in ipairs(particleRList) do
				if game.time > value.time + 0.55 then
					disappearedRObject = {
						obj = value.obj,
						time = game.time
					}
					table.remove(particleRList, key)
					self:DebugPrint("Removed particle R")
				end
			end
			if rshots then
				rshots = (rshots - 1 >= 1 and rshots - 1 or nil)
			end
		elseif string.find(object.name, "_W_MistArea") then
			local owner = object.asEffectEmitter.attachment.object
			if not owner then goto endMist end
			local owner2 = owner.asAttackableUnit.owner
			if not owner2 then goto endMist end
			particleGwenList[owner2.handle] = nil
			self:DebugPrint("Removed particle Gwen")
			::endMist::
		elseif string.find(object.name, "_R_Gatemarker") or string.find(object.name, "_R_ChargeIndicator") or (string.find(object.name, "_R_Update_Indicator") and not string.find(object.name, "PreJump")) or string.find(object.name, "R_Tar_Ground") or string.find(object.name, "R_Landing") or string.find(object.name, "W_ImpactWarning") or string.find(object.name, "_W_tar") or object.name == "global_ss_teleport_target_red.troy" or object.name == "global_ss_teleport_target_red.troy" then
			for key,value in ipairs(particleCastList) do
				if value.obj.handle == object.handle then
					table.remove(particleCastList, key)
					self:DebugPrint("Removed cast particle " .. value.obj.name)
					break
				end
			end
		end
		table.remove(debugList, #debugList)
	end

	-- Seems more optimal to make a buff list like that, I guess, I was told so
	function Xerath:OnBuff(source, buff, gained)
		self:debugFlush()
		if not source.isHero then return end
		table.insert(debugList, "Buff")
		if source and source.isEnemy and not gained and buff.name == "willrevive" and source.characterState.statusFlags == 65537 and source:hasItem(3026) and self:getStasisTime(source) <= 0 then
			buffs["Time" .. source.handle] = game.time + 4
			self:DebugPrint("Detected Guardian angel on " .. source.skinName)
		end
		if self.XerathMenu.debug_print_buffs:get() then
			self:DebugPrint(source.skinName .. " -> Buff " .. (gained and "gained" or "lost") .. " : (" .. tostring(buff.name) .. ")" .. (buff.caster and (" from " .. buff.caster.name) or ""))
		end
		if source and source.isEnemy and (buff.type == 37 or buff.type == 38) then
			if gained then
				buffs["GodBuffTime" .. source.handle] = game.time + buff.remainingTime
				self:DebugPrint("Detected godmode buff on " .. source.skinName)
			elseif buffs["GodBuffTime" .. source.handle] ~= nil and buffs["GodBuffTime" .. source.handle] <= game.time then
				buffs["GodBuffTime" .. source.handle] = nil
				self:DebugPrint("Removed godmode buff on " .. source.skinName)
			end
		end
		local buffFlag = false
		for i, name in ipairs(buffToCheck) do
			if not buff.caster or buff.caster.handle == player.handle then break end
			if buff.name == name then
				buffFlag = true
				break
			end
		end
		if not buffFlag then
			for i, name in ipairs(selfBuffToCheck) do
				if buff.caster and buff.caster.handle ~= player.handle then break end
				if buff.name == name then
					buffFlag = true
					break
				end
			end
		end
		if not buffFlag then table.remove(debugList, #debugList) return end
		if gained then
			buffs[source.handle .. buff.name] = buff
			self:DebugPrint(source.skinName .. " -> Buff added (" .. tostring(buff.name) .. ")" .. (buff.caster and (" from " .. buff.caster.name) or ""))
		else
			buffs[source.handle .. buff.name] = nil
			self:DebugPrint(source.skinName .. " -> Buff removed (" .. tostring(buff.name) .. ")" .. (buff.caster and (" from " .. buff.caster.name) or ""))
		end
		table.remove(debugList, #debugList)
	end

	function Xerath:OnTick()
		self:debugFlush()
		table.insert(debugList, "Tick")
		hasCasted = false
		self:DrawCalcs()
		self:TargetSelector()
		QTarget = nil
		RTarget = nil
		if player.isDead then table.remove(debugList, #debugList) return end
		local stunBuffList = {BuffType.Stun, BuffType.Silence, BuffType.Taunt, BuffType.Polymorph, BuffType.Fear, BuffType.Charm, BuffType.Suppression, BuffType.Knockup, BuffType.Knockback, BuffType.Asleep}
		for key,buff in ipairs(stunBuffList) do
			if player:hasBuffOfType(buff) then
				instantQCast.time = nil
				table.remove(debugList, #debugList)
				return
			end
		end
		if self:IsCasting() then
			orb.setAttackPause(0.075)
			instantQCast.time = nil
			table.remove(debugList, #debugList)
			return
		end
		if player.asHero.isWindingUp and myHero.mana/myHero.maxMana < 0.75 and myHero:getBuff("xerathascended2onhit") then table.remove(debugList, #debugList) return end
		if instantQCast.time and instantQCast.time > game.time - 0.15 then
			player:updateChargeableSpell(SpellSlot.Q, instantQCast.pos)
			self:DebugPrint("Casted instant Q with range of " .. self.qData.range)
			table.remove(debugList, #debugList)
			return
		end
		self:Combo()
		self:Harass()
		self:Auto()
		table.remove(debugList, #debugList)
	end

	function Xerath:TargetSelector()
		table.insert(debugList, "TargetSelector")
		local lowPrio = {}
		targetList = {}
		for key, target in pairs(ts.getTargets()) do
			local stasisTime = self:getStasisTime(target)
			local spellPrio = (target.isCastingInterruptibleSpell and target.isCastingInterruptibleSpell > 1)
			if stasisTime > 0 or spellPrio then
				table.insert(targetList, 1, target)
			elseif not self.XerathMenu.misc.shield_logic:get() or (target.allShield + target.magicalShield) <= 0 or not target.isVisible then
				table.insert(targetList, target)
			else
				local accountQ = (player:spellSlot(SpellSlot.Q).state == 0 or (player.activeSpell and player.activeSpell.hash == 2320506602 and casting[player.handle] and game.time < casting[player.handle])) and player.pos:distance2D(target.pos) <= 1500
				local accountW = (player:spellSlot(SpellSlot.W).state == 0 and player.pos:distance2D(target.pos) <= self.wData.range) or self:WillGetHitByW(target)
				local accountE = (player:spellSlot(SpellSlot.E).state == 0 and (player.pos:distance2D(target.pos) - target.boundingRadius) <= self.eData.range) or self:MissileE(target)
				local accountR = rBuff and player.pos:distance2D(target.pos) <= self.rData.range
				local QDamage = accountQ and self:GetDamageQ(target, 999) or 0
				local WDamage = accountW and (accountQ and self:GetDamageW2Alternative(target, 999) or self:GetDamageW2(target, 999)) or 0
				local EDamage = accountE and ((accountQ or accountW) and self:GetDamageEAlternative(target, 999) or self:GetDamageE(target, 999)) or 0
				local RDamage = accountR and self:GetDamageR(target, 0, 0, target.health, true) or 0
				local potentialDamage = QDamage + WDamage + EDamage + RDamage
				if (target.allShield + target.magicalShield)*2 <= potentialDamage then
					table.insert(targetList, target)
				else
					table.insert(lowPrio, target)
				end
			end
		end
		for key, target in pairs(lowPrio) do
			table.insert(targetList, target)
		end
		table.remove(debugList, #debugList)
	end

	function Xerath:DrawCalcs()
		table.insert(debugList, "DrawCalcs")
		table.insert(debugList, "ParticleDelete")
		for key,value in ipairs(particleRList) do
			if game.time > value.time + 0.8 then
				disappearedRObject = {
					obj = value.obj,
					time = game.time
				}
				table.remove(particleRList, key)
				self:DebugPrint("Removed particle R")
			end
		end
		for key,value in ipairs(particleWList) do
			if game.time > value.time + 0.783 then
				table.remove(particleWList, key)
				self:DebugPrint("Removed particle W")
			end
		end
		table.remove(debugList, #debugList)
		table.insert(debugList, "DrawCalcs1")
		changedList = (oldXValue and oldYValue) and (oldXValue ~= self.XerathMenu.drawings.draw_r_list_x:get() or oldYValue ~= self.XerathMenu.drawings.draw_r_list_y:get()) or false
		oldXValue = self.XerathMenu.drawings.draw_r_list_x:get()
		oldYValue = self.XerathMenu.drawings.draw_r_list_y:get()
		if changedList then
			listChanged = os.clock()
		end
		changed = oldValue and self.XerathMenu.misc.near_mouse_r:get() ~= oldValue or false
		oldValue = self.XerathMenu.misc.near_mouse_r:get()
		if changed then
			changeTime = os.clock()
		end
		rBuff = myHero:getBuff("xerathrshots")
		qBuff = myHero:getBuff("XerathArcanopulseChargeUp")
		ElderBuff = myHero:getBuff("ElderDragonBuff")
		table.remove(debugList, #debugList)
		table.insert(debugList, "DrawLoop")
		killList = {}
		drawRDamage = {}
		RKillable = {}
		drawRValue = {}
		for _, unit in pairs(ts.getTargets()) do
			if unit.isHealthBarVisible and not unit.isDead then
				if unit.skinName == "Yuumi" then
					local YuumiBuff = unit:getBuff("YuumiWAttach")
					if YuumiBuff and YuumiBuff.caster.handle == unit.handle then goto continue end
				end
				table.insert(debugList, "DrawLoop1")
				-- Draw R damage on every enemies HP bars
				local rDamage = nil
				local shotsToKill = 0
				local isFirstShot = true
				local totalHP = unit.health + unit.allShield + unit.magicalShield
				local rActive = player:spellSlot(SpellSlot.R).level ~= 0 and (player:spellSlot(SpellSlot.R).cooldown <= 0 or particleRList[1] or rBuff)
				if self.XerathMenu.drawings.draw_r_damage:get() and rActive then
					rDamage = 0
					for i = (((particleRList[1] or rBuff) and rshots and rshots > 0) and rshots or 2 + player:spellSlot(SpellSlot.R).level) - 1, 0, -1 do
						local calculatedRDamage = self:GetDamageR(unit, 0, i, totalHP - rDamage, isFirstShot)
						local calculatedRMaxDamage = self:GetDamageR(unit, 0, 0, totalHP - rDamage, isFirstShot)
						if ((totalHP) - (rDamage + calculatedRMaxDamage))/unit.maxHealth < (ElderBuff and 0.2 or 0) then
							rDamage = rDamage + calculatedRMaxDamage
							shotsToKill = shotsToKill + 1
							break
						end
						rDamage = rDamage + calculatedRDamage
						shotsToKill = shotsToKill + 1
						isFirstShot = false
					end
					if ((totalHP) - rDamage)/unit.maxHealth < 0.2 and ElderBuff then
						rDamage = totalHP
					end
					table.insert(drawRDamage, {unit = unit, damage = rDamage})
				end
				table.remove(debugList, #debugList)
				table.insert(debugList, "DrawLoop2")
				if self.XerathMenu.drawings.draw_r_damage_text:get() and rActive then
					if not rDamage then
						rDamage = 0
						for i = (((particleRList[1] or rBuff) and rshots and rshots > 0) and rshots or 2 + player:spellSlot(SpellSlot.R).level) - 1, 0, -1 do
							local calculatedRDamage = self:GetDamageR(unit, 0, i, totalHP - rDamage, isFirstShot)
							local calculatedRMaxDamage = self:GetDamageR(unit, 0, 0, totalHP - rDamage, isFirstShot)
							if ((totalHP) - (rDamage + calculatedRMaxDamage))/unit.maxHealth < (ElderBuff and 0.2 or 0) then
								rDamage = rDamage + calculatedRMaxDamage
								shotsToKill = shotsToKill + 1
								break
							end
							rDamage = rDamage + calculatedRDamage
							shotsToKill = shotsToKill + 1
							isFirstShot = false
						end
						if ((totalHP) - rDamage)/unit.maxHealth < 0.2 and ElderBuff then
							rDamage = totalHP
						end
					end
					if rDamage > 0 then
						local pos = vec2(unit.healthBarPosition.x + 70, unit.healthBarPosition.y - 30)
						local hpPercent =  100-((totalHP - rDamage) / (unit.maxHealth + unit.allShield + unit.magicalShield))*100
						local text = tostring(math.ceil(totalHP - rDamage) .. " (" .. tostring(math.floor(hpPercent)) .. "%)")
						-- Inspired from https://github.com/plsfixrito/KappAIO/blob/master/KappaAIO%20Reborn/Plugins/Champions/Darius/Darius.cs#L341
						local red = 51*math.min(100, hpPercent)/20
						if rDamage >= totalHP then
							table.insert(RKillable, {unit = unit, shots = shotsToKill})
						else
							table.insert(drawRValue, {unit = unit, text = text, red = red})
						end
					end
				end
				table.remove(debugList, #debugList)
				table.insert(debugList, "DrawLoop3")
				if self.XerathMenu.drawings.draw_r_list:get() and not player.isDead and rActive and unit.pos:distance2D(player.pos) <= 5000 then
					if not rDamage then
						rDamage = 0
						for i = (((particleRList[1] or rBuff) and rshots and rshots > 0) and rshots or 2 + player:spellSlot(SpellSlot.R).level) - 1, 0, -1 do
							local calculatedRDamage = self:GetDamageR(unit, 0, i, totalHP - rDamage, isFirstShot)
							local calculatedRMaxDamage = self:GetDamageR(unit, 0, 0, totalHP - rDamage, isFirstShot)
							if ((totalHP) - (rDamage + calculatedRMaxDamage))/unit.maxHealth < (ElderBuff and 0.2 or 0) then
								rDamage = rDamage + calculatedRMaxDamage
								shotsToKill = shotsToKill + 1
								break
							end
							rDamage = rDamage + calculatedRDamage
							shotsToKill = shotsToKill + 1
							isFirstShot = false
						end
						if ((totalHP) - rDamage)/unit.maxHealth < 0.2 and ElderBuff then
							rDamage = totalHP
						end
					end
					if rDamage >= totalHP then
						table.insert(killList, unit.skinName .. " is killable in " .. shotsToKill .. (shotsToKill > 1 and " shots" or " shot"))
					end
				end
				table.remove(debugList, #debugList)
				::continue::
			end
		end
		table.remove(debugList, #debugList)
		table.remove(debugList, #debugList)
	end

	function Xerath:Auto()
		table.insert(debugList, "Auto")
		table.insert(debugList, "Auto1")
		isUlting = rBuff
		if self.XerathMenu.misc.manual_r:get() and not self.XerathMenu.misc.manual_r_dont_r1:get() and not isUlting and player:spellSlot(SpellSlot.R).state == 0 then
			player:castSpell(SpellSlot.R, true, false)
		end
		local onceOnly = false
		local CCE = self.XerathMenu.misc.e_stun:get() and player:spellSlot(SpellSlot.E).state == 0
		local CCW = self.XerathMenu.misc.w_stun:get() and player:spellSlot(SpellSlot.W).state == 0
		local ChannelE = self.XerathMenu.misc.e_channel:get() and player:spellSlot(SpellSlot.E).state == 0
		local ChannelW = self.XerathMenu.misc.w_channel:get() and player:spellSlot(SpellSlot.W).state == 0
		local DashE = self.XerathMenu.misc.e_dash:get() and player:spellSlot(SpellSlot.E).state == 0
		local DashW = self.XerathMenu.misc.w_dash:get() and player:spellSlot(SpellSlot.W).state == 0
		local DashQ = self.XerathMenu.misc.q_dash:get() and player:spellSlot(SpellSlot.Q).state == 0 and qBuff
		local StasisE = self.XerathMenu.misc.e_stasis:get() and player:spellSlot(SpellSlot.E).state == 0
		local StasisW = self.XerathMenu.misc.w_stasis:get() and player:spellSlot(SpellSlot.W).state == 0
		local StasisQ = self.XerathMenu.misc.q_stasis:get() and player:spellSlot(SpellSlot.Q).state == 0 and qBuff
		local CastingE = self.XerathMenu.misc.e_casting:get() and player:spellSlot(SpellSlot.E).state == 0
		local CastingW = self.XerathMenu.misc.w_casting:get() and player:spellSlot(SpellSlot.W).state == 0
		local CastingQ = self.XerathMenu.misc.q_casting:get() and player:spellSlot(SpellSlot.Q).state == 0 and qBuff
		local pingLatency = game.latency/1000
		table.remove(debugList, #debugList)
		table.insert(debugList, "AutoLoop")
		for index, enemy in pairs(targetList) do
			if hasCasted then break end
			local stasisTime = self:getStasisTime(enemy)
			local validTarget =  enemy and ((enemy:isValidTarget(math.huge, true, player.pos) and enemy.isTargetableToTeamFlags and enemy.isTargetable) or stasisTime > 0 or self:invisibleValid(enemy, math.huge))
			if not validTarget then goto continue end

			if enemy.characterState.statusFlags ~= 65537 then buffs["Time" .. enemy.handle] = nil end

			table.insert(debugList, "AutoCalcs")
			local dashing = enemy.path and enemy.path.isDashing
			local CCTime = pred.getCrowdControlledTime(enemy)
			local channelingSpell = (enemy.isCastingInterruptibleSpell and enemy.isCastingInterruptibleSpell > 0) or (enemy.activeSpell and enemy.activeSpell.hash == 692142347) or enemy.isRecalling
			local manualE = self.XerathMenu.misc.manual_e:get() and not onceOnly and player:spellSlot(SpellSlot.E).state == 0 and (enemy.pos:distance2D(player.pos) - enemy.boundingRadius) <= self.eData.range
			local castTime = (enemy.activeSpell and casting[enemy.handle] and game.time < casting[enemy.handle]) and (casting[enemy.handle] - game.time) or 0
			local prioCast = dashing or castTime > 0 or (stasisTime > 0 and (stasisTime - pingLatency + 0.2) < 0.6)
			local manualR = enemy.pos:distance2D(player.pos) <= 5000 and enemy.pos:distance2DSqr(game.cursorPos) <= (self.XerathMenu.misc.near_mouse_r:get() > 0 and self.XerathMenu.misc.near_mouse_r:get()^ 2 or math.huge) and (stasisTime - pingLatency) < 1
			local needsUltCasted = manualR and isUlting
			table.remove(debugList, #debugList)
			if (CCTime <= 0 or not (CCE or CCW)) and (not channelingSpell or not (ChannelE or ChannelW)) and (not dashing or not (DashE or DashW or DashQ)) and (stasisTime <= 0 or not (StasisE or StasisW or StasisQ)) and (castTime <= 0 or not (CastingE or CastingW or CastingQ)) and not manualE and not needsUltCasted then goto continue end

			table.insert(debugList, "AutoCalcs2")
			local godBuffTimeAuto = self:godBuffTime(enemy)
			local noKillBuffTimeAuto = self:noKillBuffTime(enemy)
			local QDamage = self:GetDamageQ(enemy, 0)
			local EDamage = self:GetDamageE(enemy, 0)
			local WDamage = self:GetDamageW2(enemy, 0)
			local RDamage = self:GetDamageR(enemy, 0, 0, enemy.health, true)
			local totalHP = (enemy.health + enemy.allShield + enemy.magicalShield)
			local ELandingTime = (math.max(self.eData.delay, (player.pos:distance2D(enemy.pos) - (enemy.boundingRadius + self.eData.radius)) / self.eData.speed + self.eData.delay))
			local CCImmuneBuff = enemy:getBuff("UdyrE2Activation")
			local isCCImmune = CCImmuneBuff and (game.time - CCImmuneBuff.startTime) <= 1.5
			local canBeStunned = not enemy.isUnstoppable and not enemy:getBuff("MorganaE") and not enemy:getBuff("bansheesveil") and not enemy:getBuff("itemmagekillerveil") and not enemy:getBuff("malzaharpassiveshield") and not isCCImmune
			local canBeSlowed = canBeStunned and not enemy:getBuff("Highlander")
			table.remove(debugList, #debugList)
			if isUlting then goto ult end
			
			if stasisTime <= 0 then
				table.insert(debugList, "AutoEDash")
				if DashE and dashing and godBuffTimeAuto <= 0.2 + pingLatency and (noKillBuffTimeAuto <= 0.2 + pingLatency or EDamage < totalHP) and canBeStunned then
					self:CastE(enemy,"dash", godBuffTimeAuto, pingLatency, noKillBuffTimeAuto, EDamage, totalHP, CCTime)
				end
				table.remove(debugList, #debugList)
				table.insert(debugList, "AutoEInterrupt")
				if ChannelE and channelingSpell and godBuffTimeAuto <= 0.2 + pingLatency and (noKillBuffTimeAuto <= 0.2 + pingLatency or EDamage < totalHP) and canBeStunned then
					self:CastE(enemy,"channel", godBuffTimeAuto, pingLatency, noKillBuffTimeAuto, EDamage, totalHP, CCTime)
				end
				table.remove(debugList, #debugList)
				table.insert(debugList, "AutoECC")
				if CCE and CCTime > 0 and (CCTime - pingLatency - 0.3) < ELandingTime and godBuffTimeAuto <= 0.2 + pingLatency and (noKillBuffTimeAuto <= 0.2 + pingLatency or EDamage < totalHP) and canBeStunned then
					self:CastE(enemy,"stun", godBuffTimeAuto, pingLatency, noKillBuffTimeAuto, EDamage, totalHP, CCTime)
				end
				table.remove(debugList, #debugList)
				table.insert(debugList, "AutoECasting")
				if CastingE and castTime > 0 and (castTime - pingLatency - 0.3) < ELandingTime and godBuffTimeAuto <= 0.2 + pingLatency and (noKillBuffTimeAuto <= 0.2 + pingLatency or EDamage < totalHP) and canBeStunned then
					self:CastE(enemy,"casting", godBuffTimeAuto, pingLatency, noKillBuffTimeAuto, EDamage, totalHP, CCTime)
				end
			end
			table.remove(debugList, #debugList)
			table.insert(debugList, "AutoEStasis")
			if StasisE and stasisTime > 0 and (stasisTime - pingLatency + 0.05) < ELandingTime and godBuffTimeAuto <= 0.2 + pingLatency and (noKillBuffTimeAuto <= 0.2 + pingLatency or EDamage < totalHP) and canBeStunned then
				self:CastE(enemy,"stasis", godBuffTimeAuto, pingLatency, noKillBuffTimeAuto, EDamage, totalHP, CCTime)
			end
			if stasisTime <= 0 then
				table.remove(debugList, #debugList)
				table.insert(debugList, "AutoWDash")
				if DashW and dashing and godBuffTimeAuto <= 0.6 + pingLatency and (noKillBuffTimeAuto <= 0.6 + pingLatency or WDamage < totalHP) then
					self:CastW(enemy,"dash", godBuffTimeAuto, pingLatency, noKillBuffTimeAuto, WDamage, totalHP, CCTime)
				end
				table.remove(debugList, #debugList)
				table.insert(debugList, "AutoWChannel")
				if ChannelW and channelingSpell and godBuffTimeAuto <= 0.6 + pingLatency and (noKillBuffTimeAuto <= 0.6 + pingLatency or WDamage < totalHP) then
					self:CastW(enemy,"channel", godBuffTimeAuto, pingLatency, noKillBuffTimeAuto, WDamage, totalHP, CCTime)
				end
				table.remove(debugList, #debugList)
				table.insert(debugList, "AutoWCC")
				if CCW and CCTime > 0 and (CCTime - pingLatency - 0.3) < 0.75 and godBuffTimeAuto <= 0.6 + pingLatency and (noKillBuffTimeAuto <= 0.6 + pingLatency or WDamage < totalHP) then
					self:CastW(enemy,"stun", godBuffTimeAuto, pingLatency, noKillBuffTimeAuto, WDamage, totalHP, CCTime)
				end
				table.remove(debugList, #debugList)
				table.insert(debugList, "AutoWCasting")
				if CastingW and castTime > 0 and (castTime - pingLatency - 0.3) < 0.75 and godBuffTimeAuto <= 0.6 + pingLatency and (noKillBuffTimeAuto <= 0.6 + pingLatency or WDamage < totalHP) then
					self:CastW(enemy,"casting", godBuffTimeAuto, pingLatency, noKillBuffTimeAuto, WDamage, totalHP, CCTime)
				end
			end
			table.remove(debugList, #debugList)
			table.insert(debugList, "AutoWStasis")
			if StasisW and not StasisE and stasisTime > 0 and (stasisTime - pingLatency + 0.2) < 0.75 and godBuffTimeAuto <= 0.6 + pingLatency and (noKillBuffTimeAuto <= 0.6 + pingLatency or WDamage < totalHP) then
				self:CastW(enemy,"stasis", godBuffTimeAuto, pingLatency, noKillBuffTimeAuto, QDamage, totalHP, CCTime)
			end
			table.remove(debugList, #debugList)
			table.insert(debugList, "AutoQDash")
			if DashQ and dashing and godBuffTimeAuto <= 0.4 + pingLatency and (noKillBuffTimeAuto <= 0.4 + pingLatency or QDamage < totalHP) then
				self:CastQ2(enemy,"dash", godBuffTimeAuto, pingLatency, noKillBuffTimeAuto, QDamage, totalHP, qBuff, CCTime, canBeStunned)
			end
			table.remove(debugList, #debugList)
			table.insert(debugList, "AutoQCasting")
			if CastingQ and castTime > 0 and godBuffTimeAuto <= 0.4 + pingLatency and (noKillBuffTimeAuto <= 0.4 + pingLatency or QDamage < totalHP) then
				self:CastQ2(enemy,"casting", godBuffTimeAuto, pingLatency, noKillBuffTimeAuto, QDamage, totalHP, qBuff, CCTime, canBeStunned)
			end
			table.remove(debugList, #debugList)
			table.insert(debugList, "AutoQStasis")
			if StasisQ and stasisTime > 0 and (stasisTime - pingLatency + 0.2) < 0.5 and godBuffTimeAuto <= 0.4 + pingLatency and (noKillBuffTimeAuto <= 0.4 + pingLatency or QDamage < totalHP) then
				self:CastQ2(enemy,"stasis", godBuffTimeAuto, pingLatency, noKillBuffTimeAuto, QDamage, totalHP, qBuff, CCTime, canBeStunned)
			end
			table.remove(debugList, #debugList)
			table.insert(debugList, "ManualE")
			if self.XerathMenu.misc.w_before_e:get() and manualE and player:spellSlot(SpellSlot.W).state == 0 and enemy.pos:distance2D(player.pos) <= self.wData.range and orb.predictHP(enemy, 0.9 + pingLatency) > 0 and not enemy.isZombie and godBuffTimeAuto <= 0.9 + pingLatency and (noKillBuffTimeAuto <= 0.9 + pingLatency or WDamage < totalHP) and canBeSlowed then
				self:CastW(enemy,"manual", godBuffTimeAuto, pingLatency, noKillBuffTimeAuto, WDamage, totalHP, CCTime)
				onceOnly = true
				table.remove(debugList, #debugList)
				break
			end
			if manualE and orb.predictHP(enemy, 0.2 + pingLatency) > 0 and not enemy.isZombie and godBuffTimeAuto <= 0.5 + pingLatency and (noKillBuffTimeAuto <= 0.5 + pingLatency or EDamage < totalHP) and canBeStunned then
				if CCTime or CCTime - pingLatency - 0.25 < ELandingTime then
					self:CastE(enemy,"manual", godBuffTimeAuto, pingLatency, noKillBuffTimeAuto, EDamage, totalHP, CCTime)
					onceOnly = true
					table.remove(debugList, #debugList)
					break
				end
			end
			table.remove(debugList, #debugList)
			::ult::
			table.insert(debugList, "ManualUlt")
			if needsUltCasted and (orb.predictHP(enemy, 0.5 + pingLatency) > 0 or stasisTime > 0) and godBuffTimeAuto <= 1 + pingLatency and (noKillBuffTimeAuto <= 1 + pingLatency or RDamage < totalHP) then
				if not self:WillGetHitByR(enemy) or not ((((totalHP) - RDamage)/enemy.maxHealth) < (ElderBuff and 0.2 or 0)) then
					if player:spellSlot(SpellSlot.R).state == 0 and (stasisTime - pingLatency + 0.2) < 0.6 then
						local predResult = pred.getPrediction(enemy, self.rData)
						local mustShoot = (self.XerathMenu.misc.auto_r:get() or self.XerathMenu.misc.manual_r:get() or prioCast or (predResult and predResult.hitChance >= 6))
						if mustShoot then
							self:CastR(enemy, godBuffTimeAuto, pingLatency, noKillBuffTimeAuto, RDamage, totalHP, CCTime, prioCast, predResult)
						end
					end
					RTarget = enemy
					table.remove(debugList, #debugList)
					break
				else
					self:DebugPrint("Overkill prevented on " .. enemy.name)
				end
			end
			table.remove(debugList, #debugList)
			::continue::
		end
		table.remove(debugList, #debugList)
		table.insert(debugList, "AutoParticleLoop")
		local EParticle = (self.XerathMenu.misc.e_particle:get() and player:spellSlot(SpellSlot.E).state == 0)
		local WParticle = (self.XerathMenu.misc.w_particle:get() and player:spellSlot(SpellSlot.W).state == 0)
		local QParticle = (self.XerathMenu.misc.q_particle:get() and player:spellSlot(SpellSlot.Q).state == 0) and qBuff
		if (EParticle or WParticle or QParticle) and particleCastList[1] and not hasCasted then
			for key,value in ipairs(particleCastList) do
				if not value or (value.time + value.castTime) <= game.time or (value.team and value.team == player.team) or value.isAlly then table.remove(particleCastList, key) goto nextParticle end
				if not value.owner then
					local particleOwner = (value.obj.asEffectEmitter.attachment.object and value.obj.asEffectEmitter.attachment.object.isAIBase and value.obj.asEffectEmitter.attachment.object.isEnemy) and value.obj.asEffectEmitter.attachment.object or ((value.obj.asEffectEmitter.targetAttachment.object and value.obj.asEffectEmitter.targetAttachment.object.isAIBase and value.obj.asEffectEmitter.targetAttachment.object.isEnemy) and value.obj.asEffectEmitter.targetAttachment.object or nil)
					if not particleOwner or not particleOwner.isHero or particleOwner.isAlly then
						if particleOwner and particleOwner.isAttackableUnit and particleOwner.asAttackableUnit.owner and particleOwner.asAttackableUnit.owner.isHero and particleOwner.asAttackableUnit.owner.isEnemy then
							particleOwner = particleOwner.asAttackableUnit.owner.asAIBase
						elseif particleOwner and particleOwner.isMissile and particleOwner.asMissile.caster and particleOwner.asMissile.caster.isHero and particleOwner.asAttackableUnit.asMissile.caster.isEnemy then
							particleOwner = particleOwner.asMissile.caster.asAIBase
						else
							particleOwner = {
								isEnemy = true,
								boundingRadius = value.bounding,
								characterIntermediate = {
									moveSpeed = value.speed
								},
								homeless = true
							}
							print("Homeless particle : " .. value.obj.name)
						end
					end
					value.owner = particleOwner
				end
				particleOwner = value.owner
				if value.owner and value.owner.isHero then
					particleOwner = particleOwner.asAIBase
				end
				if value.teleport then
					if value.target then
						value.castingPos = value.obj.pos:extend(value.nexusPos, value.target.boundingRadius+particleOwner.boundingRadius)
					else
						value.castingPos = value.obj.pos
					end
				end
				if value.zedR then
					value.castingPos = value.target.pos + (particleOwner.direction * (value.target.boundingRadius+particleOwner.boundingRadius))
				end
				if particleOwner.isDead or not value.castingPos or player.pos:distance2D(value.castingPos) > math.max(1500, self.eData.range + particleOwner.boundingRadius) or not particleOwner.isEnemy then goto nextParticle end
				local particleTime = (value.time + value.castTime) - game.time
				local ELandingTime = (math.max(self.eData.delay, (player.pos:distance2D(value.castingPos) - (particleOwner.boundingRadius + self.eData.radius)) / self.eData.speed + self.eData.delay))
				local QCanDodge = particleOwner.characterIntermediate.moveSpeed*((self.qData.delay - particleTime) + pingLatency) > self.qData.radius + particleOwner.boundingRadius
				local WCanDodge = particleOwner.characterIntermediate.moveSpeed*((self.wData.delay - particleTime) + pingLatency) > self.wData.radius
				local ECanDodge = particleOwner.characterIntermediate.moveSpeed*((ELandingTime - particleTime) + pingLatency) > self.eData.radius + particleOwner.boundingRadius
				local canQ = QParticle and not QCanDodge and player.pos:distance2D(value.castingPos) <= self:GetChargeRange(1500, 750, 1.5)
				local canW = WParticle and not WCanDodge and player.pos:distance2D(value.castingPos) <= self.wData.range
				self.eData.range = 1065 + particleOwner.boundingRadius
				local canE = EParticle and not ECanDodge and (player.pos:distance2D(value.castingPos) - particleOwner.boundingRadius) <= self.eData.range and not pred.findSpellCollisions((particleOwner.handle and particleOwner or nil), self.eData, player.pos, value.castingPos, ELandingTime+pingLatency)[1]
				self.eData.range = 1065
				if QParticle then goto qBuffHandling end
				if canE and (particleTime - pingLatency + 0.1) <= ELandingTime then
					player:castSpell(SpellSlot.E, value.castingPos, true, false)
					hasCasted = true
					self:DebugPrint("Casted E on particle")
				elseif canW and not canE and (particleTime - pingLatency + 0.2) <= 0.75 then
					player:castSpell(SpellSlot.W, value.castingPos, true, false)
					hasCasted = true
					self:DebugPrint("Casted W on particle")
				end
				goto nextParticle
				::qBuffHandling::
				if canQ and (particleTime - pingLatency) <= 0.5 then
					player:updateChargeableSpell(SpellSlot.Q, value.castingPos)
					hasCasted = true
					self:DebugPrint("Casted Q on particle")
				end
				::nextParticle::
			end
		end
		table.remove(debugList, #debugList)
		if isUlting then
			orb.setMovePause(0.075)
			orb.setAttackPause(0.075)
		end
		table.remove(debugList, #debugList)
	end

	-- This function will include all the logics for the combo mode
	function Xerath:Combo()
		if isUlting or hasCasted then return end

		if orb.isComboActive == false then return end

		table.insert(debugList, "Combo")
		for index, target in pairs(targetList) do
			local validTarget =  target and not target.isZombie and target.isValid and (target:isValidTarget(math.max(1500, self.eData.range + target.boundingRadius), true, player.pos) or self:invisibleValid(target, math.max(1500, self.eData.range + target.boundingRadius))) and target.isTargetableToTeamFlags and target.isTargetable and not target.isInvulnerable
			if not validTarget then goto continue end

			table.insert(debugList, "ComboCalcs")
			local CanUseQ = self.XerathMenu.combo.use_q:get() and player:spellSlot(SpellSlot.Q).state == 0
			local CanUseW = self.XerathMenu.combo.use_w:get() and player:spellSlot(SpellSlot.W).state == 0 and (target.path and pred.positionAfterTime(target, 0.75 + game.latency/1000):distance2D(player.pos) <= 1000 or target.pos:distance2D(player.pos) <= 1000)
			local CanUseE = self.XerathMenu.combo.use_e:get() and player:spellSlot(SpellSlot.E).state == 0 and (target.pos:distance2D(player.pos) - target.boundingRadius) <= self.eData.range
			table.remove(debugList, #debugList)
			if not CanUseQ and not CanUseW and not CanUseE then goto continue end

			table.insert(debugList, "ComboCalcs2")
			local CCTime = pred.getCrowdControlledTime(target)
			local dashing = target.path and target.path.isDashing
			local godBuffTimeCombo = self:godBuffTime(target)
			local pingLatency = game.latency/1000
			local noKillBuffTimeCombo = self:noKillBuffTime(target)
			local QDamage = self:GetDamageQ(target, 0)
			local EDamage = self:GetDamageE(target, 0)
			local WDamage = self:GetDamageW2(target, 0)
			local RDamage = self:GetDamageR(target, 0, 0, target.health, true)
			local totalHP = (target.health + target.allShield + target.magicalShield)
			local channelingSpell = (target.isCastingInterruptibleSpell and target.isCastingInterruptibleSpell > 0) or (target.activeSpell and target.activeSpell.hash == 692142347)
			local ELandingTime = (math.max(self.eData.delay, (player.pos:distance2D(target.pos) - (target.boundingRadius + self.eData.radius)) / self.eData.speed + self.eData.delay))
			local CCImmuneBuff = target:getBuff("UdyrE2Activation")
			local isCCImmune = CCImmuneBuff and (game.time - CCImmuneBuff.startTime) <= 1.5
			local canBeStunned = not target.isUnstoppable and not target:getBuff("MorganaE") and not target:getBuff("bansheesveil") and not target:getBuff("itemmagekillerveil") and not target:getBuff("malzaharpassiveshield") and not isCCImmune
			local chargingQ = qBuff
			local shouldNotSwapTarget = false
			table.remove(debugList, #debugList)

			table.insert(debugList, "ComboE")
			if CanUseE and orb.predictHP(target, 0.2 + pingLatency) > 0 and godBuffTimeCombo <= 0.5 + pingLatency and (noKillBuffTimeCombo <= 0.5 + game.latency/1000 or not ((((totalHP) - EDamage)/target.maxHealth) < (ElderBuff and 0.2 or 0))) and canBeStunned then
				-- Chain CC logic inspired by Hellsing Xerath https://github.com/Hellsing/EloBuddy-Addons/blob/master/Xerath/Modes/Combo.cs#L32
				if CCTime <= 0 or (CCTime - pingLatency - 0.3) < ELandingTime then
					if self:CastE(target,"combo", godBuffTimeCombo, pingLatency, noKillBuffTimeCombo, EDamage, totalHP, CCTime) > 0 then shouldNotSwapTarget = true end
				else
					if CCTime > 0 and CCTime < 1 then table.remove(debugList, #debugList) break end
				end
			end
			table.remove(debugList, #debugList)
			table.insert(debugList, "ComboQ")
			if CanUseQ and (target.path and pred.positionAfterTime(target, 0.55 + pingLatency):distance2D(player.pos) <= 750 or target.pos:distance2D(player.pos) <= 750) and not CanUseW and orb.predictHP(target, 0.45 + pingLatency) > 0 and godBuffTimeCombo <= 0.85 + pingLatency and (noKillBuffTimeCombo <= 0.85 + pingLatency or not ((((totalHP) - QDamage)/target.maxHealth) < (ElderBuff and 0.2 or 0))) and not chargingQ then
				if self:CastQ(target,"combo", godBuffTimeCombo, pingLatency, noKillBuffTimeCombo, QDamage, totalHP, CCTime) > 0 then table.remove(debugList, #debugList) break end
			end
			table.remove(debugList, #debugList)
			table.insert(debugList, "ComboW")
			if CanUseW and orb.predictHP(target, 0.9 + pingLatency) > 0 and godBuffTimeCombo <= 0.9 + pingLatency and (noKillBuffTimeCombo <= 0.9 + game.latency/1000 or not ((((totalHP) - WDamage)/target.maxHealth) < (ElderBuff and 0.2 or 0))) then
				if self:CastW(target,"combo", godBuffTimeCombo, pingLatency, noKillBuffTimeCombo, WDamage, totalHP, CCTime) > 0 then table.remove(debugList, #debugList) break end
			end
			table.remove(debugList, #debugList)
			table.insert(debugList, "ComboQ2")
			if CanUseQ and (target.path and pred.positionAfterTime(target, 0.5 + pingLatency):distance2D(player.pos) <= 1500 or target.pos:distance2D(player.pos) <= 1500) and orb.predictHP(target, 1.5 + pingLatency) > 0 and godBuffTimeCombo <= 1.5 + pingLatency and (noKillBuffTimeCombo <= 1.5 + pingLatency or not ((((totalHP) - QDamage)/target.maxHealth) < (ElderBuff and 0.2 or 0))) then
				self:CastQ2(target,"combo", godBuffTimeCombo, pingLatency, noKillBuffTimeCombo, QDamage, totalHP, chargingQ, CCTime, canBeStunned)
				if chargingQ then
					QTarget = target
					table.remove(debugList, #debugList)
					break
				end
			end
			table.remove(debugList, #debugList)
			if shouldNotSwapTarget then break end
			::continue::
		end
		table.remove(debugList, #debugList)
	end

	function Xerath:Harass()
		if isUlting or hasCasted then return end

		if orb.harassKeyDown == false then return end

		table.insert(debugList, "Harass")
		for index, target in pairs(targetList) do
			local validTarget =  target and not target.isZombie and target.isValid and (target:isValidTarget(math.max(1500, self.eData.range + target.boundingRadius), true, player.pos) or self:invisibleValid(target, math.max(1500, self.eData.range + target.boundingRadius))) and target.isTargetableToTeamFlags and target.isTargetable and not target.isInvulnerable
			if not validTarget then goto continue end

			table.insert(debugList, "HarassCalcs")
			local CanUseQ = self.XerathMenu.harass.use_q:get() and player:spellSlot(SpellSlot.Q).state == 0
			local CanUseW = self.XerathMenu.harass.use_w:get() and player:spellSlot(SpellSlot.W).state == 0 and (target.path and pred.positionAfterTime(target, 0.75 + game.latency/1000):distance2D(player.pos) <= 1000 or target.pos:distance2D(player.pos) <= 1000)
			table.remove(debugList, #debugList)
			if not CanUseQ and not CanUseW then goto continue end

			table.insert(debugList, "HarassCalcs2")
			local CCTime = pred.getCrowdControlledTime(target)
			local dashing = target.path and target.path.isDashing
			local godBuffTimeCombo = self:godBuffTime(target)
			local pingLatency = game.latency/1000
			local noKillBuffTimeCombo = self:noKillBuffTime(target)
			local QDamage = self:GetDamageQ(target, 0)
			local EDamage = self:GetDamageE(target, 0)
			local WDamage = self:GetDamageW2(target, 0)
			local RDamage = self:GetDamageR(target, 0, 0, target.health, true)
			local totalHP = (target.health + target.allShield + target.magicalShield)
			local channelingSpell = (target.isCastingInterruptibleSpell and target.isCastingInterruptibleSpell > 0) or (target.activeSpell and target.activeSpell.hash == 692142347)
			local ELandingTime = (math.max(self.eData.delay, (player.pos:distance2D(target.pos) - (target.boundingRadius + self.eData.radius)) / self.eData.speed + self.eData.delay))
			local CCImmuneBuff = target:getBuff("UdyrE2Activation")
			local isCCImmune = CCImmuneBuff and (game.time - CCImmuneBuff.startTime) <= 1.5
			local canBeStunned = not target.isUnstoppable and not target:getBuff("MorganaE") and not target:getBuff("bansheesveil") and not target:getBuff("itemmagekillerveil") and not target:getBuff("malzaharpassiveshield") and not isCCImmune
			local chargingQ = qBuff
			table.remove(debugList, #debugList)

			table.insert(debugList, "HarassQ")
			if CanUseQ and (target.path and pred.positionAfterTime(target, 0.55 + pingLatency):distance2D(player.pos) <= 750 or target.pos:distance2D(player.pos) <= 750) and not CanUseW and orb.predictHP(target, 0.45 + pingLatency) > 0 and godBuffTimeCombo <= 0.85 + pingLatency and (noKillBuffTimeCombo <= 0.85 + pingLatency or not ((((totalHP) - QDamage)/target.maxHealth) < (ElderBuff and 0.2 or 0))) and not chargingQ then
				if self:CastQ(target,"harass", godBuffTimeCombo, pingLatency, noKillBuffTimeCombo, QDamage, totalHP, CCTime) > 0 then table.remove(debugList, #debugList) break end
			end
			table.remove(debugList, #debugList)
			table.insert(debugList, "HarassW")
			if CanUseW and orb.predictHP(target, 0.65 + pingLatency) > 0 and godBuffTimeCombo <= 0.9 + pingLatency and (noKillBuffTimeCombo <= 0.9 + game.latency/1000 or not ((((totalHP) - WDamage)/target.maxHealth) < (ElderBuff and 0.2 or 0))) then
				if self:CastW(target,"harass", godBuffTimeCombo, pingLatency, noKillBuffTimeCombo, WDamage, totalHP, CCTime) > 0 then table.remove(debugList, #debugList) break end
			end
			table.remove(debugList, #debugList)
			table.insert(debugList, "HarassQ2")
			if CanUseQ and (target.path and pred.positionAfterTime(target, 0.5 + pingLatency):distance2D(player.pos) <= 1500 or target.pos:distance2D(player.pos) <= 1500) and orb.predictHP(target, 1.5 + pingLatency) > 0 and godBuffTimeCombo <= 1.5 + pingLatency and (noKillBuffTimeCombo <= 1.5 + pingLatency or not ((((totalHP) - QDamage)/target.maxHealth) < (ElderBuff and 0.2 or 0))) then
				self:CastQ2(target,"harass", godBuffTimeCombo, pingLatency, noKillBuffTimeCombo, QDamage, totalHP, chargingQ, CCTime, canBeStunned)
				if chargingQ then
					QTarget = target
					table.remove(debugList, #debugList)
					break
				end
			end
			table.remove(debugList, #debugList)
			::continue::
		end
		table.remove(debugList, #debugList)
	end

	-- This function will cast Q on the target, the mode attribute is used to check if its enabled in the menu based on mode, as we created the menu similar for combo and harass.
	function Xerath:CastQ(target, mode, godBuffTime, pingLatency, noKillBuffTime, GetDamageQ, totalHP, stunTime)
		if hasCasted then return 0 end
		if not totalHP then totalHP = 0 end
		self.qData.delay = 0.55
		self.qData.range = 750
		self.qData.range = self.qData.range - (player.characterIntermediate.moveSpeed*pingLatency*2)
		local p = pred.getPrediction(target, self.qData)
		if godBuffTime <= 0.45 + pingLatency and (noKillBuffTime <= 0.45 + pingLatency or (QDamage < totalHP)) and (not self:MissileE(target) or stunTime > 0) and p and p.castPosition.isValid and player.pos:distance2D(p.castPosition) <= self.qData.range and p.hitChance >= (target.characterIntermediate.moveSpeed > 0  and HitchanceMenu[self.XerathMenu.prediction.q_hitchance:get()] or 1) then
			if not timeSinceUpdate or timeSinceUpdate < game.time - 0.15 then
				player:castSpell(SpellSlot.Q, game.cursorPos, true, true)
				instantQCast = {
					pos = p.castPosition,
					time = game.time
				}
				hasCasted = true
				self:DebugPrint("Casting insta Q on " .. mode)
			end
		end
		return p and p.hitChance or 0
	end

	function Xerath:CastQ2(target, mode, godBuffTime, pingLatency, noKillBuffTime, GetDamageQ, totalHP, chargingQ, stunTime, canBeStunned)
		if hasCasted then return 0 end
		if not totalHP then totalHP = 0 end
		local buff = chargingQ
		buff = buff and buff.valid or nil
		self.qChargeData.from = player.pos:extend(target.pos, 750)
		local averageSpeed = self:prediSlowXer(chargingQ and (game.time - chargingQ.startTime) or 0)
		self.qChargeData.speed = 500 + averageSpeed + (averageSpeed - target.characterIntermediate.moveSpeed)
		local pQ1 = pred.getPrediction(target, self.qChargeData)
		if not buff and ((pQ1 and pQ1.castPosition.isValid and player.pos:distance2D(pQ1.castPosition) <= 1500 and pQ1.hitChance >= 1) or target.path.count <= 1) then
			player:castSpell(SpellSlot.Q, game.cursorPos, true, false)
			hasCasted = true
		elseif godBuffTime <= 0.4 + pingLatency and (noKillBuffTime <= 0.4 + pingLatency or not ((((totalHP) - GetDamageQ)/target.maxHealth) < (ElderBuff and 0.2 or 0))) then
			local channelingSpell = (target.isCastingInterruptibleSpell and target.isCastingInterruptibleSpell > 0) or (target.activeSpell and target.activeSpell.hash == 692142347)
			self.qData.delay = 0.5
			local chargeRange = self:GetChargeRange(1500, 750, 1.5)
			self.qData.range = chargeRange
			if self.qData.range < 1500 then
				if target.path and not target.path.isDashing and target.path.count > 1 then
					self.qData.range = self.qData.range - math.min(250, (target.characterIntermediate.moveSpeed * (self.qData.delay + pingLatency)))
				end
				self.qData.range = self.qData.range - 50
			end
			local canBeSlowed = canBeStunned and not target:getBuff("Highlander")
			p = pred.getPrediction(target, self.qData)
			if (not self:MissileE(target) or (target.path and (target.path.isDashing or target.path.count <= 1))) and p and p.castPosition.isValid and player.pos:distance2D(p.castPosition) <= chargeRange and p.hitChance >= (target.characterIntermediate.moveSpeed > 0 and HitchanceMenu[self.XerathMenu.prediction.q_hitchance:get()] or 1) and (not self:WillGetHitByW(target) or stunTime > 0 or not canBeSlowed or godBuffTime > 0) then
				player:updateChargeableSpell(SpellSlot.Q, p.castPosition)
				hasCasted = true
				self:DebugPrint("Casted Q with range of " .. math.ceil(self.qData.range) .. " on " .. mode)
				self.qData.range = 750
			end
		end
		return pQ1 and pQ1.hitChance or 0
	end

	-- This function will cast W on the target, the mode attribute is used to check if its enabled in the menu based on mode, as we created the menu similar for combo and harass.
	function Xerath:CastW(target, mode, godBuffTime, pingLatency, noKillBuffTime, GetDamageW, totalHP, stunTime)
		if hasCasted then return 0 end
		if not totalHP then totalHP = 0 end
		local w2 = pred.getPrediction(target, self.w2Data)
		local w1 = pred.getPrediction(target, self.wData)
		local p = (self.XerathMenu.misc.w_center_logic:get() or (w2 and w2.hitChance >= 6)) and ((w2 and w2.hitChance < HitchanceMenu[self.XerathMenu.prediction.w_hitchance:get()]) and w1 or w2) or w1
		local hitChanceMode = (mode == "dash" or mode == "stun" or mode == "casting") and 6 or ((target.characterIntermediate.moveSpeed > 0 and (mode == "combo" or mode == "harass" or mode == "manual")) and HitchanceMenu[self.XerathMenu.prediction.w_hitchance:get()] or 1)
		if godBuffTime <= 0.6 + pingLatency and (noKillBuffTime <= 0.6 + pingLatency or not ((((totalHP) - GetDamageW)/target.maxHealth) < (ElderBuff and 0.2 or 0))) and (not self:MissileE(target) or (target.path and (target.path.isDashing or target.path.count <= 1))) and p and p.castPosition.isValid and player.pos:distance2D(p.castPosition) <= self.wData.range and p.hitChance >= hitChanceMode then
			local test = self:MissileE(target)
			player:castSpell(SpellSlot.W, p.castPosition, true, false)
			self:DebugPrint("Casted W on " .. mode)
			hasCasted = true
		end
		return p and p.hitChance or 0
	end

	function Xerath:CastE(target, mode, godBuffTime, pingLatency, noKillBuffTime, GetDamageE, totalHP, stunTime)
		if hasCasted then return 0 end
		if not totalHP then totalHP = 0 end
		local totalRadius = target.boundingRadius + self.eData.radius
		self.eData.range = 1065 + target.boundingRadius
		if player.pos:distance2D(target.pos) > totalRadius then
			self.eData.from = player.pos:extend(target.pos, totalRadius)
		else
			self.eData.from = target.pos
		end
		local p = pred.getPrediction(target, self.eData)
		self.eData.range = 1065
		local hitChanceMode = (mode == "dash" or mode == "stun" or mode == "casting") and 6 or ((target.characterIntermediate.moveSpeed > 0 and (mode == "combo" or mode == "harass" or mode == "manual")) and HitchanceMenu[self.XerathMenu.prediction.e_hitchance:get()] or 1)
		-- Cast E with pred
		if godBuffTime <= 0.2 + pingLatency and (noKillBuffTime <= 0.2 + pingLatency or not ((((totalHP) - GetDamageE)/target.maxHealth) < (ElderBuff and 0.2 or 0))) and (not self:MissileE(target) or (target.path and (target.path.isDashing or target.path.count <= 1))) and p and p.castPosition.isValid and (player.pos:distance2D(p.castPosition) - target.boundingRadius) <= self.eData.range and p.hitChance >= hitChanceMode and (not self:WillGetHitByW(target) or stunTime > 0 or godBuffTime > 0) then
			player:castSpell(SpellSlot.E, p.castPosition, true, false)
			hasCasted = true
			self:DebugPrint("Casted E on " .. mode)
		end
		return p and p.hitChance or 0
	end

	function Xerath:CastR(target, godBuffTime, pingLatency, noKillBuffTime, GetDamageR, totalHP, stunTime, prioCast, predResult)
		if hasCasted then return 0 end
		if not totalHP then totalHP = 0 end
		local p = predResult
		-- Cast R with pred
		if godBuffTime <= 0.5 + pingLatency and (noKillBuffTime <= 0.5 + pingLatency or not ((((totalHP) - GetDamageR)/target.maxHealth) < (ElderBuff and 0.2 or 0))) and (not self:MissileE(target) or (target.path and (target.path.isDashing or target.path.count <= 1))) and p and p.castPosition.isValid and player.pos:distance2D(p.castPosition) <= self.rData.range and p.hitChance >= ((target.characterIntermediate.moveSpeed > 0 and not prioCast) and HitchanceMenu[self.XerathMenu.prediction.r_hitchance:get()] or 1) then
			player:castSpell(SpellSlot.R, p.castPosition, true, false)
			hasCasted = true
			self:DebugPrint("Casted R")
		end
		return p and p.hitChance or 0
	end

	-- This function will be called every time the player draws a screen (based on FPS)
	-- This is where all drawing code will be executed
	function Xerath:OnDraw()
		self:debugFlush()
		table.insert(debugList, "Draw")
		table.insert(debugList, "Draw1")
		-- Check if the menu option is enabled to draw the Q range
		if self.XerathMenu.drawings.draw_q_range:get() then
			local alpha = player:spellSlot(SpellSlot.Q).state == 0 and 255 or 50
			graphics.drawCircle(player.pos, self:GetTrueChargeRange(1500, 750, 1.5), 2, graphics.argb(alpha, 204, 127, 0))
			graphics.drawCircle(player.pos, 1500, 2, graphics.argb(alpha, 204, 127, 0))
		end
		-- Check if the menu option is enabled to draw the W range
		if self.XerathMenu.drawings.draw_w_range:get() then
			-- If its just 1 line like previous one to check if spell is ready, we can use this code aswell
			-- It has the same effect if checks if the spell is ready, if it is it sets the value to 255, if not it sets it to 50
			local alpha = player:spellSlot(SpellSlot.W).state == 0 and 255 or 50
			graphics.drawCircle(player.pos, self.wData.range, 2, graphics.argb(alpha, 0, 255, 255))
		end
		if self.XerathMenu.drawings.draw_e_range:get() then
			local alpha = player:spellSlot(SpellSlot.E).state == 0 and 255 or 50
			graphics.drawCircle(player.pos, self.eData.range, 2, graphics.argb(alpha, 0, 127, 255))
		end
		if self.XerathMenu.drawings.draw_r_range:get() then
			local alpha = player:spellSlot(SpellSlot.R).state == 0 and 255 or 50
			graphics.drawCircle(player.pos, self.rData.range, 2, graphics.argb(alpha, 255, 127, 0))
		end
		if self.XerathMenu.drawings.draw_q_target:get() and QTarget then
			if QTarget.isValid and not QTarget.isDead then
				graphics.drawCircle(QTarget.pos, 50 + QTarget.boundingRadius, 2, graphics.argb(255, 255, 127, 0))
				graphics.drawCircle(QTarget.pos, (250*-game.time) % 50 + QTarget.boundingRadius, 2, graphics.argb(255, 255, 127, 0))
			end
		end
		if self.XerathMenu.drawings.draw_r_target:get() and RTarget then
			if RTarget.isValid and not RTarget.isDead then
				graphics.drawCircle(RTarget.pos, 50 + RTarget.boundingRadius, 2, graphics.argb(255, 255, 0, 0))
				graphics.drawCircle(RTarget.pos, (250*-game.time) % 50 + RTarget.boundingRadius, 2, graphics.argb(255, 255, 0, 0))
			end
		end
		if self.XerathMenu.drawings.draw_r_range_minimap:get() then
			if player:spellSlot(SpellSlot.R).state == 0 or rBuff then
				graphics.drawCircleMinimap(player.pos, self.rData.range, 1, graphics.argb(255, 255, 127, 0))
			end
		end
		table.remove(debugList, #debugList)
		table.insert(debugList, "DrawCalcsDraw")
		for key,value in ipairs(drawRDamage) do
			if not value.unit.isValid or not value.unit.isHealthBarVisible or value.unit.isDead then goto skipDamage end
			value.unit:drawDamage(value.damage, graphics.argb(150,255,170,0))
			::skipDamage::
		end
		for key,value in ipairs(RKillable) do
			if not value.unit.isValid or not value.unit.isHealthBarVisible or value.unit.isDead then goto skipKillable end
			pos = vec2(value.unit.healthBarPosition.x + 70, value.unit.healthBarPosition.y - 30)
			graphics.drawText2D("Killable -> " .. value.shots .. (value.shots > 1 and " shots" or " shot"), 24, pos, graphics.argb(255,255, 0, 0))
			::skipKillable::
		end
		for key,value in ipairs(drawRValue) do
			if not value.unit.isValid or not value.unit.isHealthBarVisible or value.unit.isDead then goto skipDrawValue end
			pos = vec2(value.unit.healthBarPosition.x + 70, value.unit.healthBarPosition.y - 30)
			graphics.drawText2D(value.text, 24, pos, graphics.argb(255, value.red, 255-value.red, 255-value.red))
			::skipDrawValue::
		end
		table.remove(debugList, #debugList)
		table.insert(debugList, "Draw2")
		if not killList[1] and (listChanged and listChanged + 2 > os.clock() or false) then
			table.insert(killList, "Champion is killable in 3 shots")
		end
		for key,value in ipairs(killList) do
			graphics.drawText2D(value, 24, vec2(self.XerathMenu.drawings.draw_r_list_x:get(), self.XerathMenu.drawings.draw_r_list_y:get()+50*key), graphics.argb(255,255, 0, 0))
		end
		if self.XerathMenu.misc.near_mouse_r:get() > 0 and self.XerathMenu.drawings.draw_near_mouse_r_range:get() and (rBuff or (changeTime and changeTime + 2 > os.clock() or false)) then
			graphics.drawCircle(game.cursorPos, self.XerathMenu.misc.near_mouse_r:get(), 1, graphics.argb(255, 255 , 127, 0))
		end
		table.remove(debugList, #debugList)
		table.insert(debugList, "Draw3")
		if self.XerathMenu.drawings.draw_debug_w:get() then
			for key,value in ipairs(particleWList) do
				graphics.drawCircle(value.obj.pos, self.wData.radius, 3, graphics.argb(255, 0, 255, 255))
				graphics.drawCircle(value.obj.pos, self.w2Data.radius, 3, graphics.argb(255, 0, 127, 255))
			end
		end
		if self.XerathMenu.drawings.draw_debug_r:get() then
			for key,value in ipairs(particleRList) do
				graphics.drawCircle(value.obj.pos, self.rData.radius, 3, graphics.argb(255, 255, 127, 0))
			end
		end
		if self.XerathMenu.drawings.draw_debug_e:get() then
			for key,value in ipairs(particleEList) do
				local missingLivingTime = game.time - value.time
				local traveledDistance = missingLivingTime * value.obj.missileSpeed
				graphics.drawLine(value.obj.startPosition:extend(value.obj.endPosition, traveledDistance), value.obj.endPosition, 3, graphics.argb(255, 255, 127, 125))
				graphics.drawCircle(vec3(value.obj.pos.x, player.pos.y, value.obj.pos.z), self.eData.radius, 4, graphics.argb(255, 127, 0, 255))
			end
		end
		table.remove(debugList, #debugList)
		table.remove(debugList, #debugList)
	end

	-- This function will be called every time someone did cast a spell.
	function Xerath:OnCastSpell(source, spell)
		self:debugFlush()
		-- Compare the handler of the source to our player
		if source.handle == player.handle then
			table.insert(debugList, "CastSpell")
			-- Store the time when the spell was casted, which will be used inside Annie:IsCasting()
			if spell.slot + (spell.name ~= "XerathArcanopulse2" and 1 or 5) <= 5 then
				self.castTimeClock[spell.slot + (spell.name ~= "XerathArcanopulse2" and 1 or 5)] = game.time + self.castTime[spell.slot + (spell.name ~= "XerathArcanopulse2" and 1 or 5)]
				self:DebugPrint("Casting spell: " .. spell.name)
			end
			if spell.name == "XerathLocusOfPower2" then
				rshots = 2 + player:spellSlot(SpellSlot.R).level
			end
			table.remove(debugList, #debugList)
		end
		if not source or not source.isHero then return end
		table.insert(debugList, "Exceptions")
		if spell.name == "EvelynnR" and source.isAlly then
			allyREveCast = game.time
		end
		if spell.name == "EkkoR" and source.isAlly then
			allyREkkoCast = game.time
		end
		table.remove(debugList, #debugList)
		if spell.name == "EkkoR" or spell.name == "EvelynnR" or spell.name == "FizzE" then return end
		table.insert(debugList, "SpellCast")
		local isInstant = bit.band(spell.spellData.resource.flags, 4) == 4
		local castTime = (isInstant or spell.spellData.resource.canMoveWhileChanneling) and 0 or spell.castDelay
		local channelTime = spell.spellData.resource.canMoveWhileChanneling and 0 or spell.spellData.resource.channelDuration -- Add channelduration
		local totalTime = castTime + channelTime
		if totalTime > 0 then
			casting[source.handle] = game.time + totalTime
		end
		table.remove(debugList, #debugList)
	end

	function Xerath:OnBasicAttack(source, spell)
		self:debugFlush()
		if not source or not source.isHero then return end
		table.insert(debugList, "SpellCast")
		local isInstant = bit.band(spell.spellData.resource.flags, 4) == 4
		local castTime = (isInstant or spell.spellData.resource.canMoveWhileChanneling) and 0 or spell.castDelay
		local channelTime = spell.spellData.resource.canMoveWhileChanneling and 0 or spell.spellData.resource.channelDuration -- Add channelduration
		local totalTime = castTime + channelTime
		local target = spell.target
		if target.asAIBase and target.asAIBase.isPlant and target.name == 'PlantSatchel' then
			if source.pos:distance2D(target.pos) <= 325 then
				totalTime = 0
			end
		end
		if totalTime > 0 then
			casting[source.handle] = game.time + totalTime
		end
		table.remove(debugList, #debugList)
	end

	-- This function will be executed inside OnTick and will prevent spamming the same spell as it gets casted.
	-- While a spell is being casted (0.25 sec most of the time), the spell state stays the same.
	function Xerath:IsCasting()
		-- Get current time
		local time = game.time
		-- loop through all the spells
		for index, value in ipairs(self.castTimeClock) do
			-- Logic so casting is considered as finished for the server, your ping
			if time - value < (index ~= 3 and -game.latency/1000 or 0.033) then
				return true
			end
		end
		return false
	end

	-- Call the initialization function
	Xerath:__init()

end)

-- This callback is called when the script gets unloaded.
cb.add(cb.unload, function()
	-- We delete the menu for our script, with the same name as we created it.
	menu.delete('open_Xerath')
end)
