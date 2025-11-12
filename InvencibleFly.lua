-- Fly invencibleV3(ultima mejora, pishe script todo culero)

-- services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- player
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- CONFIG
local BASE_SPEED = 39.93
local BOOST_SPEEDS = {79.87, 199.66, 319.46}
local camera = workspace.CurrentCamera
local FOV_BASE = camera.FieldOfView
local FOV_LEVELS = {FOV_BASE + 10, FOV_BASE + 20, FOV_BASE + 30}

local TRANSPARENCY = 0.32
local FLY_ACTIVE_COLOR = Color3.fromRGB(0,255,0)
local BOOST_BASE_COLOR = Color3.fromRGB(0,137,255)
local FLY_INACTIVE_COLOR = Color3.fromRGB(255,42,42)

local SPEED_LERP = 8
local VEL_LERP = 8
local ROT_LERP = 10
local FOV_LERP = 6

local LEV_P2P = 2.4
local LEV_AMPL = LEV_P2P / 2
local LEV_FREQ = 0.6

local INPUT_DEADZONE = 0.08
local INPUT_TILT_MAX = 30
local INPUT_ROLL_MAX = 25
local CAMERA_TILT_INFLUENCE = 0.45
local CAMERA_ROLL_INFLUENCE = 0.9
local BOOST_PITCH_DEG = -90

-- STATE
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local hrp = character:WaitForChild("HumanoidRootPart")

local flying = false
local boostLevel = 0
local targetSpeed = BASE_SPEED
local currentSpeed = BASE_SPEED
local targetFOV = FOV_BASE

local levBaseY = hrp.Position.Y
local tAccum = 0
local currentCamRoll = 0
local wasMoving = false

-- Body movers vars
local bodyVel = nil
local bodyGyro = nil

-- Helper functions for body movers (unchanged)
local function createBodyMovers()
	if bodyVel and bodyVel.Parent == hrp then return end
	if bodyVel then pcall(function() bodyVel:Destroy() end) bodyVel = nil end
	if bodyGyro then pcall(function() bodyGyro:Destroy() end) bodyGyro = nil end

	bodyVel = Instance.new("BodyVelocity")  
	bodyVel.MaxForce = Vector3.new(1e5, 1e8, 1e5)  
	bodyVel.Velocity = Vector3.new(0,0,0)  
	bodyVel.Parent = hrp  

	bodyGyro = Instance.new("BodyGyro")  
	bodyGyro.MaxTorque = Vector3.new(4e6,4e6,4e6)  
	bodyGyro.P = 3000  
	bodyGyro.D = 200  
	bodyGyro.Parent = hrp
end

local function removeBodyMovers()
	if bodyVel then pcall(function() bodyVel:Destroy() end) bodyVel = nil end
	if bodyGyro then pcall(function() bodyGyro:Destroy() end) bodyGyro = nil end
end

-- Anim handling (kept)
local ANIMS = { BOOST_CYAN = 90872539 }
local animTracks = {}
local function createAnimation(id)
	local a = Instance.new("Animation")
	a.AnimationId = "rbxassetid://"..tostring(id)
	return a
end
local function safeLoad(hum, id)
	local ok, track = pcall(function() return hum:LoadAnimation(createAnimation(id)) end)
	if ok and track then track.Looped = true; return track end
	return nil
end

-- Yellow handlers (preserve logic / fix). These functions are required by boost logic.
local yellowSpeedConn = nil
local yellowFreezeTask = nil
local function clearYellowHandlers()
	if yellowSpeedConn then
		pcall(function() yellowSpeedConn:Disconnect() end)
		yellowSpeedConn = nil
	end
	yellowFreezeTask = nil
end

-- lock/unlock feet helpers (kept)
local lockedFeetData = {}
local function findFootParts(chr)
	local left, right = nil, nil
	left = chr:FindFirstChild("LeftFoot") or chr:FindFirstChild("Left Lower Leg") or chr:FindFirstChild("LeftLowerLeg")
	right = chr:FindFirstChild("RightFoot") or chr:FindFirstChild("Right Lower Leg") or chr:FindFirstChild("RightLowerLeg")
	if not left then left = chr:FindFirstChild("Left Leg") or chr:FindFirstChild("Left") end
	if not right then right = chr:FindFirstChild("Right Leg") or chr:FindFirstChild("Right") end
	return left, right
end
local function unlockFeet()
	for k,v in pairs(lockedFeetData) do
		pcall(function()
			if v.ap then v.ap:Destroy() end
			if v.ao then v.ao:Destroy() end
			if v.attFoot then v.attFoot:Destroy() end
			if v.attAnchor then v.attAnchor:Destroy() end
			if v.anchor then v.anchor:Destroy() end
		end)
		lockedFeetData[k] = nil
	end
end
local function lockFeet()
	unlockFeet()
	if not character then return end
	local leftFoot, rightFoot = findFootParts(character)
	if not leftFoot and not rightFoot then return end

	local function createLockFor(foot)  
		if not foot then return end  
		local anchor = Instance.new("Part")  
		anchor.Name = "FootAnchor_TMP"  
		anchor.Size = Vector3.new(0.2,0.2,0.2)  
		anchor.Transparency = 1  
		anchor.CanCollide = false  
		anchor.Anchored = true  
		anchor.CFrame = foot.CFrame  
		anchor.Parent = workspace  

		local attFoot = Instance.new("Attachment", foot)  
		attFoot.Name = "FootLock_Att_Foot"  

		local attAnchor = Instance.new("Attachment", anchor)  
		attAnchor.Name = "FootLock_Att_Anchor"  

		local ap = Instance.new("AlignPosition", foot)  
		ap.Name = "FootLock_AlignPos"  
		ap.Attachment0 = attFoot  
		ap.Attachment1 = attAnchor  
		ap.RigidityEnabled = false  
		ap.Responsiveness = 200  
		ap.MaxForce = 1e5  
		ap.MaxVelocity = math.huge  
		ap.Parent = foot  

		local ao = Instance.new("AlignOrientation", foot)  
		ao.Name = "FootLock_AlignOri"  
		ao.Attachment0 = attFoot  
		ao.Attachment1 = attAnchor  
		ao.Responsiveness = 200  
		ao.MaxTorque = 1e5  
		ao.Parent = foot  

		return {  
			anchor = anchor,  
			attFoot = attFoot,  
			attAnchor = attAnchor,  
			ap = ap,  
			ao = ao  
		}  
	end  

	if leftFoot then lockedFeetData.left = createLockFor(leftFoot) end  
	if rightFoot then lockedFeetData.right = createLockFor(rightFoot) end
end

-- Idle reverse and movement/boost track management (kept; identical to original)
local idleReverseConn = nil

local function loadAnimationsToHumanoid(hum)
	for _, track in pairs(animTracks) do pcall(function() track:Stop() end) end
	animTracks = {}

	animTracks.idle_main   = safeLoad(hum, 74909537)  
	animTracks.idle_second = safeLoad(hum, 203929876)  
	animTracks.idle_third  = safeLoad(hum, 97172005)  
	animTracks.idle_fourth = safeLoad(hum, 161235826)  

	if animTracks.idle_main then  
		pcall(function()  
			animTracks.idle_main.Looped = false  
			animTracks.idle_main.Priority = Enum.AnimationPriority.Action3  
			animTracks.idle_main:Play()  
			animTracks.idle_main:AdjustSpeed(0)  
			animTracks.idle_main:AdjustWeight(1)  
		end)  
	end  

	for _,k in ipairs({"idle_second","idle_third","idle_fourth"}) do  
		local t = animTracks[k]  
		if t then  
			pcall(function()  
				t.Looped = false  
				t:Play()  
				t:AdjustSpeed(0)  
				t.TimePosition = 0  
				t:AdjustWeight(0)  
			end)  
			if k == "idle_second" then pcall(function() t.Priority = Enum.AnimationPriority.Action3 end) end  
			if k == "idle_third" or k == "idle_fourth" then pcall(function() t.Priority = Enum.AnimationPriority.Action end) end  
		end  
	end  

	animTracks.forward_a = safeLoad(hum, 165167557)  
	animTracks.forward_b = safeLoad(hum, 97172005)  
	animTracks.forward_extra = safeLoad(hum, 161235826)  
	animTracks.side_a = safeLoad(hum, 27753183)  
	animTracks.side_b = safeLoad(hum, 21633130)  
	animTracks.backward_a = animTracks.side_a  
	animTracks.backward_b = animTracks.side_b  
	animTracks.boost_cyan = safeLoad(hum, ANIMS.BOOST_CYAN)  
	animTracks.boost_yellow = safeLoad(hum, 93693205)  
	animTracks.boost_red_prio = safeLoad(hum, 148831127)  
	animTracks.boost_red_sec = safeLoad(hum, 193342492)  

	if animTracks.forward_extra then  
		pcall(function()  
			animTracks.forward_extra.Looped = false  
			animTracks.forward_extra:Play()  
			animTracks.forward_extra:AdjustSpeed(0)  
			animTracks.forward_extra.TimePosition = 0  
			animTracks.forward_extra:AdjustWeight(0)  
			animTracks.forward_extra.Priority = Enum.AnimationPriority.Action  
		end)  
	end
end

local function stopAllMovementTracks()
	if idleReverseConn then pcall(function() idleReverseConn:Disconnect() end) idleReverseConn = nil end
	for _,v in ipairs({
		"idle_main","idle_second","idle_third","idle_fourth",
		"forward_a","forward_b","forward_extra","backward_a","backward_b","side_a","side_b"
	}) do
		local t = animTracks[v]
		if t and t.IsPlaying then
			pcall(function() t:Stop() end)
		end
	end
	for _,k in ipairs({"idle_second","idle_third","idle_fourth"}) do
		local t = animTracks[k]
		if t then pcall(function() t:AdjustWeight(0) end) end
	end
end

local function stopAllBoostTracks()
	if yellowSpeedConn then pcall(function() yellowSpeedConn:Disconnect() end) yellowSpeedConn = nil end
	yellowFreezeTask = nil

	for _,v in ipairs({"boost_cyan","boost_yellow","boost_red_prio","boost_red_sec"}) do  
		local t = animTracks[v]  
		if t and t.IsPlaying then pcall(function() t:Stop() end) end  
	end  
	pcall(unlockFeet)
end

local currentMovementState = nil
local currentBoostState = 0

local function startIdleReverse()
	if idleReverseConn then pcall(function() idleReverseConn:Disconnect() end) idleReverseConn = nil end

	local main = animTracks.idle_main  
	local s2 = animTracks.idle_second  
	local s3 = animTracks.idle_third  
	local s4 = animTracks.idle_fourth  

	if not main then  
		if s2 then pcall(function() s2:Play(); s2.TimePosition = 0; s2:AdjustSpeed(0); s2.Priority = Enum.AnimationPriority.Action3; s2:AdjustWeight(1,0.1) end) end  
		if s3 then pcall(function() s3:Play(); s3.TimePosition = 0; s3:AdjustSpeed(0); s3.Priority = Enum.AnimationPriority.Action; s3:AdjustWeight(1,0.1) end) end  
		if s4 then pcall(function() s4:Play(); s4.TimePosition = 0; s4:AdjustSpeed(0); s4.Priority = Enum.AnimationPriority.Action; s4:AdjustWeight(1,0.1) end) end  
		return  
	end  

	if s2 then pcall(function() s2:Play(); s2.TimePosition = 0; s2:AdjustSpeed(0); s2:AdjustWeight(0); s2.Priority = Enum.AnimationPriority.Action3 end) end  
	if s3 then pcall(function() s3:Play(); s3.TimePosition = 0; s3:AdjustSpeed(0); s3:AdjustWeight(0); s3.Priority = Enum.AnimationPriority.Action end) end  
	if s4 then pcall(function() s4:Play(); s4.TimePosition = 0; s4:AdjustSpeed(0); s4:AdjustWeight(0); s4.Priority = Enum.AnimationPriority.Action end) end  

	pcall(function()  
		main.Looped = false  
		main.Priority = Enum.AnimationPriority.Action3  
		main:Play()  
		main:AdjustSpeed(0)  
		main:AdjustWeight(1)  
	end)  

	task.wait()  

	local ok, animLength = pcall(function() return main.Length end)  
	animLength = (ok and type(animLength) == "number" and animLength > 0) and animLength or 0  

	if animLength <= 0 then  
		if s2 then pcall(function() s2:AdjustWeight(1,0.1) end) end  
		if s3 then pcall(function() s3:AdjustWeight(1,0.1) end) end  
		if s4 then pcall(function() s4:AdjustWeight(1,0.1) end) end  
		return  
	end  

	local REVERSE_SPEED = 33  
	local FREEZE_AT = 0.370  

	local currentTime = animLength  
	pcall(function() main.TimePosition = currentTime end)  

	local isFrozen = false  
	idleReverseConn = RunService.Heartbeat:Connect(function(deltaTime)  
		if not main or isFrozen == true then return end  
		local timeStep = deltaTime * REVERSE_SPEED  
		currentTime = currentTime - timeStep  
		if currentTime <= FREEZE_AT then  
			currentTime = FREEZE_AT  
			pcall(function()  
				main.TimePosition = FREEZE_AT  
				main:AdjustSpeed(0)  
			end)  
			isFrozen = true  
			if s2 then pcall(function() s2:AdjustWeight(1, 0.1) end) end  
			if s3 then pcall(function() s3:AdjustWeight(1, 0.1) end) end  
			if s4 then pcall(function() s4:AdjustWeight(1, 0.1) end) end  
			if idleReverseConn then pcall(function() idleReverseConn:Disconnect() end) idleReverseConn = nil end  
		else  
			pcall(function() main.TimePosition = currentTime end)  
		end  
	end)
end

local function playMovementTrack(state)
	if currentMovementState == state then return end
	if currentMovementState == "idle" and state ~= "idle" then
		if idleReverseConn then pcall(function() idleReverseConn:Disconnect() end) idleReverseConn = nil end
		for _,k in ipairs({"idle_second","idle_third","idle_fourth"}) do
			local t = animTracks[k]
			if t then pcall(function() t:AdjustWeight(0) end) end
		end
	end

	stopAllMovementTracks()  
	currentMovementState = state  
	if state == "idle" then  
		startIdleReverse()  
	else  
		if state == "forward" then  
			local a,b,e = animTracks.forward_a, animTracks.forward_b, animTracks.forward_extra  
			if a then a:Play(); pcall(function() a.TimePosition = 0; a:AdjustSpeed(0); a.Priority = Enum.AnimationPriority.Action3; a:AdjustWeight(1) end) end  
			if b then b:Play(); pcall(function() b.TimePosition = 0; b:AdjustSpeed(0); b.Priority = Enum.AnimationPriority.Action3; b:AdjustWeight(1) end) end  
			if e then e:Play(); pcall(function() e.TimePosition = 0; e:AdjustSpeed(0); e.Priority = Enum.AnimationPriority.Action; e:AdjustWeight(1) end) end  
		elseif state == "backward" then  
			local a,b = animTracks.backward_a, animTracks.backward_b  
			if a then a:Play(); pcall(function() a.TimePosition = 0; a:AdjustSpeed(0); a.Priority = Enum.AnimationPriority.Action3; a:AdjustWeight(1) end) end  
			if b then b:Play(); pcall(function() b.TimePosition = 0; b:AdjustSpeed(0); b.Priority = Enum.AnimationPriority.Action3; b:AdjustWeight(1) end) end  
		elseif state == "side" then  
			local a,b = animTracks.side_a, animTracks.side_b  
			if a then a:Play(); pcall(function() a.TimePosition = 0; a:AdjustSpeed(0); a.Priority = Enum.AnimationPriority.Action3; a:AdjustWeight(1) end) end  
			if b then b:Play(); pcall(function() b.TimePosition = 0; b:AdjustSpeed(0); b.Priority = Enum.AnimationPriority.Action3; b:AdjustWeight(1) end) end  
		end  
	end
end

-- UI CREATION: (tu UI original, sin cambios conceptuales)
local existingGui = playerGui:FindFirstChild("FlyBoostUI")
if existingGui then existingGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FlyBoostUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local function makeShadow(name, x,y,w,h,transp,corner)
	local f = Instance.new("Frame")
	f.Name = name
	f.Position = UDim2.new(0, x, 0, y)
	f.Size = UDim2.new(0, w, 0, h)
	f.BackgroundColor3 = Color3.fromRGB(0,0,0)
	f.BackgroundTransparency = transp
	f.BorderSizePixel = 0
	f.ZIndex = 0
	f.Parent = screenGui
	local c = Instance.new("UICorner", f)
	c.CornerRadius = UDim.new(0, corner)
	return f
end

makeShadow("Shadow1", 972, 125, 176, 177, 0.997, 28)
makeShadow("Shadow2", 972, 127, 176, 173, 0.977, 26)
makeShadow("Shadow3", 972, 129, 176, 169, 0.949, 24)
makeShadow("Shadow4", 972, 131, 176, 165, 0.929, 22)
makeShadow("Shadow5", 972, 133, 176, 161, 0.909, 20)
makeShadow("Shadow6", 972, 135, 176, 157, 0.889, 18)

local background = Instance.new("Frame")
background.Name = "Background"
background.Position = UDim2.new(0, 972, 0, 137)
background.Size = UDim2.new(0, 176, 0, 153)
background.BackgroundColor3 = Color3.fromRGB(0,0,0)
background.BackgroundTransparency = 0.909
background.BorderSizePixel = 0
background.ZIndex = 0
background.Parent = screenGui
local backgroundCorner = Instance.new("UICorner", background)
backgroundCorner.CornerRadius = UDim.new(0, 16)

-- BOOST
local boostButton = Instance.new("TextButton")
boostButton.Name = "BoostButton"
boostButton.Position = UDim2.new(0, 976, 0, 140)
boostButton.Size = UDim2.new(0, 168, 0, 74)
boostButton.BackgroundColor3 = Color3.fromRGB(0, 115, 216)
boostButton.BackgroundTransparency = 0.25
boostButton.BorderSizePixel = 0
boostButton.Text = "BOOST"
boostButton.TextColor3 = Color3.fromRGB(219, 219, 230)
boostButton.TextSize = 51
boostButton.Font = Enum.Font.ArialBold
boostButton.TextStrokeTransparency = 0
boostButton.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
boostButton.ZIndex = 1
boostButton.Parent = screenGui
local boostCorner = Instance.new("UICorner", boostButton)
boostCorner.CornerRadius = UDim.new(1,0)

-- FLY
local flyButton = Instance.new("TextButton")
flyButton.Name = "FlyButton"
flyButton.Position = UDim2.new(0, 976, 0, 215)
flyButton.Size = UDim2.new(0, 168, 0, 74)
flyButton.BackgroundColor3 = Color3.fromRGB(203, 40, 40)
flyButton.BackgroundTransparency = 0.25
flyButton.BorderSizePixel = 0
flyButton.Text = "FLY"
flyButton.TextColor3 = Color3.fromRGB(219, 219, 230)
flyButton.TextSize = 69
flyButton.Font = Enum.Font.ArialBold
flyButton.TextStrokeTransparency = 0
flyButton.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
flyButton.ZIndex = 1
flyButton.Parent = screenGui
local flyCorner = Instance.new("UICorner", flyButton)
flyCorner.CornerRadius = UDim.new(1,0)

-- Boost indicator capsule
local boostIndicator = Instance.new("Frame")
boostIndicator.Name = "BoostIndicator"
boostIndicator.Position = UDim2.new(0, 967, 0, 190)
boostIndicator.Size = UDim2.new(0, 54, 0, 28)
boostIndicator.BackgroundColor3 = Color3.fromRGB(255,255,255)
boostIndicator.BackgroundTransparency = 0.28
boostIndicator.BorderSizePixel = 0
boostIndicator.Visible = false
boostIndicator.ZIndex = 2
boostIndicator.Parent = screenGui
local indicatorCorner = Instance.new("UICorner", boostIndicator)
indicatorCorner.CornerRadius = UDim.new(1,0)

-- UI state vars
local flyActive_ui = false          -- UI's local fly state (keeps in sync with flying)
local isAnimating = false
local indicatorColors = {
	[0] = Color3.fromRGB(255,255,255),
	[1] = Color3.fromRGB(100,150,180),
	[2] = Color3.fromRGB(255,204,0),
	[3] = Color3.fromRGB(255,0,0)
}
local originalBoostSize = UDim2.new(0,168,0,74)
local originalBoostPos  = UDim2.new(0,976,0,140)
local originalFlySize   = UDim2.new(0,168,0,74)
local originalFlyPos    = UDim2.new(0,976,0,215)
local originalIndicatorSize = UDim2.new(0,54,0,28)
local originalIndicatorPos  = UDim2.new(0,967,0,190)

-- UI animation helpers (kept)
local function animateButton(button, originalSize, originalPos)
	if isAnimating then return end
	isAnimating = true
	local sizeReduction = UDim2.new(0,14,0,14)
	local positionOffset = UDim2.new(0,7,0,7)

	local tweenInfoDown = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)  
	local goal = { Size = originalSize - sizeReduction, Position = originalPos + positionOffset }  
	local tween = TweenService:Create(button, tweenInfoDown, goal)  
	tween:Play()  
	tween.Completed:Wait()  

	local tweenInfoBack = TweenInfo.new(0.12, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)  
	local goalBack = { Size = originalSize, Position = originalPos }  
	local tweenBack = TweenService:Create(button, tweenInfoBack, goalBack)  
	tweenBack:Play()  
	tweenBack.Completed:Connect(function()  
		isAnimating = false  
	end)
end

local function animateHover(button, isHovering, originalSize, originalPos)
	local sizeChange = UDim2.new(0,3,0,3)
	local positionChange = UDim2.new(0,1.5,0,1.5)

	local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)  
	if isHovering then  
		local goal = { Size = originalSize - sizeChange, Position = originalPos + positionChange, BackgroundTransparency = 0.15 }  
		local tween = TweenService:Create(button, tweenInfo, goal)  
		tween:Play()  
	else  
		local goal = { Size = originalSize, Position = originalPos, BackgroundTransparency = 0.25 }  
		local tween = TweenService:Create(button, tweenInfo, goal)  
		tween:Play()  
	end
end

local function animateIndicator()
	local sizeReduction = UDim2.new(0,4,0,4)
	local positionOffset = UDim2.new(0,2,0,2)
	local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local goalDown = { Size = originalIndicatorSize - sizeReduction, Position = originalIndicatorPos + positionOffset }
	local tweenDown = TweenService:Create(boostIndicator, tweenInfo, goalDown)
	tweenDown:Play()
	tweenDown.Completed:Wait()
	local tweenInfoBack = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local goalBack = { Size = originalIndicatorSize, Position = originalIndicatorPos }
	local tweenBack = TweenService:Create(boostIndicator, tweenInfoBack, goalBack)
	tweenBack:Play()
end

-- keep setBoostIndicatorByLevel function (from original)
local function setBoostIndicatorByLevel(level)
	if level == 0 then
		TweenService:Create(boostIndicator, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(255,255,255), Size = UDim2.new(0,52,0,32)}):Play()
	elseif level == 1 then
		TweenService:Create(boostIndicator, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(173,216,230), Size = UDim2.new(0,62,0,32)}):Play()
	elseif level == 2 then
		TweenService:Create(boostIndicator, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(255,204,0), Size = UDim2.new(0,70,0,32)}):Play()
	elseif level == 3 then
		TweenService:Create(boostIndicator, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(220,20,60), Size = UDim2.new(0,78,0,32)}):Play()
	end
end

local function updateBoostIndicatorUI()
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local goal = { BackgroundColor3 = indicatorColors[boostLevel] or indicatorColors[0] }
	TweenService:Create(boostIndicator, tweenInfo, goal):Play()
	animateIndicator()
end

local function updateIndicatorVisibilityUI()
	boostIndicator.Visible = flyActive_ui
end

-- Input helpers (kept)
local function camBasisFull() local cam = camera.CFrame return cam.LookVector, cam.RightVector end
local function getMobileAxes()
	local md = humanoid.MoveDirection
	if md.Magnitude < 0.01 then return 0,0,0 end
	local camLook, camRight = camBasisFull()
	local fwdFlat = Vector3.new(camLook.X,0,camLook.Z); if fwdFlat.Magnitude>0 then fwdFlat = fwdFlat.Unit end
	local rightFlat = Vector3.new(camRight.X,0,camRight.Z); if rightFlat.Magnitude>0 then rightFlat = rightFlat.Unit end
	return md:Dot(fwdFlat), md:Dot(rightFlat), md.Magnitude
end
local function getKeyboardAxes()
	local f = 0; local r = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then f = f + 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then f = f - 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then r = r + 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then r = r - 1 end
	return f, r
end
local function isPlayerMoving()
	if humanoid and humanoid.MoveDirection and humanoid.MoveDirection.Magnitude > INPUT_DEADZONE then return true end
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.A)
	or UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.D) then
		return true
	end
	return false
end

-- Boost Yellow routine (preserved)
local function startYellowRoutine(track)
	if not track then return end
	clearYellowHandlers()
	local CONSTANT_SPEED = 33
	local freezeScheduled = false

	yellowSpeedConn = RunService.Heartbeat:Connect(function()  
		if track and track.IsPlaying and not freezeScheduled then  
			if track.Speed ~= CONSTANT_SPEED then  
				pcall(function() track:AdjustSpeed(CONSTANT_SPEED) end)  
			end  
		end  
	end)  

	pcall(function() track:Play(); track:AdjustSpeed(CONSTANT_SPEED); track.Priority = Enum.AnimationPriority.Action end)  

	yellowFreezeTask = coroutine.create(function()  
		local ok, length = pcall(function() return track.Length end)  
		local animLength = (ok and type(length) == "number" and length > 0) and length or 0  
		local freezePoint = math.max(0, animLength - 0.05)  
		local adjusted = (animLength > 0) and (freezePoint / CONSTANT_SPEED) or 0.02  
		wait(adjusted)  
		freezeScheduled = true  
		clearYellowHandlers()  
		pcall(function() track:AdjustSpeed(0); track:AdjustWeight(1) end)  
	end)  
	coroutine.resume(yellowFreezeTask)
end

-- playBoostTrack (keeps original behavior but uses UI indicator)
local function playBoostTrack(level)
	if currentBoostState == level then return end
	stopAllBoostTracks()
	currentBoostState = level
	setBoostIndicatorByLevel(level)
	-- Also update simple UI color/size
	boostLevel = level
	updateBoostIndicatorUI()

	if level == 0 then return end  

	if level == 1 then  
		local t = animTracks.boost_cyan  
		if t then pcall(function() t.Priority = Enum.AnimationPriority.Action; t:Play(); t:AdjustSpeed(1) end) end  

	elseif level == 2 then  
		local t = animTracks.boost_yellow  
		if t then startYellowRoutine(t) end  

	elseif level == 3 then  
		local pr = animTracks.boost_red_prio  
		local sc = animTracks.boost_red_sec  
		if pr then pcall(function() pr.Priority = Enum.AnimationPriority.Action4; pr:Play(); pr:AdjustSpeed(0); pr.TimePosition = 0; pr:AdjustWeight(1) end) end  
		if sc then pcall(function() sc.Priority = Enum.AnimationPriority.Action3; sc:Play(); sc:AdjustSpeed(0); sc.TimePosition = 0; sc:AdjustWeight(1) end) end  
	end
end

-- Helper: actualiza la animación de movimiento según input (usada cuando boost se apaga)
local function updateMovementFromInput()
	local kbF,kbR = getKeyboardAxes()
	local mF,mR,mMag = getMobileAxes()
	local fwdAxis = kbF + mF
	local rightAxis = kbR + mR
	local inputMag = math.sqrt(fwdAxis*fwdAxis + rightAxis*rightAxis)

	if inputMag < INPUT_DEADZONE then
		playMovementTrack("idle")
	else
		if math.abs(rightAxis) > math.abs(fwdAxis) and math.abs(rightAxis) > 0.15 then
			playMovementTrack("side")
		else
			if fwdAxis > 0.25 then playMovementTrack("forward")
			elseif fwdAxis < -0.25 then playMovementTrack("backward")
			else playMovementTrack("side") end
		end
	end
end

-- INITIAL: ensure anims loaded
loadAnimationsToHumanoid(humanoid)

-- Sync UI initial text/colors with flight state
flyButton.Text = "FLY"
boostButton.Text = "BOOST"
flyButton.BackgroundColor3 = Color3.fromRGB(203,40,40)
boostIndicator.Visible = false
setBoostIndicatorByLevel(0)

-- ---------- CONNECT UI EVENTS TO FLIGHT LOGIC ----------

-- When UI fly button is clicked: toggle flight state (red: off; green: on)
flyButton.MouseButton1Click:Connect(function()
	animateButton(flyButton, originalFlySize, originalFlyPos)

	-- toggle UI state  
	flyActive_ui = not flyActive_ui  
	updateIndicatorVisibilityUI()  

	-- animate color change on the button  
	local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)  
	local colorGoal = flyActive_ui and {BackgroundColor3 = FLY_ACTIVE_COLOR} or {BackgroundColor3 = Color3.fromRGB(203,40,40)}  
	TweenService:Create(flyButton, tweenInfo, colorGoal):Play()  

	-- Now toggle the actual flight logic to match UI:  
	if flyActive_ui and not flying then  
		-- Activate flight logic  
		flying = true  
		levBaseY = hrp.Position.Y  
		tAccum = 0  
		wasMoving = isPlayerMoving()  
		createBodyMovers()  
		humanoid.PlatformStand = true  
		if not next(animTracks) then loadAnimationsToHumanoid(humanoid) end  
		playMovementTrack("idle")  
		playBoostTrack(boostLevel)  
		flyButton.Text = "FLY"  
		-- ensure indicator visible & current level applied  
		boostIndicator.Visible = true  
		setBoostIndicatorByLevel(boostLevel)  
	elseif not flyActive_ui and flying then  
		-- Deactivate flight logic  
		flying = false  
		removeBodyMovers()  
		humanoid.PlatformStand = false  
		stopAllBoostTracks(); stopAllMovementTracks()  
		currentMovementState = nil; currentBoostState = 0; boostLevel = 0  
		targetSpeed = BASE_SPEED; targetFOV = FOV_BASE  
		flyButton.Text = "FLY"  
		-- reset UI indicator  
		boostIndicator.Visible = false  
		setBoostIndicatorByLevel(0)  
	end
end)

-- Hover animations on FLY (optional for mouse)
flyButton.MouseEnter:Connect(function()
	if not isAnimating then animateHover(flyButton, true, originalFlySize, originalFlyPos) end
end)
flyButton.MouseLeave:Connect(function()
	if not isAnimating then animateHover(flyButton, false, originalFlySize, originalFlyPos) end
end)

-- BOOST button behavior (MODIFICADO: solo activa si flying==true y jugador está en movimiento)
boostButton.MouseButton1Click:Connect(function()
	animateButton(boostButton, originalBoostSize, originalBoostPos)

	-- Only change boost while flight is active AND player is moving
	if not flying then
		-- vuelo no activo -> no hacemos nada
		return
	end

	-- exige que el jugador esté en movimiento para subir/ciclar boost
	if not isPlayerMoving() then
		-- si no hay movimiento, no permitimos activar boost
		-- (si quieres feedback visual aquí, lo podemos agregar)
		return
	end

	-- Ciclar boost
	boostLevel = (boostLevel + 1) % 4
	-- update flight internals
	if boostLevel == 0 then
		targetSpeed = BASE_SPEED; targetFOV = FOV_BASE
	else
		targetSpeed = BOOST_SPEEDS[boostLevel]; targetFOV = FOV_LEVELS[boostLevel]
	end
	-- apply the visual indicator & play boost anims
	setBoostIndicatorByLevel(boostLevel)
	playBoostTrack(boostLevel)

	-- Si boost se desactiva (al pasar a 0) forzamos que vuelvan las anims normales
	if boostLevel == 0 then
		-- actualizar anims de movimiento según input (repara bug 4º click)
		updateMovementFromInput()
	end
end)

boostButton.MouseEnter:Connect(function()
	if not isAnimating then animateHover(boostButton, true, originalBoostSize, originalBoostPos) end
end)
boostButton.MouseLeave:Connect(function()
	if not isAnimating then animateHover(boostButton, false, originalBoostSize, originalBoostPos) end
end)

-- ---------- INPUT / MAIN LOOP (unchanged flight loop behavior, con reset de boost cuando cesa movimiento) ----------
RunService.RenderStepped:Connect(function(dt)
	tAccum = tAccum + dt
	currentSpeed = currentSpeed + (targetSpeed - currentSpeed) * math.clamp(dt * SPEED_LERP, 0, 1)
	camera.FieldOfView = camera.FieldOfView + (targetFOV - camera.FieldOfView) * math.clamp(dt * FOV_LERP, 0, 1)

	local movingNow = isPlayerMoving()  
	if wasMoving and not movingNow then  
		if boostLevel ~= 0 then  
			boostLevel = 0  
			targetSpeed = BASE_SPEED  
			targetFOV = FOV_BASE  
			playBoostTrack(0)  
			-- ensure normal flight anims resume when movement stops
			playMovementTrack("idle")  
		end  
	end  
	wasMoving = movingNow  

	if not flying then  
		currentCamRoll = currentCamRoll + (0 - currentCamRoll) * math.clamp(dt * 8, 0, 1)  
		local camPos = camera.CFrame.Position  
		local camLookVec = camera.CFrame.LookVector  
		local desiredCamCFrame = CFrame.lookAt(camPos, camPos + camLookVec, Vector3.new(0,1,0)) * CFrame.Angles(0,0,currentCamRoll)  
		camera.CFrame = camera.CFrame:Lerp(desiredCamCFrame, math.clamp(dt * 8, 0, 1))  
		if bodyVel then bodyVel.MaxForce = Vector3.new(0,0,0); bodyVel.Velocity = Vector3.new(0,0,0) end  
		if bodyGyro then bodyGyro.MaxTorque = Vector3.new(0,0,0) end  
		return  
	end  

	local omega = 2 * math.pi * LEV_FREQ  
	local levDisp = LEV_AMPL * math.sin(omega * tAccum)  
	local levVel = LEV_AMPL * omega * math.cos(omega * tAccum)  

	local kbF, kbR = getKeyboardAxes()  
	local mF, mR, mMag = getMobileAxes()  
	local fwdAxis = kbF + mF  
	local rightAxis = kbR + mR  
	local inputMag = math.sqrt(fwdAxis*fwdAxis + rightAxis*rightAxis)  

	if inputMag < INPUT_DEADZONE then  
		local targetVel = Vector3.new(0, levVel, 0)  
		if bodyVel then bodyVel.Velocity = bodyVel.Velocity:Lerp(targetVel, math.clamp(dt * (VEL_LERP*1.3), 0, 1)) end  
	else  
		local camLook, camRight = camBasisFull()  
		local dir = camLook * fwdAxis + camRight * rightAxis  
		if dir.Magnitude > 0.0001 then  
			dir = dir.Unit  
			local scale = math.min(1, inputMag)  
			local moveVel = dir * currentSpeed * scale  
			local targetVel = Vector3.new(moveVel.X, moveVel.Y + levVel, moveVel.Z)  
			if bodyVel then bodyVel.Velocity = bodyVel.Velocity:Lerp(targetVel, math.clamp(dt * VEL_LERP, 0, 1)) end  
		end  
	end  

	local camLook = camera.CFrame.LookVector  
	local desiredCFrameBase = CFrame.lookAt(hrp.Position, hrp.Position + camLook, Vector3.new(0,1,0))  

	local tiltForward = 0  
	local tiltSide = 0  
	if inputMag > INPUT_DEADZONE then  
		local nx = fwdAxis / math.max(1, inputMag)  
		local ny = rightAxis / math.max(1, inputMag)  
		tiltForward = -INPUT_TILT_MAX * math.clamp(nx, -1, 1)  
		tiltSide = INPUT_ROLL_MAX * math.clamp(ny, -1, 1) * -1  
	end  

	local finalTiltForward = tiltForward  
	local finalTiltSide = tiltSide  
	if boostLevel > 0 and inputMag > INPUT_DEADZONE then finalTiltForward = BOOST_PITCH_DEG end  

	local cameraPitchDeg = math.deg(math.asin(math.clamp(camera.CFrame.LookVector.Y, -1, 1)))  
	local cameraTiltContribution = -cameraPitchDeg * CAMERA_TILT_INFLUENCE  
	finalTiltForward = finalTiltForward + cameraTiltContribution  
	finalTiltForward = math.clamp(finalTiltForward, -90, 90)  
	finalTiltSide = math.clamp(finalTiltSide, -45, 45)  

	local tiltCFrame = CFrame.Angles(math.rad(finalTiltForward), 0, math.rad(finalTiltSide))  
	local desiredBodyCFrame = desiredCFrameBase * tiltCFrame  
	if bodyGyro then  
		bodyGyro.CFrame = bodyGyro.CFrame:Lerp(desiredBodyCFrame, math.clamp(dt * ROT_LERP, 0, 1))  
		bodyGyro.P = 3000; bodyGyro.D = 200  
	end  

	local targetCamRoll = math.rad(finalTiltSide) * CAMERA_ROLL_INFLUENCE  
	currentCamRoll = currentCamRoll + (targetCamRoll - currentCamRoll) * math.clamp(dt * 8, 0, 1)  
	local camPos = camera.CFrame.Position  
	local camLookVec = camera.CFrame.LookVector  
	local desiredCamCFrame2 = CFrame.lookAt(camPos, camPos + camLookVec, Vector3.new(0,1,0)) * CFrame.Angles(0,0,currentCamRoll)  
	camera.CFrame = camera.CFrame:Lerp(desiredCamCFrame2, math.clamp(dt * 8, 0, 1))  

	-- anims  
	if boostLevel > 0 then  
		playBoostTrack(boostLevel)  
		stopAllMovementTracks()  
	else  
		playBoostTrack(0)  
		if inputMag < INPUT_DEADZONE then  
			playMovementTrack("idle")  
		else  
			if math.abs(rightAxis) > math.abs(fwdAxis) and math.abs(rightAxis) > 0.15 then  
				playMovementTrack("side")  
			else  
				if fwdAxis > 0.25 then playMovementTrack("forward")  
				elseif fwdAxis < -0.25 then playMovementTrack("backward")  
				else playMovementTrack("side") end  
			end  
		end  
	end
end)

-- Death / respawn handling (kept)
humanoid.Died:Connect(function()
	if flying then
		flying = false
		removeBodyMovers()
		humanoid.PlatformStand = false
		stopAllBoostTracks(); stopAllMovementTracks()
		currentMovementState = nil; currentBoostState = 0; boostLevel = 0
		targetSpeed = BASE_SPEED; targetFOV = FOV_BASE
		flyButton.Text = "FLY"
		flyButton.BackgroundColor3 = Color3.fromRGB(203,40,40)
		boostIndicator.Visible = false
		setBoostIndicatorByLevel(0)
	end
end)

player.CharacterAdded:Connect(function(char)
	character = char
	humanoid = character:WaitForChild("Humanoid")
	hrp = character:WaitForChild("HumanoidRootPart")
	removeBodyMovers()
	-- reparent GUI to PlayerGui in case of respawn
	screenGui.Parent = player:WaitForChild("PlayerGui")
	flying = false
	humanoid.PlatformStand = false
	stopAllBoostTracks(); stopAllMovementTracks()
	animTracks = {}
	loadAnimationsToHumanoid(humanoid)
	currentMovementState = nil; currentBoostState = 0; boostLevel = 0
	targetSpeed = BASE_SPEED; targetFOV = FOV_BASE
	flyButton.Text = "FLY"
	flyButton.BackgroundColor3 = Color3.fromRGB(203,40,40)
	boostIndicator.Visible = false
	setBoostIndicatorByLevel(0)
end)

-- ---------- RefreshAnims (kept as you requested) ----------
local function refreshConstantly(duration)
	local startTime = tick()
	while tick() - startTime < duration do
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			local playingTracks = animator:GetPlayingAnimationTracks()
			for _, track in pairs(playingTracks) do
				track:Stop(0)
				track:Destroy()
			end
		end
		task.wait()
	end
	print("Refresco de animaciones completado")
end

-- run the refresher at start and on respawn (already wired above for CharacterAdded)
refreshConstantly(0.3)

print("Vuelo de inservible, cargado correctamente")


-- Refresco de animaciones inicial(no borrar porfavor, es util)

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

-- Función para refrescar constantemente durante un tiempo determinado
local function refreshConstantly(duration)
	local startTime = tick()
	
	while tick() - startTime < duration do
		-- Obtener el Animator del Humanoid
		local animator = humanoid:FindFirstChildOfClass("Animator")
		
		if animator then
			-- Detener todas las animaciones en reproducción
			local playingTracks = animator:GetPlayingAnimationTracks()
			
			for _, track in pairs(playingTracks) do
				track:Stop(0) -- Detener inmediatamente
				track:Destroy()
			end
		end
		
		task.wait() -- Esperar un frame antes de refrescar de nuevo
	end
	
	print("Refresco de animaciones completado")
end

-- Ejecutar el refresco constante al inicio
refreshConstantly(0.3)

-- Refrescar animaciones constantemente cada vez que el personaje reaparece
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid")
	refreshConstantly(0.3)
end)
