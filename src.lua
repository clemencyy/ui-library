--------------------------------------
-- services --------------------------
--------------------------------------

local userInputService = game:GetService("UserInputService")
local httpService = game:GetService("HttpService")
local runService = game:GetService("RunService")
local tweenService = game:GetService("TweenService")
local collectionService = game:GetService("CollectionService")

local replicatedStorage = game:GetService("ReplicatedStorage")
local replicatedFirst = game:GetService("ReplicatedFirst")

local debris = game:GetService("Debris")
local lighting = game:GetService("Lighting")
local players = game:GetService("Players")
local workspace = game:GetService("Workspace")


--------------------------------------
-- player ----------------------------
--------------------------------------

local player = players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:FindFirstChildWhichIsA("Humanoid")

local mouse = player:GetMouse()


--------------------------------------
-- library ---------------------------
--------------------------------------

local library = {
	version = "1.0.0",
	connections = {
	},
	toggleKey = Enum.KeyCode.RightShift,
	visible = true,
	theme = {
		accent = Color3.fromRGB(227, 153, 11)
	},
	animation = {
		elementSlide = 70,
		elementStagger = 0.06,
		elementDuration = 0.7,
		elementFade = 0.5,
		maxStagger = 9e9,
	},

}
library.isDialogOpen = false


--------------------------------------
-- flags -----------------------------
--------------------------------------

library.flags = {}

local flagInfo = {}

local flagKinds = {
	createToggle = "toggle",
	createCheckbox = "checkbox",
	createSlider = "slider",
	createRangeSlider = "range",
	createDropdown = "dropdown",
	createSegmented = "segmented",
	createInput = "input",
	createColorPicker = "color",
	createKeybind = "keybind",
	createPlayerPicker = "player",
}

local function packFlag(kind, element)
	if kind == "range" then
		local low, high = element:value()
		return {low, high}
	elseif kind == "color" then
		return "#" .. element:value():ToHex()
	elseif kind == "keybind" then
		local key = element:value()
		local parts = element.modifiers and element:modifiers() or {}
		table.insert(parts, typeof(key) == "EnumItem" and key.Name or tostring(key))
		return table.concat(parts, "+")
	elseif kind == "player" then
		local value = element:value()
		if type(value) == "table" then
			local names = {}
			for _, target in value do
				table.insert(names, target.Name)
			end
			return names
		end
		return value and value.Name or ""
	end
	local value = element:value()
	if type(value) == "table" then
		return table.clone(value)
	end
	return value
end

local function unpackFlag(kind, element, value, skipCallback)
	if kind == "range" then
		element:set(value[1], value[2], skipCallback)
	elseif kind == "color" then
		if type(value) == "string" then
			value = Color3.fromHex(value)
		end
		element:set(value, skipCallback)
	elseif kind == "keybind" then
		element:set(value, nil, not skipCallback)
	else
		element:set(value, skipCallback)
	end
end

function library:registerFlag(name, method, element)
	local kind = flagKinds[method]
	if not kind then
		return
	end
	flagInfo[name] = {kind = kind, element = element}
	library.flags[name] = element
end

function library:removeFlag(name, element)
	local info = flagInfo[name]
	if info and (element == nil or info.element == element) then
		flagInfo[name] = nil
		library.flags[name] = nil
	end
end

function library:getFlag(name)
	local info = flagInfo[name]
	if not info then return nil end
	return packFlag(info.kind, info.element)
end

function library:setFlag(name, value, skipCallback)
	local info = flagInfo[name]
	if not info then return false end
	local ok, problem = pcall(unpackFlag, info.kind, info.element, value, skipCallback)
	return ok
end

function library:getFlags()
	local data = {}
	for name, info in flagInfo do
		local ok, value = pcall(packFlag, info.kind, info.element)
		if ok then
			data[name] = value
		end
	end
	return data
end

function library:setFlags(data, skipCallback)
	if type(data) ~= "table" then return end
	for name, value in data do
		library:setFlag(name, value, skipCallback)
	end
end


--------------------------------------
-- utility ---------------------------
--------------------------------------

local utility = {}

function utility.create(class, props, children)
	local obj = Instance.new(class)

	local success, rt = pcall(function()
		return obj.RichText
	end)
	if success and rt ~= nil then
		obj.RichText = true
	end

	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			obj[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = obj
	end
	if props and props.Parent then
		obj.Parent = props.Parent
	end

	if obj:IsA("Frame") or obj:IsA("ScrollingFrame") then
		obj.BorderSizePixel = 0
	end

	return obj
end

function utility.callback(callback, context, ...)
	if type(callback) ~= "function" then
		return true
	end

	local success, result = pcall(callback, ...)

	if not success then
		warn(("callback error in '%s': %s"):format(context or "unknown", tostring(result)))
	end

	return success, result
end

local tweenInfos = {}

function utility.tween(obj, duration, goal, style, direction)
	style = style or Enum.EasingStyle.Quint
	direction = direction or Enum.EasingDirection.Out
	local key = duration .. style.Name .. direction.Name
	local tweenInfo = tweenInfos[key]
	if not tweenInfo then
		tweenInfo = TweenInfo.new(duration, style, direction)
		tweenInfos[key] = tweenInfo
	end

	local tween = tweenService:Create(obj, tweenInfo, goal)
	tween:Play()

	return tween
end

function utility.roundUp(n, decimals)
	local mult = 10 ^ (decimals or 0)
	return math.floor(n * mult + 0.5) / mult
end

function utility.contrast(color)
	local function channel(value)
		return value <= 0.03928 and value / 12.92 or ((value + 0.055) / 1.055) ^ 2.4
	end
	local luminance = 0.2126 * channel(color.R) + 0.7152 * channel(color.G) + 0.0722 * channel(color.B)
	local againstWhite = 1.05 / (luminance + 0.05)
	local againstBlack = (luminance + 0.05) / 0.05
	return againstBlack >= againstWhite and Color3.fromRGB(10, 10, 10) or Color3.fromRGB(255, 255, 255)
end

library.contrast = utility.contrast

function utility.knob(color)
	local function channel(value)
		return value <= 0.03928 and value / 12.92 or ((value + 0.055) / 1.055) ^ 2.4
	end
	local luminance = 0.2126 * channel(color.R) + 0.7152 * channel(color.G) + 0.0722 * channel(color.B)
	if 1.05 / (luminance + 0.05) < 1.5 then
		return Color3.fromRGB(10, 10, 10)
	end
	return Color3.fromRGB(255, 255, 255)
end

library.knob = utility.knob

utility.grab = nil

local function listenForGrabs()
	if utility.grabMove and utility.grabMove.Connected then return end
	utility.grabMove = userInputService.InputChanged:Connect(function(input)
		local grab = utility.grab
		if not grab or not grab.move then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			grab.move(input)
		end
	end)
	utility.grabEnd = userInputService.InputEnded:Connect(function(input)
		local grab = utility.grab
		if not grab then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			utility.grab = nil
			if grab.release then
				grab.release(input)
			end
		end
	end)
	table.insert(library.connections, utility.grabMove)
	table.insert(library.connections, utility.grabEnd)
end

function utility.capture(move, release)
	listenForGrabs()
	local previous = utility.grab
	utility.grab = {move = move, release = release}
	if previous and previous.release then
		previous.release()
	end
end

function utility.makeRoom(popup)
	local scroll = popup:FindFirstAncestorWhichIsA("ScrollingFrame")
	if not scroll then
		return function() end
	end
	local layout = scroll:FindFirstChildWhichIsA("UIListLayout")
	local spacer = scroll:FindFirstChild("popupSpace")
	if not spacer then
		spacer = Instance.new("Frame")
		spacer.Name = "popupSpace"
		spacer.BackgroundTransparency = 1
		spacer.BorderSizePixel = 0
		spacer.Size = UDim2.new(1, 0, 0, 0)
		spacer.LayoutOrder = 1000000
		spacer.Visible = false
		spacer:SetAttribute("wrapped", true)
		spacer.Parent = scroll
	end
	if utility.roomShrink then
		utility.roomShrink:Cancel()
		utility.roomShrink = nil
	end
	local function gap()
		return layout and layout.Padding.Offset or 0
	end
	local function refresh()
		local natural = scroll.AbsoluteCanvasSize.Y - (spacer.Visible and (spacer.Size.Y.Offset + gap()) or 0)
		local bottom = popup.AbsolutePosition.Y + popup.AbsoluteSize.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y + 12
		local need = math.max(0, math.ceil(bottom - natural - gap()))
		spacer.Size = UDim2.new(1, 0, 0, need)
		spacer.Visible = need > 0
		local want = bottom - scroll.AbsoluteSize.Y
		if want > scroll.CanvasPosition.Y then
			scroll.CanvasPosition = Vector2.new(scroll.CanvasPosition.X, want)
		end
	end
	local sizeConn = popup:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh)
	task.defer(refresh)
	return function()
		sizeConn:Disconnect()
		local shrink = tweenService:Create(spacer, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 0, 0)})
		shrink.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed then
				spacer.Visible = false
			end
		end)
		utility.roomShrink = shrink
		shrink:Play()
	end
end

function utility.openRoom(popup)
	if utility.roomRelease then
		utility.roomRelease()
	end
	utility.roomRelease = utility.makeRoom(popup)
end

function utility.closeRoom()
	if utility.roomRelease then
		utility.roomRelease()
		utility.roomRelease = nil
	end
end

function utility.sizeBox(box, minWidth)
	local function fit()
		task.defer(function()
			if not box.Parent then return end
			local width = math.max(minWidth or 28, box.TextBounds.X + 16)
			utility.tween(box, 0.3, {Size = UDim2.fromOffset(width, box.Size.Y.Offset)}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		end)
	end
	box:GetPropertyChangedSignal("Text"):Connect(fit)
	fit()
end

function utility.editBox(props)
	local box = utility.create("TextBox", {
		Name = props.Name or "edit",
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		Position = props.Position or UDim2.new(),
		Size = UDim2.fromOffset(props.width or 28, 20),
		BackgroundColor3 = Color3.fromRGB(20, 20, 20),
		Text = props.Text or "",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 13,
		TextXAlignment = props.align or Enum.TextXAlignment.Center,
		ClearTextOnFocus = false,
		FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium),
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = 12,
		Parent = props.Parent,
	}, {
		utility.create("UICorner", {CornerRadius = UDim.new(0, 4)}),
		utility.create("UIStroke", {Name = "UIStroke", Color = Color3.fromRGB(25, 25, 25), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}),
		utility.create("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6)}),
		utility.create("UIShadow", {
			Offset = UDim2.new(0, 0, 0, 0),
			Transparency = .5,
			Name = "UIShadow",
			BlurRadius = UDim.new(0, 15),
			Color = Color3.fromRGB(0, 0, 0),
			ZIndex = 1,
			Spread = UDim2.new(0, 0, 0, 0),
			Enabled = true,
		}),
	})
	utility.sizeBox(box, 28)
	return box
end

local labelRest = setmetatable({}, {__mode = "k"})

function utility.dismissEdit(holder, label)
	local quart, out = Enum.EasingStyle.Quart, Enum.EasingDirection.Out
	local parts = holder:GetDescendants()
	table.insert(parts, holder)
	for _, part in parts do
		if part:IsA("TextBox") then
			part.TextEditable = false
			utility.tween(part, 0.25, {TextTransparency = 1, BackgroundTransparency = 1}, quart, out)
		elseif part:IsA("TextLabel") then
			utility.tween(part, 0.25, {TextTransparency = 1}, quart, out)
		elseif part:IsA("UIStroke") or part:IsA("UIShadow") then
			pcall(function()
				utility.tween(part, 0.25, {Transparency = 1}, quart, out)
			end)
		end
	end
	utility.tween(holder, 0.3, {Position = holder.Position - UDim2.fromOffset(0, 5)}, quart, out)
	task.delay(0.3, function()
		holder:Destroy()
	end)

	local rest = labelRest[label] or label.Position
	labelRest[label] = rest
	label.TextTransparency = 1
	label.Position = rest + UDim2.fromOffset(0, 5)
	label.Visible = true
	utility.tween(label, 0.4, {TextTransparency = 0, Position = rest}, quart, out)
end

function utility.stackDropdown(element)
	local options = element:FindFirstChild("options")
	if not options or not options:FindFirstChild("chevron") or element:GetAttribute("stacked") then
		return
	end
	local base = element:FindFirstChild("description") and 54 or 44
	element:SetAttribute("stacked", true)
	element.Size = UDim2.new(1, 0, 0, base * 2 - 13)
	options.Position = UDim2.new(0, 8, 0, base - 6)
	options.Size = UDim2.new(1, -16, 0, base - 15)
	tweenService:Create(options, TweenInfo.new(0), {Size = UDim2.new(1, -16, 0, base - 15)}):Play()
	local title = element:FindFirstChild("title")
	if title then
		title.Size = UDim2.new(1, -30, 0, title.Size.Y.Offset)
	end
end

function utility.isTop(target, x, y)
	local modal = library.modalFrame
	if modal and modal.Parent and modal.Visible and target ~= modal and not target:IsDescendantOf(modal) then
		if not x then
			local mouse = player:GetMouse()
			x, y = mouse.X, mouse.Y
		end
		local spot, area = modal.AbsolutePosition, modal.AbsoluteSize
		if x >= spot.X and x <= spot.X + area.X and y >= spot.Y and y <= spot.Y + area.Y then
			return false
		end
	end
	local popup = library.popupFrame
	if not popup or not popup.Parent or not popup.Visible then
		return true
	end
	if target == popup or target:IsDescendantOf(popup) then
		return true
	end
	if not x then
		local mouse = player:GetMouse()
		x, y = mouse.X, mouse.Y
	end
	local position, size = popup.AbsolutePosition, popup.AbsoluteSize
	local inside = x >= position.X and x <= position.X + size.X and y >= position.Y and y <= position.Y + size.Y
	return not inside
end

utility.active = nil
function utility.setupDrag(frame, handle, registry)
	if registry then
		table.insert(registry, library.connections)
	end

	handle = handle or frame

	local dragging = false
	local dragStart
	local startPos
	local targetPos = frame.Position
	local connections = {}

	local function getViewport()
		local cam = workspace.CurrentCamera
		return cam and cam.ViewportSize or Vector2.new(1920, 1080)
	end

	local function clampPosition(pos, scale)
		local screen = getViewport()
		local size = frame.AbsoluteSize
		local anchor = frame.AnchorPoint

		local absX = pos.X + scale.X * screen.X
		local absY = pos.Y + scale.Y * screen.Y

		local minX = size.X * anchor.X
		local minY = size.Y * anchor.Y
		local maxX = screen.X - size.X * (1 - anchor.X)
		local maxY = screen.Y - size.Y * (1 - anchor.Y)

		absX = math.clamp(absX, minX, maxX)
		absY = math.clamp(absY, minY, maxY)

		return absX - scale.X * screen.X, absY - scale.Y * screen.Y
	end

	local startFollow

	local function updateTarget(input)
		if not dragging or utility.active ~= frame then
			return
		end

		local delta = input.Position - dragStart
		local newX = startPos.X.Offset + delta.X
		local newY = startPos.Y.Offset + delta.Y

		newX, newY = clampPosition(Vector2.new(newX, newY), Vector2.new(startPos.X.Scale, startPos.Y.Scale))

		targetPos = UDim2.new(startPos.X.Scale, newX, startPos.Y.Scale, newY)
		startFollow()
	end

	connections[#connections + 1] = handle.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		if utility.active and utility.active ~= frame then
			return
		end

		dragging = true
		utility.active = frame
		dragStart = input.Position
		startPos = frame.Position
		targetPos = frame.Position

		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
				if utility.active == frame then
					utility.active = nil
				end
			end
		end)
	end)

	connections[#connections + 1] = userInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			updateTarget(input)
		end
	end)

	connections[#connections + 1] = userInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false

			if utility.active == frame then
				utility.active = nil
			end
		end
	end)

	local follow
	local function arrived(a, b)
		return a.X.Scale == b.X.Scale and a.Y.Scale == b.Y.Scale and math.abs(a.X.Offset - b.X.Offset) < 0.5 and math.abs(a.Y.Offset - b.Y.Offset) < 0.5
	end
	startFollow = function()
		if follow then return end
		follow = runService.RenderStepped:Connect(function()
			if frame:GetAttribute("resizing") then
				targetPos = frame.Position
				return
			end
			local nextPos = frame.Position:Lerp(targetPos, 0.25)
			if not dragging and arrived(nextPos, targetPos) then
				frame.Position = targetPos
				follow:Disconnect()
				follow = nil
				return
			end
			frame.Position = nextPos
		end)
	end

	connections[#connections + 1] = frame.Destroying:Connect(function()
		if follow then
			follow:Disconnect()
			follow = nil
		end
	end)

	return connections
end


--------------------------------------
-- builder ---------------------------
--------------------------------------

local builder = {}


--------------------------------------
-- canvas ----------------------------
--------------------------------------

function builder.canvas(screen, size)
	local canvas: Frame = utility.create("Frame", {
		Name = "canvas",
		BackgroundColor3 = Color3.fromRGB(10,10,10),
		Size = size,
		Position = UDim2.fromOffset(600, 300),
		AnchorPoint = Vector2.new(0.5,0.5),
		ClipsDescendants = true,
		Parent = screen,
		ZIndex = 1,
	}, {
		utility.create("UICorner", {
			Name = "UICorner",
			CornerRadius = UDim.new(0, 12)
		}),
		utility.create("UIShadow", {
			Name = "UIShadow",
			Offset = UDim2.new(0, 0, 0, 6),
			Transparency = 0.35,
			BlurRadius = UDim.new(0, 36),
			Color = Color3.fromRGB(0, 0, 0),
			ZIndex = 1,
			Spread = UDim2.new(0, 2, 0, 2),
			Enabled = true,
		}),
	})

	return canvas :: Frame
end


--------------------------------------
-- topbar ----------------------------
--------------------------------------

function builder.topbar(canvas, title, subtitle, icon, display)
	local topbar = utility.create("Frame", {
		Name = "topbar",
		BackgroundColor3 = Color3.fromRGB(10,10,10),
		Size = UDim2.new(1,0,0,48),
		Parent = canvas,
		ZIndex = 15
	}, {
		utility.create("UICorner", {
			CornerRadius = UDim.new(0, 12)
		}),
		utility.create("UIPadding", {
			PaddingLeft = UDim.new(0, 15),
			PaddingRight = UDim.new(0, 3),
		}),
	})

	utility.create("Frame", {
		Name = "block",
		BackgroundColor3 = Color3.fromRGB(10,10,10),
		Size = UDim2.new(2,0,0.177,1),
		Position = UDim2.new(-0.5, 0, 0.8, 0),
		Parent = topbar,
		ZIndex = 15,
		Visible = false
	})

	utility.create("Frame", {
		Name = "divider",
		BackgroundColor3 = Color3.fromRGB(25,25,25),
		Size = UDim2.new(2,0,0,1),
		Position = UDim2.new(1.5,0,1,0),
		Parent = topbar,
		ZIndex = 15,
		AnchorPoint = Vector2.new(1,1)
	})


	--------------------------------------
	-- title -----------------------------
	--------------------------------------

	local title = utility.create("TextLabel", {
		Name = "title",
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(255,255,255),
		Text = title,
		ZIndex = 15,
		Size = UDim2.new(0,164,0,12),
		Position = UDim2.new(0,0,0,10),
		FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
		Parent = topbar,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local subtitle = utility.create("TextLabel", {
		Name = "subtitle",
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(139,139,139),
		Text = subtitle,
		ZIndex = 15,
		Size = UDim2.new(0,169,0,11),
		Position = UDim2.new(0,0,0,25),
		FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
		Parent = topbar,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local iconSize = 26
	local iconLabel = utility.create("ImageLabel", {
		Name = "icon",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(iconSize, iconSize),
		Image = "",
		ScaleType = Enum.ScaleType.Fit,
		Visible = false,
		ZIndex = 15,
		Parent = topbar,
	})


	--------------------------------------
	-- nav buttons -----------------------
	--------------------------------------

	local nav = utility.create("Frame", {
		Name = "nav",
		BackgroundTransparency = 1,
		Size = UDim2.new(0,-58,0,46),
		ZIndex = 15,
		Position = UDim2.new(0.995,0,0,0),
		BackgroundColor3 = Color3.fromRGB(10,10,10),
		Parent = topbar,
	})

	local close = utility.create("TextLabel", {
		Name = "close",
		BackgroundColor3 = Color3.fromRGB(10,10,10),
		Size = UDim2.new(0,33,0,33),
		Position = UDim2.new(1,0,0.5,0),
		TextTransparency = 1,
		Parent = nav,
		AnchorPoint = Vector2.new(1,0.5),
	}, {
		utility.create("UICorner", {
			CornerRadius = UDim.new(0,6),
		}),

		utility.create("ImageLabel", {
			Name = "icon",
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(.5, .5),
			AnchorPoint = Vector2.new(.5, .5),
			Size = UDim2.fromOffset(15,15),
			ZIndex = 15,
			Image = "rbxassetid://10747384394",
			ImageColor3 = Color3.fromRGB(100,100,100),
			ScaleType = Enum.ScaleType.Fit,

		})
	})

	close.MouseEnter:Connect(function()
		local icon = close:FindFirstChild("icon")
		if icon then
			utility.tween(icon, .5, {
				ImageColor3 = Color3.fromRGB(255,255,255)
			})
		end
	end)

	close.MouseLeave:Connect(function()
		local icon = close:FindFirstChild("icon")
		if icon then
			utility.tween(icon, .5, {
				ImageColor3 = Color3.fromRGB(100,100,100)
			})
		end
	end)

	local hide = utility.create("TextButton", {
		Name = "hide",
		BackgroundColor3 = Color3.fromRGB(10,10,10),
		Size = UDim2.new(0,33,0,33),
		Position = UDim2.new(.4,0,0.5,0),
		AutoButtonColor = false,
		TextTransparency = 1,
		Parent = nav,
		Visible = true,
		AnchorPoint = Vector2.new(1,0.5),
	}, {
		utility.create("UICorner", {
			CornerRadius = UDim.new(0,6),
		}),

		utility.create("ImageLabel", {
			Name = "icon",
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(.5, .5),
			AnchorPoint = Vector2.new(.5, .5),
			Size = UDim2.fromOffset(15,15),
			ZIndex = 15,
			Image = "rbxassetid://10734896206",
			ImageColor3 = Color3.fromRGB(100,100,100),
			ScaleType = Enum.ScaleType.Fit,

		})
	})

	hide.MouseEnter:Connect(function()
		local icon = hide:FindFirstChild("icon")
		if icon then
			utility.tween(icon, .5, {
				ImageColor3 = Color3.fromRGB(255,255,255)
			})
		end
	end)

	hide.MouseLeave:Connect(function()
		local icon = hide:FindFirstChild("icon")
		if icon then
			utility.tween(icon, .5, {
				ImageColor3 = Color3.fromRGB(100,100,100)
			})
		end
	end)


	--------------------------------------
	-- search bar ------------------------
	--------------------------------------

	local search = utility.create("TextButton", {
		Name = "search",
		BackgroundColor3 = Color3.fromRGB(10,10,10),
		Size = UDim2.new(0,33,0,33),
		Position = UDim2.new(-.2,0,0.5,0),
		AutoButtonColor = false,
		TextTransparency = 1,
		Parent = nav,
		Visible = true,
		AnchorPoint = Vector2.new(1,0.5),
	}, {
		utility.create("UICorner", {
			CornerRadius = UDim.new(0,6),
		}),

		utility.create("ImageLabel", {
			Name = "icon",
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(.5, .5),
			AnchorPoint = Vector2.new(.5, .5),
			Size = UDim2.fromOffset(15,15),
			ZIndex = 15,
			Image = "rbxassetid://10734943674",
			ImageColor3 = Color3.fromRGB(100,100,100),
			ScaleType = Enum.ScaleType.Fit,
		})
	})

	search.MouseEnter:Connect(function()
		utility.tween(search.icon, .5, {
			ImageColor3 = Color3.fromRGB(255,255,255)
		})
	end)

	search.MouseLeave:Connect(function()
		if search:GetAttribute("open") then return end
		utility.tween(search.icon, .5, {
			ImageColor3 = Color3.fromRGB(100,100,100)
		})
	end)

	local searchBar = utility.create("Frame", {
		Name = "searchBar",
		BackgroundColor3 = Color3.fromRGB(15,15,15),
		Size = UDim2.new(0,0,0,30),
		Position = UDim2.new(-.2,-38,0.5,0),
		AnchorPoint = Vector2.new(1,0.5),
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 15,
		Parent = nav,
	}, {
		utility.create("UICorner", {
			CornerRadius = UDim.new(0,6),
		}),
		utility.create("UIStroke", {
			Color = Color3.fromRGB(25,25,25),
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})

	local searchBox = utility.create("TextBox", {
		Name = "box",
		BackgroundTransparency = 1,
		Size = UDim2.new(1,-20,1,0),
		Position = UDim2.fromOffset(10,0),
		Text = "",
		PlaceholderText = "search features...",
		PlaceholderColor3 = Color3.fromRGB(100,100,100),
		TextColor3 = Color3.fromRGB(255,255,255),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
		ZIndex = 15,
		Parent = searchBar,
	})
	searchBox.RichText = false

	local title = topbar.title
	local params = Instance.new("GetTextBoundsParams")
	params.Text = title.Text
	params.Font = title.FontFace         
	params.Size = title.TextSize
	params.Width = math.huge

	local titleBounds = game:GetService("TextService"):GetTextBoundsAsync(params)
	local titleWidth = math.ceil(titleBounds.X)

	local tags = utility.create("Frame", {
		AnchorPoint = Vector2.new(0, 0),
		BackgroundTransparency = 1,
		Name = "tags",
		Position = UDim2.new(0, titleWidth + 40, 0, 3),
		Visible = true,
		ZIndex = 1,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Size = UDim2.new(0, 573, 0, 28),
		Parent = topbar,
	}, {
		utility.create("UIListLayout", {
			Name = "UIListLayout",
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		})
	})

	local mode = "title"

	local function placeTags()
		local x
		if mode == "icon" then
			x = iconSize + 10
		else
			x = title.Position.X.Offset + math.ceil(title.TextBounds.X) + 8
		end
		tags.Position = UDim2.new(0, x, 0, mode == "icon" and 10 or 3)
	end
	title:GetPropertyChangedSignal("TextBounds"):Connect(placeTags)
	title:GetPropertyChangedSignal("Text"):Connect(placeTags)

	local function setIcon(image)
		if type(image) == "number" then
			image = "rbxassetid://" .. image
		end
		iconLabel.Image = image or ""
	end

	local function setDisplay(newMode)
		if newMode ~= "icon" and newMode ~= "both" then
			newMode = "title"
		end
		if newMode ~= "title" and iconLabel.Image == "" then
			warn("theres no icon set, showing the title instead")
			newMode = "title"
		end
		mode = newMode
		local textX = mode == "both" and iconSize + 10 or 0
		iconLabel.Visible = mode ~= "title"
		title.Visible = mode ~= "icon"
		subtitle.Visible = mode ~= "icon"
		title.Position = UDim2.new(0, textX, 0, 10)
		subtitle.Position = UDim2.new(0, textX, 0, 25)
		placeTags()
	end

	setIcon(icon)
	setDisplay(display or (icon and "both" or "title"))
	task.defer(placeTags)

	return {
		frame = topbar,
		title = title,
		subtitle = subtitle,
		icon = iconLabel,
		setIcon = setIcon,
		setDisplay = setDisplay,
		topbar = topbar,
		tags = tags,
		nav = {
			close = close,
			hide = hide,
			search = search,
		},
		searchBar = searchBar,
		searchBox = searchBox,
	}
end


--------------------------------------
-- sidebar ---------------------------
--------------------------------------

function builder.sidebar(canvas)
	local sidebar = utility.create("Frame", {
		Name = "sidebar",
		BackgroundColor3 = Color3.fromRGB(10, 10, 10),
		BackgroundTransparency = 0,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(0, 157, 1, 0),
		AnchorPoint = Vector2.new(0, 0),
		Visible = true,
		ZIndex = 5,
		AutomaticSize = Enum.AutomaticSize.None,
		ClipsDescendants = false,
		Parent = canvas,
	}, {
		utility.create("UICorner", {
			CornerRadius = UDim.new(0, 12),
		})
	})

	utility.create("Frame", {
		AnchorPoint = Vector2.new(0, 0),
		BackgroundTransparency = 0,
		Name = "divider",
		Position = UDim2.new(1, 0, 0, 45),
		Visible = true,
		ZIndex = 5,
		BackgroundColor3 = Color3.fromRGB(25, 25, 25),
		Size = UDim2.new(0, 1, 1, 0),
		Parent = sidebar,
	})

	local list = utility.create("ScrollingFrame", {
		AnchorPoint = Vector2.new(0, 0),
		BackgroundTransparency = 15,
		Name = "list",
		Position = UDim2.new(0, 0, 0, 55),
		Visible = true,
		ZIndex = 5,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Size = UDim2.new(1, 0, 1, -80),
		Parent = sidebar,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0,
	}, {
		utility.create("UIListLayout", {
			Name = "UIListLayout",
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		utility.create("UIPadding", {
			Name = "UIPadding",
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6)

		})
	})

	return {
		frame = sidebar,
		list = list
	}
end


--------------------------------------
-- dialog ----------------------------
--------------------------------------

function builder.dialog(container)
	local ease = Enum.EasingStyle.Quart
	local out, into = Enum.EasingDirection.Out, Enum.EasingDirection.In
	local medium = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal)
	local regular = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	local bold = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	local white = Color3.fromRGB(255, 255, 255)
	local danger = Color3.fromRGB(248, 113, 113)
	local width = 300

	local dialog = {}
	local queue = {}

	local open

	local function nextInQueue()
		library.isDialogOpen = false
		local nextConfig = table.remove(queue, 1)
		if nextConfig then
			task.delay(0.1, function()
				open(nextConfig.config, nextConfig.handle)
			end)
		end
	end

	open = function(config, handle)
		library.isDialogOpen = true
		local buttons = config.buttons
		local hasButtons = type(buttons) == "table" and #buttons > 0
		local entries = {}
		if hasButtons then
			for index, entry in buttons do
				local text, kind
				if type(entry) == "table" then
					text = entry.text or entry[1] or "button"
					kind = entry.type
				else
					text = entry
				end
				if not kind then
					if index == #buttons and #buttons > 1 then
						kind = config.danger and "danger" or "accent"
					elseif index == #buttons and config.danger then
						kind = "danger"
					else
						kind = "default"
					end
				end
				table.insert(entries, {text = tostring(text), kind = kind})
			end
		end
		local inputConfig = config.input
		if inputConfig and not hasButtons then
			hasButtons = true
			entries = {{text = "cancel", kind = "ghost"}, {text = "confirm", kind = "accent"}}
		end
		if inputConfig == true then
			inputConfig = {}
		end
		local cardWidth = width + math.max(0, #entries - 3) * 70
		local style = config.type and library.notificationTypes and library.notificationTypes[config.type]
		local accent = library.theme.accent
		local closed = false
		local connections = {}

		local overlay = utility.create("Frame", {
			Name = "dialog",
			BackgroundColor3 = Color3.fromRGB(10, 10, 10),
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 900,
			Active = true,
			Parent = container,
		})

		local shadow = utility.create("Frame", {
			Name = "shadow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(15, 15, 15),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0.5, 12),
			Size = UDim2.fromOffset(cardWidth, 160),
			ZIndex = 901,
			Parent = overlay,
		}, {
			utility.create("UICorner", {CornerRadius = UDim.new(0, 8)}),
			utility.create("UIScale", {Name = "scale", Scale = 0.95}),
			utility.create("UIShadow", {
				Name = "UIShadow",
				Offset = UDim2.new(0, 0, 0, 0),
				Transparency = 1,
				BlurRadius = UDim.new(0, 25),
				Color = Color3.fromRGB(22, 22, 22),
				ZIndex = 1,
				Spread = UDim2.new(0, 0, 0, 0),
				Enabled = true,
			}),
		})

		local card = utility.create("CanvasGroup", {
			Name = "card",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(15, 15, 15),
			GroupTransparency = 1,
			Position = UDim2.new(0.5, 0, 0.5, 12),
			Size = UDim2.fromOffset(cardWidth, 160),
			ZIndex = 902,
			Parent = overlay,
		}, {
			utility.create("UICorner", {CornerRadius = UDim.new(0, 8)}),
			utility.create("UIScale", {Name = "scale", Scale = 0.95}),
			utility.create("UIStroke", {
				Name = "UIStroke",
				Color = Color3.fromRGB(25, 25, 25),
				Thickness = 1,
				Transparency = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			}),
		})

		local top = 20
		local badge
		if style then
			badge = utility.create("Frame", {
				Name = "badge",
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = style.color,
				BackgroundTransparency = 0.86,
				Position = UDim2.new(0.5, 0, 0, 18),
				Size = UDim2.fromOffset(28, 28),
				ZIndex = 903,
				Parent = card,
			}, {
				utility.create("UICorner", {CornerRadius = UDim.new(1, 0)}),
				utility.create("UIScale", {Name = "scale", Scale = 0.8}),
				utility.create("TextLabel", {
					Name = "glyph",
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					Text = style.glyph or "",
					TextColor3 = style.color,
					TextSize = 15,
					FontFace = bold,
					ZIndex = 904,
				}),
			})
			top = 56
		end

		local titleLabel = utility.create("TextLabel", {
			Name = "title",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0, top + 6),
			Size = UDim2.new(1, -30, 0, 20),
			Text = config.title or "header",
			TextColor3 = white,
			TextTransparency = 1,
			TextSize = 16,
			TextTruncate = Enum.TextTruncate.AtEnd,
			FontFace = medium,
			ZIndex = 903,
			Parent = card,
		})

		local bodyLabel = utility.create("TextLabel", {
			Name = "body",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0, top + 32),
			Size = UDim2.new(1, -40, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = config.body or "",
			TextColor3 = Color3.fromRGB(100, 100, 100),
			TextTransparency = 1,
			TextSize = 13,
			TextWrapped = true,
			LineHeight = 1.15,
			FontFace = medium,
			ZIndex = 903,
			Parent = card,
		})

		local field, fieldBox
		if inputConfig then
			field = utility.create("Frame", {
				Name = "input",
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Color3.fromRGB(20, 20, 20),
				BackgroundTransparency = 1,
				Position = UDim2.new(0.5, 0, 0, top + 32),
				Size = UDim2.new(1, -40, 0, 32),
				ZIndex = 903,
				Parent = card,
			}, {
				utility.create("UICorner", {CornerRadius = UDim.new(0, 5)}),
				utility.create("UIStroke", {Name = "UIStroke", Color = Color3.fromRGB(25, 25, 25), Thickness = 1, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}),
			})
			fieldBox = utility.create("TextBox", {
				Name = "box",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(10, 0),
				Size = UDim2.new(1, -20, 1, 0),
				Text = tostring(inputConfig.default or ""),
				PlaceholderText = inputConfig.placeholder or "type here...",
				PlaceholderColor3 = Color3.fromRGB(90, 90, 90),
				TextColor3 = white,
				TextTransparency = 1,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				ClearTextOnFocus = false,
				FontFace = regular,
				ZIndex = 904,
				Parent = field,
			})
		end

		local row = utility.create("Frame", {
			Name = "buttons",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -12),
			Size = UDim2.new(1, -24, 0, 35),
			Visible = hasButtons,
			ZIndex = 903,
			Parent = card,
		}, {
			utility.create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
		})

		local timer = utility.create("Frame", {
			Name = "timer",
			BackgroundColor3 = style and style.color or accent,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 2),
			Visible = not hasButtons,
			ZIndex = 906,
			Parent = card,
		})

		local syncLoop = runService.RenderStepped:Connect(function()
			shadow.Size = card.Size
			shadow.Position = card.Position
			shadow.scale.Scale = card.scale.Scale
			local fade = card.GroupTransparency
			shadow.BackgroundTransparency = fade
			shadow.UIShadow.Transparency = 0.5 + 0.5 * fade
		end)
		table.insert(library.connections, syncLoop)
		overlay.Destroying:Connect(function()
			syncLoop:Disconnect()
		end)

		local function choose(choice)
			if closed then return end
			closed = true
			for _, connection in connections do
				connection:Disconnect()
			end
			if config.callback and choice ~= nil then
				task.spawn(config.callback, choice, fieldBox and fieldBox.Text or nil)
			end
			task.delay(0.5, function()
				syncLoop:Disconnect()
				overlay:Destroy()
				nextInQueue()
			end)
		end
		handle.close = function()
			choose(nil)
		end

		local buttonFrames = {}
		for index, entry in entries do
			local style = library.buttonTypes[entry.kind] or library.buttonTypes.default
			local button = utility.create("TextButton", {
				Name = entry.text,
				AutoButtonColor = false,
				Text = "",
				BackgroundColor3 = style.fill,
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 0, 1, 0),
				LayoutOrder = index,
				ZIndex = 904,
				Parent = row,
			}, {
				utility.create("UICorner", {CornerRadius = UDim.new(0, 5)}),
				utility.create("UIScale", {Name = "scale", Scale = 1}),
				utility.create("UIStroke", {
					Name = "UIStroke",
					Color = style.stroke or style.fill,
					Thickness = style.stroke and 1 or 0,
					Transparency = 1,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
				utility.create("TextLabel", {
					Name = "label",
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					Text = entry.text,
					TextColor3 = style.label,
					TextTransparency = 1,
					TextSize = 14,
					TextTruncate = Enum.TextTruncate.AtEnd,
					FontFace = medium,
					ZIndex = 905,
				}),
			})
			button:SetAttribute("restingTransparency", style.transparent and 1 or 0)
			table.insert(buttonFrames, button)
			button.MouseEnter:Connect(function()
				utility.tween(button, 0.25, {BackgroundColor3 = style.hoverFill or style.fill}, ease, out)
				utility.tween(button.UIStroke, 0.25, {Color = style.hoverStroke or style.stroke or style.fill}, ease, out)
				utility.tween(button.label, 0.25, {TextColor3 = style.hoverLabel or style.label}, ease, out)
				if style.transparent then
					utility.tween(button, 0.25, {BackgroundTransparency = style.hoverTransparency or 1}, ease, out)
				end
			end)
			button.MouseLeave:Connect(function()
				utility.tween(button, 0.3, {BackgroundColor3 = style.fill}, ease, out)
				utility.tween(button.UIStroke, 0.3, {Color = style.stroke or style.fill}, ease, out)
				utility.tween(button.label, 0.3, {TextColor3 = style.label}, ease, out)
				utility.tween(button.scale, 0.3, {Scale = 1}, ease, out)
				if style.transparent then
					utility.tween(button, 0.3, {BackgroundTransparency = 1}, ease, out)
				end
			end)
			button.MouseButton1Down:Connect(function()
				utility.tween(button.scale, 0.12, {Scale = 0.97}, ease, out)
			end)
			button.MouseButton1Up:Connect(function()
				utility.tween(button.scale, 0.25, {Scale = 1}, ease, out)
			end)
			button.Activated:Connect(function()
				choose(entry.text)
			end)
		end

		if fieldBox then
			fieldBox.Focused:Connect(function()
				utility.tween(field.UIStroke, 0.3, {Color = Color3.fromRGB(30, 30, 30)}, ease, out)
			end)
			fieldBox.FocusLost:Connect(function(enterPressed)
				utility.tween(field.UIStroke, 0.3, {Color = Color3.fromRGB(25, 25, 25)}, ease, out)
				if enterPressed then
					choose(entries[#entries].text)
				end
			end)
		end

		table.insert(connections, userInputService.InputBegan:Connect(function(input)
			if closed then return end
			if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
				if hasButtons then
					choose(entries[#entries].text)
				end
			elseif input.KeyCode == Enum.KeyCode.Escape then
				choose(hasButtons and entries[1].text or nil)
			end
		end))

		table.insert(connections, overlay.InputBegan:Connect(function(input)
			if closed or config.dismissable == false then return end
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
			local point = Vector2.new(input.Position.X, input.Position.Y)
			local topLeft, size = card.AbsolutePosition, card.AbsoluteSize
			local within = point.X >= topLeft.X and point.X <= topLeft.X + size.X and point.Y >= topLeft.Y and point.Y <= topLeft.Y + size.Y
			if not within then
				choose(hasButtons and entries[1].text or nil)
			end
		end))

		local duration = config.duration or 3
		local remaining = duration
		if not hasButtons then
			table.insert(connections, runService.RenderStepped:Connect(function(dt)
				if card.GroupTransparency > 0.5 then return end
				remaining -= dt
				timer.Size = UDim2.new(math.clamp(remaining / duration, 0, 1), 0, 0, 2)
				if remaining <= 0 then
					choose(nil)
				end
			end))
		end

		task.defer(function()
			local bodyHeight = bodyLabel.Text ~= "" and bodyLabel.AbsoluteSize.Y or 0
			local fieldTop = top + 26 + bodyHeight + (bodyHeight > 0 and 14 or 0)
			if field then
				field.Position = UDim2.new(0.5, 0, 0, fieldTop + 6)
			end
			local height = top + 32 + bodyHeight + (bodyHeight > 0 and 20 or 0) + (field and 44 or 0) + (hasButtons and (35 + 12) or 10)
			card.Size = UDim2.fromOffset(cardWidth, height)

			utility.tween(overlay, 0.45, {BackgroundTransparency = 0.15}, ease, out)
			utility.tween(card, 0.6, {GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.5)}, ease, out)
			utility.tween(card.scale, 0.6, {Scale = 1}, ease, out)
			utility.tween(card.UIStroke, 0.6, {Transparency = 0}, ease, out)
			if badge then
				task.delay(0.1, function()
					utility.tween(badge.scale, 0.55, {Scale = 1}, ease, out)
				end)
			end
			task.delay(0.12, function()
				utility.tween(titleLabel, 0.5, {TextTransparency = 0, Position = UDim2.new(0.5, 0, 0, top)}, ease, out)
			end)
			task.delay(0.2, function()
				utility.tween(bodyLabel, 0.5, {TextTransparency = 0, Position = UDim2.new(0.5, 0, 0, top + 26)}, ease, out)
			end)
			if field then
				task.delay(0.24, function()
					if closed then return end
					utility.tween(field, 0.5, {BackgroundTransparency = 0, Position = UDim2.new(0.5, 0, 0, fieldTop)}, ease, out)
					utility.tween(field.UIStroke, 0.5, {Transparency = 0}, ease, out)
					utility.tween(fieldBox, 0.5, {TextTransparency = 0}, ease, out)
				end)
				task.delay(0.45, function()
					if not closed then
						fieldBox:CaptureFocus()
					end
				end)
			end
			for index, button in buttonFrames do
				task.delay(0.28 + (index - 1) * 0.06, function()
					if closed then return end
					utility.tween(button, 0.45, {BackgroundTransparency = button:GetAttribute("restingTransparency") or 0}, ease, out)
					utility.tween(button.UIStroke, 0.45, {Transparency = 0}, ease, out)
					utility.tween(button.label, 0.45, {TextTransparency = 0}, ease, out)
				end)
			end
		end)
	end

	function dialog:prompt(config)
		config = config or {}
		local handle = {}
		if library.isDialogOpen then
			local entry = {config = config, handle = handle}
			table.insert(queue, entry)
			handle.close = function()
				local index = table.find(queue, entry)
				if index then
					table.remove(queue, index)
				end
			end
			return handle
		end
		open(config, handle)
		return handle
	end

	return dialog
end


--------------------------------------
-- button types ----------------------
--------------------------------------

library.buttonTypes = {
	default = {
		fill = Color3.fromRGB(20, 20, 20),
		stroke = Color3.fromRGB(25, 25, 25),
		label = Color3.fromRGB(255, 255, 255),
		hoverFill = Color3.fromRGB(25, 25, 25),
		hoverStroke = Color3.fromRGB(30, 30, 30),
	},
	accent = setmetatable({}, {
		__index = function(_, key)
			local accent = library.theme.accent
			local ink = utility.contrast(accent)
			if key == "fill" then
				return accent
			elseif key == "label" then
				return ink
			elseif key == "hoverFill" then
				return accent:Lerp(ink.R > 0.5 and Color3.new(0, 0, 0) or Color3.new(1, 1, 1), 0.2)
			end
			return nil
		end,
	}),
	danger = {
		fill = Color3.fromRGB(38, 20, 20),
		stroke = Color3.fromRGB(80, 36, 36),
		label = Color3.fromRGB(248, 113, 113),
		hoverFill = Color3.fromRGB(52, 24, 24),
		hoverStroke = Color3.fromRGB(110, 46, 46),
		hoverLabel = Color3.fromRGB(255, 140, 140),
	},
	success = {
		fill = Color3.fromRGB(18, 34, 24),
		stroke = Color3.fromRGB(34, 74, 48),
		label = Color3.fromRGB(74, 222, 128),
		hoverFill = Color3.fromRGB(22, 46, 30),
		hoverStroke = Color3.fromRGB(44, 98, 62),
		hoverLabel = Color3.fromRGB(120, 235, 160),
	},
	ghost = {
		fill = Color3.fromRGB(20, 20, 20),
		label = Color3.fromRGB(100, 100, 100),
		hoverLabel = Color3.fromRGB(255, 255, 255),
		transparent = true,
		hoverTransparency = 0.5,
	},
}


--------------------------------------
-- notification types ----------------
--------------------------------------

library.notificationTypes = {
	default = {color = Color3.fromRGB(255, 255, 255), glyph = "•"},
	info = {color = Color3.fromRGB(96, 165, 250), glyph = "i"},
	success = {color = Color3.fromRGB(74, 222, 128), glyph = "✓"},
	warning = {color = Color3.fromRGB(255, 195, 9), glyph = "!"},
	error = {color = Color3.fromRGB(248, 113, 113), glyph = "×"},
	loading = {color = Color3.fromRGB(255, 195, 9), spinner = true},
}


--------------------------------------
-- notifications ---------------------
--------------------------------------

function builder.notification(screen)
	local width = 270
	local ease = Enum.EasingStyle.Quart
	local out, into = Enum.EasingDirection.Out, Enum.EasingDirection.In
	local medium = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal)
	local regular = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	local bold = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)

	local notificationFrame = utility.create("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		Name = "notification",
		Position = UDim2.new(1, -14, 1, -14),
		ZIndex = 300,
		Size = UDim2.new(0, width, 0.7, 0),
		Parent = screen,
	}, {
		utility.create("UIListLayout", {
			Name = "UIListLayout",
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})

	local instance = {}
	instance.frame = notificationFrame
	local order = 0
	local active = {}

	local function resolveType(name)
		return library.notificationTypes[name or "default"] or library.notificationTypes.default
	end

	function instance:notify(config)
		config = config or {}
		local kind = config.type or "default"
		local style = resolveType(kind)
		local duration = config.duration or 3
		local groupKey = kind .. "|" .. tostring(config.title) .. "|" .. tostring(config.body)
		local existing = config.group ~= false and active[groupKey]
		if existing and existing.bump then
			existing.bump()
			if instance.onBumped then
				task.spawn(instance.onBumped, config, kind, groupKey)
			end
			return existing
		end
		order += 1

		local holder = utility.create("Frame", {
			Name = "toast",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = order,
			ZIndex = 300,
			Parent = notificationFrame,
		})

		local card = utility.create("CanvasGroup", {
			Name = "card",
			BackgroundColor3 = Color3.fromRGB(15, 15, 15),
			GroupTransparency = 1,
			Position = UDim2.fromOffset(40, 0),
			Size = UDim2.new(1, 0, 0, 56),
			ZIndex = 301,
			Parent = holder,
		}, {
			utility.create("UICorner", {CornerRadius = UDim.new(0, 10)}),
			utility.create("UIStroke", {
				Name = "UIStroke",
				Color = Color3.fromRGB(30, 30, 30),
				Thickness = 1,
				Transparency = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
				LineJoinMode = Enum.LineJoinMode.Round,
				StrokeSizingMode = Enum.StrokeSizingMode.FixedSize,
			}),
		})

		local shadow = utility.create("Frame", {
			Name = "shadow",
			BackgroundColor3 = Color3.fromRGB(15, 15, 15),
			BackgroundTransparency = 1,
			Position = card.Position,
			Size = card.Size,
			ZIndex = 300,
			Parent = holder,
		}, {
			utility.create("UICorner", {CornerRadius = UDim.new(0, 10)}),
			utility.create("UIShadow", {
				Name = "UIShadow",
				Offset = UDim2.fromOffset(0, 4),
				Transparency = 1,
				BlurRadius = UDim.new(0, 18),
				Color = Color3.fromRGB(0, 0, 0),
				ZIndex = 1,
				Spread = UDim2.new(0, 0, 0, 0),
				Enabled = true,
			}),
		})
		local shadowEffect = shadow.UIShadow

		local badge = utility.create("Frame", {
			Name = "badge",
			BackgroundColor3 = style.color,
			BackgroundTransparency = 0.86,
			Position = UDim2.fromOffset(12, 14),
			Size = UDim2.fromOffset(24, 24),
			ZIndex = 302,
			Parent = card,
		}, {
			utility.create("UICorner", {CornerRadius = UDim.new(1, 0)}),
		})

		local glyph = utility.create("TextLabel", {
			Name = "glyph",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = style.glyph or "",
			TextColor3 = style.color,
			TextSize = 14,
			FontFace = bold,
			ZIndex = 303,
			Parent = badge,
		})

		local icon = utility.create("ImageLabel", {
			Name = "icon",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(14, 14),
			Image = config.icon or style.icon or "",
			ImageColor3 = style.color,
			Visible = (config.icon or style.icon) ~= nil,
			ZIndex = 303,
			Parent = badge,
		})

		local ring = utility.create("Frame", {
			Name = "ring",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(14, 14),
			Visible = false,
			ZIndex = 303,
			Parent = badge,
		}, {
			utility.create("UICorner", {CornerRadius = UDim.new(1, 0)}),
		})
		local ringStroke = utility.create("UIStroke", {Color = style.color, Thickness = 2, Parent = ring})
		local ringGradient = utility.create("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.35, 0),
				NumberSequenceKeypoint.new(0.6, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = ringStroke,
		})

		local titleLabel = utility.create("TextLabel", {
			Name = "title",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(46, 13),
			Size = UDim2.new(1, -58, 0, 16),
			Text = config.title or "notification",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			FontFace = medium,
			ZIndex = 302,
			Parent = card,
		})

		local bodyLabel = utility.create("TextLabel", {
			Name = "body",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(46, 31),
			Size = UDim2.new(1, -58, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = config.body or "",
			TextColor3 = Color3.fromRGB(110, 110, 110),
			TextSize = 13,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			FontFace = regular,
			ZIndex = 302,
			Parent = card,
		})

		local timer = utility.create("Frame", {
			Name = "timer",
			BackgroundColor3 = style.color,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 2),
			ZIndex = 303,
			Parent = card,
		})

		local handle = {}
		local closed = false
		local hovered = false
		local remaining = duration
		local total = duration
		local timed = not style.spinner and duration > 0 and not config.sticky
		local spinning = style.spinner == true

		local countPill = utility.create("TextLabel", {
			Name = "count",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 12),
			Size = UDim2.fromOffset(0, 18),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Color3.fromRGB(20, 20, 20),
			Text = "x1",
			TextColor3 = Color3.fromRGB(170, 170, 170),
			TextSize = 11,
			FontFace = medium,
			Visible = false,
			ZIndex = 304,
			Parent = card,
		}, {
			utility.create("UICorner", {CornerRadius = UDim.new(1, 0)}),
			utility.create("UIStroke", {Color = Color3.fromRGB(25, 25, 25), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}),
			utility.create("UIPadding", {PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7)}),
			utility.create("UIScale", {Name = "scale", Scale = 1}),
		})

		local actions
		local suppressCard = false
		if type(config.buttons) == "table" and #config.buttons > 0 then
			actions = utility.create("Frame", {
				Name = "actions",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(46, 36),
				Size = UDim2.new(1, -58, 0, 22),
				ZIndex = 302,
				Parent = card,
			}, {
				utility.create("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 6),
				}),
			})
			for index, entry in config.buttons do
				local text = type(entry) == "table" and (entry.text or entry[1]) or entry
				local kindName = type(entry) == "table" and entry.type or (index == 1 and "accent" or "default")
				local look = library.buttonTypes[kindName] or library.buttonTypes.default
				local button = utility.create("TextButton", {
					Name = tostring(text),
					AutoButtonColor = false,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, 22),
					BackgroundColor3 = look.fill,
					BackgroundTransparency = look.transparent and 1 or 0,
					Text = tostring(text),
					TextColor3 = look.label,
					TextSize = 12,
					FontFace = medium,
					LayoutOrder = index,
					ZIndex = 303,
					Parent = actions,
				}, {
					utility.create("UICorner", {CornerRadius = UDim.new(0, 5)}),
					utility.create("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}),
					utility.create("UIStroke", {Name = "UIStroke", Color = look.stroke or look.fill, Thickness = look.stroke and 1 or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}),
				})
				button.MouseEnter:Connect(function()
					utility.tween(button, 0.25, {BackgroundColor3 = look.hoverFill or look.fill, TextColor3 = look.hoverLabel or look.label}, ease, out)
					utility.tween(button.UIStroke, 0.25, {Color = look.hoverStroke or look.stroke or look.fill}, ease, out)
				end)
				button.MouseLeave:Connect(function()
					utility.tween(button, 0.3, {BackgroundColor3 = look.fill, TextColor3 = look.label}, ease, out)
					utility.tween(button.UIStroke, 0.3, {Color = look.stroke or look.fill}, ease, out)
				end)
				button.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						suppressCard = true
					end
				end)
				button.Activated:Connect(function()
					if type(entry) == "table" and entry.callback then
						task.spawn(entry.callback, handle)
					end
					if config.buttonCallback then
						task.spawn(config.buttonCallback, tostring(text), handle)
					end
					handle:close()
				end)
			end
		end

		local count = 1
		active[groupKey] = handle
		function handle.bump()
			if closed then return end
			count += 1
			countPill.Text = "x" .. count
			if not countPill.Visible then
				countPill.Visible = true
				titleLabel.Size = UDim2.new(1, -96, 0, 16)
			end
			countPill.scale.Scale = 1.3
			utility.tween(countPill.scale, 0.4, {Scale = 1}, ease, out)
			if timed then
				remaining = total
				timer.Size = UDim2.new(1, 0, 0, 2)
			end
		end

		local function measure()
			local bodyHeight = bodyLabel.Text ~= "" and bodyLabel.AbsoluteSize.Y or 0
			local height = bodyHeight > 0 and (31 + bodyHeight + 14) or 52
			if actions then
				local y = bodyHeight > 0 and (31 + bodyHeight + 10) or 38
				actions.Position = UDim2.fromOffset(46, y)
				height = y + 22 + 13
			end
			if bodyHeight == 0 and not actions then
				titleLabel.Position = UDim2.fromOffset(46, 18)
				badge.Position = UDim2.fromOffset(12, 14)
			else
				titleLabel.Position = UDim2.fromOffset(46, 13)
			end
			return height
		end

		local function applyStyle(newStyle, animate)
			local time = animate and 0.35 or 0
			if animate then
				utility.tween(badge, time, {BackgroundColor3 = newStyle.color}, ease, out)
				utility.tween(glyph, time, {TextColor3 = newStyle.color}, ease, out)
				utility.tween(timer, time, {BackgroundColor3 = newStyle.color}, ease, out)
				utility.tween(ringStroke, time, {Color = newStyle.color}, ease, out)
				icon.ImageColor3 = newStyle.color
			else
				badge.BackgroundColor3 = newStyle.color
				glyph.TextColor3 = newStyle.color
				timer.BackgroundColor3 = newStyle.color
				ringStroke.Color = newStyle.color
				icon.ImageColor3 = newStyle.color
			end
			spinning = newStyle.spinner == true
			ring.Visible = spinning
			glyph.Visible = not spinning and not icon.Visible
			glyph.Text = newStyle.glyph or ""
			timer.Visible = not spinning and not config.sticky
		end

		applyStyle(style, false)

		local loop
		loop = runService.RenderStepped:Connect(function(dt)
			shadow.Position = card.Position
			shadow.Size = card.Size
			local fade = card.GroupTransparency
			shadow.BackgroundTransparency = fade
			shadowEffect.Transparency = 0.3 + 0.7 * fade
			if spinning then
				ringGradient.Rotation = (ringGradient.Rotation + dt * 360) % 360
			end
			if timed and not hovered and not closed then
				remaining -= dt
				timer.Size = UDim2.new(math.clamp(remaining / total, 0, 1), 0, 0, 2)
				if remaining <= 0 then
					handle:close()
				end
			end
		end)

		function handle:close()
			if closed then return end
			closed = true
			if active[groupKey] == handle then
				active[groupKey] = nil
			end
			utility.tween(card, 0.4, {GroupTransparency = 1, Position = UDim2.fromOffset(50, 0)}, ease, into)
			utility.tween(card.UIStroke, 0.4, {Transparency = 1}, ease, into)
			task.delay(0.3, function()
				utility.tween(holder, 0.4, {Size = UDim2.new(1, 0, 0, 0)}, ease, out)
				task.delay(0.42, function()
					loop:Disconnect()
					holder:Destroy()
				end)
			end)
		end

		function handle:update(newConfig)
			if closed then return end
			newConfig = newConfig or {}
			if active[groupKey] == handle then
				active[groupKey] = nil
			end
			if newConfig.type then
				applyStyle(resolveType(newConfig.type), true)
			end
			local function swapText(label, text)
				if text == nil or label.Text == text then return end
				utility.tween(label, 0.15, {TextTransparency = 1}, ease, out)
				task.delay(0.15, function()
					label.Text = text
					utility.tween(label, 0.3, {TextTransparency = 0}, ease, out)
					task.defer(function()
						if not closed then
							utility.tween(holder, 0.35, {Size = UDim2.new(1, 0, 0, measure())}, ease, out)
							utility.tween(card, 0.35, {Size = UDim2.new(1, 0, 0, measure())}, ease, out)
						end
					end)
				end)
			end
			swapText(titleLabel, newConfig.title)
			swapText(bodyLabel, newConfig.body)
			local newDuration = newConfig.duration or (newConfig.type and not spinning and 3) or nil
			if newDuration and newDuration > 0 and not spinning then
				total = newDuration
				remaining = newDuration
				timed = true
				timer.Size = UDim2.new(1, 0, 0, 2)
			end
		end

		card.MouseEnter:Connect(function()
			hovered = true
		end)
		card.MouseLeave:Connect(function()
			hovered = false
		end)
		card.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				task.defer(function()
					if suppressCard then
						suppressCard = false
						return
					end
					if config.callback then
						task.spawn(config.callback)
					end
					handle:close()
				end)
			end
		end)

		if instance.onAdded then
			task.spawn(instance.onAdded, config, kind, groupKey)
		end

		task.defer(function()
			local height = measure()
			card.Size = UDim2.new(1, 0, 0, height)
			utility.tween(holder, 0.45, {Size = UDim2.new(1, 0, 0, height)}, ease, out)
			task.delay(0.08, function()
				utility.tween(card, 0.55, {GroupTransparency = 0, Position = UDim2.fromOffset(0, 0)}, ease, out)
				utility.tween(card.UIStroke, 0.55, {Transparency = 0}, ease, out)
			end)
		end)

		return handle
	end

	return instance
end


--------------------------------------
-- library.new -----------------------
--------------------------------------

function library.new(config)
	if library.window then
		print("cant make two windows")
		return
	end

	config = config or {}

	local title = config.title or "my script"
	local subtitle = config.subtitle or ""
	local configFolder = config.configFolder or config.title
	local size = config.size or UDim2.fromOffset(700,400)

	local screen = utility.create("ScreenGui", {
		Name = title,
		Parent = game.CoreGui,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.None,
	})

	local canvas = builder.canvas(screen, size)
	local notification = builder.notification(screen)

	local topbar = builder.topbar(canvas, title, subtitle, config.icon, config.display)
	local sidebar = builder.sidebar(canvas)
	local content = utility.create("Frame", {
		AnchorPoint = Vector2.new(0, 0),
		BackgroundTransparency = 1,
		Name = "content",
		Position = UDim2.new(0, 165, 0, 0),
		Visible = true,
		ZIndex = 10,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Size = UDim2.new(1, -170, 1, 0),
		Parent = canvas
	}, {
		utility.create("Frame", {
			AnchorPoint = Vector2.new(0, 0),
			BackgroundTransparency = 1,
			Name = "container",
			Position = UDim2.new(0, 0, 0, 48),
			Visible = true,
			ZIndex = 10,
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			Size = UDim2.new(1, 0, 1, -50),
		})
	})
	local dialog = builder.dialog(content)


	--------------------------------------
	-- library funcs ---------------------
	--------------------------------------

	function library:notify(config)
		config = config or {}
		config.title = config.title or "notification"
		config.duration = config.duration or 3
		return notification:notify(config)
	end


	--------------------------------------
	-- window ----------------------------
	--------------------------------------

	local window
	window = {
		canvas = canvas,
		topbar = topbar,
		sidebar = sidebar,
		screen = screen,

	}
	window.originalSize = canvas.Size
	window.isOpen = true
	utility.setupDrag(canvas, topbar.frame)


	--------------------------------------
	-- resize ----------------------------
	--------------------------------------

	local minSize = config.minSize or Vector2.new(560, 340)
	local grip = utility.create("TextButton", {
		Name = "resize",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -4, 1, -4),
		Size = UDim2.fromOffset(16, 16),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 50,
		Parent = canvas,
	})
	for _, offset in {Vector2.new(12, 4), Vector2.new(8, 8), Vector2.new(12, 8), Vector2.new(4, 12), Vector2.new(8, 12), Vector2.new(12, 12)} do
		utility.create("Frame", {
			Name = "dot",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(offset.X, offset.Y),
			Size = UDim2.fromOffset(2, 2),
			BorderSizePixel = 0,
			BackgroundColor3 = Color3.fromRGB(60, 60, 60),
			ZIndex = 51,
			Parent = grip,
		}, {
			utility.create("UICorner", {CornerRadius = UDim.new(1, 0)}),
		})
	end
	local resizing, gripHovered = false, false
	local resizeStart, startSize, startPosition
	local function setGrip(color)
		for _, dot in grip:GetChildren() do
			if dot:IsA("Frame") then
				utility.tween(dot, 0.25, {BackgroundColor3 = color}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
			end
		end
	end
	grip.MouseEnter:Connect(function()
		gripHovered = true
		if not resizing then setGrip(Color3.fromRGB(140, 140, 140)) end
	end)
	grip.MouseLeave:Connect(function()
		gripHovered = false
		if not resizing then setGrip(Color3.fromRGB(60, 60, 60)) end
	end)
	grip.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		resizing = true
		resizeStart = input.Position
		startSize = canvas.AbsoluteSize
		startPosition = canvas.Position
		canvas:SetAttribute("resizing", true)
		setGrip(library.theme.accent)
	end)
	table.insert(library.connections, userInputService.InputChanged:Connect(function(input)
		if not resizing then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local delta = input.Position - resizeStart
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
		local w = math.clamp(startSize.X + delta.X, minSize.X, viewport.X - 20)
		local h = math.clamp(startSize.Y + delta.Y, minSize.Y, viewport.Y - 20)
		local anchor = canvas.AnchorPoint
		canvas.Size = UDim2.fromOffset(w, h)
		canvas.Position = startPosition + UDim2.fromOffset((w - startSize.X) * anchor.X, (h - startSize.Y) * anchor.Y)
	end))
	table.insert(library.connections, userInputService.InputEnded:Connect(function(input)
		if not resizing then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		resizing = false
		window.originalSize = canvas.Size
		canvas:SetAttribute("resizing", nil)
		setGrip(gripHovered and Color3.fromRGB(140, 140, 140) or Color3.fromRGB(60, 60, 60))
	end))
	topbar.nav.close.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			window:dialog({
				title = "close window?",
				body = "are you sure you want to unload the interface?",
				type = "warning",
				danger = true,
				buttons = {
					"no",
					"yes",
				},
				callback = function(choice)
					if choice == "yes" then
						library:unload()
					end
				end,
			})
		end
	end)

	topbar.nav.hide.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			window:toggle(false)
		end
	end)

	library.window = window


	--------------------------------------
	-- tooltips --------------------------
	--------------------------------------

	local guiService = game:GetService("GuiService")
	local tooltipFrame = utility.create("CanvasGroup", {
		Name = "tooltip",
		BackgroundColor3 = Color3.fromRGB(15, 15, 15),
		GroupTransparency = 1,
		Size = UDim2.fromOffset(0, 0),
		Visible = false,
		ZIndex = 950,
		Parent = screen,
	}, {
		utility.create("UICorner", {CornerRadius = UDim.new(0, 6)}),
		utility.create("UIStroke", {Name = "UIStroke", Color = Color3.fromRGB(25, 25, 25), Thickness = 1, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual}),
		utility.create("UIPadding", {PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}),
		utility.create("TextLabel", {
			Name = "text",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(0, 0),
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = "",
			TextColor3 = Color3.fromRGB(170, 170, 170),
			TextSize = 13,
			TextWrapped = true,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
			ZIndex = 951,
		}, {
			utility.create("UISizeConstraint", {MaxSize = Vector2.new(240, math.huge)}),
		}),
	})
	local tooltipShadow = utility.create("Frame", {
		Name = "tooltipShadow",
		BackgroundColor3 = Color3.fromRGB(15, 15, 15),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 949,
		Parent = screen,
	}, {
		utility.create("UICorner", {CornerRadius = UDim.new(0, 6)}),
		utility.create("UIShadow", {
			Name = "UIShadow",
			Offset = UDim2.fromOffset(0, 4),
			Transparency = 1,
			BlurRadius = UDim.new(0, 16),
			Color = Color3.fromRGB(0, 0, 0),
			ZIndex = 1,
			Spread = UDim2.new(0, 0, 0, 0),
			Enabled = true,
		}),
	})
	local tooltipScale = utility.create("UIScale", {Scale = 0.94, Parent = tooltipFrame})
	local tooltipProgress = Instance.new("NumberValue")
	local tooltipOwner
	local tooltipToken = 0
	local tooltipShown = false
	local tooltipPos
	local quartEase = Enum.EasingStyle.Quart

	local typeChars = {}
	local typeHead = 0
	local typeSpeed = 75
	local typeFade = 9
	local lastRendered

	local function esc(text)
		text = string.gsub(text, "&", "&amp;")
		text = string.gsub(text, "<", "&lt;")
		text = string.gsub(text, ">", "&gt;")
		return text
	end

	local function drawTip()
		local count = #typeChars
		local solid = math.clamp(math.floor(typeHead - typeFade), 0, count)
		local parts = {}
		if solid > 0 then
			table.insert(parts, esc(table.concat(typeChars, "", 1, solid)))
		end
		for index = solid + 1, count do
			local alpha = math.clamp((typeHead - index + 1) / typeFade, 0, 1)
			if alpha <= 0 then
				table.insert(parts, '<font transparency="1">' .. esc(table.concat(typeChars, "", index, count)) .. "</font>")
				break
			end
			table.insert(parts, string.format('<font transparency="%.2f">%s</font>', 1 - alpha, esc(typeChars[index])))
		end
		local text = table.concat(parts)
		if text ~= lastRendered then
			lastRendered = text
			tooltipFrame.text.Text = text
		end
	end

	local textService = game:GetService("TextService")
	local function tipSize(text)
		local bounds = textService:GetTextSize(text, 13, Enum.Font.Roboto, Vector2.new(240, 1000))
		return Vector2.new(math.ceil(bounds.X) + 1, math.ceil(bounds.Y))
	end

	local function typeTip(text)
		local bounds = tipSize(text)
		local goal = UDim2.fromOffset(bounds.X + 20, bounds.Y + 14)
		tooltipFrame.text.Size = UDim2.fromOffset(bounds.X, bounds.Y)
		if tooltipFrame.Visible and tooltipProgress.Value > 0.05 then
			utility.tween(tooltipFrame, 0.35, {Size = goal}, quartEase, Enum.EasingDirection.Out)
		else
			tooltipFrame.Size = goal
		end
		table.clear(typeChars)
		for _, code in utf8.codes(text) do
			table.insert(typeChars, utf8.char(code))
		end
		typeHead = 0
		lastRendered = nil
		drawTip()
	end

	local function hideTip()
		tooltipToken += 1
		tooltipOwner = nil
		if not tooltipShown then return end
		tooltipShown = false
		local token = tooltipToken
		utility.tween(tooltipProgress, 0.25, {Value = 0}, quartEase, Enum.EasingDirection.Out)
		task.delay(0.27, function()
			if token == tooltipToken then
				tooltipFrame.Visible = false
				tooltipShadow.Visible = false
				tooltipPos = nil
			end
		end)
	end

	local function tipPos(size)
		local mouse = userInputService:GetMouseLocation()
		if not screen.IgnoreGuiInset then
			mouse -= guiService:GetGuiInset()
		end
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
		local x = math.clamp(mouse.X + 14, 6, viewport.X - size.X - 6)
		local y = mouse.Y + 18
		if y + size.Y > viewport.Y - 6 then
			y = mouse.Y - size.Y - 12
		end
		return Vector2.new(x, y)
	end

	table.insert(library.connections, runService.RenderStepped:Connect(function(dt)
		if not tooltipFrame.Visible then return end
		if typeHead < #typeChars + typeFade then
			typeHead = math.min(typeHead + dt * typeSpeed, #typeChars + typeFade)
			drawTip()
		end
		local p = tooltipProgress.Value
		local size = tooltipFrame.AbsoluteSize
		local goal = tipPos(size)
		if not tooltipPos then
			tooltipPos = goal
		else
			tooltipPos = tooltipPos:Lerp(goal, math.min(1, dt * 9))
		end
		local rise = (1 - p) * 6
		tooltipFrame.Position = UDim2.fromOffset(tooltipPos.X, tooltipPos.Y + rise)
		tooltipFrame.GroupTransparency = 1 - p
		tooltipFrame.UIStroke.Transparency = 1 - p
		tooltipScale.Scale = 0.94 + 0.06 * p
		tooltipShadow.Position = tooltipFrame.Position
		tooltipShadow.Size = UDim2.fromOffset(size.X, size.Y)
		tooltipShadow.UIShadow.Transparency = 1 - 0.7 * p
	end))

	local function showTip(target)
		local text = target:GetAttribute("tooltip") or ""
		local wasVisible = tooltipFrame.Visible
		tooltipOwner = target
		tooltipShown = true
		if not wasVisible then
			tooltipPos = nil
		end
		typeTip(text)
		tooltipFrame.Visible = true
		tooltipShadow.Visible = true
		utility.tween(tooltipProgress, 0.4, {Value = 1}, quartEase, Enum.EasingDirection.Out)
	end

	function window:tooltip(target, text)
		if not target or not target:IsA("GuiObject") then return end
		target:SetAttribute("tooltip", text)
		target.MouseEnter:Connect(function()
			local current = target:GetAttribute("tooltip")
			if not current or current == "" then return end
			tooltipToken += 1
			local token = tooltipToken
			tooltipOwner = target
			if tooltipFrame.Visible and tooltipProgress.Value > 0.05 then
				showTip(target)
				return
			end
			task.delay(0.35, function()
				if token ~= tooltipToken or tooltipOwner ~= target or not window.isOpen then return end
				showTip(target)
			end)
		end)
		target.MouseLeave:Connect(function()
			if tooltipOwner ~= target then return end
			tooltipToken += 1
			local token = tooltipToken
			task.delay(0.08, function()
				if token == tooltipToken then
					hideTip()
				end
			end)
		end)
		target.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				if tooltipOwner == target or tooltipShown then
					hideTip()
				end
			end
		end)
		target.Destroying:Connect(function()
			if tooltipOwner == target then
				hideTip()
			end
		end)
	end
	window.hideTooltip = hideTip


	--------------------------------------
	-- window funcs ----------------------
	--------------------------------------

	function window:toggle(state)
		if state == nil then
			state = not window.isOpen
		end

		window.isOpen = state

		local shadow = canvas:FindFirstChild("UIShadow")
		if shadow then
			pcall(function()
				utility.tween(shadow, state and 0.4 or 0.2, {Transparency = state and 0.35 or 1}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
			end)
		end

		if state then
			utility.tween(canvas, 0.3, {
				Size = window.originalSize
			}, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		else
			utility.tween(canvas, 0.3, {
				Size = UDim2.new(
					window.originalSize.X.Scale,
					window.originalSize.X.Offset,
					0,
					0
				)
			},  Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		end
	end

	function window:setIcon(image)
		topbar.setIcon(image)
	end

	function window:setDisplay(mode)
		topbar.setDisplay(mode)
	end

	function window:setToggleKey(bind: Enum.KeyCode)
		library.toggleKey = bind
		if window.onToggleKeyChanged then
			window.onToggleKeyChanged(bind)
		end
	end

	function window:dialog(config)
		config = config or {}
		config.title = config.title or "header"
		config.body = config.body or ""
		config.duration = config.duration or 3
		return dialog:prompt(config)
	end

	userInputService.InputBegan:Connect(function(input, gpe)
		if gpe then
			return
		end

		if input.KeyCode == library.toggleKey and not library.bindingToggle then
			window:toggle(not window.isOpen)
		end
	end)


	--------------------------------------
	-- tabs ------------------------------
	--------------------------------------

	local tabs = {}
	local currentTab = nil
	local searchIndex = {}

	function window:createSection(name)
		local sectionOrder = #sidebar.list:GetChildren() + 1
		local sectionFrame = utility.create("Frame", {
			AnchorPoint = Vector2.new(0, 0),
			BackgroundTransparency = 1,
			Name = "section",
			Parent = sidebar.list,

			Position = UDim2.new(0, 0, 0, 0),
			Visible = true,

			ZIndex = 5,
			BackgroundColor3 = Color3.fromRGB(25, 25, 25),

			Size = UDim2.new(0, 145, 0, 19),
			LayoutOrder = sectionOrder,
		}, {
			utility.create("TextLabel", {
				Visible = true,
				TextColor3 = Color3.fromRGB(100, 100, 100),
				Text = name,

				AnchorPoint = Vector2.new(0.5, 0.5),
				Name = "label",
				BackgroundTransparency = 1,

				Position = UDim2.new(0.5, 0, 0.5, 0),
				ZIndex = 5,

				TextSize = 14,
				Size = UDim2.new(0.9, 0, 0.57, 0),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,

				FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
			})
		})

		return sectionFrame
	end

	function window:createDivider()
		local dividerOrder = #sidebar.list:GetChildren() + 1
		local dividerFrame = utility.create("Frame", {
			AnchorPoint = Vector2.new(0, 0),
			BackgroundTransparency = 1,
			Name = "divider",
			Position = UDim2.new(0, 0, 0.11538461595773697, 0),
			Visible = true,
			ZIndex = 5,
			BackgroundColor3 = Color3.fromRGB(25, 25, 25),
			Size = UDim2.new(0, 145, 0, 11),
			Parent = sidebar.list,
			LayoutOrder = dividerOrder,
		}, {
			utility.create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 0,
				Name = "Frame",
				Position = UDim2.new(0.5, 0, 0.5, 0),
				Visible = true,
				ZIndex = 5,
				BackgroundColor3 = Color3.fromRGB(25, 25, 25),
				Size = UDim2.new(0.800000011920929, 0, 0, 1),
			})
		})

		return dividerFrame
	end

	local entranceCache = setmetatable({}, {__mode = "k"})
	local entranceToken = setmetatable({}, {__mode = "k"})


	--------------------------------------
	-- entrance animations ---------------
	--------------------------------------

	local function snapshot(element)
		local values = {}
		local function record(inst)
			local entry = {}
			if inst:IsA("GuiObject") then
				entry.BackgroundTransparency = inst.BackgroundTransparency
			end
			if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
				entry.TextTransparency = inst.TextTransparency
				entry.TextStrokeTransparency = inst.TextStrokeTransparency
			end
			if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
				entry.ImageTransparency = inst.ImageTransparency
			end
			if inst:IsA("UIStroke") then
				entry.Transparency = inst.Transparency
			end
			if next(entry) then
				values[inst] = entry
			end
		end
		record(element)
		for _, descendant in element:GetDescendants() do
			record(descendant)
		end
		return values
	end

	local function animateElement(element, delay)
		local settings = library.animation
		entranceToken[element] = (entranceToken[element] or 0) + 1
		local token = entranceToken[element]
		local cache = entranceCache[element]
		if not cache then
			cache = snapshot(element)
			entranceCache[element] = cache
		end
		element.Position = UDim2.fromOffset(-settings.elementSlide, 0)
		for inst, entry in cache do
			if inst.Parent then
				for property, value in entry do
					if value < 1 then
						inst[property] = 1
					end
				end
			end
		end
		task.delay(delay, function()
			if entranceToken[element] ~= token or not element.Parent then return end
			tweenService:Create(element, TweenInfo.new(settings.elementDuration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Position = UDim2.fromOffset(0, 0),
			}):Play()
			local fadeInfo = TweenInfo.new(settings.elementFade, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
			for inst, entry in cache do
				if inst.Parent then
					tweenService:Create(inst, fadeInfo, entry):Play()
				end
			end
			task.delay(math.max(settings.elementDuration, settings.elementFade) + 0.05, function()
				if entranceToken[element] == token then
					entranceCache[element] = nil
				end
			end)
		end)
	end

	library.animateElement = animateElement

	local function playEntrance(tab)
		local list = tab and tab.list
		if not list then return end
		local holders = {}
		for _, holder in list:GetChildren() do
			if holder:GetAttribute("entranceHolder") and holder.Visible then
				table.insert(holders, holder)
			end
		end
		table.sort(holders, function(a, b)
			if a.LayoutOrder ~= b.LayoutOrder then
				return a.LayoutOrder < b.LayoutOrder
			end
			return a.AbsolutePosition.Y < b.AbsolutePosition.Y
		end)
		local settings = library.animation
		for index, holder in holders do
			local element = holder:FindFirstChildWhichIsA("GuiObject")
			if element then
				animateElement(element, math.min(index - 1, settings.maxStagger) * settings.elementStagger)
			end
		end
	end

	local function wrapElement(list, element)
		if element.Parent ~= list or element:GetAttribute("entranceHolder") or element:GetAttribute("wrapped") then return end
		element:SetAttribute("wrapped", true)
		local holder = Instance.new("Frame")
		holder.Name = element.Name
		holder:SetAttribute("entranceHolder", true)
		holder.BackgroundTransparency = 1
		holder.BorderSizePixel = 0
		local function fitHolder()
			holder.Size = UDim2.new(element.Size.X.Scale, element.Size.X.Offset, 0, element.AbsoluteSize.Y)
		end
		fitHolder()
		holder.LayoutOrder = element.LayoutOrder
		holder.ZIndex = element.ZIndex
		holder.Visible = element.Visible
		holder.Parent = list
		element.AnchorPoint = Vector2.new(0, 0)
		element.Position = UDim2.fromOffset(0, 0)
		element.Parent = holder
		element:GetPropertyChangedSignal("LayoutOrder"):Connect(function()
			holder.LayoutOrder = element.LayoutOrder
		end)
		element:GetPropertyChangedSignal("ZIndex"):Connect(function()
			holder.ZIndex = element.ZIndex
		end)
		element:GetPropertyChangedSignal("Visible"):Connect(function()
			holder.Visible = element.Visible
		end)
		element:GetPropertyChangedSignal("Size"):Connect(fitHolder)
		element:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitHolder)
		element.Destroying:Connect(function()
			holder:Destroy()
		end)
	end


	--------------------------------------
	-- create tab ------------------------
	--------------------------------------

	function window:createTab(config)
		local tabName = config.name or "Tab"
		local tabIcon = config.icon or "rbxassetid://10723407389"
		local tabOrder = config.order or (#sidebar.list:GetChildren() + 1)
		if not sidebar then
			sidebar = builder.sidebar(canvas)
			window.sidebar = sidebar
		end

		local tab = {}

		local tabBtn
		local tabContent

		tabBtn = utility.create("TextLabel", {
			Visible = true,
			TextColor3 = Color3.fromRGB(0, 0, 0),
			Text = tabName,
			AnchorPoint = Vector2.new(0, 0),
			Name = "tab",
			BackgroundTransparency = 0,
			TextTransparency = 1,
			Position = UDim2.new(0, 0, 0, 0),
			BackgroundColor3 = Color3.fromRGB(10, 10, 10),
			ZIndex = 5,
			TextSize = 14,
			Size = UDim2.new(1, 0, -0.01, 38),
			LayoutOrder = tabOrder,
			Parent = sidebar.list
		}, {
			utility.create("ImageLabel", {
				Visible = true,
				AnchorPoint = Vector2.new(0, 0.5),
				Image = tabIcon,
				ImageColor3 = Color3.fromRGB(100, 100, 100),
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 10, 0.5, -1),
				Name = "icon",
				ZIndex = 5,
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				Size = UDim2.new(0, 16, 0, 16),
			}),
			utility.create("TextLabel", {
				Visible = true,
				TextColor3 = Color3.fromRGB(100, 100, 100),
				Text = tabName,
				AnchorPoint = Vector2.new(0, 0.5),
				Name = "label",
				BackgroundTransparency = 1,
				Position = UDim2.new(-0.041, 40, 0.5, 0),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				ZIndex = 5,
				TextSize = 14,
				Size = UDim2.new(1, -56, 0.39, 0),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
			}),
			utility.create("UICorner", {
				Name = "UICorner",
				CornerRadius = UDim.new(0, 10),
			})
		})

		tabContent = utility.create("CanvasGroup", {
			AnchorPoint = Vector2.new(0, 0),
			BackgroundTransparency = 1,
			Name = tabName,
			Position = UDim2.new(0, 0, 0, 0),
			Visible = false,
			ZIndex = 10,
			BackgroundColor3 = Color3.fromRGB(200, 200, 200),
			Size = UDim2.new(1, 0, 1, -15),
			Parent = content.container
		}, {
			utility.create("ScrollingFrame", {
				AnchorPoint = Vector2.new(0, 0),
				BackgroundTransparency = 1,
				Name = "list",
				Position = UDim2.new(0, 0, 0, 0),
				Visible = true,
				ZIndex = 10,
				BackgroundColor3 = Color3.fromRGB(15, 15, 15),
				Size = UDim2.new(1, 0, 1, 0),
				ScrollBarThickness = 5,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(0, 0, 0, 0),
			}, {
				utility.create("UIListLayout", {
					Name = "UIListLayout",
					Padding = UDim.new(0, 6),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				utility.create("UIPadding", {
					PaddingTop = UDim.new(0, 14),
					Name = "UIPadding",
					PaddingBottom = UDim.new(0, 0),
					PaddingLeft = UDim.new(0, 6),
					PaddingRight = UDim.new(0, 6),
				}),
			})

		})

		tab.button = tabBtn
		tab.name = tabName
		tab.order = tabOrder
		tab.content = tabContent
		tab.list = tabContent.list

		table.insert(tabs, tab)

		task.defer(function()
			if not currentTab or #tabs == 1 then
				window:selectTab(tab)
			end
		end)

		tabBtn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				if not utility.isTop(tabBtn, input.Position.X, input.Position.Y) then return end
				window:selectTab(tab)
			end
		end)


		--------------------------------------
		-- divider ---------------------------
		--------------------------------------

		function tab:createDivider()
			utility.create("Frame", {
				AnchorPoint = Vector2.new(0, 0),
				BackgroundTransparency = 1,
				Name = "divider",
				Position = UDim2.new(0, 0, 0.11538461595773697, 0),
				Visible = true,
				ZIndex = 5,
				BackgroundColor3 = Color3.fromRGB(25, 25, 25),
				Size = UDim2.new(1, 0, 0, 11),
				Parent = tab.list,
			}, {
				utility.create("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 0,
					Name = "Frame",
					Position = UDim2.new(0.5, 0, 0.5, 0),
					Visible = true,
					ZIndex = 5,
					BackgroundColor3 = Color3.fromRGB(25, 25, 25),
					Size = UDim2.new(1, -10, 0, 1),
				})
			})
		end


		--------------------------------------
		-- player picker ---------------------
		--------------------------------------

		local function pickerDropdown(config, labelOf, imageOf, findText)
			local title = config.title or "Dropdown"
			local description = config.description

			local options = config.options or {}
			local default = config.default
			local callback = config.callback or function() end

			local selected = ""
			local expanded = false
			local multi = config.multi == true
			local searchable = config.search == true
			local picked = {}
			if multi and type(default) == "table" then
				for _, value in default do
					picked[value] = true
				end
			end

			local dropdownFrame = utility.create("Frame", {
				AnchorPoint = Vector2.new(0, 0),
				BackgroundTransparency = 0,
				Name = "playerPicker",
				Position = UDim2.new(0, 0, 0.3115122616291046, 0),
				Visible = true,
				ZIndex = 10,
				BackgroundColor3 = Color3.fromRGB(15, 15, 15),
				Size = UDim2.new(1, 0, 0, (description and 54 or 44)),
				Parent = tab.list,
			}, {
				utility.create("Frame", {
					AnchorPoint = Vector2.new(0, 0),
					BackgroundTransparency = 0,
					Name = "options",
					Position = UDim2.new(1, -198, 0, 7),
					Visible = true,
					ZIndex = 15,
					BackgroundColor3 = Color3.fromRGB(20, 20, 20),
					Size = UDim2.new(0, 190, 1, -15),
					ClipsDescendants = true,

				}, {
					utility.create("Frame", {
						AnchorPoint = Vector2.new(0, 0),
						BackgroundTransparency = 1,
						Name = "list",
						Position = UDim2.new(0, 5, 0, 50),
						Visible = true,
						ZIndex = 1,
						BackgroundColor3 = Color3.fromRGB(25, 25, 25),
						Size = UDim2.new(1, 50, 0, 50),
					}, {
						utility.create("UICorner", {
							Name = "UICorner",
							CornerRadius = UDim.new(0, 5),
						}),
						utility.create("UIListLayout", {
							Name = "UIListLayout",
							Padding = UDim.new(0, 5),
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
						utility.create("UIPadding", {
							PaddingTop = UDim.new(0, 5),
							Name = "UIPadding",
							PaddingBottom = UDim.new(0, 0),
							PaddingLeft = UDim.new(0, 0),
							PaddingRight = UDim.new(0, 0),
						}),

					}),
					utility.create("ImageLabel", {
						Visible = true,
						AnchorPoint = Vector2.new(0, 0),
						Image = "rbxassetid://10709791523",
						BackgroundTransparency = 1,
						Position = UDim2.new(1, -25, 0, (description and 12 or 7)),
						Name = "chevron",
						ZIndex = 15,
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						Size = UDim2.new(0, 15, 0, 15),
					}),
					utility.create("TextLabel", {
						Visible = true,
						TextColor3 = Color3.fromRGB(255, 255, 255),
						Text = config.placeholder or "none",
						RichText = true,
						AnchorPoint = Vector2.new(0, 0),
						Name = "value",
						BackgroundTransparency = 1,
						Position = UDim2.new(0, 10, 0, (description and 13 or 8)),
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						ZIndex = 15,
						TextSize = 14,
						Size = UDim2.new(0, 122, 0, 13),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextScaled = true,

						FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium),
					}),
					utility.create("UIStroke", {
						Name = "UIStroke",
						Color = Color3.fromRGB(20, 20, 20),
						Thickness = 1,
						ZIndex = 1,
					}),
					utility.create("UICorner", {
						Name = "UICorner",
						CornerRadius = UDim.new(0, 5),
					}),
					utility.create("Frame", {
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						Name = "divider",
						Position = UDim2.new(0.5, 0, 0, 40),
						Visible = true,
						ZIndex = 5,
						BackgroundColor3 = Color3.fromRGB(20, 20, 20),
						Size = UDim2.new(1, 0, 0, 11),
					}, {
						utility.create("Frame", {
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 0,
							Name = "Frame",
							Position = UDim2.new(0.5, 0, 0.5, 0),
							Visible = true,
							ZIndex = 5,
							BackgroundColor3 = Color3.fromRGB(20, 20, 20),
							Size = UDim2.new(1, 0, 0, 1),
						})
					}),
					utility.create("UIShadow", {
						Offset = UDim2.new(0, 0, 0, 0),
						Transparency = .5,
						Name = "UIShadow",
						BlurRadius = UDim.new(0, 15),
						Color = Color3.fromRGB(0, 0, 0),
						ZIndex = 1,
						Spread = UDim2.new(0, 0, 0, 0),
						Enabled = true,
					})
				}),

				utility.create("TextLabel", {
					Visible = true,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					Text = "Dropdown",
					AnchorPoint = Vector2.new(0, 0),
					Name = "title",
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 15, 0, 14),
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					ZIndex = 10,
					TextSize = 14,
					Size = UDim2.new(0.88416987657547, -15, 0, 13),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextScaled = true,

					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium),
				}),
				utility.create("UICorner", {
					Name = "UICorner",
					CornerRadius = UDim.new(0, 5),
				})
			})

			local optionsFrame = dropdownFrame.options
			optionsFrame.Active = true
			local listFrame = optionsFrame.list 

			local titleLabel = dropdownFrame.title
			titleLabel.Text = title
			local valueLabel = optionsFrame.value

			local function headIcon()
				if multi then
					for _, option in options do
						if picked[option] then
							return imageOf(option)
						end
					end
					return ""
				end
				return imageOf(selected ~= "" and selected or default)
			end

			local function avatarFor(label, size)
				local avatar = utility.create("ImageLabel", {
					Name = "avatar",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(0, -6, 0.5, 0),
					Size = UDim2.fromOffset(size, size),
					BackgroundColor3 = Color3.fromRGB(25, 25, 25),
					Image = "",
					ZIndex = 15,
					Parent = label,
				}, {
					utility.create("UICorner", {CornerRadius = UDim.new(1, 0)}),
				})
				local function sync()
					avatar.ImageTransparency = label.TextTransparency
					avatar.BackgroundTransparency = label.TextTransparency
				end
				label:GetPropertyChangedSignal("TextTransparency"):Connect(sync)
				sync()
				return avatar
			end

			local valueIcon = avatarFor(valueLabel, 18)

			local function getPicked()
				local list = {}
				for _, option in options do
					if picked[option] then
						table.insert(list, option)
					end
				end
				return list
			end

			local function pickedText()
				local list = getPicked()
				if #list == 0 then
					return config.placeholder or "none"
				elseif #list == 1 then
					return labelOf(list[1], true)
				elseif #list == 2 then
					return labelOf(list[1], true) .. ", " .. labelOf(list[2], true)
				end
				return #list .. " selected"
			end

			if multi then
				valueLabel.Text = pickedText()
			end

			local searchBox, searchDivider
			if searchable then
				local searchHolder = utility.create("Frame", {
					Name = "searchBox",
					LayoutOrder = -1,
					BackgroundColor3 = Color3.fromRGB(20, 20, 20),
					BackgroundTransparency = 1,
					Size = UDim2.new(1, -10, 0, 28),
					ZIndex = 14,
					Parent = optionsFrame.list,
				}, {
					utility.create("UICorner", {CornerRadius = UDim.new(0, 5)}),
					utility.create("UIStroke", {Name = "UIStroke", Color = Color3.fromRGB(25, 25, 25), Thickness = 1, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual}),
					utility.create("ImageLabel", {
						Name = "icon",
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 9, 0.5, 0),
						Size = UDim2.fromOffset(12, 12),
						Image = "rbxassetid://10734943674",
						ImageColor3 = Color3.fromRGB(100, 100, 100),
						ImageTransparency = 1,
						ZIndex = 15,
					}),
					utility.create("TextBox", {
						Name = "box",
						BackgroundTransparency = 1,
						Position = UDim2.fromOffset(28, 0),
						Size = UDim2.new(1, -36, 1, 0),
						Text = "",
						PlaceholderText = config.searchPlaceholder or "search...",
						PlaceholderColor3 = Color3.fromRGB(90, 90, 90),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextTransparency = 1,
						TextSize = 13,
						TextXAlignment = Enum.TextXAlignment.Left,
						ClearTextOnFocus = false,
						FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
						ZIndex = 15,
					}),
				})
				searchBox = searchHolder.box
				searchDivider = utility.create("Frame", {
					Name = "searchDivider",
					LayoutOrder = 0,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, -10, 0, 7),
					ZIndex = 14,
					Parent = optionsFrame.list,
				}, {
					utility.create("Frame", {
						Name = "line",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.new(1, 0, 0, 1),
						BorderSizePixel = 0,
						BackgroundColor3 = Color3.fromRGB(35, 35, 35),
						BackgroundTransparency = 1,
						ZIndex = 14,
					}),
				})
			end

			local suppressToggle = false
			if searchBox then
				for _, target in {searchBox.Parent, searchBox} do
					target.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							suppressToggle = true
						end
					end)
				end
			end

			local chevron = optionsFrame.chevron

			local baseHeight = 50
			local lastOptions = {}

			if description then
				utility.create("TextLabel", {
					Name = "description",
					Parent = dropdownFrame,

					Position = UDim2.new(0, 15, 0, 28),
					Size = UDim2.new(1, -15, 0, 12),
					BackgroundTransparency = 1,

					Text = description,
					TextColor3 = Color3.fromRGB(100, 100, 100),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextSize = 14,
					TextScaled = true,

					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular),
				})
			end

			local optionButtons = {}
			local animToken = 0
			local valueToken = 0
			local quint = Enum.EasingStyle.Quart
			local sine = Enum.EasingStyle.Quart
			local out = Enum.EasingDirection.Out
			local accent = library.theme.accent
			local valueBase = UDim2.new(0, 10, 0, (description and 13 or 8))
			valueIcon.Image = headIcon()
			valueIcon.Visible = valueIcon.Image ~= ""
			valueBase = UDim2.new(0, valueIcon.Visible and 34 or 10, 0, (description and 13 or 8))
			valueLabel.Position = valueBase

			local function currentChoice()
				if selected ~= "" then
					return selected
				end
				return default
			end

			local function optionLabelX(button)
				local x = button:GetAttribute("selected") and 42 or 36
				if button:GetAttribute("hovered") then
					x += 3
				end
				return x
			end

			local function paintOption(button, time)
				time = time or 0.35
				utility.tween(button.label, time, {Position = UDim2.new(0, optionLabelX(button), 0, 9)}, quint, out)
				utility.tween(button.bar, time, {Size = UDim2.new(0, 2, 0, button:GetAttribute("selected") and 12 or 0)}, quint, out)
			end

			local function setShadow(button, value, time)
				local shadow = button:FindFirstChild("UIShadow")
				if not shadow then return end
				pcall(function()
					if time then
						utility.tween(shadow, time, {Transparency = value}, sine, out)
					else
						shadow.Transparency = value
					end
				end)
			end

			local function setValue(text)
				valueToken += 1
				local token = valueToken
				utility.tween(valueLabel, 0.15, {TextTransparency = 1, Position = valueBase - UDim2.fromOffset(0, 6)}, sine, Enum.EasingDirection.In)
				task.delay(0.12, function()
					if token ~= valueToken then return end
					valueLabel.Text = text
					valueIcon.Image = headIcon()
					valueIcon.Visible = valueIcon.Image ~= ""
					valueBase = UDim2.new(0, valueIcon.Visible and 34 or 10, 0, (description and 13 or 8))
					valueLabel.Position = valueBase + UDim2.fromOffset(0, 6)
					utility.tween(valueLabel, 0.4, {TextTransparency = 0, Position = valueBase}, quint, out)
				end)
			end

			local function hideOptionInstantly(button)
				button.BackgroundTransparency = 1
				button.UIStroke.Transparency = 1
				button.bar.BackgroundTransparency = 1
				button.label.TextTransparency = 1
				button.label.Position = UDim2.new(0, optionLabelX(button) - 6, 0, 9)
				setShadow(button, 1)
			end

			local function fadeSearch(visible, staggered, token)
				if not searchBox then return end
				local holder = searchBox.Parent
				local function apply(time)
					local goal = visible and 0 or 1
					utility.tween(holder, time, {BackgroundTransparency = goal}, sine, out)
					utility.tween(holder.UIStroke, time, {Transparency = goal}, sine, out)
					utility.tween(holder.icon, time, {ImageTransparency = goal, Position = UDim2.new(0, visible and 9 or 3, 0.5, 0)}, quint, out)
					utility.tween(searchBox, time, {TextTransparency = goal, Position = UDim2.fromOffset(visible and 28 or 22, 0)}, quint, out)
					utility.tween(searchDivider.line, time, {BackgroundTransparency = goal}, sine, out)
				end
				if visible and staggered then
					holder.BackgroundTransparency = 1
					holder.UIStroke.Transparency = 1
					holder.icon.ImageTransparency = 1
					holder.icon.Position = UDim2.new(0, 3, 0.5, 0)
					searchBox.TextTransparency = 1
					searchBox.Position = UDim2.fromOffset(22, 0)
					searchDivider.line.BackgroundTransparency = 1
					task.delay(0.08, function()
						if token ~= animToken then return end
						apply(0.4)
					end)
				else
					apply(visible and 0.3 or 0.15)
				end
			end

			local function setOptionsVisible(visible, staggered)
				animToken += 1
				local token = animToken
				fadeSearch(visible, staggered, token)
				local searchOffset = searchBox and 0.05 or 0
				for index, button in optionButtons do
					local function apply(time)
						local goal = visible and 0 or 1
						utility.tween(button, time, {BackgroundTransparency = goal}, sine, out)
						utility.tween(button.UIStroke, time, {Transparency = goal}, sine, out)
						utility.tween(button.bar, time, {BackgroundTransparency = goal}, sine, out)
						utility.tween(button.label, time, {
							TextTransparency = goal,
							Position = UDim2.new(0, optionLabelX(button) - (visible and 0 or 6), 0, 9),
						}, quint, out)
						setShadow(button, visible and 0.65 or 1, time)
					end
					if visible and staggered then
						hideOptionInstantly(button)
						task.delay(0.08 + searchOffset + (index - 1) * 0.05, function()
							if token ~= animToken then return end
							apply(0.4)
						end)
					else
						apply(visible and 0.3 or 0.15)
					end
				end
			end

			local update

			local function closeAfterPick()
				task.delay(0.12, function()
					if expanded then
						expanded = false
						update(true)
					end
				end)
			end

			update = function(animate)
				local listHeight = listFrame.UIListLayout.AbsoluteContentSize.Y + 10
				local totalHeight = listHeight - (description and 0 or -10)

				local stacked = dropdownFrame:GetAttribute("stacked")
				utility.tween(optionsFrame, 0.5, {
					Size = stacked and UDim2.new(1, -16, 0, (description and 54 or 44) + (expanded and totalHeight or -15)) or UDim2.new(0, 190, 1, expanded and totalHeight or -15)
				}, quint, out)

				utility.tween(listFrame, 0.5, {
					Size = expanded and UDim2.new(1, -10, 0, listHeight) or UDim2.new(1, -10, 0, 0)
				}, quint, out)

				utility.tween(chevron, 0.5, {
					Rotation = expanded and -180 or 0
				}, quint, out)

				utility.tween(optionsFrame.UIStroke, 0.3, {
					Transparency = expanded and 0 or 1
				}, sine, out)

				utility.tween(optionsFrame, 0.4, {
					BackgroundColor3 = expanded and Color3.fromRGB(15, 15, 15) or Color3.fromRGB(20, 20, 20)
				}, sine, out)

				if expanded then
					dropdownFrame.ZIndex = 999
				else
					if dropdownFrame.ZIndex > 500 then
						dropdownFrame.ZIndex = 500
					end
					task.delay(0.5, function()
						if not expanded then
							dropdownFrame.ZIndex = 15
						end
					end)
				end

				if animate then
					setOptionsVisible(expanded, expanded)
				end

				local function optionsChanged()
					if #lastOptions ~= #options then
						return true
					end
					for i, v in ipairs(options) do
						if lastOptions[i] ~= v then
							return true
						end
					end
					return false
				end

				if not optionsChanged() then return end

				for _, child in pairs(listFrame:GetChildren()) do
					if child:IsA("Frame") and child.Name ~= "searchBox" and child.Name ~= "searchDivider" then
						child:Destroy()
					end
				end
				table.clear(optionButtons)

				lastOptions = table.clone(options)

				for index, option in ipairs(options) do
					local button = utility.create("Frame", {
						Name = "option",
						Active = true,
						Size = UDim2.new(1, -10, 0, 30),
						ZIndex = 1,
						BackgroundColor3 = Color3.fromRGB(20, 20, 20),
						LayoutOrder = index,
						Parent = listFrame,
					}, {
						utility.create("UICorner", {
							CornerRadius = UDim.new(0, 5),
						}),
						utility.create("UIStroke", {
							Enabled = true,
							Color = Color3.fromRGB(25, 25, 25),
							ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
							LineJoinMode = Enum.LineJoinMode.Round,
							Name = "UIStroke",
							Thickness = 1,
							ZIndex = 1,
							Transparency = 0,
							StrokeSizingMode = Enum.StrokeSizingMode.FixedSize,
						}),
						utility.create("Frame", {
							Name = "bar",
							BackgroundColor3 = accent,
							BorderSizePixel = 0,
							AnchorPoint = Vector2.new(0, 0.5),
							Position = UDim2.new(0, 7, 0.5, 0),
							Size = UDim2.new(0, 2, 0, 0),
							ZIndex = 16,
						}, {
							utility.create("UICorner", {
								CornerRadius = UDim.new(1, 0),
							}),
						}),
						utility.create("TextLabel", {
							Visible = true,
							TextColor3 = Color3.fromRGB(255, 255, 255),
							Text = labelOf(option),
							RichText = true,
							AnchorPoint = Vector2.new(0, 0),
							Name = "label",
							BackgroundTransparency = 1,
							Position = UDim2.new(0, 10, 0, 9),
							BackgroundColor3 = Color3.fromRGB(255, 255, 255),
							ZIndex = 15,
							TextSize = 14,
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,
							FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
							Size = UDim2.new(0, 130, 0, 12),
						}),
						utility.create("UIShadow", {
							Offset = UDim2.new(0, 0, 0, 0),
							Transparency = .65,
							Name = "UIShadow",
							BlurRadius = UDim.new(0, 15),
							Color = Color3.fromRGB(0, 0, 0),
							ZIndex = 1,
							Spread = UDim2.new(0, 0, 0, 0),
							Enabled = true,
						})
					})

					button:SetAttribute("option", option)
					avatarFor(button.label, 20).Image = imageOf(option)
					button:SetAttribute("selected", if multi then picked[option] == true else option == currentChoice())
					button.bar.Size = UDim2.new(0, 2, 0, button:GetAttribute("selected") and 12 or 0)
					button.label.Position = UDim2.new(0, optionLabelX(button), 0, 9)
					table.insert(optionButtons, button)

					if not expanded then
						hideOptionInstantly(button)
					end

					button.MouseEnter:Connect(function()
						button:SetAttribute("hovered", true)
						paintOption(button, 0.3)
					end)

					button.MouseLeave:Connect(function()
						button:SetAttribute("hovered", nil)
						paintOption(button, 0.35)
					end)

					button.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							if not expanded then return end
							suppressToggle = true
							if multi then
								picked[option] = not picked[option] or nil
								button:SetAttribute("selected", picked[option] == true)
								paintOption(button, 0.4)
								setValue(pickedText())
								callback(getPicked())
								return
							end
							selected = option
							for _, other in optionButtons do
								other:SetAttribute("selected", other == button)
								paintOption(other, 0.4)
							end
							setValue(labelOf(option, true))
							callback(selected)
							closeAfterPick()
						end
					end)
				end
			end

			local fullOptionSize = UDim2.new(1, -10, 0, 30)

			local function bump(button)
				local token = (button:GetAttribute("filterToken") or 0) + 1
				button:SetAttribute("filterToken", token)
				return token
			end

			local function popIn(button, delayTime)
				local token = bump(button)
				hideOptionInstantly(button)
				button.Size = UDim2.new(1, -10, 0, 0)
				button.Visible = true
				utility.tween(button, 0.35, {Size = fullOptionSize}, quint, out)
				task.delay(delayTime, function()
					if button:GetAttribute("filterToken") ~= token or not expanded then return end
					utility.tween(button, 0.35, {BackgroundTransparency = 0}, sine, out)
					utility.tween(button.UIStroke, 0.35, {Transparency = 0}, sine, out)
					utility.tween(button.bar, 0.35, {BackgroundTransparency = 0}, sine, out)
					utility.tween(button.label, 0.4, {
						TextTransparency = 0,
						Position = UDim2.new(0, optionLabelX(button), 0, 9),
					}, quint, out)
					setShadow(button, 0.65, 0.35)
				end)
			end

			local function popOut(button)
				local token = bump(button)
				utility.tween(button, 0.15, {BackgroundTransparency = 1}, sine, out)
				utility.tween(button.UIStroke, 0.15, {Transparency = 1}, sine, out)
				utility.tween(button.bar, 0.15, {BackgroundTransparency = 1}, sine, out)
				utility.tween(button.label, 0.2, {
					TextTransparency = 1,
					Position = UDim2.new(0, optionLabelX(button) - 6, 0, 9),
				}, quint, out)
				setShadow(button, 1, 0.15)
				utility.tween(button, 0.3, {Size = UDim2.new(1, -10, 0, 0)}, quint, out)
				task.delay(0.3, function()
					if button:GetAttribute("filterToken") ~= token then return end
					button.Visible = false
					button.Size = fullOptionSize
				end)
			end

			local function filter()
				if not searchBox then return end
				local query = string.lower(searchBox.Text)
				local shown = 0
				for _, button in optionButtons do
					local text = string.lower(findText(button:GetAttribute("option")))
					local match = query == "" or string.find(text, query, 1, true) ~= nil
					local showing = button:GetAttribute("filtered") ~= true
					if not expanded then
						bump(button)
						button:SetAttribute("filtered", not match or nil)
						button.Visible = match
						button.Size = fullOptionSize
					elseif match and not showing then
						button:SetAttribute("filtered", nil)
						popIn(button, 0.05 + shown * 0.04)
						shown += 1
					elseif not match and showing then
						button:SetAttribute("filtered", true)
						popOut(button)
					end
				end
			end

			if searchBox then
				searchBox:GetPropertyChangedSignal("Text"):Connect(filter)
			end

			local function toggleExpand()
				expanded = not expanded
				if expanded then
					if library.closePopup and library.popupOwner ~= dropdownFrame then
						library.closePopup()
					end
					library.popupOwner = dropdownFrame
					library.popupFrame = optionsFrame
					utility.openRoom(optionsFrame)
					library.closePopup = function()
						if expanded then
							toggleExpand()
						end
					end
				elseif library.popupOwner == dropdownFrame then
					library.popupOwner = nil
					library.popupFrame = nil
					utility.closeRoom()
					library.closePopup = nil
				end
				update(true)
				if searchBox then
					if expanded then
						task.delay(0.15, function()
							if expanded then
								searchBox:CaptureFocus()
							end
						end)
					else
						searchBox:ReleaseFocus()
						task.delay(0.4, function()
							if not expanded then
								searchBox.Text = ""
							end
						end)
					end
				end
			end

			local conn1,conn2

			conn1 = listFrame.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
				if expanded then
					update()
				end
			end)

			table.insert(library.connections, conn1)

			conn2 = optionsFrame.InputBegan:Connect(function(input)
				if not utility.isTop(optionsFrame, input.Position.X, input.Position.Y) then return end
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					task.defer(function()
						if suppressToggle then
							suppressToggle = false
							return
						end
						toggleExpand()
					end)
				end
			end)		

			table.insert(library.connections, conn2)

			update()

			return {
				frame = optionsFrame,
				setOptions = function(_, new)
					options = new
					update()
					filter()
				end,
				value = function()
					if multi then
						return getPicked()
					end
					return selected ~= "" and selected or default
				end,
				set = function(_, value, skipCallback)
					if multi then
						table.clear(picked)
						for _, option in (type(value) == "table" and value or {value}) do
							picked[option] = true
						end
						for _, button in optionButtons do
							button:SetAttribute("selected", picked[button:GetAttribute("option")] == true)
							paintOption(button, 0.4)
						end
						setValue(pickedText())
						if not skipCallback then callback(getPicked()) end
					else
						selected = value
						for _, button in optionButtons do
							button:SetAttribute("selected", button:GetAttribute("option") == value)
							paintOption(button, 0.4)
						end
						setValue(labelOf(value, true))
						if not skipCallback then callback(selected) end
					end
				end,
			}
		end

		function tab:createPlayerPicker(config)
			config = config or {}
			local show = config.show or "both"
			local kind = config.type or "dropdown"
			local multi = config.multi == true
			local includeSelf = config.includeSelf ~= false
			local callback = config.callback or function() end
			local known = {}

			local function remember(target)
				local key = tostring(target.UserId)
				known[key] = {name = target.Name, display = target.DisplayName}
				return key
			end

			local function playerOf(key)
				if not key or key == "" then return nil end
				return players:GetPlayerByUserId(tonumber(key))
			end

			local function keyOf(value)
				if typeof(value) == "Instance" and value:IsA("Player") then
					return remember(value)
				end
				if type(value) == "string" then
					for _, target in players:GetPlayers() do
						if target.Name == value or target.DisplayName == value then
							return remember(target)
						end
					end
				end
				return nil
			end

			local function labelOf(key, short)
				local info = key and known[key]
				if not info then
					return config.placeholder or "none"
				end
				if show == "username" then
					return info.name
				elseif show == "display" then
					return info.display
				end
				if short then
					return info.display
				end
				return info.display .. '  <font color="#646464">@' .. info.name .. "</font>"
			end

			local function imageOf(key)
				if not key or key == "" or not known[key] then return "" end
				return "rbxthumb://type=AvatarHeadShot&id=" .. key .. "&w=48&h=48"
			end

			local function findText(key)
				local info = known[key]
				if not info then return "" end
				return info.name .. " " .. info.display
			end

			local cachedKeys
			local function keys()
				if cachedKeys then
					return table.clone(cachedKeys)
				end
				local list = {}
				for _, target in players:GetPlayers() do
					if includeSelf or target ~= player then
						table.insert(list, remember(target))
					end
				end
				table.sort(list, function(one, two)
					return string.lower(known[one].display) < string.lower(known[two].display)
				end)
				cachedKeys = list
				return table.clone(list)
			end

			local function toPlayers(value)
				if multi then
					local list = {}
					for _, key in value or {} do
						local target = playerOf(key)
						if target then
							table.insert(list, target)
						end
					end
					return list
				end
				return playerOf(value)
			end

			local function toKeys(value)
				if multi then
					local list = {}
					for _, item in (type(value) == "table" and value or {value}) do
						local key = keyOf(item)
						if key then
							table.insert(list, key)
						end
					end
					return list
				end
				return keyOf(value) or ""
			end

			local object
			local connections = {}

			if kind == "list" then
				local description = config.description
				local top = description and 54 or 44
				local searchable = config.search == true
				local rowHeight = show == "both" and 40 or 34
				local height = config.height or 210
				local selectedKey = multi and nil or (config.default and toKeys(config.default) or "")
				local picked = {}
				if multi then
					for _, key in toKeys(config.default or {}) do
						picked[key] = true
					end
				end
				local rows = {}
				local quart = Enum.EasingStyle.Quart
				local out = Enum.EasingDirection.Out
				local accent = library.theme.accent

				local frame = utility.create("Frame", {
					Name = "playerPicker",
					Size = UDim2.new(1, 0, 0, top + (searchable and 34 or 0) + height + 10),
					BackgroundColor3 = Color3.fromRGB(15, 15, 15),
					ZIndex = 10,
					Parent = tab.list,
				}, {
					utility.create("UICorner", {CornerRadius = UDim.new(0, 5)}),
				})

				utility.create("TextLabel", {
					Name = "title",
					Position = UDim2.new(0, 15, 0, 14),
					Size = UDim2.new(1, -110, 0, 13),
					BackgroundTransparency = 1,
					Text = config.title or "players",
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextScaled = true,
					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium),
					ZIndex = 10,
					Parent = frame,
				})

				if description then
					utility.create("TextLabel", {
						Name = "description",
						Position = UDim2.new(0, 15, 0, 28),
						Size = UDim2.new(1, -110, 0, 12),
						BackgroundTransparency = 1,
						Text = description,
						TextColor3 = Color3.fromRGB(100, 100, 100),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextScaled = true,
						FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular),
						ZIndex = 10,
						Parent = frame,
					})
				end

				local countLabel = utility.create("TextLabel", {
					Name = "count",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -12, 0, 14),
					Size = UDim2.new(0, 90, 0, 12),
					BackgroundTransparency = 1,
					Text = "",
					TextColor3 = Color3.fromRGB(100, 100, 100),
					TextXAlignment = Enum.TextXAlignment.Right,
					TextScaled = true,
					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular),
					ZIndex = 10,
					Parent = frame,
				})

				local searchBox
				if searchable then
					local holder = utility.create("Frame", {
						Name = "search",
						Position = UDim2.new(0, 10, 0, top),
						Size = UDim2.new(1, -20, 0, 28),
						BackgroundColor3 = Color3.fromRGB(20, 20, 20),
						ZIndex = 10,
						Parent = frame,
					}, {
						utility.create("UICorner", {CornerRadius = UDim.new(0, 5)}),
						utility.create("UIStroke", {Name = "UIStroke", Color = Color3.fromRGB(25, 25, 25), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}),
						utility.create("ImageLabel", {
							Name = "icon",
							BackgroundTransparency = 1,
							AnchorPoint = Vector2.new(0, 0.5),
							Position = UDim2.new(0, 9, 0.5, 0),
							Size = UDim2.fromOffset(12, 12),
							Image = "rbxassetid://10734943674",
							ImageColor3 = Color3.fromRGB(100, 100, 100),
							ZIndex = 11,
						}),
					})
					searchBox = utility.create("TextBox", {
						Name = "box",
						BackgroundTransparency = 1,
						Position = UDim2.fromOffset(28, 0),
						Size = UDim2.new(1, -36, 1, 0),
						Text = "",
						PlaceholderText = config.searchPlaceholder or "search players...",
						PlaceholderColor3 = Color3.fromRGB(90, 90, 90),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextSize = 13,
						TextXAlignment = Enum.TextXAlignment.Left,
						ClearTextOnFocus = false,
						FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular),
						ZIndex = 11,
						Parent = holder,
					})
					searchBox.Focused:Connect(function()
						utility.tween(holder.UIStroke, 0.3, {Color = Color3.fromRGB(30, 30, 30)}, quart, out)
					end)
					searchBox.FocusLost:Connect(function()
						utility.tween(holder.UIStroke, 0.3, {Color = Color3.fromRGB(25, 25, 25)}, quart, out)
					end)
				end

				local scroll = utility.create("ScrollingFrame", {
					Name = "players",
					Position = UDim2.new(0, 10, 0, top + (searchable and 34 or 0)),
					Size = UDim2.new(1, -20, 0, height),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ScrollBarThickness = 2,
					ScrollBarImageColor3 = Color3.fromRGB(40, 40, 40),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					CanvasSize = UDim2.new(),
					ScrollingDirection = Enum.ScrollingDirection.Y,
					ZIndex = 10,
					Parent = frame,
				}, {
					utility.create("UIListLayout", {Name = "UIListLayout", Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}),
					utility.create("UIPadding", {PaddingTop = UDim.new(0, 1), PaddingBottom = UDim.new(0, 1), PaddingLeft = UDim.new(0, 1), PaddingRight = UDim.new(0, 6)}),
				})

				local empty = utility.create("TextLabel", {
					Name = "empty",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0.5, 0, 0, top + (searchable and 34 or 0) + height / 2),
					Size = UDim2.new(1, -20, 0, 14),
					BackgroundTransparency = 1,
					Text = "nobody here",
					TextColor3 = Color3.fromRGB(100, 100, 100),
					TextTransparency = 1,
					TextSize = 13,
					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular),
					ZIndex = 10,
					Parent = frame,
				})

				local function isSelected(key)
					if multi then
						return picked[key] == true
					end
					return key == selectedKey
				end

				local function textX(row)
					local x = 46
					if isSelected(row.Name) then x += 6 end
					if row:GetAttribute("hovered") then x += 3 end
					return x
				end

				local function paint(row, time)
					time = time or 0.35
					local on = isSelected(row.Name)
					utility.tween(row.text, time, {Position = UDim2.new(0, textX(row), 0, 0)}, quart, out)
					utility.tween(row.avatar, time, {Position = UDim2.new(0, textX(row) - 34, 0.5, 0)}, quart, out)
					utility.tween(row.bar, time, {Size = UDim2.new(0, 2, 0, on and 16 or 0)}, quart, out)
					utility.tween(row, time, {BackgroundColor3 = on and Color3.fromRGB(25, 25, 25) or Color3.fromRGB(20, 20, 20)}, quart, out)
					utility.tween(row.UIStroke, time, {Color = on and Color3.fromRGB(30, 30, 30) or Color3.fromRGB(25, 25, 25)}, quart, out)
				end

				local function fade(row, visible, time)
					local goal = visible and 0 or 1
					utility.tween(row, time, {BackgroundTransparency = goal}, quart, out)
					utility.tween(row.UIStroke, time, {Transparency = goal}, quart, out)
					utility.tween(row.bar, time, {BackgroundTransparency = goal}, quart, out)
					utility.tween(row.avatar, time, {ImageTransparency = goal, BackgroundTransparency = goal}, quart, out)
					for _, label in row.text:GetChildren() do
						if label:IsA("TextLabel") then
							utility.tween(label, time, {TextTransparency = goal}, quart, out)
						end
					end
				end

				local function recount()
					local shown = 0
					for _, row in rows do
						if row:GetAttribute("filtered") ~= true and row:GetAttribute("leaving") ~= true then
							shown += 1
						end
					end
					local total = 0
					for _, row in rows do
						if row:GetAttribute("leaving") ~= true then total += 1 end
					end
					countLabel.Text = total == 1 and "1 player" or (total .. " players")
					utility.tween(empty, 0.3, {TextTransparency = shown == 0 and 0 or 1}, quart, out)
					empty.Text = total == 0 and "nobody here" or "no matches"
				end

				local function fire()
					if multi then
						local list = {}
						for _, key in keys() do
							if picked[key] then table.insert(list, key) end
						end
						callback(toPlayers(list))
					else
						callback(playerOf(selectedKey))
					end
				end

				local function makeRow(key, animate)
					local info = known[key]
					local row = utility.create("Frame", {
						Name = key,
						Active = true,
						Size = UDim2.new(1, 0, 0, rowHeight),
						BackgroundColor3 = Color3.fromRGB(20, 20, 20),
						ClipsDescendants = true,
						ZIndex = 10,
						Parent = scroll,
					}, {
						utility.create("UICorner", {CornerRadius = UDim.new(0, 5)}),
						utility.create("UIStroke", {Name = "UIStroke", Color = Color3.fromRGB(25, 25, 25), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}),
						utility.create("Frame", {
							Name = "bar",
							AnchorPoint = Vector2.new(0, 0.5),
							Position = UDim2.new(0, 6, 0.5, 0),
							Size = UDim2.new(0, 2, 0, 0),
							BackgroundColor3 = accent,
							BorderSizePixel = 0,
							ZIndex = 11,
						}, {
							utility.create("UICorner", {CornerRadius = UDim.new(1, 0)}),
						}),
						utility.create("ImageLabel", {
							Name = "avatar",
							AnchorPoint = Vector2.new(0, 0.5),
							Position = UDim2.new(0, 12, 0.5, 0),
							Size = UDim2.fromOffset(rowHeight - 12, rowHeight - 12),
							BackgroundColor3 = Color3.fromRGB(30, 30, 30),
							Image = imageOf(key),
							ZIndex = 11,
						}, {
							utility.create("UICorner", {CornerRadius = UDim.new(1, 0)}),
						}),
						utility.create("Frame", {
							Name = "text",
							BackgroundTransparency = 1,
							Position = UDim2.new(0, 46, 0, 0),
							Size = UDim2.new(1, -56, 1, 0),
							ZIndex = 11,
						}),
					})
					local function line(name, text, color, weight, y, size)
						utility.create("TextLabel", {
							Name = name,
							BackgroundTransparency = 1,
							AnchorPoint = Vector2.new(0, 0.5),
							Position = UDim2.new(0, 0, y, 0),
							Size = UDim2.new(1, 0, 0, size + 2),
							Text = text,
							TextColor3 = color,
							TextSize = size,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
							FontFace = Font.new("rbxasset://fonts/families/Roboto.json", weight),
							ZIndex = 11,
							Parent = row.text,
						})
					end
					if show == "both" then
						line("display", info.display, Color3.fromRGB(255, 255, 255), Enum.FontWeight.Medium, 0.33, 14)
						line("username", "@" .. info.name, Color3.fromRGB(100, 100, 100), Enum.FontWeight.Regular, 0.7, 12)
					elseif show == "username" then
						line("username", info.name, Color3.fromRGB(255, 255, 255), Enum.FontWeight.Medium, 0.5, 14)
					else
						line("display", info.display, Color3.fromRGB(255, 255, 255), Enum.FontWeight.Medium, 0.5, 14)
					end
					if key == tostring(player.UserId) then
						utility.create("TextLabel", {
							Name = "you",
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -10, 0.5, 0),
							Size = UDim2.fromOffset(30, 12),
							BackgroundTransparency = 1,
							Text = "you",
							TextColor3 = Color3.fromRGB(100, 100, 100),
							TextSize = 11,
							TextXAlignment = Enum.TextXAlignment.Right,
							FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular),
							ZIndex = 11,
							Parent = row.text,
						})
					end

					row.MouseEnter:Connect(function()
						row:SetAttribute("hovered", true)
						paint(row, 0.3)
					end)
					row.MouseLeave:Connect(function()
						row:SetAttribute("hovered", nil)
						paint(row, 0.35)
					end)
					row.InputBegan:Connect(function(input)
						if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
						if not utility.isTop(row, input.Position.X, input.Position.Y) then return end
						if multi then
							picked[key] = not picked[key] or nil
							paint(row, 0.4)
						else
							if selectedKey == key then return end
							selectedKey = key
							for _, other in rows do
								paint(other, 0.4)
							end
						end
						fire()
					end)

					rows[key] = row
					paint(row, 0)
					if animate then
						row.Size = UDim2.new(1, 0, 0, 0)
						fade(row, false, 0)
						utility.tween(row, 0.4, {Size = UDim2.new(1, 0, 0, rowHeight)}, quart, out)
						task.delay(0.1, function()
							if row.Parent and row:GetAttribute("leaving") ~= true then
								fade(row, true, 0.4)
							end
						end)
					end
					return row
				end

				local function order()
					for index, key in keys() do
						if rows[key] then
							rows[key].LayoutOrder = index
						end
					end
				end

				local function filter()
					local query = searchBox and string.lower(searchBox.Text) or ""
					for key, row in rows do
						if row:GetAttribute("leaving") ~= true then
							local match = query == "" or string.find(string.lower(findText(key)), query, 1, true) ~= nil
							local showing = row:GetAttribute("filtered") ~= true
							if match and not showing then
								row:SetAttribute("filtered", nil)
								row.Visible = true
								utility.tween(row, 0.35, {Size = UDim2.new(1, 0, 0, rowHeight)}, quart, out)
								fade(row, true, 0.35)
							elseif not match and showing then
								row:SetAttribute("filtered", true)
								fade(row, false, 0.15)
								utility.tween(row, 0.3, {Size = UDim2.new(1, 0, 0, 0)}, quart, out)
								task.delay(0.3, function()
									if row:GetAttribute("filtered") then
										row.Visible = false
									end
								end)
							end
						end
					end
					recount()
				end

				if searchBox then
					searchBox:GetPropertyChangedSignal("Text"):Connect(filter)
				end

				local function sync(animate)
					local live = {}
					for _, key in keys() do
						live[key] = true
						if not rows[key] then
							makeRow(key, animate)
						end
					end
					for key, row in rows do
						if not live[key] and row:GetAttribute("leaving") ~= true then
							row:SetAttribute("leaving", true)
							fade(row, false, 0.2)
							utility.tween(row, 0.35, {Size = UDim2.new(1, 0, 0, 0)}, quart, out)
							task.delay(0.35, function()
								if rows[key] == row then
									rows[key] = nil
								end
								row:Destroy()
								recount()
							end)
							local changed = false
							if multi and picked[key] then
								picked[key] = nil
								changed = true
							elseif not multi and selectedKey == key then
								selectedKey = ""
								changed = true
							end
							if changed then fire() end
						end
					end
					order()
					filter()
				end

				sync(false)

				object = {
					frame = frame,
					value = function()
						if multi then
							local list = {}
							for _, key in keys() do
								if picked[key] then table.insert(list, key) end
							end
							return toPlayers(list)
						end
						return playerOf(selectedKey)
					end,
					set = function(_, value, skip)
						if multi then
							table.clear(picked)
							for _, key in toKeys(value) do
								picked[key] = true
							end
						else
							selectedKey = toKeys(value)
						end
						for _, row in rows do
							paint(row, 0.4)
						end
						if not skip then fire() end
					end,
					refresh = function()
						sync(true)
					end,
				}

				table.insert(connections, players.PlayerAdded:Connect(function()
					task.defer(function()
						cachedKeys = nil
						sync(true)
					end)
				end))
				table.insert(connections, players.PlayerRemoving:Connect(function(leaving)
					remember(leaving)
					task.defer(function()
						if leaving.Parent then
							task.wait()
						end
						cachedKeys = nil
						sync(true)
					end)
				end))
			else
				local dropdownConfig = table.clone(config)
				dropdownConfig.options = keys()
				dropdownConfig.default = config.default and toKeys(config.default) or nil
				dropdownConfig.callback = function(value)
					callback(toPlayers(value))
				end
				local dropdown = pickerDropdown(dropdownConfig, labelOf, imageOf, findText)
				if not multi and dropdownConfig.default and dropdownConfig.default ~= "" then
					dropdown:set(dropdownConfig.default, true)
				end
				local function refresh()
					local current = dropdown.value()
					dropdown:setOptions(keys())
					if multi then
						local stillHere = {}
						local lost = false
						for _, key in current or {} do
							if playerOf(key) then
								table.insert(stillHere, key)
							else
								lost = true
							end
						end
						if lost then dropdown:set(stillHere) end
					elseif current and current ~= "" and not playerOf(current) then
						dropdown:set("")
					end
				end
				object = {
					frame = dropdown.frame,
					value = function()
						return toPlayers(dropdown.value())
					end,
					set = function(_, value, skip)
						dropdown:set(toKeys(value), skip)
					end,
					refresh = refresh,
				}
				table.insert(connections, players.PlayerAdded:Connect(function()
					task.defer(function()
						cachedKeys = nil
						refresh()
					end)
				end))
				table.insert(connections, players.PlayerRemoving:Connect(function(leaving)
					remember(leaving)
					task.defer(function()
						if leaving.Parent then
							task.wait()
						end
						cachedKeys = nil
						refresh()
					end)
				end))
			end

			for _, connection in connections do
				table.insert(library.connections, connection)
			end

			return object
		end


		--------------------------------------
		-- dropdown --------------------------
		--------------------------------------

		function tab:createDropdown(config)
			local title = config.title or "Dropdown"
			local description = config.description

			local options = config.options or {}
			local default = config.default
			local callback = config.callback or function() end

			local selected = ""
			local expanded = false
			local multi = config.multi == true
			local searchable = config.search == true
			local picked = {}
			if multi and type(default) == "table" then
				for _, value in default do
					picked[value] = true
				end
			end

			local dropdownFrame = utility.create("Frame", {
				AnchorPoint = Vector2.new(0, 0),
				BackgroundTransparency = 0,
				Name = "dropdown",
				Position = UDim2.new(0, 0, 0.3115122616291046, 0),
				Visible = true,
				ZIndex = 10,
				BackgroundColor3 = Color3.fromRGB(15, 15, 15),
				Size = UDim2.new(1, 0, 0, (description and 54 or 44)),
				Parent = tab.list,
			}, {
				utility.create("Frame", {
					AnchorPoint = Vector2.new(0, 0),
					BackgroundTransparency = 0,
					Name = "options",
					Position = UDim2.new(1, -198, 0, 7),
					Visible = true,
					ZIndex = 15,
					BackgroundColor3 = Color3.fromRGB(20, 20, 20),
					Size = UDim2.new(0, 190, 1, -15),
					ClipsDescendants = true,

				}, {
					utility.create("Frame", {
						AnchorPoint = Vector2.new(0, 0),
						BackgroundTransparency = 1,
						Name = "list",
						Position = UDim2.new(0, 5, 0, 50),
						Visible = true,
						ZIndex = 1,
						BackgroundColor3 = Color3.fromRGB(25, 25, 25),
						Size = UDim2.new(1, 50, 0, 50),
					}, {
						utility.create("UICorner", {
							Name = "UICorner",
							CornerRadius = UDim.new(0, 5),
						}),
						utility.create("UIListLayout", {
							Name = "UIListLayout",
							Padding = UDim.new(0, 5),
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
						utility.create("UIPadding", {
							PaddingTop = UDim.new(0, 5),
							Name = "UIPadding",
							PaddingBottom = UDim.new(0, 0),
							PaddingLeft = UDim.new(0, 0),
							PaddingRight = UDim.new(0, 0),
						}),

					}),
					utility.create("ImageLabel", {
						Visible = true,
						AnchorPoint = Vector2.new(0, 0),
						Image = "rbxassetid://10709791523",
						BackgroundTransparency = 1,
						Position = UDim2.new(1, -25, 0, (description and 12 or 7)),
						Name = "chevron",
						ZIndex = 15,
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						Size = UDim2.new(0, 15, 0, 15),
					}),
					utility.create("TextLabel", {
						Visible = true,
						TextColor3 = Color3.fromRGB(255, 255, 255),
						Text = (type(default) == "string" and default) or "N/A",
						AnchorPoint = Vector2.new(0, 0),
						Name = "value",
						BackgroundTransparency = 1,
						Position = UDim2.new(0, 10, 0, (description and 13 or 8)),
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						ZIndex = 15,
						TextSize = 14,
						Size = UDim2.new(0, 145, 0, 13),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextScaled = true,

						FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium),
					}),
					utility.create("UIStroke", {
						Name = "UIStroke",
						Color = Color3.fromRGB(20, 20, 20),
						Thickness = 1,
						ZIndex = 1,
					}),
					utility.create("UICorner", {
						Name = "UICorner",
						CornerRadius = UDim.new(0, 5),
					}),
					utility.create("Frame", {
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						Name = "divider",
						Position = UDim2.new(0.5, 0, 0, 40),
						Visible = true,
						ZIndex = 5,
						BackgroundColor3 = Color3.fromRGB(20, 20, 20),
						Size = UDim2.new(1, 0, 0, 11),
					}, {
						utility.create("Frame", {
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 0,
							Name = "Frame",
							Position = UDim2.new(0.5, 0, 0.5, 0),
							Visible = true,
							ZIndex = 5,
							BackgroundColor3 = Color3.fromRGB(20, 20, 20),
							Size = UDim2.new(1, 0, 0, 1),
						})
					}),
					utility.create("UIShadow", {
						Offset = UDim2.new(0, 0, 0, 0),
						Transparency = .5,
						Name = "UIShadow",
						BlurRadius = UDim.new(0, 15),
						Color = Color3.fromRGB(0, 0, 0),
						ZIndex = 1,
						Spread = UDim2.new(0, 0, 0, 0),
						Enabled = true,
					})
				}),

				utility.create("TextLabel", {
					Visible = true,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					Text = "Dropdown",
					AnchorPoint = Vector2.new(0, 0),
					Name = "title",
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 15, 0, 14),
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					ZIndex = 10,
					TextSize = 14,
					Size = UDim2.new(0.88416987657547, -15, 0, 13),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextScaled = true,

					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium),
				}),
				utility.create("UICorner", {
					Name = "UICorner",
					CornerRadius = UDim.new(0, 5),
				})
			})

			local optionsFrame = dropdownFrame.options
			optionsFrame.Active = true
			local listFrame = optionsFrame.list 

			local titleLabel = dropdownFrame.title
			titleLabel.Text = title
			local valueLabel = optionsFrame.value

			local function getPicked()
				local list = {}
				for _, option in options do
					if picked[option] then
						table.insert(list, option)
					end
				end
				return list
			end

			local function pickedText()
				local list = getPicked()
				if #list == 0 then
					return config.placeholder or "none"
				elseif #list <= 2 then
					return table.concat(list, ", ")
				end
				return #list .. " selected"
			end

			if multi then
				valueLabel.Text = pickedText()
			end

			local searchBox, searchDivider
			if searchable then
				local searchHolder = utility.create("Frame", {
					Name = "searchBox",
					LayoutOrder = -1,
					BackgroundColor3 = Color3.fromRGB(20, 20, 20),
					BackgroundTransparency = 1,
					Size = UDim2.new(1, -10, 0, 28),
					ZIndex = 14,
					Parent = optionsFrame.list,
				}, {
					utility.create("UICorner", {CornerRadius = UDim.new(0, 5)}),
					utility.create("UIStroke", {Name = "UIStroke", Color = Color3.fromRGB(25, 25, 25), Thickness = 1, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual}),
					utility.create("ImageLabel", {
						Name = "icon",
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 9, 0.5, 0),
						Size = UDim2.fromOffset(12, 12),
						Image = "rbxassetid://10734943674",
						ImageColor3 = Color3.fromRGB(100, 100, 100),
						ImageTransparency = 1,
						ZIndex = 15,
					}),
					utility.create("TextBox", {
						Name = "box",
						BackgroundTransparency = 1,
						Position = UDim2.fromOffset(28, 0),
						Size = UDim2.new(1, -36, 1, 0),
						Text = "",
						PlaceholderText = config.searchPlaceholder or "search...",
						PlaceholderColor3 = Color3.fromRGB(90, 90, 90),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextTransparency = 1,
						TextSize = 13,
						TextXAlignment = Enum.TextXAlignment.Left,
						ClearTextOnFocus = false,
						FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
						ZIndex = 15,
					}),
				})
				searchBox = searchHolder.box
				searchDivider = utility.create("Frame", {
					Name = "searchDivider",
					LayoutOrder = 0,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, -10, 0, 7),
					ZIndex = 14,
					Parent = optionsFrame.list,
				}, {
					utility.create("Frame", {
						Name = "line",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.new(1, 0, 0, 1),
						BorderSizePixel = 0,
						BackgroundColor3 = Color3.fromRGB(35, 35, 35),
						BackgroundTransparency = 1,
						ZIndex = 14,
					}),
				})
			end

			local suppressToggle = false
			if searchBox then
				for _, target in {searchBox.Parent, searchBox} do
					target.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							suppressToggle = true
						end
					end)
				end
			end

			local chevron = optionsFrame.chevron

			local baseHeight = 50
			local lastOptions = {}

			if description then
				utility.create("TextLabel", {
					Name = "description",
					Parent = dropdownFrame,

					Position = UDim2.new(0, 15, 0, 28),
					Size = UDim2.new(1, -15, 0, 12),
					BackgroundTransparency = 1,

					Text = description,
					TextColor3 = Color3.fromRGB(100, 100, 100),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextSize = 14,
					TextScaled = true,

					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular),
				})
			end

			local optionButtons = {}
			local animToken = 0
			local valueToken = 0
			local quint = Enum.EasingStyle.Quart
			local sine = Enum.EasingStyle.Quart
			local out = Enum.EasingDirection.Out
			local accent = library.theme.accent
			local valueBase = UDim2.new(0, 10, 0, (description and 13 or 8))

			local function currentChoice()
				if selected ~= "" then
					return selected
				end
				return default
			end

			local function optionLabelX(button)
				local x = button:GetAttribute("selected") and 16 or 10
				if button:GetAttribute("hovered") then
					x += 3
				end
				return x
			end

			local function paintOption(button, time)
				time = time or 0.35
				utility.tween(button.label, time, {Position = UDim2.new(0, optionLabelX(button), 0, 9)}, quint, out)
				utility.tween(button.bar, time, {Size = UDim2.new(0, 2, 0, button:GetAttribute("selected") and 12 or 0)}, quint, out)
			end

			local function setShadow(button, value, time)
				local shadow = button:FindFirstChild("UIShadow")
				if not shadow then return end
				pcall(function()
					if time then
						utility.tween(shadow, time, {Transparency = value}, sine, out)
					else
						shadow.Transparency = value
					end
				end)
			end

			local function setValue(text)
				valueToken += 1
				local token = valueToken
				utility.tween(valueLabel, 0.15, {TextTransparency = 1, Position = valueBase - UDim2.fromOffset(0, 6)}, sine, Enum.EasingDirection.In)
				task.delay(0.12, function()
					if token ~= valueToken then return end
					valueLabel.Text = text
					valueLabel.Position = valueBase + UDim2.fromOffset(0, 6)
					utility.tween(valueLabel, 0.4, {TextTransparency = 0, Position = valueBase}, quint, out)
				end)
			end

			local function hideOptionInstantly(button)
				button.BackgroundTransparency = 1
				button.UIStroke.Transparency = 1
				button.bar.BackgroundTransparency = 1
				button.label.TextTransparency = 1
				button.label.Position = UDim2.new(0, optionLabelX(button) - 6, 0, 9)
				setShadow(button, 1)
			end

			local function fadeSearch(visible, staggered, token)
				if not searchBox then return end
				local holder = searchBox.Parent
				local function apply(time)
					local goal = visible and 0 or 1
					utility.tween(holder, time, {BackgroundTransparency = goal}, sine, out)
					utility.tween(holder.UIStroke, time, {Transparency = goal}, sine, out)
					utility.tween(holder.icon, time, {ImageTransparency = goal, Position = UDim2.new(0, visible and 9 or 3, 0.5, 0)}, quint, out)
					utility.tween(searchBox, time, {TextTransparency = goal, Position = UDim2.fromOffset(visible and 28 or 22, 0)}, quint, out)
					utility.tween(searchDivider.line, time, {BackgroundTransparency = goal}, sine, out)
				end
				if visible and staggered then
					holder.BackgroundTransparency = 1
					holder.UIStroke.Transparency = 1
					holder.icon.ImageTransparency = 1
					holder.icon.Position = UDim2.new(0, 3, 0.5, 0)
					searchBox.TextTransparency = 1
					searchBox.Position = UDim2.fromOffset(22, 0)
					searchDivider.line.BackgroundTransparency = 1
					task.delay(0.08, function()
						if token ~= animToken then return end
						apply(0.4)
					end)
				else
					apply(visible and 0.3 or 0.15)
				end
			end

			local function setOptionsVisible(visible, staggered)
				animToken += 1
				local token = animToken
				fadeSearch(visible, staggered, token)
				local searchOffset = searchBox and 0.05 or 0
				for index, button in optionButtons do
					local function apply(time)
						local goal = visible and 0 or 1
						utility.tween(button, time, {BackgroundTransparency = goal}, sine, out)
						utility.tween(button.UIStroke, time, {Transparency = goal}, sine, out)
						utility.tween(button.bar, time, {BackgroundTransparency = goal}, sine, out)
						utility.tween(button.label, time, {
							TextTransparency = goal,
							Position = UDim2.new(0, optionLabelX(button) - (visible and 0 or 6), 0, 9),
						}, quint, out)
						setShadow(button, visible and 0.65 or 1, time)
					end
					if visible and staggered then
						hideOptionInstantly(button)
						task.delay(0.08 + searchOffset + (index - 1) * 0.05, function()
							if token ~= animToken then return end
							apply(0.4)
						end)
					else
						apply(visible and 0.3 or 0.15)
					end
				end
			end

			local update

			local function closeAfterPick()
				task.delay(0.12, function()
					if expanded then
						expanded = false
						update(true)
					end
				end)
			end

			update = function(animate)
				local listHeight = listFrame.UIListLayout.AbsoluteContentSize.Y + 10
				local totalHeight = listHeight - (description and 0 or -10)

				local stacked = dropdownFrame:GetAttribute("stacked")
				utility.tween(optionsFrame, 0.5, {
					Size = stacked and UDim2.new(1, -16, 0, (description and 54 or 44) + (expanded and totalHeight or -15)) or UDim2.new(0, 190, 1, expanded and totalHeight or -15)
				}, quint, out)

				utility.tween(listFrame, 0.5, {
					Size = expanded and UDim2.new(1, -10, 0, listHeight) or UDim2.new(1, -10, 0, 0)
				}, quint, out)

				utility.tween(chevron, 0.5, {
					Rotation = expanded and -180 or 0
				}, quint, out)

				utility.tween(optionsFrame.UIStroke, 0.3, {
					Transparency = expanded and 0 or 1
				}, sine, out)

				utility.tween(optionsFrame, 0.4, {
					BackgroundColor3 = expanded and Color3.fromRGB(15, 15, 15) or Color3.fromRGB(20, 20, 20)
				}, sine, out)

				if expanded then
					dropdownFrame.ZIndex = 999
				else
					if dropdownFrame.ZIndex > 500 then
						dropdownFrame.ZIndex = 500
					end
					task.delay(0.5, function()
						if not expanded then
							dropdownFrame.ZIndex = 15
						end
					end)
				end

				if animate then
					setOptionsVisible(expanded, expanded)
				end

				local function optionsChanged()
					if #lastOptions ~= #options then
						return true
					end
					for i, v in ipairs(options) do
						if lastOptions[i] ~= v then
							return true
						end
					end
					return false
				end

				if not optionsChanged() then return end

				for _, child in pairs(listFrame:GetChildren()) do
					if child:IsA("Frame") and child.Name ~= "searchBox" and child.Name ~= "searchDivider" then
						child:Destroy()
					end
				end
				table.clear(optionButtons)

				lastOptions = table.clone(options)

				for index, option in ipairs(options) do
					local button = utility.create("Frame", {
						Name = "option",
						Active = true,
						Size = UDim2.new(1, -10, 0, 30),
						ZIndex = 1,
						BackgroundColor3 = Color3.fromRGB(20, 20, 20),
						LayoutOrder = index,
						Parent = listFrame,
					}, {
						utility.create("UICorner", {
							CornerRadius = UDim.new(0, 5),
						}),
						utility.create("UIStroke", {
							Enabled = true,
							Color = Color3.fromRGB(25, 25, 25),
							ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
							LineJoinMode = Enum.LineJoinMode.Round,
							Name = "UIStroke",
							Thickness = 1,
							ZIndex = 1,
							Transparency = 0,
							StrokeSizingMode = Enum.StrokeSizingMode.FixedSize,
						}),
						utility.create("Frame", {
							Name = "bar",
							BackgroundColor3 = accent,
							BorderSizePixel = 0,
							AnchorPoint = Vector2.new(0, 0.5),
							Position = UDim2.new(0, 7, 0.5, 0),
							Size = UDim2.new(0, 2, 0, 0),
							ZIndex = 16,
						}, {
							utility.create("UICorner", {
								CornerRadius = UDim.new(1, 0),
							}),
						}),
						utility.create("TextLabel", {
							Visible = true,
							TextColor3 = Color3.fromRGB(255, 255, 255),
							Text = option or "N/A",
							AnchorPoint = Vector2.new(0, 0),
							Name = "label",
							BackgroundTransparency = 1,
							Position = UDim2.new(0, 10, 0, 9),
							BackgroundColor3 = Color3.fromRGB(255, 255, 255),
							ZIndex = 15,
							TextSize = 14,
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,
							FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
							Size = UDim2.new(0, 145, 0, 12),
						}),
						utility.create("UIShadow", {
							Offset = UDim2.new(0, 0, 0, 0),
							Transparency = .65,
							Name = "UIShadow",
							BlurRadius = UDim.new(0, 15),
							Color = Color3.fromRGB(0, 0, 0),
							ZIndex = 1,
							Spread = UDim2.new(0, 0, 0, 0),
							Enabled = true,
						})
					})

					button:SetAttribute("option", option)
					button:SetAttribute("selected", if multi then picked[option] == true else option == currentChoice())
					button.bar.Size = UDim2.new(0, 2, 0, button:GetAttribute("selected") and 12 or 0)
					button.label.Position = UDim2.new(0, optionLabelX(button), 0, 9)
					table.insert(optionButtons, button)

					if not expanded then
						hideOptionInstantly(button)
					end

					button.MouseEnter:Connect(function()
						button:SetAttribute("hovered", true)
						paintOption(button, 0.3)
					end)

					button.MouseLeave:Connect(function()
						button:SetAttribute("hovered", nil)
						paintOption(button, 0.35)
					end)

					button.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							if not expanded then return end
							suppressToggle = true
							if multi then
								picked[option] = not picked[option] or nil
								button:SetAttribute("selected", picked[option] == true)
								paintOption(button, 0.4)
								setValue(pickedText())
								callback(getPicked())
								return
							end
							selected = option
							for _, other in optionButtons do
								other:SetAttribute("selected", other == button)
								paintOption(other, 0.4)
							end
							setValue(option)
							callback(selected)
							closeAfterPick()
						end
					end)
				end
			end

			local fullOptionSize = UDim2.new(1, -10, 0, 30)

			local function bump(button)
				local token = (button:GetAttribute("filterToken") or 0) + 1
				button:SetAttribute("filterToken", token)
				return token
			end

			local function popIn(button, delayTime)
				local token = bump(button)
				hideOptionInstantly(button)
				button.Size = UDim2.new(1, -10, 0, 0)
				button.Visible = true
				utility.tween(button, 0.35, {Size = fullOptionSize}, quint, out)
				task.delay(delayTime, function()
					if button:GetAttribute("filterToken") ~= token or not expanded then return end
					utility.tween(button, 0.35, {BackgroundTransparency = 0}, sine, out)
					utility.tween(button.UIStroke, 0.35, {Transparency = 0}, sine, out)
					utility.tween(button.bar, 0.35, {BackgroundTransparency = 0}, sine, out)
					utility.tween(button.label, 0.4, {
						TextTransparency = 0,
						Position = UDim2.new(0, optionLabelX(button), 0, 9),
					}, quint, out)
					setShadow(button, 0.65, 0.35)
				end)
			end

			local function popOut(button)
				local token = bump(button)
				utility.tween(button, 0.15, {BackgroundTransparency = 1}, sine, out)
				utility.tween(button.UIStroke, 0.15, {Transparency = 1}, sine, out)
				utility.tween(button.bar, 0.15, {BackgroundTransparency = 1}, sine, out)
				utility.tween(button.label, 0.2, {
					TextTransparency = 1,
					Position = UDim2.new(0, optionLabelX(button) - 6, 0, 9),
				}, quint, out)
				setShadow(button, 1, 0.15)
				utility.tween(button, 0.3, {Size = UDim2.new(1, -10, 0, 0)}, quint, out)
				task.delay(0.3, function()
					if button:GetAttribute("filterToken") ~= token then return end
					button.Visible = false
					button.Size = fullOptionSize
				end)
			end

			local function filter()
				if not searchBox then return end
				local query = string.lower(searchBox.Text)
				local shown = 0
				for _, button in optionButtons do
					local text = string.lower(tostring(button:GetAttribute("option")))
					local match = query == "" or string.find(text, query, 1, true) ~= nil
					local showing = button:GetAttribute("filtered") ~= true
					if not expanded then
						bump(button)
						button:SetAttribute("filtered", not match or nil)
						button.Visible = match
						button.Size = fullOptionSize
					elseif match and not showing then
						button:SetAttribute("filtered", nil)
						popIn(button, 0.05 + shown * 0.04)
						shown += 1
					elseif not match and showing then
						button:SetAttribute("filtered", true)
						popOut(button)
					end
				end
			end

			if searchBox then
				searchBox:GetPropertyChangedSignal("Text"):Connect(filter)
			end

			local function toggleExpand()
				expanded = not expanded
				if expanded then
					if library.closePopup and library.popupOwner ~= dropdownFrame then
						library.closePopup()
					end
					library.popupOwner = dropdownFrame
					library.popupFrame = optionsFrame
					utility.openRoom(optionsFrame)
					library.closePopup = function()
						if expanded then
							toggleExpand()
						end
					end
				elseif library.popupOwner == dropdownFrame then
					library.popupOwner = nil
					library.popupFrame = nil
					utility.closeRoom()
					library.closePopup = nil
				end
				update(true)
				if searchBox then
					if expanded then
						task.delay(0.15, function()
							if expanded then
								searchBox:CaptureFocus()
							end
						end)
					else
						searchBox:ReleaseFocus()
						task.delay(0.4, function()
							if not expanded then
								searchBox.Text = ""
							end
						end)
					end
				end
			end

			local conn1,conn2

			conn1 = listFrame.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
				if expanded then
					update()
				end
			end)

			table.insert(library.connections, conn1)

			conn2 = optionsFrame.InputBegan:Connect(function(input)
				if not utility.isTop(optionsFrame, input.Position.X, input.Position.Y) then return end
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					task.defer(function()
						if suppressToggle then
							suppressToggle = false
							return
						end
						toggleExpand()
					end)
				end
			end)		

			table.insert(library.connections, conn2)

			update()

			return {
				frame = optionsFrame,
				setOptions = function(_, new)
					options = new
					update()
					filter()
				end,
				value = function()
					if multi then
						return getPicked()
					end
					return selected ~= "" and selected or default
				end,
				set = function(_, value, skipCallback)
					if multi then
						table.clear(picked)
						for _, option in (type(value) == "table" and value or {value}) do
							picked[option] = true
						end
						for _, button in optionButtons do
							button:SetAttribute("selected", picked[button:GetAttribute("option")] == true)
							paintOption(button, 0.4)
						end
						setValue(pickedText())
						if not skipCallback then callback(getPicked()) end
					else
						selected = value
						for _, button in optionButtons do
							button:SetAttribute("selected", button:GetAttribute("option") == value)
							paintOption(button, 0.4)
						end
						setValue(value)
						if not skipCallback then callback(selected) end
					end
				end,
			}
		end


		--------------------------------------
		-- toggle ----------------------------
		--------------------------------------

		function tab:createToggle(config)
			config = config or {}

			local title = config.title or "Toggle"
			local description = config.description
			local callback = config.callback or function() end
			local order = config.order or (#tab.list:GetChildren() + 1)

			local enabled = config.default or false

			local toggleFrame = utility.create("Frame", {
				Name = title,
				Parent = tab.list,

				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, (description and 54 or 44)),
				BackgroundColor3 = Color3.fromRGB(15, 15, 15),
			}, {
				utility.create("Frame", {
					Name = "toggleBg",

					Position = UDim2.new(1, -51, 0.5, -12),
					Size = UDim2.new(0, 44, 0, 24),

					BackgroundColor3 = enabled and library.theme.accent or Color3.fromRGB(25, 25, 25),
				}, {
					utility.create("Frame", {
						Name = "knob",

						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = enabled and UDim2.new(0.7, 0, 0.5, 0) or UDim2.new(0.3, 0, 0.5, 0),
						Size = UDim2.new(0, 18, 0, 18),

						BackgroundColor3 = enabled and utility.knob(library.theme.accent) or Color3.fromRGB(255, 255, 255),
					}, {
						utility.create("UICorner", {
							CornerRadius = UDim.new(1, 0)
						})
					}),

					utility.create("UICorner", {
						CornerRadius = UDim.new(1, 0)
					}),
					utility.create("UIShadow", {
						Offset = UDim2.new(0, 0, 0, 0),
						Transparency = .5,
						Name = "UIShadow",
						BlurRadius = UDim.new(0, 15),
						Color = Color3.fromRGB(0, 0, 0),
						ZIndex = 1,
						Spread = UDim2.new(0, 0, 0, 0),
						Enabled = true,
					})
				}),
				utility.create("UICorner", {
					CornerRadius = UDim.new(0, 5)
				})
			})

			local toggleBg = toggleFrame.toggleBg
			local knob = toggleBg.knob

			utility.create("TextLabel", {
				Name = "title",
				Parent = toggleFrame,

				Position = UDim2.new(0, 15, 0, 14),
				Size = UDim2.new(1, -15, 0, 13),
				BackgroundTransparency = 1,

				Text = title,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextSize = 14,
				TextScaled = true,

				FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium),
			})

			if description then
				utility.create("TextLabel", {
					Name = "description",
					Parent = toggleFrame,

					Position = UDim2.new(0, 15, 0, 28),
					Size = UDim2.new(1, -15, 0, 12),
					BackgroundTransparency = 1,

					Text = description,
					TextColor3 = Color3.fromRGB(100, 100, 100),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextSize = 14,
					TextScaled = true,

					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular),
				})
			end

			local function update(state, skip)
				enabled = state

				utility.tween(knob, 0.3, {
					Position = enabled and UDim2.new(0.7, 0, 0.5, 0) or UDim2.new(0.3, 0, 0.5, 0),
					BackgroundColor3 = enabled and utility.knob(library.theme.accent) or Color3.fromRGB(255, 255, 255),
				}, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

				utility.tween(toggleBg, 0.3, {
					BackgroundColor3 = enabled and library.theme.accent or Color3.fromRGB(25, 25, 25)
				})

				if not skip then
					callback(enabled)
				end
			end

			toggleBg.InputBegan:Connect(function(input)
				if not utility.isTop(toggleBg, input.Position.X, input.Position.Y) then return end
				if input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch then
					update(not enabled)
				end
			end)

			update(enabled, true)

			return {
				frame = toggleFrame,
				value = function()
					return enabled
				end,
				set = function(_, state, skip)
					update(state, skip)
				end,
				toggle = function(skip)
					update(not enabled, skip)
				end
			}
		end


		--------------------------------------
		-- slider ----------------------------
		--------------------------------------

		function tab:createSlider(config)
			config = config or {}

			local title = config.title or "Toggle"
			local description = config.description
			local callback = config.callback or function() end
			local min = config.min or 0
			local max = config.max or 100
			local increment = config.increment or 1
			local display = config.display or ""
			local marks = {}
			if type(config.marks) == "table" then
				for label, markValue in config.marks do
					if type(markValue) == "table" then
						table.insert(marks, {label = tostring(markValue.label or markValue[2]), value = markValue.value or markValue[1]})
					else
						table.insert(marks, {label = tostring(label), value = markValue})
					end
				end
				table.sort(marks, function(a, b)
					return a.value < b.value
				end)
			end
			local hasMarks = #marks > 0
			local decimals = 0
			do
				local text = tostring(increment)
				local dot = string.find(text, ".", 1, true)
				if dot then
					decimals = #text - dot
				end
			end

			local value = math.clamp(config.default or min, min, max)

			local sliderFrame = utility.create("Frame", {
				Name = title,
				Parent = tab.list,

				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(1, 0, 0, (description and 72 or 54) + (hasMarks and 18 or 0)),

				AnchorPoint = Vector2.new(0, 0),
				BackgroundColor3 = Color3.fromRGB(15, 15, 15),
				BackgroundTransparency = 0,

				ZIndex = 10,
			}, {
				utility.create("Frame", {
					Name = "sliderBg",

					Position = UDim2.new(0, 14, 1, hasMarks and -38 or -20),
					Size = UDim2.new(1, -28, 0, 8),

					BackgroundColor3 = Color3.fromRGB(25, 25, 25),

					ZIndex = 10,
				}, {
					utility.create("Frame", {
						Name = "fill",

						Size = UDim2.new(0, 0, 1, 0),

						BackgroundColor3 = library.theme.accent,

						ZIndex = 10,
					}, {
						utility.create("UICorner", {
							CornerRadius = UDim.new(1, 0)
						})
					}),
					utility.create("Frame", {
						Name = "knob",

						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(0, 0, 0.5, 0),
						Size = UDim2.new(0, 16, 0, 16),

						BackgroundColor3 = Color3.fromRGB(255, 255, 255),

						ZIndex = 10,
					}, {
						utility.create("UICorner", {
							CornerRadius = UDim.new(1, 0)
						})
					}),
					utility.create("UICorner", {
						CornerRadius = UDim.new(1, 0)
					}),
					utility.create("UIShadow", {
						Offset = UDim2.new(0, 0, 0, 0),
						Transparency = .5,
						Name = "UIShadow",
						BlurRadius = UDim.new(0, 15),
						Color = Color3.fromRGB(0, 0, 0),
						ZIndex = 1,
						Spread = UDim2.new(0, 0, 0, 0),
						Enabled = true,
					})
				}),
				utility.create("UICorner", {
					CornerRadius = UDim.new(0, 5)
				})
			})

			local sliderBg = sliderFrame.sliderBg
			local fill = sliderBg.fill
			local knob = sliderBg.knob
			local markLabels = {}

			local titleLabel = utility.create("TextLabel", {
				Name = "title",

				Position = UDim2.new(0, 15, 0, 14),
				Size = UDim2.new(1, -15, 0, 13),
				BackgroundTransparency = 1,

				Text = title,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextSize = 14,
				TextScaled = true,

				FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium),

				Parent = sliderFrame
			})

			local displayLabel = utility.create("TextLabel", {
				Name = "display",
				Parent = sliderFrame,

				Position = UDim2.new(1, -60, 0, 14),
				Size = UDim2.new(0, 50, 0, 12),
				BackgroundTransparency = 1,

				Text = value .. display,
				TextColor3 = Color3.fromRGB(100, 100, 100),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextSize = 14,
				TextScaled = true,

				FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular),
			})

			if description then
				utility.create("TextLabel", {
					Name = "description",
					Parent = sliderFrame,

					Position = UDim2.new(0, 15, 0, 28),
					Size = UDim2.new(1, -100, 0, 12),
					BackgroundTransparency = 1,

					Text = description,
					TextColor3 = Color3.fromRGB(100, 100, 100),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextSize = 14,
					TextScaled = true,

					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular),

				})
			end

			local shown = Instance.new("NumberValue")
			shown.Value = value
			local function format(number)
				if decimals == 0 then
					return tostring(math.floor(number + 0.5))
				end
				return string.format("%." .. decimals .. "f", number)
			end
			shown.Changed:Connect(function(number)
				displayLabel.Text = format(number) .. display
			end)

			local update
			local editing
			displayLabel.InputBegan:Connect(function(input)
				if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
				if editing then return end
				local spot = displayLabel.Position
				editing = utility.editBox({
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(spot.X.Scale, spot.X.Offset + displayLabel.Size.X.Offset + 4, spot.Y.Scale, spot.Y.Offset + displayLabel.Size.Y.Offset / 2),
					width = math.max(28, displayLabel.TextBounds.X + 16),
					Text = format(value),
					align = Enum.TextXAlignment.Right,
					Parent = sliderFrame,
				})
				displayLabel.Visible = false
				editing.FocusLost:Connect(function()
					local typed = tonumber((string.gsub(editing.Text, "[^%d%.%-]", "")))
					utility.dismissEdit(editing, displayLabel)
					editing = nil
					if typed then
						update(typed)
					end
				end)
				editing:CaptureFocus()
				editing.CursorPosition = #editing.Text + 1
			end)

			local dragging = false

			for _, mark in marks do
				local percent = math.clamp((mark.value - min) / (max - min), 0, 1)
				utility.create("Frame", {
					Name = "tick",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(percent, 0, 1, 4),
					Size = UDim2.fromOffset(1, 4),
					BorderSizePixel = 0,
					BackgroundColor3 = Color3.fromRGB(40, 40, 40),
					ZIndex = 10,
					Parent = sliderBg,
				})
				local anchorX = percent < 0.06 and 0 or percent > 0.94 and 1 or 0.5
				local label = utility.create("TextButton", {
					Name = "mark",
					AnchorPoint = Vector2.new(anchorX, 0),
					Position = UDim2.new(percent, 0, 1, 9),
					Size = UDim2.fromOffset(80, 12),
					BackgroundTransparency = 1,
					AutoButtonColor = false,
					Text = mark.label,
					TextColor3 = Color3.fromRGB(100, 100, 100),
					TextSize = 11,
					TextXAlignment = anchorX == 0 and Enum.TextXAlignment.Left or anchorX == 1 and Enum.TextXAlignment.Right or Enum.TextXAlignment.Center,
					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular),
					ZIndex = 10,
					Parent = sliderBg,
				})
				label.MouseButton1Click:Connect(function()
					update(mark.value)
				end)
				table.insert(markLabels, {label = label, value = mark.value})
			end

			update = function(newValue, skip)
				newValue = math.clamp(newValue, min, max)
				newValue = math.floor(newValue / increment + 0.5) * increment
				value = utility.roundUp(newValue, 2)

				local percent = (value - min) / (max - min)

				utility.tween(knob, 0.2, {
					Position = UDim2.new(percent, 0, 0.5, 0)
				}, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

				utility.tween(fill, 0.2, {
					Size = UDim2.new(percent, 0, 1, 0)
				}, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

				utility.tween(shown, 0.35, {Value = value}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
				for _, entry in markLabels do
					local active = math.abs(entry.value - value) < 1e-6
					utility.tween(entry.label, 0.25, {TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(100, 100, 100)}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
				end

				if not skip then
					callback(value)
				end
			end

			local function updateFromInput(x)
				local absPos = sliderBg.AbsolutePosition.X
				local absSize = sliderBg.AbsoluteSize.X
				local percent = math.clamp((x - absPos) / absSize, 0, 1)
				local raw = min + percent * (max - min)
				for _, mark in marks do
					if math.abs(raw - mark.value) <= (max - min) * 0.025 then
						raw = mark.value
						break
					end
				end
				update(raw)
			end

			sliderBg.InputBegan:Connect(function(input)
				if not utility.isTop(sliderBg, input.Position.X, input.Position.Y) then return end
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = true
					updateFromInput(input.Position.X)
					utility.capture(function(moved)
						updateFromInput(moved.Position.X)
					end, function()
						dragging = false
					end)
				end
			end)

			update(value, true)

			return {
				frame = sliderFrame,
				value = function()
					return value
				end,
				set = function(_, newValue, skip)
					update(newValue, skip)
				end,
			}
		end


		--------------------------------------
		-- range slider ----------------------
		--------------------------------------

		function tab:createRangeSlider(config)
			config = config or {}

			local title = config.title or "range"
			local description = config.description
			local callback = config.callback or function() end
			local min = config.min or 0
			local max = config.max or 100
			local increment = config.increment or 1
			local display = config.display or ""
			local gap = config.gap or 0
			local decimals = 0
			do
				local text = tostring(increment)
				local dot = string.find(text, ".", 1, true)
				if dot then
					decimals = #text - dot
				end
			end
			local default = type(config.default) == "table" and config.default or {min, max}
			local low = math.clamp(default[1] or min, min, max)
			local high = math.clamp(default[2] or max, low, max)

			local rangeFrame = utility.create("Frame", {
				Name = title,
				Parent = tab.list,
				Size = UDim2.new(1, 0, 0, description and 72 or 54),
				BackgroundColor3 = Color3.fromRGB(15, 15, 15),
				ZIndex = 10,
			}, {
				utility.create("UICorner", {CornerRadius = UDim.new(0, 5)}),
			})

			local track = utility.create("Frame", {
				Name = "sliderBg",
				Position = UDim2.new(0, 14, 1, -20),
				Size = UDim2.new(1, -28, 0, 8),
				BackgroundColor3 = Color3.fromRGB(25, 25, 25),
				ZIndex = 10,
				Parent = rangeFrame,
			}, {
				utility.create("UICorner", {CornerRadius = UDim.new(1, 0)}),
				utility.create("UIShadow", {
					Name = "UIShadow",
					Offset = UDim2.new(0, 0, 0, 0),
					Transparency = 0.5,
					BlurRadius = UDim.new(0, 15),
					Color = Color3.fromRGB(0, 0, 0),
					ZIndex = 1,
					Spread = UDim2.new(0, 0, 0, 0),
					Enabled = true,
				}),
			})

			local fill = utility.create("Frame", {
				Name = "fill",
				Size = UDim2.new(0, 0, 1, 0),
				BackgroundColor3 = library.theme.accent,
				ZIndex = 10,
				Parent = track,
			}, {
				utility.create("UICorner", {CornerRadius = UDim.new(1, 0)}),
			})

			local function makeKnob(name)
				return utility.create("Frame", {
					Name = name,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0, 0, 0.5, 0),
					Size = UDim2.fromOffset(16, 16),
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					ZIndex = 11,
					Parent = track,
				}, {
					utility.create("UICorner", {CornerRadius = UDim.new(1, 0)}),
				})
			end
			local lowKnob = makeKnob("lowKnob")
			local highKnob = makeKnob("highKnob")

			utility.create("TextLabel", {
				Name = "title",
				Position = UDim2.new(0, 15, 0, 14),
				Size = UDim2.new(1, -15, 0, 13),
				BackgroundTransparency = 1,
				Text = title,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextSize = 14,
				TextScaled = true,
				FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium),
				ZIndex = 10,
				Parent = rangeFrame,
			})

			local displayLabel = utility.create("TextLabel", {
				Name = "display",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -10, 0, 14),
				Size = UDim2.new(0, 160, 0, 12),
				BackgroundTransparency = 1,
				Text = "",
				TextColor3 = Color3.fromRGB(100, 100, 100),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextSize = 14,
				TextScaled = true,
				FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular),
				ZIndex = 10,
				Parent = rangeFrame,
			})

			if description then
				utility.create("TextLabel", {
					Name = "description",
					Position = UDim2.new(0, 15, 0, 28),
					Size = UDim2.new(1, -100, 0, 12),
					BackgroundTransparency = 1,
					Text = description,
					TextColor3 = Color3.fromRGB(100, 100, 100),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextSize = 14,
					TextScaled = true,
					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular),
					ZIndex = 10,
					Parent = rangeFrame,
				})
			end

			local function format(number)
				if decimals == 0 then
					return tostring(math.floor(number + 0.5))
				end
				return string.format("%." .. decimals .. "f", number)
			end

			local shownLow = Instance.new("NumberValue")
			local shownHigh = Instance.new("NumberValue")
			shownLow.Value = low
			shownHigh.Value = high
			local function redraw()
				displayLabel.Text = format(shownLow.Value) .. display .. "  –  " .. format(shownHigh.Value) .. display
			end
			shownLow.Changed:Connect(redraw)
			shownHigh.Changed:Connect(redraw)
			redraw()

			local function snap(number)
				number = math.clamp(number, min, max)
				return utility.roundUp(math.floor(number / increment + 0.5) * increment, 2)
			end

			local function place(time)
				local lowPercent = (low - min) / (max - min)
				local highPercent = (high - min) / (max - min)
				utility.tween(lowKnob, time, {Position = UDim2.new(lowPercent, 0, 0.5, 0)}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
				utility.tween(highKnob, time, {Position = UDim2.new(highPercent, 0, 0.5, 0)}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
				utility.tween(fill, time, {
					Position = UDim2.new(lowPercent, 0, 0, 0),
					Size = UDim2.new(highPercent - lowPercent, 0, 1, 0),
				}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
				utility.tween(shownLow, 0.35, {Value = low}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
				utility.tween(shownHigh, 0.35, {Value = high}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
			end

			local function update(newLow, newHigh, skip)
				local oldLow, oldHigh = low, high
				newLow = snap(newLow)
				newHigh = snap(newHigh)
				if newLow > newHigh then
					newLow, newHigh = newHigh, newLow
				end
				if newHigh - newLow < gap then
					if newLow ~= oldLow then
						newLow = math.max(min, newHigh - gap)
					else
						newHigh = math.min(max, newLow + gap)
					end
				end
				low, high = newLow, newHigh
				place(0.2)
				if not skip and (low ~= oldLow or high ~= oldHigh) then
					callback(low, high)
				end
			end

			local textService = game:GetService("TextService")
			local function widthOf(text)
				local params = Instance.new("GetTextBoundsParams")
				params.Text = text
				params.Font = displayLabel.FontFace
				params.Size = math.max(1, displayLabel.TextBounds.Y)
				params.Width = 2000
				local ok, bounds = pcall(textService.GetTextBoundsAsync, textService, params)
				return ok and bounds.X or 0
			end

			local editing
			displayLabel.InputBegan:Connect(function(input)
				if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
				if editing then return end
				local shownText = displayLabel.Text
				local cut = string.find(shownText, "  –", 1, true)
				local full = widthOf(shownText)
				local side = "high"
				if cut and full > 0 then
					local lowWidth = widthOf(string.sub(shownText, 1, cut + #"  –" - 1))
					local scale = displayLabel.TextBounds.X / full
					local textStart = displayLabel.AbsolutePosition.X + displayLabel.AbsoluteSize.X - displayLabel.TextBounds.X
					if input.Position.X < textStart + lowWidth * scale then
						side = "low"
					end
				end
				if editing then return end

				local spot = displayLabel.Position
				editing = utility.create("Frame", {
					Name = "edit",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(spot.X.Scale, spot.X.Offset + 4, spot.Y.Scale, spot.Y.Offset + displayLabel.Size.Y.Offset / 2),
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, 20),
					BackgroundTransparency = 1,
					ZIndex = 12,
					Parent = rangeFrame,
				}, {
					utility.create("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 6),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
				})
				local function plain(name, text, order)
					return utility.create("TextLabel", {
						Name = name,
						AutomaticSize = Enum.AutomaticSize.X,
						Size = UDim2.new(0, 0, 1, 0),
						BackgroundTransparency = 1,
						Text = text,
						TextColor3 = Color3.fromRGB(100, 100, 100),
						TextSize = 13,
						FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular),
						LayoutOrder = order,
						ZIndex = 12,
						Parent = editing,
					})
				end
				local field
				if side == "low" then
					field = utility.editBox({Name = "low", Text = format(low), LayoutOrder = 1, Parent = editing})
					plain("high", format(high) .. display, 3)
				else
					plain("low", format(low) .. display, 1)
					field = utility.editBox({Name = "high", Text = format(high), LayoutOrder = 3, Parent = editing})
				end
				plain("dash", "–", 2)
				displayLabel.Visible = false

				field.FocusLost:Connect(function()
					if not editing then return end
					local typed = tonumber((string.gsub(field.Text, "[^%d%.%-]", "")))
					utility.dismissEdit(editing, displayLabel)
					editing = nil
					if typed then
						if side == "low" then
							update(typed, high)
						else
							update(low, typed)
						end
					end
				end)
				field:CaptureFocus()
				field.CursorPosition = #field.Text + 1
			end)

			local held
			local function grow(knob, big)
				if not knob then return end
				utility.tween(knob, 0.25, {Size = big and UDim2.fromOffset(18, 18) or UDim2.fromOffset(16, 16)}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
			end

			local function valueAt(x)
				local percent = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
				return min + percent * (max - min)
			end

			local function drag(x)
				local raw = valueAt(x)
				if held == lowKnob then
					update(math.min(raw, high - gap), high)
				else
					update(low, math.max(raw, low + gap))
				end
			end

			track.InputBegan:Connect(function(input)
				if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
				if not utility.isTop(track, input.Position.X, input.Position.Y) then return end
				local raw = valueAt(input.Position.X)
				local lowDistance = math.abs(raw - low)
				local highDistance = math.abs(raw - high)
				if lowDistance < highDistance or (lowDistance == highDistance and raw < low) then
					held = lowKnob
				else
					held = highKnob
				end
				grow(held, true)
				drag(input.Position.X)
				utility.capture(function(moved)
					drag(moved.Position.X)
				end, function()
					grow(held, false)
					held = nil
				end)
			end)

			place(0)

			return {
				frame = rangeFrame,
				value = function()
					return low, high
				end,
				set = function(_, newLow, newHigh, skip)
					update(newLow or low, newHigh or high, skip)
				end,
			}
		end


		--------------------------------------
		-- custom ----------------------------
		--------------------------------------

		function tab:createCustom(config)
			config = config or {}
			local customFrame = utility.create("Frame", {
				Name = config.name or "custom",
				Parent = tab.list,
				Size = UDim2.new(1, 0, 0, config.height or 40),
				BackgroundTransparency = 1,
				ZIndex = 10,
			})
			return {
				frame = customFrame,
				setHeight = function(_, height)
					customFrame.Size = UDim2.new(1, 0, 0, height)
				end,
			}
		end


		--------------------------------------
		-- label -----------------------------
		--------------------------------------

		function tab:createLabel(config)
			config = config or {}
			local text = config.text or "text"

			local labelFrame = utility.create("Frame", {
				Name = text,
				Parent = tab.list,

				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
			}, {
				utility.create("TextLabel", {
					Name = "label",

					Position = UDim2.new(0, 0, 0, 5),
					Size = UDim2.new(1, 0, 0, 13),
					BackgroundTransparency = 1,

					Text = text,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextSize = 14,
					TextScaled = true,

					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
				})
			})

			local label = labelFrame.label

			return {
				frame = labelFrame,
				set = function(_, newText)
					text = newText
					label.Text = newText
					labelFrame.Name = newText
				end
			}
		end


		--------------------------------------
		-- paragraph -------------------------
		--------------------------------------

		function tab:createParagraph(config)
			config = config or {}

			local title = config.title or "title"
			local body = config.body or "body"

			local paragraphFrame = utility.create("Frame", {
				Name = title,
				Parent = tab.list,

				Size = UDim2.new(1, 0, 0, 34),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
			}, {
				utility.create("UIPadding", {
					PaddingBottom = UDim.new(0, 3),
				}),
				utility.create("TextLabel", {
					Name = "body",

					Position = UDim2.new(0, 0, 0, 21),
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,

					Text = body,
					TextColor3 = Color3.fromRGB(100, 100, 100),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					TextSize = 12,
					TextScaled = false,
					TextWrapped = true,
					LineHeight = 1.1,

					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
				}),
				utility.create("TextLabel", {
					Name = "title",

					Position = UDim2.new(0, 0, 0, 5),
					Size = UDim2.new(1, 0, 0, 16),
					BackgroundTransparency = 1,

					Text = title,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextSize = 14,
					TextScaled = true,

					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),

				})
			})

			local titleLabel = paragraphFrame.title
			local bodyLabel = paragraphFrame.body

			return {
				frame = paragraphFrame,
				set = function(_, newTitle, newText)
					if newTitle then
						titleLabel.Text = newTitle
						paragraphFrame.Name = newTitle
					end

					if newText then
						bodyLabel.Text = newText
						bodyLabel.Text = newText
					end
				end
			}
		end


		--------------------------------------
		-- button ----------------------------
		--------------------------------------

		function tab:createButton(config)
			config = config or {}
			local title = config.title or "button"
			local callback = config.callback or function() end
			local description = config.description

			local buttonFrame = utility.create("Frame", {
				Name = title,
				Parent = tab.list,

				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(1, 0, 0, (description and 54 or 44)),

				AnchorPoint = Vector2.new(0, 0),
				BackgroundColor3 = Color3.fromRGB(15, 15, 15),
				BackgroundTransparency = 0,

				Visible = true,
				ZIndex = 10,
			}, {
				utility.create("TextLabel", {
					Name = "title",

					Position = UDim2.new(0, 15, 0, 14),
					Size = UDim2.new(0.88416987657547, -15, 0, 13),

					AnchorPoint = Vector2.new(0, 0),
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 1,

					Visible = true,
					ZIndex = 10,

					Text = title,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextSize = 14,
					TextScaled = true,

					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
				}),
				utility.create("TextLabel", {
					Name = "display",

					Position = UDim2.new(1, -60, 0.5, 0),
					Size = UDim2.new(0, 50, 0, 10),

					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 1,

					Visible = true,
					ZIndex = 10,

					Text = "button",
					TextColor3 = Color3.fromRGB(50, 50, 50),
					TextXAlignment = Enum.TextXAlignment.Right,
					TextSize = 14,
					TextScaled = true,

					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
				}),
				utility.create("UICorner", {
					Name = "UICorner",
					CornerRadius = UDim.new(0, 5),
				})
			})

			if description then
				utility.create("TextLabel", {
					Name = "description",
					Parent = buttonFrame,

					Position = UDim2.new(0, 15, 0, 28),
					Size = UDim2.new(1, -15, 0, 12),

					AnchorPoint = Vector2.new(0, 0),
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 1,

					ZIndex = 10,

					Text = description,
					TextColor3 = Color3.fromRGB(100, 100, 100),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextSize = 14,
					TextScaled = true,

					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
				})
			end

			buttonFrame.InputBegan:Connect(function(input)
				if not utility.isTop(buttonFrame, input.Position.X, input.Position.Y) then return end
				if input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch then
					callback()
				end
			end)

			return {
				frame = buttonFrame,
				setText = function(_, text)
					buttonFrame.display.Text = text
				end,
			}
		end


		--------------------------------------
		-- hold button -----------------------
		--------------------------------------

		function tab:createHoldButton(config)
			config = config or {}
			local title = config.title or "hold button"
			local description = config.description
			local callback = config.callback or function() end
			local duration = config.duration or 1
			local hint = config.text or "hold"
			local accent = library.theme.accent
			local ink = utility.contrast(accent)
			local quart = Enum.EasingStyle.Quart
			local out = Enum.EasingDirection.Out

			local frame = utility.create("Frame", {
				Name = title,
				Parent = tab.list,
				Size = UDim2.new(1, 0, 0, description and 54 or 44),
				BackgroundColor3 = Color3.fromRGB(15, 15, 15),
				ZIndex = 10,
			}, {
				utility.create("UICorner", {CornerRadius = UDim.new(0, 5)}),
			})

			local fill = utility.create("Frame", {
				Name = "fill",
				Size = UDim2.new(0, 0, 1, 0),
				BackgroundColor3 = accent,
				BorderSizePixel = 0,
				ClipsDescendants = true,
				ZIndex = 12,
				Parent = frame,
			}, {
				utility.create("UICorner", {CornerRadius = UDim.new(0, 5)}),
			})

			local glow = utility.create("UIShadow", {
				Name = "glow",
				Color = accent,
				Transparency = 1,
				BlurRadius = UDim.new(0, 18),
				Spread = UDim2.new(0, 0, 0, 0),
				Offset = UDim2.new(0, 0, 0, 0),
				ZIndex = 1,
				Enabled = true,
				Parent = frame,
			})

			local raised = 0
			local function flash()
				raised += 1
				local token = raised
				frame.ZIndex = 998
				task.delay(1.2, function()
					if token == raised then
						frame.ZIndex = 10
					end
				end)
				glow.Transparency = 0.15
				glow.Spread = UDim2.new(0, 2, 0, 2)
				utility.tween(glow, 0.25, {Spread = UDim2.new(0, 10, 0, 10)}, quart, out)
				task.delay(0.15, function()
					utility.tween(glow, 0.9, {Transparency = 1, Spread = UDim2.new(0, 14, 0, 14)}, quart, out)
				end)
			end

			local overlay = utility.create("Frame", {
				Name = "overlay",
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(0, 0),
				ZIndex = 12,
				Parent = fill,
			})
			local function fitOverlay()
				overlay.Size = UDim2.fromOffset(frame.AbsoluteSize.X, frame.AbsoluteSize.Y)
			end
			frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitOverlay)
			fitOverlay()

			local pairs_ = {}
			local function text(name, props, colorOnTop, transparencyOnTop)
				local base = table.clone(props)
				base.Name = name
				base.BackgroundTransparency = 1
				base.ZIndex = 11
				base.Parent = frame
				local bottom = utility.create("TextLabel", base)
				local top = table.clone(props)
				top.Name = name
				top.BackgroundTransparency = 1
				top.TextColor3 = colorOnTop
				top.TextTransparency = transparencyOnTop or 0
				top.ZIndex = 13
				top.Parent = overlay
				local upper = utility.create("TextLabel", top)
				pairs_[name] = {bottom, upper}
				return bottom, upper
			end

			text("title", {
				Position = UDim2.new(0, 15, 0, 14),
				Size = UDim2.new(1, -90, 0, 13),
				Text = title,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextScaled = true,
				FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium),
			}, ink)

			if description then
				text("description", {
					Position = UDim2.new(0, 15, 0, 28),
					Size = UDim2.new(1, -90, 0, 12),
					Text = description,
					TextColor3 = Color3.fromRGB(100, 100, 100),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextScaled = true,
					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular),
				}, ink, 0.35)
			end

			local display, displayTop = text("display", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.new(0, 70, 0, 10),
				Text = hint,
				TextColor3 = Color3.fromRGB(50, 50, 50),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextScaled = true,
				FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium),
			}, ink)

			local function setDisplay(value)
				display.Text = value
				displayTop.Text = value
			end

			local progress = Instance.new("NumberValue")
			local holding = false
			local finished = false
			local tween

			local function stop()
				if tween then
					tween:Cancel()
					tween = nil
				end
			end

			local function release()
				if not holding then return end
				holding = false
				if finished then return end
				stop()
				tween = tweenService:Create(progress, TweenInfo.new(0.4, quart, out), {Value = 0})
				tween:Play()
			end

			local function complete()
				finished = true
				holding = false
				stop()
				setDisplay(config.doneText or "done")
				flash()
				task.spawn(callback)
				task.delay(0.7, function()
					tween = tweenService:Create(progress, TweenInfo.new(0.5, quart, out), {Value = 0})
					tween:Play()
					task.delay(0.5, function()
						setDisplay(hint)
						finished = false
					end)
				end)
			end

			progress.Changed:Connect(function(value)
				fill.Size = UDim2.new(value, 0, 1, 0)
				fill.Visible = value > 0.001
				if holding and not finished and value >= 0.999 then
					complete()
				end
			end)
			fill.Visible = false

			frame.InputBegan:Connect(function(input)
				if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
				if finished or holding or not utility.isTop(frame, input.Position.X, input.Position.Y) then return end
				holding = true
				utility.capture(nil, release)
				stop()
				tween = tweenService:Create(progress, TweenInfo.new(duration * (1 - progress.Value), Enum.EasingStyle.Linear), {Value = 1})
				tween:Play()
			end)

			frame.MouseLeave:Connect(release)

			return {
				frame = frame,
				setText = function(_, value)
					hint = value
					if not finished then
						setDisplay(value)
					end
				end,
				cancel = function()
					release()
				end,
			}
		end


		--------------------------------------
		-- keybind ---------------------------
		--------------------------------------

		function tab:createKeybind(config)
			config = config or {}

			local title = config.title or "keybind"
			local callback = config.callback or function() end
			local changedCallback = config.changedCallback or function() end
			local description = config.description
			local default = config.default or Enum.KeyCode.Unknown
			local modifierKeys = {
				Ctrl = {Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl},
				Shift = {Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift},
				Alt = {Enum.KeyCode.LeftAlt, Enum.KeyCode.RightAlt},
			}
			local modifierOrder = {"Ctrl", "Shift", "Alt"}
			local function modifierOf(keyCode)
				for name, codes in modifierKeys do
					if table.find(codes, keyCode) then
						return name
					end
				end
				return nil
			end
			local function parseBind(bind, extra)
				local found = {}
				for _, name in extra or {} do
					found[name] = true
				end
				if type(bind) == "string" then
					local parts = string.split(bind, "+")
					local last = Enum.KeyCode.Unknown
					for index, part in parts do
						part = string.gsub(part, "%s", "")
						local lowered = string.lower(part)
						local mod = (lowered == "ctrl" or lowered == "control") and "Ctrl" or lowered == "shift" and "Shift" or lowered == "alt" and "Alt" or nil
						if mod and index < #parts then
							found[mod] = true
						else
							local ok, code = pcall(function()
								return Enum.KeyCode[part]
							end)
							if not ok or not code then
								ok, code = pcall(function()
									return Enum.KeyCode[string.upper(part)]
								end)
							end
							last = ok and code or Enum.KeyCode.Unknown
						end
					end
					bind = last
				end
				local list = {}
				for _, name in modifierOrder do
					if found[name] then
						table.insert(list, name)
					end
				end
				return bind, list
			end
			local modifiers
			default, modifiers = parseBind(default, config.modifiers)
			local function heldModifiers()
				local list = {}
				for _, name in modifierOrder do
					for _, code in modifierKeys[name] do
						if userInputService:IsKeyDown(code) then
							table.insert(list, name)
							break
						end
					end
				end
				return list
			end
			local preview = "..."
			local pendingModifier

			local mode = config.type
			if mode ~= "toggle" and mode ~= "hold" then
				mode = "toggle"
			end

			local key = default
			local isBinding = false
			local state = false
			local suppressRelease = false
			local lastSet = 0
			local ignoreInput = false

			local keybindFrame = utility.create("Frame", {
				AnchorPoint = Vector2.new(0, 0),
				BackgroundTransparency = 0,
				Name = title,
				Position = UDim2.new(0, 0, 0, 0),
				Visible = true,
				ZIndex = 10,
				BackgroundColor3 = Color3.fromRGB(15, 15, 15),
				Size = UDim2.new(1, 0, 0, description and 54 or 40),
				Parent = tab.list,
			}, {
				utility.create("Frame", {
					AnchorPoint = Vector2.new(1, .5),
					BackgroundTransparency = 0,
					Name = "keybindBg",
					Position = UDim2.new(1, -8, 0.5, 0),
					Visible = true,
					ZIndex = 10,
					BackgroundColor3 = Color3.fromRGB(20, 20, 20),
					Size = UDim2.new(0, 0, 0, 30),
				}, {
					utility.create("UICorner", {
						Name = "UICorner",
						CornerRadius = UDim.new(0, 6),
					}),
					utility.create("UIStroke", {
						Name = "UIStroke",
						ZIndex = 1,
						Color = Color3.fromRGB(25, 25, 25),
						Transparency = 1,
					}),
					utility.create("TextLabel", {
						Visible = true,
						FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						ZIndex = 1,
						Text = "",
						Name = "label",
						TextXAlignment = Enum.TextXAlignment.Center,
						AnchorPoint = Vector2.new(.5, 0.5),
						TextScaled = false,
						BackgroundTransparency = 1,
						Position = UDim2.new(0.5, 0, 0.5, 0),
						TextYAlignment = Enum.TextYAlignment.Center,
						TextSize = 14,
						Size = UDim2.new(0, 0, 0, 15),
						AutomaticSize = Enum.AutomaticSize.X,
					}),
					utility.create("UIShadow", {
						Offset = UDim2.new(0, 0, 0, 0),
						Transparency = .5,
						Name = "UIShadow",
						BlurRadius = UDim.new(0, 15),
						Color = Color3.fromRGB(0, 0, 0),
						ZIndex = 1,
						Spread = UDim2.new(0, 0, 0, 0),
						Enabled = true,
					})
				}),

				utility.create("TextLabel", {
					Visible = true,
					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					ZIndex = 10,
					Text = title,
					Name = "title",
					TextXAlignment = Enum.TextXAlignment.Left,
					AnchorPoint = Vector2.new(0, 0),
					TextScaled = true,
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 15, 0, 14),
					TextYAlignment = Enum.TextYAlignment.Center,
					TextSize = 14,
					Size = UDim2.new(1, -145, 0, 13),
				}),
				utility.create("UICorner", {
					Name = "UICorner",
					CornerRadius = UDim.new(0, 5),
				})
			})

			local keybindBg = keybindFrame.keybindBg
			local keyLabel = keybindBg.label
			local stroke = keybindBg.UIStroke

			local function stringify(input)
				if input == Enum.KeyCode.Unknown then
					return "Unknown"
				end

				if typeof(input) == "EnumItem" and input.EnumType == Enum.UserInputType then
					if input == Enum.UserInputType.MouseButton1 then return "LMB" end
					if input == Enum.UserInputType.MouseButton2 then return "RMB" end
					if input == Enum.UserInputType.MouseButton3 then return "MMB" end
					return tostring(input):gsub("Enum.UserInputType.", "")
				end

				return tostring(input):gsub("Enum.KeyCode.", "")
			end

			local function refresh()
				local bound = stringify(key)
				if #modifiers > 0 and key ~= Enum.KeyCode.Unknown then
					bound = table.concat(modifiers, " + ") .. " + " .. bound
				end
				keyLabel.Text = isBinding and preview or bound

				task.defer(function()
					local bounds = keyLabel.TextBounds
					utility.tween(keybindBg, .3, {
						Size = UDim2.new(0, bounds.X + 20, 0, 30)
					}, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

					keyLabel.TextTransparency = 1
					tweenService:Create(keyLabel, TweenInfo.new(.5), {
						TextTransparency = 0
					}):Play()
				end)
			end

			window:tooltip(keybindBg, "")
			local conflictEntry = {}
			function conflictEntry.signature()
				if key == Enum.KeyCode.Unknown then return nil end
				return table.concat(modifiers, "+") .. "+" .. tostring(key)
			end
			function conflictEntry.show(other)
				keybindBg:SetAttribute("tooltip", other and ("same key as " .. other) or "")
				utility.tween(keyLabel, 0.3, {TextColor3 = other and Color3.fromRGB(248, 113, 113) or Color3.fromRGB(255, 255, 255)}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
			end
			conflictEntry.title = title
			window.keybinds = window.keybinds or {}
			table.insert(window.keybinds, conflictEntry)
			window.checkKeybinds = window.checkKeybinds or function()
				for _, entry in window.keybinds do
					local mine = entry.signature()
					local other
					if mine then
						for _, candidate in window.keybinds do
							if candidate ~= entry and candidate.signature() == mine then
								other = candidate.title
								break
							end
						end
					end
					entry.show(other)
				end
			end
			task.defer(window.checkKeybinds)

			local function setKey(newKey, newModifiers)
				isBinding = false
				pendingModifier = nil
				preview = "..."

				utility.tween(stroke, .3, {
					Transparency = 1
				})

				if newKey ~= nil then
					key = newKey
					modifiers = newModifiers or {}
					task.defer(window.checkKeybinds)
					changedCallback(key)

					if mode == "hold" then
						suppressRelease = true
						lastSet = tick()
					end
				end

				refresh()
			end

			refresh()

			local function isMatch(input)
				if key == Enum.KeyCode.Unknown then return false end
				for _, name in modifiers do
					local held = false
					for _, code in modifierKeys[name] do
						if userInputService:IsKeyDown(code) then
							held = true
						end
					end
					if not held then return false end
				end

				if key.EnumType == Enum.KeyCode then
					return input.KeyCode == key
				end

				if key.EnumType == Enum.UserInputType then
					return input.UserInputType == key
				end

				return false
			end

			keybindBg.InputBegan:Connect(function(input)
				if not utility.isTop(keybindBg, input.Position.X, input.Position.Y) then return end
				if input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch then

					isBinding = not isBinding
					preview = "..."
					pendingModifier = nil

					if isBinding then
						ignoreInput = true

						utility.tween(stroke, .3, {
							Transparency = 0
						})

						task.delay(0.01, function()
							ignoreInput = false

						end)
					end

					refresh()
				end
			end)

			local beganConn = userInputService.InputBegan:Connect(function(input, gp)
				if ignoreInput then return end

				if isBinding then
					if input.UserInputType == Enum.UserInputType.Keyboard then
						if input.KeyCode == Enum.KeyCode.Escape then
							setKey()
						elseif input.KeyCode == Enum.KeyCode.Backspace then
							setKey(Enum.KeyCode.Unknown)
						elseif modifierOf(input.KeyCode) then
							pendingModifier = input.KeyCode
							preview = table.concat(heldModifiers(), " + ") .. " + ..."
							refresh()
						else
							setKey(input.KeyCode, heldModifiers())
						end
					elseif tostring(input.UserInputType):find("MouseButton") then
						setKey(input.UserInputType, heldModifiers())
					end
					return
				end

				if gp or key == Enum.KeyCode.Unknown then
					return
				end

				if not isMatch(input) then return end

				if mode == "toggle" then
					state = not state
					callback(state)
				else
					callback(true)
				end
			end)

			table.insert(library.connections, beganConn)

			table.insert(library.connections, userInputService.InputEnded:Connect(function(input)
				if isBinding and pendingModifier and input.KeyCode == pendingModifier then
					setKey(pendingModifier, {})
				end
			end))

			if mode == "hold" then
				local endedConn = userInputService.InputEnded:Connect(function(input)
					if key == Enum.KeyCode.Unknown then return end
					if not isMatch(input) then return end

					if suppressRelease and (tick() - lastSet < 0.3) then
						suppressRelease = false
						return
					end

					callback(false)
				end)

				table.insert(library.connections, endedConn)

				local focusConn = userInputService.WindowFocusReleased:Connect(function()
					callback(false)
				end)

				table.insert(library.connections, focusConn)
			end

			if description then
				utility.create("TextLabel", {
					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
					TextColor3 = Color3.fromRGB(100, 100, 100),
					ZIndex = 10,
					Text = description,
					Name = "description",
					TextXAlignment = Enum.TextXAlignment.Left,
					AnchorPoint = Vector2.new(0, 0),
					TextScaled = true,
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 15, 0, 28),
					TextYAlignment = Enum.TextYAlignment.Center,
					TextSize = 14,
					Visible = true,
					Size = UDim2.new(1, -145, 0, 12),
					Parent = keybindFrame
				})
			end

			return {
				frame = keybindFrame,
				value = function()
					return key
				end,
				modifiers = function()
					return table.clone(modifiers)
				end,
				set = function(_, new, newModifiers, fireChanged)
					key, modifiers = parseBind(new, newModifiers)
					refresh()
					task.defer(window.checkKeybinds)
					if fireChanged then
						changedCallback(key)
					end

				end,

			}
		end


		--------------------------------------
		-- input -----------------------------
		--------------------------------------

		function tab:createInput(config)
			config = config or {}
			local title = config.title or "input"
			local description = config.description
			local default = config.default or ""
			local placeholder = config.placeholder or "..."
			local callback = config.callback or function()

			end

			local value = default
			local clear = config.clear or false
			local numerical = config.numerical or false
			local limit = config.limit or 50

			local inputFrame = utility.create("Frame", {
				AnchorPoint = Vector2.new(0, 0),
				BackgroundTransparency = 0,
				Name = title,
				Position = UDim2.new(0, 0, 0, 0),
				Visible = true,
				ZIndex = 10,
				BackgroundColor3 = Color3.fromRGB(15, 15, 15),
				Size = UDim2.new(1, 0, 0, (description and 54 or 44)),
				Parent = tab.list
			}, {
				utility.create("Frame", {
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundTransparency = 0,
					Name = "inputBg",
					Position = UDim2.new(1, -7, 0.5, 0),
					Visible = true,
					ZIndex = 10,
					BackgroundColor3 = Color3.fromRGB(20, 20, 20),
					Size = UDim2.new(0, 124, 0, 30),
				}, {
					utility.create("TextBox", {
						Visible = true,
						FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						ZIndex = 1,
						Text = default,
						Name = "label",
						TextXAlignment = Enum.TextXAlignment.Left,
						AnchorPoint = Vector2.new(0, 0.5),
						TextScaled = false,
						BackgroundTransparency = 1,
						Position = UDim2.new(0, 10, 0.5, 0),
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						TextYAlignment = Enum.TextYAlignment.Center,
						TextSize = 14,
						Size = UDim2.new(0, 0, 0, 15),
						ClearTextOnFocus = clear,
						PlaceholderText = placeholder,
						AutomaticSize = Enum.AutomaticSize.X,
					}),
					utility.create("UIStroke", {
						Name = "UIStroke",
						ZIndex = 1,
						Color = Color3.fromRGB(25, 25, 25),
						Transparency = 1,
					}),
					utility.create("UICorner", {
						Name = "UICorner",
						CornerRadius = UDim.new(0, 6),
					}),
					utility.create("UIShadow", {
						Offset = UDim2.new(0, 0, 0, 0),
						Transparency = .5,
						Name = "UIShadow",
						BlurRadius = UDim.new(0, 15),
						Color = Color3.fromRGB(0, 0, 0),
						ZIndex = 1,
						Spread = UDim2.new(0, 0, 0, 0),
						Enabled = true,
					})
				}),
				utility.create("UICorner", {
					Name = "UICorner",
					CornerRadius = UDim.new(0, 5),
				}),

				utility.create("TextLabel", {
					Visible = true,
					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					ZIndex = 10,
					Text = "Input",
					Name = "title",
					TextXAlignment = Enum.TextXAlignment.Left,
					AnchorPoint = Vector2.new(0, 0),
					TextScaled = true,
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 15, 0, 14),
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					TextYAlignment = Enum.TextYAlignment.Center,
					TextSize = 14,
					Size = UDim2.new(1, -145, 0, 13),
				})
			})

			local titleLabel = inputFrame.title

			local inputBg = inputFrame.inputBg
			local inputBox = inputBg.label
			local masked = config.password == true
			local revealed = false
			local mask, eye, caret
			if masked then
				inputBox.TextTransparency = 1
				mask = utility.create("TextLabel", {
					Name = "mask",
					BackgroundTransparency = 1,
					AnchorPoint = inputBox.AnchorPoint,
					Position = inputBox.Position,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.new(0, 0, 0, 15),
					Text = "",
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left,
					FontFace = inputBox.FontFace,
					ZIndex = 2,
					Parent = inputBg,
				})
				caret = utility.create("Frame", {
					Name = "caret",
					AnchorPoint = Vector2.new(0, 0.5),
					Size = UDim2.fromOffset(1, 14),
					BorderSizePixel = 0,
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					Visible = false,
					ZIndex = 3,
					Parent = inputBg,
				})
				eye = utility.create("TextButton", {
					Name = "eye",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -8, 0.5, 0),
					Size = UDim2.fromOffset(28, 20),
					BackgroundTransparency = 1,
					AutoButtonColor = false,
					Text = "show",
					TextColor3 = Color3.fromRGB(100, 100, 100),
					TextSize = 11,
					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular),
					ZIndex = 3,
					Parent = inputBg,
				})
			end

			local function drawMask()
				if not masked then return end
				local text = inputBox.Text
				inputBox.TextTransparency = revealed and 0 or 1
				mask.Visible = not revealed
				if text == "" then
					mask.Text = inputBox.PlaceholderText
					mask.TextColor3 = inputBox.PlaceholderColor3
				else
					mask.Text = string.rep("• ", utf8.len(text) or #text)
					mask.TextColor3 = Color3.fromRGB(255, 255, 255)
				end
			end

			local input = {
				frame = inputFrame,
				autocompletes = config.autocompletes or {},
			}

			local ghost = utility.create("TextLabel", {
				Name = "ghost",
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				RichText = true,
				Text = "",
				TextColor3 = Color3.fromRGB(80, 80, 80),
				TextTransparency = 1,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				FontFace = inputBox.FontFace,
				ZIndex = 2,
				Parent = inputBox,
			})

			local suggestion
			local ghostShown = false

			local function esc(text)
				text = string.gsub(text, "&", "&amp;")
				text = string.gsub(text, "<", "&lt;")
				text = string.gsub(text, ">", "&gt;")
				return text
			end

			local function suggest(text)
				if text == "" or masked then return nil end
				local lower = string.lower(text)
				for _, option in input.autocompletes or {} do
					option = tostring(option)
					if #option > #text and string.lower(string.sub(option, 1, #text)) == lower then
						return option
					end
				end
				return nil
			end

			local function resize()
				task.defer(function()
					local width = inputBox.TextBounds.X
					if masked then
						if not revealed then
							width = mask.TextBounds.X
						end
						width += 34
					end
					if ghostShown then
						width = math.max(width, ghost.TextBounds.X)
					end
					utility.tween(inputBg, 0.3, {
						Size = UDim2.new(0, width + 20, 0, 30)
					}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
				end)
			end

			local function updateGhost()
				local text = inputBox.Text
				suggestion = inputBox:IsFocused() and suggest(text) or nil
				if suggestion then
					ghost.Text = '<font transparency="1">' .. esc(text) .. "</font>" .. esc(string.sub(suggestion, #text + 1))
					if not ghostShown then
						ghostShown = true
						utility.tween(ghost, 0.25, {TextTransparency = 0}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
					end
				elseif ghostShown then
					ghostShown = false
					utility.tween(ghost, 0.2, {TextTransparency = 1}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
				end
			end

			local function update()
				if numerical then
					local digits = inputBox.Text:gsub('%D+', '')
					if digits ~= inputBox.Text then
						inputBox.Text = digits
						return
					end
				end
				if string.find(inputBox.Text, "\t", 1, true) then
					local cleaned = string.gsub(inputBox.Text, "\t", "")
					inputBox.Text = suggestion or cleaned
					inputBox.CursorPosition = #inputBox.Text + 1
					return
				end
				if #inputBox.Text > limit then
					inputBox.Text = string.sub(inputBox.Text, 1, limit)
					return
				end
				updateGhost()
				drawMask()
				resize()
			end

			if masked then
				eye.MouseEnter:Connect(function()
					utility.tween(eye, 0.25, {TextColor3 = Color3.fromRGB(255, 255, 255)}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
				end)
				eye.MouseLeave:Connect(function()
					utility.tween(eye, 0.3, {TextColor3 = Color3.fromRGB(100, 100, 100)}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
				end)
				eye.MouseButton1Click:Connect(function()
					revealed = not revealed
					eye.Text = revealed and "hide" or "show"
					drawMask()
					resize()
				end)
				local blink = 0
				local caretLoop
				local function stopCaret()
					if caretLoop then
						caretLoop:Disconnect()
						caretLoop = nil
					end
					caret.Visible = false
					blink = 0
				end
				inputBox.Focused:Connect(function()
					if caretLoop then return end
					caretLoop = runService.RenderStepped:Connect(function(dt)
						if revealed then
							caret.Visible = false
							return
						end
						blink = (blink + dt) % 1
						caret.Visible = blink < 0.5
						local x = inputBox.Text == "" and 0 or mask.TextBounds.X
						caret.Position = UDim2.new(0, mask.Position.X.Offset + x + 1, 0.5, 0)
					end)
				end)
				inputBox.FocusLost:Connect(stopCaret)
				inputBox.Destroying:Connect(stopCaret)
				task.defer(drawMask)
			end

			local conn1,conn2

			inputBox.Focused:Connect(function()
				utility.tween(inputBg.UIStroke, 0.3, {
					Transparency = 0
				})
				updateGhost()
				resize()
			end)

			inputBox.FocusLost:Connect(function(enterPressed)
				utility.tween(inputBg.UIStroke, 0.3, {
					Transparency = 1
				})
				if enterPressed and suggestion then
					local picked = suggestion
					suggestion = nil
					inputBox.Text = picked
				end
				updateGhost()
				resize()

				value = inputBox.Text
				callback(value)
			end)
			conn1 = inputBox:GetPropertyChangedSignal("Text"):Connect(function()
				update()
			end)

			table.insert(library.connections, conn1)

			titleLabel.Text = title
			if description then
				utility.create("TextLabel", {
					Visible = true,
					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
					TextColor3 = Color3.fromRGB(100, 100, 100),
					ZIndex = 10,
					Text = description,
					Name = "description",
					TextXAlignment = Enum.TextXAlignment.Left,
					AnchorPoint = Vector2.new(0, 0),
					TextScaled = true,
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 15, 0, 28),
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					TextYAlignment = Enum.TextYAlignment.Center,
					TextSize = 14,
					Size = UDim2.new(1, -145, 0, 12),
					Parent = inputFrame,
				})
			end

			update()

			function input:set(text, skipCallback)
				inputBox.Text = tostring(text)
				value = inputBox.Text
				if not skipCallback then
					callback(value)
				end
			end

			function input:value()
				return inputBox.Text
			end

			return input
		end

		local quartStyle = Enum.EasingStyle.Quart
		local easeOut = Enum.EasingDirection.Out
		local function clicked(input)
			return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
		end

		local function setHeader(frame, config, defaultTitle, rightWidth)
			local title = config.title or defaultTitle
			frame.Name = title
			frame.title.Text = title
			local description = frame:FindFirstChild("description")
			if rightWidth then
				frame.title.Size = UDim2.new(1, -rightWidth, 0, frame.title.Size.Y.Offset)
				if description then
					description.Size = UDim2.new(1, -rightWidth, 0, description.Size.Y.Offset)
				end
			end
			if config.description then
				if description then
					description.Text = config.description
				end
				frame.Size = UDim2.new(1, 0, 0, 54)
			else
				if description then
					description:Destroy()
				end
				frame.Size = UDim2.new(1, 0, 0, 44)
			end
			frame.LayoutOrder = 0
			frame.ZIndex = 10
		end

		local boxStrokeColor = Color3.fromRGB(25, 25, 25)
		local rowLabelColor = Color3.fromRGB(150, 150, 150)

		local function setBox(box, state, instant)
			local goals = {
				{box.fill, {BackgroundTransparency = state and 0 or 1}},
				{box.fill.scale, {Scale = state and 1 or 0.6}},
				{box.check, {TextTransparency = state and 0 or 1}},
				{box.check.scale, {Scale = state and 1 or 0.5}},
			}
			for _, goal in goals do
				if instant then
					for property, value in goal[2] do
						goal[1][property] = value
					end
				else
					utility.tween(goal[1], state and 0.35 or 0.25, goal[2], quartStyle, easeOut)
				end
			end
		end

		local function initBox(box)
			box.UIStroke.Color = boxStrokeColor
			box.UIStroke.Transparency = 0
			box.UIStroke.Thickness = 0
		end

		local function hover(box, hovered)
			utility.tween(box.UIStroke, 0.25, {Thickness = hovered and 1 or 0}, quartStyle, easeOut)
		end


		--------------------------------------
		-- segmented -------------------------
		--------------------------------------

		function tab:createSegmented(config)
			config = config or {}
			local options = config.options or {"one", "two", "three"}
			local callback = config.callback or function() end
			local current = config.default or options[1]
			local textService = game:GetService("TextService")

			local frame = utility.create("Frame", {
				Name = "segmented",
				Size = UDim2.new(1, 0, 0, 54),
				BackgroundColor3 = Color3.fromRGB(15, 15, 15),
				ZIndex = 10,
				LayoutOrder = 11,
			}, {
				utility.create("UICorner", {
					Name = "UICorner",
					CornerRadius = UDim.new(0, 5),
				}),
				utility.create("TextLabel", {
					Name = "title",
					Position = UDim2.new(0, 15, 0, 14),
					Size = UDim2.new(1, -203, 0, 13),
					BackgroundTransparency = 1,
					ZIndex = 10,
					Text = "Segmented",
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 14,
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
					TextWrapped = true,
				}),
				utility.create("TextLabel", {
					Name = "description",
					Position = UDim2.new(0, 15, 0, 28),
					Size = UDim2.new(1, -203, 0, 12),
					BackgroundTransparency = 1,
					ZIndex = 10,
					Text = "the highlight slides between options",
					TextColor3 = Color3.fromRGB(100, 100, 100),
					TextSize = 14,
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
					TextWrapped = true,
				}),
				utility.create("Frame", {
					Name = "segments",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -7, 0.5415, 0),
					Size = UDim2.new(0, 169, 0, 32),
					BackgroundColor3 = Color3.fromRGB(15, 15, 15),
					ZIndex = 10,
				}, {
					utility.create("UICorner", {
						Name = "UICorner",
						CornerRadius = UDim.new(0, 6),
					}),
					utility.create("UIStroke", {
						Name = "UIStroke",
						Color = Color3.fromRGB(20, 20, 20),
					}),
					utility.create("Frame", {
						Name = "indicator",
						Position = UDim2.new(0, 48, 0, 3),
						Size = UDim2.new(0, 69, 0, 26),
						BackgroundColor3 = Color3.fromRGB(20, 20, 20),
						ZIndex = 11,
					}, {
						utility.create("UICorner", {
							Name = "UICorner",
							CornerRadius = UDim.new(0, 4),
						}),
						utility.create("UIStroke", {
							Name = "UIStroke",
							Color = Color3.fromRGB(25, 25, 25),
						}),
						utility.create("Frame", {
							Name = "bar",
							AnchorPoint = Vector2.new(0.5, 1),
							Position = UDim2.new(0.5, 0, 1, -3),
							Size = UDim2.new(0, 10, 0, 2),
							BackgroundColor3 = library.theme.accent,
							BorderSizePixel = 0,
							ZIndex = 12,
						}, {
							utility.create("UICorner", {
								Name = "UICorner",
								CornerRadius = UDim.new(1, 0),
							}),
						}),
					}),
					utility.create("UIShadow", {
						Name = "UIShadow",
						BlurRadius = UDim.new(0, 15),
					}),
				}),
			})
			local track = frame.segments
			local indicator = track.indicator
			local unselectedColor = Color3.fromRGB(100, 100, 100)
			local buttonY = UDim.new(0, 3)
			local buttonHeight = UDim.new(0, 26)
			local fontEnum = Enum.Font.Roboto

			local widths = {}
			local total = 0
			for index, option in options do
				local width = math.ceil(textService:GetTextSize(tostring(option), 13, fontEnum, Vector2.new(1000, 100)).X) + 36
				widths[index] = width
				total += width
			end

			setHeader(frame, config, "segmented", total + 40)
			track.Size = UDim2.new(0, total + 6, track.Size.Y.Scale, track.Size.Y.Offset)

			local buttons = {}
			local select

			local offset = 3
			for index, option in options do
				local button = utility.create("TextButton", {
					Name = "low",
					Position = UDim2.new(0, 3, 0, 3),
					Size = UDim2.new(0, 45, 0, 26),
					BackgroundTransparency = 1,
					ZIndex = 13,
					Text = "low",
					TextColor3 = Color3.fromRGB(100, 100, 100),
					TextSize = 13,
					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
					AutoButtonColor = false,
				})
				button.Name = tostring(option)
				button.Text = tostring(option)
				button.Position = UDim2.new(0, offset, buttonY.Scale, buttonY.Offset)
				button.Size = UDim2.new(0, widths[index], buttonHeight.Scale, buttonHeight.Offset)
				button.TextColor3 = unselectedColor
				button.Parent = track
				offset += widths[index]
				buttons[option] = button
				button.MouseEnter:Connect(function()
					if option ~= current then
						utility.tween(button, 0.25, {TextColor3 = Color3.fromRGB(170, 170, 170)}, quartStyle, easeOut)
					end
				end)
				button.MouseLeave:Connect(function()
					if option ~= current then
						utility.tween(button, 0.3, {TextColor3 = unselectedColor}, quartStyle, easeOut)
					end
				end)
				button.MouseButton1Click:Connect(function()
					if not utility.isTop(button) then return end
					if option ~= current then
						select(option)
					end
				end)
			end

			local barSize = indicator.bar.Size

			select = function(option, skipCallback, instant)
				local button = buttons[option]
				if not button then return end
				current = option
				if instant then
					indicator.Position = button.Position
					indicator.Size = button.Size
				else
					utility.tween(indicator, 0.45, {Position = button.Position, Size = button.Size}, quartStyle, easeOut)
					indicator.bar.Size = UDim2.fromOffset(math.max(barSize.X.Offset - 6, 2), barSize.Y.Offset)
					utility.tween(indicator.bar, 0.5, {Size = barSize}, quartStyle, easeOut)
				end
				for name, other in buttons do
					local goal = name == option and Color3.fromRGB(255, 255, 255) or unselectedColor
					if instant then
						other.TextColor3 = goal
					else
						utility.tween(other, 0.3, {TextColor3 = goal}, quartStyle, easeOut)
					end
				end
				if not skipCallback then
					callback(option)
				end
			end

			select(current, true, true)
			frame.Parent = tab.list

			return {
				frame = frame,
				value = function()
					return current
				end,
				set = function(_, option, skipCallback)
					select(option, skipCallback)
				end,
			}
		end


		--------------------------------------
		-- checkbox --------------------------
		--------------------------------------

		function tab:createCheckbox(config)
			config = config or {}
			local callback = config.callback or function() end

			if type(config.options) ~= "table" then
				local frame = utility.create("Frame", {
					Name = "checkbox",
					Size = UDim2.new(1, 0, 0, 54),
					BackgroundColor3 = Color3.fromRGB(15, 15, 15),
					ZIndex = 10,
					LayoutOrder = 12,
				}, {
					utility.create("UICorner", {
						Name = "UICorner",
						CornerRadius = UDim.new(0, 5),
					}),
					utility.create("TextLabel", {
						Name = "title",
						Position = UDim2.new(0, 15, 0, 14),
						Size = UDim2.new(1, -60, 0, 13),
						BackgroundTransparency = 1,
						ZIndex = 10,
						Text = "Checkbox",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextSize = 14,
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
						TextWrapped = true,
					}),
					utility.create("TextLabel", {
						Name = "description",
						Position = UDim2.new(0, 15, 0, 28),
						Size = UDim2.new(1, -60, 0, 12),
						BackgroundTransparency = 1,
						ZIndex = 10,
						Text = "click anywhere on it",
						TextColor3 = Color3.fromRGB(100, 100, 100),
						TextSize = 14,
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
						TextWrapped = true,
					}),
					utility.create("Frame", {
						Name = "box",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -17, 0.5, 0),
						Size = UDim2.new(0, 20, 0, 20),
						BackgroundColor3 = Color3.fromRGB(20, 20, 20),
						ZIndex = 11,
					}, {
						utility.create("UICorner", {
							Name = "UICorner",
							CornerRadius = UDim.new(0, 5),
						}),
						utility.create("UIStroke", {
							Name = "UIStroke",
							Color = Color3.fromRGB(30, 30, 30),
							Transparency = 1,
						}),
						utility.create("Frame", {
							Name = "fill",
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.new(0.5, 0, 0.5, 0),
							Size = UDim2.new(1, 0, 1, 0),
							BackgroundColor3 = library.theme.accent,
							ZIndex = 12,
						}, {
							utility.create("UICorner", {
								Name = "UICorner",
								CornerRadius = UDim.new(0, 5),
							}),
							utility.create("UIScale", {
								Name = "scale",
							}),
						}),
						utility.create("TextLabel", {
							Name = "check",
							Size = UDim2.new(1, 0, 1, 0),
							BackgroundTransparency = 1,
							ZIndex = 13,
							Text = "✓",
							TextColor3 = utility.contrast(library.theme.accent),
							TextSize = 14,
							FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
						}, {
							utility.create("UIScale", {
								Name = "scale",
							}),
						}),
					}),
				})
				setHeader(frame, config, "checkbox", 60)
				local box = frame.box
				initBox(box)
				local state = config.default == true
				setBox(box, state, true)

				local function set(value, skipCallback)
					state = value == true
					setBox(box, state)
					if not skipCallback then
						callback(state)
					end
				end

				frame.MouseEnter:Connect(function() hover(box, true) end)
				frame.MouseLeave:Connect(function() hover(box, false) end)
				frame.InputBegan:Connect(function(input)
					if not utility.isTop(frame, input.Position.X, input.Position.Y) then return end
					if clicked(input) then
						set(not state)
					end
				end)
				frame.Parent = tab.list

				return {
					frame = frame,
					value = function()
						return state
					end,
					set = function(_, value, skipCallback)
						set(value, skipCallback)
					end,
					toggle = function(skipCallback)
						set(not state, skipCallback)
					end,
				}
			end

			local options = config.options
			local checked = {}
			for _, option in (type(config.default) == "table" and config.default or {}) do
				checked[option] = true
			end

			local frame = utility.create("Frame", {
				Name = "checkboxList",
				Size = UDim2.new(1, 0, 0, 170),
				BackgroundColor3 = Color3.fromRGB(15, 15, 15),
				ZIndex = 10,
				LayoutOrder = 13,
			}, {
				utility.create("UICorner", {
					Name = "UICorner",
					CornerRadius = UDim.new(0, 5),
				}),
				utility.create("TextLabel", {
					Name = "title",
					Position = UDim2.new(0, 15, 0, 14),
					Size = UDim2.new(1, -15, 0, 13),
					BackgroundTransparency = 1,
					ZIndex = 10,
					Text = "Checkbox list",
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 14,
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
					TextWrapped = true,
				}),
				utility.create("TextLabel", {
					Name = "description",
					Position = UDim2.new(0, 15, 0, 28),
					Size = UDim2.new(1, -15, 0, 12),
					BackgroundTransparency = 1,
					ZIndex = 10,
					Text = "always visible, pick as many as u want",
					TextColor3 = Color3.fromRGB(100, 100, 100),
					TextSize = 14,
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
					TextWrapped = true,
				}),
				utility.create("Frame", {
					Name = "rows",
					Position = UDim2.new(0, 15, 0, 48),
					Size = UDim2.new(1, -30, 0, 112),
					BackgroundTransparency = 1,
					ZIndex = 10,
				}, {
					utility.create("UIListLayout", {
						Name = "UIListLayout",
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
				}),
			})
			setHeader(frame, config, "checkbox", 15)
			local rows = frame.rows
			local headerHeight = config.description and 54 or 44
			local rowsTop = headerHeight - (54 - rows.Position.Y.Offset)
			local rowHeight = 28
			rows.Position = UDim2.new(rows.Position.X.Scale, rows.Position.X.Offset, 0, rowsTop)
			rows.Size = UDim2.new(rows.Size.X.Scale, rows.Size.X.Offset, 0, #options * rowHeight)
			frame.Size = UDim2.new(1, 0, 0, rowsTop + #options * rowHeight + 10)

			local entries = {}

			local function getChecked()
				local list = {}
				for _, option in options do
					if checked[option] then
						table.insert(list, option)
					end
				end
				return list
			end

			local function setRow(option, instant)
				local entry = entries[option]
				local state = checked[option] == true
				setBox(entry.box, state, instant)
				local color = state and Color3.fromRGB(255, 255, 255) or rowLabelColor
				if instant then
					entry.label.TextColor3 = color
				else
					utility.tween(entry.label, 0.3, {TextColor3 = color}, quartStyle, easeOut)
				end
			end

			for index, option in options do
				local row = utility.create("TextButton", {
					Name = "level ups",
					Size = UDim2.new(1, 0, 0, 28),
					BackgroundTransparency = 1,
					ZIndex = 10,
					LayoutOrder = 2,
					Text = "",
					AutoButtonColor = false,
				}, {
					utility.create("Frame", {
						Name = "box",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 0, 0.5, 0),
						Size = UDim2.new(0, 20, 0, 20),
						BackgroundColor3 = Color3.fromRGB(20, 20, 20),
						ZIndex = 11,
					}, {
						utility.create("UICorner", {
							Name = "UICorner",
							CornerRadius = UDim.new(0, 5),
						}),
						utility.create("UIStroke", {
							Name = "UIStroke",
							Color = Color3.fromRGB(25, 25, 25),
						}),
						utility.create("Frame", {
							Name = "fill",
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.new(0.5, 0, 0.5, 0),
							Size = UDim2.new(1, 0, 1, 0),
							BackgroundColor3 = library.theme.accent,
							BackgroundTransparency = 1,
							ZIndex = 12,
						}, {
							utility.create("UICorner", {
								Name = "UICorner",
								CornerRadius = UDim.new(0, 5),
							}),
							utility.create("UIScale", {
								Name = "scale",
								Scale = 0.6,
							}),
						}),
						utility.create("TextLabel", {
							Name = "check",
							Size = UDim2.new(1, 0, 1, 0),
							BackgroundTransparency = 1,
							ZIndex = 13,
							Text = "✓",
							TextColor3 = utility.contrast(library.theme.accent),
							TextTransparency = 1,
							TextSize = 14,
							FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
						}, {
							utility.create("UIScale", {
								Name = "scale",
								Scale = 0.5,
							}),
						}),
					}),
					utility.create("TextLabel", {
						Name = "label",
						Position = UDim2.new(0, 30, 0, 0),
						Size = UDim2.new(1, -30, 1, 0),
						BackgroundTransparency = 1,
						ZIndex = 11,
						Text = "level ups",
						TextColor3 = Color3.fromRGB(150, 150, 150),
						TextSize = 13,
						TextXAlignment = Enum.TextXAlignment.Left,
						FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
					}),
				})
				row.Name = tostring(option)
				row.LayoutOrder = index
				local box = row.box
				initBox(box)
				local label = row.label
				local labelBase = label.Position
				label.Text = tostring(option)
				row.Parent = rows
				entries[option] = {box = box, label = label}
				setRow(option, true)
				row.MouseEnter:Connect(function()
					hover(box, true)
					utility.tween(label, 0.3, {Position = labelBase + UDim2.fromOffset(3, 0)}, quartStyle, easeOut)
				end)
				row.MouseLeave:Connect(function()
					hover(box, false)
					utility.tween(label, 0.35, {Position = labelBase}, quartStyle, easeOut)
				end)
				row.MouseButton1Click:Connect(function()
					if not utility.isTop(row) then return end
					checked[option] = not checked[option] or nil
					setRow(option)
					callback(getChecked())
				end)
			end
			frame.Parent = tab.list

			return {
				frame = frame,
				value = function()
					return getChecked()
				end,
				set = function(_, list, skipCallback)
					table.clear(checked)
					for _, option in (type(list) == "table" and list or {list}) do
						checked[option] = true
					end
					for _, option in options do
						setRow(option)
					end
					if not skipCallback then
						callback(getChecked())
					end
				end,
			}
		end


		--------------------------------------
		-- color picker ----------------------
		--------------------------------------

		function tab:createColorPicker(config)
			config = config or {}
			local callback = config.callback or function() end
			local color = config.default or library.theme.accent
			local hue, sat, val = color:ToHSV()
			local guiServiceRef = game:GetService("GuiService")

			local frame = utility.create("Frame", {
				Name = "colorPicker",
				Size = UDim2.new(1, 0, 0, 54),
				BackgroundColor3 = Color3.fromRGB(15, 15, 15),
				ZIndex = 999,
				LayoutOrder = 9,
			}, {
				utility.create("UICorner", {
					Name = "UICorner",
					CornerRadius = UDim.new(0, 5),
				}),
				utility.create("TextLabel", {
					Name = "title",
					Position = UDim2.new(0, 15, 0, 14),
					Size = UDim2.new(1, -130, 0, 13),
					BackgroundTransparency = 1,
					ZIndex = 10,
					Text = "Color picker",
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 14,
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
					TextWrapped = true,
				}),
				utility.create("TextLabel", {
					Name = "description",
					Position = UDim2.new(0, 15, 0, 28),
					Size = UDim2.new(1, -130, 0, 12),
					BackgroundTransparency = 1,
					ZIndex = 10,
					Text = "click the swatch to open the picker",
					TextColor3 = Color3.fromRGB(100, 100, 100),
					TextSize = 14,
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
					TextWrapped = true,
				}),
				utility.create("TextButton", {
					Name = "pill",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -7, 0.5, 0),
					Size = UDim2.new(0, 104, 0, 30),
					BackgroundColor3 = Color3.fromRGB(20, 20, 20),
					ZIndex = 10,
					Text = "",
					AutoButtonColor = false,
				}, {
					utility.create("UICorner", {
						Name = "UICorner",
						CornerRadius = UDim.new(0, 6),
					}),
					utility.create("Frame", {
						Name = "swatch",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 8, 0.5, 0),
						Size = UDim2.new(0, 16, 0, 16),
						BackgroundColor3 = Color3.fromRGB(255, 195, 9),
						ZIndex = 11,
					}, {
						utility.create("UICorner", {
							Name = "UICorner",
							CornerRadius = UDim.new(0, 4),
						}),
						utility.create("UIStroke", {
							Name = "UIStroke",
							Color = Color3.fromRGB(40, 40, 40),
						}),
					}),
					utility.create("TextLabel", {
						Name = "hex",
						Position = UDim2.new(0, 32, 0, 0),
						Size = UDim2.new(1, -40, 1, 0),
						BackgroundTransparency = 1,
						ZIndex = 11,
						Text = "#FFC309",
						TextColor3 = Color3.fromRGB(200, 200, 200),
						TextSize = 12,
						TextXAlignment = Enum.TextXAlignment.Left,
						FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
					}),
					utility.create("UIStroke", {
						Name = "UIStroke",
						Color = Color3.fromRGB(25, 25, 25),
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
					utility.create("UIShadow", {
						Name = "UIShadow",
						BlurRadius = UDim.new(0, 15),
					}),
				}),
				utility.create("Frame", {
					Name = "picker",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -7, 1, 2),
					Size = UDim2.new(0, 220, 0, 196),
					BackgroundColor3 = Color3.fromRGB(15, 15, 15),
					ZIndex = 20,
					ClipsDescendants = true,
				}, {
					utility.create("UICorner", {
						Name = "UICorner",
						CornerRadius = UDim.new(0, 6),
					}),
					utility.create("UIStroke", {
						Name = "UIStroke",
						Color = Color3.fromRGB(20, 20, 20),
					}),
					utility.create("UIShadow", {
						Name = "UIShadow",
						Offset = UDim2.new(0, 0, 0, 4),
						Transparency = 0.4,
						BlurRadius = UDim.new(0, 18),
					}),
					utility.create("Frame", {
						Name = "saturation",
						Position = UDim2.new(0, 10, 0, 10),
						Size = UDim2.new(0, 200, 0, 120),
						BackgroundColor3 = Color3.fromRGB(255, 193, 0),
						ZIndex = 21,
					}, {
						utility.create("UICorner", {
							Name = "UICorner",
							CornerRadius = UDim.new(0, 4),
						}),
						utility.create("Frame", {
							Name = "white",
							Size = UDim2.new(1, 0, 1, 0),
							BackgroundColor3 = Color3.fromRGB(255, 255, 255),
							ZIndex = 22,
						}, {
							utility.create("UICorner", {
								Name = "UICorner",
								CornerRadius = UDim.new(0, 4),
							}),
							utility.create("UIGradient", {
								Name = "UIGradient",
								Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)}),
							}),
						}),
						utility.create("Frame", {
							Name = "black",
							Size = UDim2.new(1, 0, 1, 0),
							BackgroundColor3 = Color3.fromRGB(0, 0, 0),
							ZIndex = 23,
						}, {
							utility.create("UICorner", {
								Name = "UICorner",
								CornerRadius = UDim.new(0, 4),
							}),
							utility.create("UIGradient", {
								Name = "UIGradient",
								Rotation = 90,
								Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)}),
							}),
						}),
						utility.create("Frame", {
							Name = "cursor",
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.new(0.9647, 0, 0, 0),
							Size = UDim2.new(0, 10, 0, 10),
							BackgroundColor3 = Color3.fromRGB(255, 195, 9),
							ZIndex = 24,
						}, {
							utility.create("UICorner", {
								Name = "UICorner",
								CornerRadius = UDim.new(1, 0),
							}),
							utility.create("UIStroke", {
								Name = "UIStroke",
								Color = Color3.fromRGB(255, 255, 255),
								Thickness = 2,
							}),
						}),
					}),
					utility.create("Frame", {
						Name = "hue",
						Position = UDim2.new(0, 10, 0, 140),
						Size = UDim2.new(0, 200, 0, 10),
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						ZIndex = 21,
					}, {
						utility.create("UICorner", {
							Name = "UICorner",
							CornerRadius = UDim.new(1, 0),
						}),
						utility.create("UIGradient", {
							Name = "UIGradient",
							Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)), ColorSequenceKeypoint.new(0.1667, Color3.fromRGB(255, 255, 0)), ColorSequenceKeypoint.new(0.3333, Color3.fromRGB(0, 255, 0)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)), ColorSequenceKeypoint.new(0.6667, Color3.fromRGB(0, 0, 255)), ColorSequenceKeypoint.new(0.8333, Color3.fromRGB(255, 0, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))}),
						}),
						utility.create("Frame", {
							Name = "cursor",
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.new(0.126, 0, 0.5, 0),
							Size = UDim2.new(0, 6, 0, 16),
							BackgroundColor3 = Color3.fromRGB(255, 255, 255),
							ZIndex = 24,
						}, {
							utility.create("UICorner", {
								Name = "UICorner",
								CornerRadius = UDim.new(1, 0),
							}),
							utility.create("UIStroke", {
								Name = "UIStroke",
								Color = Color3.fromRGB(15, 15, 15),
							}),
						}),
					}),
					utility.create("Frame", {
						Name = "hexInput",
						Position = UDim2.new(0, 10, 0, 160),
						Size = UDim2.new(0, 128, 0, 26),
						BackgroundColor3 = Color3.fromRGB(20, 20, 20),
						ZIndex = 21,
					}, {
						utility.create("UICorner", {
							Name = "UICorner",
							CornerRadius = UDim.new(0, 5),
						}),
						utility.create("UIStroke", {
							Name = "UIStroke",
							Color = Color3.fromRGB(25, 25, 25),
						}),
						utility.create("TextBox", {
							Name = "box",
							Position = UDim2.new(0, 10, 0, 0),
							Size = UDim2.new(1, -20, 1, 0),
							BackgroundTransparency = 1,
							ZIndex = 22,
							Text = "#FFC309",
							TextColor3 = Color3.fromRGB(220, 220, 220),
							TextSize = 12,
							FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
							TextXAlignment = Enum.TextXAlignment.Left,
							ClearTextOnFocus = false,
						}),
						utility.create("UIShadow", {
							Name = "UIShadow",
							BlurRadius = UDim.new(0, 15),
						}),
					}),
					utility.create("Frame", {
						Name = "preview",
						Position = UDim2.new(0, 146, 0, 160),
						Size = UDim2.new(0, 64, 0, 26),
						BackgroundColor3 = Color3.fromRGB(255, 195, 9),
						ZIndex = 21,
					}, {
						utility.create("UICorner", {
							Name = "UICorner",
							CornerRadius = UDim.new(0, 5),
						}),
						utility.create("UIStroke", {
							Name = "UIStroke",
							Color = Color3.fromRGB(25, 25, 25),
						}),
						utility.create("UIShadow", {
							Name = "UIShadow",
							BlurRadius = UDim.new(0, 15),
						}),
					}),
				}),
			})
			setHeader(frame, config, "color", 130)
			local pill = frame.pill
			local panel = frame.picker
			panel.Active = true
			local sv = panel.saturation
			local svCursor = sv.cursor
			local hueBar = panel.hue
			local hueCursor = hueBar.cursor
			local hexHolder = panel.hexInput
			local hexBox = hexHolder.box
			local preview = panel.preview
			local openSize = panel.Size
			local closedSize = UDim2.new(openSize.X.Scale, openSize.X.Offset, 0, 0)
			local hexStroke = hexHolder.UIStroke.Color
			panel.Size = closedSize
			panel.Visible = false
			pill.UIStroke.Transparency = 1

			local function render(skipCallback)
				color = Color3.fromHSV(hue, sat, val)
				local hexText = "#" .. string.upper(color:ToHex())
				local glide = 0.2
				utility.tween(sv, glide, {BackgroundColor3 = Color3.fromHSV(hue, 1, 1)}, quartStyle, easeOut)
				utility.tween(svCursor, glide, {Position = UDim2.fromScale(sat, 1 - val), BackgroundColor3 = color}, quartStyle, easeOut)
				utility.tween(hueCursor, glide, {Position = UDim2.fromScale(hue, 0.5)}, quartStyle, easeOut)
				utility.tween(pill.swatch, glide, {BackgroundColor3 = color}, quartStyle, easeOut)
				utility.tween(preview, glide, {BackgroundColor3 = color}, quartStyle, easeOut)
				pill.hex.Text = hexText
				if not hexBox:IsFocused() then
					hexBox.Text = hexText
				end
				if not skipCallback then
					callback(color)
				end
			end

			local function cursorPos()
				return userInputService:GetMouseLocation() - guiServiceRef:GetGuiInset()
			end

			local draggingSv, draggingHue = false, false
			local function dragSv()
				local location = cursorPos()
				sat = math.clamp((location.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
				val = 1 - math.clamp((location.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
				render()
			end
			local function dragHue()
				local location = cursorPos()
				hue = math.clamp((location.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 0.999)
				render()
			end

			sv.InputBegan:Connect(function(input)
				if clicked(input) then
					draggingSv = true
					dragSv()
					utility.capture(dragSv, function()
						draggingSv = false
					end)
				end
			end)
			hueBar.InputBegan:Connect(function(input)
				if clicked(input) then
					draggingHue = true
					dragHue()
					utility.capture(dragHue, function()
						draggingHue = false
					end)
				end
			end)

			hexBox.Focused:Connect(function()
				utility.tween(hexHolder.UIStroke, 0.3, {Color = Color3.fromRGB(30, 30, 30)}, quartStyle, easeOut)
			end)
			hexBox.FocusLost:Connect(function()
				utility.tween(hexHolder.UIStroke, 0.3, {Color = hexStroke}, quartStyle, easeOut)
				local text = string.gsub(hexBox.Text, "[^%x]", "")
				if #text == 3 then
					text = string.gsub(text, "%x", "%0%0")
				end
				if #text == 6 then
					local ok, parsed = pcall(Color3.fromHex, text)
					if ok then
						hue, sat, val = parsed:ToHSV()
						render()
						return
					end
				end
				hexBox.Text = "#" .. string.upper(color:ToHex())
			end)

			local open = false
			local openToken = 0
			local function setOpen(state)
				open = state
				openToken += 1
				local token = openToken
				if state then
					if library.closePopup and library.popupOwner ~= frame then
						library.closePopup()
					end
					library.popupOwner = frame
					library.popupFrame = panel
					utility.openRoom(panel)
					library.closePopup = function()
						if open then
							setOpen(false)
						end
					end
				elseif library.popupOwner == frame then
					library.popupOwner = nil
					library.popupFrame = nil
					utility.closeRoom()
					library.closePopup = nil
				end
				if state then
					frame.ZIndex = 999
					panel.Visible = true
					utility.tween(panel, 0.45, {Size = openSize}, quartStyle, easeOut)
					utility.tween(pill.UIStroke, 0.3, {Transparency = 0}, quartStyle, easeOut)
				else
					draggingSv, draggingHue = false, false
					if frame.ZIndex > 500 then
						frame.ZIndex = 500
					end
					utility.tween(panel, 0.35, {Size = closedSize}, quartStyle, easeOut)
					utility.tween(pill.UIStroke, 0.3, {Transparency = 1}, quartStyle, easeOut)
					task.delay(0.36, function()
						if token == openToken and not open then
							panel.Visible = false
							frame.ZIndex = 10
						end
					end)
				end
			end

			pill.MouseButton1Click:Connect(function()
				if not utility.isTop(pill) then return end
				setOpen(not open)
			end)

			local function within(gui, location)
				local position, size = gui.AbsolutePosition, gui.AbsoluteSize
				return location.X >= position.X and location.X <= position.X + size.X and location.Y >= position.Y and location.Y <= position.Y + size.Y
			end
			table.insert(library.connections, userInputService.InputBegan:Connect(function(input)
				if not open or not clicked(input) then return end
				local location = cursorPos()
				if not within(panel, location) and not within(pill, location) then
					setOpen(false)
				end
			end))

			render(true)
			frame.Parent = tab.list

			return {
				frame = frame,
				value = function()
					return color
				end,
				set = function(_, newColor, skipCallback)
					hue, sat, val = newColor:ToHSV()
					render(skipCallback)
				end,
			}
		end


		--------------------------------------
		-- layout ----------------------------
		--------------------------------------

		do
			local textService = game:GetService("TextService")
			local quart = Enum.EasingStyle.Quart
			local out = Enum.EasingDirection.Out
			local regular = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
			local accent = library.theme.accent
			local guideColor = Color3.fromRGB(30, 30, 30)
			local idleColor = Color3.fromRGB(100, 100, 100)
			local hoverColor = Color3.fromRGB(170, 170, 170)
			local activeColor = Color3.fromRGB(255, 255, 255)

			local function animate(element, delayTime)
				if library.animateElement then
					library.animateElement(element, delayTime)
				end
			end

			local function wrap(element, target, order)
				local holder = Instance.new("Frame")
				holder.Name = element.Name
				holder.BackgroundTransparency = 1
				holder.BorderSizePixel = 0
				holder.LayoutOrder = order
				holder.ZIndex = element.ZIndex
				local function fit()
					holder.Size = UDim2.new(1, 0, 0, element.AbsoluteSize.Y)
				end
				fit()
				holder.Parent = target
				element.AnchorPoint = Vector2.new(0, 0)
				element.Position = UDim2.fromOffset(0, 0)
				element.Parent = holder
				element:GetPropertyChangedSignal("ZIndex"):Connect(function()
					holder.ZIndex = element.ZIndex
				end)
				element:GetPropertyChangedSignal("Visible"):Connect(function()
					holder.Visible = element.Visible
				end)
				element:GetPropertyChangedSignal("Size"):Connect(fit)
				element:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
				element.Destroying:Connect(function()
					holder:Destroy()
				end)
				return holder
			end

			local function zSync(owner, content)
				local function refresh()
					local highest = 10
					for _, child in content:GetChildren() do
						if child:IsA("GuiObject") then
							highest = math.max(highest, child.ZIndex)
						end
					end
					owner.ZIndex = highest
				end
				return function(child)
					child:GetPropertyChangedSignal("ZIndex"):Connect(refresh)
					refresh()
				end
			end

			local function redirect(target, onMoved)
				local counter = 0
				return setmetatable({}, {
					__index = function(_, key)
						if type(key) ~= "string" or string.sub(key, 1, 6) ~= "create" or type(tab[key]) ~= "function" then
							return nil
						end
						return function(_, ...)
							local before = {}
							for _, child in tab.list:GetChildren() do
								before[child] = true
							end
							local result = tab[key](tab, ...)
							for _, child in tab.list:GetChildren() do
								if not before[child] and child:IsA("GuiObject") then
									counter += 1
									child:SetAttribute("wrapped", true)
									local holder = wrap(child, target, counter)
									if onMoved then
										onMoved(holder)
									end
									break
								end
							end
							return result
						end
					end,
				})
			end


			--------------------------------------
			-- groupboxes ------------------------
			--------------------------------------

			function tab:createGroupbox(config)
				if type(config) == "string" then
					config = {title = config}
				end
				config = config or {}
				local side = config.side == "right" and "right" or "left"

				local columns = tab.groupColumns
				if not columns or not columns.Parent then
					columns = utility.create("Frame", {
						Name = "groupboxes",
						BackgroundTransparency = 1,
						AutomaticSize = Enum.AutomaticSize.Y,
						Size = UDim2.new(1, 0, 0, 0),
						ZIndex = 10,
					})
					for index, name in {"left", "right"} do
						utility.create("Frame", {
							Name = name,
							BackgroundTransparency = 1,
							AutomaticSize = Enum.AutomaticSize.Y,
							Position = index == 1 and UDim2.new() or UDim2.new(0.5, 4, 0, 0),
							Size = UDim2.new(0.5, -4, 0, 0),
							ZIndex = 10,
							Parent = columns,
						}, {
							utility.create("UIListLayout", {Name = "UIListLayout", Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}),
						})
					end
					local sideDepth = zSync(columns, columns)
					sideDepth(columns.left)
					sideDepth(columns.right)
					columns.AncestryChanged:Connect(function()
						local holder = columns.Parent
						if holder and holder ~= tab.list and holder:GetAttribute("entranceHolder") then
							holder:SetAttribute("entranceHolder", false)
						end
					end)
					columns.Parent = tab.list
					tab.groupColumns = columns
					tab.groupCount = 0
				end

				local column = columns[side]
				tab.groupCount += 1
				local box = utility.create("Frame", {
					Name = config.title or "groupbox",
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.Y,
					Size = UDim2.new(1, 0, 0, 0),
					LayoutOrder = tab.groupCount,
					ZIndex = 10,
					Parent = column,
				}, {
					utility.create("UICorner", {CornerRadius = UDim.new(0, 6)}),
					utility.create("UIStroke", {Name = "UIStroke", Color = Color3.fromRGB(15, 15, 15), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}),
				})
				local top = utility.create("Frame", {
					Name = "top",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 32),
					ZIndex = 10,
					Parent = box,
				})
				local outline = utility.create("Frame", {
					Name = "headerOutline",
					BackgroundColor3 = Color3.fromRGB(20, 20, 20),
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(-1, -1),
					Size = UDim2.new(1, 2, 0, 34),
					ZIndex = 10,
					Parent = top,
				}, {
					utility.create("UICorner", {CornerRadius = UDim.new(0, 7)}),
				})
				local outlineFill = utility.create("Frame", {
					Name = "fill",
					BackgroundColor3 = Color3.fromRGB(20, 20, 20),
					BorderSizePixel = 0,
					Position = UDim2.new(0, 0, 0.5, 0),
					Size = UDim2.new(1, 0, 0.5, 0),
					ZIndex = 10,
					Parent = outline,
				})
				local header = utility.create("Frame", {
					Name = "header",
					BackgroundColor3 = Color3.fromRGB(15, 15, 15),
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 32),
					ZIndex = 10,
					Parent = top,
				}, {
					utility.create("UICorner", {CornerRadius = UDim.new(0, 6)}),
				})
				local headerFill = utility.create("Frame", {
					Name = "fill",
					BackgroundColor3 = Color3.fromRGB(15, 15, 15),
					BorderSizePixel = 0,
					Position = UDim2.new(0, 0, 0.5, 0),
					Size = UDim2.new(1, 0, 0.5, 0),
					ZIndex = 10,
					Parent = header,
				})
				local titleLabel = utility.create("TextLabel", {
					Name = "title",
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(12, 0),
					Size = UDim2.new(1, (config.collapsible or config.collapsed ~= nil) and -44 or -24, 1, 0),
					Text = config.title or "groupbox",
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium),
					ZIndex = 11,
					Parent = header,
				})
				local body = utility.create("Frame", {
					Name = "items",
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.Y,
					Position = UDim2.fromOffset(0, 33),
					Size = UDim2.new(1, 0, 0, 0),
					ZIndex = 10,
					Parent = box,
				}, {
					utility.create("UIListLayout", {Name = "UIListLayout", Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}),
					utility.create("UIPadding", {
						PaddingTop = UDim.new(0, 8),
						PaddingBottom = UDim.new(0, 8),
						PaddingLeft = UDim.new(0, 8),
						PaddingRight = UDim.new(0, 8),
					}),
				})

				local depth = zSync(box, body)
				local columnDepth = zSync(column, column)
				columnDepth(box)
				local groupbox = redirect(body, function(holder)
					local element = holder:FindFirstChildWhichIsA("GuiObject")
					if element then
						utility.stackDropdown(element)
					end
					depth(holder)
				end)
				rawset(groupbox, "frame", box)
				rawset(groupbox, "setTitle", function(_, text)
					titleLabel.Text = tostring(text)
				end)

				if config.collapsible == true or config.collapsed ~= nil then
					local collapsed = config.collapsed == true
					local quart, out = Enum.EasingStyle.Quart, Enum.EasingDirection.Out
					titleLabel.ZIndex = 11
					local chevron = utility.create("ImageLabel", {
						Name = "chevron",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -10, 0.5, 0),
						Size = UDim2.fromOffset(14, 14),
						BackgroundTransparency = 1,
						Image = "rbxassetid://10709791523",
						ImageColor3 = Color3.fromRGB(100, 100, 100),
						Rotation = collapsed and 90 or 180,
						ZIndex = 11,
						Parent = header,
					})

					local function fullHeight()
						return 33 + body.AbsoluteSize.Y
					end
					local animating = false
					local token = 0
					box.AutomaticSize = Enum.AutomaticSize.None
					box.ClipsDescendants = collapsed
					box.Size = UDim2.new(1, 0, 0, collapsed and 32 or fullHeight())
					headerFill.BackgroundTransparency = collapsed and 1 or 0
					outlineFill.BackgroundTransparency = collapsed and 1 or 0
					body:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
						if not collapsed and not animating then
							box.Size = UDim2.new(1, 0, 0, fullHeight())
						end
					end)

					local function setCollapsed(state)
						if state == collapsed then return end
						collapsed = state
						token += 1
						local mine = token
						animating = true
						box.ClipsDescendants = true
						utility.tween(chevron, 0.4, {Rotation = collapsed and 90 or 180}, quart, out)
						utility.tween(box, 0.45, {Size = UDim2.new(1, 0, 0, collapsed and 32 or fullHeight())}, quart, out)
						if collapsed then
							task.delay(0.3, function()
								if mine == token then
									utility.tween(headerFill, 0.15, {BackgroundTransparency = 1}, quart, out)
									utility.tween(outlineFill, 0.15, {BackgroundTransparency = 1}, quart, out)
								end
							end)
						else
							headerFill.BackgroundTransparency = 0
							outlineFill.BackgroundTransparency = 0
						end
						task.delay(0.45, function()
							if mine ~= token then return end
							animating = false
							if not collapsed then
								box.ClipsDescendants = false
								box.Size = UDim2.new(1, 0, 0, fullHeight())
							end
						end)
					end

					header.InputBegan:Connect(function(input)
						if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
						if not utility.isTop(header, input.Position.X, input.Position.Y) then return end
						setCollapsed(not collapsed)
					end)
					header.MouseEnter:Connect(function()
						utility.tween(chevron, 0.25, {ImageColor3 = Color3.fromRGB(170, 170, 170)}, quart, out)
					end)
					header.MouseLeave:Connect(function()
						utility.tween(chevron, 0.3, {ImageColor3 = Color3.fromRGB(100, 100, 100)}, quart, out)
					end)

					rawset(groupbox, "collapse", function(_, state)
						setCollapsed(state ~= false)
					end)
					rawset(groupbox, "expand", function()
						setCollapsed(false)
					end)
					rawset(groupbox, "toggle", function()
						setCollapsed(not collapsed)
					end)
					rawset(groupbox, "collapsed", function()
						return collapsed
					end)

					window.subPageSelectors = window.subPageSelectors or {}
					window.subPageSelectors[body] = function()
						if collapsed then
							setCollapsed(false)
							return true
						end
						return false
					end
				end

				if tab.content then
					tab.content:GetPropertyChangedSignal("Visible"):Connect(function()
						if not tab.content.Visible then return end
						task.defer(function()
							local settings = library.animation
							local baseDelay = (box.LayoutOrder - 1) * settings.elementStagger
							animate(top, baseDelay)
							local boxStroke = box:FindFirstChildOfClass("UIStroke")
							if boxStroke then
								boxStroke.Transparency = 1
								task.delay(baseDelay, function()
									if tab.content.Visible then
										utility.tween(boxStroke, settings.elementFade, {Transparency = 0}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
									else
										boxStroke.Transparency = 0
									end
								end)
							end
							local items = {}
							for _, holder in body:GetChildren() do
								if holder:IsA("GuiObject") and holder.Visible then
									table.insert(items, holder)
								end
							end
							table.sort(items, function(a, b)
								return a.LayoutOrder < b.LayoutOrder
							end)
							for index, holder in items do
								local element = holder:FindFirstChildWhichIsA("GuiObject")
								if element then
									animate(element, baseDelay + math.min(index - 1, settings.maxStagger) * settings.elementStagger)
								end
							end
						end)
					end)
				end

				return groupbox
			end


			--------------------------------------
			-- sections --------------------------
			--------------------------------------

			function tab:createSection(config)
				if type(config) == "string" then
					config = {title = config}
				end
				config = config or {}
				local frame = utility.create("Frame", {
					Name = "section",
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.Y,
					Size = UDim2.new(1, 0, 0, 0),
					ZIndex = 10,
				})
				local header = utility.create("Frame", {
					Name = "header",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 24),
					ZIndex = 10,
					Parent = frame,
				})
				local label = utility.create("TextLabel", {
					Name = "title",
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.X,
					Position = UDim2.fromOffset(4, 0),
					Size = UDim2.new(0, 0, 1, 0),
					Text = string.upper(config.title or "section"),
					TextColor3 = Color3.fromRGB(100, 100, 100),
					TextSize = 11,
					FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
					ZIndex = 10,
					Parent = header,
				})
				local line = utility.create("Frame", {
					Name = "line",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 60, 0.5, 0),
					Size = UDim2.new(1, -60, 0, 1),
					BorderSizePixel = 0,
					BackgroundColor3 = Color3.fromRGB(20, 20, 20),
					ZIndex = 10,
					Parent = header,
				})
				local function placeLine()
					local start = 4 + label.AbsoluteSize.X + 10
					local tail = header:FindFirstChild("chevron") and 28 or 0
					line.Position = UDim2.new(0, start, 0.5, 0)
					line.Size = UDim2.new(1, -start - tail, 0, 1)
				end
				label:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeLine)
				task.defer(placeLine)

				local body = utility.create("Frame", {
					Name = "items",
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.Y,
					Position = UDim2.fromOffset(0, 30),
					Size = UDim2.new(1, 0, 0, 0),
					ZIndex = 10,
					Parent = frame,
				}, {
					utility.create("UIListLayout", {Name = "UIListLayout", Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}),
					utility.create("UIPadding", {PaddingBottom = UDim.new(0, 6)}),
				})

				local depth = zSync(frame, body)
				local section = redirect(body, function(holder)
					depth(holder)
				end)
				rawset(section, "frame", frame)
				rawset(section, "setTitle", function(_, text)
					label.Text = string.upper(tostring(text))
				end)

				if config.collapsible == true or config.collapsed ~= nil then
					local collapsed = config.collapsed == true
					local quart, out = Enum.EasingStyle.Quart, Enum.EasingDirection.Out
					local layout = body.UIListLayout
					local chevron = utility.create("ImageLabel", {
						Name = "chevron",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -4, 0.5, 0),
						Size = UDim2.fromOffset(14, 14),
						BackgroundTransparency = 1,
						Image = "rbxassetid://10709791523",
						ImageColor3 = Color3.fromRGB(100, 100, 100),
						Rotation = collapsed and 90 or 180,
						ZIndex = 10,
						Parent = header,
					})
					task.defer(placeLine)

					local function fullHeight()
						return 30 + layout.AbsoluteContentSize.Y + 6
					end
					local animating = false
					local token = 0
					frame.AutomaticSize = Enum.AutomaticSize.None
					frame.ClipsDescendants = collapsed
					frame.Size = UDim2.new(1, 0, 0, collapsed and 24 or fullHeight())
					layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
						if not collapsed and not animating then
							frame.Size = UDim2.new(1, 0, 0, fullHeight())
						end
					end)

					local function setCollapsed(state)
						if state == collapsed then return end
						collapsed = state
						token += 1
						local mine = token
						animating = true
						frame.ClipsDescendants = true
						utility.tween(chevron, 0.4, {Rotation = collapsed and 90 or 180}, quart, out)
						utility.tween(frame, 0.45, {Size = UDim2.new(1, 0, 0, collapsed and 24 or fullHeight())}, quart, out)
						task.delay(0.45, function()
							if mine ~= token then return end
							animating = false
							if not collapsed then
								frame.ClipsDescendants = false
								frame.Size = UDim2.new(1, 0, 0, fullHeight())
							end
						end)
					end

					header.InputBegan:Connect(function(input)
						if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
						if not utility.isTop(header, input.Position.X, input.Position.Y) then return end
						setCollapsed(not collapsed)
					end)
					header.MouseEnter:Connect(function()
						utility.tween(label, 0.25, {TextColor3 = Color3.fromRGB(170, 170, 170)}, quart, out)
						utility.tween(chevron, 0.25, {ImageColor3 = Color3.fromRGB(170, 170, 170)}, quart, out)
					end)
					header.MouseLeave:Connect(function()
						utility.tween(label, 0.3, {TextColor3 = Color3.fromRGB(100, 100, 100)}, quart, out)
						utility.tween(chevron, 0.3, {ImageColor3 = Color3.fromRGB(100, 100, 100)}, quart, out)
					end)

					rawset(section, "collapse", function(_, state)
						setCollapsed(state ~= false)
					end)
					rawset(section, "expand", function()
						setCollapsed(false)
					end)
					rawset(section, "toggle", function()
						setCollapsed(not collapsed)
					end)
					rawset(section, "collapsed", function()
						return collapsed
					end)

					window.subPageSelectors = window.subPageSelectors or {}
					window.subPageSelectors[body] = function()
						if collapsed then
							setCollapsed(false)
							return true
						end
						return false
					end
				end

				frame.AncestryChanged:Connect(function()
					local holder = frame.Parent
					if holder and holder ~= tab.list and holder:GetAttribute("entranceHolder") then
						holder:SetAttribute("entranceHolder", false)
					end
				end)
				frame.Parent = tab.list

				if tab.content then
					tab.content:GetPropertyChangedSignal("Visible"):Connect(function()
						if not tab.content.Visible then return end
						task.defer(function()
							local before = 0
							for _, child in tab.list:GetChildren() do
								if child ~= frame and child ~= frame.Parent and child:IsA("GuiObject") and child.Visible and child.AbsolutePosition.Y < frame.AbsolutePosition.Y then
									before += 1
								end
							end
							local settings = library.animation
							local baseDelay = math.min(before, settings.maxStagger) * settings.elementStagger
							animate(header, baseDelay)
							local items = {}
							for _, holder in body:GetChildren() do
								if holder:IsA("GuiObject") and holder.Visible then
									table.insert(items, holder)
								end
							end
							table.sort(items, function(a, b)
								return a.LayoutOrder < b.LayoutOrder
							end)
							for index, holder in items do
								local element = holder:FindFirstChildWhichIsA("GuiObject")
								if element then
									animate(element, baseDelay + math.min(index - 1, settings.maxStagger) * settings.elementStagger)
								end
							end
						end)
					end)
				end

				return section
			end


			--------------------------------------
			-- sub-tabs --------------------------
			--------------------------------------

			function tab:createSubTabs(config)
				config = config or {}
				local names = {}
				local startNames = config.tabs or config.options or {}
				local current
				local barHeight, gap, indent, spineX, padding, bottom = 32, 8, 20, 9, 6, 8

				local frame = utility.create("Frame", {
					Name = "subTabs",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, barHeight),
					ZIndex = 10,
				})

				local bar = utility.create("Frame", {
					Name = "bar",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, barHeight),
					ZIndex = 10,
					Parent = frame,
				})
				utility.create("Frame", {
					Name = "divider",
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 0, 1, 0),
					Size = UDim2.new(1, 0, 0, 1),
					BorderSizePixel = 0,
					BackgroundColor3 = Color3.fromRGB(20, 20, 20),
					ZIndex = 10,
					Parent = bar,
				})
				local underline = utility.create("Frame", {
					Name = "underline",
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 0, 1, 0),
					Size = UDim2.fromOffset(0, 2),
					BorderSizePixel = 0,
					BackgroundColor3 = accent,
					ZIndex = 12,
					Parent = bar,
				}, {
					utility.create("UICorner", {CornerRadius = UDim.new(1, 0)}),
				})

				local spine = utility.create("Frame", {
					Name = "spine",
					Position = UDim2.fromOffset(spineX, barHeight),
					Size = UDim2.fromOffset(1, 0),
					BorderSizePixel = 0,
					BackgroundColor3 = guideColor,
					ZIndex = 10,
					Parent = frame,
				})
				local ticks = {}

				local container = utility.create("Frame", {
					Name = "pages",
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(indent, barHeight + gap),
					Size = UDim2.new(1, -indent, 0, 0),
					ZIndex = 10,
					Parent = frame,
				})

				local pages, buttons, proxies, textWidths = {}, {}, {}, {}
				local result = {frame = frame}
				local depth = zSync(frame, container)
				local switchToken = 0

				local function heightOf(name)
					local page = pages[name]
					return page and page.UIListLayout.AbsoluteContentSize.Y or 0
				end

				local function itemsOf(name)
					local page = pages[name]
					local items = {}
					if not page then return items end
					for _, child in page:GetChildren() do
						if child:IsA("GuiObject") and child.Visible then
							table.insert(items, child)
						end
					end
					table.sort(items, function(a, b)
						return a.LayoutOrder < b.LayoutOrder
					end)
					return items
				end

				local function spots(name)
					local results = {}
					local y = 0
					for _, holder in itemsOf(name) do
						local height = holder.AbsoluteSize.Y
						table.insert(results, barHeight + gap + y + math.floor(height / 2))
						y += height + padding
					end
					return results
				end

				local function drawTree(name, time, fresh, baseDelay)
					local points = spots(name)
					local last = points[#points] or barHeight
					local spineLength = math.max(last - barHeight, 0)
					if fresh then
						spine.Size = UDim2.fromOffset(1, 0)
					end
					if time and time > 0 then
						task.delay(fresh and (baseDelay or 0) or 0, function()
							utility.tween(spine, time, {Size = UDim2.fromOffset(1, spineLength)}, quart, out)
						end)
					else
						spine.Size = UDim2.fromOffset(1, spineLength)
					end
					for index, y in points do
						local tick = ticks[index]
						local isNew = false
						if not tick then
							tick = utility.create("Frame", {
								Name = "tick",
								Position = UDim2.fromOffset(spineX, y),
								Size = UDim2.fromOffset(0, 1),
								BorderSizePixel = 0,
								BackgroundColor3 = guideColor,
								BackgroundTransparency = 1,
								ZIndex = 10,
								Parent = frame,
							})
							ticks[index] = tick
							isNew = true
						end
						tick:SetAttribute("active", true)
						local goal = {Position = UDim2.fromOffset(spineX, y), Size = UDim2.fromOffset(indent - spineX - 3, 1), BackgroundTransparency = 0}
						if time and time > 0 then
							if isNew or fresh then
								tick.Position = UDim2.fromOffset(spineX, y)
								tick.Size = UDim2.fromOffset(0, 1)
								tick.BackgroundTransparency = 1
								task.delay((baseDelay or 0) + 0.1 + (index - 1) * library.animation.elementStagger, function()
									if tick:GetAttribute("active") then
										utility.tween(tick, 0.4, goal, quart, out)
									end
								end)
							else
								utility.tween(tick, time, goal, quart, out)
							end
						else
							for property, value in goal do
								tick[property] = value
							end
						end
					end
					for index = #points + 1, #ticks do
						local tick = ticks[index]
						tick:SetAttribute("active", false)
						utility.tween(tick, 0.2, {BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 1)}, quart, out)
					end
				end

				local function fit(time, fresh, baseDelay)
					local height = heightOf(current)
					if time and time > 0 then
						utility.tween(container, time, {Size = UDim2.new(1, -indent, 0, height)}, quart, out)
						utility.tween(frame, time, {Size = UDim2.new(1, 0, 0, barHeight + gap + height + bottom)}, quart, out)
					else
						container.Size = UDim2.new(1, -indent, 0, height)
						frame.Size = UDim2.new(1, 0, 0, barHeight + gap + height + bottom)
					end
					drawTree(current, time, fresh, baseDelay)
				end

				local clipToken = 0
				local function clip(seconds)
					clipToken += 1
					local token = clipToken
					container.ClipsDescendants = true
					task.delay(seconds, function()
						if token == clipToken then
							container.ClipsDescendants = false
						end
					end)
				end

				local function playPage(name, baseDelay)
					local settings = library.animation
					local stagger = settings.elementStagger
					local holders = itemsOf(name)
					clip(baseDelay + math.max(#holders - 1, 0) * stagger + math.max(settings.elementDuration, settings.elementFade) + 0.05)
					for index, holder in holders do
						local element = holder:FindFirstChildWhichIsA("GuiObject")
						if element then
							animate(element, baseDelay + (index - 1) * stagger)
						end
					end
				end

				local function group(page)
					local fader = utility.create("CanvasGroup", {
						Name = "fader",
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, math.max(page.AbsoluteSize.Y, 1)),
						ZIndex = page.ZIndex,
						Parent = container,
					})
					page.Position = UDim2.fromOffset(0, 0)
					page.Parent = fader
					return fader
				end

				local function ungroup(page, fader)
					if page.Parent == fader then
						page.Parent = container
					end
					fader:Destroy()
				end

				local function slideLine(name, instant)
					local button = buttons[name]
					if not button then return end
					local width = textWidths[name]
					local goal = {
						Position = UDim2.new(0, button.Position.X.Offset + math.floor((button.Size.X.Offset - width) / 2), 1, 0),
						Size = UDim2.fromOffset(width, 2),
					}
					if instant then
						underline.Position = goal.Position
						underline.Size = goal.Size
					else
						utility.tween(underline, 0.45, goal, quart, out)
					end
				end

				local function select(name, instant)
					if not pages[name] then return end
					local previous = current
					current = name
					tab.activeSub = name
					if window.updateCrumb then
						window.updateCrumb()
					end
					local index = table.find(names, name)
					local previousIndex = table.find(names, previous) or index
					local direction = index >= previousIndex and 1 or -1
					switchToken += 1
					local token = switchToken

					for other, button in buttons do
						local color = other == name and activeColor or idleColor
						if instant then
							button.TextColor3 = color
						else
							utility.tween(button, 0.3, {TextColor3 = color}, quart, out)
						end
					end
					slideLine(name, instant)
					if instant then
						for other, page in pages do
							page.Visible = other == name
							page.Position = UDim2.fromOffset(0, 0)
						end
						task.defer(fit, 0)
						return
					end
					if previous == name then return end

					local oldPage, newPage = pages[previous], pages[name]
					for other, page in pages do
						if other ~= previous and other ~= name then
							page.Visible = false
						end
					end

					if oldPage then
						local oldFader = group(oldPage)
						utility.tween(oldFader, 0.2, {GroupTransparency = 1, Position = UDim2.fromOffset(-20 * direction, 0)}, quart, out)
						task.delay(0.21, function()
							ungroup(oldPage, oldFader)
							if current ~= previous then
								oldPage.Visible = false
							end
						end)
					end

					newPage.Visible = true
					newPage.Position = UDim2.fromOffset(0, 0)
					playPage(name, 0.08)
					fit(0.45, true, 0)
				end

				local offset = 0
				local function addPage(name)
					name = tostring(name)
					if pages[name] then
						return proxies[name]
					end
					table.insert(names, name)
					local width = math.ceil(textService:GetTextSize(tostring(name), 13, Enum.Font.Roboto, Vector2.new(1000, 100)).X)
					textWidths[name] = width
					local button = utility.create("TextButton", {
						Name = tostring(name),
						BackgroundTransparency = 1,
						AutoButtonColor = false,
						Position = UDim2.new(0, offset, 0, 0),
						Size = UDim2.new(0, width + 24, 1, -2),
						Text = tostring(name),
						TextColor3 = idleColor,
						TextSize = 13,
						FontFace = regular,
						ZIndex = 13,
						Parent = bar,
					})
					offset += width + 24
					buttons[name] = button
					button.MouseEnter:Connect(function()
						if name ~= current then
							utility.tween(button, 0.25, {TextColor3 = hoverColor}, quart, out)
						end
					end)
					button.MouseLeave:Connect(function()
						if name ~= current then
							utility.tween(button, 0.3, {TextColor3 = idleColor}, quart, out)
						end
					end)
					button.MouseButton1Click:Connect(function()
						if name ~= current then
							select(name)
						end
					end)

					local page = utility.create("Frame", {
						Name = tostring(name),
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						Visible = false,
						ZIndex = 10,
						Parent = container,
					}, {
						utility.create("UIListLayout", {Name = "UIListLayout", Padding = UDim.new(0, padding), SortOrder = Enum.SortOrder.LayoutOrder}),
					})
					pages[name] = page
					window.subPageSelectors = window.subPageSelectors or {}
					window.subPageSelectors[page] = function()
						if current ~= name then
							select(name)
							return true
						end
						return false
					end
					page.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
						if name == current then
							fit(0.3)
						end
					end)
					local pageDepth = zSync(page, page)
					local proxy = redirect(page, function(holder)
						pageDepth(holder)
						depth(page)
					end)
					proxies[name] = proxy
					result[name] = proxy
					if not current then
						current = name
						select(name, true)
					end
					return proxy
				end

				for _, name in startNames do
					addPage(name)
				end
				if config.default and pages[tostring(config.default)] then
					select(tostring(config.default), true)
				end

				frame.AncestryChanged:Connect(function()
					local holder = frame.Parent
					if holder and holder ~= tab.list and holder:GetAttribute("entranceHolder") then
						holder:SetAttribute("entranceHolder", false)
					end
				end)
				frame.Parent = tab.list

				if tab.content then
					tab.content:GetPropertyChangedSignal("Visible"):Connect(function()
						if not tab.content.Visible then return end
						task.defer(function()
							local before = 0
							for _, child in tab.list:GetChildren() do
								if child ~= frame and child ~= frame.Parent and child:IsA("GuiObject") and child.Visible and child.AbsolutePosition.Y < frame.AbsolutePosition.Y then
									before += 1
								end
							end
							local settings = library.animation
							local baseDelay = math.min(before, settings.maxStagger) * settings.elementStagger
							animate(bar, baseDelay)
							playPage(current, baseDelay)
							fit(0.6, true, baseDelay)
						end)
					end)
				end

				result.createTab = function(_, tabConfig)
					local name = type(tabConfig) == "table" and (tabConfig.name or tabConfig.title) or tabConfig
					return addPage(name or ("tab " .. (#names + 1)))
				end
				result.page = function(_, name)
					return proxies[name]
				end
				result.select = function(_, name)
					select(name)
				end
				result.value = function()
					return current
				end

				return result
			end
		end

		local placed = 0
		local seen = {}
		for _, child in tab.list:GetChildren() do
			seen[child] = true
		end
		for key, method in pairs(tab) do
			if type(method) == "function" and string.sub(key, 1, 6) == "create" then
				tab[key] = function(self, config, ...)
					local mark = #library.connections
					local result = method(self, config, ...)
					local flag = type(config) == "table" and config.flag ~= nil and type(result) == "table" and tostring(config.flag) or nil
					if flag then
						library:registerFlag(flag, key, result)
					end
					local found
					local frame = type(result) == "table" and rawget(result, "frame")
					if typeof(frame) == "Instance" then
						local object = frame
						while object and object.Parent ~= tab.list do
							object = object.Parent
						end
						if object and not seen[object] then
							found = object
						end
					end
					if not found then
						for _, child in tab.list:GetChildren() do
							if not seen[child] and child:IsA("GuiObject") and not child:GetAttribute("entranceHolder") then
								found = child
								break
							end
						end
					end
					if found and flag then
						found.Destroying:Connect(function()
							library:removeFlag(flag, result)
						end)
					end
					if found then
						seen[found] = true
						local owned = {}
						for index = mark + 1, #library.connections do
							table.insert(owned, library.connections[index])
						end
						if #owned > 0 then
							found.Destroying:Connect(function()
								for _, connection in owned do
									connection:Disconnect()
								end
							end)
						end
					end
					for _, child in (found and {found} or {}) do
						do
							local info = type(config) == "table" and config or {}
							placed += 1
							local layoutOrder = type(info.order) == "number" and info.order or placed
							child.LayoutOrder = layoutOrder
							for _, inner in child:GetChildren() do
								if inner:IsA("GuiObject") and inner:GetAttribute("wrapped") then
									inner.LayoutOrder = layoutOrder
								end
							end
							if key == "createDivider" then
								break
							end
							table.insert(searchIndex, {
								tab = tab,
								frame = child,
								kind = string.lower((string.gsub(string.sub(key, 7), "(%l)(%u)", "%1 %2"))),
								title = tostring(info.title or info.text or string.lower((string.gsub(string.sub(key, 7), "(%l)(%u)", "%1 %2")))),
								description = tostring(info.description or ""),
							})
							if info.tooltip then
								window:tooltip(child, info.tooltip)
							end
							break
						end
					end
					return result
				end
			end
		end

		if tab.list then
			local list = tab.list
			for _, child in list:GetChildren() do
				if child:IsA("GuiObject") then
					task.defer(wrapElement, list, child)
				end
			end
			table.insert(library.connections, list.ChildAdded:Connect(function(child)
				if child:IsA("GuiObject") and not child:GetAttribute("entranceHolder") then
					task.defer(wrapElement, list, child)
				end
			end))
		end

		return tab
	end


	--------------------------------------
	-- tab selection ---------------------
	--------------------------------------

	function window:selectTab(target)
		if not target or currentTab == target or target.isDrawer then return end

		currentTab = target

		for _, tab in ipairs(tabs) do
			local button = tab.button
			local content = tab.content

			local isActive = tab == target

			if button then
				local icon = button:FindFirstChild("icon")
				local label = button:FindFirstChild("label")

				local goalColor = isActive and Color3.fromRGB(200, 200, 200) or Color3.fromRGB(100, 100, 100)

				if icon then
					tweenService:Create(icon, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						ImageColor3 = goalColor
					}):Play()
				end

				if label then
					tweenService:Create(label, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						TextColor3 = goalColor
					}):Play()
				end
			end

			if content then
				if isActive then
					content.Visible = true
					content.GroupTransparency = 1
					content.Position = UDim2.new(0, 0, 0, 0)
					playEntrance(tab)

					task.delay(0.12, function()
						if currentTab ~= tab then return end

						tweenService:Create(content, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
							GroupTransparency = 0,
						}):Play()
					end)
				else
					tweenService:Create(content, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						GroupTransparency = 1
					}):Play()

					task.delay(0.15, function()
						if currentTab ~= tab then
							content.Visible = false
						end
					end)
				end
			end
		end
	end


	--------------------------------------
	-- status bar ------------------------
	--------------------------------------

	local tags = {}
	function window:createStatusBar(config)
		if window.statusBar then
			return window.statusBar
		end
		config = config or {}
		local height = 24
		local bar = utility.create("Frame", {
			Name = "status",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, height),
			BackgroundTransparency = 1,
			ZIndex = 14,
			Parent = canvas,
		}, {
			utility.create("Frame", {
				Name = "line",
				Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = Color3.fromRGB(20, 20, 20),
				BorderSizePixel = 0,
				ZIndex = 14,
			}),
			utility.create("Frame", {
				Name = "left",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(12, 1),
				Size = UDim2.new(0.5, -12, 1, -1),
				ZIndex = 14,
			}, {
				utility.create("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 12),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			}),
			utility.create("Frame", {
				Name = "right",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -24, 0, 1),
				Size = UDim2.new(0.5, -24, 1, -1),
				ZIndex = 14,
			}, {
				utility.create("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 12),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			}),
		})

		local side = canvas:FindFirstChild("sidebar")
		if side then
			side.Size = UDim2.new(side.Size.X.Scale, side.Size.X.Offset, 1, -height)
			local divider = side:FindFirstChild("divider")
			if divider then
				divider.Size = UDim2.new(divider.Size.X.Scale, divider.Size.X.Offset, 1, -divider.Position.Y.Offset)
			end
		end
		local holder = canvas.content:FindFirstChild("container")
		if holder then
			holder.Size = UDim2.new(1, 0, 1, -50 - height)
		end
		canvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			bar.Visible = canvas.AbsoluteSize.Y > 120
		end)

		local order = 0
		local status = {frame = bar}
		function status:add(name, value, where)
			order += 1
			local label = utility.create("TextLabel", {
				Name = name or "item",
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				BackgroundTransparency = 1,
				RichText = true,
				Text = "",
				TextColor3 = Color3.fromRGB(150, 150, 150),
				TextSize = 11,
				FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium),
				LayoutOrder = order,
				ZIndex = 14,
				Parent = where == "right" and bar.right or bar.left,
			})
			local item = {label = label}
			function item:set(newValue)
				value = newValue
				if name then
					label.Text = '<font color="#555555">' .. name .. "</font>  " .. tostring(value)
				else
					label.Text = tostring(value)
				end
			end
			function item:remove()
				label:Destroy()
			end
			item:set(value == nil and "" or value)
			return item
		end

		function status:addBind(name, where)
			order += 1
			local quart, out = Enum.EasingStyle.Quart, Enum.EasingDirection.Out
			local holder = utility.create("Frame", {
				Name = "bind",
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				BackgroundTransparency = 1,
				LayoutOrder = -order,
				ZIndex = 14,
				Parent = where == "right" and bar.right or bar.left,
			}, {
				utility.create("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 6),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			})
			utility.create("TextLabel", {
				Name = "label",
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = name or "toggle",
				TextColor3 = Color3.fromRGB(85, 85, 85),
				TextSize = 11,
				FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium),
				LayoutOrder = 1,
				ZIndex = 14,
				Parent = holder,
			})
			local pill = utility.create("TextButton", {
				Name = "key",
				AutoButtonColor = false,
				Size = UDim2.new(0, 20, 0, 16),
				BackgroundColor3 = Color3.fromRGB(20, 20, 20),
				Text = "",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 10,
				FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium),
				LayoutOrder = 2,
				ZIndex = 14,
				Parent = holder,
			}, {
				utility.create("UICorner", {CornerRadius = UDim.new(0, 4)}),
				utility.create("UIStroke", {Name = "UIStroke", Color = Color3.fromRGB(25, 25, 25), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}),
				utility.create("UIShadow", {
					Name = "UIShadow",
					Offset = UDim2.new(0, 0, 0, 0),
					Transparency = 0.5,
					BlurRadius = UDim.new(0, 10),
					Color = Color3.fromRGB(0, 0, 0),
					ZIndex = 1,
					Spread = UDim2.new(0, 0, 0, 0),
					Enabled = true,
				}),
			})

			local binding = false
			local function keyText()
				local key = library.toggleKey
				return key and key.Name or "none"
			end
			local function show(text)
				pill.Text = text
				task.defer(function()
					utility.tween(pill, 0.3, {Size = UDim2.new(0, pill.TextBounds.X + 12, 0, 16)}, quart, out)
					pill.TextTransparency = 1
					tweenService:Create(pill, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
				end)
			end
			show(keyText())

			pill.MouseEnter:Connect(function()
				utility.tween(pill.UIStroke, 0.25, {Color = Color3.fromRGB(30, 30, 30)}, quart, out)
			end)
			pill.MouseLeave:Connect(function()
				utility.tween(pill.UIStroke, 0.3, {Color = Color3.fromRGB(25, 25, 25)}, quart, out)
			end)
			pill.MouseButton1Click:Connect(function()
				if binding then return end
				binding = true
				library.bindingToggle = true
				show("...")
				local listen
				listen = userInputService.InputBegan:Connect(function(input)
					if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
					listen:Disconnect()
					binding = false
					task.delay(0.1, function()
						library.bindingToggle = false
					end)
					if input.KeyCode ~= Enum.KeyCode.Escape then
						window:setToggleKey(input.KeyCode)
					end
					show(keyText())
				end)
				table.insert(library.connections, listen)
			end)

			local previous = window.onToggleKeyChanged
			window.onToggleKeyChanged = function(bind)
				if previous then
					previous(bind)
				end
				if not binding then
					show(keyText())
				end
			end

			local item = {frame = holder}
			function item:remove()
				holder:Destroy()
			end
			return item
		end

		if config.text then
			status:add(nil, config.text, "left")
		end
		if config.fps or config.ping then
			local fpsItem = config.fps and status:add("fps", "--", "right")
			local pingItem = config.ping and status:add("ping", "--", "right")
			local frames, elapsed = 0, 0
			table.insert(library.connections, runService.Heartbeat:Connect(function(dt)
				frames += 1
				elapsed += dt
				if elapsed < 0.5 then return end
				if fpsItem then
					fpsItem:set(math.floor(frames / elapsed + 0.5))
				end
				if pingItem then
					pingItem:set(math.floor(player:GetNetworkPing() * 1000 + 0.5) .. "ms")
				end
				frames, elapsed = 0, 0
			end))
		end

		if config.bind then
			status:addBind(type(config.bind) == "string" and config.bind or "toggle", "left")
		end

		window.statusBar = status
		return status
	end


	--------------------------------------
	-- tags ------------------------------
	--------------------------------------

	function window:createTag(name, color)
		local tagName = name or "NEW"
		local tagColor = color or Color3.fromRGB(255, 255, 255)

		local tag = utility.create("Frame", {
			AnchorPoint = Vector2.new(0, 0),
			BackgroundTransparency = 0,
			Name = tagName,
			Position = UDim2.new(0, 0, 0, 0),
			Visible = true,
			ZIndex = 1,
			BackgroundColor3 = tagColor,
			Size = UDim2.new(0, 40, 0, 14),
			Parent = window.topbar.tags
		}, {
			utility.create("UICorner", {
				Name = "UICorner",
				CornerRadius = UDim.new(0, 3),
			}),
			utility.create("UIStroke", {
				Name = "UIStroke",
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = tagColor,
				Thickness = 1,
				BorderOffset = UDim.new(0, 1),
				BorderStrokePosition = Enum.BorderStrokePosition.Outer,
				ZIndex = 1,
			}),
			utility.create("TextLabel", {
				Visible = true,
				FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
				TextColor3 = utility.contrast(tagColor),
				ZIndex = 1,
				Text = tagName,
				Name = "label",
				TextXAlignment = Enum.TextXAlignment.Center,
				AnchorPoint = Vector2.new(0.5, 0.5),
				TextSize = 11,
				TextWrapped = false,
				TextScaled = false,
				BackgroundTransparency = 1,
				Position = UDim2.new(0.5, 0, 0.5, 0),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				TextYAlignment = Enum.TextYAlignment.Center,
				Size = UDim2.new(1, 0, 0.8, 0),
			}),
			utility.create("UIShadow", {
				Offset = UDim2.new(0, 0, 0, 0),
				Transparency = .3,
				Name = "UIShadow",
				BlurRadius = UDim.new(0, 5),
				Color = tagColor,
				ZIndex = 1,
				Spread = UDim2.new(0.10000000149011612, 0, 0, 0),
				Enabled = true,
			})
		})

		local label = tag:FindFirstChild("label")
		if label then
			local textWidth = label.TextBounds.X
			tag.Size = UDim2.new(0, textWidth + 15, 0, 14)
		end

		table.insert(tags, tag)
	end


	--------------------------------------
	-- search ----------------------------
	--------------------------------------

	local searchOpen = false
	local searchWidth = 220
	local currentResults = {}
	local white = Color3.fromRGB(255,255,255)
	local gray = Color3.fromRGB(100,100,100)
	local accent = Color3.fromRGB(255,195,9)
	local medium = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal)
	local regular = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)

	local searchResults = utility.create("Frame", {
		Name = "searchResults",
		BackgroundColor3 = Color3.fromRGB(15,15,15),
		AnchorPoint = Vector2.new(1,0),
		Position = UDim2.new(1,-12,0,54),
		Size = UDim2.new(0,searchWidth + 40,0,0),
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 60,
		Parent = canvas,
	}, {
		utility.create("UICorner", {
			CornerRadius = UDim.new(0,5),
		}),
		utility.create("UIStroke", {
			Name = "UIStroke",
			Color = Color3.fromRGB(20,20,20),
			Thickness = 1,
			Transparency = 1,
		}),
		utility.create("UIShadow", {
			Offset = UDim2.new(0,0,0,0),
			Transparency = 0,
			Name = "UIShadow",
			BlurRadius = UDim.new(0,15),
			Color = Color3.fromRGB(0,0,0),
			ZIndex = 1,
			Spread = UDim2.new(0,0,0,0),
			Enabled = true,
		}),
		utility.create("TextLabel", {
			Name = "count",
			BackgroundTransparency = 1,
			Text = "",
			TextColor3 = white,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(12,0),
			Size = UDim2.new(0.4,-12,0,34),
			FontFace = medium,
			ZIndex = 61,
		}),
		utility.create("TextLabel", {
			Name = "hint",
			BackgroundTransparency = 1,
			Text = "arrows to move, enter to go",
			TextColor3 = gray,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1,0),
			Position = UDim2.new(1,-12,0,0),
			Size = UDim2.new(0.6,0,0,34),
			FontFace = regular,
			ZIndex = 61,
		}),
		utility.create("Frame", {
			Name = "divider",
			BackgroundColor3 = Color3.fromRGB(20,20,20),
			BorderSizePixel = 0,
			Position = UDim2.new(0,0,0,34),
			Size = UDim2.new(1,0,0,1),
			ZIndex = 61,
		}),
		utility.create("Frame", {
			Name = "list",
			BackgroundTransparency = 1,
			Position = UDim2.new(0,0,0,35),
			Size = UDim2.new(1,0,0,0),
			AutomaticSize = Enum.AutomaticSize.Y,
			ZIndex = 61,
		}, {
			utility.create("UIListLayout", {
				Padding = UDim.new(0,5),
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),
			utility.create("UIPadding", {
				PaddingTop = UDim.new(0,10),
				PaddingBottom = UDim.new(0,10),
				PaddingLeft = UDim.new(0,0),
				PaddingRight = UDim.new(0,0),
			}),
		}),
	})

	local resultList = searchResults.list
	local rowCache = {}
	local tabEntries = {}
	local orderedRows = {}
	local extraRows = {}
	local selectedIndex = 1
	local panelShown = false
	local sine = Enum.EasingStyle.Quart
	local out = Enum.EasingDirection.Out

	local function fitPanel()
		if not panelShown then return end
		utility.tween(searchResults, 0.4, {Size = UDim2.new(0,searchWidth + 40,0,35 + resultList.AbsoluteSize.Y)}, sine, out)
	end

	table.insert(library.connections, resultList:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitPanel))

	local function clearRows()
		for _, row in rowCache do
			row:Destroy()
		end
		table.clear(rowCache)
		table.clear(orderedRows)
		for _, row in extraRows do
			row:Destroy()
		end
		table.clear(extraRows)
	end

	local function showPanel()
		if panelShown then return end
		panelShown = true
		if not searchResults.Visible then
			searchResults.Size = UDim2.new(0,searchWidth + 40,0,0)
			searchResults.Visible = true
		end
		utility.tween(searchResults.UIStroke, 0.15, {Transparency = 0}, sine, out)
		fitPanel()
	end

	local function hidePanel()
		if not panelShown then return end
		panelShown = false
		utility.tween(searchResults.UIStroke, 0.15, {Transparency = 1}, sine, out)
		utility.tween(searchResults, 0.35, {Size = UDim2.new(0,searchWidth + 40,0,0)}, sine, out).Completed:Connect(function()
			if not panelShown then
				searchResults.Visible = false
				clearRows()
			end
		end)
	end

	local function escapeRich(text)
		text = string.gsub(text, "&", "&amp;")
		text = string.gsub(text, "<", "&lt;")
		text = string.gsub(text, ">", "&gt;")
		return text
	end

	local recentSearches = {}
	local recentEntries = {}

	local function highlight(text, query)
		local start, finish = string.find(string.lower(text), query, 1, true)
		if not start then
			return escapeRich(text)
		end
		return escapeRich(string.sub(text, 1, start - 1))
			.. '<font color="#' .. library.theme.accent:ToHex() .. '">' .. escapeRich(string.sub(text, start, finish)) .. "</font>"
			.. escapeRich(string.sub(text, finish + 1))
	end

	local function flash(frame)
		local stroke = utility.create("UIStroke", {
			Color = accent,
			Thickness = 1.5,
			Transparency = 0,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = frame,
		})
		task.delay(0.6, function()
			utility.tween(stroke, 1.1, {Transparency = 1}, sine, out)
			task.delay(0.85, function()
				stroke:Destroy()
			end)
		end)
	end

	local function jumpTo(entry)
		if entry.recent then
			topbar.searchBox.Text = entry.title
			topbar.searchBox:CaptureFocus()
			topbar.searchBox.CursorPosition = #entry.title + 1
			return
		end
		local typed = topbar.searchBox.Text
		if typed ~= "" then
			local existing = table.find(recentSearches, typed)
			if existing then
				table.remove(recentSearches, existing)
			end
			table.insert(recentSearches, 1, typed)
			while #recentSearches > 5 do
				table.remove(recentSearches)
			end
		end
		window:closeSearch()
		if entry.tab.isDrawer and window.openSettings then
			window:openSettings()
		end
		window:selectTab(entry.tab)
		if not entry.frame then return end
		local switched = false
		local node = entry.frame.Parent
		while node and node ~= entry.tab.list do
			local selector = window.subPageSelectors and window.subPageSelectors[node]
			if selector and selector() then
				switched = true
			end
			node = node.Parent
		end
		task.delay(switched and 0.5 or 0.05, function()
			local list = entry.tab.list
			local offset = entry.frame.AbsolutePosition.Y - list.AbsolutePosition.Y + list.CanvasPosition.Y - 14
			utility.tween(list, 0.5, {CanvasPosition = Vector2.new(0, math.max(0, offset))}, sine, out)
			flash(entry.frame)
		end)
	end

	local function setRow(row, active)
		utility.tween(row.bar, 0.3, {Size = UDim2.new(0,2,0,active and 14 or 0)}, sine, out)
		utility.tween(row.content, 0.35, {Position = UDim2.fromOffset(active and 6 or 0,0)}, sine, out)
		utility.tween(row.content.kind, 0.3, {TextColor3 = active and white or gray}, sine, out)
	end

	local function setSelected(index)
		if #orderedRows == 0 then
			selectedIndex = 1
			return
		end
		selectedIndex = math.clamp(index, 1, #orderedRows)
		for i, row in orderedRows do
			setRow(row, i == selectedIndex)
		end
	end

	local function fadeRow(row, delay)
		task.delay(delay, function()
			if not row.Parent then return end
			utility.tween(row, 0.35, {BackgroundTransparency = 0}, sine, out)
			utility.tween(row.UIStroke, 0.35, {Transparency = 0}, sine, out)
			for _, label in row.content:GetChildren() do
				if label:IsA("TextLabel") then
					utility.tween(label, 0.35, {TextTransparency = 0}, sine, out)
				end
			end
		end)
	end

	local function makeRow(entry)
		local row = utility.create("Frame", {
			Name = "result",
			BackgroundColor3 = Color3.fromRGB(20,20,20),
			BackgroundTransparency = 1,
			Size = UDim2.new(1,-20,0,30),
			ZIndex = 62,
			Parent = resultList,
		}, {
			utility.create("UICorner", {
				CornerRadius = UDim.new(0,5),
			}),
			utility.create("UIStroke", {
				Name = "UIStroke",
				Color = Color3.fromRGB(25,25,25),
				Thickness = 1,
				Transparency = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
				LineJoinMode = Enum.LineJoinMode.Round,
				StrokeSizingMode = Enum.StrokeSizingMode.FixedSize,
			}),
			utility.create("UIShadow", {
				Offset = UDim2.new(0, 0, 0, 0),
				Transparency = .65,
				Name = "UIShadow",
				BlurRadius = UDim.new(0, 15),
				Color = Color3.fromRGB(0, 0, 0),
				ZIndex = 1,
				Spread = UDim2.new(0, 0, 0, 0),
				Enabled = true,
			}),
			utility.create("Frame", {
				Name = "bar",
				BackgroundColor3 = accent,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0,0.5),
				Position = UDim2.new(0,6,0.5,0),
				Size = UDim2.new(0,2,0,0),
				ZIndex = 63,
			}, {
				utility.create("UICorner", {
					CornerRadius = UDim.new(1,0),
				}),
			}),
			utility.create("Frame", {
				Name = "content",
				BackgroundTransparency = 1,
				Size = UDim2.new(1,0,1,0),
				Position = UDim2.fromOffset(14,0),
				ZIndex = 63,
			}, {
				utility.create("TextLabel", {
					Name = "title",
					BackgroundTransparency = 1,
					RichText = true,
					Text = "",
					TextColor3 = white,
					TextTransparency = 1,
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					AnchorPoint = Vector2.new(0,0.5),
					Position = UDim2.new(0,10,0.5,0),
					Size = UDim2.new(1,-130,0,14),
					FontFace = regular,
					ZIndex = 64,
				}),
				utility.create("TextLabel", {
					Name = "kind",
					BackgroundTransparency = 1,
					Text = entry.recent and "recent" or entry.kind == "tab" and "tab" or (entry.tab.name .. "  ·  " .. entry.kind),
					TextColor3 = gray,
					TextTransparency = 1,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Right,
					AnchorPoint = Vector2.new(1,0.5),
					Position = UDim2.new(1,-16,0.5,0),
					Size = UDim2.new(0,110,0,14),
					TextTruncate = Enum.TextTruncate.AtEnd,
					FontFace = regular,
					ZIndex = 64,
				}),
			}),
		})

		row.MouseEnter:Connect(function()
			local index = table.find(orderedRows, row)
			if index and index ~= selectedIndex then
				setSelected(index)
			end
		end)

		row.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				jumpTo(entry)
			end
		end)

		return row
	end

	local function infoRow(text, order)
		local label = utility.create("TextLabel", {
			Name = "info",
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = gray,
			TextTransparency = 1,
			TextSize = 12,
			Size = UDim2.new(1,0,0,24),
			LayoutOrder = order,
			FontFace = regular,
			ZIndex = 62,
			Parent = resultList,
		})
		utility.tween(label, 0.4, {TextTransparency = 0}, sine, out)
		table.insert(extraRows, label)
	end

	local function runSearch(query)
		currentResults = {}
		query = string.lower(query or "")
		for _, label in extraRows do
			label:Destroy()
		end
		table.clear(extraRows)
		local recentMode = query == ""
		if recentMode then
			if #recentSearches == 0 or not searchOpen then
				hidePanel()
				return
			end
			for _, text in recentSearches do
				recentEntries[text] = recentEntries[text] or {recent = true, title = text, kind = "recent", description = ""}
				table.insert(currentResults, recentEntries[text])
			end
		end
		for _, tab in (recentMode and {} or tabs) do
			if string.find(string.lower(tab.name), query, 1, true) then
				tabEntries[tab] = tabEntries[tab] or {tab = tab, title = tab.name, kind = "tab", description = ""}
				table.insert(currentResults, tabEntries[tab])
			end
		end
		for _, entry in (recentMode and {} or searchIndex) do
			if entry.frame.Parent and (string.find(string.lower(entry.title), query, 1, true) or string.find(string.lower(entry.description), query, 1, true)) then
				table.insert(currentResults, entry)
			end
		end
		local limit = math.min(#currentResults, 7)
		local keep = {}
		for index = 1, limit do
			keep[currentResults[index]] = true
		end
		for entry, row in rowCache do
			if not keep[entry] then
				row:Destroy()
				rowCache[entry] = nil
			end
		end
		table.clear(orderedRows)
		local fresh = 0
		for index = 1, limit do
			local entry = currentResults[index]
			local row = rowCache[entry]
			if not row then
				row = makeRow(entry)
				rowCache[entry] = row
				fadeRow(row, fresh * 0.05)
				fresh += 1
			end
			row.LayoutOrder = index
			row.content.title.Text = highlight(entry.title, query)
			orderedRows[index] = row
		end
		if #currentResults == 0 then
			infoRow("nothing here, try something else", 1)
		elseif #currentResults > limit then
			infoRow("+" .. (#currentResults - limit) .. " others", limit + 1)
		end
		searchResults.count.Text = recentMode and "recent searches" or (#currentResults == 1 and "1 result" or (#currentResults .. " results"))
		setSelected(1)
		showPanel()
	end

	function window:openSearch()
		if searchOpen then return end
		searchOpen = true
		local bar = topbar.searchBar
		topbar.nav.search:SetAttribute("open", true)
		bar.Visible = true
		bar.Size = UDim2.new(0,0,0,30)
		utility.tween(bar, 0.4, {Size = UDim2.new(0,searchWidth,0,30)}, sine, out)
		utility.tween(topbar.nav.search.icon, 0.4, {ImageColor3 = white}, sine, out)
		task.delay(0.05, function()
			topbar.searchBox:CaptureFocus()
		end)
		task.delay(0.15, function()
			if searchOpen and topbar.searchBox.Text == "" then
				runSearch("")
			end
		end)
	end

	function window:closeSearch()
		if not searchOpen then return end
		searchOpen = false
		topbar.nav.search:SetAttribute("open", nil)
		topbar.searchBox:ReleaseFocus()
		topbar.searchBox.Text = ""
		hidePanel()
		utility.tween(topbar.nav.search.icon, 0.4, {ImageColor3 = gray}, sine, out)
		utility.tween(topbar.searchBar, 0.35, {Size = UDim2.new(0,0,0,30)}, sine, out).Completed:Connect(function()
			if not searchOpen then
				topbar.searchBar.Visible = false
			end
		end)
	end

	local originalToggle = window.toggle
	function window:toggle(state)
		if state == false or (state == nil and window.isOpen) then
			window:closeSearch()
		end
		return originalToggle(self, state)
	end

	topbar.nav.search.MouseButton1Click:Connect(function()
		if searchOpen then
			window:closeSearch()
		else
			window:openSearch()
		end
	end)

	topbar.searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		runSearch(topbar.searchBox.Text)
	end)

	topbar.searchBox.FocusLost:Connect(function(enterPressed)
		if enterPressed and currentResults[selectedIndex] then
			jumpTo(currentResults[selectedIndex])
		end
	end)

	userInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.F and window.isOpen
			and (userInputService:IsKeyDown(Enum.KeyCode.LeftControl) or userInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
			window:openSearch()
		elseif input.KeyCode == Enum.KeyCode.Escape and searchOpen then
			window:closeSearch()
		elseif input.KeyCode == Enum.KeyCode.Down and searchOpen then
			setSelected(selectedIndex + 1)
		elseif input.KeyCode == Enum.KeyCode.Up and searchOpen then
			setSelected(selectedIndex - 1)
		end
	end)


	--------------------------------------
	-- bell ------------------------------
	--------------------------------------

	local nav = topbar.nav.search.Parent
	local quart, easeOut = Enum.EasingStyle.Quart, Enum.EasingDirection.Out
	local bell = utility.create("TextButton", {
		Name = "bell",
		BackgroundColor3 = Color3.fromRGB(10, 10, 10),
		Size = UDim2.new(0, 33, 0, 33),
		Position = topbar.nav.search.Position + UDim2.fromOffset(-38, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		AutoButtonColor = false,
		Text = "",
		ZIndex = 15,
		Parent = nav,
	}, {
		utility.create("UICorner", {CornerRadius = UDim.new(0, 6)}),
		utility.create("ImageLabel", {
			Name = "icon",
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(15, 15),
			Image = "rbxassetid://10709775704",
			ImageColor3 = gray,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 15,
		}),
		utility.create("Frame", {
			Name = "dot",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 6, 0.5, -6),
			Size = UDim2.fromOffset(6, 6),
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 16,
		}, {
			utility.create("UICorner", {CornerRadius = UDim.new(1, 0)}),
			utility.create("UIScale", {Name = "scale", Scale = 0}),
		}),
	})
	local bellBase = bell.Position


	--------------------------------------
	-- breadcrumb ------------------------
	--------------------------------------

	local crumb = utility.create("TextLabel", {
		Name = "breadcrumb",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = bellBase + UDim2.fromOffset(-42, 0),
		Size = UDim2.fromOffset(260, 16),
		BackgroundTransparency = 1,
		RichText = true,
		Text = "",
		TextColor3 = gray,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		FontFace = regular,
		ZIndex = 15,
		Parent = nav,
	})
	local crumbBase = crumb.Position
	local crumbToken = 0
	local crumbHidden = false

	local function crumbText()
		if not currentTab then return "" end
		local text = '<font color="#646464">' .. currentTab.name .. "</font>"
		if currentTab.activeSub then
			text ..= '<font color="#3C3C3C">  ›  </font><font color="#C8C8C8">' .. currentTab.activeSub .. "</font>"
		end
		return text
	end

	local function updateCrumb()
		local text = crumbText()
		if text == crumb.Text then return end
		crumbToken += 1
		local token = crumbToken
		if crumb.Text == "" then
			crumb.Text = text
			return
		end
		utility.tween(crumb, 0.15, {TextTransparency = 1, Position = crumbBase + UDim2.fromOffset(0, -5)}, quart, Enum.EasingDirection.In)
		task.delay(0.15, function()
			if token ~= crumbToken then return end
			crumb.Text = text
			crumb.Position = crumbBase + UDim2.fromOffset(0, 5)
			utility.tween(crumb, 0.35, {TextTransparency = crumbHidden and 1 or 0, Position = crumbBase}, quart, easeOut)
		end)
	end
	window.updateCrumb = updateCrumb

	local baseSelectTab = window.selectTab
	function window:selectTab(target)
		baseSelectTab(self, target)
		updateCrumb()
	end


	--------------------------------------
	-- notification feed -----------------
	--------------------------------------

	local history = {}
	local unread = 0
	local panelOpen = false
	local panelToken = 0
	local panelWidth = 280

	local panel = utility.create("Frame", {
		Name = "notifications",
		BackgroundColor3 = Color3.fromRGB(15, 15, 15),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.fromOffset(panelWidth, 0),
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 60,
		Parent = canvas,
	}, {
		utility.create("UIShadow", {
			Name = "UIShadow",
			Offset = UDim2.new(0, 0, 0, 0),
			Transparency = 0,
			BlurRadius = UDim.new(0, 15),
			Color = Color3.fromRGB(0, 0, 0),
			ZIndex = 1,
			Spread = UDim2.new(0, 0, 0, 0),
			Enabled = true,
		}),
		utility.create("UICorner", {CornerRadius = UDim.new(0, 5)}),
		utility.create("UIStroke", {Name = "UIStroke", Color = Color3.fromRGB(20, 20, 20), Thickness = 1, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}),
		utility.create("TextLabel", {
			Name = "header",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(0.6, -12, 0, 34),
			Text = "notifications",
			TextColor3 = white,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = medium,
			ZIndex = 61,
		}),
		utility.create("TextButton", {
			Name = "clear",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 0),
			Size = UDim2.new(0, 70, 0, 34),
			AutoButtonColor = false,
			Text = "clear all",
			TextColor3 = gray,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Right,
			FontFace = regular,
			ZIndex = 61,
		}),
		utility.create("Frame", {
			Name = "divider",
			Position = UDim2.fromOffset(0, 34),
			Size = UDim2.new(1, 0, 0, 1),
			BorderSizePixel = 0,
			BackgroundColor3 = Color3.fromRGB(20, 20, 20),
			ZIndex = 61,
		}),
	})
	local feed = utility.create("ScrollingFrame", {
		Name = "list",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 35),
		Size = UDim2.new(1, 0, 1, -35),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = Color3.fromRGB(40, 40, 40),
		ZIndex = 61,
		Parent = panel,
	}, {
		utility.create("UIListLayout", {Name = "UIListLayout", Padding = UDim.new(0, 5), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}),
		utility.create("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8)}),
	})

	local function ago(stamp)
		local seconds = math.floor(os.clock() - stamp)
		if seconds < 5 then return "now" end
		if seconds < 60 then return seconds .. "s" end
		if seconds < 3600 then return math.floor(seconds / 60) .. "m" end
		return math.floor(seconds / 3600) .. "h"
	end

	local function panelHeight()
		if #history == 0 then
			return 35 + 48
		end
		return 35 + math.min(feed.UIListLayout.AbsoluteContentSize.Y + 16, 280)
	end

	local function rebuildFeed(animate)
		for _, child in feed:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		if #history == 0 then
			utility.create("TextLabel", {
				Name = "empty",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 32),
				Text = "nothing here yet",
				TextColor3 = gray,
				TextSize = 12,
				FontFace = regular,
				ZIndex = 62,
				Parent = feed,
			})
			return
		end
		for index, entry in history do
			local style = library.notificationTypes[entry.kind] or library.notificationTypes.default
			local row = utility.create("Frame", {
				Name = "entry",
				BackgroundColor3 = Color3.fromRGB(20, 20, 20),
				BackgroundTransparency = animate and 1 or 0,
				Size = UDim2.new(1, -16, 0, entry.body ~= "" and 44 or 30),
				LayoutOrder = index,
				ZIndex = 62,
				Parent = feed,
			}, {
				utility.create("UICorner", {CornerRadius = UDim.new(0, 5)}),
				utility.create("UIStroke", {Name = "UIStroke", Color = Color3.fromRGB(25, 25, 25), Thickness = 1, Transparency = animate and 1 or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}),
				utility.create("Frame", {
					Name = "bar",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 7, 0.5, 0),
					Size = UDim2.new(0, 2, 1, -16),
					BackgroundColor3 = style.color,
					BackgroundTransparency = animate and 1 or 0,
					BorderSizePixel = 0,
					ZIndex = 63,
				}, {
					utility.create("UICorner", {CornerRadius = UDim.new(1, 0)}),
				}),
				utility.create("TextLabel", {
					Name = "title",
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(17, entry.body ~= "" and 7 or 0),
					Size = UDim2.new(1, -70, 0, entry.body ~= "" and 16 or 30),
					Text = entry.title,
					TextColor3 = white,
					TextTransparency = animate and 1 or 0,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					FontFace = medium,
					ZIndex = 63,
				}),
				utility.create("TextLabel", {
					Name = "body",
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(17, 23),
					Size = UDim2.new(1, -30, 0, 14),
					Text = entry.body,
					TextColor3 = Color3.fromRGB(110, 110, 110),
					TextTransparency = animate and 1 or 0,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					FontFace = regular,
					Visible = entry.body ~= "",
					ZIndex = 63,
				}),
				utility.create("TextLabel", {
					Name = "time",
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -10, 0, entry.body ~= "" and 7 or 0),
					Size = UDim2.new(0, 50, 0, entry.body ~= "" and 16 or 30),
					Text = (entry.count > 1 and ("x" .. entry.count .. "  ") or "") .. ago(entry.time),
					TextColor3 = Color3.fromRGB(80, 80, 80),
					TextTransparency = animate and 1 or 0,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Right,
					FontFace = regular,
					ZIndex = 63,
				}),
			})
			if animate then
				task.delay(0.06 + (index - 1) * 0.04, function()
					if not row.Parent then return end
					utility.tween(row, 0.35, {BackgroundTransparency = 0}, quart, easeOut)
					utility.tween(row.UIStroke, 0.35, {Transparency = 0}, quart, easeOut)
					utility.tween(row.bar, 0.35, {BackgroundTransparency = 0}, quart, easeOut)
					for _, name in {"title", "body", "time"} do
						utility.tween(row[name], 0.35, {TextTransparency = 0}, quart, easeOut)
					end
				end)
			end
		end
	end

	local function setDot(visible)
		local dot = bell.dot
		if visible then
			dot.Visible = true
			utility.tween(dot.scale, 0.4, {Scale = 1}, quart, easeOut)
		else
			utility.tween(dot.scale, 0.25, {Scale = 0}, quart, easeOut)
			task.delay(0.26, function()
				if unread == 0 then
					dot.Visible = false
				end
			end)
		end
	end

	local function fitPanel(time)
		task.defer(function()
			if panelOpen then
				utility.tween(panel, time or 0.3, {Size = UDim2.fromOffset(panelWidth, panelHeight())}, quart, easeOut)
			end
		end)
	end

	local function openPanel()
		if panelOpen then return end
		panelOpen = true
		panelToken += 1
		if searchOpen then
			window:closeSearch()
		end
		local right = bell.AbsolutePosition.X + bell.AbsoluteSize.X - canvas.AbsolutePosition.X
		panel.Position = UDim2.fromOffset(right, 54)
		panel.Size = UDim2.fromOffset(panelWidth, 0)
		panel.Visible = true
		rebuildFeed(true)
		unread = 0
		setDot(false)
		utility.tween(panel.UIStroke, 0.2, {Transparency = 0}, quart, easeOut)
		utility.tween(bell.icon, 0.3, {ImageColor3 = white}, quart, easeOut)
		fitPanel(0.45)
	end

	local function closePanel()
		if not panelOpen then return end
		panelOpen = false
		panelToken += 1
		local token = panelToken
		utility.tween(panel, 0.3, {Size = UDim2.fromOffset(panelWidth, 0)}, quart, easeOut)
		utility.tween(panel.UIStroke, 0.25, {Transparency = 1}, quart, easeOut)
		utility.tween(bell.icon, 0.3, {ImageColor3 = gray}, quart, easeOut)
		task.delay(0.32, function()
			if token == panelToken then
				panel.Visible = false
			end
		end)
	end
	window.openNotifications = openPanel
	window.closeNotifications = closePanel

	local function record(config, kind, key, bumped)
		local entry
		if bumped then
			for index, existing in history do
				if existing.key == key then
					entry = table.remove(history, index)
					break
				end
			end
		end
		if entry then
			entry.count += 1
			entry.time = os.clock()
		else
			entry = {title = tostring(config.title or "notification"), body = tostring(config.body or ""), kind = kind, key = key, count = 1, time = os.clock()}
		end
		table.insert(history, 1, entry)
		while #history > 30 do
			table.remove(history)
		end
		if panelOpen then
			rebuildFeed(false)
			fitPanel()
		else
			unread += 1
			setDot(true)
		end
	end
	notification.onAdded = function(config, kind, key)
		record(config, kind, key, false)
	end
	notification.onBumped = function(config, kind, key)
		record(config, kind, key, true)
	end

	panel.clear.MouseEnter:Connect(function()
		utility.tween(panel.clear, 0.25, {TextColor3 = white}, quart, easeOut)
	end)
	panel.clear.MouseLeave:Connect(function()
		utility.tween(panel.clear, 0.3, {TextColor3 = gray}, quart, easeOut)
	end)
	panel.clear.MouseButton1Click:Connect(function()
		table.clear(history)
		rebuildFeed(false)
		fitPanel()
	end)

	bell.MouseEnter:Connect(function()
		utility.tween(bell.icon, 0.5, {ImageColor3 = white})
	end)
	bell.MouseLeave:Connect(function()
		if panelOpen then return end
		utility.tween(bell.icon, 0.5, {ImageColor3 = gray})
	end)
	bell.MouseButton1Click:Connect(function()
		if panelOpen then
			closePanel()
		else
			openPanel()
		end
	end)

	table.insert(library.connections, userInputService.InputBegan:Connect(function(input)
		if not panelOpen then return end
		if input.KeyCode == Enum.KeyCode.Escape then
			closePanel()
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local point = Vector2.new(input.Position.X, input.Position.Y)
		local function inside(gui)
			local position, size = gui.AbsolutePosition, gui.AbsoluteSize
			return point.X >= position.X and point.X <= position.X + size.X and point.Y >= position.Y and point.Y <= position.Y + size.Y
		end
		if not inside(panel) and not inside(bell) then
			closePanel()
		end
	end))

	local function shiftNav(open)
		local offset = open and -(searchWidth + 8) or 0
		crumbHidden = open
		utility.tween(bell, 0.4, {Position = bellBase + UDim2.fromOffset(offset, 0)}, quart, easeOut)
		if window.gearButton then
			utility.tween(window.gearButton, 0.4, {Position = window.gearBase + UDim2.fromOffset(offset, 0)}, quart, easeOut)
		end
		utility.tween(crumb, 0.3, {TextTransparency = open and 1 or 0}, quart, easeOut)
		if open then
			closePanel()
		end
	end

	local baseOpenSearch, baseCloseSearch = window.openSearch, window.closeSearch
	function window:openSearch()
		local was = searchOpen
		baseOpenSearch(self)
		if not was and searchOpen then
			shiftNav(true)
		end
	end
	function window:closeSearch()
		local was = searchOpen
		baseCloseSearch(self)
		if was and not searchOpen then
			shiftNav(false)
		end
	end


	--------------------------------------
	-- settings drawer -------------------
	--------------------------------------

	function window:createSettings(settingsConfig)
		if window.settingsTab then
			return window.settingsTab
		end
		settingsConfig = settingsConfig or {}
		local width = settingsConfig.width or 280
		local white = Color3.fromRGB(255, 255, 255)

		local gear = utility.create("TextButton", {
			Name = "settings",
			BackgroundColor3 = Color3.fromRGB(10, 10, 10),
			Size = UDim2.new(0, 33, 0, 33),
			Position = bellBase + UDim2.fromOffset(-38, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			AutoButtonColor = false,
			Text = "",
			ZIndex = 15,
			Parent = nav,
		}, {
			utility.create("UICorner", {CornerRadius = UDim.new(0, 6)}),
			utility.create("ImageLabel", {
				Name = "icon",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(15, 15),
				Image = "rbxassetid://10734950309",
				ImageColor3 = gray,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 15,
			}),
		})
		window.gearButton = gear
		window.gearBase = gear.Position
		if searchOpen then
			gear.Position = window.gearBase + UDim2.fromOffset(-(searchWidth + 8), 0)
		end
		crumbBase = crumbBase + UDim2.fromOffset(-38, 0)
		crumb.Position = crumbBase

		local shade = utility.create("Frame", {
			Name = "settingsShade",
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 48),
			Size = UDim2.new(1, 0, 1, -48),
			Active = true,
			Visible = false,
			ZIndex = 70,
			Parent = canvas,
		})
		local drawer = utility.create("Frame", {
			Name = "drawer",
			BackgroundColor3 = Color3.fromRGB(10, 10, 10),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, width + 20, 0, 0),
			Size = UDim2.new(0, width, 1, 0),
			ZIndex = 71,
			Parent = shade,
		}, {
			utility.create("UICorner", {CornerRadius = UDim.new(0, 12)}),
			utility.create("UIStroke", {Name = "UIStroke", Color = Color3.fromRGB(20, 20, 20), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}),
			utility.create("UIShadow", {
				Name = "UIShadow",
				Offset = UDim2.new(0, 0, 0, 0),
				Transparency = 0.4,
				BlurRadius = UDim.new(0, 30),
				Color = Color3.fromRGB(0, 0, 0),
				ZIndex = 1,
				Spread = UDim2.new(0, 0, 0, 0),
				Enabled = true,
			}),
		})
		local drawerHeader = utility.create("Frame", {
			Name = "header",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 44),
			ZIndex = 72,
			Parent = drawer,
		})
		utility.create("TextLabel", {
			Name = "title",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(16, 0),
			Size = UDim2.new(1, -60, 1, 0),
			Text = settingsConfig.title or "settings",
			TextColor3 = white,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium),
			ZIndex = 72,
			Parent = drawerHeader,
		})
		local closeButton = utility.create("ImageButton", {
			Name = "close",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			Image = "rbxassetid://10747384394",
			ImageColor3 = gray,
			ZIndex = 72,
			Parent = drawerHeader,
		})
		utility.create("Frame", {
			Name = "divider",
			Position = UDim2.fromOffset(0, 44),
			Size = UDim2.new(1, 0, 0, 1),
			BorderSizePixel = 0,
			BackgroundColor3 = Color3.fromRGB(20, 20, 20),
			ZIndex = 72,
			Parent = drawer,
		})

		local settingsTab = window:createTab({name = settingsConfig.title or "settings", icon = "rbxassetid://10734950309", order = 100000})
		settingsTab.isDrawer = true
		local index = table.find(tabs, settingsTab)
		if index then
			table.remove(tabs, index)
		end
		if settingsTab.button then
			settingsTab.button.Visible = false
		end
		local body = settingsTab.content
		body.Parent = drawer
		body.AnchorPoint = Vector2.new(0, 0)
		body.Position = UDim2.fromOffset(0, 45)
		body.Size = UDim2.new(1, 0, 1, -45)
		body.ZIndex = 72
		body.GroupTransparency = 0
		body.Visible = true
		window.settingsTab = settingsTab

		local open = false
		local token = 0
		local function setOpen(state)
			if state == open then return end
			open = state
			token += 1
			local mine = token
			local quart, out = Enum.EasingStyle.Quart, Enum.EasingDirection.Out
			if state then
				if library.closePopup then
					library.closePopup()
				end
				if window.closeNotifications then
					window.closeNotifications()
				end
				shade.Visible = true
				library.modalFrame = shade
				utility.tween(shade, 0.3, {BackgroundTransparency = 0.5}, quart, out)
				utility.tween(drawer, 0.45, {Position = UDim2.new(1, -8, 0, 8)}, quart, out)
				utility.tween(gear.icon, 0.3, {ImageColor3 = white}, quart, out)
				utility.tween(gear.icon, 0.45, {Rotation = 90}, quart, out)
				playEntrance(settingsTab)
			else
				if library.modalFrame == shade then
					library.modalFrame = nil
				end
				if library.closePopup then
					library.closePopup()
				end
				utility.tween(shade, 0.3, {BackgroundTransparency = 1}, quart, out)
				utility.tween(drawer, 0.35, {Position = UDim2.new(1, width + 20, 0, 8)}, quart, Enum.EasingDirection.In)
				utility.tween(gear.icon, 0.3, {ImageColor3 = gray}, quart, out)
				utility.tween(gear.icon, 0.45, {Rotation = 0}, quart, out)
				task.delay(0.35, function()
					if mine == token then
						shade.Visible = false
					end
				end)
			end
		end
		drawer.Size = UDim2.new(0, width, 1, -16)

		function window:openSettings()
			setOpen(true)
		end
		function window:closeSettings()
			setOpen(false)
		end
		function window:toggleSettings()
			setOpen(not open)
		end

		gear.MouseEnter:Connect(function()
			utility.tween(gear.icon, 0.5, {ImageColor3 = white})
		end)
		gear.MouseLeave:Connect(function()
			if open then return end
			utility.tween(gear.icon, 0.5, {ImageColor3 = gray})
		end)
		gear.MouseButton1Click:Connect(function()
			setOpen(not open)
		end)
		closeButton.MouseEnter:Connect(function()
			utility.tween(closeButton, 0.3, {ImageColor3 = white})
		end)
		closeButton.MouseLeave:Connect(function()
			utility.tween(closeButton, 0.3, {ImageColor3 = gray})
		end)
		closeButton.MouseButton1Click:Connect(function()
			setOpen(false)
		end)
		shade.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
			local spot, area = drawer.AbsolutePosition, drawer.AbsoluteSize
			local x, y = input.Position.X, input.Position.Y
			if x >= spot.X and x <= spot.X + area.X and y >= spot.Y and y <= spot.Y + area.Y then return end
			if library.popupFrame or library.isDialogOpen then return end
			setOpen(false)
		end)
		table.insert(library.connections, userInputService.InputBegan:Connect(function(input)
			if open and input.KeyCode == Enum.KeyCode.Escape and not library.isDialogOpen then
				setOpen(false)
			end
		end))

		local drawerDialog = builder.dialog(shade)


		--------------------------------------
		-- fake filesystem -------------------
		--------------------------------------

		if not (isfolder and makefolder and isfile and writefile and readfile and delfile and listfiles) then
			local fakeFolders = { [""] = true }
			local fakeFiles = {}

			local function normalizePath(path)
				if not path or path == "" then return "" end
				path = tostring(path):gsub("\\", "/")
				path = path:gsub("^/+", "")
				path = path:gsub("/+$", "")
				return path
			end

			isfolder = function(path)
				return fakeFolders[normalizePath(path)] == true
			end

			makefolder = function(path)
				path = normalizePath(path)
				if path == "" then return end
				local current = ""
				for part in path:gmatch("[^/]+") do
					current = (current == "") and part or (current .. "/" .. part)
					fakeFolders[current] = true
				end
			end

			isfile = function(path)
				return fakeFiles[normalizePath(path)] ~= nil
			end

			writefile = function(path, content)
				path = normalizePath(path)
				local parent = path:match("^(.*)/[^/]+$")
				if parent then
					makefolder(parent)
				end
				fakeFiles[path] = tostring(content)
			end

			readfile = function(path)
				return fakeFiles[normalizePath(path)]
			end

			delfile = function(path)
				fakeFiles[normalizePath(path)] = nil
			end

			listfiles = function(path)
				path = normalizePath(path)
				local results = {}
				local prefix = (path == "") and "" or (path .. "/")

				local function isDirectChild(itemPath)
					if itemPath == path or itemPath == "" then return false end
					if string.sub(itemPath, 1, #prefix) == prefix then
						local remainder = string.sub(itemPath, #prefix + 1)
						return not remainder:find("/")
					end
					return false
				end

				for filePath in pairs(fakeFiles) do
					if isDirectChild(filePath) then
						table.insert(results, filePath)
					end
				end

				for folderPath in pairs(fakeFolders) do
					if isDirectChild(folderPath) then
						table.insert(results, folderPath)
					end
				end

				return results
			end
		end


		--------------------------------------
		-- config ----------------------------
		--------------------------------------

		function settingsTab:createConfig(options)

			options = options or {}
			local medium = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium)
			local regular = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular)
			local quart, out = Enum.EasingStyle.Quart, Enum.EasingDirection.Out

			local pad = 10
			local gap = 6
			local top = 44
			local listHeight = options.height or 137
			local rowHeight = 28
			local nameHeight = 23
			local controlHeight = 24

			local nameY = top + listHeight + gap
			local firstRowY = nameY + nameHeight + gap
			local secondRowY = firstRowY + controlHeight + gap
			local total = secondRowY + controlHeight + pad

			local holder = settingsTab:createCustom({name = "config", title = options.title or "configuration", height = total})

			local card = utility.create("Frame", {
				Name = "card",
				BackgroundColor3 = Color3.fromRGB(15, 15, 15),
				Size = UDim2.fromScale(1, 1),
				ZIndex = 10,
				Parent = holder.frame,
			}, {
				utility.create("UICorner", {CornerRadius = UDim.new(0, 5)}),
			})

			utility.create("TextLabel", {
				Name = "title",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 15, 0, 14),
				Size = UDim2.new(1, -110, 0, 13),
				Text = options.title or "configuration",
				TextColor3 = white,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextScaled = true,
				FontFace = medium,
				ZIndex = 10,
				Parent = card,
			})

			local countLabel = utility.create("TextLabel", {
				Name = "count",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, 14),
				Size = UDim2.new(0, 90, 0, 12),
				Text = "0 configs",
				TextColor3 = gray,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextScaled = true,
				FontFace = regular,
				ZIndex = 10,
				Parent = card,
			})

			local container = utility.create("Frame", {
				Name = "container",
				BackgroundColor3 = Color3.fromRGB(20, 20, 20),
				Position = UDim2.fromOffset(pad, top),
				Size = UDim2.new(1, -pad * 2, 0, listHeight),
				ZIndex = 10,
				Parent = card,
			}, {
				utility.create("UICorner", {CornerRadius = UDim.new(0, 6)}),
				utility.create("UIStroke", {Name = "UIStroke", Color = Color3.fromRGB(25, 25, 25), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}),
				utility.create("UIShadow", {Name = "UIShadow", Offset = UDim2.new(0, 0, 0, 0), Transparency = 0.65, BlurRadius = UDim.new(0, 15), Color = Color3.fromRGB(0, 0, 0), ZIndex = 1, Spread = UDim2.new(0, 0, 0, 0), Enabled = true}),
			})

			local list = utility.create("ScrollingFrame", {
				Name = "list",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(5, 5),
				Size = UDim2.new(1, -8, 1, -10),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 2,
				ScrollBarImageColor3 = Color3.fromRGB(40, 40, 40),
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ZIndex = 10,
				Parent = container,
			}, {
				utility.create("UIListLayout", {Name = "layout", SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5)}),
				utility.create("UIPadding", {PaddingTop = UDim.new(0, 1), PaddingBottom = UDim.new(0, 1), PaddingLeft = UDim.new(0, 1), PaddingRight = UDim.new(0, 6)}),
			})

			local empty = utility.create("TextLabel", {
				Name = "empty",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0, top + listHeight / 2),
				Size = UDim2.new(1, -20, 0, 14),
				Text = "no configs",
				TextColor3 = gray,
				TextSize = 13,
				FontFace = regular,
				ZIndex = 10,
				Parent = card,
			})

			local nameBox = utility.create("TextBox", {
				Name = "name",
				BackgroundColor3 = Color3.fromRGB(20, 20, 20),
				Position = UDim2.fromOffset(pad, nameY),
				Size = UDim2.new(1, -pad * 2, 0, nameHeight),
				Text = "",
				PlaceholderText = "config name",
				PlaceholderColor3 = Color3.fromRGB(90, 90, 90),
				TextColor3 = white,
				TextSize = 13,
				ClearTextOnFocus = false,
				FontFace = regular,
				ZIndex = 11,
				Parent = card,
			}, {
				utility.create("UICorner", {CornerRadius = UDim.new(0, 5)}),
				utility.create("UIStroke", {Name = "UIStroke", Color = Color3.fromRGB(25, 25, 25), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}),
				utility.create("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}),
				utility.create("UIShadow", {Name = "UIShadow", Offset = UDim2.new(0, 0, 0, 0), Transparency = 0.65, BlurRadius = UDim.new(0, 15), Color = Color3.fromRGB(0, 0, 0), ZIndex = 1, Spread = UDim2.new(0, 0, 0, 0), Enabled = true}),
			})

			local function makeButton(text, right, y)
				local button = utility.create("TextButton", {
					Name = text,
					BackgroundColor3 = Color3.fromRGB(20, 20, 20),
					AutoButtonColor = false,
					Position = right and UDim2.new(0.5, gap / 2, 0, y) or UDim2.fromOffset(pad, y),
					Size = UDim2.new(0.5, -pad - gap / 2, 0, controlHeight),
					Text = "",
					ZIndex = 11,
					Parent = card,
				}, {
					utility.create("UICorner", {CornerRadius = UDim.new(0, 5)}),
					utility.create("UIStroke", {Name = "UIStroke", Color = Color3.fromRGB(25, 25, 25), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}),
					utility.create("UIShadow", {Name = "UIShadow", Offset = UDim2.new(0, 0, 0, 0), Transparency = 0.65, BlurRadius = UDim.new(0, 15), Color = Color3.fromRGB(0, 0, 0), ZIndex = 1, Spread = UDim2.new(0, 0, 0, 0), Enabled = true}),
					utility.create("TextLabel", {
						Name = "label",
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						Text = text,
						TextColor3 = Color3.fromRGB(200, 200, 200),
						TextSize = 13,
						FontFace = medium,
						ZIndex = 12,
					}),
				})
				return button
			end

			local createButton = makeButton("create", false, firstRowY)
			local deleteButton = makeButton("delete", true, firstRowY)
			local loadButton = makeButton("load", false, secondRowY)
			local saveButton = makeButton("save", true, secondRowY)

			local rows = {}
			local picked
			local count = 0

			local object = {
				frame = holder.frame,
				container = container,
				list = list,
				nameBox = nameBox,
				buttons = {create = createButton, delete = deleteButton, load = loadButton, save = saveButton},
			}

			local function recount()
				local total = 0
				for _ in rows do
					total += 1
				end
				countLabel.Text = total == 1 and "1 config" or (total .. " configs")
				utility.tween(empty, 0.3, {TextTransparency = total == 0 and 0 or 1}, quart, out)
			end

			local function paint(row)
				local on = row.Name == picked
				local hovered = row:GetAttribute("hovered")
				local x = 14 + (on and 6 or 0) + (hovered and 4 or 0)
				utility.tween(row.label, 0.35, {Position = UDim2.new(0, x, 0, 0)}, quart, out)
				utility.tween(row.bar, 0.35, {Size = UDim2.new(0, 2, 0, on and 16 or 0)}, quart, out)
			end

			function object:select(name)
				picked = rows[name] and name or nil
				for _, row in rows do
					paint(row)
				end
				if picked then
					nameBox.Text = picked
				end
			end

			function object:selected()
				return picked
			end

			function object:name()
				return nameBox.Text
			end

			function object:setName(text)
				nameBox.Text = text or ""
			end

			function object:add(name)
				name = tostring(name)
				if name == "" or rows[name] then return end
				count += 1
				local row = utility.create("TextButton", {
					Name = name,
					BackgroundColor3 = Color3.fromRGB(25, 25, 25),
					AutoButtonColor = false,
					Size = UDim2.new(1, 0, 0, rowHeight),
					Text = "",
					LayoutOrder = count,
					ZIndex = 10,
					Parent = list,
				}, {
					utility.create("UICorner", {CornerRadius = UDim.new(0, 5)}),
					utility.create("UIStroke", {Name = "UIStroke", Color = Color3.fromRGB(30, 30, 30), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}),
					utility.create("UIShadow", {Name = "UIShadow", Offset = UDim2.new(0, 0, 0, 0), Transparency = 0.65, BlurRadius = UDim.new(0, 15), Color = Color3.fromRGB(0, 0, 0), ZIndex = 1, Spread = UDim2.new(0, 0, 0, 0), Enabled = true}),
					utility.create("Frame", {
						Name = "bar",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 6, 0.5, 0),
						Size = UDim2.new(0, 2, 0, 0),
						BackgroundColor3 = library.theme.accent,
						BorderSizePixel = 0,
						ZIndex = 11,
					}, {
						utility.create("UICorner", {CornerRadius = UDim.new(1, 0)}),
					}),
					utility.create("TextLabel", {
						Name = "label",
						BackgroundTransparency = 1,
						Position = UDim2.new(0, 14, 0, 0),
						Size = UDim2.new(1, -28, 1, 0),
						Text = name,
						TextColor3 = white,
						TextSize = 14,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						FontFace = medium,
						ZIndex = 11,
					}),
				})
				rows[name] = row
				row.MouseEnter:Connect(function()
					row:SetAttribute("hovered", true)
					paint(row)
				end)
				row.MouseLeave:Connect(function()
					row:SetAttribute("hovered", nil)
					paint(row)
				end)
				row.MouseButton1Click:Connect(function()
					object:select(name)
				end)
				recount()
			end

			function object:remove(name)
				local row = rows[name]
				if not row then return end
				rows[name] = nil
				row:Destroy()
				if picked == name then
					picked = nil
				end
				recount()
			end
			
			function object:clear()
				for name in rows do
					object:remove(name)
				end
			end

			local configFolder = tostring(config.configFolder or "configs"):gsub("^[/\\]+", ""):gsub("[/\\]+$", "")
			local isBusy = false

			if not isfolder(configFolder) then
				pcall(makefolder, configFolder)
			end

			local function sanitizeName(name)
				if type(name) ~= "string" then return nil end
				local clean = name:gsub('[<>:"/\\|%?%*]', ""):match("^%s*(.-)%s*$")
				if not clean or clean == "" then return nil end
				return clean
			end

			local function getPath(name)
				return configFolder .. "/" .. name .. ".json"
			end

			local function getCurrentConfig()
				return library:getFlags()
			end

			local function applyConfig(data)
				library:setFlags(data, true)
			end

			local function saveToFile(name, quiet)
				local cleanName = sanitizeName(name)
				if not cleanName then
					if not quiet then
						library:notify({title = "config", body = "invalid config name", type = "error"})
					end
					return false, "invalid config name"
				end

				if not isfolder(configFolder) then
					pcall(makefolder, configFolder)
				end

				local data = getCurrentConfig()
				local success, encoded = pcall(httpService.JSONEncode, httpService, data)
				if not success then
					if not quiet then
						library:notify({title = "config", body = "failed to encode config", type = "error"})
					end
					return false, "failed to encode config"
				end

				local ok = pcall(writefile, getPath(cleanName), encoded)
				if not ok then
					if not quiet then
						library:notify({title = "config", body = "failed to save config", type = "error"})
					end
					return false, "failed to save config"
				end

				return true
			end

			local function fileListed(name)
				local cleanName = sanitizeName(name)
				if not cleanName then return false end
				return isfile(getPath(cleanName)) == true
			end
			
			local function getConfigFiles()
				local targetFolder = configFolder:gsub("\\", "/"):gsub("^%./", ""):gsub("^/+", ""):gsub("/+$", ""):lower()

				for _, tryPath in ipairs({ targetFolder, "./" .. targetFolder, targetFolder .. "/", "./" .. targetFolder .. "/" }) do
					local ok, files = pcall(listfiles, tryPath)
					if ok and type(files) == "table" and next(files) ~= nil then
						local matched = {}
						for _, file in pairs(files) do
							local norm = tostring(file):gsub("\\", "/"):gsub("^%./", "")
							if norm:lower():find("^" .. targetFolder:gsub("(%W)", "%%%1") .. "/[^/]+%.json$") then
								table.insert(matched, norm)
							end
						end
						if #matched > 0 then
							return matched
						end
					end
				end

				local okRoot, rootFiles = pcall(listfiles, "")
				if okRoot and type(rootFiles) == "table" then
					local matched = {}
					local pattern = "^" .. targetFolder:gsub("(%W)", "%%%1") .. "/[^/]+%.json$"
					for _, file in pairs(rootFiles) do
						local norm = tostring(file):gsub("\\", "/"):gsub("^%./", "")
						if norm:lower():match(pattern) then
							table.insert(matched, norm)
						end
					end
					return matched
				end

				return {}
			end

			local function loadFromFile(name)
				local cleanName = sanitizeName(name)
				if not cleanName then
					library:notify({title = "config", body = "invalid config name", type = "error"})
					return false
				end

				local path = getPath(cleanName)
				if not isfile(path) then
					library:notify({title = "config", body = "config file not found", type = "error"})
					return false
				end

				local ok, content = pcall(readfile, path)
				if not ok or type(content) ~= "string" then
					library:notify({title = "config", body = "failed to read config", type = "error"})
					return false
				end

				local success, data = pcall(httpService.JSONDecode, httpService, content)
				if not success or type(data) ~= "table" then
					library:notify({title = "config", body = "failed to decode config", type = "error"})
					return false
				end

				applyConfig(data)
				library:notify({title = "config", body = 'loaded "' .. cleanName .. '"', type = "success"})
				return true
			end

			local function deleteFile(name)
				local cleanName = sanitizeName(name)
				if not cleanName then return false end

				local path = getPath(cleanName)
				if isfile(path) then
					return pcall(delfile, path)
				end
				return true
			end

			local function refreshList()
				object:clear()
				if not isfolder(configFolder) then return end

				local files = getConfigFiles()
				local seen = {}

				for _, file in pairs(files) do
					local name = tostring(file):match("([^/\\]+)%.json$")
					if name and name ~= "" and not seen[name] then
						seen[name] = true
						object:add(name)
					end
				end
			end

			createButton.MouseButton1Click:Connect(function()
				local name = object:name()
				if name == "" then return end
				if rows[name] then
					object:select(name)
					return
				end
				if saveToFile(name) then
					object:add(name)
					object:select(name)
					library:notify({title = "config", body = "created \"" .. name .. "\"", type = "success"})
				end
			end)

			deleteButton.MouseButton1Click:Connect(function()
				if isBusy then return end
				local name = object:selected()
				if not name or name == "" then return end

				drawerDialog:prompt({
					duration = 4,
					title = "delete config?",
					body = 'are you sure you want to delete "' .. name .. '"?',
					type = "warning",
					danger = true,
					buttons = {"cancel", "delete"},
					callback = function(choice)
						if choice ~= "delete" or isBusy then return end
						isBusy = true

						local note = library:notify({title = "config", body = 'deleting "' .. name .. '"...', type = "loading"})
						local ok = deleteFile(name)

						if not ok then
							isBusy = false
							note:update({type = "error", body = 'failed to delete "' .. name .. '"'})
							return
						end

						task.spawn(function()
							local started = os.clock()
							while fileListed(name) do
								if os.clock() - started >= 10 then
									isBusy = false
									note:update({type = "error", body = '"' .. name .. '" is still there after deleting'})
									return
								end
								task.wait(0.15)
							end
							
							task.wait(1)

							object:remove(name)
							if object:name() == name then
								object:setName("")
							end
							isBusy = false
							note:update({type = "success", body = 'deleted "' .. name .. '"'})
						end)
					end,
				})
			end)

			loadButton.MouseButton1Click:Connect(function()
				if isBusy then return end
				local name = object:selected()
				if not name or name == "" then return end
				loadFromFile(name)
			end)

			saveButton.MouseButton1Click:Connect(function()
				if isBusy then return end
				local cleanName = sanitizeName(object:name())
				if not cleanName then
					library:notify({title = "config", body = "enter a valid config name", type = "error"})
					return
				end

				if object:name() ~= cleanName then
					object:setName(cleanName)
				end

				local function doSave()
					if isBusy then return end
					isBusy = true

					local note = library:notify({title = "config", body = 'saving "' .. cleanName .. '"...', type = "loading"})
					local ok, problem = saveToFile(cleanName, true)

					if not ok then
						isBusy = false
						note:update({type = "error", body = problem or "failed to save config"})
						return
					end

					task.spawn(function()
						local started = os.clock()
						while not fileListed(cleanName) do
							if os.clock() - started >= 10 then
								isBusy = false
								note:update({type = "error", body = 'couldnt find "' .. cleanName .. '" after saving'})
								return
							end
							task.wait(0.15)
						end
						
						task.wait(1)

						if not rows[cleanName] then
							object:add(cleanName)
						end
						object:select(cleanName)
						isBusy = false
						note:update({type = "success", body = 'saved "' .. cleanName .. '"'})
					end)
				end

				if rows[cleanName] then
					drawerDialog:prompt({
						duration = 3,
						title = "overwrite config?",
						body = 'are you sure you want to overwrite "' .. cleanName .. '"?',
						type = "warning",
						danger = true,
						buttons = {"cancel", "overwrite"},
						callback = function(choice)
							if choice == "overwrite" then
								doSave()
							end
						end,
					})
				else
					doSave()
				end
			end)
			
			task.spawn(function()
				task.wait(0.1)

				if not isfolder(configFolder) then
					pcall(makefolder, configFolder)
					return
				end

				local files = {}
				for attempt = 1, 5 do
					files = getConfigFiles()
					if next(files) ~= nil then
						break
					end
					task.wait(0.2)
				end

				object:clear()
				local seen = {}

				for _, file in pairs(files) do
					local name = tostring(file):match("([^/\\]+)%.json$")
					if name and name ~= "" and not seen[name] then
						seen[name] = true
						object:add(name)
					end
				end
			end)

			return object
		end


		--------------------------------------
		-- unload button ---------------------
		--------------------------------------

		function settingsTab:createUnload(options)
			options = options or {}
			local medium = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium)
			local quart, out = Enum.EasingStyle.Quart, Enum.EasingDirection.Out
			local style = library.buttonTypes.danger

			local holder = settingsTab:createCustom({name = "unload", title = options.title or "unload", height = 32})
			local button = utility.create("TextButton", {
				Name = "button",
				BackgroundColor3 = style.fill,
				AutoButtonColor = false,
				Size = UDim2.fromScale(1, 1),
				Text = "",
				ZIndex = 10,
				Parent = holder.frame,
			}, {
				utility.create("UICorner", {CornerRadius = UDim.new(0, 5)}),
				utility.create("UIStroke", {Name = "UIStroke", Color = style.stroke, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}),
				utility.create("TextLabel", {
					Name = "label",
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					Text = options.title or "unload",
					TextColor3 = style.label,
					TextSize = 14,
					FontFace = medium,
					ZIndex = 11,
				}),
			})
			button.MouseButton1Click:Once(function()
				if options.callback then
					options.callback()
				end
				task.wait(0.3)
				library:unload()
			end)

			return {frame = holder.frame, button = button}
		end

		return settingsTab
	end


	--------------------------------------
	-- loader ----------------------------
	--------------------------------------

	local function startLoader(options)
		options = options or {}
		local accent = library.theme.accent
		local medium = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal)
		local regular = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
		local mono = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal)
		local ease = Enum.EasingStyle.Quart
		local out, inOut, into = Enum.EasingDirection.Out, Enum.EasingDirection.InOut, Enum.EasingDirection.In

		local loaderTitle = options.title or title
		local loaderSubtitle = options.description or subtitle
		local welcomeText = options.subtitle or "welcome back,"
		local nameText = options.name or string.lower(player.DisplayName)
		local logo = options.logo
		if type(logo) == "number" then
			logo = "rbxassetid://" .. logo
		end
		local steps = options.steps or {"initializing", "loading modules", "building interface", "applying theme", "almost there"}
		local duration = options.duration or 2.8
		local manual = options.manual == true

		if options.type == "terminal" then
			local width, height = options.width or 470, options.height or 280
			local monoRegular = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
			local accentHex = "#" .. accent:ToHex()
			local okHex = "#5FD38D"
			local dimHex = "#5A5A5A"
			local startTime = os.clock()

			local function esc(text)
				text = string.gsub(text, "&", "&amp;")
				text = string.gsub(text, "<", "&lt;")
				text = string.gsub(text, ">", "&gt;")
				return text
			end
			local function tint(color, text)
				return '<font color="' .. color .. '">' .. text .. "</font>"
			end

			window.loading = true
			window.isOpen = false
			canvas.Visible = false

			local blur = Instance.new("BlurEffect")
			blur.Name = "libraryLoaderBlur"
			blur.Size = 0
			blur.Parent = lighting

			local backdrop = utility.create("Frame", {
				Name = "loader",
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 200,
				Parent = screen,
			})

			local card = utility.create("CanvasGroup", {
				Name = "terminal",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(width, height),
				BackgroundColor3 = Color3.fromRGB(8, 8, 8),
				GroupTransparency = 1,
				ZIndex = 201,
				Parent = backdrop,
			}, {
				utility.create("UICorner", {CornerRadius = UDim.new(0, 8)}),
				utility.create("UIStroke", {Name = "UIStroke", Color = Color3.fromRGB(25, 25, 25), Thickness = 1, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}),
				utility.create("UIScale", {Name = "scale", Scale = 0.94}),
			})

			local cardShadow = utility.create("Frame", {
				Name = "cardShadow",
				AnchorPoint = card.AnchorPoint,
				Position = card.Position,
				Size = card.Size,
				BackgroundColor3 = Color3.fromRGB(8, 8, 8),
				BackgroundTransparency = 1,
				ZIndex = 200,
				Parent = backdrop,
			}, {
				utility.create("UICorner", {CornerRadius = UDim.new(0, 8)}),
				utility.create("UIScale", {Name = "scale", Scale = 0.94}),
				utility.create("UIShadow", {
					Name = "UIShadow",
					Offset = UDim2.fromOffset(0, 8),
					Transparency = 1,
					BlurRadius = UDim.new(0, 32),
					Color = Color3.fromRGB(0, 0, 0),
					ZIndex = 1,
					Spread = UDim2.new(0, 0, 0, 0),
					Enabled = true,
				}),
			})

			local header = utility.create("Frame", {
				Name = "header",
				BackgroundColor3 = Color3.fromRGB(12, 12, 12),
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 30),
				ZIndex = 202,
				Parent = card,
			})
			local headerLine = utility.create("Frame", {
				Name = "line",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, 1),
				BorderSizePixel = 0,
				BackgroundColor3 = Color3.fromRGB(20, 20, 20),
				ZIndex = 203,
				Parent = header,
			})
			local headerTitle = utility.create("TextLabel", {
				Name = "title",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(14, 0),
				Size = UDim2.new(1, -90, 1, 0),
				Text = string.lower(player.Name) .. "@" .. string.gsub(string.lower(loaderTitle), "%s+", "-") .. ": ~",
				TextColor3 = Color3.fromRGB(100, 100, 100),
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				FontFace = monoRegular,
				ZIndex = 203,
				Parent = header,
			})
			local headerVersion = utility.create("TextLabel", {
				Name = "version",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -14, 0, 0),
				Size = UDim2.new(0, 70, 1, 0),
				Text = "v" .. tostring(library.version),
				TextColor3 = Color3.fromRGB(60, 60, 60),
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Right,
				FontFace = monoRegular,
				ZIndex = 203,
				Parent = header,
			})

			local body = utility.create("Frame", {
				Name = "body",
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				Position = UDim2.fromOffset(0, 30),
				Size = UDim2.new(1, 0, 1, -30),
				ZIndex = 202,
				Parent = card,
			}, {
				utility.create("UIPadding", {PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 14), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16)}),
				utility.create("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom}),
			})

			local alive = true
			local lineCount = 0
			local function addLine(rich, order)
				lineCount += 1
				local label = utility.create("TextLabel", {
					Name = "line",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 16),
					RichText = true,
					Text = rich,
					TextColor3 = Color3.fromRGB(180, 180, 180),
					TextTransparency = 1,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					FontFace = monoRegular,
					LayoutOrder = order or lineCount,
					ZIndex = 203,
					Parent = body,
				}, {
					utility.create("UIPadding", {Name = "shift", PaddingLeft = UDim.new(0, 8)}),
				})
				utility.tween(label, 0.35, {TextTransparency = 0}, ease, out)
				utility.tween(label.shift, 0.45, {PaddingLeft = UDim.new(0, 0)}, ease, out)
				return label
			end

			local barWidth = 26
			local function barText(value)
				local filled = math.floor(value * barWidth + 0.5)
				local bar
				if filled >= barWidth then
					bar = string.rep("=", barWidth)
				elseif filled > 0 then
					bar = string.rep("=", filled - 1) .. ">" .. string.rep(" ", barWidth - filled)
				else
					bar = string.rep(" ", barWidth)
				end
				return tint(dimHex, "[") .. tint(accentHex, bar) .. tint(dimHex, "]") .. " " .. math.floor(value * 100 + 0.5) .. "%"
			end

			local spinnerFrames = {"|", "/", "-", "\\"}
			local spinIndex, spinTime, cursorTime = 1, 0, 0
			local cursorOn = true
			local activeStep, typing, progressLine

			local function stepText(done, text)
				if done then
					return tint(dimHex, "[") .. tint(okHex, "ok") .. tint(dimHex, "]") .. " " .. esc(text)
				end
				return tint(dimHex, "[") .. tint(accentHex, esc(spinnerFrames[spinIndex]) .. " ") .. tint(dimHex, "]") .. " " .. tint("#8C8C8C", esc(text))
			end

			local function finishStep()
				if activeStep then
					activeStep.label.Text = stepText(true, activeStep.text)
					activeStep = nil
				end
			end

			local function setStatus(text)
				if not alive then return end
				finishStep()
				activeStep = {label = addLine(stepText(false, text)), text = text}
			end

			local function drawTyping()
				if typing then
					typing.label.Text = typing.prefix .. esc(typing.shown) .. (cursorOn and tint(accentHex, "_") or "")
				end
			end

			local prompt = tint(accentHex, "$") .. " "
			local function typeCmd(text, speed)
				local label = addLine(prompt)
				typing = {label = label, prefix = prompt, shown = ""}
				for index = 1, #text do
					if not alive then return end
					typing.shown = string.sub(text, 1, index)
					cursorOn = true
					cursorTime = 0
					drawTyping()
					task.wait(speed or 0.025)
				end
				task.wait(0.2)
				local done = typing
				typing = nil
				done.label.Text = done.prefix .. esc(done.shown)
			end

			local loop = runService.RenderStepped:Connect(function(dt)
				cardShadow.Position = card.Position
				cardShadow.Size = card.Size
				cardShadow.scale.Scale = card.scale.Scale
				local fade = card.GroupTransparency
				cardShadow.BackgroundTransparency = fade
				cardShadow.UIShadow.Transparency = 0.15 + 0.85 * fade
				spinTime += dt
				if spinTime >= 0.08 then
					spinTime = 0
					spinIndex = spinIndex % #spinnerFrames + 1
					if activeStep then
						activeStep.label.Text = stepText(false, activeStep.text)
					end
				end
				cursorTime += dt
				if cursorTime >= 0.5 then
					cursorTime = 0
					cursorOn = not cursorOn
					drawTyping()
				end
			end)

			local progressValue = Instance.new("NumberValue")
			progressValue.Changed:Connect(function(value)
				if progressLine then
					progressLine.Text = barText(value)
				end
			end)

			local function setProgress(value, time)
				utility.tween(progressValue, time or 0.6, {Value = math.clamp(value, 0, 1)}, ease, inOut)
			end

			local finished, ready, finishQueued = false, false, false
			local controller = {}

			local function runFinish()
				setProgress(1, 0.45)
				task.wait(0.5)
				finishStep()
				if progressLine then
					lineCount += 1
					progressLine.LayoutOrder = lineCount
				end
				task.wait(0.15)
				addLine(tint(okHex, "done") .. " " .. tint(dimHex, string.format("in %.2fs", os.clock() - startTime)))
				task.wait(0.2)
				typing = {label = addLine(prompt), prefix = prompt, shown = ""}
				drawTyping()
				task.wait(0.8)

				for _, label in body:GetChildren() do
					if label:IsA("TextLabel") then
						utility.tween(label, 0.35, {TextTransparency = 1}, ease, out)
					end
				end
				task.wait(0.25)

				local morph = 0.9
				utility.tween(header, morph * 0.7, {BackgroundTransparency = 1}, ease, inOut)
				utility.tween(headerLine, morph * 0.7, {BackgroundTransparency = 1}, ease, inOut)
				utility.tween(headerTitle, morph * 0.5, {TextTransparency = 1}, ease, out)
				utility.tween(headerVersion, morph * 0.5, {TextTransparency = 1}, ease, out)
				canvas.Size = window.originalSize
				utility.tween(card, morph, {Size = window.originalSize, Position = canvas.Position, BackgroundColor3 = canvas.BackgroundColor3}, ease, inOut)
				utility.tween(backdrop, morph, {BackgroundTransparency = 1}, ease, inOut)
				utility.tween(blur, morph, {Size = 0}, ease, inOut)
				task.wait(morph + 0.02)

				canvas.Visible = true
				window.isOpen = true
				window.loading = false
				utility.tween(card, 0.45, {GroupTransparency = 1}, ease, out)
				utility.tween(card.UIStroke, 0.45, {Transparency = 1}, ease, out)
				if options.callback then
					task.spawn(options.callback)
				end
				task.wait(0.5)
				alive = false
				typing = nil
				loop:Disconnect()
				backdrop:Destroy()
				blur:Destroy()
				progressValue:Destroy()
			end

			function controller:finish()
				if finished then return end
				finished = true
				if ready then
					task.spawn(runFinish)
				else
					finishQueued = true
				end
			end

			function controller:setStatus(text)
				setStatus(text)
			end

			function controller:setProgress(value, text)
				if text then
					setStatus(text)
				end
				setProgress(value)
			end

			utility.tween(backdrop, 0.5, {BackgroundTransparency = 0.45}, ease, out)
			utility.tween(blur, 0.5, {Size = 14}, ease, out)

			task.spawn(function()
				task.wait(0.15)
				utility.tween(card, 0.7, {GroupTransparency = 0}, ease, out)
				utility.tween(card.UIStroke, 0.7, {Transparency = 0}, ease, out)
				utility.tween(card.scale, 0.8, {Scale = 1}, ease, out)
				task.wait(0.5)
				typeCmd(options.command or ("./" .. string.gsub(string.lower(loaderTitle), "%s+", "-") .. " --start"))
				if not alive then return end
				task.wait(0.1)
				addLine(tint(dimHex, esc(string.lower(loaderTitle) .. " v" .. tostring(library.version) .. "  ·  " .. string.lower(os.date("%b %d %H:%M")))))
				task.wait(0.3)
				progressLine = addLine(barText(0), 1000000)
				setStatus(steps[1] or "loading")
				ready = true
				if finishQueued then
					task.spawn(runFinish)
					return
				end
				if manual then
					return
				end
				local count = math.max(#steps, 1)
				local per = duration / count
				for index, step in steps do
					if not alive or finished then return end
					if index > 1 then
						setStatus(step)
					end
					setProgress(index / count * 0.92 + (math.random() * 0.04), per * 0.9)
					task.wait(per)
				end
				controller:finish()
			end)

			window.loader = controller
			return controller
		end

		local brandWidth, infoWidth, cardHeight = 200, 320, 240

		window.loading = true
		window.isOpen = false
		canvas.Visible = false

		local blur = Instance.new("BlurEffect")
		blur.Name = "libraryLoaderBlur"
		blur.Size = 0
		blur.Parent = lighting

		local backdrop = utility.create("Frame", {
			Name = "loader",
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 200,
			Parent = screen,
		})

		local card = utility.create("CanvasGroup", {
			Name = "card",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(brandWidth, cardHeight),
			BackgroundColor3 = Color3.fromRGB(10, 10, 10),
			GroupTransparency = 1,
			ZIndex = 201,
			Parent = backdrop,
		}, {
			utility.create("UICorner", {CornerRadius = UDim.new(0, 12)}),
			utility.create("UIStroke", {Name = "UIStroke", Color = Color3.fromRGB(25, 25, 25), Thickness = 1, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}),
			utility.create("UIScale", {Name = "scale", Scale = 0.94}),
		})

		local cardShadow = utility.create("Frame", {
			Name = "cardShadow",
			AnchorPoint = card.AnchorPoint,
			Position = card.Position,
			Size = card.Size,
			BackgroundColor3 = Color3.fromRGB(10, 10, 10),
			BackgroundTransparency = 1,
			ZIndex = 200,
			Parent = backdrop,
		}, {
			utility.create("UICorner", {CornerRadius = UDim.new(0, 12)}),
			utility.create("UIScale", {Name = "scale", Scale = 0.94}),
			utility.create("UIShadow", {
				Name = "UIShadow",
				Offset = UDim2.fromOffset(0, 8),
				Transparency = 1,
				BlurRadius = UDim.new(0, 32),
				Color = Color3.fromRGB(0, 0, 0),
				ZIndex = 1,
				Spread = UDim2.new(0, 0, 0, 0),
				Enabled = true,
			}),
		})

		local brand = utility.create("Frame", {
			Name = "brand",
			BackgroundColor3 = Color3.fromRGB(13, 13, 13),
			BorderSizePixel = 0,
			Size = UDim2.new(0, brandWidth, 1, 0),
			ZIndex = 202,
			Parent = card,
		})

		local pattern = utility.create("CanvasGroup", {
			Name = "pattern",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 203,
			Parent = brand,
		}, {
			utility.create("UIGradient", {
				Rotation = 45,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.1),
					NumberSequenceKeypoint.new(0.7, 0.85),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})

		local gridSpacing = 20
		local grid = utility.create("Frame", {
			Name = "grid",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(-gridSpacing, -gridSpacing),
			Size = UDim2.new(1, gridSpacing * 2, 1, gridSpacing * 2),
			ZIndex = 203,
			Parent = pattern,
		})
		for x = 0, brandWidth + gridSpacing * 2, gridSpacing do
			utility.create("Frame", {
				Name = "column",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 0.95,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(x, 0),
				Size = UDim2.new(0, 1, 1, 0),
				ZIndex = 203,
				Parent = grid,
			})
		end
		for y = 0, cardHeight + gridSpacing * 2, gridSpacing do
			utility.create("Frame", {
				Name = "row",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 0.95,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, y),
				Size = UDim2.new(1, 0, 0, 1),
				ZIndex = 203,
				Parent = grid,
			})
		end

		local edge = utility.create("Frame", {
			Name = "edge",
			BackgroundColor3 = Color3.fromRGB(25, 25, 25),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 1, 1, 0),
			ZIndex = 204,
			Parent = brand,
		})

		local mark, markSub, underline
		if logo then
			mark = utility.create("ImageLabel", {
				Name = "logo",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(84, 84),
				BackgroundTransparency = 1,
				Image = logo,
				ImageTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 205,
				Parent = brand,
			})
		else
			mark = utility.create("TextLabel", {
				Name = "mark",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 0.5, 4),
				Size = UDim2.new(1, -30, 0, 30),
				BackgroundTransparency = 1,
				Text = loaderTitle,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextTransparency = 1,
				TextSize = 26,
				TextTruncate = Enum.TextTruncate.AtEnd,
				FontFace = medium,
				ZIndex = 205,
				Parent = brand,
			})
			markSub = utility.create("TextLabel", {
				Name = "description",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0.5, 8),
				Size = UDim2.new(1, -30, 0, 16),
				BackgroundTransparency = 1,
				Text = loaderSubtitle,
				TextColor3 = Color3.fromRGB(139, 139, 139),
				TextTransparency = 1,
				TextSize = 13,
				TextTruncate = Enum.TextTruncate.AtEnd,
				FontFace = regular,
				ZIndex = 205,
				Parent = brand,
			})
			underline = utility.create("Frame", {
				Name = "underline",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0.5, 34),
				Size = UDim2.fromOffset(0, 2),
				BackgroundColor3 = accent,
				BorderSizePixel = 0,
				ZIndex = 205,
				Parent = brand,
			}, {
				utility.create("UICorner", {CornerRadius = UDim.new(1, 0)}),
			})
		end
		local markScale = utility.create("UIScale", {Scale = 0.94, Parent = mark})

		local info = utility.create("Frame", {
			Name = "info",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(brandWidth, 0),
			Size = UDim2.new(0, infoWidth, 1, 0),
			ZIndex = 202,
			Parent = card,
		})

		local welcomeLabel = utility.create("TextLabel", {
			Name = "welcome",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(28, 52),
			Size = UDim2.new(1, -56, 0, 16),
			Text = welcomeText,
			TextColor3 = Color3.fromRGB(100, 100, 100),
			TextTransparency = 1,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = regular,
			ZIndex = 205,
			Parent = info,
		})

		local nameLabel = utility.create("TextLabel", {
			Name = "name",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(28, 70),
			Size = UDim2.new(1, -56, 0, 30),
			Text = nameText,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextTransparency = 1,
			TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			FontFace = medium,
			ZIndex = 205,
			Parent = info,
		})

		local statusHolder = utility.create("Frame", {
			Name = "status",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.fromOffset(28, 142),
			Size = UDim2.new(1, -110, 0, 18),
			ZIndex = 205,
			Parent = info,
		})

		local percent = utility.create("TextLabel", {
			Name = "percent",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -28, 0, 142),
			Size = UDim2.fromOffset(60, 18),
			Text = "0%",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextTransparency = 1,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right,
			FontFace = mono,
			ZIndex = 205,
			Parent = info,
		})

		local track = utility.create("Frame", {
			Name = "track",
			BackgroundColor3 = Color3.fromRGB(20, 20, 20),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(28, 168),
			Size = UDim2.new(1, -56, 0, 4),
			ZIndex = 205,
			Parent = info,
		}, {
			utility.create("UICorner", {CornerRadius = UDim.new(1, 0)}),
		})

		local fill = utility.create("Frame", {
			Name = "fill",
			BackgroundColor3 = accent,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(0, 1),
			ZIndex = 206,
			Parent = track,
		}, {
			utility.create("UICorner", {CornerRadius = UDim.new(1, 0)}),
		})

		local footer = utility.create("TextLabel", {
			Name = "footer",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(28, 196),
			Size = UDim2.new(1, -56, 0, 14),
			Text = string.lower(loaderTitle) .. "  ·  v" .. tostring(library.version) .. "  ·  " .. string.lower(os.date("%b %d")),
			TextColor3 = Color3.fromRGB(60, 60, 60),
			TextTransparency = 1,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = mono,
			ZIndex = 205,
			Parent = info,
		})

		local infoItems = {
			{welcomeLabel, "TextTransparency"},
			{nameLabel, "TextTransparency"},
			{statusHolder, nil},
			{percent, "TextTransparency"},
			{track, "BackgroundTransparency", fill},
			{footer, "TextTransparency"},
		}
		for _, item in infoItems do
			item.base = item[1].Position
		end

		local alive = true
		local drift = 0
		local patternLoop = runService.RenderStepped:Connect(function(dt)
			cardShadow.Position = card.Position
			cardShadow.Size = card.Size
			cardShadow.scale.Scale = card.scale.Scale
			local fade = card.GroupTransparency
			cardShadow.BackgroundTransparency = fade
			cardShadow.UIShadow.Transparency = 0.15 + 0.85 * fade
			drift = (drift + dt * 6) % gridSpacing
			grid.Position = UDim2.fromOffset(-gridSpacing + drift, -gridSpacing + drift)
		end)

		local currentStatus
		local function setStatus(text)
			if not alive then return end
			local label = utility.create("TextLabel", {
				Name = "line",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, 10),
				Size = UDim2.fromScale(1, 1),
				Text = text,
				TextColor3 = Color3.fromRGB(160, 160, 160),
				TextTransparency = 1,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				FontFace = regular,
				ZIndex = 206,
				Parent = statusHolder,
			})
			utility.tween(label, 0.45, {Position = UDim2.fromOffset(0, 0), TextTransparency = 0}, ease, out)
			local old = currentStatus
			currentStatus = label
			if old then
				utility.tween(old, 0.4, {Position = UDim2.fromOffset(0, -10), TextTransparency = 1}, ease, out)
				task.delay(0.42, function()
					old:Destroy()
				end)
			end
		end

		local progressValue = Instance.new("NumberValue")
		progressValue.Value = 0
		progressValue.Changed:Connect(function(value)
			percent.Text = math.floor(value * 100 + 0.5) .. "%"
		end)

		local function setProgress(value, time)
			value = math.clamp(value, 0, 1)
			time = time or 0.6
			utility.tween(fill, time, {Size = UDim2.fromScale(value, 1)}, ease, inOut)
			utility.tween(progressValue, time, {Value = value}, ease, inOut)
		end

		local function showInfo(visible)
			for index, item in infoItems do
				local inst, property, extra = item[1], item[2], item[3]
				local delayTime = visible and (index - 1) * 0.07 or (#infoItems - index) * 0.03
				task.delay(delayTime, function()
					if not alive then return end
					if visible then
						inst.Position = item.base + UDim2.fromOffset(14, 0)
					end
					utility.tween(inst, visible and 0.6 or 0.35, {
						Position = visible and item.base or item.base + UDim2.fromOffset(-10, 0),
					}, ease, out)
					if property then
						utility.tween(inst, visible and 0.5 or 0.3, {[property] = visible and 0 or 1}, ease, out)
					end
					if extra then
						utility.tween(extra, visible and 0.5 or 0.3, {BackgroundTransparency = visible and 0 or 1}, ease, out)
					end
					if inst == statusHolder and currentStatus then
						utility.tween(currentStatus, visible and 0.5 or 0.3, {TextTransparency = visible and 0 or 1}, ease, out)
					end
				end)
			end
		end

		local function measureTopbar()
			local savedPosition = canvas.Position
			canvas.Position = UDim2.fromOffset(-10000, -10000)
			canvas.Size = window.originalSize
			canvas.Visible = true
			runService.RenderStepped:Wait()
			local origin = canvas.AbsolutePosition
			local titleLabel, subtitleLabel = topbar.title, topbar.subtitle
			local result = {
				titlePosition = titleLabel.AbsolutePosition - origin,
				titleSize = titleLabel.AbsoluteSize,
				titleTextSize = math.max(titleLabel.TextBounds.Y, 8),
				titleColor = titleLabel.TextColor3,
				subtitlePosition = subtitleLabel.AbsolutePosition - origin,
				subtitleSize = subtitleLabel.AbsoluteSize,
				subtitleTextSize = math.max(subtitleLabel.TextBounds.Y, 8),
				subtitleColor = subtitleLabel.TextColor3,
			}
			canvas.Visible = false
			canvas.Position = savedPosition
			return result
		end

		local function pinLeft(label)
			local bounds = label.TextBounds
			local center = label.AbsolutePosition + label.AbsoluteSize / 2
			local brandOrigin = brand.AbsolutePosition
			label.AnchorPoint = Vector2.new(0, 0)
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextYAlignment = Enum.TextYAlignment.Top
			label.TextTruncate = Enum.TextTruncate.None
			label.Size = UDim2.fromOffset(math.ceil(bounds.X) + 2, math.ceil(bounds.Y))
			label.Position = UDim2.fromOffset(math.floor(center.X - bounds.X / 2 - brandOrigin.X), math.floor(center.Y - bounds.Y / 2 - brandOrigin.Y))
		end

		local finished = false
		local ready = false
		local finishQueued = false
		local controller = {}

		local function runFinish()
			setProgress(1, 0.45)
			task.wait(0.45)
			setStatus("ready")
			task.wait(0.6)
			showInfo(false)
			task.wait(0.45)

			local targets = measureTopbar()
			local morph = 0.9
			utility.tween(brand, morph, {BackgroundTransparency = 1}, ease, inOut)
			utility.tween(edge, morph * 0.8, {BackgroundTransparency = 1}, ease, inOut)
			utility.tween(pattern, morph, {GroupTransparency = 1}, ease, inOut)

			if logo then
				utility.tween(mark, 0.45, {ImageTransparency = 1}, ease, out)
				utility.tween(markScale, 0.45, {Scale = 0.9}, ease, out)
			else
				if underline then
					utility.tween(underline, 0.35, {Size = UDim2.fromOffset(0, 2)}, ease, out)
				end
				pinLeft(mark)
				pinLeft(markSub)
				local titleY = targets.titlePosition.Y + (targets.titleSize.Y - targets.titleTextSize) / 2
				local subtitleY = targets.subtitlePosition.Y + (targets.subtitleSize.Y - targets.subtitleTextSize) / 2
				utility.tween(mark, morph, {
					Position = UDim2.fromOffset(targets.titlePosition.X, titleY),
					Size = UDim2.fromOffset(targets.titleSize.X, targets.titleTextSize),
					TextSize = targets.titleTextSize,
					TextColor3 = targets.titleColor,
				}, ease, inOut)
				utility.tween(markSub, morph, {
					Position = UDim2.fromOffset(targets.subtitlePosition.X, subtitleY),
					Size = UDim2.fromOffset(targets.subtitleSize.X, targets.subtitleTextSize),
					TextSize = targets.subtitleTextSize,
					TextColor3 = targets.subtitleColor,
				}, ease, inOut)
			end

			canvas.Size = window.originalSize
			utility.tween(card, morph, {Size = window.originalSize, Position = canvas.Position}, ease, inOut)
			utility.tween(backdrop, morph, {BackgroundTransparency = 1}, ease, inOut)
			utility.tween(blur, morph, {Size = 0}, ease, inOut)
			task.wait(morph + 0.02)

			canvas.Visible = true
			window.isOpen = true
			window.loading = false
			utility.tween(card, 0.45, {GroupTransparency = 1}, ease, out)
			utility.tween(card.UIStroke, 0.45, {Transparency = 1}, ease, out)
			if options.callback then
				task.spawn(options.callback)
			end
			task.wait(0.5)
			alive = false
			patternLoop:Disconnect()
			backdrop:Destroy()
			blur:Destroy()
			progressValue:Destroy()
		end

		function controller:finish()
			if finished then return end
			finished = true
			if ready then
				task.spawn(runFinish)
			else
				finishQueued = true
			end
		end

		function controller:setStatus(text)
			setStatus(text)
		end

		function controller:setProgress(value, text)
			if text then
				setStatus(text)
			end
			setProgress(value)
		end

		utility.tween(backdrop, 0.5, {BackgroundTransparency = 0.45}, ease, out)
		utility.tween(blur, 0.5, {Size = 14}, ease, out)

		task.spawn(function()
			task.wait(0.15)
			utility.tween(card, 0.7, {GroupTransparency = 0}, ease, out)
			utility.tween(card.UIStroke, 0.7, {Transparency = 0}, ease, out)
			utility.tween(card.scale, 0.8, {Scale = 1}, ease, out)
			task.wait(0.2)
			if logo then
				utility.tween(mark, 0.8, {ImageTransparency = 0}, ease, out)
			else
				utility.tween(mark, 0.8, {TextTransparency = 0}, ease, out)
				task.delay(0.15, function()
					utility.tween(markSub, 0.7, {TextTransparency = 0}, ease, out)
				end)
				task.delay(0.3, function()
					utility.tween(underline, 0.7, {Size = UDim2.fromOffset(24, 2)}, ease, out)
				end)
			end
			utility.tween(markScale, 0.9, {Scale = 1}, ease, out)
			task.wait(1.1)
			if not alive then return end
			utility.tween(card, 0.85, {Size = UDim2.fromOffset(brandWidth + infoWidth, cardHeight)}, ease, inOut)
			utility.tween(edge, 0.6, {BackgroundTransparency = 0}, ease, out)
			task.wait(0.35)
			setStatus(steps[1] or "loading")
			showInfo(true)
			task.wait(0.7)
			ready = true
			if finishQueued then
				task.spawn(runFinish)
				return
			end
			if manual then
				return
			end
			local count = math.max(#steps, 1)
			local per = duration / count
			for index, step in steps do
				if not alive or finished then return end
				if index > 1 then
					setStatus(step)
				end
				setProgress(index / count * 0.92 + (math.random() * 0.04), per * 0.9)
				task.wait(per)
			end
			controller:finish()
		end)

		window.loader = controller
		return controller
	end

	local toggleBeforeLoader = window.toggle
	function window:toggle(state)
		if window.loading then return end
		return toggleBeforeLoader(self, state)
	end

	function window:showLoader(options)
		if window.loading then return window.loader end
		if window.hideTooltip then
			window.hideTooltip()
		end
		if window.closeSearch then
			window:closeSearch()
		end
		return startLoader(options or {})
	end

	if config.loader then
		startLoader(type(config.loader) == "table" and config.loader or {})
	end

	return window
end


--------------------------------------
-- unload ----------------------------
--------------------------------------

function library:unload()
	if self.window then
		self.window.canvas:Destroy()
		self.window = nil
	end

	for _, connection in pairs(self.connections) do
		if connection then
			connection:Disconnect()
		end
	end

	self.connections = {}
	table.clear(flagInfo)
	table.clear(self.flags)

	self.isDialogOpen = false
	self.visible = false

end

return library
