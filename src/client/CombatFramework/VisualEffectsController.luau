--[[
	Module: VisualEffectsController
	Type: Client Visual Effects Module
	Location: StarterPlayer.StarterPlayerScripts.CombatFramework.VisualEffectsController
	Path: src/client/CombatFramework/VisualEffectsController.luau
	
	Description:
		Manages visual effects for combat actions (highlights, particles, etc.).
		Separates VFX logic from core combat controller for better modularity.
		Handles creation, cleanup, and timing of visual feedback.
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Core.Config
	
	Author: Professional Roblox Scripter
	Created: December 13, 2025
--]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module Imports
local CombatSystem = ReplicatedStorage:WaitForChild("CombatCore")
local Core = CombatSystem:WaitForChild("Core")
local Config = require(Core.Config)

-- Constants
local LocalPlayer = Players.LocalPlayer

-- Visual Effects Controller Class
local VisualEffectsController = {}
VisualEffectsController.__index = VisualEffectsController

-- ========================================
-- TYPES
-- ========================================

type VisualEffectsController = {
	_activeEffects: {[string]: Instance},
}

-- ========================================
-- CONSTRUCTOR
-- ========================================

function VisualEffectsController.new(): VisualEffectsController
	local self = setmetatable({}, VisualEffectsController)
	
	self._activeEffects = {}
	
	return self
end

-- ========================================
-- STRONG ATTACK (M2) EFFECTS
-- ========================================

function VisualEffectsController:ApplyStrongAttackEffect()
	local character = LocalPlayer.Character
	if not character then return end
	
	-- Remove existing effect if any
	self:RemoveEffect("M2Charge")
	
	-- Create Highlight effect (red body + white outline)
	local highlight = Instance.new("Highlight")
	highlight.Name = "M2ChargeEffect"
	highlight.FillColor = Color3.fromRGB(255, 50, 50) -- Red body
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255) -- White outline
	highlight.FillTransparency = 0.3 -- Slightly transparent red
	highlight.OutlineTransparency = 0 -- Solid white outline
	highlight.Adornee = character
	highlight.Parent = character
	
	-- Store reference
	self._activeEffects["M2Charge"] = highlight
	
	-- Auto-remove after M2 duration
	task.delay(Config.StrongAttack.StunDuration + 0.3, function()
		self:RemoveEffect("M2Charge")
	end)
end

-- ========================================
-- HIT EFFECTS
-- ========================================

function VisualEffectsController:PlayHitEffect(character: Model)
	if not character then return end
	
	-- Flash white briefly
	local highlight = Instance.new("Highlight")
	highlight.Name = "HitFlash"
	highlight.FillColor = Color3.fromRGB(255, 255, 255)
	highlight.OutlineColor = Color3.fromRGB(255, 200, 200)
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0.3
	highlight.Adornee = character
	highlight.Parent = character
	
	-- Remove after brief flash
	task.delay(0.15, function()
		if highlight and highlight.Parent then
			highlight:Destroy()
		end
	end)
end

-- ========================================
-- EFFECT MANAGEMENT
-- ========================================

function VisualEffectsController:RemoveEffect(effectName: string)
	local effect = self._activeEffects[effectName]
	if effect then
		-- Find by name as backup if reference lost
		local character = LocalPlayer.Character
		if character then
			local existingEffect = character:FindFirstChild(effectName .. "Effect")
			if existingEffect then
				existingEffect:Destroy()
			end
		end
		
		-- Destroy stored reference
		if effect.Parent then
			effect:Destroy()
		end
		
		self._activeEffects[effectName] = nil
	end
end

function VisualEffectsController:ClearAllEffects()
	for _, effect in pairs(self._activeEffects) do
		if effect and effect.Parent then
			effect:Destroy()
		end
	end
	table.clear(self._activeEffects)
end

-- ========================================
-- CLEANUP
-- ========================================

function VisualEffectsController:Destroy()
	self:ClearAllEffects()
end

return VisualEffectsController
