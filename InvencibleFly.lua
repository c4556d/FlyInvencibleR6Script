-- Flight v6.4 - Adaptado: BodyMovers creados solo en ON / destruidos en OFF
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local hrp = character:WaitForChild("HumanoidRootPart")
local camera = workspace.CurrentCamera

-- CONFIG (igual que antes)
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

-- Body movers variables (nil hasta crear)
local bodyVel = nil
local bodyGyro = nil

-- UI (idéntica a la anterior, resumida aquí)
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
bgGradient.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 0.4)})
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

local boostIndicator = Instance.new("Frame", container)
boostIndicator.Name = "BoostIndicator"
boostIndicator.Size = UDim2.new(0, 52, 0, 32)
boostIndicator.Position = UDim2.new(0, -26, 0, 59)
boostIndicator.AnchorPoint = Vector2.new(0, 0)
boostIndicator.BackgroundColor3 = Color3.fromRGB(255,255,255)
boostIndicator.BackgroundTransparency = 0.25
boostIndicator.BorderSizePixel = 0
boostIndicator.ZIndex = 3
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
	-- Si ya existen, aseguramos que están parented
	if bodyVel and bodyVel.Parent and bodyVel.Parent == hrp then return end
	-- destroy prev (por seguridad)
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
	if bodyVel then
		pcall(function() bodyVel:Destroy() end)
		bodyVel = nil
	end
	if bodyGyro then
		pcall(function() bodyGyro:Destroy() end)
		bodyGyro = nil
	end
end

-- Anim handling (igual que en el script anterior, cargando las anims combinadas)
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

local function loadAnimationsToHumanoid(hum)
	for _, track in pairs(animTracks) do pcall(function() track:Stop() end) end
	animTracks = {}
	animTracks.idle_a = safeLoad(hum, 73033633)
	animTracks.idle_b = safeLoad(hum, 21633130)
	animTracks.forward_a = safeLoad(hum, 165167557)
	animTracks.forward_b = safeLoad(hum, 97172005)
	animTracks.side_a = safeLoad(hum, 27753183)
	animTracks.side_b = safeLoad(hum, 21633130)
	animTracks.backward_a = animTracks.side_a
	animTracks.backward_b = animTracks.side_b
	animTracks.boost_cyan = safeLoad(hum, ANIMS.BOOST_CYAN)
	animTracks.boost_yellow_torso = safeLoad(hum, 129423131)
	animTracks.boost_yellow_arms = safeLoad(hum, 56153856)
	animTracks.boost_red_prio = safeLoad(hum, 148831127)
	animTracks.boost_red_sec = safeLoad(hum, 193342492)
end

local function stopAllMovementTracks()
	for _,v in ipairs({"idle_a","idle_b","forward_a","forward_b","backward_a","backward_b","side_a","side_b"}) do
		local t = animTracks[v]
		if t and t.IsPlaying then pcall(function() t:Stop() end) end
	end
end
local function stopAllBoostTracks()
	for _,v in ipairs({"boost_cyan","boost_yellow_torso","boost_yellow_arms","boost_red_prio","boost_red_sec"}) do
		local t = animTracks[v]
		if t and t.IsPlaying then pcall(function() t:Stop() end) end
	end
end

local currentMovementState = nil
local currentBoostState = 0

local function playMovementTrack(state)
	if currentMovementState == state then return end
	stopAllMovementTracks()
	currentMovementState = state
	if state == "idle" then
		local a = animTracks.idle_a
		local b = animTracks.idle_b
		if a then a:Play(); pcall(function() a.TimePosition = 0; a:AdjustSpeed(0); a.Priority = Enum.AnimationPriority.Action3 end) end
		if b then b:Play(); pcall(function() b.TimePosition = 0; b:AdjustSpeed(0); b.Priority = Enum.AnimationPriority.Action3 end) end
	else
		if state == "forward" then
			local a,b = animTracks.forward_a, animTracks.forward_b
			if a then a:Play(); pcall(function() a.TimePosition = 0; a:AdjustSpeed(0); a.Priority = Enum.AnimationPriority.Action3 end) end
			if b then b:Play(); pcall(function() b.TimePosition = 0; b:AdjustSpeed(0); b.Priority = Enum.AnimationPriority.Action3 end) end
		elseif state == "backward" then
			local a,b = animTracks.backward_a, animTracks.backward_b
			if a then a:Play(); pcall(function() a.TimePosition = 0; a:AdjustSpeed(0); a.Priority = Enum.AnimationPriority.Action3 end) end
			if b then b:Play(); pcall(function() b.TimePosition = 0; b:AdjustSpeed(0); b.Priority = Enum.AnimationPriority.Action3 end) end
		elseif state == "side" then
			local a,b = animTracks.side_a, animTracks.side_b
			if a then a:Play(); pcall(function() a.TimePosition = 0; a:AdjustSpeed(0); a.Priority = Enum.AnimationPriority.Action3 end) end
			if b then b:Play(); pcall(function() b.TimePosition = 0; b:AdjustSpeed(0); b.Priority = Enum.AnimationPriority.Action3 end) end
		end
	end
end

local function setBoostIndicatorByLevel(level)
	if level == 0 then
		TweenService:Create(boostIndicator, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(255,255,255)}):Play()
		TweenService:Create(boostIndicator, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = UDim2.new(0,52,0,32)}):Play()
	elseif level == 1 then
		TweenService:Create(boostIndicator, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(173,216,230)}):Play()
		TweenService:Create(boostIndicator, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = UDim2.new(0,62,0,32)}):Play()
	elseif level == 2 then
		TweenService:Create(boostIndicator, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(255,204,0)}):Play()
		TweenService:Create(boostIndicator, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = UDim2.new(0,70,0,32)}):Play()
	elseif level == 3 then
		TweenService:Create(boostIndicator, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(220,20,60)}):Play()
		TweenService:Create(boostIndicator, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = UDim2.new(0,78,0,32)}):Play()
	end
end

local function playBoostTrack(level)
	if currentBoostState == level then return end
	stopAllBoostTracks()
	currentBoostState = level
	setBoostIndicatorByLevel(level)
	if level == 0 then return end

	if level == 1 then
		local t = animTracks.boost_cyan
		if t then t.Priority = Enum.AnimationPriority.Action; t:Play(); pcall(function() t:AdjustSpeed(1) end) end

	elseif level == 2 then
		local torso = animTracks.boost_yellow_torso
		local arms = animTracks.boost_yellow_arms
		if torso then
			pcall(function() torso.Priority = Enum.AnimationPriority.Action end)
			coroutine.wrap(function()
				pcall(function() torso:Play(); torso:AdjustSpeed(100) end)
				local ok, length = pcall(function() return torso.Length end)
				local adjusted = 0.02
				if ok and type(length) == "number" and length > 0 then
					local freezeTime = math.max(0, length - 0.05)
					adjusted = freezeTime / 100
				end
				wait(adjusted)
				pcall(function() torso:AdjustSpeed(0) end)
				if arms then
					pcall(function()
						arms.Priority = Enum.AnimationPriority.Action4
						arms:Play()
						arms.TimePosition = 0
						arms:AdjustSpeed(0)
						arms:AdjustWeight(1, 0.1)
					end)
				end
			end)()
		end

	elseif level == 3 then
		local pr = animTracks.boost_red_prio
		local sc = animTracks.boost_red_sec
		if pr then pcall(function() pr.Priority = Enum.AnimationPriority.Action4; pr:Play(); pr:AdjustSpeed(0); pr.TimePosition = 0; pr:AdjustWeight(1) end) end
		if sc then pcall(function() sc.Priority = Enum.AnimationPriority.Action3; sc:Play(); sc:AdjustSpeed(0); sc.TimePosition = 0; sc:AdjustWeight(1) end) end
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
		-- Deactivate: remover movers en lugar de solo setear fuerzas
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
		-- Activate: crear movers aquí
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
	-- reasignar referencias y limpiar movers para evitar duplicates
	character = char
	humanoid = character:WaitForChild("Humanoid")
	hrp = character:WaitForChild("HumanoidRootPart")
	-- aseguramos que no queden movers colgando
	removeBodyMovers()
	gui.Parent = player:WaitForChild("PlayerGui")
	-- reset estado
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
		-- Si no está volando, nos aseguramos de que no haya forces activas
		currentCamRoll = currentCamRoll + (0 - currentCamRoll) * math.clamp(dt * 8, 0, 1)
		local camPos = camera.CFrame.Position
		local camLookVec = camera.CFrame.LookVector
		local desiredCamCFrame = CFrame.lookAt(camPos, camPos + camLookVec, Vector3.new(0,1,0)) * CFrame.Angles(0,0,currentCamRoll)
		camera.CFrame = camera.CFrame:Lerp(desiredCamCFrame, math.clamp(dt * 8, 0, 1))
		-- Deja fuerzas inactivas o destruidas
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
	-- Aplicar gyro solo si existe
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

print("[Flight v6.4 - adaptado] BodyMovers creados solo en ON / destruidos en OFF. Animaciones reasignadas.")
