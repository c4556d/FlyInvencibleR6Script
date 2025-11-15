-- FlyInvencible ultimate(hola chismoso)

-- Services(servicios)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- jugador(el tuyo wey)
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

-- configuracion
local BASE_SPEED = 39.93
local BOOST_SPEEDS = {79.87, 199.66, 319.46}
local FOV_BASE = camera.FieldOfView
local FOV_LEVELS = {FOV_BASE + 10, FOV_BASE + 20, FOV_BASE + 30}

local FLY_ACTIVE_COLOR = Color3.fromRGB(0,255,0)
local FLY_INACTIVE_COLOR = Color3.fromRGB(203,40,40)

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

-- ---------------- Player character ----------------
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local hrp = character:WaitForChild("HumanoidRootPart")

-- ---------------- Estado ----------------
local flying = false
local boostLevel = 0
local targetSpeed = BASE_SPEED
local currentSpeed = BASE_SPEED
local targetFOV = FOV_BASE

local levBaseY = hrp.Position.Y
local tAccum = 0
local currentCamRoll = 0
local wasMoving = false

-- Body movers
local bodyVel = nil
local bodyGyro = nil

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

-- ---------------- Animaciones (dos modos: BasicFly por defecto y FlyPrepared) ----------------

-- BASIC (original) anim config (tu versión original)
local ANIMATIONS_BASIC = {
	IDLE = {
		HIGH_1 = "rbxassetid://74909537",
		HIGH_2 = "rbxassetid://153839856",
		LOW_1  = "rbxassetid://74909500",
		CUT_TO = 0.386
	},
	FORWARD = {
		HIGH_1 = "rbxassetid://74909537",
		HIGH_2 = "rbxassetid://153839856",
		LOW_1  = "rbxassetid://97172005",
		LOW_2  = "rbxassetid://161235826",
		CUT_TO = 0.386
	},
	BACKWARD = {
		HIGH_1 = "rbxassetid://74909537",
		HIGH_2 = "rbxassetid://153839856",
		LOW_1  = "rbxassetid://69803972",
		LOW_2  = "rbxassetid://161235826",
		CUT_TO = 0.386
	}
}

-- PREPARED (modo nuevo que pediste — animaciones fusionadas)
local ANIMATIONS_PREPARED = {
	-- Idle: 1 alta + 2 bajas (congeladas en frame 0)
	IDLE = {
		HIGH_1 = "rbxassetid://157568994",   -- prioridad alta
		LOW_1  = "rbxassetid://97172005",
		LOW_2  = "rbxassetid://161235826",
		-- para prepared usamos TimePosition=0 (no CUT_TO)
	},

	-- Forward (Fly w): 3 bajas + 1 alta (alta domina, bajas fusionadas)
	FORWARD = {
		HIGH_1 = "rbxassetid://157568994",   -- prioridad alta (insert first)
		LOW_1  = "rbxassetid://97172005",
		LOW_2  = "rbxassetid://161235826",
		LOW_3  = "rbxassetid://97169019"
	},

	-- Backward (S): 1 alta + 2 bajas
	BACKWARD = {
		HIGH_1 = "rbxassetid://157568994",
		LOW_1  = "rbxassetid://69803972",
		LOW_2  = "rbxassetid://161235826"
	}
}

-- Boost config (igual a antes)
local BOOST_LEVELS = {
	[1] = {
		SPEED = BOOST_SPEEDS[1],
		FOV_INCREASE = 10,
		COLOR = Color3.fromRGB(100,150,180),
		ANIMATION_HIGH = "rbxassetid://90872539",
		TILT = 90
	},
	[2] = {
		SPEED = BOOST_SPEEDS[2],
		FOV_INCREASE = 20,
		COLOR = Color3.fromRGB(255,204,0),
		ANIMATION_HIGH = "rbxassetid://93693205",
		ANIMATION_HIGH_CUT = 4.012,
		TILT = 90
	},
	[3] = {
		SPEED = BOOST_SPEEDS[3],
		FOV_INCREASE = 30,
		COLOR = Color3.fromRGB(220,20,60),
		ANIMATION_LOW_1 = "rbxassetid://188856222",
		ANIMATION_LOW_2 = "rbxassetid://97169019",
		ANIMATION_HIGH = "rbxassetid://148831127",
		TILT = 90
	}
}

-- Estado de animación y modo
local ANIMATIONS = ANIMATIONS_BASIC -- por defecto
local animTracks = {}
local currentAnimState = nil
local flightAnimMode = "BasicFly" -- "BasicFly" or "FlyPrepared"

-- Aux: parar y destruir tracks actuales
local function stopAllAnimations()
	for _, track in pairs(animTracks) do
		pcall(function()
			if track and track.IsPlaying then track:Stop() end
			if track and track.Parent then track:Destroy() end
		end)
	end
	animTracks = {}
	currentAnimState = nil
end

-- Cargar anim (robusta)
local function loadAnimation(animId)
	if not animId then return nil end
	local a = Instance.new("Animation")
	a.AnimationId = animId
	local ok, track = pcall(function() return humanoid:LoadAnimation(a) end)
	if ok and track then return track end
	return nil
end

-- Función genérica que reproduce combinaciones HIGH_* (Action3) primero, luego LOW_* (Action).
-- Mantiene la convención de aplicar CUT_TO (si existe en la tabla) al primer track cargado.
local function playStateAnimations(stateKey)
	if currentAnimState == stateKey then return end
	stopAllAnimations()
	currentAnimState = stateKey

	local cfg = ANIMATIONS[stateKey]
	if not cfg then return end

	-- recoger keys HIGH_* ordenadas
	local highKeys = {}
	local lowKeys = {}
	for k,v in pairs(cfg) do
		if type(k) == "string" then
			if string.find(k:upper(), "HIGH") then table.insert(highKeys, k) end
			if string.find(k:upper(), "LOW") then table.insert(lowKeys, k) end
		end
	end
	table.sort(highKeys, function(a,b) return a < b end)
	table.sort(lowKeys, function(a,b) return a < b end)

	-- cargar HIGHs (prioridad Action3)
	for _, key in ipairs(highKeys) do
		local id = cfg[key]
		local tr = loadAnimation(id)
		if tr then
			tr.Looped = false
			tr.Priority = Enum.AnimationPriority.Action3
			tr:Play()
			tr:AdjustSpeed(0)
			-- por seguridad congelar en 0 (muchas prepared usan frame 0)
			pcall(function() tr.TimePosition = 0 end)
			table.insert(animTracks, tr)
		end
	end

	-- cargar LOWs (prioridad Action)
	for _, key in ipairs(lowKeys) do
		local id = cfg[key]
		local tr = loadAnimation(id)
		if tr then
			tr.Looped = false
			tr.Priority = Enum.AnimationPriority.Action
			tr:Play()
			tr:AdjustSpeed(0)
			pcall(function() tr.TimePosition = 0 end)
			table.insert(animTracks, tr)
		end
	end

	-- aplicar CUT_TO si está presente (igual que en original)
	if cfg.CUT_TO and animTracks[1] then
		task.wait()
		pcall(function() animTracks[1].TimePosition = cfg.CUT_TO end)
	end
end

-- Wrappers para compatibilidad con el resto del código
local function playIdleAnimations() playStateAnimations("IDLE") end
local function playForwardAnimations() playStateAnimations("FORWARD") end
local function playBackwardAnimations() playStateAnimations("BACKWARD") end

-- Boost animation (sin cambios lógicos)
local function playBoostAnimation(level)
	stopAllAnimations()
	currentAnimState = "BOOST_" .. tostring(level)

	local cfg = BOOST_LEVELS[level]
	if not cfg then return end

	if level == 1 then
		local tr = loadAnimation(cfg.ANIMATION_HIGH)
		if tr then
			tr.Looped = false; tr.Priority = Enum.AnimationPriority.Action3; tr:Play(); tr:AdjustSpeed(0); tr.TimePosition = 0
			table.insert(animTracks, tr)
		end

	elseif level == 2 then
		local tr = loadAnimation(cfg.ANIMATION_HIGH)
		if tr then
			tr.Looped = false; tr.Priority = Enum.AnimationPriority.Action3; tr:Play(); tr:AdjustSpeed(0)
			table.insert(animTracks, tr)
			-- aplicar corte
			task.wait()
			pcall(function() tr.TimePosition = cfg.ANIMATION_HIGH_CUT end)
		end

	elseif level == 3 then
		local low1 = loadAnimation(cfg.ANIMATION_LOW_1)
		if low1 then low1.Looped = false; low1.Priority = Enum.AnimationPriority.Action; low1:Play(); low1:AdjustSpeed(0); low1.TimePosition = 0; table.insert(animTracks, low1) end
		local low2 = loadAnimation(cfg.ANIMATION_LOW_2)
		if low2 then low2.Looped = false; low2.Priority = Enum.AnimationPriority.Action; low2:Play(); low2:AdjustSpeed(0); low2.TimePosition = 0; table.insert(animTracks, low2) end
		local high = loadAnimation(cfg.ANIMATION_HIGH)
		if high then high.Looped = false; high.Priority = Enum.AnimationPriority.Action3; high:Play(); high:AdjustSpeed(0); high.TimePosition = 0; table.insert(animTracks, high) end
		task.wait()
	end
end

-- ---------------- UI CREATION (original + nuevo panel de modos) ----------------
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
background.Size = UDim2.new(0, 176, 0, 220) -- algo más alto para panel de modos
background.BackgroundColor3 = Color3.fromRGB(0,0,0)
background.BackgroundTransparency = 0.909
background.BorderSizePixel = 0
background.ZIndex = 0
background.Parent = screenGui
local backgroundCorner = Instance.new("UICorner", background)
backgroundCorner.CornerRadius = UDim.new(0, 16)

-- BOOST button
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

-- FLY button
local flyButton = Instance.new("TextButton")
flyButton.Name = "FlyButton"
flyButton.Position = UDim2.new(0, 976, 0, 215)
flyButton.Size = UDim2.new(0, 168, 0, 74)
flyButton.BackgroundColor3 = FLY_INACTIVE_COLOR
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

-- Boost indicator capsule (la cápsula blanca que muestra color según nivel)
local boostIndicator = Instance.new("Frame")
boostIndicator.Name = "BoostIndicator"
boostIndicator.Position = UDim2.new(0, 967, 0, 190)
boostIndicator.Size = UDim2.new(0, 54, 0, 28)
boostIndicator.BackgroundColor3 = Color3.fromRGB(255,255,255)
boostIndicator.BackgroundTransparency = 0.28
boostIndicator.BorderSizePixel = 0
boostIndicator.Visible = false -- solo visible cuando fly activo (verde)
boostIndicator.ZIndex = 2
boostIndicator.Parent = screenGui
local indicatorCorner = Instance.new("UICorner", boostIndicator)
indicatorCorner.CornerRadius = UDim.new(1,0)

-- UI helpers
local flyActive_ui = false
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
	tweenBack.Completed:Connect(function() isAnimating = false end)
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
	tweenDown:Play(); tweenDown.Completed:Wait()
	local tweenInfoBack = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local goalBack = { Size = originalIndicatorSize, Position = originalIndicatorPos }
	local tweenBack = TweenService:Create(boostIndicator, tweenInfoBack, goalBack)
	tweenBack:Play()
end

local function setBoostIndicatorByLevel(level)
	if level == 0 then
		TweenService:Create(boostIndicator, TweenInfo.new(0.12), {BackgroundColor3 = indicatorColors[0], Size = UDim2.new(0,52,0,32)}):Play()
	elseif level == 1 then
		TweenService:Create(boostIndicator, TweenInfo.new(0.12), {BackgroundColor3 = indicatorColors[1], Size = UDim2.new(0,62,0,32)}):Play()
	elseif level == 2 then
		TweenService:Create(boostIndicator, TweenInfo.new(0.12), {BackgroundColor3 = indicatorColors[2], Size = UDim2.new(0,70,0,32)}):Play()
	elseif level == 3 then
		TweenService:Create(boostIndicator, TweenInfo.new(0.12), {BackgroundColor3 = indicatorColors[3], Size = UDim2.new(0,78,0,32)}):Play()
	end
end

local function updateBoostIndicatorUI()
	local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local goal = { BackgroundColor3 = indicatorColors[boostLevel] or indicatorColors[0] }
	TweenService:Create(boostIndicator, tweenInfo, goal):Play()
	animateIndicator()
end

local function updateIndicatorVisibilityUI()
	boostIndicator.Visible = flyActive_ui
end

-- ---------------- Nuevo: panel para elegir modo de animación (BasicFly / FlyPrepared) ----------------
local modePanel = Instance.new("Frame")
modePanel.Name = "ModePanel"
modePanel.Position = UDim2.new(0, 976, 0, 293) -- posición debajo de Fly
modePanel.Size = UDim2.new(0, 168, 0, 120)
modePanel.BackgroundTransparency = 0.05
modePanel.BackgroundColor3 = Color3.fromRGB(20,20,20)
modePanel.BorderSizePixel = 0
modePanel.ZIndex = 1
modePanel.Parent = screenGui

local mpCorner = Instance.new("UICorner", modePanel)
mpCorner.CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel", modePanel)
title.Name = "TitleLabel"
title.Size = UDim2.new(1, -12, 0, 24)
title.Position = UDim2.new(0, 6, 0, 6)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.Text = "Anim Mode"
title.TextColor3 = Color3.fromRGB(230,230,230)
title.TextXAlignment = Enum.TextXAlignment.Left

-- Toggle (cortina) button (small)
local toggleBtn = Instance.new("TextButton", modePanel)
toggleBtn.Name = "ToggleBtn"
toggleBtn.Size = UDim2.new(0, 26, 0, 22)
toggleBtn.Position = UDim2.new(1, -34, 0, 6)
toggleBtn.BackgroundTransparency = 0.1
toggleBtn.BackgroundColor3 = Color3.fromRGB(60,60,60)
toggleBtn.Font = Enum.Font.Gotham
toggleBtn.TextSize = 18
toggleBtn.Text = "˅" -- arrow
toggleBtn.TextColor3 = Color3.fromRGB(230,230,230)
toggleBtn.BorderSizePixel = 0
local toggleCorner = Instance.new("UICorner", toggleBtn)
toggleCorner.CornerRadius = UDim.new(0,6)

-- BasicFly button
local basicBtn = Instance.new("TextButton", modePanel)
basicBtn.Name = "BasicBtn"
basicBtn.Size = UDim2.new(1, -12, 0, 36)
basicBtn.Position = UDim2.new(0, 6, 0, 36)
basicBtn.BackgroundColor3 = Color3.fromRGB(45,45,45)
basicBtn.TextColor3 = Color3.fromRGB(220,220,220)
basicBtn.Font = Enum.Font.Gotham
basicBtn.TextSize = 14
basicBtn.Text = "BasicFly (default)"
basicBtn.BorderSizePixel = 0

local basicCorner = Instance.new("UICorner", basicBtn)
basicCorner.CornerRadius = UDim.new(0, 8)

-- PreparedFly button
local prepBtn = Instance.new("TextButton", modePanel)
prepBtn.Name = "PrepBtn"
prepBtn.Size = UDim2.new(1, -12, 0, 36)
prepBtn.Position = UDim2.new(0, 6, 0, 76)
prepBtn.BackgroundColor3 = Color3.fromRGB(45,45,45)
prepBtn.TextColor3 = Color3.fromRGB(220,220,220)
prepBtn.Font = Enum.Font.Gotham
prepBtn.TextSize = 14
prepBtn.Text = "FlyPrepared"
prepBtn.BorderSizePixel = 0

local prepCorner = Instance.new("UICorner", prepBtn)
prepCorner.CornerRadius = UDim.new(0, 8)

-- Info / feedback label
local modeInfo = Instance.new("TextLabel", modePanel)
modeInfo.Name = "ModeInfo"
modeInfo.Size = UDim2.new(1, -12, 0, 18)
modeInfo.Position = UDim2.new(0, 6, 0, 6 + 24)
modeInfo.BackgroundTransparency = 1
modeInfo.Font = Enum.Font.Gotham
modeInfo.TextSize = 12
modeInfo.Text = "Modo: BasicFly"
modeInfo.TextColor3 = Color3.fromRGB(180,180,180)
modeInfo.TextXAlignment = Enum.TextXAlignment.Right

-- Error popup (aparece si intentan cambiar mientras fly activo)
local errorPopup = Instance.new("Frame", screenGui)
errorPopup.Name = "ErrorPopup"
errorPopup.Position = UDim2.new(0, 972, 0, 430)
errorPopup.Size = UDim2.new(0, 176, 0, 40)
errorPopup.BackgroundColor3 = Color3.fromRGB(180,40,40)
errorPopup.BackgroundTransparency = 0.9
errorPopup.BorderSizePixel = 0
errorPopup.ZIndex = 5
errorPopup.Visible = false
local errCorner = Instance.new("UICorner", errorPopup)
errCorner.CornerRadius = UDim.new(0,10)
local errLabel = Instance.new("TextLabel", errorPopup)
errLabel.Size = UDim2.new(1, -12, 1, -8)
errLabel.Position = UDim2.new(0,6,0,4)
errLabel.BackgroundTransparency = 1
errLabel.Font = Enum.Font.Gotham
errLabel.TextSize = 14
errLabel.TextColor3 = Color3.fromRGB(240,240,240)
errLabel.TextWrapped = true
errLabel.Text = "Error: desactiva el FLY antes de cambiar el modo de animación."

local function showError(msg, duration)
	errLabel.Text = msg or "Desactiva el FLY primero."
	errorPopup.Visible = true
	-- pequeño tween para aparecer
	local tween = TweenService:Create(errorPopup, TweenInfo.new(0.12), {BackgroundTransparency = 0.45})
	tween:Play()
	task.delay(duration or 2, function()
		local tween2 = TweenService:Create(errorPopup, TweenInfo.new(0.18), {BackgroundTransparency = 0.9})
		tween2:Play()
		task.delay(0.18, function() errorPopup.Visible = false end)
	end)
end

-- ---------------- Persistencia local del modo (StringValue en Player) ----------------
local savedModeValue = player:FindFirstChild("FlyAnimMode_Local")
if not savedModeValue then
	savedModeValue = Instance.new("StringValue")
	savedModeValue.Name = "FlyAnimMode_Local"
	savedModeValue.Value = flightAnimMode -- default
	savedModeValue.Parent = player
end

-- Función para aplicar modo (solo si vuelo desactivado)
local function applyFlightMode(mode)
	if flying then
		showError("Primero desactiva el FLY para cambiar el modo de animación.", 2.2)
		return false
	end

	if mode == "BasicFly" then
		ANIMATIONS = ANIMATIONS_BASIC
		flightAnimMode = "BasicFly"
		modeInfo.Text = "Modo: BasicFly"
		-- stop current anims (ya estamos sin vuelo) para evitar inconsistencias
		stopAllAnimations()
		-- guardar localmente
		pcall(function() savedModeValue.Value = flightAnimMode end)
		return true
	elseif mode == "FlyPrepared" then
		ANIMATIONS = ANIMATIONS_PREPARED
		flightAnimMode = "FlyPrepared"
		modeInfo.Text = "Modo: FlyPrepared"
		stopAllAnimations()
		pcall(function() savedModeValue.Value = flightAnimMode end)
		return true
	end
	return false
end

-- Inicializar modo a partir del valor guardado (si existe)
if savedModeValue.Value == "FlyPrepared" then
	applyFlightMode("FlyPrepared")
else
	applyFlightMode("BasicFly")
end

-- Eventos botones de modo
basicBtn.MouseButton1Click:Connect(function()
	if applyFlightMode("BasicFly") then
		-- confirm visual rápido
		local t = TweenService:Create(basicBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(60,60,60)})
		t:Play()
		task.delay(0.2, function() TweenService:Create(basicBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(45,45,45)}):Play() end)
	end
end)

prepBtn.MouseButton1Click:Connect(function()
	if applyFlightMode("FlyPrepared") then
		local t = TweenService:Create(prepBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(60,60,60)})
		t:Play()
		task.delay(0.2, function() TweenService:Create(prepBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(45,45,45)}):Play() end)
	end
end)

-- ---------------- Panel "cortina" (abrir / cerrar) ----------------
local modeCollapsed = false
-- children to hide when collapsed (we'll keep title + toggle visible)
local collapseChildren = {
	["BasicBtn"] = basicBtn,
	["PrepBtn"] = prepBtn,
	["ModeInfo"] = modeInfo
}

local function setPanelCollapsed(collapsed)
	if modeCollapsed == collapsed then return end
	modeCollapsed = collapsed

	if collapsed then
		-- tween size (reduce height) and make background more transparent
		local t1 = TweenService:Create(modePanel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0,168,0,32)})
		t1:Play()
		local t2 = TweenService:Create(modePanel, TweenInfo.new(0.18), {BackgroundTransparency = 0.85})
		t2:Play()
		-- hide internal controls smoothly (text transparency + Visible after)
		for _, child in pairs(collapseChildren) do
			if child then
				local txt = child
				-- fade out text if TextLabel/Button
				pcall(function()
					if txt:IsA("TextLabel") or txt:IsA("TextButton") then
						local prop = {TextTransparency = 1}
						TweenService:Create(txt, TweenInfo.new(0.14), prop):Play()
						task.delay(0.14, function() txt.Visible = false end)
					else
						txt.Visible = false
					end
				end)
			end
		end
		-- change toggle arrow
		toggleBtn.Text = "˄"
	else
		-- expand
		for _, child in pairs(collapseChildren) do
			if child then
				child.Visible = true
				-- fade in
				pcall(function()
					if child:IsA("TextLabel") or child:IsA("TextButton") then
						child.TextTransparency = 1
						TweenService:Create(child, TweenInfo.new(0.15), {TextTransparency = 0}):Play()
					end
				end)
			end
		end
		local t1 = TweenService:Create(modePanel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0,168,0,120)})
		t1:Play()
		local t2 = TweenService:Create(modePanel, TweenInfo.new(0.18), {BackgroundTransparency = 0.05})
		t2:Play()
		toggleBtn.Text = "˅"
	end
end

toggleBtn.MouseButton1Click:Connect(function()
	setPanelCollapsed(not modeCollapsed)
end)

-- start with panel expanded by default (but respect saved collapsed state if you want; currently default expanded)
setPanelCollapsed(false)

-- ---------------- Input helpers ----------------
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

-- ---------------- UI events -> sincronizar con lógica y anims ----------------
flyButton.MouseButton1Click:Connect(function()
	animateButton(flyButton, originalFlySize, originalFlyPos)

	-- toggle UI state
	flyActive_ui = not flyActive_ui
	updateIndicatorVisibilityUI()

	-- color del botón
	local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local colorGoal = flyActive_ui and {BackgroundColor3 = FLY_ACTIVE_COLOR} or {BackgroundColor3 = FLY_INACTIVE_COLOR}
	TweenService:Create(flyButton, tweenInfo, colorGoal):Play()

	-- sincronizar lógica
	if flyActive_ui and not flying then
		-- activar vuelo
		flying = true
		levBaseY = hrp.Position.Y
		tAccum = 0
		wasMoving = isPlayerMoving()
		createBodyMovers()
		humanoid.PlatformStand = true
		-- anims: iniciar idle (según ANIMATIONS activo)
		playIdleAnimations()
		-- aplicar indicador visual actual
		boostIndicator.Visible = true
		setBoostIndicatorByLevel(boostLevel)
		-- ajustar target speed segun boost
		if boostLevel == 0 then
			targetSpeed = BASE_SPEED; targetFOV = FOV_BASE
		else
			targetSpeed = BOOST_SPEEDS[boostLevel]; targetFOV = FOV_LEVELS[boostLevel]
			-- cuando ya hay boost, reproducir su anim
			playBoostAnimation(boostLevel)
		end
	elseif not flyActive_ui and flying then
		-- desactivar vuelo
		flying = false
		removeBodyMovers()
		humanoid.PlatformStand = false
		boostLevel = 0
		targetSpeed = BASE_SPEED; targetFOV = FOV_BASE
		-- stop anims y reset UI
		stopAllAnimations()
		boostIndicator.Visible = false
		setBoostIndicatorByLevel(0)
	end
end)

flyButton.MouseEnter:Connect(function() if not isAnimating then animateHover(flyButton, true, originalFlySize, originalFlyPos) end end)
flyButton.MouseLeave:Connect(function() if not isAnimating then animateHover(flyButton, false, originalFlySize, originalFlyPos) end end)

-- Boost button behavior (solo si vuela y se mueve)
boostButton.MouseButton1Click:Connect(function()
	animateButton(boostButton, originalBoostSize, originalBoostPos)

	if not flying then
		return
	end

	if not isPlayerMoving() then
		-- no permitir boost si está quieto
		return
	end

	-- ciclar boost 0..3
	boostLevel = (boostLevel + 1) % 4

	if boostLevel == 0 then
		targetSpeed = BASE_SPEED; targetFOV = FOV_BASE
		setBoostIndicatorByLevel(0)
		updateBoostIndicatorUI()
		-- volver a anims normales
		playIdleAnimations()
	else
		targetSpeed = BOOST_SPEEDS[boostLevel]; targetFOV = FOV_LEVELS[boostLevel]
		setBoostIndicatorByLevel(boostLevel)
		updateBoostIndicatorUI()
		-- reproducir anim de boost (nivel)
		playBoostAnimation(boostLevel)
	end
end)

boostButton.MouseEnter:Connect(function() if not isAnimating then animateHover(boostButton, true, originalBoostSize, originalBoostPos) end end)
boostButton.MouseLeave:Connect(function() if not isAnimating then animateHover(boostButton, false, originalBoostSize, originalBoostPos) end end)

-- ---------------- MAIN LOOP ----------------
RunService.RenderStepped:Connect(function(dt)
	tAccum = tAccum + dt
	currentSpeed = currentSpeed + (targetSpeed - currentSpeed) * math.clamp(dt * SPEED_LERP, 0, 1)
	camera.FieldOfView = camera.FieldOfView + (targetFOV - camera.FieldOfView) * math.clamp(dt * FOV_LERP, 0, 1)

	local movingNow = isPlayerMoving()
	if wasMoving and not movingNow then
		-- al detenerse, resetear boost a 0 (y anims)
		if boostLevel ~= 0 then
			boostLevel = 0
			targetSpeed = BASE_SPEED
			targetFOV = FOV_BASE
			setBoostIndicatorByLevel(0)
			updateBoostIndicatorUI()
			playIdleAnimations()
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

	-- levitación pequeña
	local omega = 2 * math.pi * LEV_FREQ
	local levDisp = LEV_AMPL * math.sin(omega * tAccum)
	local levVel = LEV_AMPL * omega * math.cos(omega * tAccum)

	-- inputs
	local kbF, kbR = getKeyboardAxes()
	local mF, mR, mMag = getMobileAxes()
	local fwdAxis = kbF + mF
	local rightAxis = kbR + mR
	local inputMag = math.sqrt(fwdAxis*fwdAxis + rightAxis*rightAxis)

	-- mover
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

	-- orientación + inclinaciones
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

	-- Animations: si no hay boost, elegir anim por input; si hay boost, boost anim ya fue invocado cuando subió el nivel
	if boostLevel == 0 then
		if inputMag > INPUT_DEADZONE and fwdAxis > 0.25 then
			playForwardAnimations()
		elseif inputMag > INPUT_DEADZONE and fwdAxis < -0.25 then
			playBackwardAnimations()
		else
			playIdleAnimations()
		end
	end

	-- actualizar indicador UI (solo color)
	updateBoostIndicatorUI()
end)

-- ---------------- Death / respawn ----------------
humanoid.Died:Connect(function()
	if flying then
		flying = false
		removeBodyMovers()
		humanoid.PlatformStand = false
		boostLevel = 0
		targetSpeed = BASE_SPEED; targetFOV = FOV_BASE
		flyButton.Text = "FLY"
		flyButton.BackgroundColor3 = FLY_INACTIVE_COLOR
		boostIndicator.Visible = false
		setBoostIndicatorByLevel(0)
		stopAllAnimations()
	end
end)

player.CharacterAdded:Connect(function(char)
	character = char
	humanoid = character:WaitForChild("Humanoid")
	hrp = character:WaitForChild("HumanoidRootPart")
	removeBodyMovers()
	-- reparent GUI to PlayerGui en respawn
	screenGui.Parent = player:WaitForChild("PlayerGui")
	flying = false
	humanoid.PlatformStand = false
	boostLevel = 0
	targetSpeed = BASE_SPEED; targetFOV = FOV_BASE
	flyButton.Text = "FLY"
	flyButton.BackgroundColor3 = FLY_INACTIVE_COLOR
	boostIndicator.Visible = false
	setBoostIndicatorByLevel(0)
	stopAllAnimations()
	-- re-apply saved mode (local)
	if savedModeValue and savedModeValue.Value then
		-- safe call: apply only when not flying
		pcall(function() applyFlightMode(savedModeValue.Value) end)
	end
end)

print("Vuelo de invencible, cargado correctamente, hecho por:G1")
