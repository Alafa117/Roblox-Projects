--[[
	Module: LightAttack
	Type: Combat Mechanic Module (Server)
	Location: ServerScriptService.CombatHandler.Mechanics.LightAttack
	Path: src/server/CombatHandler/Mechanics/LightAttack.luau
	
	Description:
		Implements the Light Attack (M1) combat mechanic.
		Handles hitbox detection, damage calculation, combo multipliers.
		Server-authoritative with range validation and anti-exploit checks.
		Applies knockback and stun effects to hit targets.
		Inherits from BaseAttack for common functionality.
	
	Phase 4 Refactoring:
		- Moved from shared/ to server/ (correct architecture)
		- Updated imports to reflect server-only location
	
Reorganized: December 23, 2025 - Moved to Mechanics/ subfolder
	
	Dependencies:
		- ReplicatedStorage.CombatCore (Config, Enums, Types, Logger, ValidationHelper)
		- CombatHandler.Mechanics (BaseAttack)
		- CombatHandler.Helpers (AttackHelper)
		- CombatHandler.Physics (RagdollManager)
	
	Author: Professional Roblox Scripter
	Created: December 11, 2025
	Relocated: December 17, 2025
--]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

-- Module Imports
local CombatSystem = ReplicatedStorage:WaitForChild("CombatCore")

local Config = require(CombatSystem.Config.Config)
local Enums = require(CombatSystem.Data.Enums)
local Types = require(CombatSystem.Data.Types)
local Logger = require(CombatSystem.Logging.Logger).GetInstance()
local ValidationHelper = require(CombatSystem.Validation.ValidationHelper)
local TypeValidators = require(CombatSystem.Validation.TypeValidators)
local SpatialHelper = require(CombatSystem.Helpers.SpatialHelper)

-- Server-side modules
local CombatHandler = ServerScriptService:WaitForChild("CombatHandler")
local ServerMechanics = CombatHandler:WaitForChild("Mechanics")
local BaseAttack = require(ServerMechanics.BaseAttack)
local AttackHelper = require(CombatHandler.Helpers.AttackHelper)
local RagdollManager = require(CombatHandler.Physics.RagdollManager).GetInstance()

-- Movement mechanics for cancellation
local Dash = require(CombatSystem.Movement.Dash)
local Slide = require(CombatSystem.Movement.Slide)

-- Light Attack Module
local LightAttack = setmetatable({}, BaseAttack)
LightAttack.__index = LightAttack

-- ========================================
-- CONSTANTS
-- ========================================

local HITBOX_FORWARD_OFFSET = 3  -- Studs in front of player
local HITBOX_MAX_ANGLE = 120     -- Degrees

-- ========================================
-- EXECUTE METHOD
-- ========================================

function LightAttack:Execute(player: Player, data: {[string]: any})
	Logger:MechanicExecute("LightAttack", player.Name, "Combo: " .. tostring(data.ComboCount or 1))
	
	-- Validate execution (Phase 2: uses base class)
	if not self:_ValidateExecution(player, "LightAttack") then
		return
	end
	
	-- Cancel active movement mechanics (Dash/Slide)
	Dash:CancelDash(player)
	Slide:CancelSlide(player)
	
	local comboCount = data.ComboCount or 1
	
	-- Get attack parameters
	local attackData = self:_GetAttackData(player, comboCount)
	
	-- Perform hitbox detection (Phase 2: uses base class)
	local hitPlayers = self:_DetectHits(attackData, HITBOX_FORWARD_OFFSET, HITBOX_MAX_ANGLE)
	Logger:MechanicHitDetection("LightAttack", #hitPlayers)
	
	-- Apply damage to hit players
	for _, victim in ipairs(hitPlayers) do
		local victimName = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Name else victim.Name
		Logger:MechanicDamageApplied("LightAttack", victimName, attackData.Damage)
		self:_ApplyDamage(attackData, victim, comboCount)
	end
	
	-- Broadcast to clients for VFX (Phase 2: uses base class)
	Logger:MechanicVFXBroadcast("LightAttack")
	self:_BroadcastAttackToClients(player, "LightAttack", hitPlayers, "HitSpark", comboCount)
end

-- ========================================
-- ATTACK DATA GENERATION
-- ========================================

function LightAttack:_GetAttackData(player: Player, comboCount: number): Types.AttackData
	-- Get character (support both Players and Test Rigs/NPCs)
	local character = if typeof(player) == "Instance" and player:IsA("Player") then player.Character else player
	local humanoid, _rootPart = ValidationHelper.GetCharacterComponents(character)
	
	-- Combo multipliers
	local damageMultiplier = 1 + (comboCount - 1) * 0.1 -- +10% per combo
	local knockbackMultiplier
	
	-- Special finisher on 6th combo
	if comboCount == 6 then
		knockbackMultiplier = Config.LightAttack.FinisherKnockback / Config.LightAttack.Knockback
	else
		knockbackMultiplier = 1 + (comboCount - 1) * 0.15 -- +15% per combo
	end
	
	local attackData: Types.AttackData = {
		Attacker = player,
		Victim = nil,
		AttackType = Enums.AttackType.LightAttack,
		Damage = Config.LightAttack.Damage * damageMultiplier,
		Knockback = Config.LightAttack.Knockback * knockbackMultiplier,
		Range = Config.LightAttack.Range,
		HitboxSize = Config.LightAttack.HitboxSize,
		ComboCount = comboCount,
		Timestamp = os.clock(),
	}
	
	-- ✅ Validate AttackData structure
	TypeValidators.Assert(
		TypeValidators.AttackData,
		attackData,
		"LightAttack AttackData"
	)
	
	return attackData
end

-- ========================================
-- DAMAGE APPLICATION
-- ========================================

function LightAttack:_ApplyDamage(attackData: Types.AttackData, victim: Player | Model, comboCount: number)
	-- Apply damage through base class (Phase 2: cached service reference)
	local hitData = self:_ApplyDamageToVictim(attackData, victim)
	
	if not hitData then
		return
	end
	
	-- FIXED: Apply stun only for hits 1-5, NOT for hit 6 (December 27, 2025)
	-- Hit 6 needs knockback+ragdoll to work, stun would freeze the victim
	if comboCount < 6 then
		self:_ApplyStunToVictim(victim, Config.LightAttack.StunDuration)
	end
	
	-- Apply knockback on ALL hits (small knockback on 1-5, ragdoll on 6th)
	if comboCount == 6 then
		local victimChar = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Character else victim
		
		-- Directional block break validation (December 25, 2025)
		-- If blocking, check attack direction to determine behavior
		if victimChar and (hitData.HitResult == Enums.HitResult.Blocked or hitData.HitResult == Enums.HitResult.PerfectBlock) then
			local attacker = attackData.Attacker
			local attackerChar = if typeof(attacker) == "Instance" and attacker:IsA("Player") then attacker.Character else attacker
			
			if attackerChar then
				-- Check if attack is from front or back
				local isFromFront = SpatialHelper.IsInFront(victimChar, attackerChar, 120)
				
				if not isFromFront then
					-- FIXED: Back attack while blocking (December 27, 2025)
					-- Disable block and continue to apply knockback+ragdoll below
					if typeof(victim) == "Instance" and victim:IsA("Player") then
						local PlayerDataManager = require(CombatHandler.Core.PlayerDataManager).GetInstance()
						PlayerDataManager:SetBlocking(victim, false)
						Logger:Debug("Block disabled by back attack (M1 finisher) - applying knockback+ragdoll", {
							victim = victim.Name,
							noStun = true
						})
					end
					-- Don't return - continue to knockback+ragdoll below
				else
					-- Front attack while blocking: apply stun (block break)
					if typeof(victim) == "Instance" and victim:IsA("Player") then
						local PlayerDataManager = require(CombatHandler.Core.PlayerDataManager).GetInstance()
						
						-- FIXED: Set block break cooldown to prevent spam-blocking (December 28, 2025)
						-- Bug 3: Spamming Block during hit evades block break
						-- Player cannot reactivate block for BlockBreakStunDuration
						local victimData = PlayerDataManager:GetPlayerData(victim)
						if victimData then
							victimData.BlockBreakCooldown = os.clock() + Config.Block.BlockBreakStunDuration
						end
						
						self:_ApplyStunToVictim(victim, Config.Block.BlockBreakStunDuration)
						
						-- Add visual outline for block break (red) - December 26, 2025
						if victim.Character then
							local highlight = Instance.new("Highlight")
							highlight.Name = "BlockBreakHighlight"
							highlight.FillColor = Color3.fromRGB(255, 50, 50) -- Red
							highlight.OutlineColor = Color3.fromRGB(200, 0, 0)
							highlight.FillTransparency = 0.6
							highlight.OutlineTransparency = 0
							highlight.Parent = victim.Character
							
							-- Remove highlight after stun duration
							task.delay(Config.Block.BlockBreakStunDuration, function()
								if highlight and highlight.Parent then
									highlight:Destroy()
								end
							end)
						end
						
						Logger:Debug("Block broken by M1 finisher", {
							victim = victim.Name,
							stunDuration = Config.Block.BlockBreakStunDuration
						})
					end
					return -- Exit early, stun applied, no ragdoll
				end
			end
		end
		
		-- Apply ragdoll with knockback if:
		-- 1) NOT blocking at all, OR
		-- 2) Blocking BUT attacked from back (block was disabled above)
		if victimChar and hitData.HitResult ~= Enums.HitResult.PerfectBlock then
			-- Calculate knockback direction
			local attacker = attackData.Attacker
			local attackerChar = if typeof(attacker) == "Instance" and attacker:IsA("Player") then attacker.Character else attacker
			
			if attackerChar then
				local SpatialHelper = require(CombatSystem.Helpers.SpatialHelper)
				local direction = SpatialHelper.GetDirectionTo(attackerChar, victimChar)
				
				if direction then
					-- Apply ragdoll WITH integrated knockback physics
					RagdollManager:ApplyRagdoll(
						victimChar, 
						Config.LightAttack.FinisherRagdollDuration,
						direction, -- Knockback direction
						Config.LightAttack.FinisherKnockback -- Knockback force
					)
					
					Logger:Debug("Combo finisher applied", {
						victim = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Name else victimChar.Name,
						knockback = Config.LightAttack.FinisherKnockback,
						ragdollDuration = Config.LightAttack.FinisherRagdollDuration
					})
				end
			end
		end
	else
		-- Small knockback on hits 1-5 (only if NOT blocking)
		if hitData.HitResult ~= Enums.HitResult.Blocked and hitData.HitResult ~= Enums.HitResult.PerfectBlock then
			local victimChar = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Character else victim
			if victimChar then
				local attacker = attackData.Attacker
				local attackerChar = if typeof(attacker) == "Instance" and attacker:IsA("Player") then attacker.Character else attacker
				
				if attackerChar then
					local SpatialHelper = require(CombatSystem.Helpers.SpatialHelper)
					local direction = SpatialHelper.GetDirectionTo(attackerChar, victimChar)
					
					if direction then
						-- Small knockback (8 studs base force as configured in Config)
						local knockbackMultiplier = 1 + (comboCount - 1) * 0.15  -- +15% per combo
						self:_ApplyKnockbackToVictim(attackData, victim, knockbackMultiplier, 0)
						
						Logger:Debug("M1 knockback applied", {
							victim = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Name else victimChar.Name,
							combo = comboCount,
							knockback = Config.LightAttack.Knockback * knockbackMultiplier
						})
					end
				end
			end
		end
	end
end

return LightAttack

