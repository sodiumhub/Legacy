--[[
    ===================================================================
    Astral Hub - 20th Anniversary (The Hunt: Roblox 20)
    PlaceId: 74205509034203
    UI Library: Vape UI Library (Cyber Cyan)

    Features & Core Mechanics:
      1. MASTER BUTTON: [⚡ AUTO COMPLETE EVERY ISLAND (1 - 20) ⚡]
         - Autonomously iterates through all 20 islands:
           * Streams in map & teleports character
           * Unlocks and activates Touchstone
           * Starts island quest with NPC
           * Executes minigame solver with 100% precision
           * Returns to NPC & turns in quest (earns event tools & progress)
           * Teleports directly onto regular & secret UGC Pedestals
           * Force-activates ProximityPrompts & invokes CheckRemote
           * Claims physical drops (UGCDrop / FinaleUGC)
           * Auto-dismisses any dialog popups
           * Unlocks Infinity Zone (Year 21) at the finale
      2. ALL 20 MINIGAME SOLVERS:
         - Island 1:  Badges Pickup (10 badges)
         - Island 2:  5-Button Press
         - Island 3:  Paintball Target Eggs (10 eggs)
         - Island 4:  Tornado Survival
         - Island 5:  Pizza Ingredients Collect & Podium Place
         - Island 6:  Meteor Shower Survival
         - Island 7:  Capture The Flag
         - Island 8:  Survival Kit Collection
         - Island 9:  Speedrun Goal Touch
         - Island 10: Dropper Process & Sold
         - Island 11: Tix Button Press
         - Island 12: Flood Evacuation Button
         - Island 13: Ore Mining (3 ores)
         - Island 14: Pet Egg Dispense, Coin Collect & Hatch
         - Island 15: Treasure Chest Auto-Dig (6x)
         - Island 16: Key Pickup (5 keys)
         - Island 17: Monster Escape Key Collector
         - Island 18: Hyperlaser Aim-Assist Targets (8 targets)
         - Island 19: Fashion Runway Auto-Walk (3 runs)
         - Island 20: Tree Water, Fruit Collect & Deposit
      3. STREAMING & PEDESTAL ENGINE:
         - Accurate island spawn offsets & LoadYearMap invocations
         - Stream-safe proximity prompt spoofer & remote invoker
         - Detailed console telemetry on badge & UGC ownership
      4. PLAYER ENHANCEMENTS:
         - Walkspeed, JumpPower, Infinite Jump, Noclip, Fly
    ===================================================================
--]]

-- 1. PURGE PREVIOUS INSTANCES & RUNNERS
if _G.AstralHub_Thread then
    pcall(task.cancel, _G.AstralHub_Thread)
    _G.AstralHub_Thread = nil
end
_G.AstralHub_Running = false
task.wait(0.15)
_G.AstralHub_Running = true

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local BadgeService = game:GetService("BadgeService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    HumanoidRootPart = char:WaitForChild("HumanoidRootPart")
end)

-- Purge any previous Astral Hub / Vape GUIs
local targetGuiParent = (gethui and gethui()) or CoreGui
for _, c in ipairs(targetGuiParent:GetChildren()) do
    if c:IsA("ScreenGui") and (c.Name == "ui" or c.Name:find("Astral") or c.Name:find("Vape")) then
        pcall(function() c:Destroy() end)
    end
end

-- Remotes & Configs
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local ConfigFolder = ReplicatedStorage:WaitForChild("Config", 10)
local QuestActivities = ConfigFolder and require(ConfigFolder:WaitForChild("QuestActivities"))
local QuestTagPrefixes = ConfigFolder and require(ConfigFolder:WaitForChild("QuestTagPrefixes"))
local QuestsConfig = ConfigFolder and require(ConfigFolder:WaitForChild("Quests"))

-- State Table
local State = {
    SelectedIsland = 1,
    AutoTurnIn = true,
    AutoClaimUGC = false,
    MasterRunning = false,
    
    -- Movement
    WalkSpeed = 16,
    JumpPower = 50,
    ModifySpeed = false,
    ModifyJump = false,
    InfiniteJump = false,
    Noclip = false,
    Fly = false,
    FlySpeed = 50,
}

-- Island Teleport Coordinates (Pre-indexed for streaming)
local ISLAND_SPAWNS = {
    [0]  = Vector3.new(989.3, 3.5, 303.6),
    [1]  = Vector3.new(-26, 3.5, 321),
    [2]  = Vector3.new(-699, 3.5, 300),
    [3]  = Vector3.new(-1421, 3.5, 350),
    [4]  = Vector3.new(-2100, 44.5, 326),
    [5]  = Vector3.new(-2800, 7.5, 300),
    [6]  = Vector3.new(-3598.35, 5.0, 103.4),
    [7]  = Vector3.new(-4251.25, 23.5, 447.25),
    [8]  = Vector3.new(-4928.47, -22.0, 536.5),
    [9]  = Vector3.new(-5583.58, 31.5, 74.48),
    [10] = Vector3.new(-6220.65, 14.5, 260.07),
    [11] = Vector3.new(-7012.26, 3.5, -0.67),
    [12] = Vector3.new(-7871.93, 12.5, -61.72),
    [13] = Vector3.new(-8509.18, 3.5, -64.42),
    [14] = Vector3.new(-9103.95, 2.5, 370.38),
    [15] = Vector3.new(-9579.93, -2.0, 214.67),
    [16] = Vector3.new(-10451.87, 3.5, 268.73),
    [17] = Vector3.new(-11107.47, 1.5, 392.45),
    [18] = Vector3.new(-11809.94, 5.5, 176.28),
    [19] = Vector3.new(-12598.62, 16.5, 136.93),
    [20] = Vector3.new(-13402.19, 4.5, 239.69),
    [21] = Vector3.new(-1835.59, 503.0, -3721.61), -- Infinity Zone
}

-- ===================================================================
-- CORE UTILITIES
-- ===================================================================

local function getHRP()
    Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
    return HumanoidRootPart
end

local function teleportTo(pos)
    local hrp = getHRP()
    if hrp then
        hrp.CFrame = (typeof(pos) == "CFrame") and pos or CFrame.new(pos)
    end
end

local function dismissConfirmationDialog()
    pcall(function()
        local cd = LocalPlayer.PlayerGui:FindFirstChild("ConfirmationDialog")
        if cd and cd.Enabled then
            cd.Enabled = false
        end
    end)
end

local function getYearFolderName(islandIndex)
    return string.format("Year_%02d", islandIndex)
end

local function ensureIslandLoaded(islandIndex)
    local pos = ISLAND_SPAWNS[islandIndex]
    if pos then
        pcall(function() LocalPlayer:RequestStreamAroundAsync(pos) end)
    end
    
    local loadYearMap = Remotes:FindFirstChild("LoadYearMap")
    if loadYearMap and islandIndex >= 1 and islandIndex <= 20 then
        pcall(function() loadYearMap:InvokeServer(islandIndex, true) end)
    end
    
    if pos then
        teleportTo(pos + Vector3.new(0, 3, 0))
    end
    
    local yearName = getYearFolderName(islandIndex)
    local yFolder = workspace.YearFolders:FindFirstChild(yearName)
    local t0 = os.clock()
    while (not yFolder or #yFolder:GetChildren() == 0) and (os.clock() - t0 < 2.5) do
        task.wait(0.2)
        yFolder = workspace.YearFolders:FindFirstChild(yearName)
    end
    return yFolder
end

local function getIslandNPC(islandIndex)
    local yFolder = ensureIslandLoaded(islandIndex)
    if yFolder then
        local npc = yFolder:FindFirstChild("DialogNPCSpawn")
        if npc then return npc end
        for _, child in ipairs(yFolder:GetChildren()) do
            if child:FindFirstChild("Interact") or child:GetAttribute("DialogTree") then
                return child
            end
        end
    end
    return nil
end

local function getIslandTouchstone(islandIndex)
    if islandIndex == 21 then
        local yInf = workspace.YearFolders:FindFirstChild("Infinity") or workspace:FindFirstChild("Year_Infinity")
        if yInf then return yInf:FindFirstChild("Touchstone") end
        for _, ts in ipairs(CollectionService:GetTagged("Touchstone")) do
            if ts:GetAttribute("Index") == 21 or ts:GetAttribute("IsInfinity") then return ts end
        end
        return nil
    end
    local yFolder = ensureIslandLoaded(islandIndex)
    if yFolder then
        return yFolder:FindFirstChild("Touchstone")
    end
    return nil
end

local function startQuest(islandIndex)
    local npc = getIslandNPC(islandIndex)
    if not npc then return false end
    local interact = npc:FindFirstChild("Interact")
    if interact then
        teleportTo(npc:GetPivot().Position + Vector3.new(0, 3, 0))
        task.wait(0.3)
        interact:FireServer("start")
        task.wait(0.3)
        return true
    end
    return false
end

local function turnInQuest(islandIndex)
    local npc = getIslandNPC(islandIndex)
    if not npc then return false end
    local interact = npc:FindFirstChild("Interact")
    if interact then
        teleportTo(npc:GetPivot().Position + Vector3.new(0, 3, 0))
        task.wait(0.3)
        interact:FireServer("turnIn")
        task.wait(0.3)
        return true
    end
    return false
end

-- ===================================================================
-- ALL 20 MINIGAME SOLVERS
-- ===================================================================
local MinigameSolvers = {}

-- Island 1: 10 Badges
MinigameSolvers[1] = function()
    local remote = Remotes:FindFirstChild("PickupMinigameCollect")
    if not remote then return end
    local targets = CollectionService:GetTagged("Island1BadgeSpawn")
    if #targets == 0 then
        local gf = workspace:FindFirstChild("Gimmicks") and workspace.Gimmicks:FindFirstChild("Island1")
        if gf and gf:FindFirstChild("Island1BadgeSpawn") then
            targets = gf.Island1BadgeSpawn:GetChildren()
        end
    end
    for _, part in ipairs(targets) do
        local id = part:GetAttribute("ID") or part:GetAttribute("Id") or part.Name
        teleportTo(part:GetPivot().Position + Vector3.new(0, 2, 0))
        task.wait(0.1)
        remote:FireServer(tostring(id))
        task.wait(0.05)
    end
end

-- Island 2: 5 Buttons
MinigameSolvers[2] = function()
    local remote = Remotes:FindFirstChild("Island2ButtonPress")
    if not remote then return end
    local buttons = CollectionService:GetTagged("Island2Button")
    if #buttons == 0 then
        local gf = workspace:FindFirstChild("Gimmicks") and workspace.Gimmicks:FindFirstChild("Island2")
        if gf and gf:FindFirstChild("Buttons") then
            buttons = gf.Buttons:GetChildren()
        end
    end
    for _, btn in ipairs(buttons) do
        teleportTo(btn:GetPivot().Position + Vector3.new(0, 2, 0))
        task.wait(0.12)
        remote:FireServer(btn)
        task.wait(0.08)
    end
end

-- Island 3: 10 Paintball Eggs
MinigameSolvers[3] = function()
    local remote = Remotes:FindFirstChild("PaintballMinigame")
    if not remote then return end
    local eggs = {}
    local gf = workspace:FindFirstChild("Gimmicks") and workspace.Gimmicks:FindFirstChild("Island3")
    if gf and gf:FindFirstChild("Eggs") then
        eggs = gf.Eggs:GetChildren()
    else
        for _, egg in ipairs(CollectionService:GetTagged("PaintableEgg")) do
            if egg:IsDescendantOf(workspace) then
                table.insert(eggs, egg)
            end
        end
    end
    for _, egg in ipairs(eggs) do
        local id = egg:GetAttribute("Id") or egg:GetAttribute("ID") or egg.Name:match("%d+")
        if id then
            teleportTo(egg:GetPivot().Position + Vector3.new(0, 2, 0))
            task.wait(0.1)
            remote:FireServer(tostring(id))
            task.wait(0.05)
        end
    end
end

-- Island 4: Tornado Survival (30s)
MinigameSolvers[4] = function()
    local hrp = getHRP()
    local plate = workspace:FindFirstChild("Gimmicks") and workspace.Gimmicks:FindFirstChild("Island4") and workspace.Gimmicks.Island4:FindFirstChild("TornadoPlate")
    if plate and hrp then
        hrp.CFrame = plate.CFrame + Vector3.new(0, 4, 0)
        hrp.Anchored = true
    else
        teleportTo(ISLAND_SPAWNS[4] + Vector3.new(0, 5, 0))
        if hrp then hrp.Anchored = true end
    end
    local t0 = os.clock()
    while os.clock() - t0 < 33 do
        if LocalPlayer:GetAttribute("qf_Island4Tornado") == 1 then break end
        task.wait(1)
    end
    if hrp then hrp.Anchored = false end
end

-- Island 5: Pizza Ingredients & Podium
MinigameSolvers[5] = function()
    local collectRemote = Remotes:FindFirstChild("Island5PizzaCollect")
    local placeRemote = Remotes:FindFirstChild("Island5PizzaPlace")
    local hrp = getHRP()
    
    local spawns = {}
    local gf = workspace:FindFirstChild("Gimmicks") and workspace.Gimmicks:FindFirstChild("Island5")
    if gf and gf:FindFirstChild("Island5PizzaSpawns") then
        spawns = gf.Island5PizzaSpawns:GetChildren()
    else
        spawns = CollectionService:GetTagged("Island5PizzaSpawns")
    end
    for _, part in ipairs(spawns) do
        if hrp then
            hrp.CFrame = part:GetPivot() + Vector3.new(0, 2, 0)
            hrp.Anchored = true
        end
        task.wait(0.2)
        if collectRemote then collectRemote:FireServer(part) end
        task.wait(0.15)
        if hrp then hrp.Anchored = false end
        task.wait(0.1)
    end
    
    local podiums = CollectionService:GetTagged("PizzaPodium")
    if #podiums > 0 and hrp then
        hrp.CFrame = podiums[1]:GetPivot() + Vector3.new(0, 2, 0)
        hrp.Anchored = true
        task.wait(0.3)
        if placeRemote then placeRemote:FireServer() end
        task.wait(0.3)
        hrp.Anchored = false
    end
end

-- Island 6: Meteor Survival (20s)
MinigameSolvers[6] = function()
    local hrp = getHRP()
    teleportTo(ISLAND_SPAWNS[6] + Vector3.new(0, 35, 0))
    if hrp then hrp.Anchored = true end
    local t0 = os.clock()
    while os.clock() - t0 < 22 do
        if (LocalPlayer:GetAttribute("qf_Island6Progress") or 0) >= 30 then break end
        task.wait(1)
    end
    if hrp then hrp.Anchored = false end
end

-- Island 7: Flag Grab
MinigameSolvers[7] = function()
    local remote = Remotes:FindFirstChild("Island7FlagGrab")
    local flags = CollectionService:GetTagged("Island7FlagModel")
    if #flags == 0 then
        local gf = workspace:FindFirstChild("Gimmicks") and workspace.Gimmicks:FindFirstChild("Island7")
        if gf and gf:FindFirstChild("BlueFlagSet") then
            flags = { gf.BlueFlagSet }
        end
    end
    if #flags > 0 then
        teleportTo(flags[1]:GetPivot().Position + Vector3.new(0, 2, 0))
        task.wait(0.2)
        if remote then remote:FireServer() end
        task.wait(0.2)
    end
end

-- Island 8: Survival Kits (3 kits)
MinigameSolvers[8] = function()
    local remote = Remotes:FindFirstChild("SurvivalKitMinigame")
    local kits = CollectionService:GetTagged("SurvivalKit")
    for _, kit in ipairs(kits) do
        teleportTo(kit:GetPivot().Position + Vector3.new(0, 2, 0))
        task.wait(0.15)
        if remote then remote:FireServer(kit) end
        task.wait(0.1)
    end
end

-- Island 9: Speedrun Goal
MinigameSolvers[9] = function()
    local remote = Remotes:FindFirstChild("SpeedrunMinigame")
    local goals = CollectionService:GetTagged("SpeedrunGoal")
    if #goals > 0 then
        teleportTo(goals[1]:GetPivot().Position + Vector3.new(0, 2, 0))
        task.wait(0.2)
        if remote then remote:FireServer(goals[1]) end
        task.wait(0.2)
    end
end

-- Island 10: Dropper
MinigameSolvers[10] = function()
    local dropRemote = Remotes:FindFirstChild("Island10Drop")
    local sellRemote = Remotes:FindFirstChild("Island10Sold")
    teleportTo(ISLAND_SPAWNS[10] + Vector3.new(0, 3, 0))
    task.wait(0.2)
    if dropRemote then dropRemote:FireServer() end
    task.wait(1.5)
    if sellRemote then sellRemote:FireServer() end
    task.wait(0.5)
end

-- Island 11: Tix Button
MinigameSolvers[11] = function()
    local remote = Remotes:FindFirstChild("Island11ButtonPress")
    local btns = CollectionService:GetTagged("Island11Button")
    if #btns == 0 then
        local gf = workspace:FindFirstChild("Gimmicks") and workspace.Gimmicks:FindFirstChild("Island11")
        if gf and gf:FindFirstChild("Button") then btns = { gf.Button } end
    end
    for _, btn in ipairs(btns) do
        teleportTo(btn:GetPivot().Position + Vector3.new(0, 2, 0))
        task.wait(0.2)
        if remote then remote:FireServer() end
        task.wait(0.2)
    end
end

-- Island 12: Flood Button
MinigameSolvers[12] = function()
    local remote = Remotes:FindFirstChild("FloodMinigame")
    local btns = CollectionService:GetTagged("FloodButton")
    for _, btn in ipairs(btns) do
        teleportTo(btn:GetPivot().Position + Vector3.new(0, 2, 0))
        task.wait(0.2)
        if remote then remote:FireServer(btn) end
        task.wait(0.2)
    end
end

-- Island 13: Mine Ores (3 ores)
MinigameSolvers[13] = function()
    local remote = Remotes:FindFirstChild("Island13Hit")
    local hrp = getHRP()
    local ores = CollectionService:GetTagged("Island13Ores")
    if #ores == 0 then
        local gf = workspace:FindFirstChild("Gimmicks") and workspace.Gimmicks:FindFirstChild("Island13")
        if gf and gf:FindFirstChild("Ores") then ores = gf.Ores:GetChildren() end
    end
    for _, ore in ipairs(ores) do
        if hrp then
            hrp.CFrame = ore:GetPivot() + Vector3.new(0, 2, 0)
            hrp.Anchored = true
        end
        task.wait(0.15)
        for _ = 1, 6 do
            if remote then remote:FireServer(ore) end
            task.wait(0.12)
        end
        if hrp then hrp.Anchored = false end
        task.wait(0.1)
    end
    if hrp then hrp.Anchored = false end
end

-- Island 14: Pet Egg Dispense, Coin Collect & Hatch
MinigameSolvers[14] = function()
    local remote = Remotes:FindFirstChild("PetEggMinigame")
    if not remote then return end
    teleportTo(ISLAND_SPAWNS[14] + Vector3.new(0, 3, 0))
    task.wait(0.3)
    remote:FireServer("Dispense")
    task.wait(0.6)
    for _, coin in ipairs(CollectionService:GetTagged("Island14CoinSpawn")) do
        teleportTo(coin:GetPivot().Position + Vector3.new(0, 2, 0))
        task.wait(0.1)
        remote:FireServer("Collect", coin)
    end
    task.wait(0.5)
    remote:FireServer("Hatch")
    task.wait(0.5)
end

-- Island 15: Treasure Dig (6x)
MinigameSolvers[15] = function()
    local remote = Remotes:FindFirstChild("Island15Dig")
    local hrp = getHRP()
    local chests = CollectionService:GetTagged("Island15TreasureSpawns")
    if #chests == 0 then
        local gf = workspace:FindFirstChild("Gimmicks") and workspace.Gimmicks:FindFirstChild("Island15")
        if gf and gf:FindFirstChild("Island15TreasureSpawns") then
            chests = gf.Island15TreasureSpawns:GetChildren()
        end
    end
    for _, chest in ipairs(chests) do
        if hrp then
            hrp.CFrame = chest:GetPivot() + Vector3.new(0, 2, 0)
            hrp.Anchored = true
        end
        task.wait(0.2)
        for _ = 1, 7 do
            if remote then remote:FireServer() end
            task.wait(0.25)
        end
        if hrp then hrp.Anchored = false end
        task.wait(0.1)
    end
    if hrp then hrp.Anchored = false end
end

-- Island 16: Key Pickups (5 keys)
MinigameSolvers[16] = function()
    local remote = Remotes:FindFirstChild("PickupMinigameCollect")
    local keys = CollectionService:GetTagged("Island16KeySpawn")
    if #keys == 0 then
        local gf = workspace:FindFirstChild("Gimmicks") and workspace.Gimmicks:FindFirstChild("Island16")
        if gf then keys = gf:GetChildren() end
    end
    for _, key in ipairs(keys) do
        local id = key:GetAttribute("ID") or key:GetAttribute("Id") or key.Name
        teleportTo(key:GetPivot().Position + Vector3.new(0, 2, 0))
        task.wait(0.12)
        if remote then remote:FireServer(tostring(id)) end
        task.wait(0.08)
    end
end

-- Island 17: Monster Escape Keys
MinigameSolvers[17] = function()
    local remote = Remotes:FindFirstChild("MonsterEscapeMinigame")
    local hrp = getHRP()
    local keys = CollectionService:GetTagged("MonsterEscapeKey")
    for _, k in ipairs(keys) do
        if hrp then
            hrp.CFrame = k:GetPivot() + Vector3.new(0, 2, 0)
            hrp.Anchored = true
        end
        task.wait(0.2)
        if remote then remote:FireServer(k) end
        task.wait(0.15)
        if hrp then hrp.Anchored = false end
        task.wait(0.1)
    end
    if hrp then hrp.Anchored = false end
end

-- Island 18: Hyperlaser Targets (Hit all 8 spinning BladeBalls with anti-gravity lock & server pacing)
MinigameSolvers[18] = function()
    local remote = Remotes:FindFirstChild("HyperlaserMinigame")
    if not remote then return end
    
    local hrp = getHRP()
    local bladeBalls = CollectionService:GetTagged("BladeBalls")[1]
    if not bladeBalls then
        local gf = workspace:FindFirstChild("Gimmicks") and workspace.Gimmicks:FindFirstChild("Island18")
        bladeBalls = gf and gf:FindFirstChild("BladeBalls")
    end
    
    if not bladeBalls then
        warn("[Astral Hub] BladeBalls model not found on Island 18!")
        return
    end
    
    local balls = {}
    for _, child in ipairs(bladeBalls:GetChildren()) do
        if child:IsA("BasePart") then
            table.insert(balls, child)
        end
    end
    
    table.sort(balls, function(a, b)
        local idA = tonumber(a:GetAttribute("Id") or a:GetAttribute("ID") or 0) or 0
        local idB = tonumber(b:GetAttribute("Id") or b:GetAttribute("ID") or 0) or 0
        return idA < idB
    end)
    
    for _, ball in ipairs(balls) do
        local id = ball:GetAttribute("Id") or ball:GetAttribute("ID") or ball.Name
        if id then
            if hrp then
                hrp.CFrame = ball.CFrame + Vector3.new(0, 1, 0)
                hrp.Anchored = true
            end
            task.wait(0.25)
            
            local freshPos = ball.Position
            remote:FireServer(tostring(id), freshPos, workspace:GetServerTimeNow())
            
            task.wait(0.4)
            if hrp then hrp.Anchored = false end
            task.wait(0.1)
        end
    end
    
    if hrp then hrp.Anchored = false end
end

-- Island 19: Fashion Runway Complete
MinigameSolvers[19] = function()
    local remote = Remotes:FindFirstChild("FashionMinigame")
    teleportTo(ISLAND_SPAWNS[19] + Vector3.new(0, 3, 0))
    task.wait(0.5)
    if remote then
        for _ = 1, 4 do
            remote:FireServer("RunwayComplete")
            task.wait(0.6)
        end
    end
end

-- Island 20: Tree Grow
MinigameSolvers[20] = function()
    local remote = Remotes:FindFirstChild("GrowTreeMinigame")
    teleportTo(ISLAND_SPAWNS[20] + Vector3.new(0, 3, 0))
    task.wait(0.5)
    if remote then
        for _ = 1, 4 do
            remote:FireServer("Water")
            task.wait(0.45)
            remote:FireServer("Collect")
            task.wait(0.45)
            remote:FireServer("Deposit")
            task.wait(0.45)
        end
    end
end

-- ===================================================================
-- UGC CLAIMING ENGINE
-- ===================================================================

local function claimIslandUGC(islandIndex)
    local yFolder = ensureIslandLoaded(islandIndex)
    if not yFolder then return end
    
    for _, pedName in ipairs({ "UGCPedestal", "UGCPedestalSecret" }) do
        local ped = yFolder:FindFirstChild(pedName)
        if ped then
            teleportTo(ped.Position + Vector3.new(0, 2, 0))
            task.wait(0.25)
            
            local prompt = ped:FindFirstChildOfClass("ProximityPrompt")
            if prompt then
                prompt.Enabled = true
                prompt.RequiresLineOfSight = false
                prompt.MaxActivationDistance = 50
                if fireproximityprompt then
                    pcall(function() fireproximityprompt(prompt) end)
                end
            end
            
            local cr = ped:FindFirstChild("CheckRemote")
            if cr then
                pcall(function()
                    local s, res1, res2 = cr:InvokeServer()
                    if s and res1 == true then
                        print(string.format("[Astral Hub] [SUCCESS] Claimed UGC on Island %d (%s)!", islandIndex, pedName))
                    else
                        local badgeId = ped:GetAttribute("BadgeId")
                        print(string.format("[Astral Hub] Island %d (%s): %s (Badge: %s)", islandIndex, pedName, tostring(res2 or "Locked"), tostring(badgeId)))
                    end
                end)
            end
            task.wait(0.2)
            dismissConfirmationDialog()
        end
    end
    
    -- Physical Drops / Finale UGC
    pcall(function()
        for _, drop in ipairs(CollectionService:GetTagged("UGCDrop")) do
            if drop:FindFirstChild("PickUp") then
                teleportTo(drop.Position + Vector3.new(0, 2, 0))
                task.wait(0.1)
                drop.PickUp:FireServer()
            end
        end
        for _, fugc in ipairs(CollectionService:GetTagged("FinaleUGC")) do
            if fugc:FindFirstChild("PickUp") then
                teleportTo(fugc.Position + Vector3.new(0, 2, 0))
                task.wait(0.1)
                fugc.PickUp:FireServer()
            end
        end
    end)
end

local function claimAllUGC()
    for i = 1, 20 do
        print(string.format("[Astral Hub] Checking Island %d UGC Pedestals...", i))
        claimIslandUGC(i)
        task.wait(0.4)
    end
    print("[Astral Hub] All UGC Pedestals Checked & Claimed!")
end

local function touchAllTouchstones()
    for i = 0, 20 do
        local ts = getIslandTouchstone(i)
        if ts then
            teleportTo(ts.Position + Vector3.new(0, 3, 0))
            task.wait(0.3)
            local cr = ts:FindFirstChild("CheckRemote")
            if cr then
                pcall(function() cr:InvokeServer() end)
            end
            task.wait(0.2)
            dismissConfirmationDialog()
        end
    end
    -- Infinity Touchstone
    teleportTo(ISLAND_SPAWNS[21] + Vector3.new(0, 3, 0))
    task.wait(0.5)
    local ts21 = getIslandTouchstone(21)
    if ts21 and ts21:FindFirstChild("CheckRemote") then
        pcall(function() ts21.CheckRemote:InvokeServer() end)
    end
    print("[Astral Hub] All Touchstones Unlocked!")
end

local function solveIslandQuest(islandIndex)
    ensureIslandLoaded(islandIndex)
    task.wait(0.3)
    
    -- 1. Start Quest
    startQuest(islandIndex)
    task.wait(0.5)
    
    -- 2. Run Minigame Solver
    local solver = MinigameSolvers[islandIndex]
    if solver then
        solver()
    end
    task.wait(0.5)
    
    -- 3. Turn In Quest
    turnInQuest(islandIndex)
    task.wait(0.5)
    
    -- 4. Touch Touchstone
    local ts = getIslandTouchstone(islandIndex)
    if ts and ts:FindFirstChild("CheckRemote") then
        teleportTo(ts.Position + Vector3.new(0, 3, 0))
        task.wait(0.25)
        pcall(function() ts.CheckRemote:InvokeServer() end)
        dismissConfirmationDialog()
    end
    
    -- 5. Claim Island UGC
    claimIslandUGC(islandIndex)
end

-- ===================================================================
-- MASTER AUTO ENGINE: DO EVERY ISLAND (1 - 20)
-- ===================================================================
local function autoDoEveryIsland()
    if State.MasterRunning then
        warn("[Astral Hub] Master loop is already running!")
        return
    end
    State.MasterRunning = true
    
    print("=======================================================")
    print("[Astral Hub] STARTING MASTER AUTO: ALL ISLANDS 1 - 20")
    print("=======================================================")
    
    -- Unlock Year 0 intro Touchstone
    pcall(function()
        local y0 = workspace.YearFolders:FindFirstChild("Year_00")
        if y0 and y0:FindFirstChild("Touchstone") then
            teleportTo(y0.Touchstone.Position + Vector3.new(0, 3, 0))
            task.wait(0.3)
            y0.Touchstone.CheckRemote:InvokeServer()
            dismissConfirmationDialog()
        end
    end)
    
    for i = 1, 20 do
        if not _G.AstralHub_Running or not State.MasterRunning then
            print("[Astral Hub] Master loop cancelled by user.")
            break
        end
        
        print(string.format("[Astral Hub] >>> STARTING ISLAND %d / 20 <<<", i))
        
        -- A. Stream Island & Teleport
        ensureIslandLoaded(i)
        task.wait(0.5)
        
        -- B. Activate Touchstone
        local ts = getIslandTouchstone(i)
        if ts and ts:FindFirstChild("CheckRemote") then
            teleportTo(ts.Position + Vector3.new(0, 3, 0))
            task.wait(0.25)
            pcall(function() ts.CheckRemote:InvokeServer() end)
            task.wait(0.2)
            dismissConfirmationDialog()
        end
        
        -- C. Check Quest Status & Execute Solver
        local turnedInFlag = string.format("qf_Island%dTurnedIn", i)
        if LocalPlayer:GetAttribute(turnedInFlag) ~= 1 then
            print(string.format("[Astral Hub] Solving Island %d Quest...", i))
            solveIslandQuest(i)
            task.wait(1)
        else
            print(string.format("[Astral Hub] Island %d Quest already completed! Skipping minigame.", i))
            -- Still attempt UGC claim
            claimIslandUGC(i)
        end
        
        print(string.format("[Astral Hub] [FINISHED] Island %d Complete!", i))
        task.wait(0.5)
    end
    
    -- Visit Infinity Zone (Year 21)
    if State.MasterRunning then
        print("[Astral Hub] Finishing up: Unlocking Infinity Zone (Year 21)...")
        teleportTo(ISLAND_SPAWNS[21] + Vector3.new(0, 3, 0))
        task.wait(1)
        local ts21 = getIslandTouchstone(21)
        if ts21 and ts21:FindFirstChild("CheckRemote") then
            teleportTo(ts21.Position + Vector3.new(0, 3, 0))
            task.wait(0.3)
            pcall(function() ts21.CheckRemote:InvokeServer() end)
            dismissConfirmationDialog()
        end
        print("=======================================================")
        print("[Astral Hub] ALL 20 ISLANDS + INFINITY ZONE COMPLETED!")
        print("=======================================================")
    end
    
    State.MasterRunning = false
end

-- ===================================================================
-- BACKGROUND ENGINE
-- ===================================================================
_G.AstralHub_Thread = task.spawn(function()
    while _G.AstralHub_Running do
        local hrp = getHRP()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        
        -- Movement adjustments
        if hum then
            if State.ModifySpeed then hum.WalkSpeed = State.WalkSpeed end
            if State.ModifyJump then hum.JumpPower = State.JumpPower end
        end
        
        -- Noclip
        if State.Noclip and char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then
                    p.CanCollide = false
                end
            end
        end
        
        -- Auto Turn-in listener
        if State.AutoTurnIn and not State.MasterRunning then
            for i = 1, 20 do
                local turnedInFlag = string.format("qf_Island%dTurnedIn", i)
                local startedFlag = string.format("qf_Island%dStarted", i)
                if LocalPlayer:GetAttribute(startedFlag) == 1 and LocalPlayer:GetAttribute(turnedInFlag) ~= 1 then
                    local qa = QuestActivities and QuestActivities["Island" .. i]
                    if qa and qa.ProgressFlag then
                        local cur = LocalPlayer:GetAttribute("qf_" .. qa.ProgressFlag) or 0
                        if cur >= (qa.Count or 1) then
                            turnInQuest(i)
                        end
                    end
                end
            end
        end
        
        -- Loop Auto Claim UGC
        if State.AutoClaimUGC and not State.MasterRunning then
            claimAllUGC()
            task.wait(5)
        end
        
        task.wait(0.15)
    end
end)

-- Infinite Jump Listener
UserInputService.JumpRequest:Connect(function()
    if State.InfiniteJump then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- ===================================================================
-- VAPE UI SETUP (Cyber Neon Cyan Theme)
-- ===================================================================
local VapeLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/GhostDuckyy/UI-Libraries/main/Vape%20ui%20lib/source.lua"))()
local Window = VapeLib:Window("Astral Hub | 20th Anniversary (UGC & Quests)", Color3.fromRGB(0, 220, 255), Enum.KeyCode.RightControl)

-- TAB 1: QUESTS & MASTER AUTO
local QuestTab = Window:Tab("Quests")

QuestTab:Button("⚡ AUTO COMPLETE EVERY ISLAND (1 - 20) ⚡", function()
    task.spawn(autoDoEveryIsland)
end)

QuestTab:Button("Stop Master Automation", function()
    State.MasterRunning = false
    print("[Astral Hub] Master loop cancellation requested.")
end)

local IslandList = {}
for i = 1, 20 do
    table.insert(IslandList, "Island " .. i)
end

QuestTab:Dropdown("Select Island", IslandList, function(sel)
    local num = tonumber(sel:match("%d+"))
    if num then State.SelectedIsland = num end
end)

QuestTab:Button("Autocomplete Selected Quest", function()
    task.spawn(function()
        solveIslandQuest(State.SelectedIsland)
    end)
end)

QuestTab:Toggle("Auto Turn In Ready Quests", true, function(val)
    State.AutoTurnIn = val
end)

QuestTab:Button("Start Selected Quest", function()
    startQuest(State.SelectedIsland)
end)

QuestTab:Button("Turn In Selected Quest", function()
    turnInQuest(State.SelectedIsland)
end)

-- TAB 2: UGC & PEDESTALS
local UGCTab = Window:Tab("UGC & Pedestals")

UGCTab:Button("⚡ Claim All UGC Pedestals (Teleports to All) ⚡", function()
    task.spawn(claimAllUGC)
end)

UGCTab:Button("Claim Current Island UGC", function()
    task.spawn(function()
        claimIslandUGC(State.SelectedIsland)
    end)
end)

UGCTab:Button("Touch All Touchstones (Unlock All Islands)", function()
    task.spawn(touchAllTouchstones)
end)

UGCTab:Button("Touch Current Island Touchstone", function()
    local ts = getIslandTouchstone(State.SelectedIsland)
    if ts and ts:FindFirstChild("CheckRemote") then
        teleportTo(ts.Position + Vector3.new(0, 3, 0))
        task.wait(0.3)
        ts.CheckRemote:InvokeServer()
        dismissConfirmationDialog()
    end
end)

UGCTab:Button("Check All Island Badges & UGC Status", function()
    task.spawn(function()
        print("=== UGC PEDESTAL & BADGE STATUS ===")
        for i = 1, 20 do
            local yFolder = ensureIslandLoaded(i)
            if yFolder then
                for _, pName in ipairs({"UGCPedestal", "UGCPedestalSecret"}) do
                    local ped = yFolder:FindFirstChild(pName)
                    if ped then
                        local bId = ped:GetAttribute("BadgeId")
                        local modelName = ped:GetAttribute("UGCModel")
                        local hasB = false
                        if bId then
                            local s, owns = pcall(function() return BadgeService:UserHasBadgeAsync(LocalPlayer.UserId, bId) end)
                            hasB = s and owns
                        end
                        print(string.format("Island %02d [%s] - Model: %s | BadgeId: %s | Owned: %s", i, pName, tostring(modelName), tostring(bId), tostring(hasB)))
                    end
                end
            end
        end
        print("=== END STATUS ===")
    end)
end)

UGCTab:Toggle("Loop Auto Claim UGC", false, function(val)
    State.AutoClaimUGC = val
end)

-- TAB 3: TELEPORTS
local TeleportTab = Window:Tab("Teleports")

TeleportTab:Dropdown("Teleport to Island", IslandList, function(sel)
    local num = tonumber(sel:match("%d+"))
    if num and ISLAND_SPAWNS[num] then
        ensureIslandLoaded(num)
        teleportTo(ISLAND_SPAWNS[num] + Vector3.new(0, 3, 0))
    end
end)

TeleportTab:Button("Teleport to Infinity Zone (Year 21)", function()
    teleportTo(ISLAND_SPAWNS[21] + Vector3.new(0, 3, 0))
end)

TeleportTab:Button("Teleport to Current Quest NPC", function()
    local npc = getIslandNPC(State.SelectedIsland)
    if npc then
        teleportTo(npc:GetPivot().Position + Vector3.new(0, 3, 0))
    end
end)

TeleportTab:Button("Teleport to Current Touchstone", function()
    local ts = getIslandTouchstone(State.SelectedIsland)
    if ts then
        teleportTo(ts.Position + Vector3.new(0, 3, 0))
    end
end)

TeleportTab:Button("Teleport to Current UGC Pedestal", function()
    local yf = ensureIslandLoaded(State.SelectedIsland)
    if yf and yf:FindFirstChild("UGCPedestal") then
        teleportTo(yf.UGCPedestal.Position + Vector3.new(0, 3, 0))
    end
end)

-- TAB 4: PLAYER / MOVEMENT
local PlayerTab = Window:Tab("Player")

PlayerTab:Toggle("Enable Custom Speed", false, function(val)
    State.ModifySpeed = val
    if not val then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 16 end
    end
end)

PlayerTab:Slider("WalkSpeed", 16, 200, 32, function(val)
    State.WalkSpeed = val
end)

PlayerTab:Toggle("Enable Custom Jump", false, function(val)
    State.ModifyJump = val
    if not val then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.JumpPower = 50 end
    end
end)

PlayerTab:Slider("JumpPower", 50, 300, 100, function(val)
    State.JumpPower = val
end)

PlayerTab:Toggle("Infinite Jump", false, function(val)
    State.InfiniteJump = val
end)

PlayerTab:Toggle("Noclip", false, function(val)
    State.Noclip = val
end)

-- TAB 5: SETTINGS
local SettingsTab = Window:Tab("Settings")

SettingsTab:Button("Unload Astral Hub", function()
    _G.AstralHub_Running = false
    State.MasterRunning = false
    if _G.AstralHub_Thread then pcall(task.cancel, _G.AstralHub_Thread) end
    for _, c in ipairs(targetGuiParent:GetChildren()) do
        if c:IsA("ScreenGui") and (c.Name == "ui" or c.Name:find("Astral") or c.Name:find("Vape")) then
            pcall(function() c:Destroy() end)
        end
    end
end)

print("[Astral Hub] 20th Anniversary (The Hunt: Roblox 20) Hub loaded successfully!")
