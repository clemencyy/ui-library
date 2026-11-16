local replicatedStorage = game:GetService("ReplicatedStorage")

local library = loadstring(game:HttpGet("https://raw.githubusercontent.com/clemencyy/ui-library/refs/heads/main/src.lua"))()

local function say(...)
	print(...)
end

local window = library.new({
	title = "showcase",
	subtitle = "every element and feature",
	icon = 10734950309,
	display = "both",
	size = UDim2.fromOffset(720, 460),
	configFolder =  "config",
	loader = {
		type = "card",
		steps = {"loading", "building tabs", "done"},
		duration = math.random(0.2, 0.7),
	},
})

window:setToggleKey(Enum.KeyCode.RightControl)
window:createTag("TAG", Color3.fromRGB(255, 195, 9))
window:createTag("ANOTHER", Color3.fromRGB(80, 200, 120))

window:createSection("ELEMENTS")
local basics = window:createTab({name = "Basics", icon = "rbxassetid://10723407389"})
local sliders = window:createTab({name = "Sliders", icon = "rbxassetid://10734950309"})
local pickers = window:createTab({name = "Pickers", icon = "rbxassetid://10734950309"})
local inputs = window:createTab({name = "Inputs", icon = "rbxassetid://10723407389"})
local keybinds = window:createTab({name = "Keybinds", icon = "rbxassetid://10734898355"})
local layout = window:createTab({name = "Layout", icon = "rbxassetid://10734950309"})
local groups = window:createTab({name = "Groupboxes", icon = "rbxassetid://10734950309"})
window:createDivider()
window:createSection("SYSTEM")
local notifications = window:createTab({name = "Notifications", icon = "rbxassetid://10709775704"})
local dialogs = window:createTab({name = "Dialogs", icon = "rbxassetid://10734943674"})
local loaders = window:createTab({name = "Loaders", icon = "rbxassetid://10734943674"})
local windowTab = window:createTab({name = "Window", icon = "rbxassetid://10734950309"})

local label = basics:createLabel({text = "label"})
local paragraph = basics:createParagraph({
	title = "paragraph",
	body = "a title with a body under it, the body wraps onto more lines when its long enough to need it",
})
basics:createDivider()
local clicks = 0
local button
button = basics:createButton({
	title = "button",
	description = "with a description",
	callback = function()
		clicks += 1
		button:setText("button (" .. clicks .. ")")
	end,
})
basics:createButton({
	title = "button without a description",
	callback = function()
		say("button pressed")
	end,
})
basics:createButton({
	title = "button with a tooltip",
	tooltip = "this is a tooltip",
	callback = function()
		say("button with a tooltip pressed")
	end,
})
basics:createHoldButton({
	title = "hold button",
	description = "hold for 1 second to fire",
	callback = function()
		say("hold button fired")
	end,
})
basics:createHoldButton({
	title = "slow hold button",
	description = "2 seconds, custom text",
	duration = 2,
	text = "hold to reset",
	doneText = "reset",
	callback = function()
		say("slow hold button fired")
	end,
})
local toggle = basics:createToggle({
	title = "toggle",
	description = "off by default",
	default = false,
	callback = function(state)
		say("toggle", state)
	end,
})
basics:createToggle({
	title = "toggle on by default",
	default = true,
	callback = function(state)
		say("toggle on by default", state)
	end,
})
basics:createDivider()
basics:createButton({
	title = "label:set()",
	callback = function()
		label:set("label set at " .. os.date("%H:%M:%S"))
	end,
})
basics:createButton({
	title = "paragraph:set()",
	callback = function()
		paragraph:set("paragraph (changed)", "the body got changed with set")
	end,
})
basics:createButton({
	title = "toggle.toggle()",
	callback = function()
		toggle.toggle()
	end,
})

local slider = sliders:createSlider({
	title = "slider",
	flag = "slider",
	description = "whole numbers",
	min = 0,
	max = 100,
	default = 50,
	callback = function(value)
		say("slider", value)
	end,
})
sliders:createSlider({
	title = "slider with decimals",
	min = 0,
	max = 1,
	increment = 0.05,
	default = 0.5,
	callback = function(value)
		say("slider with decimals", value)
	end,
})
sliders:createSlider({
	title = "slider with a display suffix",
	min = 16,
	max = 120,
	default = 16,
	display = " studs",
	callback = function(value)
		say("slider with a display suffix", value)
	end,
})
sliders:createSlider({
	title = "slider with marks",
	description = "snaps to marks, labels are clickable",
	min = 0,
	max = 100,
	default = 25,
	marks = {["low"] = 0, ["mid"] = 50, ["high"] = 100},
	callback = function(value)
		say("slider with marks", value)
	end,
})
local range = sliders:createRangeSlider({
	title = "range slider",
	flag = "range",
	description = "two knobs, min and max",
	min = 0,
	max = 100,
	default = {20, 80},
	callback = function(low, high)
		say("range slider", low, high)
	end,
})
sliders:createRangeSlider({
	title = "range slider with a gap",
	description = "knobs stay at least 20 apart",
	min = 0,
	max = 100,
	gap = 20,
	default = {30, 60},
	display = "%",
	callback = function(low, high)
		say("range slider with a gap", low, high)
	end,
})
sliders:createDivider()
sliders:createButton({
	title = "slider:set(75)",
	callback = function()
		slider:set(75)
	end,
})
sliders:createButton({
	title = "range:set(10, 90)",
	callback = function()
		range:set(10, 90)
	end,
})

local dropdown = pickers:createDropdown({
	title = "dropdown",
	options = {"one", "two", "three"},
	default = "one",
	callback = function(choice)
		say("dropdown", choice)
	end,
})
pickers:createDropdown({
	title = "multi dropdown",
	options = {"one", "two", "three", "four"},
	default = {"one"},
	multi = true,
	callback = function(list)
		say("multi dropdown", table.concat(list, ", "))
	end,
})
pickers:createDropdown({
	title = "searchable dropdown",
	options = {"apple", "banana", "cherry", "grape", "lemon", "mango", "orange", "peach", "pear", "plum"},
	default = "apple",
	search = true,
	callback = function(choice)
		say("searchable dropdown", choice)
	end,
})
pickers:createButton({
	title = "dropdown:setOptions()",
	callback = function()
		dropdown:setOptions({"four", "five", "six"})
	end,
})
pickers:createDivider()
pickers:createSegmented({
	title = "segmented",
	flag = "segmented",
	options = {"left", "middle", "right"},
	default = "middle",
	callback = function(choice)
		say("segmented", choice)
	end,
})
pickers:createCheckbox({
	title = "checkbox",
	flag = "checkbox",
	default = false,
	callback = function(state)
		say("checkbox", state)
	end,
})
pickers:createCheckbox({
	title = "checkbox list",
	options = {"one", "two", "three"},
	default = {"two"},
	callback = function(list)
		say("checkbox list", table.concat(list, ", "))
	end,
})
pickers:createColorPicker({
	title = "color picker",
	flag = "color",
	default = Color3.fromRGB(255, 195, 9),
	callback = function(color)
		say("color picker", color:ToHex())
	end,
})
pickers:createDivider()
pickers:createPlayerPicker({
	title = "player picker",
	description = "dropdown, display + username",
	show = "both",
	search = true,
	callback = function(target)
		say("player picker", target)
	end,
})
pickers:createPlayerPicker({
	title = "player picker, usernames",
	show = "username",
	multi = true,
	callback = function(list)
		say("player picker, usernames", #list)
	end,
})
pickers:createPlayerPicker({
	title = "player list",
	description = "list type, display names",
	type = "list",
	show = "display",
	search = true,
	height = 150,
	callback = function(target)
		say("player list", target)
	end,
})
pickers:createPlayerPicker({
	title = "player list, multi",
	type = "list",
	multi = true,
	height = 150,
	callback = function(list)
		say("player list, multi", #list)
	end,
})

inputs:createInput({
	title = "input",
	flag = "input",
	placeholder = "type here...",
	callback = function(text)
		say("input", text)
	end,
})
inputs:createInput({
	title = "input that clears",
	placeholder = "clears after enter...",
	clear = true,
	callback = function(text)
		say("input that clears", text)
	end,
})
inputs:createInput({
	title = "numbers only",
	placeholder = "123",
	numerical = true,
	limit = 5,
	callback = function(text)
		say("numbers only", text)
	end,
})
local autocomplete = inputs:createInput({
	title = "autocomplete",
	description = "enter or tab accepts",
	placeholder = "try a, b or c...",
	autocompletes = {"apple", "banana", "cherry"},
	callback = function(text)
		say("autocomplete", text)
	end,
})
inputs:createInput({
	title = "password",
	placeholder = "secret...",
	password = true,
	callback = function(text)
		say("password length", #text)
	end,
})
inputs:createButton({
	title = "change autocompletes",
	callback = function()
		autocomplete.autocompletes = {"avocado", "blueberry", "coconut"}
	end,
})

local keybind = keybinds:createKeybind({
	title = "keybind",
	flag = "keybind",
	default = Enum.KeyCode.F,
	callback = function()
		say("keybind pressed")
	end,
	changedCallback = function(key)
		say("keybind changed", key)
	end,
})
keybinds:createKeybind({
	title = "toggle keybind",
	default = Enum.KeyCode.G,
	type = "toggle",
	callback = function(state)
		say("toggle keybind", state)
	end,
})
keybinds:createKeybind({
	title = "hold keybind",
	default = Enum.KeyCode.H,
	type = "hold",
	callback = function(held)
		say("hold keybind", held)
	end,
})
keybinds:createKeybind({
	title = "mouse keybind",
	default = Enum.UserInputType.MouseButton3,
	callback = function()
		say("mouse keybind pressed")
	end,
})
keybinds:createKeybind({
	title = "modifier keybind",
	default = "Ctrl+K",
	callback = function()
		say("modifier keybind pressed")
	end,
})
keybinds:createKeybind({
	title = "conflicting keybind",
	description = "same key as the first one",
	default = Enum.KeyCode.F,
	callback = function()
		say("conflicting keybind pressed")
	end,
})
keybinds:createKeybind({
	title = "unbound keybind",
	callback = function()
		say("unbound keybind pressed")
	end,
})
keybinds:createButton({
	title = "keybind:set(\"Shift+F\")",
	callback = function()
		keybind:set("Shift+F")
	end,
})

layout:createToggle({
	title = "pinned with order = -1",
	order = -1,
	default = true,
	callback = function(state)
		say("pinned", state)
	end,
})
local section = layout:createSection({title = "section"})
section:createToggle({
	title = "toggle in a section",
	callback = function(state)
		say("toggle in a section", state)
	end,
})
section:createSlider({
	title = "slider in a section",
	min = 0,
	max = 10,
	default = 5,
	callback = function(value)
		say("slider in a section", value)
	end,
})
local another = layout:createSection({title = "collapsible section", collapsible = true})
another:createButton({
	title = "button in another section",
	callback = function()
		say("button in another section")
	end,
})
local folded = layout:createSection({title = "starts collapsed", collapsed = true})
folded:createToggle({
	title = "hidden until opened",
	callback = function(state)
		say("folded toggle", state)
	end,
})
folded:createDropdown({
	title = "dropdown in a folded section",
	options = {"x", "y", "z"},
	default = "x",
	callback = function(choice)
		say("folded dropdown", choice)
	end,
})

local subTabs = layout:createSubTabs()
local first = subTabs:createTab({name = "first"})
local second = subTabs:createTab({name = "second"})
local third = subTabs:createTab({name = "third"})
first:createToggle({
	title = "toggle in the first sub tab",
	callback = function(state)
		say("first sub tab toggle", state)
	end,
})
first:createSlider({
	title = "slider in the first sub tab",
	min = 0,
	max = 100,
	default = 30,
	callback = function(value)
		say("first sub tab slider", value)
	end,
})
second:createDropdown({
	title = "dropdown in the second sub tab",
	options = {"a", "b", "c"},
	default = "a",
	callback = function(choice)
		say("second sub tab dropdown", choice)
	end,
})
third:createButton({
	title = "button in the third sub tab",
	callback = function()
		say("third sub tab button")
	end,
})

for _, kind in {"default", "info", "success", "warning", "error", "loading"} do
	notifications:createButton({
		title = kind .. " notification",
		callback = function()
			library:notify({type = kind, title = kind, body = "this is a " .. kind .. " notification", duration = 3})
		end,
	})
end
notifications:createDivider()
notifications:createButton({
	title = "loading that updates",
	callback = function()
		local toast = library:notify({type = "loading", title = "loading", body = "turns into success in 2 seconds"})
		task.delay(2, function()
			toast:update({type = "success", title = "done", body = "updated", duration = 3})
		end)
	end,
})
notifications:createButton({
	title = "notification with buttons",
	callback = function()
		library:notify({
			type = "info",
			title = "buttons",
			body = "two action buttons",
			duration = 6,
			buttons = {
				{text = "accent", type = "accent", callback = function()
					say("accent pressed")
				end},
				{text = "ghost", type = "ghost"},
			},
		})
	end,
})
notifications:createButton({
	title = "sticky notification",
	callback = function()
		library:notify({type = "info", title = "sticky", body = "stays until clicked", sticky = true})
	end,
})
notifications:createButton({
	title = "grouped notification",
	description = "sends the same one 4 times",
	callback = function()
		for _ = 1, 4 do
			library:notify({type = "warning", title = "grouped", body = "same notification", duration = 3})
			task.wait(0.2)
		end
	end,
})
notifications:createButton({
	title = "ungrouped notification",
	description = "same one 3 times with group = false",
	callback = function()
		for _ = 1, 3 do
			library:notify({title = "ungrouped", body = "same notification", duration = 3, group = false})
			task.wait(0.2)
		end
	end,
})

dialogs:createButton({
	title = "dialog",
	callback = function()
		window:dialog({
			title = "dialog",
			body = "two plain buttons",
			buttons = {"no", "yes"},
			callback = function(choice)
				say("dialog", choice)
			end,
		})
	end,
})
dialogs:createButton({
	title = "dialog button types",
	callback = function()
		window:dialog({
			type = "info",
			title = "button types",
			body = "ghost, danger, default and accent",
			buttons = {
				{text = "ghost", type = "ghost"},
				{text = "danger", type = "danger"},
				{text = "default", type = "default"},
				{text = "accent", type = "accent"},
			},
			callback = function(choice)
				say("dialog button types", choice)
			end,
		})
	end,
})
dialogs:createButton({
	title = "input dialog",
	callback = function()
		window:dialog({
			title = "input dialog",
			body = "type something",
			input = {placeholder = "text...", default = ""},
			buttons = {{text = "cancel", type = "ghost"}, {text = "ok", type = "accent"}},
			callback = function(choice, text)
				say("input dialog", choice, text)
			end,
		})
	end,
})
dialogs:createButton({
	title = "dialog that closes itself",
	callback = function()
		window:dialog({title = "timed", body = "closes in 3 seconds", duration = 3})
	end,
})

loaders:createButton({
	title = "card loader",
	callback = function()
		window:showLoader({type = "card", steps = {"one", "two", "three"}, duration = 2})
	end,
})
loaders:createButton({
	title = "card loader with a logo",
	callback = function()
		window:showLoader({type = "card", logo = 10734943674, steps = {"one", "two", "three"}, duration = 2})
	end,
})
loaders:createButton({
	title = "terminal loader",
	callback = function()
		window:showLoader({type = "terminal", steps = {"one", "two", "three", "four"}, duration = 2.4})
	end,
})
loaders:createButton({
	title = "manual terminal loader",
	description = "driven by setProgress and finish",
	callback = function()
		local loader = window:showLoader({type = "terminal", manual = true, command = "./showcase --manual", steps = {"starting"}})
		if not loader then return end
		task.spawn(function()
			task.wait(2)
			loader:setProgress(0.3, "step one")
			task.wait(0.8)
			loader:setProgress(0.7, "step two")
			task.wait(0.8)
			loader:finish()
		end)
	end,
})

windowTab:createButton({
	title = "window:selectTab()",
	description = "jumps to basics",
	callback = function()
		window:selectTab(basics)
	end,
})
windowTab:createButton({
	title = "window:openSearch()",
	description = "same as ctrl + f",
	callback = function()
		window:openSearch()
	end,
})
windowTab:createButton({
	title = "window:toggle()",
	description = "hides for 2 seconds",
	callback = function()
		window:toggle(false)
		task.wait(2)
		window:toggle(true)
	end,
})
windowTab:createButton({
	title = "library:unload()",
	callback = function()
		window:dialog({
			title = "unload?",
			body = "removes the whole ui",
			buttons = {"no", "yes"},
			callback = function(choice)
				if choice == "yes" then
					library:unload()
				end
			end,
		})
	end,
})

local farming = groups:createGroupbox({title = "Farming", side = "left"})
farming:createDropdown({
	title = "weapon",
	options = {"sword", "bow", "staff"},
	default = "sword",
	callback = function(choice)
		say("farming weapon", choice)
	end,
})
farming:createSlider({
	title = "range",
	min = 5,
	max = 50,
	default = 20,
	callback = function(value)
		say("farming range", value)
	end,
})
farming:createButton({
	title = "teleport to mobs",
	callback = function()
		say("teleport to mobs")
	end,
})

local auto = groups:createGroupbox({title = "Auto", side = "right"})
for _, name in {"auto farm level", "auto farm nearest", "auto farm bosses", "auto collect drops"} do
	auto:createToggle({
		title = name,
		callback = function(state)
			say(name, state)
		end,
	})
end

local misc = groups:createGroupbox({title = "Misc", side = "left", collapsible = true})
misc:createToggle({
	title = "anti afk",
	default = true,
	callback = function(state)
		say("anti afk", state)
	end,
})
misc:createKeybind({
	title = "stop farming",
	default = Enum.KeyCode.X,
	callback = function()
		say("stop farming")
	end,
})

local stats = groups:createGroupbox({title = "Stats", side = "right", collapsed = true})
local killsLabel = stats:createLabel({text = "kills: 0"})
stats:createParagraph({title = "session", body = "groupboxes stack down their own side"})

local settings = window:createSettings()
local yours = settings:createSection({title = "your settings"})
yours:createToggle({
	title = "show tooltips",
	flag = "showTooltips",
	default = true,
	callback = function(state)
		say("show tooltips", state)
	end,
})
yours:createDropdown({
	title = "language",
	flag = "language",
	options = {"english", "tagalog", "español"},
	default = "english",
	callback = function(choice)
		say("language", choice)
	end,
})

local config = settings:createConfig()
config:add("default")
config:add("pvp")
config:add("farming")
settings:createUnload()

local status = window:createStatusBar({text = "showcase v1.0", fps = true, ping = true, bind = "toggle"})
local playerCount = status:add("players", #game:GetService("Players"):GetPlayers(), "left")
game:GetService("Players").PlayerAdded:Connect(function()
	playerCount:set(#game:GetService("Players"):GetPlayers())
end)
game:GetService("Players").PlayerRemoving:Connect(function()
	task.defer(function()
		playerCount:set(#game:GetService("Players"):GetPlayers())
	end)
end)

window:selectTab(basics)
