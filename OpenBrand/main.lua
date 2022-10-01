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

	if menu.delete('open_Brand') then return end
    -- Check if the current champion is Annie. If not, don't load the script
    if player.skinName ~= "Brand" then return end
	print("[OpenBrand] Open Brand loaded")
	
	local data = "https://raw.githubusercontent.com/yorik100/Corr/main/OpenBrand/data.json"
	local main = "https://raw.githubusercontent.com/yorik100/Corr/main/OpenBrand/main.lua"
	local version = nil
	local scriptName = "OpenBrand"
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
	local buffToCheck = {"MorganaE", "PantheonE", "KayleR", "TaricR", "SivirE", "FioraW", "NocturneShroudofDarkness", "kindredrnodeathbuff", "YuumiWAttach", "UndyingRage", "ChronoShift", "itemmagekillerveil", "bansheesveil", "malzaharpassiveshield", "XinZhaoRRangedImmunity", "ChronoRevive", "BardRStasis", "ZhonyasRingShield", "gwenwmissilecatcher", "fizzeicon", "LissandraRSelf"}
	local selfBuffToCheck = {"SRX_DragonSoulBuffHextech", "srx_dragonsoulbuffhextech_cd", "SRX_DragonSoulBuffInfernal", "SRX_DragonSoulBuffInfernal_Cooldown", "ASSETS/Perks/Styles/Inspiration/FirstStrike/FirstStrike.lua", "ASSETS/Perks/Styles/Inspiration/FirstStrike/FirstStrikeAvailable.lua", "ASSETS/Perks/Styles/Domination/DarkHarvest/DarkHarvest.lua", "ASSETS/Perks/Styles/Domination/DarkHarvest/DarkHarvestCooldown.lua", "ElderDragonBuff", "4628marker"}
    local Brand = {}
	local buffs = {}
	local particleWList = {}
	local particleGwenList = {}
	local debugList = {}
	local drawRDamage = {}
	local RKillable = {}
	local drawRValue = {}
	local drawETargets = {}
	local casting = {}
	local particleCastList = {}
	local ElderBuff = nil
	local hasCasted = false
	local allyREkkoCast = nil
	local allyREveCast = nil

    -- Creating a debug print function, so the developer can easily check the output and if someone
    -- wants to play with the simple script can disable the debug prints in the console
    function Brand:DebugPrint(...)
        if not self.BrandMenu.debug_print:get() then return end
        print("[OpenBrand] ".. ...)
    end

    -- This will be our initialization function, we call it to load the script and all its variables and functions inside
    function Brand:__init()
	
		self.castTime = {0.25,0.25,0.25,0.25}
		self.castTimeClock = {0,0,0,0}

        -- tables with spell data for prediction
        self.qData = {
            delay = 0.25,
            speed = 1600,
            range = 1100,
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
		self.wData = {
            delay = 0.875,
            speed = math.huge,
            range = 900,
			radius = 260,
            type = spellType.circular,
            rangeType = 0,
            boundingRadiusMod = true
        }
        self.rData = {
            delay = 0,
            speed = math.huge,
            range = math.huge,
			radius = 30,
			collision = { -- if not defined -> no collision calcs
				hero = SpellCollisionType.None, 
				-- Hard = Collides with object and stops on collision
				minion = SpellCollisionType.None, 
				-- Soft = Collides with object and passes through them.
				tower = SpellCollisionType.None, 
				-- None = Doesn't collide with object. Also default if not defined
				extraRadius = 10, 
				-- if not defined -> default = 0		
				-- if not defined -> default = CollisionFlags.None
				flags = bit.bor(CollisionFlags.Windwall, CollisionFlags.Samira, CollisionFlags.Braum)
			},
            type = spellType.linear,
            rangeType = 0,
            boundingRadiusMod = false
        }

        -- self.AnnieMenu will store all the menu data which got returned from the Annie:CreateMenu function
        self.BrandMenu = self:CreateMenu()
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
    function Brand:CreateMenu()
        -- Create the main menu
        local mm = menu.create('open_Brand', 'OpenBrand')
        -- Create a submenu inside the main menu
        mm:header('combo', 'Combo Mode')
        -- Create On/Off option inside the combo submenu
        mm.combo:boolean('use_q', 'Use Q', true)
        mm.combo:boolean('use_w', 'Use W', true)
        mm.combo:boolean('use_e', 'Use E', true)
		mm.combo:boolean('use_r', 'Use R', true)
		mm.combo:boolean('r_logic', 'Avoid wasting R', true)
		mm.combo:boolean('use_r_minion', 'Use R on minion to kill with bounce', true)
		mm.combo:slider('r_bounces', 'Min amount of R bounces to kill for combo R', 2, 0, 3, 1)
		mm.combo:slider('r_aoe', 'Min amount of targets to combo R (AoE)', 2, 0, 5, 1)
        -- Create slider option inside the combo submenu
        -- mm.combo:slider('multi_r', 'Multi target R', 2, 3, 5, 1)
        -- mm.combo:boolean('block_spells', 'Save spells for stun (E -> Q / W)', true)
        mm:header('harass', 'Harass Mode')
        mm.harass:boolean('use_q', 'Use Q', false)
        mm.harass:boolean('use_w', 'Use W', true)
        mm.harass:boolean('use_e', 'Use E', true)        -- mm.harass:boolean('block_spells', 'Save spells for stun (E -> Q / W)', true)
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
		mm.drawings:boolean('draw_e_range_bounce', 'Draw E Range Bounce', true)
        mm.drawings:boolean('draw_r_range', 'Draw R Range', true)
		mm.drawings:boolean('draw_r_damage', 'Draw R Damage', true)
		mm.drawings:boolean('draw_r_damage_text', 'Draw R Damage Text', true)
		mm.drawings:boolean('draw_debug_w', 'Draw W Hitbox', true)
        mm:header('misc', 'Misc')
		mm.misc:boolean('q_dash', 'Auto Q on dashes', true)
		mm.misc:boolean('w_dash', 'Auto W on dashes', true)
		mm.misc:boolean('q_channel', 'Auto Q on channels', true)
		mm.misc:boolean('w_channel', 'Auto W on channels', true)
		mm.misc:boolean('q_stun', 'Auto Q on stuns', true)
		mm.misc:boolean('w_stun', 'Auto W on stuns', true)
		mm.misc:boolean('q_stasis', 'Auto Q on stasis', true)
		mm.misc:boolean('w_stasis', 'Auto W on stasis', true)
		mm.misc:boolean('q_casting', 'Auto Q on spellcast/attack', true)
		mm.misc:boolean('w_casting', 'Auto W on spellcast/attack', true)
		mm.misc:boolean('q_particle', 'Auto Q on particles', true)
		mm.misc:boolean('w_particle', 'Auto W on particles', true)
		mm:header('prediction', 'Hitchance')
		mm.prediction:list('q_hitchance', 'Q Hitchance', { 'Low', 'Medium', 'High', 'Very High', 'Undodgeable' }, 2)
		mm.prediction:list('w_hitchance', 'W Hitchance', { 'Low', 'Medium', 'High', 'Very High', 'Undodgeable' }, 3)
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
	
	function Brand:debugFlush()
		if debugList[1] then
			local debugText = ""
			for key,value in ipairs(debugList) do 
				debugText = debugText .. " " .. value
			end
			print("[OpenDebug] Error found in" .. debugText)
			debugList = {}
		end
	end
	
	function Brand:gwenWParticlePos(target)
		local particle = particleGwenList[target.handle]
		return particle.pos
	end
	
	-- To know the remaining time of someone's invulnerable or spellshielded
	function Brand:godBuffTime(target)
		local buffTime = 0
		local buffList = {"KayleR", "TaricR", "SivirE", "FioraW", "PantheonE", "NocturneShroudofDarkness", "kindredrnodeathbuff", "XinZhaoRRangedImmunity", "gwenwmissilecatcher", "fizzeicon"}
		for i, name in ipairs(buffList) do
			local buff = target:getBuff(name)
			if buff and buffTime < buff.remainingTime and (buff.name ~= "PantheonE" or self:IsFacingPlayer(target)) and (buff.name ~= "XinZhaoRRangedImmunity" or player.pos:distance2D(target.pos) > 450) and (buff.name ~= "gwenwmissilecatcher" or player.pos:distance2D(self:gwenWParticlePos(target)) > 440) then
				buffTime = buff.remainingTime
				if buff.name == "PantheonE" then
					buffTime = buffTime + 0.15 
				end
			end
		end
		return buffTime
	end
	
	function Brand:noKillBuffTime(target)
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
	
	function Brand:getStasisTime(target)
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
	
	function Brand:invisibleValid(target, distance)
		return (target.isValid and target.pos and target.pos:distance2D(player.pos) <= distance and target.isRecalling and not target.isDead and not target.isInvulnerable and target.isTargetable)
	end
	
	function Brand:WillGetHitByW(target)
		if not target then return false end
		for key,value in ipairs(particleWList) do
			local timeBeforeHit = value.time + 0.625 - game.time
			if value.obj and (target.path and pred.positionAfterTime(target, math.max(0, timeBeforeHit)):distance2D(value.obj.pos) <= self.wData.radius or target.pos:distance2D(value.obj.pos) <= self.wData.radius) then
				return timeBeforeHit
			end
		end
		return false
	end
	
	-- Thanks seidhr
	function Brand:IsFacingPlayer(entity)
		local skillshotDirection = (entity.pos - player.pos):normalized()
		local direction = entity.direction
        local facing = skillshotDirection:dot(direction)
		return facing < 0
	end
	
	function Brand:GetExtraDamage(target, shots, predictedHealth, damageDealt, isCC, firstShot, isTargeted, passiveStacks)
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
			local buff10 = target.asAIBase:findBuff("BrandAblaze")
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
			local passiveCount = buff10 and buff10.stacks or 0
			local passiveCount = math.min(3, passiveCount + passiveStacks)
			damage = damage + damageLib.magical(player, target, (target.maxHealth*0.025)*passiveCount)
			if (not buff10 or (buff10 and buff10.stacks < 3)) and passiveCount == 3 then
				local damagePercent = (math.min(0.13, 0.0875 + 0.0025*player.level) + 0.025)
				damage = damage + damageLib.magical(player, target, target.maxHealth*damagePercent)
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
		if hasHorizonFocus and (isCC or hasRylai or (not isTargeted and player.pos:distance2D(target.pos) > 700) or target:getBuff("4628marker")) then
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
    function Brand:GetDamageQ(target, time)
        local spell = player:spellSlot(SpellSlot.Q)
        if spell.level == 0 then return 0 end
        local time = time or 0
        if spell.state ~= 0 and spell.cooldown > time then return 0 end
        local damage = 50 + spell.level * 30 + player.totalAbilityPower*0.55
		local damageLibDamage = damageLib.magical(player, target, damage)
        return damageLibDamage + self:GetExtraDamage(target, 0, target.health, damageLibDamage, false, true, false, 1)
    end

    function Brand:GetDamageW(target, time)
        local spell = player:spellSlot(SpellSlot.W)
        if spell.level == 0 then return 0 end
        local time = time or 0
        if spell.state ~= 0 and spell.cooldown > time then return 0 end
        local damage = 30 + 45 * spell.level + player.totalAbilityPower*0.60
		local damageLibDamage = damageLib.magical(player, target, damage)
        return damageLibDamage + self:GetExtraDamage(target, 0, target.health, damageLibDamage, true, true, false, 1)
    end
	
    function Brand:GetDamageW2(target, time)
		return Brand:GetDamageW(target, time)*1.25
    end

    function Brand:GetDamageE(target, time)
        local spell = player:spellSlot(SpellSlot.E)
        if spell.level == 0 then return 0 end
        local time = time or 0
        if spell.state ~= 0 and spell.cooldown > time then return 0 end
        local damage = 45 + 25 * spell.level + player.totalAbilityPower*0.45
		local damageLibDamage = damageLib.magical(player, target, damage)
        return damageLibDamage + self:GetExtraDamage(target, 0, target.health, damageLibDamage, true, true, true, 1)
    end
	
    function Brand:GetDamageR(target, time, shots, predictedHealth, firstShot, passiveStacks)
        local spell = player:spellSlot(SpellSlot.R)
        if spell.level == 0 then return 0 end
        local time = time or 0
        if spell.state ~= 0 and spell.cooldown > time then return 0 end
        local damage = 100 * spell.level + player.totalAbilityPower*0.25
		local damageLibDamage = damageLib.magical(player, target, damage)
        return damageLibDamage + self:GetExtraDamage(target, shots, predictedHealth, damageLibDamage, false, firstShot, true, passiveStacks)
    end
	
	function Brand:OnGlow()
		self:debugFlush()
		table.insert(debugList, "Glow")
		table.remove(debugList, #debugList)
	end
	
	function Brand:OnCreate(object)
		table.insert(debugList, "Create")
		
		if string.find(object.name, "_POF_tar_green") and string.find(object.name, "Brand_") then
			table.insert(particleWList, {obj = object, time = game.time})
			self:DebugPrint("Added particle W")
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
		elseif string.find(object.name, "Zed") and string.find(object.name, "_W_tar") and object.isEffectEmitter and object.asEffectEmitter.attachment.object and object.asEffectEmitter.targetAttachment.object then
            owner = object.asEffectEmitter.attachment.object.asAttackableUnit.owner.asAIBase
            target = object.asEffectEmitter.targetAttachment.object
			table.insert(particleCastList, {obj = object, time = game.time, castTime = 0.75, owner = owner, target = target, castingPos = nil, bounding = 65, speed = 345, zedR = true})
			self:DebugPrint("Added cast particle " .. object.name)
		end
		table.remove(debugList, #debugList)
		-- print(object.name)
	end
	
	function Brand:OnDelete(object)
		self:debugFlush()
		table.insert(debugList, "Delete")
		if string.find(object.name, "_POF_tar_green") and string.find(object.name, "Brand_") then
			for key,value in ipairs(particleWList) do
				if value.obj.handle == object.handle then
					table.remove(particleWList, key)
					self:DebugPrint("Removed particle W")
					break
				end
			end
		elseif string.find(object.name, "_W_MistArea") then
			local owner = object.asEffectEmitter.attachment.object
			if not owner then goto endMist end
			local owner2 = owner.asAttackableUnit.owner
			if not owner2 then goto endMist end
			particleGwenList[owner2.handle] = nil
			self:DebugPrint("Removed particle Gwen")
			::endMist::
		elseif string.find(object.name, "_R_Gatemarker") or string.find(object.name, "_R_ChargeIndicator") or (string.find(object.name, "_R_Update_Indicator") and not string.find(object.name, "PreJump")) or string.find(object.name, "R_Tar_Ground") or string.find(object.name, "R_Landing") or string.find(object.name, "W_ImpactWarning") or string.find(object.name, "_W_tar") then
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
    function Brand:OnBuff(source, buff, gained)
		self:debugFlush()
		if not source.isHero then return end
		table.insert(debugList, "Buff")
		if source and not gained and buff.name == "willrevive" and source.characterState.statusFlags == 65537 and source:hasItem(3026) and self:getStasisTime(source) <= 0 then
				buffs["Time" .. source.handle] = game.time + 4
				self:DebugPrint("Detected Guardian angel on " .. source.skinName)
		end
		if self.BrandMenu.debug_print_buffs:get() then	
			self:DebugPrint(source.skinName .. " -> Buff " .. (gained and "gained" or "lost") .. " : (" .. tostring(buff.name) .. ")" .. (buff.caster and (" from " .. buff.caster.name) or ""))
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

	function Brand:OnTick()
		self:debugFlush()
		table.insert(debugList, "Tick")
		hasCasted = false
		self:DrawCalcs()
        if player.isDead then table.remove(debugList, #debugList) return end
		local stunBuffList = {BuffType.Stun, BuffType.Silence, BuffType.Taunt, BuffType.Polymorph, BuffType.Fear, BuffType.Charm, BuffType.Suppression, BuffType.Knockup, BuffType.Knockback, BuffType.Asleep}
		for key,buff in ipairs(stunBuffList) do
			if player:hasBuffOfType(buff) then
				table.remove(debugList, #debugList)
				return
			end
		end
		if self:IsCasting() then
			orb.setAttackPause(0.075)
			table.remove(debugList, #debugList)
			return
		end
        self:Combo()
        self:Harass()
		self:Auto()
		table.remove(debugList, #debugList)
    end
	
	
	function Brand:DrawCalcs()
	table.insert(debugList, "DrawCalcs")
	ElderBuff = myHero:getBuff("ElderDragonBuff")
	table.insert(debugList, "DrawLoop")
	drawRDamage = {}
	RKillable = {}
	drawRValue = {}
	drawETargets = {}
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
			local rActive = player:spellSlot(SpellSlot.R).level ~= 0 and player:spellSlot(SpellSlot.R).cooldown <= 0
			if self.BrandMenu.drawings.draw_r_damage:get() and rActive then
				rDamage = 0
				for i = 3 - 1, 0, -1 do
					local calculatedRDamage = self:GetDamageR(unit, 0, i, totalHP - rDamage, isFirstShot, shotsToKill + 1)
					local calculatedRMaxDamage = self:GetDamageR(unit, 0, 0, totalHP - rDamage, isFirstShot, shotsToKill + 1)
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
			if self.BrandMenu.drawings.draw_r_damage_text:get() and rActive then
				if not rDamage then
					rDamage = 0
					for i = 3 - 1, 0, -1 do
					local calculatedRDamage = self:GetDamageR(unit, 0, i, totalHP - rDamage, isFirstShot, shotsToKill + 1)
					local calculatedRMaxDamage = self:GetDamageR(unit, 0, 0, totalHP - rDamage, isFirstShot, shotsToKill + 1)
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
		table.insert(debugList, "DrawELoop")
			if self.BrandMenu.drawings.draw_e_range_bounce:get() and player:spellSlot(SpellSlot.E).state == 0 then
				for _, minion in pairs(objManager.aiBases.list) do
					table.insert(debugList, "DrawELoop1 " .. (minion.name and tostring(minion.name) or ""))
					local validTarget =  minion and minion.isValid and minion.name ~= "Barrel" and minion.name ~= "GameObject" and (minion.isMinion or minion.isPet or minion.isHero) and not minion.isPlant and minion:isValidTarget(660, true, player.pos) and minion.isTargetable
					if not validTarget then goto continue1 end
					for index, target in pairs(ts.getTargets()) do
						local validTarget =  target and target:isValidTarget(600, true, minion.pos) and target.isTargetable and minion.handle ~= target.handle
						if not validTarget then goto continue2 end
						local BrandABlaze = minion.asAIBase:findBuff("BrandAblaze")
						local totalRange = (BrandABlaze and BrandABlaze.remainingTime >= 0.25 + game.latency/1000) and 600 or 300
						local minionAI = minion.asAIBase
						if minion.pos:distance2D(target.pos) <= totalRange and (minionAI.path and pred.positionAfterTime(minionAI, 0.25 + game.latency/1000) or minionAI.pos):distance2D(target.path and pred.positionAfterTime(target, 0.25 + game.latency/1000) or target.pos) <= totalRange then
							table.insert(drawETargets, {unit = minion, totalERange = totalRange})
						end
						::continue2::
					end
					::continue1::
					table.remove(debugList, #debugList)
				end
			end
			table.remove(debugList, #debugList)
			table.remove(debugList, #debugList)
			::continue::
		end
	end
	table.remove(debugList, #debugList)
	table.remove(debugList, #debugList)
	end
	
    function Brand:Auto()
		table.insert(debugList, "Auto")
		table.insert(debugList, "Auto1")
		local onceOnly = false
		local CCQ = self.BrandMenu.misc.q_stun:get() and player:spellSlot(SpellSlot.Q).state == 0
		local CCW = self.BrandMenu.misc.w_stun:get() and player:spellSlot(SpellSlot.W).state == 0
		local ChannelQ = self.BrandMenu.misc.q_channel:get() and player:spellSlot(SpellSlot.Q).state == 0
		local ChannelW = self.BrandMenu.misc.w_channel:get() and player:spellSlot(SpellSlot.W).state == 0
		local DashQ = self.BrandMenu.misc.q_dash:get() and player:spellSlot(SpellSlot.Q).state == 0
		local DashW = self.BrandMenu.misc.w_dash:get() and player:spellSlot(SpellSlot.W).state == 0
		local StasisQ = self.BrandMenu.misc.q_stasis:get() and player:spellSlot(SpellSlot.Q).state == 0
		local StasisW = self.BrandMenu.misc.w_stasis:get() and player:spellSlot(SpellSlot.W).state == 0
		local CastingQ = self.BrandMenu.misc.q_casting:get() and player:spellSlot(SpellSlot.Q).state == 0
		local CastingW = self.BrandMenu.misc.w_casting:get() and player:spellSlot(SpellSlot.W).state == 0
		local pingLatency = game.latency/1000
		table.remove(debugList, #debugList)
		table.insert(debugList, "AutoLoop")
        for index, enemy in pairs(ts.getTargets()) do
			local stasisTime = self:getStasisTime(enemy)
			local validTarget =  enemy and ((enemy:isValidTarget(math.huge, true, player.pos) and enemy.isTargetable) or stasisTime > 0 or self:invisibleValid(enemy, math.huge))
			if not validTarget then goto continue end
			
			if enemy.characterState.statusFlags ~= 65537 then buffs["Time" .. enemy.handle] = nil end
			
			table.insert(debugList, "AutoCalcs")
			local dashing = enemy.path and enemy.path.isDashing
			local CCTime = pred.getCrowdControlledTime(enemy)
			local channelingSpell = (enemy.isCastingInterruptibleSpell and enemy.isCastingInterruptibleSpell > 0) or (enemy.activeSpell and enemy.activeSpell.hash == 692142347) or enemy.isRecalling
			local castTime = (enemy.activeSpell and casting[enemy.handle] and game.time < casting[enemy.handle]) and (casting[enemy.handle] - game.time) or 0
			table.remove(debugList, #debugList)
			if (CCTime <= 0 or not (CCQ or CCW)) and (not channelingSpell or not (ChannelQ or ChannelW)) and (not dashing or not (DashQ or DashW)) and (stasisTime <= 0 or not (StasisQ or StasisW)) and (castTime <= 0 or not (CastingQ or CastingW)) then goto continue end
			
			table.insert(debugList, "AutoCalcs2")
			local godBuffTimeAuto = self:godBuffTime(enemy)
			local noKillBuffTimeAuto = self:noKillBuffTime(enemy)
			local QDamage = self:GetDamageQ(enemy, 0)
			local WDamage = self:GetDamageW2(enemy, 0)
			local RDamage = self:GetDamageR(enemy, 0, 0, enemy.health, true, 1)
			local totalHP = (enemy.health + enemy.allShield + enemy.magicalShield)
			local Ablaze = enemy.asAIBase:findBuff("BrandAblaze")
			local WHit = self:WillGetHitByW(enemy)
			local QLandingTime = ((player.pos:distance2D(enemy.pos) - (player.boundingRadius + enemy.boundingRadius)) / self.qData.speed + self.qData.delay)
			local canBeStunned = not enemy.isUnstoppable and not enemy:getBuff("MorganaE") and not enemy:getBuff("bansheesveil") and not enemy:getBuff("itemmagekillerveil") and not enemy:getBuff("malzaharpassiveshield")
			table.remove(debugList, #debugList)
			
			table.insert(debugList, "AutoQDash")
			if DashQ and dashing and godBuffTimeAuto <= 0.2 + pingLatency and (noKillBuffTimeAuto <= 0.2 + pingLatency or QDamage < totalHP) and canBeStunned then
				if Ablaze or WHit then
					self:CastQ(enemy,"dash", godBuffTimeAuto, pingLatency, noKillBuffTimeAuto, QDamage, totalHP, CCTime)
				elseif player:spellSlot(SpellSlot.E).state == 0 and enemy.isVisible and enemy.pos:distance2D(player.pos) <= 660 then
					self:CastE(enemy,"dash", godBuffTimeAuto, pingLatency, noKillBuffTimeAuto, EDamage, totalHP, CCTime, enemy)
				end
			end
			table.remove(debugList, #debugList)
			table.insert(debugList, "AutoQInterrupt")
			if ChannelQ and channelingSpell and godBuffTimeAuto <= 0.2 + pingLatency and (noKillBuffTimeAuto <= 0.2 + pingLatency or QDamage < totalHP) and canBeStunned then
				if Ablaze or WHit then
					self:CastQ(enemy,"channel", godBuffTimeAuto, pingLatency, noKillBuffTimeAuto, QDamage, totalHP, CCTime)
				elseif player:spellSlot(SpellSlot.E).state == 0 and enemy.isVisible and enemy.pos:distance2D(player.pos) <= 660 then
					self:CastE(enemy,"channel", godBuffTimeAuto, pingLatency, noKillBuffTimeAuto, EDamage, totalHP, CCTime, enemy)
				end
			end
			table.remove(debugList, #debugList)
			table.insert(debugList, "AutoQCC")
			if CCQ and CCTime > 0 and (CCTime - pingLatency - 0.3) < QLandingTime and godBuffTimeAuto <= 0.2 + pingLatency and (noKillBuffTimeAuto <= 0.2 + pingLatency or QDamage < totalHP) and canBeStunned then
				if Ablaze or WHit then
					self:CastQ(enemy,"stun", godBuffTimeAuto, pingLatency, noKillBuffTimeAuto, QDamage, totalHP, CCTime)
				elseif player:spellSlot(SpellSlot.E).state == 0 and enemy.isVisible and enemy.pos:distance2D(player.pos) <= 660 then
					self:CastE(enemy,"stun", godBuffTimeAuto, pingLatency, noKillBuffTimeAuto, EDamage, totalHP, CCTime, enemy)
				end
			end
			table.remove(debugList, #debugList)
			table.insert(debugList, "AutoQCasting")
			if CastingQ and castTime > 0 and godBuffTimeAuto <= 0.2 + pingLatency and (noKillBuffTimeAuto <= 0.2 + pingLatency or QDamage < totalHP) and canBeStunned then
				if Ablaze or WHit then
					self:CastQ(enemy,"casting", godBuffTimeAuto, pingLatency, noKillBuffTimeAuto, QDamage, totalHP, CCTime)
				elseif player:spellSlot(SpellSlot.E).state == 0 and enemy.isVisible and enemy.pos:distance2D(player.pos) <= 660 then
					self:CastE(enemy,"casting", godBuffTimeAuto, pingLatency, noKillBuffTimeAuto, EDamage, totalHP, CCTime, enemy)
				end
			end
			table.remove(debugList, #debugList)
			table.insert(debugList, "AutoQStasis")
			if StasisQ and stasisTime > 0 and (stasisTime - pingLatency) < QLandingTime and godBuffTimeAuto <= 0.2 + pingLatency and (noKillBuffTimeAuto <= 0.2 + pingLatency or QDamage < totalHP) and canBeStunned then
				self:CastQ(enemy,"stasis", godBuffTimeAuto, pingLatency, noKillBuffTimeAuto, QDamage, totalHP, CCTime)
			end
			table.remove(debugList, #debugList)
			table.insert(debugList, "AutoWDash")
			if DashW and dashing and godBuffTimeAuto <= 0.5 + pingLatency and (noKillBuffTimeAuto <= 0.5 + pingLatency or WDamage < totalHP) then
				self:CastW(enemy,"dash", godBuffTimeAuto, pingLatency, noKillBuffTimeAuto, WDamage, totalHP, CCTime)
			end
			table.remove(debugList, #debugList)
			table.insert(debugList, "AutoWChannel")
			if ChannelW and channelingSpell and godBuffTimeAuto <= 0.5 + pingLatency and (noKillBuffTimeAuto <= 0.5 + pingLatency or WDamage < totalHP) then
				self:CastW(enemy,"channel", godBuffTimeAuto, pingLatency, noKillBuffTimeAuto, WDamage, totalHP, CCTime)
			end
			table.remove(debugList, #debugList)
			table.insert(debugList, "AutoWCC")
			if CCW and CCTime > 0 and godBuffTimeAuto <= 0.5 + pingLatency and (noKillBuffTimeAuto <= 0.5 + pingLatency or WDamage < totalHP) then
				self:CastW(enemy,"stun", godBuffTimeAuto, pingLatency, noKillBuffTimeAuto, WDamage, totalHP, CCTime)
			end
			table.remove(debugList, #debugList)
			table.insert(debugList, "AutoWCasting")
			if CastingW and castTime > 0 and godBuffTimeAuto <= 0.5 + pingLatency and (noKillBuffTimeAuto <= 0.5 + pingLatency or WDamage < totalHP) then
				self:CastW(enemy,"casting", godBuffTimeAuto, pingLatency, noKillBuffTimeAuto, WDamage, totalHP, CCTime)
			end
			table.remove(debugList, #debugList)
			table.insert(debugList, "AutoWStasis")
			if StasisW and not StasisE and stasisTime > 0 and (stasisTime - pingLatency + 0.2) < 0.875 and godBuffTimeAuto <= 0.7 + pingLatency and (noKillBuffTimeAuto <= 0.7 + pingLatency or WDamage < totalHP) then
				self:CastW(enemy,"stasis", godBuffTimeAuto, pingLatency, noKillBuffTimeAuto, WDamage, totalHP, CCTime)
			end
			table.remove(debugList, #debugList)
			::continue::
        end
		table.remove(debugList, #debugList)
		table.insert(debugList, "AutoParticleLoop")
		local QParticle = (self.BrandMenu.misc.q_particle:get() and player:spellSlot(SpellSlot.Q).state == 0)
		local WParticle = (self.BrandMenu.misc.w_particle:get() and player:spellSlot(SpellSlot.W).state == 0)
		if (QParticle or WParticle) and particleCastList[1] and not hasCasted then
				if (value.team and value.team == player.team) or not value.isEnemy then goto nextParticle end
				local particleOwner = (value.obj.asEffectEmitter.attachment.object and value.obj.asEffectEmitter.attachment.object.isAIBase and value.obj.asEffectEmitter.attachment.object.isEnemy) and value.obj.asEffectEmitter.attachment.object or ((value.obj.asEffectEmitter.targetAttachment.object and value.obj.asEffectEmitter.targetAttachment.object.isAIBase and value.obj.asEffectEmitter.targetAttachment.object.isEnemy) and value.obj.asEffectEmitter.targetAttachment.object or nil)
				if not particleOwner or not particleOwner.isHero then
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
				if particleOwner and particleOwner.isHero then
					particleOwner = particleOwner.asAIBase
					print("Owner found : " .. particleOwner.name)
				end
				if value.zedR then
					value.castingPos = value.target.pos + (value.owner.direction * value.target.boundingRadius)
				end
				if not value.castingPos or player.pos:distance2D(value.castingPos) > self.qData.range or not particleOwner.isEnemy then goto nextParticle end
				local particleTime = (value.time + value.castTime) - game.time
				local QLandingTime = ((player.pos:distance2D(value.castingPos) - (player.boundingRadius + particleOwner.boundingRadius)) / self.qData.speed + self.qData.delay)
				local QCanDodge = particleOwner.characterIntermediate.moveSpeed*((QLandingTime - particleTime) + pingLatency) > self.qData.radius + particleOwner.boundingRadius
				local WCanDodge = particleOwner.characterIntermediate.moveSpeed*((self.wData.delay - particleTime) + pingLatency) > self.wData.radius
				local canQ = QParticle and not QCanDodge and not pred.findSpellCollisions((particleOwner.handle and particleOwner or nil), self.qData, player.pos, value.castingPos, QLandingTime+pingLatency)[1]
				local canW = WParticle and not WCanDodge and player.pos:distance2D(value.castingPos) <= self.wData.range
				if canQ and not canW and (particleTime - pingLatency + 0.2) <= QLandingTime then
					player:castSpell(SpellSlot.Q, value.castingPos, true, false)
					hasCasted = true
					self:DebugPrint("Casted Q on particle")
				elseif canW and (particleTime - pingLatency + 0.15) <= 0.875 then
					player:castSpell(SpellSlot.W, value.castingPos, true, false)
					hasCasted = true
					self:DebugPrint("Casted W on particle")
				end
				::nextParticle::
		end
		table.remove(debugList, #debugList)
		table.remove(debugList, #debugList)
    end
	
    -- This function will include all the logics for the combo mode
    function Brand:Combo()
		if hasCasted then return end
		
        if orb.isComboActive == false then return end
		
		table.insert(debugList, "Combo")
		local pingLatency = game.latency/1000
		for index, target in pairs(ts.getTargets()) do
			local validTarget =  target and not target.isZombie and (target:isValidTarget(1100, true, player.pos) or self:invisibleValid(target, 1100)) and target.isTargetable and not target.isInvulnerable
			if not validTarget then goto continue end
			
			table.insert(debugList, "ComboCalcs")
			local CanUseQ = self.BrandMenu.combo.use_q:get() and player:spellSlot(SpellSlot.Q).state == 0
			local CanUseW = self.BrandMenu.combo.use_w:get() and player:spellSlot(SpellSlot.W).state == 0 and (target.path and pred.positionAfterTime(target, 0.625 + game.latency/1000):distance2D(player.pos) <= 900 or target.pos:distance2D(player.pos) <= 900)
			local CanUseE = self.BrandMenu.combo.use_e:get() and player:spellSlot(SpellSlot.E).state == 0 and target.pos:distance2D(player.pos) <= 660 and target.isVisible
			local CanUseR = self.BrandMenu.combo.use_r:get() and player:spellSlot(SpellSlot.R).state == 0 and target.pos:distance2D(player.pos) <= 750
			if self.BrandMenu.combo.use_e:get() and player:spellSlot(SpellSlot.E).state == 0 then orb.setAttackPause(0.075) end
			table.remove(debugList, #debugList)
			if not CanUseQ and not CanUseW and not CanUseE and not CanUseR then goto continue end
			
			table.insert(debugList, "ComboRCalcs")
			local totalHP = (target.health + target.allShield + target.magicalShield)
			local rKills = false
			local AoECount = 0
			local rTotalDamage = 0
			if CanUseR then
				local shotsToKill = 0
				local isFirstShot = true
				local rCanBounce = false
				if player and player.pos:distance2D(target.pos) <= 600 and player.pos:distance2D(target.path and pred.positionAfterTime(target, 0.6 + game.latency/1000) or target.pos) <= 600 then rCanBounce = true end
				if not rCanBounce then
					for _, minion in pairs(objManager.aiBases.list) do
						local validTarget =  minion and minion.isValid and minion.name ~= "Barrel" and minion.name ~= "GameObject" and (minion.isMinion or minion.isPet or minion.isHero) and not minion.isPlant and minion.handle ~= target.handle and minion:isValidTarget(600, true, target.pos) and minion.isTargetable
						local enemyPos = target.path and pred.positionAfterTime(target, 0.6 + game.latency/1000) or target.pos
						local minionAI = minion.asAIBase
						if not validTarget or (minionAI.path and pred.positionAfterTime(minionAI, 0.25 + game.latency/1000) or minionAI.pos):distance2D(enemyPos) > 600 then goto continue2 end          
						rCanBounce = true
						break
						::continue2::
					end
				end
				if self.BrandMenu.combo.r_aoe:get() > 0 then
					for index2, target2 in pairs(ts.getTargets()) do
						local validTarget =  target2 and target2:isValidTarget(600, true, target.pos) and target2.isTargetable
						local enemyPos = target.path and pred.positionAfterTime(target, 0.6 + game.latency/1000) or target.pos
						local bounceEnemyPos = target2.path and pred.positionAfterTime(target2, 0.6 + game.latency/1000) or target2.pos
						if not validTarget or bounceEnemyPos:distance2D(enemyPos) > 600 then goto continue3 end
						AoECount = AoECount + 1
						::continue3::
					end
				end
				for i = 3 - 1, 0, -1 do
					local calculatedRDamage = self:GetDamageR(target, 0, i, totalHP - rTotalDamage, isFirstShot, shotsToKill + 1)
					local calculatedRMaxDamage = self:GetDamageR(target, 0, 0, totalHP - rTotalDamage, isFirstShot, shotsToKill + 1)
					if ((totalHP) - (rTotalDamage + calculatedRMaxDamage))/target.maxHealth < (ElderBuff and 0.2 or 0) then
						rTotalDamage = rTotalDamage + calculatedRMaxDamage
						shotsToKill = shotsToKill + 1
						break
					end
					rTotalDamage = rTotalDamage + calculatedRDamage
					shotsToKill = shotsToKill + 1
					isFirstShot = false
				end
				if ((totalHP) - rTotalDamage)/target.maxHealth < 0.2 and ElderBuff then
					rTotalDamage = totalHP
				end
				if rTotalDamage >= totalHP and shotsToKill <= (rCanBounce and self.BrandMenu.combo.r_bounces:get() or 1) then
					rKills = true
				end
			end
			table.remove(debugList, #debugList)
			
			table.insert(debugList, "ComboCalcs2")
			local CCTime = pred.getCrowdControlledTime(target)
			local dashing = target.path and target.path.isDashing
			local godBuffTimeCombo = self:godBuffTime(target)
			local noKillBuffTimeCombo = self:noKillBuffTime(target)
			local QDamage = self:GetDamageQ(target, 0)
			local EDamage = self:GetDamageE(target, 0)
			local WDamage = self:GetDamageW2(target, 0)
			local RDamage = rTotalDamage
			local channelingSpell = (target.isCastingInterruptibleSpell and target.isCastingInterruptibleSpell > 0) or (target.activeSpell and target.activeSpell.hash == 692142347)
			local QLandingTime = ((player.pos:distance2D(target.pos) - (player.boundingRadius + target.boundingRadius)) / self.qData.speed + self.qData.delay)
			-- local canBeStunned = not target.isUnstoppable and not target:getBuff("MorganaE") and not target:getBuff("bansheesveil") and not target:getBuff("itemmagekillerveil") and not target:getBuff("malzaharpassiveshield")
			table.remove(debugList, #debugList)
			
			table.insert(debugList, "ComboE")
			if CanUseE and orb.predictHP(target, 0.2 + pingLatency) > 0 and godBuffTimeCombo <= 0.5 + pingLatency and (noKillBuffTimeCombo <= 0.5 + game.latency/1000 or not ((((totalHP) - EDamage)/target.maxHealth) < (ElderBuff and 0.2 or 0))) then
				self:CastE(target,"combo", godBuffTimeCombo, pingLatency, noKillBuffTimeCombo, EDamage, totalHP, CCTime, target)
				table.remove(debugList, #debugList)
				break
			end
			table.remove(debugList, #debugList)
			table.insert(debugList, "ComboQ")
			if CanUseQ and orb.predictHP(target, 0.2 + pingLatency) > 0 and godBuffTimeCombo <= 0.2 + pingLatency and (noKillBuffTimeCombo <= 0.2 + pingLatency or not ((((totalHP) - QDamage)/target.maxHealth) < (ElderBuff and 0.2 or 0))) then
				if self:CastQ(target,"combo", godBuffTimeCombo, pingLatency, noKillBuffTimeCombo, QDamage, totalHP, chargingQ, CCTime) > 0 then table.remove(debugList, #debugList) break end
			end
			table.remove(debugList, #debugList)
			table.insert(debugList, "ComboW")
			if CanUseW and orb.predictHP(target, 0.7 + pingLatency) > 0 and godBuffTimeCombo <= 1 + pingLatency and (noKillBuffTimeCombo <= 1 + game.latency/1000 or not ((((totalHP) - WDamage)/target.maxHealth) < (ElderBuff and 0.2 or 0))) then
				if self:CastW(target,"combo", godBuffTimeCombo, pingLatency, noKillBuffTimeCombo, WDamage, totalHP, CCTime) > 0 then table.remove(debugList, #debugList) break end
			end
			table.remove(debugList, #debugList)
			table.insert(debugList, "ComboR")
			if CanUseR and ((rKills and self.BrandMenu.combo.r_bounces:get() > 0 and (not self.BrandMenu.combo.r_logic:get() or pred.positionAfterTime(target, 0.1 + pingLatency):distance2D(player.pos) > 750)) or (AoECount >= self.BrandMenu.combo.r_aoe:get() and self.BrandMenu.combo.r_aoe:get() > 0))and orb.predictHP(target, 0.2 + pingLatency) > 0 and godBuffTimeCombo <= 0.5 + pingLatency and (noKillBuffTimeCombo <= 0.5 + game.latency/1000 or not ((((totalHP) - EDamage)/target.maxHealth) < (ElderBuff and 0.2 or 0))) then
				self:CastR(target, "combo", godBuffTimeCombo, pingLatency, noKillBuffTimeCombo, RDamage, totalHP, CCTime, target)
				table.remove(debugList, #debugList)
				break
			end
			table.remove(debugList, #debugList)
			::continue::
		end
		table.insert(debugList, "ComboEOnMinion")
		if not hasCasted and self.BrandMenu.combo.use_e:get() and player:spellSlot(SpellSlot.E).state == 0 then
			local priority = nil
			local chosenChamp = nil
			local chosenMinion = nil
			local distanceChamp = nil
				for _, minion in pairs(objManager.aiBases.list) do
					local validTarget =  minion and minion.isValid and minion.name ~= "Barrel" and minion.name ~= "GameObject" and (minion.isMinion or minion.isPet or minion.isHero) and not minion.isPlant and minion.pos and minion:isValidTarget(660, true, player.pos) and minion.isTargetable
					if not validTarget then goto continue4 end
					for index, target in pairs(ts.getTargets()) do
						local validTarget =  target and target:isValidTarget(600, true, minion.pos) and target.isTargetable and minion.handle ~= target.handle
						if not validTarget then goto continue5 end
						local BrandABlaze = minion.asAIBase.asAIBase:findBuff("BrandAblaze")
						local totalRange = (BrandABlaze and BrandABlaze.remainingTime >= 0.25 + game.latency/1000) and 600 or 300
						local minionAI = minion.asAIBase
						if minion.pos:distance2D(target.pos) <= totalRange and (minionAI.path and pred.positionAfterTime(minionAI, 0.25 + game.latency/1000) or minionAI.pos):distance2D(target.path and pred.positionAfterTime(target, 0.25 + game.latency/1000) or target.pos) <= totalRange then
							local distanceToChamp = minion.pos:distance2D(target.pos)
							if not priority or not distanceChamp or index < priority or (index == priority and distanceChamp > distanceToChamp) then
								distanceChamp = distanceToChamp
								priority = index
								chosenChamp = target
								chosenMinion = minion
							end
						end
						::continue5::
					end
					::continue4::
				end
			if priority and chosenChamp and chosenMinion then
				self:CastE(chosenMinion,"combo minion", self:godBuffTime(chosenChamp), game.latency/1000, self:noKillBuffTime(chosenChamp), self:GetDamageE(chosenChamp, 0), (chosenChamp.health + chosenChamp.allShield + chosenChamp.magicalShield), pred.getCrowdControlledTime(chosenChamp), chosenChamp)
			end
		end
		table.remove(debugList, #debugList)
		table.insert(debugList, "ComboROnMinion")
		if not hasCasted and self.BrandMenu.combo.use_r:get() and self.BrandMenu.combo.use_r_minion:get() and self.BrandMenu.combo.r_bounces:get() > 0 and player:spellSlot(SpellSlot.R).state == 0 then
			local priority = nil
			local chosenChamp = nil
			local chosenMinion = nil
			local rTotalDamage = nil
			local distanceChamp = nil
			for _, minion in pairs(objManager.aiBases.list) do
				local validTarget =  minion and minion.isValid and minion.name ~= "Barrel" and minion.name ~= "GameObject" and (minion.isMinion or minion.isPet or minion.isHero) and not minion.isPlant and minion:isValidTarget(600, true, player.pos) and minion.isTargetable and not target.isInvulnerable
				if not validTarget then goto continue6 end
				for index, target in pairs(ts.getTargets()) do
					local validTarget =  target and target:isValidTarget(600, true, minion.pos) and target.isTargetable and minion.handle ~= target.handle
					if not validTarget then goto continue7 end
					minionAI = minion.asAIBase
					if (minionAI.path and pred.positionAfterTime(minionAI, 0.6 + game.latency/1000) or minionAI.pos):distance2D(target.path and pred.positionAfterTime(target, 0.6 + game.latency/1000) or target.pos) <= 600 then
						local rDamage = 0
						local shotsToKill = 0
						local isFirstShot = true
						local minionAI = minion.asAIBase
						local totalHP = (target.health + target.allShield + target.magicalShield)
						for i = 2 - 1, 0, -1 do
							local calculatedRDamage = self:GetDamageR(target, 0, i, totalHP - rDamage, isFirstShot, shotsToKill + 1)
							local calculatedRMaxDamage = self:GetDamageR(target, 0, 0, totalHP - rDamage, isFirstShot, shotsToKill + 1)
							if ((totalHP) - (rDamage + calculatedRMaxDamage))/target.maxHealth < (ElderBuff and 0.2 or 0) then
								rDamage = rDamage + calculatedRMaxDamage
								shotsToKill = shotsToKill + 1
								break
							end
							rDamage = rDamage + calculatedRDamage
							shotsToKill = shotsToKill + 1
							isFirstShot = false
						end
						if ((totalHP) - rDamage)/target.maxHealth < 0.2 and ElderBuff then
							rDamage = totalHP
						end
						if (not self.BrandMenu.combo.r_logic:get() or pred.positionAfterTime(target, 0.1 + pingLatency):distance2D(player.pos) > 750 or target.pos:distance2D(player.pos) > 750) and rDamage >= totalHP and shotsToKill <= self.BrandMenu.combo.r_bounces:get() then
							local distanceToChamp = minion.pos:distance2D(target.pos)
							if not priority or not distanceChamp or index < priority or (index == priority and distanceChamp > distanceToChamp) then
								distanceChamp = distanceToChamp
								priority = index
								chosenChamp = target
								chosenMinion = minion
								rTotalDamage = rDamage
							end
						end
					end
					::continue7::
				end
				::continue6::
			end
			if priority and chosenChamp and chosenMinion and rTotalDamage then
				self:CastR(chosenMinion, "combo minion", self:godBuffTime(chosenChamp), game.latency/1000, self:noKillBuffTime(chosenChamp), rTotalDamage, (chosenChamp.health + chosenChamp.allShield + chosenChamp.magicalShield), pred.getCrowdControlledTime(chosenChamp), chosenChamp)
			end
		end
		table.remove(debugList, #debugList)
		table.remove(debugList, #debugList)
    end

    function Brand:Harass()
		if hasCasted then return end
		
        if orb.harassKeyDown == false then return end
		
		table.insert(debugList, "Harass")
		for index, target in pairs(ts.getTargets()) do
			local validTarget =  target and not target.isZombie and (target:isValidTarget(1100, true, player.pos) or self:invisibleValid(target, 1100)) and target.isTargetable and not target.isInvulnerable
			if not validTarget then goto continue end
			
			table.insert(debugList, "HarassCalcs")
			local CanUseQ = self.BrandMenu.harass.use_q:get() and player:spellSlot(SpellSlot.Q).state == 0
			local CanUseW = self.BrandMenu.harass.use_w:get() and player:spellSlot(SpellSlot.W).state == 0 and (target.path and pred.positionAfterTime(target, 0.625 + game.latency/1000):distance2D(player.pos) <= 900 or target.pos:distance2D(player.pos) <= 900)
			local CanUseE = self.BrandMenu.harass.use_e:get() and player:spellSlot(SpellSlot.E).state == 0 and target.pos:distance2D(player.pos) <= 660 and target.isVisible
			if self.BrandMenu.harass.use_e:get() and player:spellSlot(SpellSlot.E).state == 0 then orb.setAttackPause(0.075) end
			table.remove(debugList, #debugList)
			if not CanUseQ and not CanUseW and not CanUseE then goto continue end
			
			table.insert(debugList, "HarassCalcs2")
			local CCTime = pred.getCrowdControlledTime(target)
			local dashing = target.path and target.path.isDashing
			local godBuffTimeCombo = self:godBuffTime(target)
			local pingLatency = game.latency/1000
			local noKillBuffTimeCombo = self:noKillBuffTime(target)
			local QDamage = self:GetDamageQ(target, 0)
			local EDamage = self:GetDamageE(target, 0)
			local WDamage = self:GetDamageW2(target, 0)
			local RDamage = self:GetDamageR(target, 0, 0, target.health, true, 1)
			local totalHP = (target.health + target.allShield + target.magicalShield)
			local channelingSpell = (target.isCastingInterruptibleSpell and target.isCastingInterruptibleSpell > 0) or (target.activeSpell and target.activeSpell.hash == 692142347)
			local QLandingTime = ((player.pos:distance2D(target.pos) - (player.boundingRadius + target.boundingRadius)) / self.qData.speed + self.qData.delay)
			-- local canBeStunned = not target.isUnstoppable and not target:getBuff("MorganaE") and not target:getBuff("bansheesveil") and not target:getBuff("itemmagekillerveil") and not target:getBuff("malzaharpassiveshield")
			table.remove(debugList, #debugList)
			
			table.insert(debugList, "HarassE")
			if CanUseE and orb.predictHP(target, 0.2 + pingLatency) > 0 and godBuffTimeCombo <= 0.5 + pingLatency and (noKillBuffTimeCombo <= 0.5 + game.latency/1000 or not ((((totalHP) - EDamage)/target.maxHealth) < (ElderBuff and 0.2 or 0))) then
				self:CastE(target,"harass", godBuffTimeCombo, pingLatency, noKillBuffTimeCombo, EDamage, totalHP, CCTime, realTarget)
				table.remove(debugList, #debugList)
				break
			end
			table.remove(debugList, #debugList)
			table.insert(debugList, "HarassQ")
			if CanUseQ and orb.predictHP(target, 0.2 + pingLatency) > 0 and godBuffTimeCombo <= 0.2 + pingLatency and (noKillBuffTimeCombo <= 0.2 + pingLatency or not ((((totalHP) - QDamage)/target.maxHealth) < (ElderBuff and 0.2 or 0))) then
				if self:CastQ(target,"harass", godBuffTimeCombo, pingLatency, noKillBuffTimeCombo, QDamage, totalHP, chargingQ, CCTime) > 0 then table.remove(debugList, #debugList) break end
			end
			table.remove(debugList, #debugList)
			table.insert(debugList, "HarassW")
			if CanUseW and orb.predictHP(target, 0.7 + pingLatency) > 0 and godBuffTimeCombo <= 1 + pingLatency and (noKillBuffTimeCombo <= 1 + game.latency/1000 or not ((((totalHP) - WDamage)/target.maxHealth) < (ElderBuff and 0.2 or 0))) then
				if self:CastW(target,"harass", godBuffTimeCombo, pingLatency, noKillBuffTimeCombo, WDamage, totalHP, CCTime) > 0 then table.remove(debugList, #debugList) break end
			end
			table.remove(debugList, #debugList)
			::continue::
		end
		table.insert(debugList, "HarassEOnMinion")
		if not hasCasted and self.BrandMenu.harass.use_e:get() and player:spellSlot(SpellSlot.E).state == 0 then
			local priority = nil
			local chosenChamp = nil
			local chosenMinion = nil
			local distanceChamp = nil
				for _, minion in pairs(objManager.aiBases.list) do
					local validTarget =  minion and minion.isValid and minion.name ~= "Barrel" and minion.name ~= "GameObject" and (minion.isMinion or minion.isPet or minion.isHero) and not minion.isPlant and minion.pos and minion:isValidTarget(660, true, player.pos) and minion.isTargetable
					if not validTarget then goto continue4 end
					for index, target in pairs(ts.getTargets()) do
						local validTarget =  target and target:isValidTarget(600, true, minion.pos) and target.isTargetable and minion.handle ~= target.handle
						if not validTarget then goto continue5 end
						local BrandABlaze = minion.asAIBase.asAIBase:findBuff("BrandAblaze")
						local totalRange = (BrandABlaze and BrandABlaze.remainingTime >= 0.25 + game.latency/1000) and 600 or 300
						local minionAI = minion.asAIBase
						if minion.pos:distance2D(target.pos) <= totalRange and (minionAI.path and pred.positionAfterTime(minionAI, 0.25 + game.latency/1000) or minionAI.pos):distance2D(target.path and pred.positionAfterTime(target, 0.25 + game.latency/1000) or target.pos) <= totalRange then
							local distanceToChamp = minion.pos:distance2D(target.pos)
							if not priority or not distanceChamp or index < priority or (index == priority and distanceChamp > distanceToChamp) then
								distanceChamp = distanceToChamp
								priority = index
								chosenChamp = target
								chosenMinion = minion
							end
						end
						::continue5::
					end
					::continue4::
				end
			if priority and chosenChamp and chosenMinion then
				self:CastE(chosenMinion,"harass minion", self:godBuffTime(chosenChamp), game.latency/1000, self:noKillBuffTime(chosenChamp), self:GetDamageE(chosenChamp, 0), (chosenChamp.health + chosenChamp.allShield + chosenChamp.magicalShield), pred.getCrowdControlledTime(chosenChamp), chosenChamp)
			end
		end
		table.remove(debugList, #debugList)
		table.remove(debugList, #debugList)
    end

    -- This function will cast Q on the target, the mode attribute is used to check if its enabled in the menu based on mode, as we created the menu similar for combo and harass.
	
    function Brand:CastQ(target, mode, godBuffTime, pingLatency, noKillBuffTime, GetDamageQ, totalHP, stunTime)
		if hasCasted then return 0 end
		if not totalHP then totalHP = 0 end
		if godBuffTime <= 0.2 + pingLatency and (noKillBuffTime <= 0.2 + pingLatency or not ((((totalHP) - GetDamageQ)/target.maxHealth) < (ElderBuff and 0.2 or 0))) then
			p = pred.getPrediction(target, self.qData)
			local WTime = self:WillGetHitByW(target)
			local AblazeBuff = target.asAIBase:findBuff("BrandAblaze")
			local hitChanceMode = (mode == "dash" or mode == "stun" or mode == "casting") and 6 or ((target.characterIntermediate.moveSpeed > 0 and (mode == "combo" or mode == "harass")) and HitchanceMenu[self.BrandMenu.prediction.q_hitchance:get()] or 1)
			if p and p.castPosition.isValid and player.pos:distance2D(p.castPosition) <= self.qData.range and p.hitChance >= hitChanceMode and ((WTime and WTime < p.timeToTarget-0.2+pingLatency) or (AblazeBuff and AblazeBuff.remainingTime >= p.timeToTarget+pingLatency) or ((((totalHP) - GetDamageQ)/target.maxHealth) < (ElderBuff and 0.2 or 0))) then
				player:castSpell(SpellSlot.Q, p.castPosition, true, false)
				hasCasted = true
				self:DebugPrint("Casted Q on " .. mode)
			else
				return 0
			end
		end
		return p and p.hitChance or 0
	end
	
    -- This function will cast W on the target, the mode attribute is used to check if its enabled in the menu based on mode, as we created the menu similar for combo and harass.
    function Brand:CastW(target, mode, godBuffTime, pingLatency, noKillBuffTime, GetDamageW, totalHP, stunTime)
		if hasCasted then return 0 end
		if not totalHP then totalHP = 0 end
		local p = pred.getPrediction(target, self.wData)
		local hitChanceMode = (mode == "dash" or mode == "stun" or mode == "casting") and 6 or ((target.characterIntermediate.moveSpeed > 0 and (mode == "combo" or mode == "harass")) and HitchanceMenu[self.BrandMenu.prediction.w_hitchance:get()] or 1)
		if godBuffTime <= 0.7 + pingLatency and (noKillBuffTime <= 0.7 + pingLatency or not ((((totalHP) - GetDamageW)/target.maxHealth) < (ElderBuff and 0.2 or 0))) and p and p.castPosition.isValid and player.pos:distance2D(p.castPosition) <= self.wData.range and p.hitChance >= hitChanceMode then
			player:castSpell(SpellSlot.W, p.castPosition, true, false)
			hasCasted = true
			self:DebugPrint("Casted W on " .. mode)
		end
		return p and p.hitChance or 0
    end
	
    function Brand:CastE(target, mode, godBuffTime, pingLatency, noKillBuffTime, GetDamageE, totalHP, stunTime, realTarget)
		if hasCasted then return end
		if not totalHP then totalHP = 0 end
		if godBuffTime <= 0.2 + pingLatency and (noKillBuffTime <= 0.2 + pingLatency or not ((((totalHP) - GetDamageE)/realTarget.maxHealth) < (ElderBuff and 0.2 or 0))) then
			player:castSpell(SpellSlot.E, target, true, false)
			hasCasted = true
			self:DebugPrint("Casted E on " .. mode)
		end
	end

    function Brand:CastR(target, mode, godBuffTime, pingLatency, noKillBuffTime, GetDamageR, totalHP, stunTime, realTarget)
		if hasCasted then return 0 end
		if not totalHP then totalHP = 0 end
		p = pred.getPrediction(target.asAIBase, self.rData)
		if godBuffTime <= 0.2 + pingLatency and (noKillBuffTime <= 0.2 + pingLatency or not ((((totalHP) - GetDamageR)/realTarget.maxHealth) < (ElderBuff and 0.2 or 0))) and p and p.castPosition.isValid and p.hitChance >= 1 then
			player:castSpell(SpellSlot.R, target, true, false)
			hasCasted = true
			self:DebugPrint("Casted R on " .. mode)
		end
		return p and p.hitChance or 0
    end

    -- This function will be called every time the player draws a screen (based on FPS)
    -- This is where all drawing code will be executed
    function Brand:OnDraw()
		self:debugFlush()
		table.insert(debugList, "Draw")
		table.insert(debugList, "Draw1")
        -- Check if the menu option is enabled to draw the Q range
        if self.BrandMenu.drawings.draw_q_range:get() then
            local alpha = player:spellSlot(SpellSlot.Q).state == 0 and 255 or 50
            graphics.drawCircle(player.pos, self.qData.range, 2, graphics.argb(alpha, 204, 127, 0))
        end
        -- Check if the menu option is enabled to draw the W range
        if self.BrandMenu.drawings.draw_w_range:get() then
            -- If its just 1 line like previous one to check if spell is ready, we can use this code aswell
            -- It has the same effect if checks if the spell is ready, if it is it sets the value to 255, if not it sets it to 50
            local alpha = player:spellSlot(SpellSlot.W).state == 0 and 255 or 50
            graphics.drawCircle(player.pos, self.wData.range, 2, graphics.argb(alpha, 0, 255, 255))
        end
        if self.BrandMenu.drawings.draw_e_range:get() then
            local alpha = player:spellSlot(SpellSlot.E).state == 0 and 255 or 50
            graphics.drawCircle(player.pos, 660, 2, graphics.argb(alpha, 0, 127, 255))
        end
        if self.BrandMenu.drawings.draw_r_range:get() then
            local alpha = player:spellSlot(SpellSlot.R).state == 0 and 255 or 50
            graphics.drawCircle(player.pos, 750, 2, graphics.argb(alpha, 255, 127, 0))
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
			graphics.drawText2D("Killable -> " .. value.shots .. (value.shots > 1 and " bounces" or " bounce"), 24, pos, graphics.argb(255,255, 0, 0))
			::skipKillable::
		end
		for key,value in ipairs(drawRValue) do
			if not value.unit.isValid or not value.unit.isHealthBarVisible or value.unit.isDead then goto skipDrawValue end
			pos = vec2(value.unit.healthBarPosition.x + 70, value.unit.healthBarPosition.y - 30)
			graphics.drawText2D(value.text, 24, pos, graphics.argb(255, value.red, 255-value.red, 255-value.red))
			::skipDrawValue::
		end
		for key,value in ipairs(drawETargets) do
			if not value.unit.isValid or not value.unit.isHealthBarVisible or value.unit.isDead then goto skipEDraw end
			graphics.drawCircle(value.unit.pos, value.totalERange, 2, graphics.argb(160, 0, 127, 255))
			::skipEDraw::
		end
		table.remove(debugList, #debugList)
		table.insert(debugList, "Draw2")
		if self.BrandMenu.drawings.draw_debug_w:get() then
			for key,value in ipairs(particleWList) do
				graphics.drawCircle(value.obj.pos, self.wData.radius, 3, graphics.argb(255, 255, 127, 0))
			end
		end
		table.remove(debugList, #debugList)
		table.remove(debugList, #debugList)
    end

    -- This function will be called every time someone did cast a spell.
    function Brand:OnCastSpell(source, spell)
		self:debugFlush()
        -- Compare the handler of the source to our player 
        if source.handle == player.handle then
			table.insert(debugList, "CastSpell")
            -- Store the time when the spell was casted, which will be used inside Annie:IsCasting()
			if spell.slot + 1 <= 4 then
				self.castTimeClock[spell.slot + 1] = game.time + self.castTime[spell.slot + 1]
				self:DebugPrint("Casting spell: " .. spell.name)
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
	
    function Brand:OnBasicAttack(source, spell)
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
    function Brand:IsCasting()
        -- Get current time
        local time = game.time
        -- loop through all the spells
        for index, value in ipairs(self.castTimeClock) do
		-- Logic so casting is considered as finished for the server, your ping
                if time - value < -game.latency/1000 then
                    return true
                end
        end
        return false
    end

    -- Call the initialization function
    Brand:__init()

end)

-- This callback is called when the script gets unloaded.
cb.add(cb.unload, function()
    -- We delete the menu for our script, with the same name as we created it.
    menu.delete('open_Brand')
end)
