-- FlyInvencible Ultimate - R6

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

-- Player
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

-- Configuración
local BASE_SPEED = 39.93
local BOOST_SPEEDS = {79.87, 199.66, 319.46}
local FOV_BASE = camera.FieldOfView
local FOV_LEVELS = {FOV_BASE + 10, FOV_BASE + 20, FOV_BASE + 30}

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

-- Player character
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local hrp = character:WaitForChild("HumanoidRootPart")

-- Estado
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
	bodyGyro.MaxTorque = Vector3.new(4e6, 4e6, 4e6)
	bodyGyro.P = 3000
	bodyGyro.D = 200
	bodyGyro.Parent = hrp
end

local function removeBodyMovers()
	if bodyVel then pcall(function() bodyVel:Destroy() end) bodyVel = nil end
	if bodyGyro then pcall(function() bodyGyro:Destroy() end) bodyGyro = nil end
end

-- Animaciones
local ANIMATIONS_BASIC = {
	IDLE = {
		HIGH_1 = "rbxassetid://74909537",
		HIGH_2 = "rbxassetid://153839856",
		LOW_1 = "rbxassetid://74909500",
		CUT_TO = 0.386
	},
	FORWARD = {
		HIGH_1 = "rbxassetid://74909537",
		HIGH_2 = "rbxassetid://153839856",
		LOW_1 = "rbxassetid://97172005",
		LOW_2 = "rbxassetid://161235826",
		LOW_3 = "rbxassetid://97169019", -- ADDED: quinta animación (LOW_3)
		CUT_TO = 0.386
	},
	BACKWARD = {
		HIGH_1 = "rbxassetid://74909537",
		HIGH_2 = "rbxassetid://153839856",
		LOW_1 = "rbxassetid://69803972",
		LOW_2 = "rbxassetid://161235826",
		CUT_TO = 0.386
	}
}

local ANIMATIONS_PREPARED = {
	IDLE = {
		HIGH_1 = "rbxassetid://157568994",
		LOW_1 = "rbxassetid://97172005",
		LOW_2 = "rbxassetid://161235826"
	},
	FORWARD = {
		HIGH_1 = "rbxassetid://157568994",
		LOW_1 = "rbxassetid://97172005",
		LOW_2 = "rbxassetid://161235826",
		LOW_3 = "rbxassetid://97169019"
	},
	BACKWARD = {
		HIGH_1 = "rbxassetid://157568994",
		LOW_1 = "rbxassetid://69803972",
		LOW_2 = "rbxassetid://161235826"
	}
}

local BOOST_LEVELS = {
	[1] = {
		SPEED = BOOST_SPEEDS[1],
		FOV_INCREASE = 10,
		ANIMATION_HIGH = "rbxassetid://90872539",
		TILT = 90
	},
	[2] = {
		SPEED = BOOST_SPEEDS[2],
		FOV_INCREASE = 20,
		ANIMATION_HIGH = "rbxassetid://93693205",
		ANIMATION_HIGH_CUT = 4.012,
		TILT = 90
	},
	[3] = {
		SPEED = BOOST_SPEEDS[3],
		FOV_INCREASE = 30,
		ANIMATION_LOW_1 = "rbxassetid://188856222",
		ANIMATION_LOW_2 = "rbxassetid://97169019",
		ANIMATION_HIGH = "rbxassetid://148831127",
		TILT = 90
	}
}

local ANIMATIONS = ANIMATIONS_BASIC
local animTracks = {}
local currentAnimState = nil
local flightAnimMode = "BasicFly"

-- NEW: table of preloaded Animation objects (NOT tracks)
local preloadedAnimations = {}

local function stopAllAnimations()
	for _, track in pairs(animTracks) do
		pcall(function()
			if track and track.IsPlaying then track:Stop() end
			if track and track.Parent then track:Destroy() end
		end)
	end
	animTracks = {}
	currentAnimState = nil
	-- preloadedAnimations remain intact (we only stored Animation objects)
end

-- CHANGED: loadAnimation now prefers preloaded Animation assets (and creates track on demand)
local function loadAnimation(animId)
	if not animId then return nil end

	-- If we have a preloaded Animation object, load from it
	if preloadedAnimations[animId] then
		local ok, track = pcall(function() return humanoid:LoadAnimation(preloadedAnimations[animId]) end)
		if ok and track then return track end
		-- fallback to dynamic creation below if LoadAnimation failed
	end

	-- Fallback: create an Animation instance and load a track (not stored)
	local a = Instance.new("Animation")
	a.AnimationId = animId
	local ok2, track2 = pcall(function() return humanoid:LoadAnimation(a) end)
	if ok2 and track2 then return track2 end
	return nil
end

-- NEW: precarga el Animation asset (no reproduce)
local function preloadAnimationAsset(animId)
	if not animId then return end
	if preloadedAnimations[animId] then return end
	local a = Instance.new("Animation")
	a.AnimationId = animId
	preloadedAnimations[animId] = a
end

-- NEW: createFrozenForwardTrack now only precarga la animación (no play)
local function createFrozenForwardTrack()
	-- precarga el asset para la animación forward extra (no se reproduce)
	preloadAnimationAsset("rbxassetid://97169019")
end

local function playStateAnimations(stateKey)
	if currentAnimState == stateKey then return end
	stopAllAnimations()
	currentAnimState = stateKey

	local cfg = ANIMATIONS[stateKey]
	if not cfg then return end

	local highKeys = {}
	local lowKeys = {}
	for k, v in pairs(cfg) do
		if type(k) == "string" then
			if string.find(k:upper(), "HIGH") then table.insert(highKeys, k) end
			if string.find(k:upper(), "LOW") then table.insert(lowKeys, k) end
		end
	end
	table.sort(highKeys, function(a, b) return a < b end)
	table.sort(lowKeys, function(a, b) return a < b end)

	for _, key in ipairs(highKeys) do
		local id = cfg[key]
		local tr = loadAnimation(id)
		if tr then
			tr.Looped = false
			tr.Priority = Enum.AnimationPriority.Action3
			tr:Play()
			tr:AdjustSpeed(0)
			pcall(function() tr.TimePosition = 0 end)
			table.insert(animTracks, tr)
		end
	end

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

	if cfg.CUT_TO and animTracks[1] then
		task.wait()
		pcall(function() animTracks[1].TimePosition = cfg.CUT_TO end)
	end
end

local function playIdleAnimations() playStateAnimations("IDLE") end
local function playForwardAnimations() playStateAnimations("FORWARD") end
local function playBackwardAnimations() playStateAnimations("BACKWARD") end

local function playBoostAnimation(level)
	if not BOOST_LEVELS[level] then return end
	stopAllAnimations()
	currentAnimState = "BOOST_" .. level

	local cfg = BOOST_LEVELS[level]
	local tracks = {}

	if cfg.ANIMATION_HIGH then
		local tr = loadAnimation(cfg.ANIMATION_HIGH)
		if tr then
			tr.Looped = false
			tr.Priority = Enum.AnimationPriority.Action3
			tr:Play()
			tr:AdjustSpeed(0)
			if cfg.ANIMATION_HIGH_CUT then
				task.wait()
				pcall(function() tr.TimePosition = cfg.ANIMATION_HIGH_CUT end)
			end
			table.insert(tracks, tr)
		end
	end

	if cfg.ANIMATION_LOW_1 then
		local tr = loadAnimation(cfg.ANIMATION_LOW_1)
		if tr then
			tr.Looped = false
			tr.Priority = Enum.AnimationPriority.Action
			tr:Play()
			tr:AdjustSpeed(0)
			table.insert(tracks, tr)
		end
	end

	if cfg.ANIMATION_LOW_2 then
		local tr = loadAnimation(cfg.ANIMATION_LOW_2)
		if tr then
			tr.Looped = false
			tr.Priority = Enum.AnimationPriority.Action
			tr:Play()
			tr:AdjustSpeed(0)
			table.insert(tracks, tr)
		end
	end

	animTracks = tracks
end

local function applyFlightMode(mode)
	if flying then
		print("Desactiva el vuelo antes de cambiar el modo de animación.")
		return false
	end

	if mode == "BasicFly" then
		ANIMATIONS = ANIMATIONS_BASIC
		flightAnimMode = "BasicFly"
		stopAllAnimations()
		print("Modo: BasicFly")
		return true
	elseif mode == "FlyPrepared" then
		ANIMATIONS = ANIMATIONS_PREPARED
		flightAnimMode = "FlyPrepared"
		stopAllAnimations()
		print("Modo: FlyPrepared")
		return true
	end
	return false
end

-- Input helpers
local function camBasisFull()
	local cam = camera.CFrame
	return cam.LookVector, cam.RightVector
end

local function getMobileAxes()
	local md = humanoid.MoveDirection
	if md.Magnitude < 0.01 then return 0, 0, 0 end
	local camLook, camRight = camBasisFull()
	local fwdFlat = Vector3.new(camLook.X, 0, camLook.Z)
	if fwdFlat.Magnitude > 0 then fwdFlat = fwdFlat.Unit end
	local rightFlat = Vector3.new(camRight.X, 0, camRight.Z)
	if rightFlat.Magnitude > 0 then rightFlat = rightFlat.Unit end
	return md:Dot(fwdFlat), md:Dot(rightFlat), md.Magnitude
end

local function getKeyboardAxes()
	local f = 0
	local r = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then f = f + 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then f = f - 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then r = r + 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then r = r - 1 end
	return f, r
end

local function isPlayerMoving()
	if humanoid and humanoid.MoveDirection and humanoid.MoveDirection.Magnitude > INPUT_DEADZONE then
		return true
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.A) or
	   UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.D) then
		return true
	end
	return false
end

-- ============= PRELOAD (IMÁGENES + ANIMACIONES) + SPLASH =============
-- Lista de imágenes a precargar (image buttons + indicator)
local IMAGE_ASSET_IDS = {
	"rbxassetid://98500005316067", -- fly off
	"rbxassetid://114583379233058", -- fly on
	"rbxassetid://124646073516633",  -- boost / button texture
	"rbxassetid://108793750615658", -- indicator 0
	"rbxassetid://81527091583929",  -- indicator 1
	"rbxassetid://119716268835917", -- indicator 2
	"rbxassetid://111874213502514", -- indicator 3
}

-- Recopilar todas las animaciones usadas (ANIMATIONS_BASIC, ANIMATIONS_PREPARED, BOOST_LEVELS)
local function collectAnimationIds()
	local ids = {}
	local function add(id)
		if not id then return end
		ids[id] = true
	end
	-- animations basic / prepared
	local function scanTable(t)
		for _, cfg in pairs(t) do
			if type(cfg) == "table" then
				for k, v in pairs(cfg) do
					if type(v) == "string" then
						add(v)
					end
				end
			end
		end
	end
	scanTable(ANIMATIONS_BASIC)
	scanTable(ANIMATIONS_PREPARED)
	-- boost levels
	for _, cfg in pairs(BOOST_LEVELS) do
		for k, v in pairs(cfg) do
			if type(v) == "string" then add(v) end
		end
	end
	-- always include frozen forward
	add("rbxassetid://97169019")
	-- convert to array
	local out = {}
	for k,_ in pairs(ids) do table.insert(out, k) end
	return out
end

-- Loading UI (splash)
local loadingGui = Instance.new("ScreenGui")
loadingGui.Name = "FlyGui_Loading"
loadingGui.ResetOnSpawn = false

local splashFrame = Instance.new("Frame")
splashFrame.Size = UDim2.new(0, 420, 0, 160)
splashFrame.Position = UDim2.new(0.5, -210, 0.5, -80)
splashFrame.AnchorPoint = Vector2.new(0,0)
splashFrame.BackgroundColor3 = Color3.fromRGB(18,18,18)
splashFrame.BorderSizePixel = 0
splashFrame.Parent = loadingGui
splashFrame.ZIndex = 1000
splashFrame.BackgroundTransparency = 1

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -24, 0, 36)
titleLabel.Position = UDim2.new(0, 12, 0, 12)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "FlyInvencible — cargando assets..."
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 20
titleLabel.TextColor3 = Color3.fromRGB(230,230,230)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = splashFrame
titleLabel.ZIndex = 1001

local detailLabel = Instance.new("TextLabel")
detailLabel.Size = UDim2.new(1, -24, 0, 24)
detailLabel.Position = UDim2.new(0, 12, 0, 48)
detailLabel.BackgroundTransparency = 1
detailLabel.Text = "Preparando animaciones e imágenes..."
detailLabel.Font = Enum.Font.SourceSans
detailLabel.TextSize = 14
detailLabel.TextColor3 = Color3.fromRGB(190,190,190)
detailLabel.TextXAlignment = Enum.TextXAlignment.Left
detailLabel.Parent = splashFrame
detailLabel.ZIndex = 1001

local progressBg = Instance.new("Frame")
progressBg.Size = UDim2.new(1, -24, 0, 12)
progressBg.Position = UDim2.new(0, 12, 0, 84)
progressBg.BackgroundColor3 = Color3.fromRGB(45,45,45)
progressBg.BorderSizePixel = 0
progressBg.Parent = splashFrame
progressBg.ZIndex = 1001
progressBg.AnchorPoint = Vector2.new(0,0)

local progressFill = Instance.new("Frame")
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.Position = UDim2.new(0,0,0,0)
progressFill.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
progressFill.BorderSizePixel = 0
progressFill.Parent = progressBg
progressFill.ZIndex = 1002

local pctLabel = Instance.new("TextLabel")
pctLabel.Size = UDim2.new(0, 60, 0, 18)
pctLabel.Position = UDim2.new(1, -72, 0, 64)
pctLabel.BackgroundTransparency = 1
pctLabel.Text = "0%"
pctLabel.Font = Enum.Font.SourceSansSemibold
pctLabel.TextSize = 14
pctLabel.TextColor3 = Color3.fromRGB(220,220,220)
pctLabel.Parent = splashFrame
pctLabel.ZIndex = 1001

-- keep loading gui visible immediately
loadingGui.Parent = playerGui
splashFrame.BackgroundTransparency = 0.05

-- MAIN screenGui (UI principal). Lo creamos pero NO lo ponemos aún en PlayerGui hasta que termine la precarga
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FlyGui"
screenGui.ResetOnSpawn = false

-- --- (UI CREATION: flyBtn / indicator / mode gui / boostBtn)
-- Crear botón de vuelo
local flyBtn = Instance.new("ImageButton")
flyBtn.Name = "Flybtn"
flyBtn.Position = UDim2.new(0.855, 0, 0.426, 0)
flyBtn.Size = UDim2.new(0, 173, 0, 83)
flyBtn.BackgroundTransparency = 1
flyBtn.BorderSizePixel = 0
flyBtn.Image = "rbxassetid://98500005316067" -- Apagado
flyBtn.Parent = screenGui

-- Overlay para el efecto de iluminación
local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.Position = UDim2.new(0, 0, 0, 0)
overlay.BackgroundColor3 = Color3.fromRGB(145, 145, 145)
overlay.BackgroundTransparency = 1
overlay.BorderSizePixel = 0
overlay.Parent = flyBtn

-- Variables de estado UI
local isHovering = false
local isPressing = false
local originalSize = UDim2.new(0, 173, 0, 83)
local pressedSize = UDim2.new(0, 146, 0, 56)
local originalPos = UDim2.new(0.855, 0, 0.426, 0)
local pressedPos = UDim2.new(0.855, 0, 0.426, 0) + UDim2.new(0, (173-146)/2, 0, (83-56)/2)

-- Función para animar el botón al presionarlo
local function animatePress()
	if isPressing then return end
	isPressing = true
	
	-- Tween down (0.12 segundos suave)
	local tweenDown = TweenService:Create(
		flyBtn,
		TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = pressedSize, Position = pressedPos}
	)
	tweenDown:Play()
	
	-- Iluminar overlay (0.18 segundos progresivo)
	local tweenOverlay = TweenService:Create(
		overlay,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{BackgroundTransparency = 0.3}
	)
	tweenOverlay:Play()
	
	tweenDown.Completed:Connect(function()
		-- Esperar un poco y luego recuperar posición
		task.wait(0.08)
		
		local tweenUp = TweenService:Create(
			flyBtn,
			TweenInfo.new(0.16, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
			{Size = originalSize, Position = originalPos}
		)
		tweenUp:Play()
		
		local tweenOverlayOff = TweenService:Create(
			overlay,
			TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{BackgroundTransparency = 1}
		)
		tweenOverlayOff:Play()
		
		tweenUp.Completed:Connect(function()
			isPressing = false
		end)
	end)
end

-- Función para el hover
local function setHoverState(hovering)
	if isHovering == hovering then return end
	isHovering = hovering
	
	if hovering then
		local tweenHoverDown = TweenService:Create(
			flyBtn,
			TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = UDim2.new(0, 160, 0, 73), Position = UDim2.new(0.855, 0, 0.426, 0) + UDim2.new(0, 6.5, 0, 5)}
		)
		tweenHoverDown:Play()
		
		local tweenHoverOverlay = TweenService:Create(
			overlay,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{BackgroundTransparency = 0.5}
		)
		tweenHoverOverlay:Play()
	else
		local tweenHoverUp = TweenService:Create(
			flyBtn,
			TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = originalSize, Position = originalPos}
		)
		tweenHoverUp:Play()
		
		local tweenHoverOverlayOff = TweenService:Create(
			overlay,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{BackgroundTransparency = 1}
		)
		tweenHoverOverlayOff:Play()
	end
end

-- Función para cambiar la imagen del botón
local function updateFlyButtonImage()
	if flying then
		flyBtn.Image = "rbxassetid://114583379233058" -- Encendido
	else
		flyBtn.Image = "rbxassetid://98500005316067" -- Apagado
	end
end

-- ========== INDICADOR DE VELOCIDAD (SOLO IMAGELABEL) ==========
-- INDICADOR: configuración de IDs de imagen para los estados
local INDICATOR_IMAGES = {
	[0] = "rbxassetid://108793750615658", -- nivel 0 (aparece cuando Flybtn=true)
	[1] = "rbxassetid://81527091583929",  -- nivel 1
	[2] = "rbxassetid://119716268835917", -- nivel 2
	[3] = "rbxassetid://111874213502514", -- nivel 3
}

local indicator = nil
local indicatorVisible = false
local indicatorOriginalSize = UDim2.new(0, 220, 0, 220)
local indicatorOriginalPos = UDim2.new(0.943, 0, 0.310, 0)

local function createIndicator()
	if indicator and indicator.Parent then return end
	indicator = Instance.new("ImageLabel")
	indicator.Name = "SpeedIndicator"
	indicator.AnchorPoint = Vector2.new(0.5, 0.5)
	-- Para centrar respecto a la posición dada
	indicator.Position = indicatorOriginalPos
	indicator.Size = indicatorOriginalSize
	indicator.BackgroundTransparency = 1 -- PNG sin fondo
	indicator.BorderSizePixel = 0
	indicator.Image = INDICATOR_IMAGES[0]
	indicator.ImageTransparency = 1 -- iniciar invisible hasta que Fly true
	indicator.Parent = screenGui
	indicator.ZIndex = 10
end

local function showIndicator()
	if not indicator then createIndicator() end
	if indicatorVisible then return end
	indicatorVisible = true
	-- Fade in
	local tweenIn = TweenService:Create(indicator, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {ImageTransparency = 0})
	tweenIn:Play()
	-- small subtle pop
	local pop1 = TweenService:Create(indicator, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 240, 0, 240)})
	local pop2 = TweenService:Create(indicator, TweenInfo.new(0.28, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {Size = indicatorOriginalSize})
	pop1:Play()
	pop1.Completed:Connect(function() pop2:Play() end)
end

local function hideIndicator()
	if not indicator or not indicatorVisible then return end
	indicatorVisible = false
	-- Fade out suavemente y reducir tamaño
	local tweenOut1 = TweenService:Create(indicator, TweenInfo.new(0.30, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {ImageTransparency = 1})
	local tweenOut2 = TweenService:Create(indicator, TweenInfo.new(0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {Size = UDim2.new(0, 160, 0, 160)})
	tweenOut1:Play()
	tweenOut2:Play()
end

local currentIndicatorState = 0
local indicatorTweenRunning = false

local function setIndicatorState(level)
	-- level expected 0..3
	if level == nil then level = 0 end
	if not indicator then createIndicator() end
	-- clamp
	if level < 0 then level = 0 end
	if level > 3 then level = 3 end

	-- if same state, no cambio (pero podemos dar un pequeño salto estético)
	if currentIndicatorState == level then
		-- pequeño salto para feedback
		local jump1 = TweenService:Create(indicator, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 205, 0, 205)})
		local jump2 = TweenService:Create(indicator, TweenInfo.new(0.22, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {Size = indicatorOriginalSize})
		jump1:Play()
		jump1.Completed:Connect(function() jump2:Play() end)
		return
	end

	currentIndicatorState = level
	-- cambiar imagen con fade y pequeño salto elegante
	local newImage = INDICATOR_IMAGES[level] or INDICATOR_IMAGES[0]
	-- Fade out current quickly, switch image, fade in slowly
	local fadeOut = TweenService:Create(indicator, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {ImageTransparency = 0.7})
	fadeOut:Play()
	fadeOut.Completed:Connect(function()
		indicator.Image = newImage
		-- pequeño "salto": reducir y volver
		local jump1 = TweenService:Create(indicator, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 190, 0, 190)})
		local jump2 = TweenService:Create(indicator, TweenInfo.new(0.35, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {Size = indicatorOriginalSize, ImageTransparency = 0})
		jump1:Play()
		jump1.Completed:Connect(function() jump2:Play() end)
	end)
end

-- ========== FIN INDICADOR ==========

-- ========== MODE GUI ==========
-- Crear GUI de modos: toggle draggable (círculo gris oscuro) y panel de modos
local modeGui = Instance.new("Folder")
modeGui.Name = "ModeGui"
modeGui.Parent = screenGui

-- Toggle (círculo gris oscuro, draggable)
local modeToggle = Instance.new("ImageButton")
modeToggle.Name = "ModeToggle"
modeToggle.AnchorPoint = Vector2.new(0.5, 0.5)
modeToggle.Position = UDim2.new(0.08, 0, 0.5, 0) -- posición inicial (movible)
modeToggle.Size = UDim2.new(0, 54, 0, 54)
modeToggle.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
modeToggle.BackgroundTransparency = 0
modeToggle.Image = "" -- sin imagen, solo color
modeToggle.AutoButtonColor = false
modeToggle.BorderSizePixel = 0
modeToggle.ZIndex = 20
modeToggle.Parent = modeGui
modeToggle.ClipsDescendants = true

-- Small inner dot to look nicer
local innerDot = Instance.new("Frame")
innerDot.Name = "InnerDot"
innerDot.Size = UDim2.new(0, 18, 0, 18)
innerDot.Position = UDim2.new(0.5, -9, 0.5, -9)
innerDot.BackgroundColor3 = Color3.fromRGB(70,70,70)
innerDot.BorderSizePixel = 0
innerDot.Parent = modeToggle
innerDot.ZIndex = 21
innerDot.AnchorPoint = Vector2.new(0,0)

-- Panel desplegable (inicialmente oculto)
local modePanel = Instance.new("Frame")
modePanel.Name = "ModePanel"
modePanel.AnchorPoint = Vector2.new(0.5, 0.5)
modePanel.Size = UDim2.new(0, 220, 0, 120)
modePanel.Position = modeToggle.Position + UDim2.new(0, 0, -0.18, 0)
modePanel.BackgroundTransparency = 1
modePanel.BorderSizePixel = 0
modePanel.Parent = modeGui
modePanel.ZIndex = 19
modePanel.Visible = true -- lo mantenemos visible pero con transparencia 1 para tweens

-- Panel background visual
local panelBg = Instance.new("Frame")
panelBg.Name = "PanelBg"
panelBg.Size = UDim2.new(1, 0, 1, 0)
panelBg.Position = UDim2.new(0, 0, 0, 0)
panelBg.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
panelBg.BackgroundTransparency = 0.95
panelBg.BorderSizePixel = 0
panelBg.Parent = modePanel
panelBg.ZIndex = 19
panelBg.ClipsDescendants = true

-- Title
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 24)
title.Position = UDim2.new(0, 0, 0, 6)
title.BackgroundTransparency = 1
title.Text = "Flight Modes"
title.Font = Enum.Font.SourceSansBold
title.TextSize = 14
title.TextColor3 = Color3.fromRGB(220,220,220)
title.Parent = modePanel
title.ZIndex = 20

-- Buttons: FlyBasic & FlyPrepared
local btnBasic = Instance.new("TextButton")
btnBasic.Name = "BtnBasic"
btnBasic.Size = UDim2.new(0.9, 0, 0, 36)
btnBasic.Position = UDim2.new(0.05, 0, 0, 36)
btnBasic.BackgroundColor3 = Color3.fromRGB(45,45,45)
btnBasic.BorderSizePixel = 0
btnBasic.Text = "FlyBasic"
btnBasic.Font = Enum.Font.SourceSans
btnBasic.TextSize = 16
btnBasic.TextColor3 = Color3.fromRGB(200,200,200)
btnBasic.AutoButtonColor = false
btnBasic.ZIndex = 20
btnBasic.Parent = modePanel

local btnPrepared = Instance.new("TextButton")
btnPrepared.Name = "BtnPrepared"
btnPrepared.Size = UDim2.new(0.9, 0, 0, 36)
btnPrepared.Position = UDim2.new(0.05, 0, 0, 76)
btnPrepared.BackgroundColor3 = Color3.fromRGB(45,45,45)
btnPrepared.BorderSizePixel = 0
btnPrepared.Text = "FlyPrepared"
btnPrepared.Font = Enum.Font.SourceSans
btnPrepared.TextSize = 16
btnPrepared.TextColor3 = Color3.fromRGB(200,200,200)
btnPrepared.AutoButtonColor = false
btnPrepared.ZIndex = 20
btnPrepared.Parent = modePanel

-- Estado del panel (hidden/shown)
local modePanelVisible = false
-- Asegurar panel inicialmente escondido (transparente y reducido)
modePanel.BackgroundTransparency = 1
panelBg.BackgroundTransparency = 1
modePanel.Size = UDim2.new(0, 0, 0, 0)
-- ADDED: hide text initially (do not show labels when panel hidden)
title.TextTransparency = 1
btnBasic.TextTransparency = 1
btnPrepared.TextTransparency = 1

-- Popup de error instructivo
local modeErrorPopup = Instance.new("TextLabel")
modeErrorPopup.Name = "ModeErrorPopup"
modeErrorPopup.Size = UDim2.new(0, 220, 0, 36)
modeErrorPopup.Position = modeToggle.Position + UDim2.new(0.12, 0, -0.08, 0)
modeErrorPopup.AnchorPoint = Vector2.new(0, 0.5)
modeErrorPopup.BackgroundColor3 = Color3.fromRGB(180,50,50)
modeErrorPopup.TextColor3 = Color3.fromRGB(255,255,255)
modeErrorPopup.Font = Enum.Font.SourceSansBold
modeErrorPopup.TextSize = 14
modeErrorPopup.Text = "error:primero desactivado el vuelo/off fly"
modeErrorPopup.BackgroundTransparency = 1
modeErrorPopup.BorderSizePixel = 0
modeErrorPopup.Visible = false
modeErrorPopup.ZIndex = 30
modeErrorPopup.Parent = modeGui

local function showModeError()
	-- show popup near toggle
	modeErrorPopup.Position = modeToggle.Position + UDim2.new(0.12, 0, -0.08, 0)
	modeErrorPopup.BackgroundTransparency = 0.1
	modeErrorPopup.Visible = true
	modeErrorPopup.TextTransparency = 0
	modeErrorPopup.Size = UDim2.new(0, 220, 0, 36)
	modeErrorPopup.BackgroundColor3 = Color3.fromRGB(180,50,50)
	-- Tween in
	local t1 = TweenService:Create(modeErrorPopup, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0, TextTransparency = 0})
	t1:Play()
	-- Auto hide after 1.8s
	task.delay(1.8, function()
		local t2 = TweenService:Create(modeErrorPopup, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1, TextTransparency = 1})
		t2:Play()
		t2.Completed:Wait()
		modeErrorPopup.Visible = false
	end)
end

local function showModePanel()
	if modePanelVisible then return end
	modePanelVisible = true
	modePanel.Position = modeToggle.Position + UDim2.new(0, 0, -0.18, 0)
	local tSize = TweenService:Create(modePanel, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 220, 0, 120)})
	local tBg = TweenService:Create(panelBg, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.85})
	tSize:Play(); tBg:Play()
	local tText1 = TweenService:Create(title, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextTransparency = 0})
	local tText2 = TweenService:Create(btnBasic, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextTransparency = 0})
	local tText3 = TweenService:Create(btnPrepared, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextTransparency = 0})
	tText1:Play(); tText2:Play(); tText3:Play()
	if flightAnimMode == "BasicFly" then
		btnBasic.BackgroundColor3 = Color3.fromRGB(75,75,75); btnPrepared.BackgroundColor3 = Color3.fromRGB(45,45,45)
	else
		btnPrepared.BackgroundColor3 = Color3.fromRGB(75,75,75); btnBasic.BackgroundColor3 = Color3.fromRGB(45,45,45)
	end
end

local function hideModePanel()
	if not modePanelVisible then return end
	modePanelVisible = false
	local tSize = TweenService:Create(modePanel, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0)})
	local tBg = TweenService:Create(panelBg, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1})
	tSize:Play(); tBg:Play()
	local tText1 = TweenService:Create(title, TweenInfo.new(0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {TextTransparency = 1})
	local tText2 = TweenService:Create(btnBasic, TweenInfo.new(0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {TextTransparency = 1})
	local tText3 = TweenService:Create(btnPrepared, TweenInfo.new(0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {TextTransparency = 1})
	tText1:Play(); tText2:Play(); tText3:Play()
end

-- Drag logic for modeToggle
local dragging = false
local dragInput = nil
local dragStart = nil
local startPos = nil
local dragThreshold = 6 -- pixels to differentiate drag vs click

modeToggle.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = modeToggle.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				-- end of input
				dragging = false
				-- check small movement to treat as click toggle
				local moved = (input.Position - dragStart).magnitude
				if moved <= dragThreshold then
					-- click (toggle visibility)
					if modePanelVisible then hideModePanel() else showModePanel() end
				end
			end
		end)
	end
end)

modeToggle.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)

-- Connection to update while dragging
local dragConnection
dragConnection = UserInputService.InputChanged:Connect(function(input)
	if input == dragInput and dragging and startPos and dragStart then
		local delta = input.Position - dragStart
		local screenSize = workspace.CurrentCamera.ViewportSize
		-- compute new position in UDim2 space (approx)
		local x = (startPos.X.Offset + delta.X) / screenSize.X
		local y = (startPos.Y.Offset + delta.Y) / screenSize.Y
		-- clamp between 0.05 and 0.95
		x = math.clamp(x, 0.02, 0.98)
		y = math.clamp(y, 0.05, 0.95)
		modeToggle.Position = UDim2.new(x, 0, y, 0)
		-- move panel and popup relative
		modePanel.Position = modeToggle.Position + UDim2.new(0, 0, -0.18, 0)
		modeErrorPopup.Position = modeToggle.Position + UDim2.new(0.12, 0, -0.08, 0)
	end
end)

-- Button behavior: change mode only if flying == false, else show error
btnBasic.MouseButton1Click:Connect(function()
	if flying then
		showModeError()
		return
	end
	local ok = applyFlightMode("BasicFly")
	if ok then
		-- visual feedback
		btnBasic.BackgroundColor3 = Color3.fromRGB(75,75,75)
		btnPrepared.BackgroundColor3 = Color3.fromRGB(45,45,45)
		-- hide panel after change
		hideModePanel()
	end
end)

btnPrepared.MouseButton1Click:Connect(function()
	if flying then
		showModeError()
		return
	end
	local ok = applyFlightMode("FlyPrepared")
	if ok then
		btnPrepared.BackgroundColor3 = Color3.fromRGB(75,75,75)
		btnBasic.BackgroundColor3 = Color3.fromRGB(45,45,45)
		hideModePanel()
	end
end)

-- Ensure panel hides by default
hideModePanel()

-- Evento del botón: Click
flyBtn.MouseButton1Click:Connect(function()
	animatePress()
	
	-- Ejecutar lógica de vuelo
	flying = not flying
	if flying then
		levBaseY = hrp.Position.Y
		tAccum = 0
		wasMoving = isPlayerMoving()
		createBodyMovers()
		humanoid.PlatformStand = true
		playIdleAnimations()
		if boostLevel == 0 then
			targetSpeed = BASE_SPEED
			targetFOV = FOV_BASE
		else
			targetSpeed = BOOST_SPEEDS[boostLevel]
			targetFOV = FOV_LEVELS[boostLevel]
			playBoostAnimation(boostLevel)
		end
		print("Vuelo activado")
		-- Show indicator (nivel 0 por defecto)
		showIndicator()
		setIndicatorState(boostLevel or 0)
	else
		removeBodyMovers()
		humanoid.PlatformStand = false
		boostLevel = 0
		targetSpeed = BASE_SPEED
		targetFOV = FOV_BASE
		stopAllAnimations()
		print("Vuelo desactivado")
		-- Hide indicator
		hideIndicator()
	end
	
	updateFlyButtonImage()
end)

-- Hover events
flyBtn.MouseEnter:Connect(function()
	setHoverState(true)
end)

flyBtn.MouseLeave:Connect(function()
	setHoverState(false)
end)

-- ============= BOOST BUTTON CREATION =============
local boostBtn = Instance.new("ImageButton")
boostBtn.Name = "Boostbtn"
boostBtn.Position = UDim2.new(0.855, 0, 0.262, 0)
boostBtn.Size = UDim2.new(0, 173, 0, 83)
boostBtn.BackgroundTransparency = 1
boostBtn.BorderSizePixel = 0
boostBtn.Image = "rbxassetid://124646073516633"
boostBtn.Parent = screenGui

-- Overlay para boost button
local boostOverlay = Instance.new("Frame")
boostOverlay.Name = "Overlay"
boostOverlay.Size = UDim2.new(1, 0, 1, 0)
boostOverlay.Position = UDim2.new(0, 0, 0, 0)
boostOverlay.BackgroundColor3 = Color3.fromRGB(145, 145, 145)
boostOverlay.BackgroundTransparency = 1
boostOverlay.BorderSizePixel = 0
boostOverlay.Parent = boostBtn

-- Variables de estado para boost button
local boostIsHovering = false
local boostIsPressing = false
local boostOriginalSize = UDim2.new(0, 173, 0, 83)
local boostPressedSize = UDim2.new(0, 146, 0, 56)
local boostOriginalPos = UDim2.new(0.855, 0, 0.262, 0)
local boostPressedPos = UDim2.new(0.855, 0, 0.262, 0) + UDim2.new(0, (173-146)/2, 0, (83-56)/2)

-- Función para animar boost button al presionarlo
local function animateBoostPress()
	if boostIsPressing then return end
	boostIsPressing = true
	
	-- Tween down (0.12 segundos suave)
	local tweenDown = TweenService:Create(
		boostBtn,
		TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = boostPressedSize, Position = boostPressedPos}
	)
	tweenDown:Play()
	
	-- Iluminar overlay (0.18 segundos progresivo)
	local tweenOverlay = TweenService:Create(
		boostOverlay,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{BackgroundTransparency = 0.3}
	)
	tweenOverlay:Play()
	
	tweenDown.Completed:Connect(function()
		-- Esperar un poco y luego recuperar posición
		task.wait(0.08)
		
		local tweenUp = TweenService:Create(
			boostBtn,
			TweenInfo.new(0.16, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
			{Size = boostOriginalSize, Position = boostOriginalPos}
		)
		tweenUp:Play()
		
		local tweenOverlayOff = TweenService:Create(
			boostOverlay,
			TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{BackgroundTransparency = 1}
		)
		tweenOverlayOff:Play()
		
		tweenUp.Completed:Connect(function()
			boostIsPressing = false
		end)
	end)
end

-- Función para el hover del boost button
local function setBoostHoverState(hovering)
	if boostIsHovering == hovering then return end
	boostIsHovering = hovering
	
	if hovering then
		local tweenHoverDown = TweenService:Create(
			boostBtn,
			TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = UDim2.new(0, 160, 0, 73), Position = UDim2.new(0.855, 0, 0.262, 0) + UDim2.new(0, 6.5, 0, 5)}
		)
		tweenHoverDown:Play()
		
		local tweenHoverOverlay = TweenService:Create(
			boostOverlay,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{BackgroundTransparency = 0.5}
		)
		tweenHoverOverlay:Play()
	else
		local tweenHoverUp = TweenService:Create(
			boostBtn,
			TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = boostOriginalSize, Position = boostOriginalPos}
		)
		tweenHoverUp:Play()
		
		local tweenHoverOverlayOff = TweenService:Create(
			boostOverlay,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{BackgroundTransparency = 1}
		)
		tweenHoverOverlayOff:Play()
	end
end

-- Función para procesar boost click (ciclo de 4 niveles: 0 -> 1 -> 2 -> 3 -> 0)
local function processBoostClick()
	-- Solo funciona si flying = true Y el jugador se está moviendo
	if not flying or not isPlayerMoving() then
		return
	end
	
	-- Ciclo correcto: 0 -> 1 -> 2 -> 3 -> 0
	boostLevel = (boostLevel + 1) % 4
	
	if boostLevel == 0 then
		targetSpeed = BASE_SPEED
		targetFOV = FOV_BASE
		playIdleAnimations()
		print("Boost desactivado (Nivel 0)")
	elseif boostLevel == 1 then
		targetSpeed = BOOST_SPEEDS[1]
		targetFOV = FOV_LEVELS[1]
		playBoostAnimation(1)
		print("Boost activado: Nivel 1")
	elseif boostLevel == 2 then
		targetSpeed = BOOST_SPEEDS[2]
		targetFOV = FOV_LEVELS[2]
		playBoostAnimation(2)
		print("Boost activado: Nivel 2")
	elseif boostLevel == 3 then
		targetSpeed = BOOST_SPEEDS[3]
		targetFOV = FOV_LEVELS[3]
		playBoostAnimation(3)
		print("Boost activado: Nivel 3")
	end

	-- Actualizar indicador visual (si está visible)
	if flying then
		showIndicator()
		setIndicatorState(boostLevel)
	end
end

-- Evento del botón boost: Click
boostBtn.MouseButton1Click:Connect(function()
	animateBoostPress()
	processBoostClick()
end)

-- Hover events para boost button
boostBtn.MouseEnter:Connect(function()
	if flying then
		setBoostHoverState(true)
	end
end)

boostBtn.MouseLeave:Connect(function()
	setBoostHoverState(false)
end)

-- NOTE: tecla "M" removida. Cambiar de modo ahora desde el GUI de modos.

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
			playIdleAnimations()
			-- actualizar indicador a nivel 0 cuando el jugador ya no se mueve
			if flying then
				showIndicator()
				setIndicatorState(0)
			end
		end
	end
	wasMoving = movingNow

	if not flying then
		currentCamRoll = currentCamRoll + (0 - currentCamRoll) * math.clamp(dt * 8, 0, 1)
		local camPos = camera.CFrame.Position
		local camLookVec = camera.CFrame.LookVector
		local desiredCamCFrame = CFrame.lookAt(camPos, camPos + camLookVec, Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, currentCamRoll)
		camera.CFrame = camera.CFrame:Lerp(desiredCamCFrame, math.clamp(dt * 8, 0, 1))
		if bodyVel then bodyVel.MaxForce = Vector3.new(0, 0, 0) bodyVel.Velocity = Vector3.new(0, 0, 0) end
		if bodyGyro then bodyGyro.MaxTorque = Vector3.new(0, 0, 0) end
		return
	end

	-- Levitación
	local omega = 2 * math.pi * LEV_FREQ
	local levDisp = LEV_AMPL * math.sin(omega * tAccum)
	local levVel = LEV_AMPL * omega * math.cos(omega * tAccum)

	-- Inputs
	local kbF, kbR = getKeyboardAxes()
	local mF, mR, mMag = getMobileAxes()
	local fwdAxis = kbF + mF
	local rightAxis = kbR + mR
	local inputMag = math.sqrt(fwdAxis * fwdAxis + rightAxis * rightAxis)

	-- Movimiento
	if inputMag < INPUT_DEADZONE then
		local targetVel = Vector3.new(0, levVel, 0)
		if bodyVel then bodyVel.Velocity = bodyVel.Velocity:Lerp(targetVel, math.clamp(dt * (VEL_LERP * 1.3), 0, 1)) end
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

	-- Orientación + inclinaciones
	local camLook = camera.CFrame.LookVector
	local desiredCFrameBase = CFrame.lookAt(hrp.Position, hrp.Position + camLook, Vector3.new(0, 1, 0))

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
		bodyGyro.P = 3000
		bodyGyro.D = 200
	end

	local targetCamRoll = math.rad(finalTiltSide) * CAMERA_ROLL_INFLUENCE
	currentCamRoll = currentCamRoll + (targetCamRoll - currentCamRoll) * math.clamp(dt * 8, 0, 1)
	local camPos = camera.CFrame.Position
	local camLookVec = camera.CFrame.LookVector
	local desiredCamCFrame2 = CFrame.lookAt(camPos, camPos + camLookVec, Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, currentCamRoll)
	camera.CFrame = camera.CFrame:Lerp(desiredCamCFrame2, math.clamp(dt * 8, 0, 1))

	-- Animaciones
	if boostLevel == 0 then
		if inputMag > INPUT_DEADZONE and fwdAxis > 0.25 then
			playForwardAnimations()
		elseif inputMag > INPUT_DEADZONE and fwdAxis < -0.25 then
			playBackwardAnimations()
		else
			playIdleAnimations()
		end
	end
end)

-- Respawn handling
humanoid.Died:Connect(function()
	if flying then
		flying = false
		removeBodyMovers()
		humanoid.PlatformStand = false
		boostLevel = 0
		targetSpeed = BASE_SPEED
		targetFOV = FOV_BASE
		stopAllAnimations()
		updateFlyButtonImage()
		-- Hide indicator on death
		hideIndicator()
	end
	-- hide mode panel and reset toggle on death
	hideModePanel()
	modeToggle.Position = UDim2.new(0.08, 0, 0.5, 0)
	modeErrorPopup.Visible = false

player.CharacterAdded:Connect(function(char)
	character = char
	humanoid = character:WaitForChild("Humanoid")
	hrp = character:WaitForChild("HumanoidRootPart")
	removeBodyMovers()
	flying = false
	humanoid.PlatformStand = false
	boostLevel = 0
	targetSpeed = BASE_SPEED
	targetFOV = FOV_BASE
	stopAllAnimations()
	updateFlyButtonImage()
	screenGui.Parent = player:WaitForChild("PlayerGui")
	-- Ensure indicator is reset
	if indicator then
		indicator.Image = INDICATOR_IMAGES[0]
		indicator.ImageTransparency = 1
		indicator.Size = indicatorOriginalSize
		indicatorVisible = false
	end
	-- ensure mode gui reset
	hideModePanel()
	modeToggle.Position = UDim2.new(0.08, 0, 0.5, 0)
	modeErrorPopup.Visible = false

	-- recreate precached forward animation asset for new humanoid (no play)
	createFrozenForwardTrack()
end)

-- create precache now (initial humanoid loaded)
-- Preload logic: sequential to display progress
task.spawn(function()
	-- Build list of animation ids to preload
	local animList = collectAnimationIds()
	-- add to preloadedAnimations table (Animation objects) and also mark for ContentProvider maybe not needed but do both
	for _, aid in ipairs(animList) do
		preloadAnimationAsset(aid)
	end

	-- Build full image list (use the IMAGE_ASSET_IDS table)
	local total = #IMAGE_ASSET_IDS + #animList
	local done = 0

	-- Helper to update progress visuals
	local function updateProgress()
		local pct = math.floor((done / total) * 100)
		pctLabel.Text = tostring(pct) .. "%"
		local target = math.clamp(done / total, 0, 1)
		pcall(function()
			TweenService:Create(progressFill, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(target, 0, 1, 0)}):Play()
		end)
	end

	-- Preload images sequentially so we can show percent
	for _, img in ipairs(IMAGE_ASSET_IDS) do
		local ok, err = pcall(function() ContentProvider:PreloadAsync({img}) end)
		done = done + 1
		updateProgress()
		-- small yield so UI updates and ROBLOX can breathe
		task.wait(0.04)
		if not ok then
			warn("Preload image failed:", img, err)
		end
	end

	-- Preload animations via ContentProvider (Animation objects cannot be preloaded via ContentProvider reliably,
	-- but we've already created Animation instances in preloadedAnimations; to be safe we iterate and call PreloadAsync on their AnimationId)
	for _, aid in ipairs(animList) do
		local ok, err = pcall(function() ContentProvider:PreloadAsync({aid}) end)
		done = done + 1
		updateProgress()
		task.wait(0.02)
		if not ok then
			warn("Preload anim failed:", aid, err)
		end
	end

	-- mark done
	updateProgress()
	task.wait(0.12)

	-- Play a little completion animation on splash
	pctLabel.Text = "100%"
	TweenService:Create(progressFill, TweenInfo.new(0.28, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 1, 0)}):Play()
	detailLabel.Text = "¡Listo! inicializando UI..."
	task.wait(0.45)

	-- Hide splash gracefully
	local tHide = TweenService:Create(splashFrame, TweenInfo.new(0.28, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {BackgroundTransparency = 1})
	tHide:Play()
	tHide.Completed:Wait()

	loadingGui:Destroy()

	-- Attach main UI
	screenGui.Parent = player:WaitForChild("PlayerGui")

	-- ensure frozen animation is cached
	createFrozenForwardTrack()
end)

print("FlyInvencible Ultimate (ACTUALIZADO) cargado — Hecho por:G1")
