--[[
	Script: SimpleNPCAI (Stationary Training Dummies)
	Type: Server Script
	Location: ServerScriptService.Testing
	
	Description:
		STATIONARY training dummies for Combat System testing.
		NPCs do NOT move, chase, or attack the player.
		They are TEST DUMMIES that only maintain their assigned state.
		YOU attack THEM for testing purposes.
		
	Features:
		- Stationary position (no movement)
		- Rotation towards player (visual only)
		- Specific state per NPC based on name
		- Block NPCs maintain blocking stance
		- R6 Avatar support only
		- NO ATTACKS - NPCs don't damage the player
		
	NPC Naming Convention (for Testing):
		Name your NPCs to assign specific TEST BEHAVIOR:
		- "Dummy_Block" or "Shield" or "Defend" → Constantly blocking (test block breaking, damage reduction)
		- "Dummy_M1" or "Light" → Stationary dummy (test M1 combos)
		- "Dummy_M2" or "Strong" or "Heavy" → Stationary dummy (test M2 heavy attacks)
		- Any other name → Stationary dummy (general testing)
		
		⚠️ IMPORTANT: NPCs named "Dash" or "Slide" will also be stationary dummies
		
		Examples:
		- "Dummy_Block" → Blocks constantly (test YOUR attacks on blocking target)
		- "Dummy_M1" → Stands still (test YOUR M1 combos)
		- "Dummy_M2" → Stands still (test YOUR M2 knockback)
		
	Setup:
		1. Create "NPCs" folder in Workspace
		2. Insert R6 Rigs (NOT R15!)
		3. Name them: Dummy_M1, Dummy_M2, Dummy_Block
		4. Run game - they stay in place
		5. YOU attack THEM
		
	Author: Professional Roblox Scripter
	Created: December 14, 2025
	Updated: December 14, 2025 - Converted to stationary training dummies
--]]

-- Services
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Wait for Combat System
task.wait(2)

-- Get NPCCombatHelper from Testing folder (same location as this script)
local Testing = ServerScriptService:WaitForChild("Testing")
local NPCCombatHelper = require(Testing:WaitForChild("NPCCombatHelper"))

-- ========================================
-- CONFIGURATION
-- ========================================

local CONFIG = {
	-- Distance to detect players
	DetectionRange = 25,
	
	-- Distance to attack
	AttackRange = 10,
	
	-- Time between actions (seconds)
	ActionCooldown = 1.5,
	
	-- Probability of each action (must sum to 100)
	ActionWeights = {
		LightAttack = 50,  -- 50% M1
		StrongAttack = 30, -- 30% M2
		Dash = 20,         -- 20% Dash
	},
	
	-- Folder where NPCs are located in Workspace
	NPCFolder = "NPCs",
}

-- ========================================
-- NPC DATA TRACKING
-- ========================================

local npcData = {}

type NPCData = {
	Model: Model,
	Humanoid: Humanoid,
	RootPart: BasePart,
	LastAction: number,
	CurrentTarget: Player?,
	IsActive: boolean,
	AssignedAction: string, -- Specific action for this NPC
	IsBlocking: boolean, -- Whether NPC is currently blocking
}

-- ========================================
-- UTILITY FUNCTIONS
-- ========================================

local function IsR6Avatar(model: Model): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false end
	
	-- R6 has 6 parts: Head, Torso, Left Arm, Right Arm, Left Leg, Right Leg
	local hasR6Parts = model:FindFirstChild("Torso") 
		and model:FindFirstChild("Left Arm") 
		and model:FindFirstChild("Right Arm")
		and model:FindFirstChild("Left Leg")
		and model:FindFirstChild("Right Leg")
	
	return hasR6Parts ~= nil
end

local function GetClosestPlayer(npcPosition: Vector3): (Player?, number)
	local closestPlayer = nil
	local closestDistance = math.huge
	
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			local humanoid = player.Character:FindFirstChild("Humanoid")
			local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
			
			if humanoid and rootPart and humanoid.Health > 0 then
				local distance = (rootPart.Position - npcPosition).Magnitude
				
				if distance < closestDistance and distance <= CONFIG.DetectionRange then
					closestPlayer = player
					closestDistance = distance
				end
			end
		end
	end
	
	return closestPlayer, closestDistance
end

local function LookAtTarget(npc: NPCData, targetPosition: Vector3)
	if not npc.RootPart then return end
	
	local npcPosition = npc.RootPart.Position
	local direction = (targetPosition - npcPosition) * Vector3.new(1, 0, 1) -- Horizontal only
	
	if direction.Magnitude > 0.1 then
		local targetCFrame = CFrame.new(npcPosition, npcPosition + direction)
		npc.RootPart.CFrame = targetCFrame
	end
end

-- Determine NPC action type based on name
-- Naming convention: "NPC_M1", "NPC_M2", "NPC_Dash", "NPC_Slide", "NPC_Block"
-- If no suffix, uses random actions (old behavior)
local function GetNPCActionType(npcName: string): string?
	local name = string.upper(npcName)
	
	-- Check for specific action in name
	if string.find(name, "BLOCK") or string.find(name, "SHIELD") or string.find(name, "DEFEND") then
		return "Block"
	elseif string.find(name, "M1") or string.find(name, "LIGHT") then
		return "LightAttack"
	elseif string.find(name, "M2") or string.find(name, "STRONG") or string.find(name, "HEAVY") then
		return "StrongAttack"
	elseif string.find(name, "DASH") then
		return "Dash"
	elseif string.find(name, "SLIDE") then
		return "Slide"
	end
	
	return nil -- No specific action (stationary dummy)
end

-- NOTE: Random actions and movement removed - NPCs are now stationary training dummies

-- ========================================
-- NPC AI LOGIC (STATIONARY MODE - NO MOVEMENT, NO ATTACKS)
-- ========================================

-- NPCs are now STATIONARY training dummies:
-- - They stay in place (no movement)
-- - They DON'T attack the player
-- - They only maintain their assigned state (e.g., blocking for Block NPCs)
-- - Player attacks THEM for testing

local function PerformAction(npc: NPCData, target: Player)
	if not npc.IsActive then return end
	
	-- Check cooldown
	local now = os.clock()
	if now - npc.LastAction < CONFIG.ActionCooldown then
		return
	end
	
	-- NPCs DON'T move or attack - they are stationary training dummies
	-- Only Block NPCs maintain blocking state
	if npc.AssignedAction == "Block" then
		-- Check distance to see if we should maintain block state
		local targetChar = target.Character
		if targetChar then
			local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
			if targetRoot then
				local distance = (npc.RootPart.Position - targetRoot.Position).Magnitude
				
				-- Look at player for visual feedback
				if distance <= CONFIG.DetectionRange then
					LookAtTarget(npc, targetRoot.Position)
				end
				
				-- Maintain blocking state
				if not npc.IsBlocking then
					local result = NPCCombatHelper.StartBlock(npc.Model)
					if result.Success then
						npc.IsBlocking = true
						print(string.format("[NPC AI] %s started blocking", npc.Model.Name))
					end
				end
				npc.LastAction = now
			end
		end
	else
		-- For non-Block NPCs, just look at player if nearby
		local targetChar = target.Character
		if targetChar then
			local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
			if targetRoot then
				local distance = (npc.RootPart.Position - targetRoot.Position).Magnitude
				if distance <= CONFIG.DetectionRange then
					LookAtTarget(npc, targetRoot.Position)
				end
			end
		end
	end
end

local function UpdateNPC(npc: NPCData)
	if not npc.IsActive then return end
	
	-- Check if NPC is still valid
	if not npc.Model or not npc.Model.Parent then
		npc.IsActive = false
		return
	end
	
	if not npc.Humanoid or npc.Humanoid.Health <= 0 then
		npc.IsActive = false
		return
	end
	
	-- Find closest player
	local closestPlayer = GetClosestPlayer(npc.RootPart.Position)
	
	if closestPlayer then
		npc.CurrentTarget = closestPlayer
		
		-- Look at target
		local targetChar = closestPlayer.Character
		if targetChar then
			local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
			if targetRoot then
				LookAtTarget(npc, targetRoot.Position)
			end
		end
		
		-- Perform action
		PerformAction(npc, closestPlayer)
	else
		npc.CurrentTarget = nil
		-- Stop moving if no target
		if npc.Humanoid then
			npc.Humanoid:MoveTo(npc.RootPart.Position)
		end
	end
end

-- ========================================
-- NPC REGISTRATION
-- ========================================

local function RegisterNPC(npcModel: Model)
	if npcData[npcModel] then
		return -- Already registered
	end
	
	local humanoid = npcModel:FindFirstChildOfClass("Humanoid")
	local rootPart = npcModel:FindFirstChild("HumanoidRootPart")
	
	if not humanoid or not rootPart then
		warn(string.format("[NPC AI] NPC '%s' is missing Humanoid or HumanoidRootPart", npcModel.Name))
		return
	end
	
	-- Validate R6 avatar
	if not IsR6Avatar(npcModel) then
		warn(string.format("[NPC AI] NPC '%s' is not an R6 avatar. Combat System only supports R6!", npcModel.Name))
		return
	end
	
	-- Determine assigned action based on NPC name
	local assignedAction = GetNPCActionType(npcModel.Name)
	
	-- Create NPC data
	local data: NPCData = {
		Model = npcModel,
		Humanoid = humanoid,
		RootPart = rootPart,
		LastAction = 0,
		CurrentTarget = nil,
		IsActive = true,
		AssignedAction = assignedAction,
		IsBlocking = false,
	}
	
	npcData[npcModel] = data
	
	-- Handle NPC death
	humanoid.Died:Connect(function()
		print(string.format("[NPC AI] NPC '%s' died", npcModel.Name))
		data.IsActive = false
	end)
	
	-- Print registration with action type
	local actionInfo = if assignedAction then string.format(" - Action: %s ONLY", assignedAction) else " - Actions: Random"
	print(string.format("[NPC AI] Registered NPC: %s (R6)%s", npcModel.Name, actionInfo))
end

local function SetupNPCs()
	-- Find NPCs folder
	local npcsFolder = workspace:FindFirstChild(CONFIG.NPCFolder)
	
	if not npcsFolder then
		warn(string.format("[NPC AI] NPCs folder '%s' not found in Workspace. Creating it...", CONFIG.NPCFolder))
		npcsFolder = Instance.new("Folder")
		npcsFolder.Name = CONFIG.NPCFolder
		npcsFolder.Parent = workspace
		
		print("[NPC AI] Please add R6 Rigs to the 'NPCs' folder in Workspace")
		return
	end
	
	-- Register existing NPCs
	for _, child in ipairs(npcsFolder:GetChildren()) do
		if child:IsA("Model") then
			RegisterNPC(child)
		end
	end
	
	-- Listen for new NPCs
	npcsFolder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			task.wait(0.5) -- Wait for NPC to fully load
			RegisterNPC(child)
		end
	end)
	
	print(string.format("[NPC AI] Setup complete. Monitoring %d NPCs", #npcsFolder:GetChildren()))
end

-- ========================================
-- MAIN UPDATE LOOP
-- ========================================

local lastUpdate = 0
local UPDATE_RATE = 0.1 -- Update every 0.1 seconds (10 FPS for AI)

local function OnHeartbeat()
	local now = os.clock()
	
	if now - lastUpdate < UPDATE_RATE then
		return
	end
	
	lastUpdate = now
	
	-- Update all NPCs
	for _, npc in pairs(npcData) do
		UpdateNPC(npc)
	end
end

-- ========================================
-- INITIALIZATION
-- ========================================

print("\n[NPC AI] ============================================")
print("[NPC AI] Simple NPC AI System Starting...")
print("[NPC AI] ============================================\n")

-- Setup NPCs
SetupNPCs()

-- Start update loop
RunService.Heartbeat:Connect(OnHeartbeat)

print("[NPC AI] System active! NPCs will attack nearby players automatically.")
print("[NPC AI] Detection Range: " .. CONFIG.DetectionRange .. " studs")
print("[NPC AI] Attack Range: " .. CONFIG.AttackRange .. " studs")
print("[NPC AI] Action Cooldown: " .. CONFIG.ActionCooldown .. " seconds")
print("[NPC AI] NOTICE: Only R6 avatars are supported!\n")
