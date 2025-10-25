local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Configuración
local FLIGHT_SPEED = 39.93
local BOOST_SPEEDS = {
	normal = 79.87,
	fast = 199.66,
	viltrum = 319.46
}
local TILT_FORWARD = 30
local TILT_BACKWARD = 30
local TILT_SIDE = 25
local BOOST_TILT_FORWARD = 90
local HOVER_AMPLITUDE = 1.5
local HOVER_SPEED = 1.5
local ASCENT_HEIGHT = 3
local TILT_SMOOTHNESS = 0.15
local BOOST_TILT_SMOOTHNESS = 0.08

-- Variables de estado
local isFlying = false
local boostLevel = 0
local currentSpeed = FLIGHT_SPEED
local bodyVelocity
local bodyGyro
local hoverFriend
local moveDirection = Vector3.new(0, 0, 0)
local currentTilt = CFrame.new()
local targetTilt = CFrame.new()
local hoverTime = 0
local currentAnimation
local lastAnimationState = "idle"
local defaultFOV = 70
local isMoving = false
local lastMovementTime = 0
local MOVEMENT_TIMEOUT = 0.1

-- IDs de animaciones
local ANIM_IDLE = 73033633
local ANIM_FORWARD = 165167557
local ANIM_BACKWARD = 79155105
local ANIM_SIDE = 94116311
local ANIM_BOOST_NORMAL = 90872539
local ANIM_BOOST_FAST = 56153856
local ANIM_BOOST_VILTRUM = 75476911

-- FOV para cada nivel de boost
local FOV_LEVELS = {
	[0] = 70,
	[1] = 80,
	[2] = 95,
	[3] = 110
}

-- Variables móviles
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local movementButtons = {}
local flyButton
local boostButton
local boostIndicator

-- Crear GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FlightGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Botón de activación de vuelo (MEJORADO)
local function createFlyButton()
	local button = Instance.new("TextButton")
	button.Name = "FlyButton"
	button.Size = UDim2.new(0, 120, 0, 50)
	button.Position = UDim2.new(1, -140, 0, 20)
	button.BackgroundColor3 = Color3.fromRGB(220, 50, 50) -- Rojo
	button.BackgroundTransparency = 0.3 -- Transparencia
	button.Text = "FLY"
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 24
	button.Font = Enum.Font.GothamBold
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Parent = screenGui
	
	-- Forma de cápsula (bordes circulares)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = button
	
	return button
end

-- Botón de boost (MEJORADO)
local function createBoostButton()
	local button = Instance.new("TextButton")
	button.Name = "BoostButton"
	button.Size = UDim2.new(0, 120, 0, 50)
	button.Position = UDim2.new(1, -270, 0, 20) -- Al lado izquierdo del botón Fly
	button.BackgroundColor3 = Color3.fromRGB(70, 130, 200) -- Azul suave
	button.BackgroundTransparency = 0.3 -- Transparencia
	button.Text = "BOOST"
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 22
	button.Font = Enum.Font.GothamBold
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Parent = screenGui
	
	-- Forma de cápsula
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = button
	
	-- Indicador de velocidad (rayita)
	local indicator = Instance.new("Frame")
	indicator.Name = "SpeedIndicator"
	indicator.Size = UDim2.new(0, 100, 0, 6)
	indicator.Position = UDim2.new(0, 10, 1, 8)
	indicator.BackgroundColor3 = Color3.fromRGB(80, 80, 80) -- Gris oscuro (desactivado)
	indicator.BorderSizePixel = 0
	indicator.Parent = button
	
	local indicatorCorner = Instance.new("UICorner")
	indicatorCorner.CornerRadius = UDim.new(1, 0)
	indicatorCorner.Parent = indicator
	
	return button, indicator
end

-- Crear controles móviles (MEJORADOS - Circulares con flechas)
local function createMobileControls()
	if not isMobile then return end
	
	local controlFrame = Instance.new("Frame")
	controlFrame.Name = "MobileControls"
	controlFrame.Size = UDim2.new(0, 200, 0, 200)
	controlFrame.Position = UDim2.new(0, 20, 1, -220)
	controlFrame.BackgroundTransparency = 1
	controlFrame.Parent = screenGui
	controlFrame.Visible = false
	
	local buttonData = {
		{name = "W", pos = UDim2.new(0.5, -30, 0, 0), key = "w", arrow = "▲"},
		{name = "A", pos = UDim2.new(0, 0, 0.5, -30), key = "a", arrow = "◄"},
		{name = "S", pos = UDim2.new(0.5, -30, 1, -60), key = "s", arrow = "▼"},
		{name = "D", pos = UDim2.new(1, -60, 0.5, -30), key = "d", arrow = "►"}
	}
	
	for _, data in ipairs(buttonData) do
		local button = Instance.new("TextButton")
		button.Name = data.name
		button.Size = UDim2.new(0, 60, 0, 60)
		button.Position = data.pos
		button.BackgroundColor3 = Color3.fromRGB(0, 0, 0) -- Negro
		button.BackgroundTransparency = 0.6 -- Transparente por defecto
		button.Text = data.arrow -- Flechita
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.TextSize = 30
		button.Font = Enum.Font.GothamBold
		button.BorderSizePixel = 0
		button.AutoButtonColor = false
		button.Parent = controlFrame
		
		-- Forma circular
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = button
		
		movementButtons[data.key] = {button = button, pressed = false}
		
		-- Animación de transparencia al tocar
		button.MouseButton1Down:Connect(function()
			movementButtons[data.key].pressed = true
			local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local tween = TweenService:Create(button, tweenInfo, {BackgroundTransparency = 0.2})
			tween:Play()
		end)
		
		button.MouseButton1Up:Connect(function()
			movementButtons[data.key].pressed = false
			local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local tween = TweenService:Create(button, tweenInfo, {BackgroundTransparency = 0.6})
			tween:Play()
		end)
	end
	
	return controlFrame
end

-- Función para actualizar FOV
local function updateFOV(targetFOV)
	local camera = workspace.CurrentCamera
	if camera then
		local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(camera, tweenInfo, {FieldOfView = targetFOV})
		tween:Play()
	end
end

-- Función para reproducir animaciones correctamente
local function playAnimation(animId, freeze)
	if not humanoid then return end
	
	if currentAnimation then
		currentAnimation:Stop(0)
		currentAnimation = nil
	end
	
	local anim = Instance.new("Animation")
	anim.AnimationId = "rbxassetid://" .. animId
	
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	
	currentAnimation = animator:LoadAnimation(anim)
	currentAnimation:Play(0.1, 1, 1)
	
	if freeze then
		wait(0.05)
		if currentAnimation then
			currentAnimation:AdjustSpeed(0)
		end
	end
	
	anim:Destroy()
end

-- Función para actualizar boost (MEJORADA)
local function updateBoost()
	local indicatorColors = {
		[0] = Color3.fromRGB(80, 80, 80), -- Gris oscuro
		[1] = Color3.fromRGB(150, 200, 200), -- Celeste grisáceo
		[2] = Color3.fromRGB(255, 220, 100), -- Amarillo
		[3] = Color3.fromRGB(255, 80, 80) -- Rojo
	}
	
	-- Animación suave del indicador
	local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(boostIndicator, tweenInfo, {
		BackgroundColor3 = indicatorColors[boostLevel]
	})
	tween:Play()
	
	-- Animación de "salto" del botón
	local originalPos = boostButton.Position
	local tweenUp = TweenService:Create(boostButton, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = originalPos - UDim2.new(0, 0, 0, 5)
	})
	local tweenDown = TweenService:Create(boostButton, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = originalPos
	})
	
	tweenUp:Play()
	tweenUp.Completed:Connect(function()
		tweenDown:Play()
	end)
	
	if boostLevel == 0 then
		currentSpeed = FLIGHT_SPEED
		updateFOV(FOV_LEVELS[0])
		lastAnimationState = "reset"
	elseif boostLevel == 1 then
		currentSpeed = BOOST_SPEEDS.normal
		updateFOV(FOV_LEVELS[1])
		playAnimation(ANIM_BOOST_NORMAL, false)
		lastAnimationState = "boost1"
	elseif boostLevel == 2 then
		currentSpeed = BOOST_SPEEDS.fast
		updateFOV(FOV_LEVELS[2])
		playAnimation(ANIM_BOOST_FAST, true)
		lastAnimationState = "boost2"
	elseif boostLevel == 3 then
		currentSpeed = BOOST_SPEEDS.viltrum
		updateFOV(FOV_LEVELS[3])
		playAnimation(ANIM_BOOST_VILTRUM, true)
		lastAnimationState = "boost3"
	end
end

-- Función para ciclar boost
local function cycleBoost()
	if not isFlying then return end
	
	boostLevel = boostLevel + 1
	if boostLevel > 3 then
		boostLevel = 1
	end
	
	updateBoost()
end

-- Función para detectar si el jugador está en movimiento
local function checkMovement()
	local moving = false
	
	if isMobile then
		if movementButtons.w and movementButtons.w.pressed then
			moving = true
		elseif movementButtons.s and movementButtons.s.pressed then
			moving = true
		elseif (movementButtons.a and movementButtons.a.pressed) or 
		       (movementButtons.d and movementButtons.d.pressed) then
			moving = true
		end
	else
		if UserInputService:IsKeyDown(Enum.KeyCode.W) or
		   UserInputService:IsKeyDown(Enum.KeyCode.A) or
		   UserInputService:IsKeyDown(Enum.KeyCode.S) or
		   UserInputService:IsKeyDown(Enum.KeyCode.D) then
			moving = true
		end
	end
	
	return moving
end

-- Función para determinar qué animación reproducir
local function updateAnimation()
	if not isFlying then return end
	
	if boostLevel > 0 then
		return
	end
	
	local animState = "idle"
	isMoving = checkMovement()
	
	if isMoving then
		lastMovementTime = tick()
	end
	
	if isMobile then
		if movementButtons.w and movementButtons.w.pressed then
			animState = "forward"
		elseif movementButtons.s and movementButtons.s.pressed then
			animState = "backward"
		elseif (movementButtons.a and movementButtons.a.pressed) or 
		       (movementButtons.d and movementButtons.d.pressed) then
			animState = "side"
		end
	else
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			animState = "forward"
		elseif UserInputService:IsKeyDown(Enum.KeyCode.S) then
			animState = "backward"
		elseif UserInputService:IsKeyDown(Enum.KeyCode.A) or 
		       UserInputService:IsKeyDown(Enum.KeyCode.D) then
			animState = "side"
		end
	end
	
	if animState ~= lastAnimationState then
		lastAnimationState = animState
		
		if animState == "forward" then
			playAnimation(ANIM_FORWARD, true)
		elseif animState == "backward" then
			playAnimation(ANIM_BACKWARD, true)
		elseif animState == "side" then
			playAnimation(ANIM_SIDE, true)
		else
			playAnimation(ANIM_IDLE, true)
		end
	end
end

local function enableFlight()
	if not character or not rootPart then return end
	
	bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(100000, 100000, 100000)
	bodyVelocity.Velocity = Vector3.new(0, 0, 0)
	bodyVelocity.Parent = rootPart
	
	bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(100000, 100000, 100000)
	bodyGyro.P = 10000
	bodyGyro.D = 500
	bodyGyro.CFrame = rootPart.CFrame
	bodyGyro.Parent = rootPart
	
	humanoid.PlatformStand = true
	
	hoverTime = 0
	lastMovementTime = tick()
	
	lastAnimationState = "idle"
	playAnimation(ANIM_IDLE, true)
	
	local initialPosition = rootPart.Position
	local targetPosition = initialPosition + Vector3.new(0, ASCENT_HEIGHT, 0)
	local startTick = tick()
	local ascentDuration = 0.8
	
	local ascentFriend
	ascentFriend = RunService.RenderStepped:Connect(function()
		local elapsed = tick() - startTick
		local alpha = math.min(elapsed / ascentDuration, 1)
		
		if alpha >= 1 then
			ascentFriend:Disconnect()
		else
			local easedAlpha = 1 - math.pow(1 - alpha, 3)
			bodyVelocity.Velocity = Vector3.new(0, (targetPosition.Y - rootPart.Position.Y) * 5, 0)
		end
	end)
	
	hoverFriend = RunService.RenderStepped:Connect(function(deltaTime)
		if not isFlying or not bodyVelocity or not bodyGyro then return end
		
		hoverTime = hoverTime + deltaTime * HOVER_SPEED
		local hoverOffset = math.sin(hoverTime) * HOVER_AMPLITUDE
		
		local currentlyMoving = checkMovement()
		
		if not currentlyMoving and boostLevel > 0 and (tick() - lastMovementTime) > MOVEMENT_TIMEOUT then
			boostLevel = 0
			updateBoost()
			lastAnimationState = "reset"
		end
		
		updateAnimation()
		
		local camera = workspace.CurrentCamera
		local cameraCFrame = camera.CFrame
		local moveVector = Vector3.new(0, 0, 0)
		
		if isMobile then
			if movementButtons.w and movementButtons.w.pressed then
				moveVector = moveVector + cameraCFrame.LookVector
			end
			if movementButtons.s and movementButtons.s.pressed then
				moveVector = moveVector - cameraCFrame.LookVector
			end
			if movementButtons.a and movementButtons.a.pressed then
				moveVector = moveVector - cameraCFrame.RightVector
			end
			if movementButtons.d and movementButtons.d.pressed then
				moveVector = moveVector + cameraCFrame.RightVector
			end
		else
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then
				moveVector = moveVector + cameraCFrame.LookVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then
				moveVector = moveVector - cameraCFrame.LookVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then
				moveVector = moveVector - cameraCFrame.RightVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then
				moveVector = moveVector + cameraCFrame.RightVector
			end
		end
		
		if moveVector.Magnitude > 0 then
			moveVector = moveVector.Unit
			lastMovementTime = tick()
		end
		
		moveDirection = moveVector
		
		bodyVelocity.Velocity = moveVector * currentSpeed + Vector3.new(0, hoverOffset, 0)
		
		local tiltX = 0
		local tiltZ = 0
		local smoothness = TILT_SMOOTHNESS
		
		if boostLevel > 0 then
			smoothness = BOOST_TILT_SMOOTHNESS
			tiltX = -math.rad(BOOST_TILT_FORWARD)
			tiltZ = 0
		elseif moveVector.Magnitude > 0 then
			local movingForward = false
			local movingBackward = false
			
			if isMobile then
				if movementButtons.w and movementButtons.w.pressed then
					movingForward = true
				elseif movementButtons.s and movementButtons.s.pressed then
					movingBackward = true
				end
			else
				if UserInputService:IsKeyDown(Enum.KeyCode.W) then
					movingForward = true
				elseif UserInputService:IsKeyDown(Enum.KeyCode.S) then
					movingBackward = true
				end
			end
			
			if movingForward then
				tiltX = -math.rad(TILT_FORWARD)
			elseif movingBackward then
				tiltX = math.rad(TILT_BACKWARD)
			end
			
			local movingLeft = false
			local movingRight = false
			
			if isMobile then
				if movementButtons.a and movementButtons.a.pressed then
					movingLeft = true
				elseif movementButtons.d and movementButtons.d.pressed then
					movingRight = true
				end
			else
				if UserInputService:IsKeyDown(Enum.KeyCode.A) then
					movingLeft = true
				elseif UserInputService:IsKeyDown(Enum.KeyCode.D) then
					movingRight = true
				end
			end
			
			if movingLeft then
				tiltZ = math.rad(TILT_SIDE)
			elseif movingRight then
				tiltZ = -math.rad(TILT_SIDE)
			end
		end
		
		targetTilt = CFrame.Angles(tiltX, 0, tiltZ)
		
		currentTilt = currentTilt:Lerp(targetTilt, smoothness)
		
		local lookDirection = cameraCFrame.LookVector
		local targetCFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + lookDirection)
		bodyGyro.CFrame = targetCFrame * currentTilt
	end)
	
	if isMobile then
		local mobileControls = screenGui:FindFirstChild("MobileControls")
		if mobileControls then
			mobileControls.Visible = true
		end
	end
end

local function disableFlight()
	if hoverFriend then
		hoverFriend:Disconnect()
		hoverFriend = nil
	end
	
	if currentAnimation then
		currentAnimation:Stop(0)
		currentAnimation = nil
	end
	
	boostLevel = 0
	currentSpeed = FLIGHT_SPEED
	updateBoost()
	updateFOV(defaultFOV)
	
	lastAnimationState = "idle"
	isMoving = false
	
	if bodyVelocity then
		bodyVelocity:Destroy()
		bodyVelocity = nil
	end
	
	if bodyGyro then
		bodyGyro:Destroy()
		bodyGyro = nil
	end
	
	if character and humanoid then
		humanoid.PlatformStand = false
	end
	
	moveDirection = Vector3.new(0, 0, 0)
	currentTilt = CFrame.new()
	targetTilt = CFrame.new()
	
	if isMobile then
		local mobileControls = screenGui:FindFirstChild("MobileControls")
		if mobileControls then
			mobileControls.Visible = false
		end
	end
end

-- Alternar vuelo (CON ANIMACIÓN DE SALTO)
local function toggleFlight()
	isFlying = not isFlying
	
	-- Animación de "salto"
	local originalPos = flyButton.Position
	local tweenUp = TweenService:Create(flyButton, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = originalPos - UDim2.new(0, 0, 0, 8)
	})
	local tweenDown = TweenService:Create(flyButton, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = originalPos
	})
	
	tweenUp:Play()
	tweenUp.Completed:Connect(function()
		tweenDown:Play()
	end)
	
	-- Transición de color suave
	local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	
	if isFlying then
		local tween = TweenService:Create(flyButton, tweenInfo, {
			BackgroundColor3 = Color3.fromRGB(50, 200, 50) -- Verde
		})
		tween:Play()
		enableFlight()
	else
		local tween = TweenService:Create(flyButton, tweenInfo, {
			BackgroundColor3 = Color3.fromRGB(220, 50, 50) -- Rojo
		})
		tween:Play()
		disableFlight()
	end
end

-- Crear interfaz
flyButton = createFlyButton()
boostButton, boostIndicator = createBoostButton()
createMobileControls()

-- Conectar botón de vuelo
flyButton.MouseButton1Click:Connect(toggleFlight)

-- Conectar botón de boost
boostButton.MouseButton1Click:Connect(cycleBoost)

-- Limpiar al morir o resetear
player.CharacterAdded:Connect(function(newCharacter)
	if isFlying then
		disableFlight()
		isFlying = false
		flyButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
	end
	
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid")
	rootPart = character:WaitForChild("HumanoidRootPart")
end)
