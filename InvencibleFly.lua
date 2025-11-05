-- Flight v6.4 - Final completo (BoostRed sin lockFeet + forward_extra 161235826 + Idle REVERSE 4-anims)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local hrp = character:WaitForChild("HumanoidRootPart")
local camera = workspace.CurrentCamera

-- CONFIG
local BASE_SPEED = 39.93
local BOOST_SPEEDS = {79.87, 199.66, 319.46}
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
local flying = false
local boostLevel = 0
local targetSpeed = BASE_SPEED
local currentSpeed = BASE_SPEED
local targetFOV = FOV_BASE

local levBaseY = hrp.Position.Y
local tAccum = 0
local currentCamRoll = 0
local wasMoving = false

-- Body movers variables
local bodyVel = nil
local bodyGyro = nil

-- UI
local gui = Instance.new("ScreenGui")
gui.Name = "FlightUI_v6_final_match"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local container = Instance.new("Frame", gui)
container.Name = "FlightContainer"
container.Size = UDim2.new(0, 220, 0, 150)
container.Position = UDim2.new(1, -20, 0.5, 0)
container.AnchorPoint = Vector2.new(1, 0.5)
container.BackgroundTransparency = 1

local backgroundBox = Instance.new("Frame", container)
backgroundBox.Name = "BackgroundBox"
backgroundBox.Size = UDim2.new(0, 205, 0, 150)
backgroundBox.Position = UDim2.new(0, 0, 0, 0)
backgroundBox.AnchorPoint = Vector2.new(0, 0)
backgroundBox.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
backgroundBox.BackgroundTransparency = 0.7
backgroundBox.BorderSizePixel = 0
backgroundBox.ZIndex = 1
local bgCorner = Instance.new("UICorner", backgroundBox)
bgCorner.CornerRadius = UDim.new(0, 12)
local bgGradient = Instance.new("UIGradient", backgroundBox)
bgGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.4),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(1, 0.4)
})
bgGradient.Rotation = 0

local function makeCapsuleButton(name, text, color, posY, width, height)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = UDim2.new(0, width, 0, height)
	b.Position = UDim2.new(0, 0, 0, posY)
	b.BackgroundColor3 = color
	b.BackgroundTransparency = TRANSPARENCY
	b.Text = text
	b.TextColor3 = Color3.new(1,1,1)
	b.Font = Enum.Font.SourceSansBold
	b.TextSize = 32
	b.AutoButtonColor = false
	b.AnchorPoint = Vector2.new(0,0)
	b.BorderSizePixel = 0
	b.ZIndex = 2
	b.TextStrokeTransparency = 0
	b.TextStrokeColor3 = Color3.new(0,0,0)
	local corner = Instance.new("UICorner", b)
	corner.CornerRadius = UDim.new(0.5, 0)
	b.Parent = container
	return b
end

local IMPULSO_WIDTH = 205
local IMPULSO_HEIGHT = 75
local FLY_WIDTH = 205
local FLY_HEIGHT = 75

local impulsoBtn = makeCapsuleButton("ImpulsoBtn", "IMPULSO", BOOST_BASE_COLOR, 0, IMPULSO_WIDTH, IMPULSO_HEIGHT)
local flyBtn = makeCapsuleButton("FlyBtn", "Fly OFF", FLY_INACTIVE_COLOR, 75, FLY_WIDTH, FLY_HEIGHT)

-- Boost indicator (ZIndex alto)
local boostIndicator = Instance.new("Frame", container)
boostIndicator.Name = "BoostIndicator"
boostIndicator.Size = UDim2.new(0, 52, 0, 32)
boostIndicator.Position = UDim2.new(0, -26, 0, 59)
boostIndicator.AnchorPoint = Vector2.new(0, 0)
boostIndicator.BackgroundColor3 = Color3.fromRGB(255,255,255)
boostIndicator.BackgroundTransparency = 0.25
boostIndicator.BorderSizePixel = 0
boostIndicator.ZIndex = 5
container.ChildAdded:Connect(function() pcall(function() boostIndicator.ZIndex = 5 end) end)
local indCorner = Instance.new("UICorner", boostIndicator)
indCorner.CornerRadius = UDim.new(0.5, 0)

local activeTweens = {}
local function safeBounce(btn)
	local scale = btn:FindFirstChild("UIButtonScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "UIButtonScale"
		scale.Scale = 1
		scale.Parent = btn
	end
	if activeTweens[btn] then
		pcall(function() activeTweens[btn]:Cancel() end)
		activeTweens[btn] = nil
	end
	local upTween = TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Scale = 1.08})
	local downTween = TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Scale = 1})
	activeTweens[btn] = upTween
	upTween:Play()
	upTween.Completed:Connect(function()
		activeTweens[btn] = downTween
		downTween:Play()
		downTween.Completed:Connect(function() activeTweens[btn] = nil end)
	end)
end

local function tween(obj, props, t) t = t or 0.28 TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), props):Play() end

-- Body movers management
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

-- Anim handling
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

-- Yellow handlers
local yellowSpeedConn = nil
local yellowFreezeTask = nil
local function clearYellowHandlers()
	if yellowSpeedConn then
		pcall(function() yellowSpeedConn:Disconnect() end)
		yellowSpeedConn = nil
	end
	yellowFreezeTask = nil
end

-- ==== Lock / unlock feet helpers (kept but not automatically used for boost red) ====
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

-- Idle reverse connection (will store the Heartbeat connection)
local idleReverseConn = nil

-- Load anims
local function loadAnimationsToHumanoid(hum)
	for _, track in pairs(animTracks) do pcall(function() track:Stop() end) end
	animTracks = {}

	-- Idle REVERSE 4-anims (exact IDs you provided)
	animTracks.idle_main   = safeLoad(hum, 74909537) -- main (reverse)
	animTracks.idle_second = safeLoad(hum, 203929876)
	animTracks.idle_third  = safeLoad(hum, 97172005)
	animTracks.idle_fourth = safeLoad(hum, 161235826)

	-- Prepare main explicitly: non-looping, priority Action3, weight 1, ensure played so engine loads it
	if animTracks.idle_main then
		pcall(function()
			animTracks.idle_main.Looped = false
			animTracks.idle_main.Priority = Enum.AnimationPriority.Action3
			animTracks.idle_main:Play()           -- ensure it's registered by the engine
			animTracks.idle_main:AdjustSpeed(0)  -- pause - we'll control TimePosition manually
			animTracks.idle_main:AdjustWeight(1) -- make sure main contributes when active
		end)
	end

	-- play and freeze the supporting tracks at first frame & invisible
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

	-- Forward / Side / Boosts (added forward_extra 161235826)
	animTracks.forward_a = safeLoad(hum, 165167557)      -- Action3 forward main
	animTracks.forward_b = safeLoad(hum, 97172005)       -- Action3 forward alternate
	animTracks.forward_extra = safeLoad(hum, 161235826)  -- NEW: extra forward (lower priority)
	animTracks.side_a = safeLoad(hum, 27753183)
	animTracks.side_b = safeLoad(hum, 21633130)
	animTracks.backward_a = animTracks.side_a
	animTracks.backward_b = animTracks.side_b
	animTracks.boost_cyan = safeLoad(hum, ANIMS.BOOST_CYAN)
	animTracks.boost_yellow = safeLoad(hum, 93693205)
	animTracks.boost_red_prio = safeLoad(hum, 148831127)
	animTracks.boost_red_sec = safeLoad(hum, 193342492)

	-- forward_extra: ensure paused/invisible at start, lower priority (Action)
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
	-- disconnect idle reverse if running
	if idleReverseConn then
		pcall(function() idleReverseConn:Disconnect() end)
		idleReverseConn = nil
	end

	for _,v in ipairs({
		"idle_main","idle_second","idle_third","idle_fourth",
		"forward_a","forward_b","forward_extra","backward_a","backward_b","side_a","side_b"
	}) do
		local t = animTracks[v]
		if t and t.IsPlaying then
			pcall(function() t:Stop() end)
		end
	end

	-- ensure support idle weights reset
	for _,k in ipairs({"idle_second","idle_third","idle_fourth"}) do
		local t = animTracks[k]
		if t then pcall(function() t:AdjustWeight(0) end) end
	end
end

local function stopAllBoostTracks()
	-- limpiar handlers del boost amarillo antes de parar anims
	if yellowSpeedConn then
		pcall(function() yellowSpeedConn:Disconnect() end)
		yellowSpeedConn = nil
	end
	yellowFreezeTask = nil

	-- detener anims
	for _,v in ipairs({"boost_cyan","boost_yellow","boost_red_prio","boost_red_sec"}) do
		local t = animTracks[v]
		if t and t.IsPlaying then pcall(function() t:Stop() end) end
	end
	-- liberar pies por si estaban bloqueados
	pcall(unlockFeet)
	currentBoostState = 0
end

local currentMovementState = nil
local currentBoostState = 0

-- Idle reverse routine (implemented exactly as your standalone)
local function startIdleReverse()
	-- safety: disconnect if already running
	if idleReverseConn then
		pcall(function() idleReverseConn:Disconnect() end)
		idleReverseConn = nil
	end

	local main = animTracks.idle_main
	local s2 = animTracks.idle_second
	local s3 = animTracks.idle_third
	local s4 = animTracks.idle_fourth

	-- fallback: if main missing, just make the other ones visible
	if not main then
		if s2 then pcall(function() s2:Play(); s2.TimePosition = 0; s2:AdjustSpeed(0); s2.Priority = Enum.AnimationPriority.Action3; s2:AdjustWeight(1,0.1) end) end
		if s3 then pcall(function() s3:Play(); s3.TimePosition = 0; s3:AdjustSpeed(0); s3.Priority = Enum.AnimationPriority.Action; s3:AdjustWeight(1,0.1) end) end
		if s4 then pcall(function() s4:Play(); s4.TimePosition = 0; s4:AdjustSpeed(0); s4.Priority = Enum.AnimationPriority.Action; s4:AdjustWeight(1,0.1) end) end
		return
	end

	-- ensure supporters are frozen and invisible
	if s2 then pcall(function() s2:Play(); s2.TimePosition = 0; s2:AdjustSpeed(0); s2:AdjustWeight(0); s2.Priority = Enum.AnimationPriority.Action3 end) end
	if s3 then pcall(function() s3:Play(); s3.TimePosition = 0; s3:AdjustSpeed(0); s3:AdjustWeight(0); s3.Priority = Enum.AnimationPriority.Action end) end
	if s4 then pcall(function() s4:Play(); s4.TimePosition = 0; s4:AdjustSpeed(0); s4:AdjustWeight(0); s4.Priority = Enum.AnimationPriority.Action end) end

	-- prepare main
	pcall(function()
		main.Looped = false
		main.Priority = Enum.AnimationPriority.Action3
		main:Play()
		main:AdjustSpeed(0)
		main:AdjustWeight(1)
	end)

	-- wait a short tick to ensure engine registers Length (if needed)
	task.wait()

	local ok, animLength = pcall(function() return main.Length end)
	animLength = (ok and type(animLength) == "number" and animLength > 0) and animLength or 0

	-- if length is zero, reveal supporters as fallback
	if animLength <= 0 then
		if s2 then pcall(function() s2:AdjustWeight(1,0.1) end) end
		if s3 then pcall(function() s3:AdjustWeight(1,0.1) end) end
		if s4 then pcall(function() s4:AdjustWeight(1,0.1) end) end
		return
	end

	local REVERSE_SPEED = 33
	local FREEZE_AT = 0.370

	-- position main at the end
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
			-- reveal supporting tracks smoothly
			if s2 then pcall(function() s2:AdjustWeight(1, 0.1) end) end
			if s3 then pcall(function() s3:AdjustWeight(1, 0.1) end) end
			if s4 then pcall(function() s4:AdjustWeight(1, 0.1) end) end
			-- disconnect
			if idleReverseConn then pcall(function() idleReverseConn:Disconnect() end) idleReverseConn = nil end
		else
			pcall(function() main.TimePosition = currentTime end)
		end
	end)
end

local function playMovementTrack(state)
	if currentMovementState == state then return end
	-- if leaving idle, clean reverse connection & reset supporting weights
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
		-- forward/back/side use their paired tracks
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

-- Boost amarillo: control de velocidad persistente y congelado
local function startYellowRoutine(track)
	if not track then return end
	clearYellowHandlers()
	local CONSTANT_SPEED = 33
	local freezeScheduled = false

	-- watchdog para forzar velocidad
	yellowSpeedConn = RunService.Heartbeat:Connect(function()
		if track and track.IsPlaying and not freezeScheduled then
			if track.Speed ~= CONSTANT_SPEED then
				pcall(function() track:AdjustSpeed(CONSTANT_SPEED) end)
			end
		end
	end)

	-- reproducir a velocidad constante
	pcall(function() track:Play(); track:AdjustSpeed(CONSTANT_SPEED); track.Priority = Enum.AnimationPriority.Action end)

	-- calcular tiempo y programar congelado en coroutine
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

local function playBoostTrack(level)
	if currentBoostState == level then return end
	stopAllBoostTracks()
	currentBoostState = level
	setBoostIndicatorByLevel(level)
	if level == 0 then return end

	if level == 1 then
		local t = animTracks.boost_cyan
		if t then pcall(function() t.Priority = Enum.AnimationPriority.Action; t:Play(); t:AdjustSpeed(1) end) end

	elseif level == 2 then
		-- Boost amarillo
		local t = animTracks.boost_yellow
		if t then startYellowRoutine(t) end

	elseif level == 3 then
		local pr = animTracks.boost_red_prio
		local sc = animTracks.boost_red_sec
		if pr then pcall(function() pr.Priority = Enum.AnimationPriority.Action4; pr:Play(); pr:AdjustSpeed(0); pr.TimePosition = 0; pr:AdjustWeight(1) end) end
		if sc then pcall(function() sc.Priority = Enum.AnimationPriority.Action3; sc:Play(); sc:AdjustSpeed(0); sc.TimePosition = 0; sc:AdjustWeight(1) end) end

		-- NOTA: ya no bloqueamos pies (lockFeet removido intencionalmente)
	end
end

-- Input helpers
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

-- Botones
impulsoBtn.MouseButton1Click:Connect(function()
	safeBounce(impulsoBtn)
	if not flying then return end
	if not isPlayerMoving() then return end
	boostLevel = (boostLevel + 1) % 4
	if boostLevel == 0 then targetSpeed = BASE_SPEED; targetFOV = FOV_BASE
	else targetSpeed = BOOST_SPEEDS[boostLevel]; targetFOV = FOV_LEVELS[boostLevel] end
	playBoostTrack(boostLevel)
end)

flyBtn.MouseButton1Click:Connect(function()
	safeBounce(flyBtn)
	if flying then
		-- Deactivate
		flying = false
		removeBodyMovers()
		humanoid.PlatformStand = false
		stopAllBoostTracks(); stopAllMovementTracks()
		currentMovementState = nil; currentBoostState = 0; boostLevel = 0
		targetSpeed = BASE_SPEED; targetFOV = FOV_BASE
		flyBtn.Text = "Fly OFF"
		tween(flyBtn,{BackgroundColor3 = FLY_INACTIVE_COLOR},0.12)
		setBoostIndicatorByLevel(0)
	else
		-- Activate
		flying = true
		levBaseY = hrp.Position.Y
		tAccum = 0
		wasMoving = isPlayerMoving()
		createBodyMovers()
		humanoid.PlatformStand = true
		if not next(animTracks) then loadAnimationsToHumanoid(humanoid) end
		playMovementTrack("idle")
		playBoostTrack(boostLevel)
		flyBtn.Text = "Fly ON"
		tween(flyBtn,{BackgroundColor3 = FLY_ACTIVE_COLOR},0.12)
		setBoostIndicatorByLevel(boostLevel)
	end
end)

-- Death / respawn handling
humanoid.Died:Connect(function()
	if flying then
		flying = false
		removeBodyMovers()
		humanoid.PlatformStand = false
		stopAllBoostTracks(); stopAllMovementTracks()
		currentMovementState = nil; currentBoostState = 0; boostLevel = 0
		targetSpeed = BASE_SPEED; targetFOV = FOV_BASE
		flyBtn.Text = "Fly OFF"
		tween(flyBtn,{BackgroundColor3 = FLY_INACTIVE_COLOR},0.12)
		setBoostIndicatorByLevel(0)
	end
end)

player.CharacterAdded:Connect(function(char)
	character = char
	humanoid = character:WaitForChild("Humanoid")
	hrp = character:WaitForChild("HumanoidRootPart")
	-- aseguro limpieza
	removeBodyMovers()
	gui.Parent = player:WaitForChild("PlayerGui")
	flying = false
	humanoid.PlatformStand = false
	stopAllBoostTracks(); stopAllMovementTracks()
	animTracks = {}
	loadAnimationsToHumanoid(humanoid)
	currentMovementState = nil; currentBoostState = 0; boostLevel = 0
	targetSpeed = BASE_SPEED; targetFOV = FOV_BASE
	flyBtn.Text = "Fly OFF"
	tween(flyBtn,{BackgroundColor3 = FLY_INACTIVE_COLOR},0.1)
	setBoostIndicatorByLevel(0)
end)

-- Main loop
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
		-- if any movers still exist, neutralize them
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

-- Inicial
loadAnimationsToHumanoid(humanoid)
flyBtn.Text = "Fly OFF"
impulsoBtn.Text = "IMPULSO"
tween(flyBtn,{BackgroundColor3 = FLY_INACTIVE_COLOR},0.1)
setBoostIndicatorByLevel(0)

print("[Flight v6.4 - final completo] BoostRed sin lockFeet + forward_extra (161235826) agregado + Idle REVERSE 4-anims.")

-- RefreshAnims Script
-- Coloca este script en StarterPlayer > StarterPlayerScripts

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
refreshConstantly(1.5)

-- Refrescar animaciones constantemente cada vez que el personaje reaparece
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid")
	refreshConstantly(1.5)
end)
