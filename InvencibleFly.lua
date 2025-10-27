-- Flight v6.4-UIfinal - UI centrada a la derecha con botones en cápsula
-- LocalScript -> StarterPlayer > StarterPlayerScripts
-- R6 compatible
-- Español

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

-- UI - Contenedor centrado verticalmente a la derecha
local gui = Instance.new("ScreenGui")
gui.Name = "FlightUI_v6_final_match"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- Contenedor con tamaño ajustado para botones más grandes pegados
local container = Instance.new("Frame", gui)
container.Name = "FlightContainer"
container.Size = UDim2.new(0, 220, 0, 150) -- altura ajustada para 2 botones pegados (75+75)
container.Position = UDim2.new(1, -20, 0.5, 0) -- posición derecha, centrado verticalmente
container.AnchorPoint = Vector2.new(1, 0.5) -- ancla en el centro derecho
container.BackgroundTransparency = 1

-- Fondo negro semi-transparente detrás de los botones
-- Este marco negro encierra ambos botones como se ve en la imagen
local backgroundBox = Instance.new("Frame", container)
backgroundBox.Name = "BackgroundBox"
backgroundBox.Size = UDim2.new(0, 205, 0, 150) -- mismo ancho que botones, altura para ambos
backgroundBox.Position = UDim2.new(0, 0, 0, 0)
backgroundBox.AnchorPoint = Vector2.new(0, 0)
backgroundBox.BackgroundColor3 = Color3.fromRGB(0, 0, 0) -- negro
backgroundBox.BackgroundTransparency = 0.7 -- transparencia de 0.7 para hacerlo más sutil
backgroundBox.BorderSizePixel = 0
backgroundBox.ZIndex = 1 -- atrás de los botones
-- Esquinas redondeadas para el fondo negro, siguiendo el estilo de cápsula
local bgCorner = Instance.new("UICorner", backgroundBox)
bgCorner.CornerRadius = UDim.new(0, 12) -- bordes ligeramente redondeados
-- Efecto de difuminado en los bordes del fondo negro
-- UIGradient crea un degradado que hace que los bordes se vean más suaves y difuminados
local bgGradient = Instance.new("UIGradient", backgroundBox)
bgGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.4), -- los bordes laterales más transparentes (difuminados)
	NumberSequenceKeypoint.new(0.5, 0), -- el centro completamente opaco (respetando la transparencia del frame)
	NumberSequenceKeypoint.new(1, 0.4) -- los bordes laterales más transparentes (difuminados)
})
bgGradient.Rotation = 0 -- horizontal para difuminar los lados izquierdo y derecho

-- Función para crear botones con forma de cápsula (bordes redondeados)
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
	b.ZIndex = 2 -- delante del fondo negro
	-- contorno del texto (stroke)
	b.TextStrokeTransparency = 0
	b.TextStrokeColor3 = Color3.new(0,0,0)
	-- corner redondeado para forma de cápsula perfecta
	local corner = Instance.new("UICorner", b)
	corner.CornerRadius = UDim.new(0.5, 0) -- radio de 0.5 para cápsula perfecta
	b.Parent = container
	return b
end

-- Dimensiones de los botones
local IMPULSO_WIDTH = 205
local IMPULSO_HEIGHT = 75
local FLY_WIDTH = 205
local FLY_HEIGHT = 75

-- Botón IMPULSO arriba (posición 0) - pegado al borde superior
local impulsoBtn = makeCapsuleButton("ImpulsoBtn", "IMPULSO", BOOST_BASE_COLOR, 0, IMPULSO_WIDTH, IMPULSO_HEIGHT)

-- Botón Fly abajo (posición 75) - pegado directamente al botón de arriba sin espacio
local flyBtn = makeCapsuleButton("FlyBtn", "Fly OFF", FLY_INACTIVE_COLOR, 75, FLY_WIDTH, FLY_HEIGHT)

-- Indicador de impulsos: cápsula posicionada entre los dos botones
-- Este indicador se posiciona en el borde donde se juntan ambos botones
local boostIndicator = Instance.new("Frame", container)
boostIndicator.Name = "BoostIndicator"
boostIndicator.Size = UDim2.new(0, 52, 0, 32)
-- Posición: en el límite entre los dos botones (a la altura 75 donde se juntan)
-- Lo colocamos ligeramente hacia la izquierda para que sobresalga
boostIndicator.Position = UDim2.new(0, -26, 0, 59) -- centrado verticalmente en la unión de botones
boostIndicator.AnchorPoint = Vector2.new(0, 0)
boostIndicator.BackgroundColor3 = Color3.fromRGB(255,255,255) -- blanco cuando sin impulso
boostIndicator.BackgroundTransparency = 0.25 -- transparencia de 0.25
boostIndicator.BorderSizePixel = 0
boostIndicator.ZIndex = 3 -- delante de todo para que se vea sobre los botones
local indCorner = Instance.new("UICorner", boostIndicator)
indCorner.CornerRadius = UDim.new(0.5, 0) -- cápsula perfecta

-- safeBounce (UIScale) para que el botón rebote sin romper Size/Position
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

-- helper tween para animaciones suaves
local function tween(obj, props, t) t = t or 0.28 TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), props):Play() end

-- Body movers para controlar el vuelo
local bodyVel = Instance.new("BodyVelocity")
bodyVel.MaxForce = Vector3.new(1e5, 1e8, 1e5)
bodyVel.Velocity = Vector3.new(0,0,0)
bodyVel.Parent = hrp

local bodyGyro = Instance.new("BodyGyro")
bodyGyro.MaxTorque = Vector3.new(0,0,0)
bodyGyro.P = 3000
bodyGyro.D = 200
bodyGyro.Parent = hrp

-- Animations
local ANIMS = {
	IDLE_PRIMARY = 73033633,
	IDLE_EXTRA   = 97172005,
	FORWARD = 165167557,
	BACKWARD = 79155105,
	SIDE = 94116311,
	BOOST_CYAN = 90872539,
	BOOST_YELLOW = 79155114,
	BOOST_RED = 132546839,
}

local animTracks = {}
local function createAnimation(id)
	local a = Instance.new("Animation")
	a.AnimationId = "rbxassetid://"..tostring(id)
	return a
end

local function loadAnimationsToHumanoid(hum)
	for _, track in pairs(animTracks) do pcall(function() track:Stop() end) end
	animTracks = {}
	local mapped = {
		idle_primary = createAnimation(ANIMS.IDLE_PRIMARY),
		idle_extra   = createAnimation(ANIMS.IDLE_EXTRA),
		forward = createAnimation(ANIMS.FORWARD),
		backward = createAnimation(ANIMS.BACKWARD),
		side = createAnimation(ANIMS.SIDE),
		boost_cyan = createAnimation(ANIMS.BOOST_CYAN),
		boost_yellow = createAnimation(ANIMS.BOOST_YELLOW),
		boost_red = createAnimation(ANIMS.BOOST_RED),
	}
	for name, anim in pairs(mapped) do
		local ok, track = pcall(function() return hum:LoadAnimation(anim) end)
		if ok and track then
			track.Looped = true
			animTracks[name] = track
		end
	end
end

local function stopAllMovementTracks()
	for _,v in ipairs({"idle_primary","idle_extra","forward","backward","side"}) do
		local t = animTracks[v]
		if t and t.IsPlaying then pcall(function() t:Stop() end) end
	end
end
local function stopAllBoostTracks()
	for _,v in ipairs({"boost_cyan","boost_yellow","boost_red"}) do
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
		local p = animTracks["idle_primary"]
		local e = animTracks["idle_extra"]
		if p then p:Play(); pcall(function() p.TimePosition = 0; p:AdjustSpeed(0) end) end
		if e then e:Play(); pcall(function() e:AdjustSpeed(1) end) end
	else
		local t = animTracks[state]
		if t then t:Play(); pcall(function() t.TimePosition = 0; t:AdjustSpeed(0) end) end
	end
end

-- Actualiza el indicador visual según el nivel de boost
-- Mantiene la transparencia de 0.25 mientras cambia colores
local function setBoostIndicatorByLevel(level)
	-- level: 0 -> blanco (sin impulso)
	-- 1 -> cyan, 2 -> yellow, 3 -> red
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
	-- actualizar indicador inmediatamente
	setBoostIndicatorByLevel(level)
	if level == 0 then return end
	if level == 1 then
		local t = animTracks["boost_cyan"]
		if t then t.Priority = Enum.AnimationPriority.Action; t:Play(); pcall(function() t:AdjustSpeed(1) end) end
	elseif level == 2 then
		local t = animTracks["boost_yellow"]
		if t then t.Priority = Enum.AnimationPriority.Action; t:Play(); pcall(function() t.TimePosition = 0; t:AdjustSpeed(0) end) end
	elseif level == 3 then
		local t = animTracks["boost_red"]
		if t then t.Priority = Enum.AnimationPriority.Action; t:Play(); pcall(function() t.TimePosition = 0; t:AdjustSpeed(0) end) end
	end
end

-- Input helpers para detectar movimiento del jugador
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

-- IMPULSO (boost) button behavior - incrementa el nivel de velocidad
impulsoBtn.MouseButton1Click:Connect(function()
	safeBounce(impulsoBtn)
	if not flying then return end
	if not isPlayerMoving() then return end
	boostLevel = (boostLevel + 1) % 4
	if boostLevel == 0 then targetSpeed = BASE_SPEED; targetFOV = FOV_BASE
	else targetSpeed = BOOST_SPEEDS[boostLevel]; targetFOV = FOV_LEVELS[boostLevel] end
	playBoostTrack(boostLevel)
end)

-- Fly toggle - activa/desactiva el modo vuelo
flyBtn.MouseButton1Click:Connect(function()
	safeBounce(flyBtn)
	if flying then
		-- Deactivate
		flying = false
		bodyVel.MaxForce = Vector3.new(0,0,0)
		bodyVel.Velocity = Vector3.new(0,0,0)
		bodyGyro.MaxTorque = Vector3.new(0,0,0)
		humanoid.PlatformStand = false
		stopAllBoostTracks(); stopAllMovementTracks()
		currentMovementState = nil; currentBoostState = 0; boostLevel = 0
		targetSpeed = BASE_SPEED; targetFOV = FOV_BASE
		-- UI
		flyBtn.Text = "Fly OFF"
		tween(flyBtn,{BackgroundColor3 = FLY_INACTIVE_COLOR},0.12)
		setBoostIndicatorByLevel(0)
	else
		-- Activate
		flying = true
		levBaseY = hrp.Position.Y
		tAccum = 0
		wasMoving = isPlayerMoving()
		bodyVel.MaxForce = Vector3.new(1e5, 1e8, 1e5)
		bodyGyro.MaxTorque = Vector3.new(4e6,4e6,4e6)
		humanoid.PlatformStand = true
		if not next(animTracks) then loadAnimationsToHumanoid(humanoid) end
		playMovementTrack("idle")
		playBoostTrack(boostLevel)
		-- UI
		flyBtn.Text = "Fly ON"
		tween(flyBtn,{BackgroundColor3 = FLY_ACTIVE_COLOR},0.12)
		setBoostIndicatorByLevel(boostLevel)
	end
end)

-- Death / respawn handling - resetea el vuelo al morir
humanoid.Died:Connect(function()
	if flying then
		flying = false
		bodyVel.MaxForce = Vector3.new(0,0,0); bodyVel.Velocity = Vector3.new(0,0,0)
		bodyGyro.MaxTorque = Vector3.new(0,0,0)
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
	bodyVel.Parent = hrp
	bodyGyro.Parent = hrp
	gui.Parent = player:WaitForChild("PlayerGui")
	-- reset
	flying = false
	bodyVel.MaxForce = Vector3.new(0,0,0); bodyVel.Velocity = Vector3.new(0,0,0)
	bodyGyro.MaxTorque = Vector3.new(0,0,0)
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

-- Main loop - controla el movimiento, levitación y animaciones durante el vuelo
RunService.RenderStepped:Connect(function(dt)
	tAccum = tAccum + dt
	currentSpeed = currentSpeed + (targetSpeed - currentSpeed) * math.clamp(dt * SPEED_LERP, 0, 1)
	camera.FieldOfView = camera.FieldOfView + (targetFOV - camera.FieldOfView) * math.clamp(dt * FOV_LERP, 0, 1)

	local movingNow = isPlayerMoving()
	-- reset boost al dejar de moverse (inmediato)
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
		bodyVel.MaxForce = Vector3.new(0,0,0); bodyVel.Velocity = Vector3.new(0,0,0)
		bodyGyro.MaxTorque = Vector3.new(0,0,0)
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
		bodyVel.Velocity = bodyVel.Velocity:Lerp(targetVel, math.clamp(dt * (VEL_LERP*1.3), 0, 1))
	else
		local camLook, camRight = camBasisFull()
		local dir = camLook * fwdAxis + camRight * rightAxis
		if dir.Magnitude > 0.0001 then
			dir = dir.Unit
			local scale = math.min(1, inputMag)
			local moveVel = dir * currentSpeed * scale
			local targetVel = Vector3.new(moveVel.X, moveVel.Y + levVel, moveVel.Z)
			bodyVel.Velocity = bodyVel.Velocity:Lerp(targetVel, math.clamp(dt * VEL_LERP, 0, 1))
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
	bodyGyro.CFrame = bodyGyro.CFrame:Lerp(desiredBodyCFrame, math.clamp(dt * ROT_LERP, 0, 1))
	bodyGyro.P = 3000; bodyGyro.D = 200

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

print("[Flight v6.4-UIfinal] Cargado: Botones pegados con fondo negro semi-transparente.")
