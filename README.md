# ui library documentation

## getting started

everything starts with one line: you loadstring the library , then call `library.new` to make the window. that gives you back a `window`, and pretty much everything else (tabs, buttons, notifications, the settings drawer) comes off of that window.

here's the smallest thing that actually shows something on screen:

```lua
local library = loadstring(game:HttpGet("https://raw.githubusercontent.com/clemencyy/ui-library/refs/heads/main/src.lua"))()

local window = library.new({
	title = "my script",
	subtitle = "v1.0",
})

local mainTab = window:createTab({name = "main"})

mainTab:createToggle({
	title = "auto farm",
	callback = function(state)
		print("auto farm is now", state)
	end,
})
```

so the pattern is always: **window → tab → element**. you make a window once, make as many tabs as you want on it, and put elements (toggles, sliders, dropdowns...) on the tabs.
a quick word you'll see a lot: a **callback** is just a function you give an element, and the library runs it whenever someone changes that element. for a toggle it gets `true` or `false`, for a slider it gets the number, and so on.

### options for library.new

all of these go inside the table you pass to `library.new`. none of them are required except `title`.

| option | what to put | if you leave it out | what it does |
|---|---|---|---|
| `title` | text | nothing | the big name in the top left. the loader uses it too |
| `subtitle` | text | nothing | the small grey line under the title |
| `size` | UDim2 | the default size | how big the window is when it opens |
| `minSize` | Vector2 | 560, 340 | the smallest someone can drag the window down to |
| `icon` | an asset id, or an `rbxassetid://` string | no icon | a picture in the top left of the window |
| `display` | `"title"`, `"icon"` or `"both"` | `"both"` if you gave an icon, otherwise `"title"` | what shows in the top left (see below) |
| `loader` | a table, or `true` | no loader | plays a loading animation before the window shows up. see loaders |
| `configFolder` | text | nothing | the folder name the config box keeps its configs in |

#### title, icon or both

`display` picks what goes in the top left corner:

- **"title"**: just the title and subtitle, like normal.

- **"icon"**: just your icon, no text at all. good if your icon already has your name in it.

- **"both"**: the icon on the left with the title and subtitle right next to it.

tags (the little coloured badges) always sit right after whatever is showing. if you ask for `"icon"` or `"both"` but never gave an icon, it prints a warning and just shows the title instead.

you can change these after the window is made too:

```lua
window:setIcon(10734950309)
window:setDisplay("icon")
```

### loader options

these go inside the `loader` table. if you just write `loader = true`, you get the card loader with all the defaults.

| option | what to put | if you leave it out | what it does |
|---|---|---|---|
| `type` | `"card"` or `"terminal"` | `"card"` | which loader you get. card is a banner that grows into the window, terminal is a fake command line |
| `steps` | a list of text | 5 built-in steps | the status lines it shows while "loading" |
| `duration` | seconds | 2.8 | how long it takes to go through all the steps |
| `manual` | `true` / `false` | `false` | set to `true` if you want to move the progress bar yourself |
| `title` | text | the window title | the text on the banner or the terminal's top bar |
| `description` | text | the window subtitle | the line under the banner's title |
| `subtitle` | text | "welcome back," | card only. the small line above the player's name |
| `name` | text | the player's display name | card only. the big name in the middle |
| `logo` | an asset id or string | no logo | card only. shows a picture instead of the text banner |
| `command` | text | "./title --start" | terminal only. the command it pretends to type |
| `width` / `height` | numbers | 470 / 280 | terminal only. how big the terminal is |
| `callback` | a function | nothing | runs once the window has finished appearing |

## the window

the window is the main box everything lives in. people can drag it around by the top bar, resize it from the little dotted corner in the bottom right, and press ctrl+f to search every element in it.

here's everything you can call on it:

| call | what it does |
|---|---|
| `window:createTab({name, icon, order})` | adds a tab to the sidebar on the left and gives you the tab back |
| `window:createSection(name)` | puts a small uppercase heading in the sidebar, like main or extra, to group tabs |
| `window:createDivider()` | puts a thin line in the sidebar between groups of tabs |
| `window:createTag(text, color)` | adds a little coloured badge next to the title, like beta or free |
| `window:selectTab(tab)` | switches to a tab from your code, like clicking it |
| `window:toggle(state)` | shows (`true`) or hides (`false`) the window. leave it empty to flip it |
| `window:setToggleKey(key)` | changes which key shows and hides the window. it's rightshift until you change it |
| `window:setIcon(image)` / `window:setDisplay(mode)` | changes the icon, or what shows in the top left |
| `window:openSearch()` / `window:closeSearch()` | opens or closes the search bar at the top |
| `window:tooltip(thing, text)` | puts a hover tooltip on any gui object, even ones you made yourself |
| `window:dialog(config)` | pops up a dialog box. see dialogs |
| `window:showLoader(options)` | plays a loader again whenever you want |
| `library:notify(config)` | shows a notification in the bottom right. see notifications |
| `library:unload()` | deletes the whole ui and stops everything it was running |

```lua
window:setToggleKey(Enum.KeyCode.RightControl)
window:createTag("BETA", Color3.fromRGB(255, 195, 9))
window:createSection("MAIN")
local homeTab = window:createTab({name = "home", icon = "rbxassetid://10723407389"})
```

### tooltips

a tooltip is the little box that pops up when you hover over something. every element takes a `tooltip` option, so you don't need to do anything extra:

```lua
playerTab:createSlider({title = "walk speed", tooltip = "16 is the normal speed", min = 16, max = 120})
```

it waits about a third of a second, then types its text in, follows the mouse a little behind it, and has a soft shadow. if you move onto another element while one is showing, it switches to the new text straight away.

want one on something that isn't an element? use `window:tooltip(someFrame, "text")`.

i
### status bar

`window:createStatusBar(config)` adds a thin bar along the bottom of the window, kind of like the bar at the bottom of an app. everything above it shrinks a bit to make room.

- `text` puts a label on the left, like your version number.

- `fps = true` and `ping = true` add live fps and ping on the right. they update twice a second.

- `bind = true` puts a little key button on the very left that shows your toggle key. click it, then press any key, and that becomes the new key for showing and hiding the window. escape cancels. use `bind = "toggle"` (or any text) to change the label next to it.

you can add your own items to it too:

```lua
local status = window:createStatusBar({text = "v1.0", fps = true, ping = true, bind = true})

local players = status:add("players", 1)
players:set(2)
players:remove()
```

`status:add(name, value, side)` takes `"left"` (the default) or `"right"` for the side. if you didn't use `bind = true`, you can still add the key button later with `status:addBind(label)`. it stays in sync with `window:setToggleKey()` either way.

### settings drawer

`window:createSettings()` adds a gear button next to the bell. clicking it dims the window and slides a panel in from the right side. you close it by clicking the x, clicking the gear again, clicking anywhere outside the panel, or pressing escape. while it's open, nothing behind it can be clicked by accident.

the drawer starts out empty. it gives you back a normal tab, so you fill it the same way you'd fill any tab:

```lua
local settings = window:createSettings()

local mine = settings:createSection("your settings")
mine:createToggle({title = "show tooltips", default = true})
mine:createDropdown({title = "language", options = {"english", "tagalog"}})
```

| option | if you leave it out | what it does |
|---|---|---|
| `title` | "settings" | the heading at the top of the drawer |
| `width` | 280 | how wide the drawer is, in pixels |

you can also open and close it from code with `window:openSettings()`, `window:closeSettings()` and `window:toggleSettings()`. if you call `createSettings` twice, you just get the same drawer back, not a second one.

#### config box

`settings:createConfig()` adds a built-in section for saving and loading configs

the configs go in the folder you set with `configFolder` in `library.new`.

#### unload button

`settings:createUnload()` adds ared button that removes the whole ui when you click it (it calls `library:unload()`). it uses the same red style as the danger button in dialogs.

```lua
settings:createUnload({
	title = "unload",
	callback = function()
		print("bye")
	end,
})
```

`callback` is optional. if you give one, it runs right before the ui goes away, which is handy for turning off anything your script was doing.

## elements

elements are the things people actually click: toggles, sliders, dropdowns and so on. you always make them from a tab with `tab:createSomething({...})`, and they give you back an object you can keep to read or change them later.

a few things work the same on every element:

- `title` is the main text, `description` is the small grey line under it, and `tooltip` is the hover text.

- `callback` runs whenever someone changes the value.

- `value()` tells you the current value.

- `set(...)` changes the value from your code. use a colon, like `toggle:set(true)`. if you add `true` at the end, like `toggle:set(true, true)`, it changes without running the callback.

- `flag = "someName"` lets the library remember it for configs. see flags.

here's the full list:

| element | main options | what you get back |
|---|---|---|
| `createButton` | title, description, callback | `setText(text)` |
| `createHoldButton` | title, description, duration, text, `doneText`, callback | `setText(text)`, `cancel()` |
| `createToggle` | title, description, default (true/false), callback(state) | `value()`, `set(state)`, `toggle()` |
| `createCheckbox` | same as toggle, but a checkbox | `value()`, `set(state)`, `toggle()` |
| `createCheckbox` with `options` | options (a list), default (a list), callback(list) | `value()` gives a list, `set(list)` |
| `createSlider` | min, max, default, increment, display, marks, callback(number) | `value()`, `set(number)` |
| `createRangeSlider` | min, max, default {low, high}, increment, gap, display, callback(low, high) | `value()` gives two numbers, `set(low, high)` |
| `createDropdown` | options, default, multi, search, placeholder, callback | `value()`, `set(option)`, `setOptions(list)` |
| `createSegmented` | options, default, callback(option) | `value()`, `set(option)` |
| `createInput` | placeholder, default, limit, numerical, clear, password, autocompletes, callback(text) | `value()`, `set(text)` |
| `createKeybind` | default, type ("toggle" or "hold"), callback, `changedCallback(key)` | `value()`, `modifiers()`, `set(key)` |
| `createColorPicker` | default (a Color3), callback(color) | `value()`, `set(color)` |
| `createPlayerPicker` | type, show, multi, search, `includeSelf`, callback | `value()`, `set(player)`, `refresh()` |
| `createLabel` | text | `set(text)` |
| `createParagraph` | title, body | `set(title, body)` |
| `createDivider` | nothing | nothing |
| `createCustom` | name, title, height | `.frame`, `setHeight(number)` |

the rest of this part goes through the elements that have extra stuff worth knowing about.

### dropdowns

a dropdown has three ways it can work:

- **normal**: click it, pick one option, it closes and runs your callback with that option.

- **multi** (`multi = true`): you can pick more than one. it stays open while you pick, the box says something like "a, b" or "3 selected", and your callback gets a list. `default` can be a list too.

- **search** (`search = true`): adds a search box at the top so people can type to filter the options. great for long lists. the box gets focused when it opens and cleared when it closes.

```lua
tab:createDropdown({
	title = "pick a weapon",
	options = {"pistol", "shotgun", "sniper"},
	default = "pistol",
	search = true,
	callback = function(choice)
		print("picked", choice)
	end,
})
```

need to change the options later (like a list of maps that loads in)? use `dropdown:setOptions({...})`. if a dropdown is near the bottom of the page, the page grows so you can still scroll down and see the whole list.

### sliders

drag the bar to change the number. a few extras:

- **typing an exact number**: click the number on the right and type. the box grows as you type. press enter or click away, and it snaps to the nearest allowed value inside min and max.

- **increment**: what the number goes up by. `1` gives whole numbers, `0.5` lets you do halves.

- **display**: text stuck on the end of the number, like `" studs"` or `"%"`.

- **marks**: little labelled ticks under the bar. dragging near one snaps onto it, and clicking a mark's label jumps straight there.

```lua
tab:createSlider({
	title = "field of view",
	min = 50,
	max = 120,
	default = 70,
	marks = {["normal"] = 70, ["wide"] = 90, ["max"] = 120},
})
```

the number rolls to the new value instead of just jumping, which looks nicer.

### range sliders

a range slider is a slider with two knobs, one for a low number and one for a high number. clicking the bar grabs whichever knob is closer, and the knobs can't pass each other. `gap` keeps them at least that far apart.

```lua
local zoom = tab:createRangeSlider({
	title = "camera zoom",
	min = 0.5,
	max = 100,
	increment = 0.5,
	default = {5, 40},
	gap = 5,
	display = " studs",
	callback = function(low, high)
		print(low, high)
	end,
})

local low, high = zoom.value()
zoom:set(10, 60)
zoom:set(nil, 80)
```

passing `nil` for one side leaves that side where it is. you can click either number to type it in, same as a normal slider, and the callback only runs when a number actually changes.

### hold buttons

a hold button only does its thing after you hold it down for a bit. it's good for stuff people shouldn't click by accident, like resetting everything.

while you hold, an accent coloured fill sweeps across the button. the text it passes over switches to black or white (whichever is easier to read on your accent colour), so the colour change moves along with the fill. let go early and the fill drains back. when it finishes, the button glows, shows `doneText` for a moment, then resets.

```lua
tab:createHoldButton({
	title = "reset everything",
	description = "hold to confirm",
	duration = 1.5,
	text = "hold",
	doneText = "done",
	callback = function()
		print("reset")
	end,
})
```

it gives you back `setText(text)` and `cancel()`. the black-or-white trick is also available on its own: `library.contrast(color)` gives you back whichever of black or white is easier to read on that colour.

### inputs

inputs are text boxes. some handy options:

- `placeholder`: the grey hint text when it's empty.

- `numerical = true`: only lets people type numbers.

- `limit`: the most characters people can type.

- `clear = true`: empties the box after enter.

- `password = true`: hides what people type with dots, and adds a little "show" / "hide" button. your callback still gets the real text.

- `autocompletes`: a list of words. while typing, the rest of the first matching word shows up faded after what they typed, and enter or tab fills it in.

```lua
local command = tab:createInput({
	title = "run a command",
	autocompletes = {"teleport", "kill", "spectate"},
	callback = function(text)
		print("ran", text)
	end,
})

command.autocompletes = {"spawn", "spectate"}
```

### keybinds

a keybind lets people pick a key for something. click it, press a key, and that's the new key.

- `type = "toggle"` (the default) runs the callback each time the key is pressed. `type = "hold"` runs it with `true` when the key goes down and `false` when it comes back up.

- `callback` runs when the key is pressed. `changedCallback` runs when someone picks a different key, and gets the new key.

- **ctrl, shift and alt combos** work. set a default like `"Ctrl+K"`, or hold the modifiers while binding. tapping shift on its own just binds shift by itself.

- **clashes**: if two keybinds in the same window end up with the same key, both turn red, and hovering them tells you which one they clash with. it goes away by itself once one of them changes.

```lua
tab:createKeybind({
	title = "open menu",
	default = "Ctrl+K",
	callback = function()
		print("pressed")
	end,
	changedCallback = function(key)
		print("new key", key)
	end,
})
```

`modifiers()` gives you the list of held modifiers, and `set` takes either `"Ctrl+Shift+F"` or `(Enum.KeyCode.F, {"Ctrl"})`.

### color pickers

click the little colour pill and a panel opens with a big square for picking how bright and strong the colour is, a rainbow bar for picking the colour itself, a box for typing a hex code (like `ff9900` or the short `f90`), and a preview. click outside to close it.

### player pickers

a player picker lets people choose players in the server, with each player's face shown next to their name. it keeps itself up to date: people who join get added, and people who leave get removed (and if they were picked, they get unpicked and your callback runs).

| option | what it does |
|---|---|
| `type` | `"dropdown"` (the default) looks like a dropdown. `"list"` shows a full list box right on the page |
| `show` | `"both"` (default) shows the display name with a grey @username. `"username"` or `"display"` show just one |
| `multi = true` | lets people pick more than one. the callback gets a list of players |
| `search = true` | adds a search box that matches both kinds of names |
| `includeSelf = false` | hides you from the list. in the list type, your own row says "you" |
| `height` | how tall the list type is (default 210) |
| `default` | a player, a username, or a display name |

```lua
local target = tab:createPlayerPicker({
	title = "teleport to",
	search = true,
	callback = function(player)
		print(player and player.Name)
	end,
})
```

the callback and `value()` give you real Player objects (or `nil` if nobody is picked). `set()` takes a player or a name, and `refresh()` rebuilds the list if you ever need to.

## flags

a flag is a nickname you give an element so the library can remember it. once an element has a flag, you can read it, change it, or save and load it from anywhere, without keeping the element in a variable.

```lua
tab:createToggle({title = "auto farm", flag = "autoFarm"})
tab:createSlider({title = "speed", min = 0, max = 100, flag = "speed"})

print(library:getFlag("speed"))
library:setFlag("autoFarm", true)
```

| call | what it does |
|---|---|
| `library.flags.autoFarm` | the element itself, so you can call `:set()` and `:value()` on it |
| `library:getFlag(name)` | the current value of that flag |
| `library:setFlag(name, value)` | changes it. the element updates on screen and its callback runs. add `true` at the end to skip the callback |
| `library:getFlags()` | every flag and its value, in one table |
| `library:setFlags(table)` | puts a table like that back onto all the elements. names that don't exist anymore are skipped. add `true` at the end to skip callbacks |

flags work on elements anywhere: normal tabs, sections, groupboxes, sub-tabs, and the settings drawer. they only work on elements that hold a value, so buttons, hold buttons, labels, paragraphs and dividers can't have one (you'll just get a warning if you try). if two elements use the same flag name, you get a warning and the newest one wins.

`getFlags()` keeps every value simple, so the whole table can be turned into json and back without breaking:

| element | what its flag looks like |
|---|---|
| toggle, checkbox | `true` or `false` |
| slider | a number, like `42` |
| range slider | two numbers, like `{20, 70}` |
| dropdown, segmented, input | text, or a list of text for multi dropdowns |
| checkbox list | a list of text |
| color picker | a hex code, like `"#ff9900"` |
| keybind | text, like `"K"` or `"Ctrl+Shift+K"` |
| player picker | a username, or a list of usernames for multi |

when you load a keybind flag, its `changedCallback` runs too (unless you skip callbacks).

## sections

a section is a way to group elements under a heading inside a tab. it shows a small grey uppercase title with a line after it, then whatever you put in it.

```lua
local movement = tab:createSection("movement")
movement:createToggle({title = "auto sprint"})
movement:createSlider({title = "hip height", min = 0, max = 10, default = 2})
```

you make elements on a section exactly like on a tab. they still slide in with everything else and still show up in search. you can also rename it with `section:setTitle(text)`.

### folding sections

add `collapsible = true` and people can click the heading to fold the section shut. a little arrow shows up on the right, and the section slides open and closed. use `collapsed = true` to make it start folded.

```lua
local advanced = tab:createSection({title = "advanced", collapsed = true})
advanced:createToggle({title = "debug mode"})
```

foldable sections also have `collapse()`, `expand()`, `toggle()` and `collapsed()` (which tells you if it's folded right now). if someone searches for something inside a folded section, the section opens up first.

## groupboxes

groupboxes are boxes with a title that sit side by side in two columns, left and right. they're great for packing a lot of stuff into one tab without it being a long scroll.

```lua
local farming = tab:createGroupbox({title = "farming", side = "left"})
farming:createDropdown({title = "weapon", options = {"sword", "bow"}})
farming:createSlider({title = "range", min = 5, max = 50})

local auto = tab:createGroupbox({title = "auto", side = "right"})
auto:createToggle({title = "auto farm level"})
```

- `side` is `"left"` or `"right"`. if you leave it out, it goes on the left. more boxes on the same side stack downwards.

- the two columns show up where you make the first groupbox in that tab. anything you add straight to the tab after that goes underneath the columns.

- dropdowns inside a groupbox go full width under their title, since the columns are too skinny for the normal side-by-side look.

- groupboxes fold the same way sections do: `collapsible = true`, `collapsed = true`, and `collapse()`, `expand()`, `toggle()`, `collapsed()`.

- `setTitle(text)` renames it.

## sub-tabs

sub-tabs are tabs inside a tab. they show up as a row of names with a gold line under the one that's open.

```lua
local subTabs = extrasTab:createSubTabs()

local general = subTabs:createTab({name = "general"})
local visuals = subTabs:createTab({name = "visuals"})

general:createToggle({title = "auto save", default = true})
visuals:createColorPicker({title = "highlight colour"})
```

so you make the group with `createSubTabs()`, add pages to it with `createTab`, and then put elements on each page exactly like a normal tab. the first page you add is the one that's open at the start.

| call | what it does |
|---|---|
| `subTabs:select("visuals")` | switches to a page from your code |
| `subTabs:value()` | tells you which page is open |

when you switch pages, the old page slides out, the new one's elements slide in one by one, and a little tree line grows down the side connecting them. search can find things on pages that aren't open, and it switches to the right page before jumping there.

## notifications, dialogs and loaders

### notifications

`library:notify(config)` shows a little popup in the bottom right corner. hovering over it pauses its timer, and clicking it closes it.

| option | if you leave it out | what it does |
|---|---|---|
| `title` | "notification" | the bold first line |
| `body` | nothing | the second line |
| `type` | "default" | the colour and icon: `default`, `info`, `success`, `warning`, `error`, or `loading` (a spinner that stays until you change it) |
| `duration` | 3 | how many seconds it stays |
| `icon` | the type's icon | your own picture instead |
| `sticky = true` | off | no timer, it stays until clicked |
| `buttons` | none | buttons inside the notification, as text or `{text, type, callback}` |
| `group = false` | grouping on | always show a new one, even if the same one is already showing |

it gives you back a handle with `close()` and `update(config)`. `update` changes the notification in place, which is perfect for loading stuff:

```lua
local toast = library:notify({type = "loading", title = "saving", body = "hold on..."})

task.delay(2, function()
	toast:update({type = "success", title = "saved", body = "all done"})
end)
```

if the exact same notification (same type, title and text) is already on screen, it doesn't stack another copy. the one that's showing gets an x2, x3 counter and its timer starts over.

```lua
library:notify({
	type = "warning",
	title = "item deleted",
	body = "u can still bring it back",
	buttons = {
		{text = "undo", type = "accent", callback = function() print("undo") end},
		{text = "dismiss", type = "ghost"},
	},
})
```

### dialogs

`window:dialog(config)` pops up a box in the middle of the window asking the player something. enter picks the last button, and escape or clicking outside closes it. if you open another dialog while one is showing, it waits its turn.

| option | what it does |
|---|---|
| `title`, `body` | the heading and the text |
| `type` | same types as notifications. it colours the icon at the top |
| `buttons` | text, or `{text, type}`. button types are `default`, `accent`, `danger`, `success` and `ghost` |
| `callback(choice)` | runs with the text of the button they clicked |
| `danger = true` | makes the last button red |
| `duration` | closes by itself after this many seconds, if there are no buttons |
| `dismissable = false` | stops escape and outside clicks from closing it |

```lua
window:dialog({
	title = "unsaved changes",
	body = "what do u wanna do with them?",
	buttons = {
		{text = "cancel", type = "ghost"},
		{text = "discard", type = "danger"},
		{text = "save", type = "accent"},
	},
	callback = function(choice)
		print(choice)
	end,
})
```

add `input` and the dialog gets a text box. the callback then gets what they typed as a second value:

```lua
window:dialog({
	title = "name ur config",
	input = {placeholder = "my config..."},
	callback = function(choice, text)
		print(choice, text)
	end,
})
```

if you don't give buttons to an input dialog, it uses "cancel" and "confirm".

### loaders

a loader plays before the window shows up, so your script feels like it's booting up.

- **card loader**: a banner with a slowly moving grid, then a panel with the player's name and a progress bar. at the end, the title slides into the top bar and the card grows into the full window.

- **terminal loader**: a fake command line. it types a command, runs each step with a spinner that turns into `[ok]`, draws a text progress bar, then turns into the window.

both give you a controller (from `window.loader`, or from `window:showLoader(options)`). with `manual = true`, you move it along yourself:

| call | what it does |
|---|---|
| `loader:setStatus(text)` | changes the current step text |
| `loader:setProgress(number, text)` | moves the bar (0 is empty, 1 is full), and can change the step text too |
| `loader:finish()` | fills the bar and opens the window |

```lua
local loader = window:showLoader({type = "terminal", manual = true, steps = {"connecting"}})
loader:setProgress(0.5, "downloading settings")
loader:finish()
```
