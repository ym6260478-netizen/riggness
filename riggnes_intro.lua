-- riggnes v2.0
-- Intro: cmd window types the code -> black hole -> explosion -> menu (cannot be skipped)
-- Toggle UI: Right Ctrl or the floating gorilla orb (bottom-left)
-- Aimbot: enable in Combat tab, then HOLD RIGHT MOUSE BUTTON

print("[riggnes] starting...")
local __ok, __err = xpcall(function()

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local LP = Players.LocalPlayer
local Mouse = LP:GetMouse()

local PlayerGui = LP:WaitForChild("PlayerGui")
local old = PlayerGui:FindFirstChild("riggnes")
if old then old:Destroy() end
pcall(function() RunService:UnbindFromRenderStep("riggnes_aim") end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "riggnes"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 10000
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

-- =============================================
-- HELPERS
-- =============================================
local conns = {}
local function bind(signal, fn)
	local c = signal:Connect(fn)
	table.insert(conns, c)
	return c
end

local function cam() return workspace.CurrentCamera end
local function getHum()
	local c = LP.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end
local function getHRP()
	local c = LP.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local Theme = {
	Bg = Color3.fromRGB(10, 12, 28),
	Side = Color3.fromRGB(14, 17, 40),
	Panel = Color3.fromRGB(18, 22, 52),
	Item = Color3.fromRGB(24, 30, 68),
	ItemHover = Color3.fromRGB(36, 46, 100),
	Off = Color3.fromRGB(58, 72, 140),
	Text = Color3.fromRGB(255, 255, 255),
	Sub = Color3.fromRGB(150, 168, 230),
	Accent = Color3.fromRGB(0, 229, 255),
}

local accentFns = {}
local function onAccent(fn)
	table.insert(accentFns, fn)
	fn(Theme.Accent)
end
local function setAccent(c)
	Theme.Accent = c
	for _, fn in ipairs(accentFns) do fn(c) end
end

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function corner(o, r) return new("UICorner", {CornerRadius = UDim.new(0, r or 8)}, o) end
local function stroke(o, c, t, tr)
	return new("UIStroke", {Color = c, Thickness = t or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, o)
end
local function tween(o, t, p, style, dir)
	TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), p):Play()
end

-- =============================================
-- STATE
-- =============================================
-- =============================================
-- OWNER CONFIG  (edit these!)
-- Owners get a gold "RIGGNES OWNER" banner that every riggnes user sees above their head,
-- (the overhead banner has been removed) plus an extra "Owner" tab for the owner only.
-- =============================================
local OWNER_NAMES = {"PUT_YOUR_ROBLOX_USERNAME_HERE"}  -- your exact Roblox username (not display name)
local OWNER_IDS = {}                                    -- or UserIds, e.g. {123456789}
local OWNER_LIST_URL = ""                               -- optional: raw link to a text file, one username/UserId per line
local OWNER_GOLD = Color3.fromRGB(255, 200, 60)
local ownerSet, ownerIdSet = {}, {}
for _, n in ipairs(OWNER_NAMES) do ownerSet[string.lower(n)] = true end
for _, i in ipairs(OWNER_IDS) do ownerIdSet[i] = true end
local function isOwner(plr)
	return plr ~= nil and (ownerSet[string.lower(plr.Name)] == true or ownerIdSet[plr.UserId] == true)
end

local origGravity = workspace.Gravity
local S = {
	-- movement
	fly = false, flySpeed = 60,
	noclip = false, infJump = false, clickTP = false, dash = false, bhop = false,
	spin = false, spinSpeed = 360,
	walk = 16, walkCustom = false, jump = 50, jumpCustom = false,
	fov = 70, fovCustom = false,
	-- visual / world
	esp = false, espHealth = true, espDist = true, fullbright = false, nofog = false,
	crosshair = false, afk = false,
	-- players
	target = nil, mode = nil, spec = false,
	headOffset = 2.2, dist = 4, orbitRadius = 6, orbitSpeed = 2, orbitAngle = 0,
	savedPos = nil, lastDash = 0,
	-- combat
	boostMult = 2.5, goldFly = false, aura = false, tagSelf = false, tagText = "RIGGNES USER", tagged = {}, flyStyle = "Hero", rainbow = false, uiScale = 1, flyPitch = 0, flyRoll = 0, flyYaw = 0, flyFovAdd = 0, aim = false, aimPred = 0, antivoid = false, aimFov = 150, aimSmooth = 4, aimPart = "Head", aimDist = 500,
	teamCheck = false, wallCheck = true, showFov = true,
	trigger = false, lastTrig = 0,
	hitbox = false, hitboxSize = 6,
}

-- =============================================
-- SOUNDS
-- =============================================
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")

-- Each list is tried in order; the first ID that actually loads gets played.
-- Swap in any Roblox audio ID you like.
local SoundBank = {
	open  = {"rbxassetid://9118823104", "rbxassetid://6895079853", "rbxassetid://4590662766"},
	close = {"rbxassetid://9118822716", "rbxassetid://6895079853", "rbxassetid://4590662766"},
}

-- plays a sound with a pitch sweep + reverb so it feels like a "whoosh"
local function playSweep(list, fromSpeed, toSpeed, dur, vol, delay)
	task.spawn(function()
		if delay then task.wait(delay) end
		for _, id in ipairs(list) do
			local s = new("Sound", {SoundId = id, Volume = vol, PlaybackSpeed = fromSpeed}, ScreenGui)
			pcall(function() ContentProvider:PreloadAsync({s}) end)
			if s.TimeLength > 0 then
				new("EqualizerSoundEffect", {HighGain = 5, MidGain = 0, LowGain = -3}, s)
				new("ReverbSoundEffect", {DecayTime = 1.4, Density = 0.7, Diffusion = 0.8, DryLevel = 0, WetLevel = -5}, s)
				s:Play()
				tween(s, dur, {PlaybackSpeed = toSpeed}, Enum.EasingStyle.Quad)
				Debris:AddItem(s, math.max(s.TimeLength / math.max(toSpeed, 0.1), 1.5) + 1)
				return
			end
			s:Destroy()
		end
	end)
end

-- ---- menu UI sounds (hover / click / toggle / tab / notify) ----
local UIBank = {"rbxassetid://6895079853", "rbxassetid://4590662766", "rbxassetid://9118823104"}
local uiSound, uiLoading = nil, false
local function loadUISound()
	if uiLoading then return end
	uiLoading = true
	task.spawn(function()
		for _, id in ipairs(UIBank) do
			local sn = new("Sound", {SoundId = id, Volume = 0.5}, ScreenGui)
			pcall(function() ContentProvider:PreloadAsync({sn}) end)
			if sn.TimeLength > 0 then uiSound = sn return end
			sn:Destroy()
		end
	end)
end
-- pitch changes make one sample feel like many different UI sounds
local function playUI(speed, vol)
	if not uiSound then loadUISound() return end
	local c = uiSound:Clone()
	c.PlaybackSpeed = speed or 1
	c.Volume = vol or 0.5
	c.Parent = ScreenGui
	c:Play()
	Debris:AddItem(c, 2)
end
loadUISound()

local T = {}      -- handles to toggles so keybinds can flip them
local toggleUI    -- assigned later

-- ---- saved settings (needs executor readfile/writefile) ----
local CFG_FILE = "riggnes_settings.json"
local cfg = {}
if typeof(isfile) == "function" and typeof(readfile) == "function" then
	pcall(function()
		if isfile(CFG_FILE) then cfg = HttpService:JSONDecode(readfile(CFG_FILE)) end
	end)
end
if type(cfg) ~= "table" then cfg = {} end
local saveToken = 0
local function saveCfg()
	if typeof(writefile) ~= "function" then return end
	saveToken += 1
	local my = saveToken
	task.delay(0.4, function() -- debounce so holding a stepper doesn't spam the disk
		if my ~= saveToken then return end
		pcall(function() writefile(CFG_FILE, HttpService:JSONEncode(cfg)) end)
	end)
end
S.keybindsOn = true -- menu/keybind system is always enabled
if type(cfg.tagText) == "string" and cfg.tagText ~= "" then S.tagText = cfg.tagText end
if tonumber(cfg.uiScale) then S.uiScale = math.clamp(cfg.uiScale / 100, 0.6, 1.6) end

local function playOpenSound()
	playSweep(SoundBank.open, 0.55, 1.5, 0.45, 1.3)         -- rising whoosh
	playSweep(SoundBank.open, 1.4, 2.4, 0.35, 0.55, 0.07)   -- sparkle layer
	playSweep(SoundBank.open, 0.35, 0.5, 0.4, 0.8)          -- sub thump
	playSweep(SoundBank.open, 2.0, 2.6, 0.2, 0.3, 0.2)      -- high chime tail
end
local function playCloseSound()
	playSweep(SoundBank.close, 1.6, 0.55, 0.4, 1.3)         -- falling whoosh
	playSweep(SoundBank.close, 0.8, 0.4, 0.3, 0.7, 0.04)    -- low thud
	playSweep(SoundBank.close, 2.2, 1.2, 0.2, 0.3)          -- soft ping
end

-- =============================================
-- NOTIFICATIONS
-- =============================================
local toasts = new("Frame", {
	BackgroundTransparency = 1, Size = UDim2.new(0, 300, 0, 220),
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20),
}, ScreenGui)
new("UIListLayout", {
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 6),
}, toasts)

local function notify(msg)
	playUI(1.8, 0.45)
	local t = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 1, TextTransparency = 1, Text = msg,
		Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text,
	}, toasts)
	corner(t, 8)
	local s = stroke(t, Theme.Accent, 1, 1)
	tween(t, 0.2, {BackgroundTransparency = 0.1, TextTransparency = 0})
	tween(s, 0.2, {Transparency = 0.3})
	task.delay(2.2, function()
		if not t.Parent then return end
		tween(t, 0.25, {BackgroundTransparency = 1, TextTransparency = 1})
		tween(s, 0.25, {Transparency = 1})
		task.wait(0.3)
		t:Destroy()
	end)
end

-- =============================================
-- MAIN WINDOW (sidebar layout)
-- =============================================
local Main = new("CanvasGroup", {
	Name = "Main", Size = UDim2.new(0, 680, 0, 490),
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
	BackgroundColor3 = Theme.Bg, Visible = false, GroupTransparency = 1,
}, ScreenGui)
corner(Main, 16)
local mainStroke = stroke(Main, Theme.Accent, 2.5, 0)
onAccent(function(c) mainStroke.Color = c end)
local uiScale = new("UIScale", {Scale = 0.92}, Main)

-- header (drag handle)
local Header = new("Frame", {Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = Theme.Side, BorderSizePixel = 0}, Main)
local TopBar = new("Frame", {Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0}, Header)
local topGrad = new("UIGradient", {}, TopBar)
onAccent(function(c)
	local h, s, v = c:ToHSV()
	topGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, c),
		ColorSequenceKeypoint.new(0.5, Color3.fromHSV((h + 0.14) % 1, s, v)),
		ColorSequenceKeypoint.new(1, c),
	})
end)
local Title = new("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.new(0, 16, 0, 3), Size = UDim2.new(0, 100, 1, -3),
	Text = "riggnes", Font = Enum.Font.GothamBlack, TextSize = 24,
	TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Left,
}, Header)
onAccent(function(c) Title.TextColor3 = c end)
new("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.new(0, 108, 0, 8), Size = UDim2.new(0, 40, 1, -3),
	Text = "v2.0", Font = Enum.Font.GothamMedium, TextSize = 11,
	TextColor3 = Theme.Sub, TextXAlignment = Enum.TextXAlignment.Left,
}, Header)
local PageTitle = new("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.new(0, 170, 0, 3), Size = UDim2.new(1, -240, 1, -3),
	Text = "", Font = Enum.Font.GothamBold, TextSize = 15,
	TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
}, Header)

local CloseBtn = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 2), Size = UDim2.new(0, 28, 0, 28),
	BackgroundColor3 = Theme.Item, Text = "×", Font = Enum.Font.GothamBold, TextSize = 20,
	TextColor3 = Theme.Text, AutoButtonColor = false,
}, Header)
corner(CloseBtn, 8)
CloseBtn.MouseEnter:Connect(function() tween(CloseBtn, 0.12, {BackgroundColor3 = Color3.fromRGB(200, 60, 70)}) end)
CloseBtn.MouseLeave:Connect(function() tween(CloseBtn, 0.12, {BackgroundColor3 = Theme.Item}) end)

do -- dragging (mouse + touch)
	local dragging, dragStart, startPos
	Header.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = i.Position
			startPos = Main.Position
			i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	bind(UIS.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - dragStart
			Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
end

-- sidebar
local Sidebar = new("Frame", {Position = UDim2.new(0, 0, 0, 46), Size = UDim2.new(0, 150, 1, -46), BackgroundColor3 = Theme.Side, BorderSizePixel = 0}, Main)
local SideList = new("Frame", {Position = UDim2.new(0, 8, 0, 10), Size = UDim2.new(1, -16, 1, -90), BackgroundTransparency = 1}, Sidebar)
new("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, SideList)

-- profile card at bottom of sidebar
local prof = new("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -8), Size = UDim2.new(1, -16, 0, 68), BackgroundColor3 = Theme.Item}, Sidebar)
corner(prof, 10)
local av = new("ImageLabel", {Position = UDim2.new(0, 7, 0.5, -20), Size = UDim2.new(0, 40, 0, 40), BackgroundColor3 = Theme.Bg, Image = ""}, prof)
corner(av, 20)
local avStroke = stroke(av, Theme.Accent, 1.5, 0)
onAccent(function(c) avStroke.Color = c end)
task.spawn(function()
	local ok, img = pcall(function()
		return Players:GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	end)
	if ok then av.Image = img end
end)
new("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.new(0, 54, 0, 9), Size = UDim2.new(1, -58, 0, 16),
	Text = LP.DisplayName, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Text,
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
}, prof)
new("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.new(0, 54, 0, 25), Size = UDim2.new(1, -58, 0, 14),
	Text = "@" .. LP.Name, Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = Theme.Sub,
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
}, prof)
T.execProf = new("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.new(0, 54, 0, 42), Size = UDim2.new(1, -58, 0, 14),
	Text = "Exec: ...", Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Theme.Accent,
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
}, prof)
onAccent(function(c) T.execProf.TextColor3 = c end)

local Content = new("Frame", {Position = UDim2.new(0, 160, 0, 54), Size = UDim2.new(1, -170, 1, -80), BackgroundTransparency = 1, ClipsDescendants = true}, Main)
new("TextLabel", {
	BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 164, 1, -6), Size = UDim2.new(1, -180, 0, 16),
	Text = "Keybinds in Settings tab  •  riggnes v2.0", Font = Enum.Font.Gotham, TextSize = 11,
	TextColor3 = Theme.Sub, TextXAlignment = Enum.TextXAlignment.Left,
}, Main)

local tabNames = {"Combat", "Movement", "Players", "Visual", "World", "Settings"}
if isOwner(LP) then table.insert(tabNames, "Owner") end
local tabBtns, pages = {}, {}

local function makePage()
	local p = new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(), Visible = false,
	}, Content)
	new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, p)
	new("UIPadding", {PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8)}, p)
	return p
end

local currentTab = 1
local function selectTab(i)
	currentTab = i
	for idx, pg in ipairs(pages) do
		local on = idx == i
		pg.Visible = on
		tween(tabBtns[idx], 0.15, {
			TextColor3 = on and Theme.Accent or Theme.Sub,
			BackgroundColor3 = on and Theme.Accent:Lerp(Theme.Item, 0.8) or Theme.Side,
		})
	end
	PageTitle.Text = tabNames[i]
end

for i, name in ipairs(tabNames) do
	local b = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = Theme.Side, Text = name, LayoutOrder = i,
		Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.Sub, AutoButtonColor = false,
	}, SideList)
	corner(b, 8)
	b.MouseButton1Click:Connect(function() playUI(1.1, 0.45) selectTab(i) end)
	b.MouseEnter:Connect(function() if currentTab ~= i then tween(b, 0.12, {BackgroundColor3 = Theme.Panel}) end end)
	b.MouseLeave:Connect(function() if currentTab ~= i then tween(b, 0.12, {BackgroundColor3 = Theme.Side}) end end)
	tabBtns[i] = b
	pages[i] = makePage()
end
onAccent(function() if pages[currentTab] then selectTab(currentTab) end end)
local PgCombat, PgMove, PgPlayers, PgVisual, PgWorld, PgSettings = pages[1], pages[2], pages[3], pages[4], pages[5], pages[6]
local PgOwner = pages[7]

-- =============================================
-- UI COMPONENTS
-- =============================================
local function section(page, text)
	new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Text = string.upper(text),
		Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Theme.Sub, TextXAlignment = Enum.TextXAlignment.Left,
	}, page)
end

local function toggle(page, text, default, cb)
	local row = new("TextButton", {Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Theme.Item, Text = "", AutoButtonColor = false}, page)
	corner(row, 8)
	stroke(row, Theme.Off, 1, 0.5)
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -70, 1, 0),
		Text = text, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	local sw = new("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 40, 0, 20), BackgroundColor3 = Theme.Off}, row)
	corner(sw, 10)
	local knob = new("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.new(0, 16, 0, 16), BackgroundColor3 = Color3.new(1, 1, 1)}, sw)
	corner(knob, 8)
	local state = default
	local function render()
		tween(sw, 0.15, {BackgroundColor3 = state and Theme.Accent or Theme.Off})
		tween(knob, 0.15, {Position = state and UDim2.new(0, 22, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)}, Enum.EasingStyle.Back)
	end
	local api = {}
	function api.set(v, silent)
		state = v
		render()
		if not silent then cb(v) end
	end
	function api.get() return state end
	row.MouseButton1Click:Connect(function() api.set(not state) playUI(state and 1.5 or 0.85, 0.5) end)
	row.MouseEnter:Connect(function() playUI(2.4, 0.08) tween(row, 0.12, {BackgroundColor3 = Theme.ItemHover}) end)
	row.MouseLeave:Connect(function() tween(row, 0.12, {BackgroundColor3 = Theme.Item}) end)
	onAccent(function() render() end)
	return api
end

local function stepper(page, text, value, min, max, step, cb, fmt)
	local row = new("Frame", {Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Theme.Item}, page)
	corner(row, 8)
	stroke(row, Theme.Off, 1, 0.5)
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -150, 1, 0),
		Text = text, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	local function mk(txt, x)
		local b = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, x, 0.5, 0), Size = UDim2.new(0, 28, 0, 24),
			BackgroundColor3 = Theme.Off, Text = txt, Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Theme.Text, AutoButtonColor = false,
		}, row)
		corner(b, 6)
		return b
	end
	local minus, plus = mk("-", -98), mk("+", -10)
	local valLbl = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -42, 0.5, 0), Size = UDim2.new(0, 52, 0, 24),
		BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.Accent,
	}, row)
	onAccent(function(c) valLbl.TextColor3 = c end)

	local api = {}
	local function show() valLbl.Text = fmt and fmt(value) or tostring(value) end
	function api.set(v, silent)
		value = math.clamp(v, min, max)
		show()
		if not silent then cb(value) end
	end
	function api.get() return value end
	show()

	local holdId = 0
	local function hold(btn, delta)
		btn.MouseButton1Down:Connect(function()
			holdId += 1
			local my = holdId
			playUI(delta > 0 and 1.35 or 1.0, 0.35)
			api.set(value + delta)
			task.spawn(function()
				task.wait(0.4)
				while holdId == my do
					api.set(value + delta)
					task.wait(0.06)
				end
			end)
		end)
		local function stop() holdId += 1 end
		btn.MouseButton1Up:Connect(stop)
		btn.MouseLeave:Connect(stop)
	end
	hold(minus, -step)
	hold(plus, step)
	return api
end

local function button(parent, text, cb, h)
	local b = new("TextButton", {
		Size = UDim2.new(1, 0, 0, h or 34), BackgroundColor3 = Theme.Item, Text = text,
		Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.Text, AutoButtonColor = false,
	}, parent)
	corner(b, 8)
	local st = stroke(b, Theme.Accent, 1.5, 0.35)
	b.MouseEnter:Connect(function()
		playUI(2.4, 0.08)
		if not b:GetAttribute("Active") then tween(b, 0.12, {BackgroundColor3 = Theme.ItemHover}) end
		tween(st, 0.12, {Transparency = 0})
	end)
	b.MouseLeave:Connect(function()
		if not b:GetAttribute("Active") then tween(b, 0.12, {BackgroundColor3 = Theme.Item}) end
		tween(st, 0.12, {Transparency = 0.35})
	end)
	b.MouseButton1Click:Connect(function() playUI(1.2, 0.5) cb(b) end)
	onAccent(function(c)
		st.Color = c
		if b:GetAttribute("Active") then
			b.TextColor3 = c
			b.BackgroundColor3 = c:Lerp(Theme.Item, 0.7)
		end
	end)
	return b
end

local function setActive(b, on)
	b:SetAttribute("Active", on)
	tween(b, 0.15, {
		BackgroundColor3 = on and Theme.Accent:Lerp(Theme.Item, 0.7) or Theme.Item,
		TextColor3 = on and Theme.Accent or Theme.Text,
	})
end

local function grid(page)
	local g = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1}, page)
	new("UIGridLayout", {CellSize = UDim2.new(0.5, -3, 0, 32), CellPadding = UDim2.new(0, 6, 0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, g)
	return g
end

-- =============================================
-- FLY / MODES / ESP / LIGHTING LOGIC
-- =============================================
local bv, bg

-- expanding energy ring (takeoff / boost / barrel roll)
local function shockwave(pos, dir)
	local ring = new("Part", {
		Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2, 2), Material = Enum.Material.Neon,
		Color = Theme.Accent, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		Transparency = 0.15, CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.rad(90), 0),
	}, workspace)
	TweenService:Create(ring, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = Vector3.new(0.3, 38, 38), Transparency = 1}):Play()
	Debris:AddItem(ring, 0.7)
end
local function stopFly()
	if bv then bv:Destroy() bv = nil end
	if bg then bg:Destroy() bg = nil end
	if T.joints then
		for _, d in pairs(T.joints) do
			if d.motor and d.motor.Parent then d.motor.C0 = d.c0 end
		end
		T.joints = nil
	end
	if T.fx then
		for _, o in pairs(T.fx) do if typeof(o) == "Instance" then o:Destroy() end end
		T.fx = nil
	end
	local hrp = getHRP()
	if hrp then -- level the character back upright
		local l = hrp.CFrame.LookVector
		local flat = Vector3.new(l.X, 0, l.Z)
		if flat.Magnitude > 0.01 then hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + flat) end
	end
	S.flyPitch, S.flyRoll = 0, 0
	local h = getHum()
	if h then h.PlatformStand = false end
end
local function startFly()
	local hrp, h = getHRP(), getHum()
	if not hrp or not h then return end
	stopFly()
	h.PlatformStand = true
	bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
	bv.Velocity = Vector3.new()
	bv.Parent = hrp
	bg = Instance.new("BodyGyro")
	bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
	bg.P = 1e4
	bg.D = 500
	bg.CFrame = hrp.CFrame
	bg.Parent = hrp

	-- fly effects: glowing trail + sparkles + launch burst
	local a0 = new("Attachment", {Position = Vector3.new(0, 0.9, 0)}, hrp)
	local a1 = new("Attachment", {Position = Vector3.new(0, -0.9, 0)}, hrp)
	local trail = new("Trail", {
		Attachment0 = a0, Attachment1 = a1, Lifetime = 0.4, LightEmission = 1, Enabled = false,
		Color = ColorSequence.new(Theme.Accent),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)}),
		WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)}),
	}, hrp)
	local em = new("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 0,
		Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(1, 4), SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)}),
		LightEmission = 1, Color = ColorSequence.new(Theme.Accent),
	}, hrp)
	T.fx = {a0 = a0, a1 = a1, trail = trail, em = em}
	-- long vapor trails streaming off the shoulders
	for idx, sx in ipairs({-1.9, 1.9}) do
		local w0 = new("Attachment", {Position = Vector3.new(sx, 0.6, 0)}, hrp)
		local w1 = new("Attachment", {Position = Vector3.new(sx, -0.6, 0)}, hrp)
		local wt = new("Trail", {
			Attachment0 = w0, Attachment1 = w1, Lifetime = 0.6, LightEmission = 0.8, Enabled = false, MinLength = 0.05,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Theme.Accent),
			Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)}),
			WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0)}),
		}, hrp)
		T.fx["w0_" .. idx] = w0
		T.fx["w1_" .. idx] = w1
		T.fx["wt_" .. idx] = wt
	end
	shockwave(hrp.Position, Vector3.new(0, 1, 0))

	-- limb animation (R15 only): remember original joint positions
	T.joints = nil
	if h.RigType == Enum.HumanoidRigType.R15 then
		local wanted = {Neck = true, LeftShoulder = true, RightShoulder = true, LeftHip = true, RightHip = true, LeftKnee = true, RightKnee = true, LeftAnkle = true, RightAnkle = true}
		local js = {}
		for _, m in ipairs(LP.Character:GetDescendants()) do
			if m:IsA("Motor6D") and wanted[m.Name] then js[m.Name] = {motor = m, c0 = m.C0} end
		end
		T.joints = js
	end
	em:Emit(40)
	S.flyBaseFov = cam().FieldOfView
	pcall(function() playSweep(SoundBank.open, 0.6, 1.8, 0.4, 0.8) end)
end
-- keep fly effects in sync with the accent color
onAccent(function(c)
	if T.fx then
		T.fx.trail.Color = ColorSequence.new(c)
		T.fx.em.Color = ColorSequence.new(c)
	end
end)

local flyToggle
local modeBtns = {}
local function refreshModeButtons()
	for name, b in pairs(modeBtns) do setActive(b, S.mode == name) end
end
local function setMode(m)
	if S.mode == m then m = nil end
	if m and not S.target then
		notify("Select a player first")
		return
	end
	if S.mode == "sit" and m ~= "sit" then
		local h = getHum()
		if h then h.Sit = false end
	end
	if m and S.fly and flyToggle then flyToggle.set(false) end
	S.mode = m
	refreshModeButtons()
	if m then notify("Mode: " .. m .. " → " .. S.target.DisplayName) end
end

-- ESP (highlight + name / health / distance)
local esp = {}
local function clearESP(plr)
	local e = esp[plr]
	if e then
		for _, o in pairs(e) do if typeof(o) == "Instance" then o:Destroy() end end
		esp[plr] = nil
	end
end
local function applyESP(plr)
	clearESP(plr)
	if not S.esp or plr == LP then return end
	local char = plr.Character
	if not char then return end
	local hl = new("Highlight", {
		FillColor = Theme.Accent, FillTransparency = 0.75, OutlineColor = Theme.Accent,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
	}, char)
	local head = char:FindFirstChild("Head")
	local bb, lbl
	if head then
		bb = new("BillboardGui", {Size = UDim2.new(0, 160, 0, 34), StudsOffset = Vector3.new(0, 2.8, 0), AlwaysOnTop = true, Adornee = head}, head)
		lbl = new("TextLabel", {
			Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = plr.DisplayName,
			Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Accent, TextStrokeTransparency = 0.4,
		}, bb)
	end
	esp[plr] = {hl = hl, bb = bb, lbl = lbl}
end
onAccent(function(c)
	for _, e in pairs(esp) do
		if e.hl then e.hl.FillColor = c e.hl.OutlineColor = c end
		if e.lbl then e.lbl.TextColor3 = c end
	end
end)
local function setESP(on)
	S.esp = on
	for _, plr in ipairs(Players:GetPlayers()) do
		if on then applyESP(plr) else clearESP(plr) end
	end
end
local function updateESPText()
	local myHRP = getHRP()
	for plr, e in pairs(esp) do
		if e.lbl and plr.Character then
			local h = plr.Character:FindFirstChildOfClass("Humanoid")
			local r = plr.Character:FindFirstChild("HumanoidRootPart")
			local txt = plr.DisplayName
			if S.espHealth and h then txt ..= "  [" .. math.floor(h.Health) .. " HP]" end
			if S.espDist and myHRP and r then txt ..= "\n" .. math.floor((myHRP.Position - r.Position).Magnitude) .. " studs" end
			e.lbl.Text = txt
		end
	end
end

-- Lighting
local lightSaved
local function saveLight()
	if not lightSaved then
		lightSaved = {Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, FogEnd = Lighting.FogEnd, GlobalShadows = Lighting.GlobalShadows, Ambient = Lighting.Ambient}
	end
end
local function setFullbright(on)
	S.fullbright = on
	if on then
		saveLight()
		Lighting.Brightness = 2
		Lighting.ClockTime = 14
		Lighting.FogEnd = 1e6
		Lighting.GlobalShadows = false
		Lighting.Ambient = Color3.fromRGB(178, 178, 178)
	elseif lightSaved then
		for k, v in pairs(lightSaved) do Lighting[k] = v end
		lightSaved = nil
	end
end

-- Spectate
local function setSpectate(on)
	if on and not S.target then notify("Select a player first") return false end
	S.spec = on
	if not on then
		local h = getHum()
		if h then cam().CameraSubject = h end
	end
	return true
end

-- Hitbox expander
local hitboxSaved = {}
local function restoreHitboxes()
	for part, d in pairs(hitboxSaved) do
		if part and part.Parent then
			part.Size = d.Size
			part.Transparency = d.Transparency
			part.CanCollide = d.CanCollide
		end
	end
	hitboxSaved = {}
end
local function applyHitboxes()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LP and plr.Character then
			if not (S.teamCheck and LP.Team and plr.Team == LP.Team) then
				local r = plr.Character:FindFirstChild("HumanoidRootPart")
				if r then
					if not hitboxSaved[r] then
						hitboxSaved[r] = {Size = r.Size, Transparency = r.Transparency, CanCollide = r.CanCollide}
					end
					r.Size = Vector3.new(S.hitboxSize, S.hitboxSize, S.hitboxSize)
					r.Transparency = 0.7
					r.CanCollide = false
				end
			end
		end
	end
end

-- =============================================
-- AIMBOT
-- =============================================
-- =============================================
-- SCRIPT TAGS (banner above a player's head, only visible on YOUR screen)
-- =============================================
local tags = {}
local function clearTag(plr)
	local t = tags[plr]
	if t then
		if t.gui then t.gui:Destroy() end
		if t.att then t.att:Destroy() end
		tags[plr] = nil
	end
end
local function makeTag(plr)
	clearTag(plr)
	local char = plr.Character
	local head = char and char:FindFirstChild("Head")
	if not head then return end
	local gui = new("BillboardGui", {
		Name = "riggnes_tag", Adornee = head, Size = UDim2.new(0, 230, 0, 52),
		StudsOffset = Vector3.new(0, 4.4, 0), AlwaysOnTop = true, MaxDistance = 200, LightInfluence = 0,
	}, head)
	local card = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(10, 12, 22), BackgroundTransparency = 0.08}, gui)
	corner(card, 14)
	local owner = isOwner(plr)
	local col = owner and OWNER_GOLD or Theme.Accent
	local st = stroke(card, col, 2.5, 0)
	new("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(24, 28, 52), Color3.fromRGB(8, 10, 18)), Rotation = 90}, card)
	local badge = new("Frame", {Position = UDim2.new(0, 8, 0.5, -17), Size = UDim2.new(0, 34, 0, 34), BackgroundColor3 = col}, card)
	corner(badge, 9)
	new("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = owner and "OWN" or "RG", Font = Enum.Font.GothamBlack,
		TextSize = owner and 11 or 16, TextColor3 = Color3.fromRGB(8, 12, 24),
	}, badge)
	local title = new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 50, 0, 6), Size = UDim2.new(1, -58, 0, 22),
		Text = owner and "RIGGNES OWNER" or S.tagText, Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = col,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
	}, card)
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 50, 0, 28), Size = UDim2.new(1, -58, 0, 16),
		Text = "@" .. plr.Name .. "  ✓", Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Theme.Sub,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
	}, card)
	local att
	if owner then -- gold sparkles floating around the owner's head
		att = new("Attachment", {Position = Vector3.new(0, 1.5, 0)}, head)
		new("ParticleEmitter", {
			Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 14, Lifetime = NumberRange.new(0.8, 1.4),
			Speed = NumberRange.new(0.5, 2), SpreadAngle = Vector2.new(180, 180), LightEmission = 1,
			Color = ColorSequence.new(OWNER_GOLD),
			Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0)}),
			Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)}),
		}, att)
	end
	tags[plr] = {gui = gui, stroke = st, badge = badge, title = title, owner = owner, att = att}
end
onAccent(function(c)
	for _, t in pairs(tags) do
		if not t.owner then
			t.stroke.Color = c
			t.badge.BackgroundColor3 = c
			t.title.TextColor3 = c
		end
	end
end)
local tagClock = 0
bind(RunService.RenderStepped, function(dt)
	tagClock += dt
	local i = 0
	for _, t in pairs(tags) do
		i += 1
		if t.gui and t.gui.Parent then
			t.gui.StudsOffset = Vector3.new(0, 4.4 + math.sin(tagClock * 2 + i) * 0.12, 0) -- gentle float
			t.stroke.Thickness = 2.2 + math.sin(tagClock * 3 + i) * 0.7                    -- pulsing border
		end
	end
end)
local function refreshTag(plr)
	clearTag(plr) -- banner/tag removed: never show anything above heads
end

local fovCircle = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false,
	Size = UDim2.new(0, S.aimFov * 2, 0, S.aimFov * 2),
}, ScreenGui)
corner(fovCircle, 1000)
local fovStroke = stroke(fovCircle, Theme.Accent, 1.5, 0.2)
onAccent(function(c) fovStroke.Color = c end)

local function visibleTo(c, part, char)
	if not S.wallCheck then return true end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {LP.Character, char}
	local origin = c.CFrame.Position
	local res = workspace:Raycast(origin, part.Position - origin, params)
	return res == nil
end

local function getClosest()
	local c = cam()
	local mpos = UIS:GetMouseLocation()
	local best, bestD = nil, S.aimFov
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LP and plr.Character then
			local char = plr.Character
			local hum = char:FindFirstChildOfClass("Humanoid")
			local part = char:FindFirstChild(S.aimPart) or char:FindFirstChild("HumanoidRootPart")
			if hum and hum.Health > 0 and part then
				if not (S.teamCheck and LP.Team and plr.Team == LP.Team) then
					if (part.Position - c.CFrame.Position).Magnitude <= S.aimDist then
						local v, on = c:WorldToViewportPoint(part.Position)
						if on then
							local d = (Vector2.new(v.X, v.Y) - mpos).Magnitude
							if d < bestD and visibleTo(c, part, char) then
								best, bestD = part, d
							end
						end
					end
				end
			end
		end
	end
	return best
end

RunService:BindToRenderStep("riggnes_aim", Enum.RenderPriority.Camera.Value + 1, function()
	local mpos = UIS:GetMouseLocation()
	fovCircle.Position = UDim2.new(0, mpos.X, 0, mpos.Y)
	fovCircle.Visible = S.aim and S.showFov
	if S.aim and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
		local part = getClosest()
		if part then
			local c = cam()
			local goal = CFrame.lookAt(c.CFrame.Position, part.Position + part.AssemblyLinearVelocity * (S.aimPred / 100))
			c.CFrame = c.CFrame:Lerp(goal, 1 / math.max(S.aimSmooth, 1))
		end
	end
end)

-- =============================================
-- PAGE: COMBAT
-- =============================================
section(PgCombat, "Aimbot  (hold Right Mouse)")
T.aim = toggle(PgCombat, "Aimbot", false, function(v) S.aim = v end)
toggle(PgCombat, "Show FOV Circle", true, function(v) S.showFov = v end)
stepper(PgCombat, "Aim FOV", S.aimFov, 30, 600, 10, function(v)
	S.aimFov = v
	fovCircle.Size = UDim2.new(0, v * 2, 0, v * 2)
end)
stepper(PgCombat, "Smoothness", S.aimSmooth, 1, 30, 1, function(v) S.aimSmooth = v end)
stepper(PgCombat, "Max Distance", S.aimDist, 50, 2000, 50, function(v) S.aimDist = v end)
stepper(PgCombat, "Prediction (moving targets)", S.aimPred, 0, 30, 1, function(v) S.aimPred = v end)
local partBtn
partBtn = button(PgCombat, "Aim Part: Head", function()
	S.aimPart = S.aimPart == "Head" and "HumanoidRootPart" or "Head"
	partBtn.Text = "Aim Part: " .. (S.aimPart == "Head" and "Head" or "Body")
end, 34)
toggle(PgCombat, "Team Check", false, function(v) S.teamCheck = v end)
toggle(PgCombat, "Wall Check", true, function(v) S.wallCheck = v end)

section(PgCombat, "Triggerbot")
toggle(PgCombat, "Triggerbot  (auto click on enemy)", false, function(v)
	S.trigger = v
	if v and typeof(mouse1click) ~= "function" then notify("Your executor has no mouse1click") end
end)

section(PgCombat, "Hitbox")
toggle(PgCombat, "Hitbox Expander", false, function(v)
	S.hitbox = v
	if not v then restoreHitboxes() end
end)
stepper(PgCombat, "Hitbox Size", S.hitboxSize, 2, 30, 1, function(v) S.hitboxSize = v end)

-- =============================================
-- PAGE: MOVEMENT
-- =============================================
local hum0 = getHum()
local defWalk = hum0 and hum0.WalkSpeed or 16
local defJump = hum0 and hum0.JumpPower or 50
S.walk, S.jump = defWalk, defJump

section(PgMove, "Flight & collision")
flyToggle = toggle(PgMove, "Fly  (WASD / Space / Shift,  E boost,  R roll)", false, function(v)
	S.fly = v
	if v then
		if S.mode then setMode(S.mode) end
		startFly()
	else
		stopFly()
	end
end)
stepper(PgMove, "Fly Speed", S.flySpeed, 10, 400, 10, function(v) S.flySpeed = v end)
local styleBtn
styleBtn = button(PgMove, "Fly Style: Hero", function()
	local order = {"Hero", "Superman", "Jet"}
	local i = table.find(order, S.flyStyle) or 1
	S.flyStyle = order[i % #order + 1]
	styleBtn.Text = "Fly Style: " .. S.flyStyle
end, 32)
toggle(PgMove, "Rainbow Fly Trail", false, function(v) S.rainbow = v end)
T.noclip = toggle(PgMove, "Noclip", false, function(v) S.noclip = v end)

section(PgMove, "Speed & jumping")
local walkStep = stepper(PgMove, "WalkSpeed", defWalk, 0, 300, 4, function(v) S.walk = v S.walkCustom = true end)
local jumpStep = stepper(PgMove, "JumpPower", defJump, 0, 500, 10, function(v) S.jump = v S.jumpCustom = true end)
T.infJump = toggle(PgMove, "Infinite Jump", false, function(v) S.infJump = v end)
toggle(PgMove, "Bunny Hop  (hold Space)", false, function(v) S.bhop = v end)
toggle(PgMove, "Dash  (press Q)", false, function(v) S.dash = v end)
toggle(PgMove, "Anti-Void  (saves you from falling)", false, function(v) S.antivoid = v end)
stepper(PgMove, "Gravity", math.floor(origGravity), 0, 400, 10, function(v) workspace.Gravity = v end)

section(PgMove, "Fun")
T.spin = toggle(PgMove, "Spin", false, function(v) S.spin = v end)
stepper(PgMove, "Spin Speed", S.spinSpeed, 90, 1800, 90, function(v) S.spinSpeed = v end)

section(PgMove, "Teleport")
toggle(PgMove, "Click TP  (Ctrl + Click)", false, function(v) S.clickTP = v end)
local mvGrid = grid(PgMove)
button(mvGrid, "Save Position", function()
	local hrp = getHRP()
	if hrp then S.savedPos = hrp.CFrame notify("Position saved") end
end)
button(mvGrid, "Go To Saved", function()
	local hrp = getHRP()
	if hrp and S.savedPos then hrp.CFrame = S.savedPos else notify("No saved position") end
end)
button(mvGrid, "Reset Speed/Jump", function()
	S.walkCustom, S.jumpCustom = false, false
	walkStep.set(defWalk, true)
	jumpStep.set(defJump, true)
	local h = getHum()
	if h then h.WalkSpeed = defWalk h.JumpPower = defJump end
end)
button(mvGrid, "Reset Character", function()
	local h = getHum()
	if h then h.Health = 0 end
end)

-- =============================================
-- PAGE: PLAYERS
-- =============================================
section(PgPlayers, "Select a player")
local search = new("TextBox", {
	Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = Theme.Item, PlaceholderText = "Search player...",
	PlaceholderColor3 = Theme.Sub, Text = "", ClearTextOnFocus = false, Font = Enum.Font.GothamMedium,
	TextSize = 13, TextColor3 = Theme.Text,
}, PgPlayers)
corner(search, 8)
new("UIPadding", {PaddingLeft = UDim.new(0, 10)}, search)
stroke(search, Theme.Off, 1, 0.5)

local list = new("ScrollingFrame", {
	Size = UDim2.new(1, 0, 0, 120), BackgroundColor3 = Theme.Item, BorderSizePixel = 0,
	ScrollBarThickness = 3, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
}, PgPlayers)
corner(list, 8)
stroke(list, Theme.Off, 1, 0.5)
new("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.Name}, list)
new("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 4)}, list)

local targetLbl = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Text = "Target: none",
	Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Left,
}, PgPlayers)
onAccent(function(c) targetLbl.TextColor3 = c end)

local refreshPlayers
local function selectTarget(plr)
	S.target = plr
	targetLbl.Text = plr and ("Target: " .. plr.DisplayName .. "  (@" .. plr.Name .. ")") or "Target: none"
	if S.spec and plr then
		local c = plr.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if h then cam().CameraSubject = h end
	end
	refreshPlayers()
end

refreshPlayers = function()
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end
	local q = search.Text:lower()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LP and (q == "" or plr.Name:lower():find(q, 1, true) or plr.DisplayName:lower():find(q, 1, true)) then
			local sel = S.target == plr
			local b = new("TextButton", {
				Name = plr.Name, Size = UDim2.new(1, 0, 0, 26),
				BackgroundColor3 = sel and Theme.Accent:Lerp(Theme.Item, 0.7) or Theme.Panel,
				Text = plr.DisplayName .. "   @" .. plr.Name, Font = Enum.Font.Gotham, TextSize = 12,
				TextColor3 = sel and Theme.Accent or Theme.Text, AutoButtonColor = false,
			}, list)
			corner(b, 6)
			b.MouseButton1Click:Connect(function() selectTarget(plr) end)
		end
	end
end
onAccent(function() if refreshPlayers then refreshPlayers() end end)
bind(search:GetPropertyChangedSignal("Text"), function() refreshPlayers() end)

local function needTarget()
	if not S.target then notify("Select a player first") end
	return S.target
end

section(PgPlayers, "Actions")
local plGrid = grid(PgPlayers)
button(plGrid, "Teleport To", function()
	local p = needTarget()
	local root = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	local hrp = getHRP()
	if root and hrp then hrp.CFrame = root.CFrame * CFrame.new(0, 1, 4) end
end)
modeBtns.sit = button(plGrid, "Sit On Head", function() setMode("sit") end)
modeBtns.piggy = button(plGrid, "Piggyback", function() setMode("piggy") end)
modeBtns.follow = button(plGrid, "Follow", function() setMode("follow") end)
modeBtns.orbit = button(plGrid, "Orbit", function() setMode("orbit") end)
modeBtns.behind = button(plGrid, "Stick Behind", function() setMode("behind") end)
modeBtns.face = button(plGrid, "Face Player", function() setMode("face") end)
local specBtn
specBtn = button(plGrid, "Spectate", function()
	local on = not S.spec
	if setSpectate(on) then setActive(specBtn, on) end
end)
button(plGrid, "Random Target", function()
	local all = {}
	for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then table.insert(all, p) end end
	if #all == 0 then notify("No other players") return end
	selectTarget(all[math.random(1, #all)])
end)
button(plGrid, "Copy Name", function()
	local p = needTarget()
	if p then
		if typeof(setclipboard) == "function" then setclipboard(p.Name) notify("Copied " .. p.Name)
		else notify("Clipboard not supported") end
	end
end)
button(plGrid, "Stop All", function()
	if S.mode then setMode(S.mode) end
	if S.spec then setSpectate(false) setActive(specBtn, false) end
end)

section(PgPlayers, "Tuning")
stepper(PgPlayers, "Head Height", S.headOffset, 0, 8, 0.2, function(v) S.headOffset = v end, function(v) return string.format("%.1f", v) end)
stepper(PgPlayers, "Follow Distance", S.dist, 1, 30, 1, function(v) S.dist = v end)
stepper(PgPlayers, "Orbit Radius", S.orbitRadius, 2, 50, 1, function(v) S.orbitRadius = v end)
stepper(PgPlayers, "Orbit Speed", S.orbitSpeed, 1, 20, 1, function(v) S.orbitSpeed = v end)

-- =============================================
-- PAGE: VISUAL
-- =============================================
section(PgVisual, "ESP")
T.esp = toggle(PgVisual, "Player ESP", false, setESP)
toggle(PgVisual, "Show Health", true, function(v) S.espHealth = v end)
toggle(PgVisual, "Show Distance", true, function(v) S.espDist = v end)

section(PgVisual, "Camera")
stepper(PgVisual, "Field of View", 70, 30, 120, 5, function(v) S.fov = v S.fovCustom = true end)
stepper(PgVisual, "Max Zoom", math.floor(LP.CameraMaxZoomDistance), 10, 2000, 50, function(v) LP.CameraMaxZoomDistance = v end)

section(PgVisual, "HUD")
local cross = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 14, 0, 14),
	BackgroundTransparency = 1, Visible = false,
}, ScreenGui)
local chH = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 2), BorderSizePixel = 0, BackgroundColor3 = Theme.Accent}, cross)
local chV = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 2, 1, 0), BorderSizePixel = 0, BackgroundColor3 = Theme.Accent}, cross)
onAccent(function(c) chH.BackgroundColor3 = c chV.BackgroundColor3 = c end)
T.cross = toggle(PgVisual, "Crosshair", false, function(v) cross.Visible = v end)

do -- FPS / ping counter
	local Stats = game:GetService("Stats")
	local hud = new("TextLabel", {
		Position = UDim2.new(0, 10, 0, 10), Size = UDim2.new(0, 150, 0, 24), BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.2, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Accent,
		Text = "", Visible = false,
	}, ScreenGui)
	corner(hud, 6)
	onAccent(function(c) hud.TextColor3 = c end)
	local frames, acc = 0, 0
	bind(RunService.RenderStepped, function(dt)
		if not hud.Visible then return end
		frames += 1
		acc += dt
		if acc >= 0.5 then
			local ping = 0
			pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
			hud.Text = math.floor(frames / acc) .. " FPS  •  " .. ping .. " ms"
			frames, acc = 0, 0
		end
	end)
	T.hud = toggle(PgVisual, "FPS / Ping Counter", false, function(v) hud.Visible = v end)
end

-- =============================================
-- PAGE: WORLD
-- =============================================
section(PgWorld, "Lighting")
T.fullbright = toggle(PgWorld, "Fullbright", false, setFullbright)
toggle(PgWorld, "No Fog", false, function(v)
	S.nofog = v
	if v then saveLight() Lighting.FogEnd = 1e6 elseif lightSaved and not S.fullbright then Lighting.FogEnd = lightSaved.FogEnd end
end)
stepper(PgWorld, "Time of Day", math.floor(Lighting.ClockTime), 0, 24, 1, function(v) saveLight() Lighting.ClockTime = v end)

section(PgWorld, "Performance")
local wGrid = grid(PgWorld)
button(wGrid, "FPS Boost", function()
	pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
	Lighting.GlobalShadows = false
	for _, o in ipairs(workspace:GetDescendants()) do
		if o:IsA("BasePart") then o.Material = Enum.Material.Plastic o.CastShadow = false
		elseif o:IsA("ParticleEmitter") or o:IsA("Trail") then o.Enabled = false end
	end
	notify("FPS boost applied")
end)
button(wGrid, "Remove Effects", function()
	for _, o in ipairs(Lighting:GetChildren()) do
		if o:IsA("PostEffect") or o:IsA("Atmosphere") or o:IsA("BlurEffect") then o:Destroy() end
	end
	notify("Effects removed")
end)

-- =============================================
-- PAGE: SETTINGS
-- =============================================
if PgOwner then
	section(PgOwner, "Owner powers")
	local info = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = Theme.Item, TextWrapped = true,
		Text = "You are the riggnes owner. Owner tab unlocked.",
		Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = OWNER_GOLD,
	}, PgOwner)
	corner(info, 8)
	stroke(info, OWNER_GOLD, 1.5, 0.3)
	new("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}, info)

	T.setAura = function(on)
		if T.aura then T.aura:Destroy() T.aura = nil end
		local hrp = getHRP()
		if on and hrp then
			T.aura = new("ParticleEmitter", {
				Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 45, Lifetime = NumberRange.new(0.8, 1.4),
				Speed = NumberRange.new(2, 6), SpreadAngle = Vector2.new(180, 180), LightEmission = 1,
				Color = ColorSequence.new(OWNER_GOLD),
				Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0)}),
				Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)}),
			}, hrp)
		end
	end
	toggle(PgOwner, "Gold Aura", false, function(v) S.aura = v T.setAura(v) end)
	toggle(PgOwner, "Golden Fly Trail", false, function(v) S.goldFly = v end)
	stepper(PgOwner, "Owner Fly Speed", S.flySpeed, 10, 1500, 50, function(v) S.flySpeed = v end)
	stepper(PgOwner, "Boost Power", S.boostMult, 1.5, 12, 0.5, function(v) S.boostMult = v end, function(v) return string.format("%.1fx", v) end)
end

section(PgSettings, "Interface")
local scaleStep
scaleStep = stepper(PgSettings, "UI Scale", math.floor(S.uiScale * 100 + 0.5), 60, 160, 5, function(v)
	S.uiScale = v / 100
	cfg.uiScale = v
	saveCfg()
	tween(uiScale, 0.15, {Scale = S.uiScale})
end, function(v) return v .. "%" end)
button(PgSettings, "Reset UI Scale", function()
	scaleStep.set(100)
end, 30)

section(PgSettings, "Accent color")
local colorNameLbl
local swatchRow = new("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Theme.Item}, PgSettings)
corner(swatchRow, 8)
stroke(swatchRow, Theme.Off, 1, 0.5)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), VerticalAlignment = Enum.VerticalAlignment.Center, HorizontalAlignment = Enum.HorizontalAlignment.Center}, swatchRow)
colorNameLbl = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Text = "Cyan",
	Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Left,
}, PgSettings)
onAccent(function(c) colorNameLbl.TextColor3 = c end)
for _, e in ipairs({
	{"Cyan", Color3.fromRGB(0, 229, 255)}, {"Mint", Color3.fromRGB(0, 255, 140)}, {"Violet", Color3.fromRGB(170, 100, 255)},
	{"Pink", Color3.fromRGB(255, 80, 170)}, {"Orange", Color3.fromRGB(255, 150, 40)}, {"Red", Color3.fromRGB(255, 70, 70)},
	{"Gold", Color3.fromRGB(255, 210, 60)}, {"Lime", Color3.fromRGB(170, 255, 60)},
}) do
	local s = new("TextButton", {Size = UDim2.new(0, 24, 0, 24), BackgroundColor3 = e[2], Text = "", AutoButtonColor = false}, swatchRow)
	corner(s, 12)
	s.MouseEnter:Connect(function() tween(s, 0.12, {Size = UDim2.new(0, 28, 0, 28)}) end)
	s.MouseLeave:Connect(function() tween(s, 0.12, {Size = UDim2.new(0, 24, 0, 24)}) end)
	s.MouseButton1Click:Connect(function()
		setAccent(e[2])
		colorNameLbl.Text = e[1]
		cfg.accent = {math.floor(e[2].R * 255 + 0.5), math.floor(e[2].G * 255 + 0.5), math.floor(e[2].B * 255 + 0.5)}
		cfg.accentName = e[1]
		saveCfg()
	end)
end

local function getExecutor()
	local function g(name)
		local v
		pcall(function() v = getgenv and getgenv()[name] end)
		if v == nil then pcall(function() v = getfenv(0)[name] end) end
		if v == nil then pcall(function() v = _G[name] end) end
		return v
	end
	for _, fname in ipairs({"identifyexecutor", "getexecutorname", "whatexecutor"}) do
		local fn = g(fname)
		if type(fn) == "function" then
			local ok, name, ver = pcall(fn)
			if ok and name and tostring(name) ~= "" then
				return tostring(name), ver and tostring(ver) or nil
			end
		end
	end
	local known = {
		{"Xeno", "Xeno"}, {"Solara", "Solara"}, {"Wave", "Wave"}, {"Velocity", "Velocity"},
		{"Delta", "Delta"}, {"Fluxus", "Fluxus"}, {"fluxus", "Fluxus"}, {"syn", "Synapse X"},
		{"KRNL_LOADED", "KRNL"}, {"is_sirhurt_closure", "SirHurt"}, {"PROTOSMASHER_LOADED", "ProtoSmasher"},
		{"SENTINEL_V2", "Sentinel"}, {"Seliware", "Seliware"}, {"Potassium", "Potassium"},
		{"Swift", "Swift"}, {"Volcano", "Volcano"}, {"Bunni", "Bunni"},
	}
	for _, k in ipairs(known) do
		if g(k[1]) ~= nil then return k[2], nil end
	end
	return "Unknown", nil
end
local execName, execVer = getExecutor()
local execText = execVer and (execName .. " " .. execVer) or execName
T.execProf.Text = "Exec: " .. execText

section(PgSettings, "Executor")
local execRow = new("Frame", {Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Theme.Item}, PgSettings)
corner(execRow, 8)
stroke(execRow, Theme.Off, 1, 0.5)
new("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(0, 90, 1, 0),
	Text = "Running on", Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text,
	TextXAlignment = Enum.TextXAlignment.Left,
}, execRow)
local execLbl = new("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.new(0, 105, 0, 0), Size = UDim2.new(1, -117, 1, 0),
	Text = execText, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.Accent,
	TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
}, execRow)
onAccent(function(c) execLbl.TextColor3 = c end)

section(PgSettings, "Keybinds  (menu toggle is permanently RightControl)")
new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1,
	Text = "Menu Toggle: RIGHT CONTROL  •  Always ON  •  Cannot be disabled or rebound",
	Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Theme.Accent,
	TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
}, PgSettings)
if typeof(writefile) ~= "function" then
	new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, TextWrapped = true,
		Text = "Your executor has no writefile, so settings can't be saved between sessions.",
		Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Theme.Sub, TextXAlignment = Enum.TextXAlignment.Left,
	}, PgSettings)
end
do
	local function flip(t) return function() t.set(not t.get()) end end
	local binds = {
		{name = "Toggle Menu", key = Enum.KeyCode.RightControl, fn = function() toggleUI() end},
		{name = "Fly", key = Enum.KeyCode.F, fn = function() flyToggle.set(not flyToggle.get()) end},
		{name = "Noclip", key = Enum.KeyCode.N, fn = flip(T.noclip)},
		{name = "Aimbot", key = Enum.KeyCode.V, fn = flip(T.aim)},
		{name = "Player ESP", key = Enum.KeyCode.B, fn = flip(T.esp)},
		{name = "Fullbright", key = Enum.KeyCode.L, fn = flip(T.fullbright)},
		{name = "Infinite Jump", key = Enum.KeyCode.J, fn = flip(T.infJump)},
		{name = "Spin", key = Enum.KeyCode.K, fn = flip(T.spin)},
		{name = "Fly Barrel Roll", key = Enum.KeyCode.R, fn = function()
			if S.fly and not S.rollStart then
				S.rollStart = tick()
				local hrp = getHRP()
				if hrp then shockwave(hrp.Position, cam().CFrame.LookVector) end
				pcall(function() playSweep(SoundBank.open, 1.0, 2.4, 0.3, 0.7) end)
			end
		end},
		{name = "Crosshair", key = Enum.KeyCode.C, fn = flip(T.cross)},
		{name = "FPS Counter", key = Enum.KeyCode.P, fn = flip(T.hud)},
		{name = "Save Position", key = Enum.KeyCode.Z, fn = function()
			local hrp = getHRP()
			if hrp then S.savedPos = hrp.CFrame notify("Position saved") end
		end},
		{name = "Go To Saved", key = Enum.KeyCode.X, fn = function()
			local hrp = getHRP()
			if hrp and S.savedPos then hrp.CFrame = S.savedPos else notify("No saved position") end
		end},
		{name = "Stop Target Modes", key = Enum.KeyCode.H, fn = function()
			if S.mode then setMode(S.mode) end
			if S.spec then setSpectate(false) setActive(specBtn, false) end
		end},
	}
	local function persist()
		cfg.keys, cfg.off = {}, {}
		for _, b in ipairs(binds) do
			cfg.keys[b.name] = b.key and b.key.Name or false
			if not b.enabled then cfg.off[b.name] = true end
		end
		cfg.kbOn = true
		saveCfg()
	end
	T.persistKeys = persist
	local listening
	for _, b in ipairs(binds) do
		b.default = b.key
		if b.name ~= "Toggle Menu" then
			local sk = type(cfg.keys) == "table" and cfg.keys[b.name]
			if sk == false then
				b.key = nil
			elseif type(sk) == "string" then
				local ok, kc = pcall(function() return Enum.KeyCode[sk] end)
				if ok and kc then b.key = kc end
			end
			b.enabled = not (type(cfg.off) == "table" and cfg.off[b.name])
		else
			-- Ignore saved settings: the menu key is locked to RightControl.
			b.key = Enum.KeyCode.RightControl
			b.enabled = true
		end
		local row = new("Frame", {Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Theme.Item}, PgSettings)
		corner(row, 8)
		stroke(row, Theme.Off, 1, 0.5)
		new("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -175, 1, 0),
			Text = b.name, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
		}, row)
		b.btn = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0, 100, 0, 24),
			BackgroundColor3 = Theme.Off, Text = b.key and b.key.Name or "None", Font = Enum.Font.GothamBold,
			TextSize = 12, TextColor3 = Theme.Accent, AutoButtonColor = false,
		}, row)
		corner(b.btn, 6)
		onAccent(function(c) b.btn.TextColor3 = c end)
		-- per-keybind on/off switch
		b.onBtn = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -114, 0.5, 0), Size = UDim2.new(0, 44, 0, 24),
			BackgroundColor3 = Theme.Off, Text = b.enabled and "ON" or "OFF", Font = Enum.Font.GothamBold,
			TextSize = 11, TextColor3 = b.enabled and Theme.Accent or Theme.Sub, AutoButtonColor = false,
		}, row)
		corner(b.onBtn, 6)
		onAccent(function(c) if b.enabled then b.onBtn.TextColor3 = c end end)
		b.onBtn.MouseButton1Click:Connect(function()
			if b.name == "Toggle Menu" then
				b.enabled = true
				b.onBtn.Text = "ON"
				b.onBtn.TextColor3 = Theme.Accent
				notify("Menu key is locked ON")
				return
			end
			b.enabled = not b.enabled
			b.onBtn.Text = b.enabled and "ON" or "OFF"
			b.onBtn.TextColor3 = b.enabled and Theme.Accent or Theme.Sub
			playUI(b.enabled and 1.5 or 0.85, 0.5)
			persist()
		end)
		b.btn.MouseButton1Click:Connect(function()
			if b.name == "Toggle Menu" then
				notify("Menu key is locked to RightControl")
				return
			end
			if listening then return end
			listening = b
			b.btn.Text = "press a key..."
			playUI(1.3, 0.5)
		end)
	end
	local resetBtn = button(PgSettings, "Reset Keybinds", function()
		for _, b in ipairs(binds) do
			b.key = b.default
			b.btn.Text = b.key and b.key.Name or "None"
			b.enabled = true
			b.onBtn.Text = "ON"
			b.onBtn.TextColor3 = Theme.Accent
		end
		persist()
		notify("Keybinds reset")
	end, 32)
	bind(UIS.InputBegan, function(i, gp)
		if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if listening then
			local b = listening
			listening = nil
			b.key = (i.KeyCode ~= Enum.KeyCode.Escape) and i.KeyCode or nil
			b.btn.Text = b.key and b.key.Name or "None"
			playUI(1.6, 0.5)
			persist()
			return
		end
		if gp then return end
		for _, b in ipairs(binds) do
			if b.key and b.key == i.KeyCode and b.enabled and (S.keybindsOn or b.name == "Toggle Menu") then
				pcall(b.fn)
				playUI(1.4, 0.4)
			end
		end
	end)
end

section(PgSettings, "Scripts")
local scGrid = grid(PgSettings)
local function runRemote(name, url)
	notify("Loading " .. name .. "...")
	local ok, err = pcall(function() loadstring(game:HttpGet(url))() end)
	if not ok then notify(name .. " failed to load") warn(err) end
end
button(scGrid, "Run M7 Admin", function()
	runRemote("M7 Admin", "https://rawscripts.net/raw/Universal-Script-M7-ADMIN-202724")
end)
button(scGrid, "Run Novoline", function()
	runRemote("Novoline", "https://novoline.pro")
end)

section(PgSettings, "Utility")
local VirtualUser = game:GetService("VirtualUser")
bind(LP.Idled, function()
	if S.afk then
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end
end)
toggle(PgSettings, "Anti-AFK", false, function(v) S.afk = v end)
local stGrid = grid(PgSettings)
button(stGrid, "Rejoin Server", function() TeleportService:Teleport(game.PlaceId, LP) end)
button(stGrid, "Server Hop", function()
	notify("Finding a server...")
	local ok, res = pcall(function()
		return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
	end)
	if ok and res and res.data then
		for _, s in ipairs(res.data) do
			if s.id ~= game.JobId and s.playing < s.maxPlayers then
				TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LP)
				return
			end
		end
	end
	notify("No other server found")
end)
local destroyAll
button(stGrid, "Destroy riggnes", function() destroyAll() end)

-- =============================================
-- PLAYER TRACKING
-- =============================================
local function hookPlayer(plr)
	bind(plr.CharacterAdded, function()
		task.wait(0.4)
		applyESP(plr)
		refreshTag(plr)
	end)
end
for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
bind(Players.PlayerAdded, function(p) hookPlayer(p) refreshPlayers() end)
bind(Players.PlayerRemoving, function(p)
	clearESP(p)
	clearTag(p)
	S.tagged[p] = nil
	if S.target == p then
		if S.mode then setMode(S.mode) end
		if S.spec then setSpectate(false) setActive(specBtn, false) end
		selectTarget(nil)
		notify(p.DisplayName .. " left")
	else
		refreshPlayers()
	end
end)
refreshPlayers()

-- =============================================
-- INPUT
-- =============================================
bind(UIS.JumpRequest, function()
	if S.infJump then
		local h = getHum()
		if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end)

bind(UIS.InputBegan, function(i, gp)
	if gp then return end
	if i.KeyCode == Enum.KeyCode.Q and S.dash and tick() - S.lastDash > 0.5 then
		local hrp = getHRP()
		if hrp then
			S.lastDash = tick()
			local l = cam().CFrame.LookVector
			local flat = Vector3.new(l.X, 0, l.Z)
			if flat.Magnitude > 0 then
				hrp.AssemblyLinearVelocity = flat.Unit * 110 + Vector3.new(0, 15, 0)
			end
		end
	end
	if i.UserInputType == Enum.UserInputType.MouseButton1 and S.clickTP and UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
		local hrp = getHRP()
		if hrp then hrp.CFrame = CFrame.new(Mouse.Hit.Position + Vector3.new(0, 3, 0)) end
	end
end)

-- =============================================
-- MAIN LOOPS
-- =============================================
local orb, face, orbStroke
local t0, espTick = 0, 0
bind(RunService.Heartbeat, function(dt)
	t0 += dt
	topGrad.Offset = Vector2.new(math.sin(t0 * 1.2) * 0.5, 0)
	if orbStroke then orbStroke.Thickness = 2.5 + math.sin(t0 * 3) * 1 end
	if face then face.Rotation = (t0 * 120) % 360 end

	local hum, hrp = getHum(), getHRP()
	local typing = UIS:GetFocusedTextBox() ~= nil

	if hum and hrp then
		local voidY = workspace.FallenPartsDestroyHeight + 80
		if hum.FloorMaterial ~= Enum.Material.Air and hrp.Position.Y > voidY + 50 then S.lastSafe = hrp.CFrame end
		if S.antivoid and S.lastSafe and hrp.Position.Y < voidY then
			hrp.AssemblyLinearVelocity = Vector3.new()
			hrp.CFrame = S.lastSafe + Vector3.new(0, 3, 0)
			notify("Anti-Void saved you")
		end
	end

	if S.esp then
		espTick += dt
		if espTick > 0.2 then espTick = 0 updateESPText() end
	end
	if S.hitbox then applyHitboxes() end

	-- triggerbot
	if S.trigger and typeof(mouse1click) == "function" and tick() - S.lastTrig > 0.12 then
		local tgt = Mouse.Target
		local model = tgt and tgt:FindFirstAncestorOfClass("Model")
		local plr = model and Players:GetPlayerFromCharacter(model)
		if plr and plr ~= LP and not (S.teamCheck and LP.Team and plr.Team == LP.Team) then
			local h = model:FindFirstChildOfClass("Humanoid")
			if h and h.Health > 0 then
				S.lastTrig = tick()
				mouse1click()
			end
		end
	end

	if hum then
		if S.walkCustom and hum.WalkSpeed ~= S.walk then hum.WalkSpeed = S.walk end
		if S.jumpCustom then
			if hum.UseJumpPower == false then hum.UseJumpPower = true end
			if hum.JumpPower ~= S.jump then hum.JumpPower = S.jump end
		end
		if S.bhop and not typing and UIS:IsKeyDown(Enum.KeyCode.Space) and hum.FloorMaterial ~= Enum.Material.Air then
			hum.Jump = true
		end
	end
	if not S.fly then S.flyFovAdd += (0 - S.flyFovAdd) * math.min(1, dt * 6) end
	if S.fly or S.flyFovAdd > 0.05 then
		cam().FieldOfView = (S.fovCustom and S.fov or (S.flyBaseFov or 70)) + S.flyFovAdd
	elseif S.fovCustom then
		cam().FieldOfView = S.fov
	end

	-- fly
	if S.fly and hrp and bv and bv.Parent then
		local c = cam()
		local move = Vector3.new()
		if not typing then
			if UIS:IsKeyDown(Enum.KeyCode.W) then move += c.CFrame.LookVector end
			if UIS:IsKeyDown(Enum.KeyCode.S) then move -= c.CFrame.LookVector end
			if UIS:IsKeyDown(Enum.KeyCode.A) then move -= c.CFrame.RightVector end
			if UIS:IsKeyDown(Enum.KeyCode.D) then move += c.CFrame.RightVector end
			if UIS:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0, 1, 0) end
			if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then move -= Vector3.new(0, 1, 0) end
		end
		local boosting = (not typing) and UIS:IsKeyDown(Enum.KeyCode.E)
		if boosting and move.Magnitude == 0 then move = c.CFrame.LookVector end
		if boosting and not S.wasBoost then
			shockwave(hrp.Position, c.CFrame.LookVector)
			pcall(function() playSweep(SoundBank.open, 0.4, 2.2, 0.5, 1.0) end)
			notify("BOOST")
		end
		S.wasBoost = boosting
		local moving = move.Magnitude > 0
		local target = moving and move.Unit * S.flySpeed * (boosting and S.boostMult or 1) or Vector3.new()
		if not moving then target += Vector3.new(0, math.sin(t0 * 2.5) * 2.5, 0) end -- idle hover bob
		bv.Velocity = bv.Velocity:Lerp(target, math.min(1, dt * 7)) -- smooth acceleration
		local vel = bv.Velocity
		local speedFrac = math.clamp(vel.Magnitude / math.max(S.flySpeed, 1), 0, 1.8)

		local look = c.CFrame.LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		if flatLook.Magnitude > 0.01 then S.flyYaw = math.atan2(-look.X, -look.Z) end
		local fwdAmt = math.clamp(vel:Dot(look) / math.max(S.flySpeed, 1), 0, 1)
		local side = math.clamp(vel:Dot(c.CFrame.RightVector) / math.max(S.flySpeed, 1), -1, 1)
		local camPitch = math.asin(math.clamp(look.Y, -1, 1))
		local tPitch = (-math.rad(75) + camPitch) * fwdAmt          -- superman dive pose
		local tRoll = side * math.rad(50)  -- bank into turns (positive = right)
		local k = math.min(1, dt * 8)
		S.flyPitch += (tPitch - S.flyPitch) * k
		S.flyRoll += (tRoll - S.flyRoll) * k
		local rollAng = 0
		if S.rollStart then
			local u = (tick() - S.rollStart) / 0.7
			if u >= 1 then
				S.rollStart = nil
			else
				local e = u < 0.5 and 2 * u * u or 1 - ((-2 * u + 2) ^ 2) / 2  -- ease in/out
				rollAng = e * math.pi * 2
			end
		end
		if bg and bg.Parent then
			local p = fwdAmt
			bg.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, S.flyYaw, 0)
				* CFrame.Angles(0, 0, -S.flyRoll * (1 - p))
				* CFrame.Angles(S.flyPitch, 0, 0)
				* CFrame.Angles(0, S.flyRoll * p + rollAng, 0)
		end

		-- hero pose: fist forward, other arm swept back, legs together with pointed toes
		local js = T.joints
		if js then
			local f = fwdAmt
			local ph = t0 * 3
			local fl = 0.03 + speedFrac * 0.03   -- tiny cloth-like flutter, no leg swinging
			local lk = math.min(1, dt * 10)
			local function pose(name, rot)
				local d = js[name]
				if d and d.motor and d.motor.Parent then d.motor.C0 = d.motor.C0:Lerp(d.c0 * rot, lk) end
			end
			pose("LeftHip", CFrame.Angles(-0.1 * f + math.sin(ph) * fl, 0, 0.02))
			pose("RightHip", CFrame.Angles(-0.1 * f + math.sin(ph + 1.2) * fl, 0, -0.02))
			pose("LeftKnee", CFrame.Angles(-0.1 * f, 0, 0))
			pose("RightKnee", CFrame.Angles(-0.1 * f, 0, 0))
			pose("LeftAnkle", CFrame.Angles(-0.7 * f, 0, 0))
			pose("RightAnkle", CFrame.Angles(-0.7 * f, 0, 0))
			local rArm, lArm = 3.0, -0.15              -- Hero: one fist forward
			if S.flyStyle == "Superman" then rArm, lArm = 3.0, 3.0    -- both arms forward
			elseif S.flyStyle == "Jet" then rArm, lArm = -0.1, -0.1 end -- arms tight at the sides
			pose("RightShoulder", CFrame.Angles(rArm * f + math.sin(ph) * 0.03, 0, -0.3 * (1 - f)))
			pose("LeftShoulder", CFrame.Angles(lArm * f, 0, 0.1 * f + 0.3 * (1 - f)))
			pose("Neck", CFrame.Angles(0.75 * f, 0, 0))
		end

		local fx = T.fx
		if fx then
			fx.trail.Enabled = speedFrac > 0.2
			for _, key in ipairs({"wt_1", "wt_2"}) do if fx[key] then fx[key].Enabled = speedFrac > 0.55 end end
			fx.trail.Lifetime = 0.15 + speedFrac * 0.5
			fx.em.Rate = speedFrac * 70
			if S.rainbow or S.goldFly then
				local col = S.goldFly and OWNER_GOLD or Color3.fromHSV((t0 * 0.4) % 1, 0.8, 1)
				local cs = ColorSequence.new(col)
				fx.trail.Color = cs
				fx.em.Color = cs
				for _, key in ipairs({"wt_1", "wt_2"}) do if fx[key] then fx[key].Color = ColorSequence.new(Color3.new(1, 1, 1), col) end end
			end
		end
		S.flyFovAdd += (speedFrac * 22 - S.flyFovAdd) * math.min(1, dt * 5)  -- speed FOV kick
	end

	-- spin
	if S.spin and not S.mode and hrp then
		hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(S.spinSpeed * dt), 0)
	end

	-- spectate keep-alive
	if S.spec and S.target then
		local tc = S.target.Character
		local th = tc and tc:FindFirstChildOfClass("Humanoid")
		if th and cam().CameraSubject ~= th then cam().CameraSubject = th end
	end

	-- target modes
	local mode = S.mode
	if mode and hrp then
		local tc = S.target and S.target.Character
		local tRoot = tc and tc:FindFirstChild("HumanoidRootPart")
		if not tRoot then return end

		if mode == "sit" then
			local head = tc:FindFirstChild("Head") or tRoot
			hrp.CFrame = head.CFrame * CFrame.new(0, S.headOffset, 0)
			hrp.AssemblyLinearVelocity = Vector3.new()
			hrp.AssemblyAngularVelocity = Vector3.new()
			if hum and not hum.Sit then hum.Sit = true end
		elseif mode == "piggy" then
			hrp.CFrame = tRoot.CFrame * CFrame.new(0, 1.3, 0.9)
			hrp.AssemblyLinearVelocity = Vector3.new()
			hrp.AssemblyAngularVelocity = Vector3.new()
		elseif mode == "follow" then
			local goal = tRoot.CFrame * CFrame.new(0, 0, S.dist)
			hrp.CFrame = hrp.CFrame:Lerp(goal, math.min(1, dt * 10))
			hrp.AssemblyLinearVelocity = Vector3.new()
		elseif mode == "behind" then
			hrp.CFrame = tRoot.CFrame * CFrame.new(0, 0, S.dist)
			hrp.AssemblyLinearVelocity = Vector3.new()
		elseif mode == "orbit" then
			S.orbitAngle += S.orbitSpeed * dt
			local pos = tRoot.Position + Vector3.new(math.cos(S.orbitAngle) * S.orbitRadius, 0, math.sin(S.orbitAngle) * S.orbitRadius)
			hrp.CFrame = CFrame.lookAt(pos, Vector3.new(tRoot.Position.X, pos.Y, tRoot.Position.Z))
			hrp.AssemblyLinearVelocity = Vector3.new()
		elseif mode == "face" then
			local p = hrp.Position
			hrp.CFrame = CFrame.lookAt(p, Vector3.new(tRoot.Position.X, p.Y, tRoot.Position.Z))
		end
	end
end)

bind(RunService.Stepped, function()
	if S.noclip then
		local c = LP.Character
		if c then
			for _, part in ipairs(c:GetDescendants()) do
				if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
			end
		end
	end
end)

bind(LP.CharacterAdded, function()
	task.wait(0.6)
	if S.fly then startFly() end
	if S.spec then setSpectate(true) end
	if S.aura and T.setAura then T.setAura(true) end
end)

-- =============================================
-- OPEN / CLOSE + ORB
-- =============================================
local uiOpen = false
local function openUI()
	uiOpen = true
	Main.Visible = true
	Main.GroupTransparency = 1
	uiScale.Scale = 0.92 * S.uiScale
	pcall(playOpenSound)
	tween(Main, 0.25, {GroupTransparency = 0})
	tween(uiScale, 0.35, {Scale = S.uiScale}, Enum.EasingStyle.Back)
	task.delay(0.5, function()
		if uiOpen then
			Main.Visible = true
			Main.GroupTransparency = 0
			uiScale.Scale = S.uiScale
		end
	end)
end
local function closeUI()
	uiOpen = false
	pcall(playCloseSound)
	tween(Main, 0.2, {GroupTransparency = 1})
	tween(uiScale, 0.2, {Scale = 0.94 * S.uiScale})
	task.delay(0.22, function()
		if not uiOpen then Main.Visible = false end
	end)
end
toggleUI = function()
	if uiOpen then closeUI() else openUI() end
end
CloseBtn.MouseButton1Click:Connect(function() closeUI() end)

-- (menu toggle key is handled by the Keybinds system in Settings)

orb = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.0285, 0, 0.85, 0),
	Size = UDim2.new(0, 46, 0, 46),
	BackgroundColor3 = Theme.Bg, Text = "", AutoButtonColor = false,
}, ScreenGui)
corner(orb, 23)
orbStroke = stroke(orb, Theme.Accent, 2.5, 0)
onAccent(function(c) orbStroke.Color = c end)

face = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(0.74, 0, 0.74, 0), BackgroundTransparency = 1,
}, orb)

local function dot(parent, x, y, w, h, color, round)
	local f = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(x, 0, y, 0),
		Size = UDim2.new(w, 0, h, 0), BackgroundColor3 = color, BorderSizePixel = 0,
	}, parent)
	corner(f, round and 100 or 3)
	return f
end

local fur = Color3.fromRGB(28, 28, 34)
dot(face, 0.06, 0.45, 0.24, 0.24, fur, true)
dot(face, 0.94, 0.45, 0.24, 0.24, fur, true)
dot(face, 0.5, 0.5, 0.86, 0.9, fur, true)
dot(face, 0.5, 0.62, 0.62, 0.52, Color3.fromRGB(120, 92, 76), true)
dot(face, 0.5, 0.33, 0.7, 0.14, fur, false)
local eyeL = dot(face, 0.36, 0.42, 0.11, 0.11, Theme.Accent, true)
local eyeR = dot(face, 0.64, 0.42, 0.11, 0.11, Theme.Accent, true)
onAccent(function(c) eyeL.BackgroundColor3 = c eyeR.BackgroundColor3 = c end)
dot(face, 0.43, 0.6, 0.07, 0.07, fur, true)
dot(face, 0.57, 0.6, 0.07, 0.07, fur, true)
dot(face, 0.5, 0.76, 0.3, 0.05, fur, false)

local orbHit = new("TextButton", {
	Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 10, AutoButtonColor = false,
}, orb)
orbHit.MouseEnter:Connect(function() tween(orb, 0.15, {Size = UDim2.new(0, 54, 0, 54)}) end)
orbHit.MouseLeave:Connect(function() tween(orb, 0.15, {Size = UDim2.new(0, 46, 0, 46)}) end)
orbHit.MouseButton1Click:Connect(toggleUI)

-- =============================================
-- CLEANUP
-- =============================================
destroyAll = function()
	stopFly()
	S.mode = nil
	S.aim = false
	local h = getHum()
	if h then h.Sit = false h.PlatformStand = false end
	setSpectate(false)
	setESP(false)
	setFullbright(false)
	restoreHitboxes()
	pcall(function() RunService:UnbindFromRenderStep("riggnes_aim") end)
	workspace.Gravity = origGravity
	for p in pairs(tags) do clearTag(p) end
	for _, c in ipairs(conns) do c:Disconnect() end
	ScreenGui:Destroy()
end

selectTab(1)
if type(cfg.accent) == "table" and tonumber(cfg.accent[1]) and tonumber(cfg.accent[2]) and tonumber(cfg.accent[3]) then
	setAccent(Color3.fromRGB(cfg.accent[1], cfg.accent[2], cfg.accent[3]))
	if cfg.accentName and colorNameLbl then colorNameLbl.Text = cfg.accentName end
else
	setAccent(Theme.Accent)
end
for _, p in ipairs(Players:GetPlayers()) do refreshTag(p) end
if OWNER_LIST_URL ~= "" then
	task.spawn(function()
		local ok, body = pcall(function() return game:HttpGet(OWNER_LIST_URL) end)
		if ok and type(body) == "string" then
			for line in body:gmatch("[^\r\n]+") do
				local v = line:gsub("%s+", "")
				local id = tonumber(v)
				if id then ownerIdSet[id] = true elseif v ~= "" then ownerSet[string.lower(v)] = true end
			end
			for _, p in ipairs(Players:GetPlayers()) do refreshTag(p) end
		end
	end)
end
-- =============================================
-- INTRO: terminal -> black hole -> explosion -> script
-- (cannot be skipped)
-- =============================================
local INTRO_CODE = [=====[
-- riggnes v2.0
-- Intro: cmd window types the code -> black hole -> explosion -> menu (cannot be skipped)
-- Toggle UI: Right Ctrl or the floating gorilla orb (bottom-left)
-- Aimbot: enable in Combat tab, then HOLD RIGHT MOUSE BUTTON

print("[riggnes] starting...")
local __ok, __err = xpcall(function()

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local LP = Players.LocalPlayer
local Mouse = LP:GetMouse()

local PlayerGui = LP:WaitForChild("PlayerGui")
local old = PlayerGui:FindFirstChild("riggnes")
if old then old:Destroy() end
pcall(function() RunService:UnbindFromRenderStep("riggnes_aim") end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "riggnes"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 10000
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

-- =============================================
-- HELPERS
-- =============================================
local conns = {}
local function bind(signal, fn)
	local c = signal:Connect(fn)
	table.insert(conns, c)
	return c
end

local function cam() return workspace.CurrentCamera end
local function getHum()
	local c = LP.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end
local function getHRP()
	local c = LP.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local Theme = {
	Bg = Color3.fromRGB(10, 12, 28),
	Side = Color3.fromRGB(14, 17, 40),
	Panel = Color3.fromRGB(18, 22, 52),
	Item = Color3.fromRGB(24, 30, 68),
	ItemHover = Color3.fromRGB(36, 46, 100),
	Off = Color3.fromRGB(58, 72, 140),
	Text = Color3.fromRGB(255, 255, 255),
	Sub = Color3.fromRGB(150, 168, 230),
	Accent = Color3.fromRGB(0, 229, 255),
}

local accentFns = {}
local function onAccent(fn)
	table.insert(accentFns, fn)
	fn(Theme.Accent)
end
local function setAccent(c)
	Theme.Accent = c
	for _, fn in ipairs(accentFns) do fn(c) end
end

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function corner(o, r) return new("UICorner", {CornerRadius = UDim.new(0, r or 8)}, o) end
local function stroke(o, c, t, tr)
	return new("UIStroke", {Color = c, Thickness = t or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, o)
end
local function tween(o, t, p, style, dir)
	TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), p):Play()
end

-- =============================================
-- STATE
-- =============================================
-- =============================================
-- OWNER CONFIG  (edit these!)
-- Owners get a gold "RIGGNES OWNER" banner that every riggnes user sees above their head,
-- (the overhead banner has been removed) plus an extra "Owner" tab for the owner only.
-- =============================================
local OWNER_NAMES = {"PUT_YOUR_ROBLOX_USERNAME_HERE"}  -- your exact Roblox username (not display name)
local OWNER_IDS = {}                                    -- or UserIds, e.g. {123456789}
local OWNER_LIST_URL = ""                               -- optional: raw link to a text file, one username/UserId per line
local OWNER_GOLD = Color3.fromRGB(255, 200, 60)
local ownerSet, ownerIdSet = {}, {}
for _, n in ipairs(OWNER_NAMES) do ownerSet[string.lower(n)] = true end
for _, i in ipairs(OWNER_IDS) do ownerIdSet[i] = true end
local function isOwner(plr)
	return plr ~= nil and (ownerSet[string.lower(plr.Name)] == true or ownerIdSet[plr.UserId] == true)
end

local origGravity = workspace.Gravity
local S = {
	-- movement
	fly = false, flySpeed = 60,
	noclip = false, infJump = false, clickTP = false, dash = false, bhop = false,
	spin = false, spinSpeed = 360,
	walk = 16, walkCustom = false, jump = 50, jumpCustom = false,
	fov = 70, fovCustom = false,
	-- visual / world
	esp = false, espHealth = true, espDist = true, fullbright = false, nofog = false,
	crosshair = false, afk = false,
	-- players
	target = nil, mode = nil, spec = false,
	headOffset = 2.2, dist = 4, orbitRadius = 6, orbitSpeed = 2, orbitAngle = 0,
	savedPos = nil, lastDash = 0,
	-- combat
	boostMult = 2.5, goldFly = false, aura = false, tagSelf = false, tagText = "RIGGNES USER", tagged = {}, flyStyle = "Hero", rainbow = false, uiScale = 1, flyPitch = 0, flyRoll = 0, flyYaw = 0, flyFovAdd = 0, aim = false, aimPred = 0, antivoid = false, aimFov = 150, aimSmooth = 4, aimPart = "Head", aimDist = 500,
	teamCheck = false, wallCheck = true, showFov = true,
	trigger = false, lastTrig = 0,
	hitbox = false, hitboxSize = 6,
}

-- =============================================
-- SOUNDS
-- =============================================
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")

-- Each list is tried in order; the first ID that actually loads gets played.
-- Swap in any Roblox audio ID you like.
local SoundBank = {
	open  = {"rbxassetid://9118823104", "rbxassetid://6895079853", "rbxassetid://4590662766"},
	close = {"rbxassetid://9118822716", "rbxassetid://6895079853", "rbxassetid://4590662766"},
}

-- plays a sound with a pitch sweep + reverb so it feels like a "whoosh"
local function playSweep(list, fromSpeed, toSpeed, dur, vol, delay)
	task.spawn(function()
		if delay then task.wait(delay) end
		for _, id in ipairs(list) do
			local s = new("Sound", {SoundId = id, Volume = vol, PlaybackSpeed = fromSpeed}, ScreenGui)
			pcall(function() ContentProvider:PreloadAsync({s}) end)
			if s.TimeLength > 0 then
				new("EqualizerSoundEffect", {HighGain = 5, MidGain = 0, LowGain = -3}, s)
				new("ReverbSoundEffect", {DecayTime = 1.4, Density = 0.7, Diffusion = 0.8, DryLevel = 0, WetLevel = -5}, s)
				s:Play()
				tween(s, dur, {PlaybackSpeed = toSpeed}, Enum.EasingStyle.Quad)
				Debris:AddItem(s, math.max(s.TimeLength / math.max(toSpeed, 0.1), 1.5) + 1)
				return
			end
			s:Destroy()
		end
	end)
end

-- ---- menu UI sounds (hover / click / toggle / tab / notify) ----
local UIBank = {"rbxassetid://6895079853", "rbxassetid://4590662766", "rbxassetid://9118823104"}
local uiSound, uiLoading = nil, false
local function loadUISound()
	if uiLoading then return end
	uiLoading = true
	task.spawn(function()
		for _, id in ipairs(UIBank) do
			local sn = new("Sound", {SoundId = id, Volume = 0.5}, ScreenGui)
			pcall(function() ContentProvider:PreloadAsync({sn}) end)
			if sn.TimeLength > 0 then uiSound = sn return end
			sn:Destroy()
		end
	end)
end
-- pitch changes make one sample feel like many different UI sounds
local function playUI(speed, vol)
	if not uiSound then loadUISound() return end
	local c = uiSound:Clone()
	c.PlaybackSpeed = speed or 1
	c.Volume = vol or 0.5
	c.Parent = ScreenGui
	c:Play()
	Debris:AddItem(c, 2)
end
loadUISound()

local T = {}      -- handles to toggles so keybinds can flip them
local toggleUI    -- assigned later

-- ---- saved settings (needs executor readfile/writefile) ----
local CFG_FILE = "riggnes_settings.json"
local cfg = {}
if typeof(isfile) == "function" and typeof(readfile) == "function" then
	pcall(function()
		if isfile(CFG_FILE) then cfg = HttpService:JSONDecode(readfile(CFG_FILE)) end
	end)
end
if type(cfg) ~= "table" then cfg = {} end
local saveToken = 0
local function saveCfg()
	if typeof(writefile) ~= "function" then return end
	saveToken += 1
	local my = saveToken
	task.delay(0.4, function() -- debounce so holding a stepper doesn't spam the disk
		if my ~= saveToken then return end
		pcall(function() writefile(CFG_FILE, HttpService:JSONEncode(cfg)) end)
	end)
end
S.keybindsOn = true -- menu/keybind system is always enabled
if type(cfg.tagText) == "string" and cfg.tagText ~= "" then S.tagText = cfg.tagText end
if tonumber(cfg.uiScale) then S.uiScale = math.clamp(cfg.uiScale / 100, 0.6, 1.6) end

local function playOpenSound()
	playSweep(SoundBank.open, 0.55, 1.5, 0.45, 1.3)         -- rising whoosh
	playSweep(SoundBank.open, 1.4, 2.4, 0.35, 0.55, 0.07)   -- sparkle layer
	playSweep(SoundBank.open, 0.35, 0.5, 0.4, 0.8)          -- sub thump
	playSweep(SoundBank.open, 2.0, 2.6, 0.2, 0.3, 0.2)      -- high chime tail
end
local function playCloseSound()
	playSweep(SoundBank.close, 1.6, 0.55, 0.4, 1.3)         -- falling whoosh
	playSweep(SoundBank.close, 0.8, 0.4, 0.3, 0.7, 0.04)    -- low thud
	playSweep(SoundBank.close, 2.2, 1.2, 0.2, 0.3)          -- soft ping
end

-- =============================================
-- NOTIFICATIONS
-- =============================================
local toasts = new("Frame", {
	BackgroundTransparency = 1, Size = UDim2.new(0, 300, 0, 220),
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20),
}, ScreenGui)
new("UIListLayout", {
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 6),
}, toasts)

local function notify(msg)
	playUI(1.8, 0.45)
	local t = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 1, TextTransparency = 1, Text = msg,
		Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text,
	}, toasts)
	corner(t, 8)
	local s = stroke(t, Theme.Accent, 1, 1)
	tween(t, 0.2, {BackgroundTransparency = 0.1, TextTransparency = 0})
	tween(s, 0.2, {Transparency = 0.3})
	task.delay(2.2, function()
		if not t.Parent then return end
		tween(t, 0.25, {BackgroundTransparency = 1, TextTransparency = 1})
		tween(s, 0.25, {Transparency = 1})
		task.wait(0.3)
		t:Destroy()
	end)
end

-- =============================================
-- MAIN WINDOW (sidebar layout)
-- =============================================
local Main = new("CanvasGroup", {
	Name = "Main", Size = UDim2.new(0, 680, 0, 490),
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
	BackgroundColor3 = Theme.Bg, Visible = false, GroupTransparency = 1,
}, ScreenGui)
corner(Main, 16)
local mainStroke = stroke(Main, Theme.Accent, 2.5, 0)
onAccent(function(c) mainStroke.Color = c end)
local uiScale = new("UIScale", {Scale = 0.92}, Main)

-- header (drag handle)
local Header = new("Frame", {Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = Theme.Side, BorderSizePixel = 0}, Main)
local TopBar = new("Frame", {Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0}, Header)
local topGrad = new("UIGradient", {}, TopBar)
onAccent(function(c)
	local h, s, v = c:ToHSV()
	topGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, c),
		ColorSequenceKeypoint.new(0.5, Color3.fromHSV((h + 0.14) % 1, s, v)),
		ColorSequenceKeypoint.new(1, c),
	})
end)
local Title = new("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.new(0, 16, 0, 3), Size = UDim2.new(0, 100, 1, -3),
	Text = "riggnes", Font = Enum.Font.GothamBlack, TextSize = 24,
	TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Left,
}, Header)
onAccent(function(c) Title.TextColor3 = c end)
new("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.new(0, 108, 0, 8), Size = UDim2.new(0, 40, 1, -3),
	Text = "v2.0", Font = Enum.Font.GothamMedium, TextSize = 11,
	TextColor3 = Theme.Sub, TextXAlignment = Enum.TextXAlignment.Left,
}, Header)
local PageTitle = new("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.new(0, 170, 0, 3), Size = UDim2.new(1, -240, 1, -3),
	Text = "", Font = Enum.Font.GothamBold, TextSize = 15,
	TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
}, Header)

local CloseBtn = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 2), Size = UDim2.new(0, 28, 0, 28),
	BackgroundColor3 = Theme.Item, Text = "?", Font = Enum.Font.GothamBold, TextSize = 20,
	TextColor3 = Theme.Text, AutoButtonColor = false,
}, Header)
corner(CloseBtn, 8)
CloseBtn.MouseEnter:Connect(function() tween(CloseBtn, 0.12, {BackgroundColor3 = Color3.fromRGB(200, 60, 70)}) end)
CloseBtn.MouseLeave:Connect(function() tween(CloseBtn, 0.12, {BackgroundColor3 = Theme.Item}) end)

do -- dragging (mouse + touch)
	local dragging, dragStart, startPos
	Header.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = i.Position
			startPos = Main.Position
			i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	bind(UIS.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - dragStart
			Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
end

-- sidebar
local Sidebar = new("Frame", {Position = UDim2.new(0, 0, 0, 46), Size = UDim2.new(0, 150, 1, -46), BackgroundColor3 = Theme.Side, BorderSizePixel = 0}, Main)
local SideList = new("Frame", {Position = UDim2.new(0, 8, 0, 10), Size = UDim2.new(1, -16, 1, -90), BackgroundTransparency = 1}, Sidebar)
new("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, SideList)

-- profile card at bottom of sidebar
local prof = new("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -8), Size = UDim2.new(1, -16, 0, 68), BackgroundColor3 = Theme.Item}, Sidebar)
corner(prof, 10)
local av = new("ImageLabel", {Position = UDim2.new(0, 7, 0.5, -20), Size = UDim2.new(0, 40, 0, 40), BackgroundColor3 = Theme.Bg, Image = ""}, prof)
corner(av, 20)
local avStroke = stroke(av, Theme.Accent, 1.5, 0)
onAccent(function(c) avStroke.Color = c end)
task.spawn(function()
	local ok, img = pcall(function()
		return Players:GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	end)
	if ok then av.Image = img end
end)
new("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.new(0, 54, 0, 9), Size = UDim2.new(1, -58, 0, 16),
	Text = LP.DisplayName, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Text,
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
}, prof)
new("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.new(0, 54, 0, 25), Size = UDim2.new(1, -58, 0, 14),
	Text = "@" .. LP.Name, Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = Theme.Sub,
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
}, prof)
T.execProf = new("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.new(0, 54, 0, 42), Size = UDim2.new(1, -58, 0, 14),
	Text = "Exec: ...", Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Theme.Accent,
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
}, prof)
onAccent(function(c) T.execProf.TextColor3 = c end)

local Content = new("Frame", {Position = UDim2.new(0, 160, 0, 54), Size = UDim2.new(1, -170, 1, -80), BackgroundTransparency = 1, ClipsDescendants = true}, Main)
new("TextLabel", {
	BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 164, 1, -6), Size = UDim2.new(1, -180, 0, 16),
	Text = "Keybinds in Settings tab  ?  riggnes v2.0", Font = Enum.Font.Gotham, TextSize = 11,
	TextColor3 = Theme.Sub, TextXAlignment = Enum.TextXAlignment.Left,
}, Main)

local tabNames = {"Combat", "Movement", "Players", "Visual", "World", "Settings"}
if isOwner(LP) then table.insert(tabNames, "Owner") end
local tabBtns, pages = {}, {}

local function makePage()
	local p = new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(), Visible = false,
	}, Content)
	new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, p)
	new("UIPadding", {PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8)}, p)
	return p
end

local currentTab = 1
local function selectTab(i)
	currentTab = i
	for idx, pg in ipairs(pages) do
		local on = idx == i
		pg.Visible = on
		tween(tabBtns[idx], 0.15, {
			TextColor3 = on and Theme.Accent or Theme.Sub,
			BackgroundColor3 = on and Theme.Accent:Lerp(Theme.Item, 0.8) or Theme.Side,
		})
	end
	PageTitle.Text = tabNames[i]
end

for i, name in ipairs(tabNames) do
	local b = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = Theme.Side, Text = name, LayoutOrder = i,
		Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.Sub, AutoButtonColor = false,
	}, SideList)
	corner(b, 8)
	b.MouseButton1Click:Connect(function() playUI(1.1, 0.45) selectTab(i) end)
	b.MouseEnter:Connect(function() if currentTab ~= i then tween(b, 0.12, {BackgroundColor3 = Theme.Panel}) end end)
	b.MouseLeave:Connect(function() if currentTab ~= i then tween(b, 0.12, {BackgroundColor3 = Theme.Side}) end end)
	tabBtns[i] = b
	pages[i] = makePage()
end
onAccent(function() if pages[currentTab] then selectTab(currentTab) end end)
local PgCombat, PgMove, PgPlayers, PgVisual, PgWorld, PgSettings = pages[1], pages[2], pages[3], pages[4], pages[5], pages[6]
local PgOwner = pages[7]

-- =============================================
-- UI COMPONENTS
-- =============================================
local function section(page, text)
	new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Text = string.upper(text),
		Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Theme.Sub, TextXAlignment = Enum.TextXAlignment.Left,
	}, page)
end

local function toggle(page, text, default, cb)
	local row = new("TextButton", {Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Theme.Item, Text = "", AutoButtonColor = false}, page)
	corner(row, 8)
	stroke(row, Theme.Off, 1, 0.5)
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -70, 1, 0),
		Text = text, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	local sw = new("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 40, 0, 20), BackgroundColor3 = Theme.Off}, row)
	corner(sw, 10)
	local knob = new("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.new(0, 16, 0, 16), BackgroundColor3 = Color3.new(1, 1, 1)}, sw)
	corner(knob, 8)
	local state = default
	local function render()
		tween(sw, 0.15, {BackgroundColor3 = state and Theme.Accent or Theme.Off})
		tween(knob, 0.15, {Position = state and UDim2.new(0, 22, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)}, Enum.EasingStyle.Back)
	end
	local api = {}
	function api.set(v, silent)
		state = v
		render()
		if not silent then cb(v) end
	end
	function api.get() return state end
	row.MouseButton1Click:Connect(function() api.set(not state) playUI(state and 1.5 or 0.85, 0.5) end)
	row.MouseEnter:Connect(function() playUI(2.4, 0.08) tween(row, 0.12, {BackgroundColor3 = Theme.ItemHover}) end)
	row.MouseLeave:Connect(function() tween(row, 0.12, {BackgroundColor3 = Theme.Item}) end)
	onAccent(function() render() end)
	return api
end

local function stepper(page, text, value, min, max, step, cb, fmt)
	local row = new("Frame", {Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Theme.Item}, page)
	corner(row, 8)
	stroke(row, Theme.Off, 1, 0.5)
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -150, 1, 0),
		Text = text, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	local function mk(txt, x)
		local b = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, x, 0.5, 0), Size = UDim2.new(0, 28, 0, 24),
			BackgroundColor3 = Theme.Off, Text = txt, Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Theme.Text, AutoButtonColor = false,
		}, row)
		corner(b, 6)
		return b
	end
	local minus, plus = mk("-", -98), mk("+", -10)
	local valLbl = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -42, 0.5, 0), Size = UDim2.new(0, 52, 0, 24),
		BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.Accent,
	}, row)
	onAccent(function(c) valLbl.TextColor3 = c end)

	local api = {}
	local function show() valLbl.Text = fmt and fmt(value) or tostring(value) end
	function api.set(v, silent)
		value = math.clamp(v, min, max)
		show()
		if not silent then cb(value) end
	end
	function api.get() return value end
	show()

	local holdId = 0
	local function hold(btn, delta)
		btn.MouseButton1Down:Connect(function()
			holdId += 1
			local my = holdId
			playUI(delta > 0 and 1.35 or 1.0, 0.35)
			api.set(value + delta)
			task.spawn(function()
				task.wait(0.4)
				while holdId == my do
					api.set(value + delta)
					task.wait(0.06)
				end
			end)
		end)
		local function stop() holdId += 1 end
		btn.MouseButton1Up:Connect(stop)
		btn.MouseLeave:Connect(stop)
	end
	hold(minus, -step)
	hold(plus, step)
	return api
end

local function button(parent, text, cb, h)
	local b = new("TextButton", {
		Size = UDim2.new(1, 0, 0, h or 34), BackgroundColor3 = Theme.Item, Text = text,
		Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.Text, AutoButtonColor = false,
	}, parent)
	corner(b, 8)
	local st = stroke(b, Theme.Accent, 1.5, 0.35)
	b.MouseEnter:Connect(function()
		playUI(2.4, 0.08)
		if not b:GetAttribute("Active") then tween(b, 0.12, {BackgroundColor3 = Theme.ItemHover}) end
		tween(st, 0.12, {Transparency = 0})
	end)
	b.MouseLeave:Connect(function()
		if not b:GetAttribute("Active") then tween(b, 0.12, {BackgroundColor3 = Theme.Item}) end
		tween(st, 0.12, {Transparency = 0.35})
	end)
	b.MouseButton1Click:Connect(function() playUI(1.2, 0.5) cb(b) end)
	onAccent(function(c)
		st.Color = c
		if b:GetAttribute("Active") then
			b.TextColor3 = c
			b.BackgroundColor3 = c:Lerp(Theme.Item, 0.7)
		end
	end)
	return b
end

local function setActive(b, on)
	b:SetAttribute("Active", on)
	tween(b, 0.15, {
		BackgroundColor3 = on and Theme.Accent:Lerp(Theme.Item, 0.7) or Theme.Item,
		TextColor3 = on and Theme.Accent or Theme.Text,
	})
end

local function grid(page)
	local g = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1}, page)
	new("UIGridLayout", {CellSize = UDim2.new(0.5, -3, 0, 32), CellPadding = UDim2.new(0, 6, 0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, g)
	return g
end

-- =============================================
-- FLY / MODES / ESP / LIGHTING LOGIC
-- =============================================
local bv, bg

-- expanding energy ring (takeoff / boost / barrel roll)
local function shockwave(pos, dir)
	local ring = new("Part", {
		Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2, 2), Material = Enum.Material.Neon,
		Color = Theme.Accent, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		Transparency = 0.15, CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.rad(90), 0),
	}, workspace)
	TweenService:Create(ring, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = Vector3.new(0.3, 38, 38), Transparency = 1}):Play()
	Debris:AddItem(ring, 0.7)
end
local function stopFly()
	if bv then bv:Destroy() bv = nil end
	if bg then bg:Destroy() bg = nil end
	if T.joints then
		for _, d in pairs(T.joints) do
			if d.motor and d.motor.Parent then d.motor.C0 = d.c0 end
		end
		T.joints = nil
	end
	if T.fx then
		for _, o in pairs(T.fx) do if typeof(o) == "Instance" then o:Destroy() end end
		T.fx = nil
	end
	local hrp = getHRP()
	if hrp then -- level the character back upright
		local l = hrp.CFrame.LookVector
		local flat = Vector3.new(l.X, 0, l.Z)
		if flat.Magnitude > 0.01 then hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + flat) end
	end
	S.flyPitch, S.flyRoll = 0, 0
	local h = getHum()
	if h then h.PlatformStand = false end
end
local function startFly()
	local hrp, h = getHRP(), getHum()
	if not hrp or not h then return end
	stopFly()
	h.PlatformStand = true
	bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
	bv.Velocity = Vector3.new()
	bv.Parent = hrp
	bg = Instance.new("BodyGyro")
	bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
	bg.P = 1e4
	bg.D = 500
	bg.CFrame = hrp.CFrame
	bg.Parent = hrp

	-- fly effects: glowing trail + sparkles + launch burst
	local a0 = new("Attachment", {Position = Vector3.new(0, 0.9, 0)}, hrp)
	local a1 = new("Attachment", {Position = Vector3.new(0, -0.9, 0)}, hrp)
	local trail = new("Trail", {
		Attachment0 = a0, Attachment1 = a1, Lifetime = 0.4, LightEmission = 1, Enabled = false,
		Color = ColorSequence.new(Theme.Accent),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)}),
		WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)}),
	}, hrp)
	local em = new("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 0,
		Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(1, 4), SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)}),
		LightEmission = 1, Color = ColorSequence.new(Theme.Accent),
	}, hrp)
	T.fx = {a0 = a0, a1 = a1, trail = trail, em = em}
	-- long vapor trails streaming off the shoulders
	for idx, sx in ipairs({-1.9, 1.9}) do
		local w0 = new("Attachment", {Position = Vector3.new(sx, 0.6, 0)}, hrp)
		local w1 = new("Attachment", {Position = Vector3.new(sx, -0.6, 0)}, hrp)
		local wt = new("Trail", {
			Attachment0 = w0, Attachment1 = w1, Lifetime = 0.6, LightEmission = 0.8, Enabled = false, MinLength = 0.05,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Theme.Accent),
			Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)}),
			WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0)}),
		}, hrp)
		T.fx["w0_" .. idx] = w0
		T.fx["w1_" .. idx] = w1
		T.fx["wt_" .. idx] = wt
	end
	shockwave(hrp.Position, Vector3.new(0, 1, 0))

	-- limb animation (R15 only): remember original joint positions
	T.joints = nil
	if h.RigType == Enum.HumanoidRigType.R15 then
		local wanted = {Neck = true, LeftShoulder = true, RightShoulder = true, LeftHip = true, RightHip = true, LeftKnee = true, RightKnee = true, LeftAnkle = true, RightAnkle = true}
		local js = {}
		for _, m in ipairs(LP.Character:GetDescendants()) do
			if m:IsA("Motor6D") and wanted[m.Name] then js[m.Name] = {motor = m, c0 = m.C0} end
		end
		T.joints = js
	end
	em:Emit(40)
	S.flyBaseFov = cam().FieldOfView
	pcall(function() playSweep(SoundBank.open, 0.6, 1.8, 0.4, 0.8) end)
end
-- keep fly effects in sync with the accent color
onAccent(function(c)
	if T.fx then
		T.fx.trail.Color = ColorSequence.new(c)
		T.fx.em.Color = ColorSequence.new(c)
	end
end)

local flyToggle
local modeBtns = {}
local function refreshModeButtons()
	for name, b in pairs(modeBtns) do setActive(b, S.mode == name) end
end
local function setMode(m)
	if S.mode == m then m = nil end
	if m and not S.target then
		notify("Select a player first")
		return
	end
	if S.mode == "sit" and m ~= "sit" then
		local h = getHum()
		if h then h.Sit = false end
	end
	if m and S.fly and flyToggle then flyToggle.set(false) end
	S.mode = m
	refreshModeButtons()
	if m then notify("Mode: " .. m .. " ? " .. S.target.DisplayName) end
end

-- ESP (highlight + name / health / distance)
local esp = {}
local function clearESP(plr)
	local e = esp[plr]
	if e then
		for _, o in pairs(e) do if typeof(o) == "Instance" then o:Destroy() end end
		esp[plr] = nil
	end
end
local function applyESP(plr)
	clearESP(plr)
	if not S.esp or plr == LP then return end
	local char = plr.Character
	if not char then return end
	local hl = new("Highlight", {
		FillColor = Theme.Accent, FillTransparency = 0.75, OutlineColor = Theme.Accent,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
	}, char)
	local head = char:FindFirstChild("Head")
	local bb, lbl
	if head then
		bb = new("BillboardGui", {Size = UDim2.new(0, 160, 0, 34), StudsOffset = Vector3.new(0, 2.8, 0), AlwaysOnTop = true, Adornee = head}, head)
		lbl = new("TextLabel", {
			Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = plr.DisplayName,
			Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Accent, TextStrokeTransparency = 0.4,
		}, bb)
	end
	esp[plr] = {hl = hl, bb = bb, lbl = lbl}
end
onAccent(function(c)
	for _, e in pairs(esp) do
		if e.hl then e.hl.FillColor = c e.hl.OutlineColor = c end
		if e.lbl then e.lbl.TextColor3 = c end
	end
end)
local function setESP(on)
	S.esp = on
	for _, plr in ipairs(Players:GetPlayers()) do
		if on then applyESP(plr) else clearESP(plr) end
	end
end
local function updateESPText()
	local myHRP = getHRP()
	for plr, e in pairs(esp) do
		if e.lbl and plr.Character then
			local h = plr.Character:FindFirstChildOfClass("Humanoid")
			local r = plr.Character:FindFirstChild("HumanoidRootPart")
			local txt = plr.DisplayName
			if S.espHealth and h then txt ..= "  [" .. math.floor(h.Health) .. " HP]" end
			if S.espDist and myHRP and r then txt ..= "\n" .. math.floor((myHRP.Position - r.Position).Magnitude) .. " studs" end
			e.lbl.Text = txt
		end
	end
end

-- Lighting
local lightSaved
local function saveLight()
	if not lightSaved then
		lightSaved = {Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, FogEnd = Lighting.FogEnd, GlobalShadows = Lighting.GlobalShadows, Ambient = Lighting.Ambient}
	end
end
local function setFullbright(on)
	S.fullbright = on
	if on then
		saveLight()
		Lighting.Brightness = 2
		Lighting.ClockTime = 14
		Lighting.FogEnd = 1e6
		Lighting.GlobalShadows = false
		Lighting.Ambient = Color3.fromRGB(178, 178, 178)
	elseif lightSaved then
		for k, v in pairs(lightSaved) do Lighting[k] = v end
		lightSaved = nil
	end
end

-- Spectate
local function setSpectate(on)
	if on and not S.target then notify("Select a player first") return false end
	S.spec = on
	if not on then
		local h = getHum()
		if h then cam().CameraSubject = h end
	end
	return true
end

-- Hitbox expander
local hitboxSaved = {}
local function restoreHitboxes()
	for part, d in pairs(hitboxSaved) do
		if part and part.Parent then
			part.Size = d.Size
			part.Transparency = d.Transparency
			part.CanCollide = d.CanCollide
		end
	end
	hitboxSaved = {}
end
local function applyHitboxes()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LP and plr.Character then
			if not (S.teamCheck and LP.Team and plr.Team == LP.Team) then
				local r = plr.Character:FindFirstChild("HumanoidRootPart")
				if r then
					if not hitboxSaved[r] then
						hitboxSaved[r] = {Size = r.Size, Transparency = r.Transparency, CanCollide = r.CanCollide}
					end
					r.Size = Vector3.new(S.hitboxSize, S.hitboxSize, S.hitboxSize)
					r.Transparency = 0.7
					r.CanCollide = false
				end
			end
		end
	end
end

-- =============================================
-- AIMBOT
-- =============================================
-- =============================================
-- SCRIPT TAGS (banner above a player's head, only visible on YOUR screen)
-- =============================================
local tags = {}
local function clearTag(plr)
	local t = tags[plr]
	if t then
		if t.gui then t.gui:Destroy() end
		if t.att then t.att:Destroy() end
		tags[plr] = nil
	end
end
local function makeTag(plr)
	clearTag(plr)
	local char = plr.Character
	local head = char and char:FindFirstChild("Head")
	if not head then return end
	local gui = new("BillboardGui", {
		Name = "riggnes_tag", Adornee = head, Size = UDim2.new(0, 230, 0, 52),
		StudsOffset = Vector3.new(0, 4.4, 0), AlwaysOnTop = true, MaxDistance = 200, LightInfluence = 0,
	}, head)
	local card = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(10, 12, 22), BackgroundTransparency = 0.08}, gui)
	corner(card, 14)
	local owner = isOwner(plr)
	local col = owner and OWNER_GOLD or Theme.Accent
	local st = stroke(card, col, 2.5, 0)
	new("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(24, 28, 52), Color3.fromRGB(8, 10, 18)), Rotation = 90}, card)
	local badge = new("Frame", {Position = UDim2.new(0, 8, 0.5, -17), Size = UDim2.new(0, 34, 0, 34), BackgroundColor3 = col}, card)
	corner(badge, 9)
	new("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = owner and "OWN" or "RG", Font = Enum.Font.GothamBlack,
		TextSize = owner and 11 or 16, TextColor3 = Color3.fromRGB(8, 12, 24),
	}, badge)
	local title = new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 50, 0, 6), Size = UDim2.new(1, -58, 0, 22),
		Text = owner and "RIGGNES OWNER" or S.tagText, Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = col,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
	}, card)
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 50, 0, 28), Size = UDim2.new(1, -58, 0, 16),
		Text = "@" .. plr.Name .. "  ?", Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Theme.Sub,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
	}, card)
	local att
	if owner then -- gold sparkles floating around the owner's head
		att = new("Attachment", {Position = Vector3.new(0, 1.5, 0)}, head)
		new("ParticleEmitter", {
			Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 14, Lifetime = NumberRange.new(0.8, 1.4),
			Speed = NumberRange.new(0.5, 2), SpreadAngle = Vector2.new(180, 180), LightEmission = 1,
			Color = ColorSequence.new(OWNER_GOLD),
			Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0)}),
			Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)}),
		}, att)
	end
	tags[plr] = {gui = gui, stroke = st, badge = badge, title = title, owner = owner, att = att}
end
onAccent(function(c)
	for _, t in pairs(tags) do
		if not t.owner then
			t.stroke.Color = c
			t.badge.BackgroundColor3 = c
			t.title.TextColor3 = c
		end
	end
end)
local tagClock = 0
bind(RunService.RenderStepped, function(dt)
	tagClock += dt
	local i = 0
	for _, t in pairs(tags) do
		i += 1
		if t.gui and t.gui.Parent then
			t.gui.StudsOffset = Vector3.new(0, 4.4 + math.sin(tagClock * 2 + i) * 0.12, 0) -- gentle float
			t.stroke.Thickness = 2.2 + math.sin(tagClock * 3 + i) * 0.7                    -- pulsing border
		end
	end
end)
local function refreshTag(plr)
	clearTag(plr) -- banner/tag removed: never show anything above heads
end

local fovCircle = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false,
	Size = UDim2.new(0, S.aimFov * 2, 0, S.aimFov * 2),
}, ScreenGui)
corner(fovCircle, 1000)
local fovStroke = stroke(fovCircle, Theme.Accent, 1.5, 0.2)
onAccent(function(c) fovStroke.Color = c end)

local function visibleTo(c, part, char)
	if not S.wallCheck then return true end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {LP.Character, char}
	local origin = c.CFrame.Position
	local res = workspace:Raycast(origin, part.Position - origin, params)
	return res == nil
end

local function getClosest()
	local c = cam()
	local mpos = UIS:GetMouseLocation()
	local best, bestD = nil, S.aimFov
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LP and plr.Character then
			local char = plr.Character
			local hum = char:FindFirstChildOfClass("Humanoid")
			local part = char:FindFirstChild(S.aimPart) or char:FindFirstChild("HumanoidRootPart")
			if hum and hum.Health > 0 and part then
				if not (S.teamCheck and LP.Team and plr.Team == LP.Team) then
					if (part.Position - c.CFrame.Position).Magnitude <= S.aimDist then
						local v, on = c:WorldToViewportPoint(part.Position)
						if on then
							local d = (Vector2.new(v.X, v.Y) - mpos).Magnitude
							if d < bestD and visibleTo(c, part, char) then
								best, bestD = part, d
							end
						end
					end
				end
			end
		end
	end
	return best
end

RunService:BindToRenderStep("riggnes_aim", Enum.RenderPriority.Camera.Value + 1, function()
	local mpos = UIS:GetMouseLocation()
	fovCircle.Position = UDim2.new(0, mpos.X, 0, mpos.Y)
	fovCircle.Visible = S.aim and S.showFov
	if S.aim and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
		local part = getClosest()
		if part then
			local c = cam()
			local goal = CFrame.lookAt(c.CFrame.Position, part.Position + part.AssemblyLinearVelocity * (S.aimPred / 100))
			c.CFrame = c.CFrame:Lerp(goal, 1 / math.max(S.aimSmooth, 1))
		end
	end
end)

-- =============================================
-- PAGE: COMBAT
-- =============================================
section(PgCombat, "Aimbot  (hold Right Mouse)")
T.aim = toggle(PgCombat, "Aimbot", false, function(v) S.aim = v end)
toggle(PgCombat, "Show FOV Circle", true, function(v) S.showFov = v end)
stepper(PgCombat, "Aim FOV", S.aimFov, 30, 600, 10, function(v)
	S.aimFov = v
	fovCircle.Size = UDim2.new(0, v * 2, 0, v * 2)
end)
stepper(PgCombat, "Smoothness", S.aimSmooth, 1, 30, 1, function(v) S.aimSmooth = v end)
stepper(PgCombat, "Max Distance", S.aimDist, 50, 2000, 50, function(v) S.aimDist = v end)
stepper(PgCombat, "Prediction (moving targets)", S.aimPred, 0, 30, 1, function(v) S.aimPred = v end)
local partBtn
partBtn = button(PgCombat, "Aim Part: Head", function()
	S.aimPart = S.aimPart == "Head" and "HumanoidRootPart" or "Head"
	partBtn.Text = "Aim Part: " .. (S.aimPart == "Head" and "Head" or "Body")
end, 34)
toggle(PgCombat, "Team Check", false, function(v) S.teamCheck = v end)
toggle(PgCombat, "Wall Check", true, function(v) S.wallCheck = v end)

section(PgCombat, "Triggerbot")
toggle(PgCombat, "Triggerbot  (auto click on enemy)", false, function(v)
	S.trigger = v
	if v and typeof(mouse1click) ~= "function" then notify("Your executor has no mouse1click") end
end)

section(PgCombat, "Hitbox")
toggle(PgCombat, "Hitbox Expander", false, function(v)
	S.hitbox = v
	if not v then restoreHitboxes() end
end)
stepper(PgCombat, "Hitbox Size", S.hitboxSize, 2, 30, 1, function(v) S.hitboxSize = v end)

-- =============================================
-- PAGE: MOVEMENT
-- =============================================
local hum0 = getHum()
local defWalk = hum0 and hum0.WalkSpeed or 16
local defJump = hum0 and hum0.JumpPower or 50
S.walk, S.jump = defWalk, defJump

section(PgMove, "Flight & collision")
flyToggle = toggle(PgMove, "Fly  (WASD / Space / Shift,  E boost,  R roll)", false, function(v)
	S.fly = v
	if v then
		if S.mode then setMode(S.mode) end
		startFly()
	else
		stopFly()
	end
end)
stepper(PgMove, "Fly Speed", S.flySpeed, 10, 400, 10, function(v) S.flySpeed = v end)
local styleBtn
styleBtn = button(PgMove, "Fly Style: Hero", function()
	local order = {"Hero", "Superman", "Jet"}
	local i = table.find(order, S.flyStyle) or 1
	S.flyStyle = order[i % #order + 1]
	styleBtn.Text = "Fly Style: " .. S.flyStyle
end, 32)
toggle(PgMove, "Rainbow Fly Trail", false, function(v) S.rainbow = v end)
T.noclip = toggle(PgMove, "Noclip", false, function(v) S.noclip = v end)

section(PgMove, "Speed & jumping")
local walkStep = stepper(PgMove, "WalkSpeed", defWalk, 0, 300, 4, function(v) S.walk = v S.walkCustom = true end)
local jumpStep = stepper(PgMove, "JumpPower", defJump, 0, 500, 10, function(v) S.jump = v S.jumpCustom = true end)
T.infJump = toggle(PgMove, "Infinite Jump", false, function(v) S.infJump = v end)
toggle(PgMove, "Bunny Hop  (hold Space)", false, function(v) S.bhop = v end)
toggle(PgMove, "Dash  (press Q)", false, function(v) S.dash = v end)
toggle(PgMove, "Anti-Void  (saves you from falling)", false, function(v) S.antivoid = v end)
stepper(PgMove, "Gravity", math.floor(origGravity), 0, 400, 10, function(v) workspace.Gravity = v end)

section(PgMove, "Fun")
T.spin = toggle(PgMove, "Spin", false, function(v) S.spin = v end)
stepper(PgMove, "Spin Speed", S.spinSpeed, 90, 1800, 90, function(v) S.spinSpeed = v end)

section(PgMove, "Teleport")
toggle(PgMove, "Click TP  (Ctrl + Click)", false, function(v) S.clickTP = v end)
local mvGrid = grid(PgMove)
button(mvGrid, "Save Position", function()
	local hrp = getHRP()
	if hrp then S.savedPos = hrp.CFrame notify("Position saved") end
end)
button(mvGrid, "Go To Saved", function()
	local hrp = getHRP()
	if hrp and S.savedPos then hrp.CFrame = S.savedPos else notify("No saved position") end
end)
button(mvGrid, "Reset Speed/Jump", function()
	S.walkCustom, S.jumpCustom = false, false
	walkStep.set(defWalk, true)
	jumpStep.set(defJump, true)
	local h = getHum()
	if h then h.WalkSpeed = defWalk h.JumpPower = defJump end
end)
button(mvGrid, "Reset Character", function()
	local h = getHum()
	if h then h.Health = 0 end
end)

-- =============================================
-- PAGE: PLAYERS
-- =============================================
section(PgPlayers, "Select a player")
local search = new("TextBox", {
	Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = Theme.Item, PlaceholderText = "Search player...",
	PlaceholderColor3 = Theme.Sub, Text = "", ClearTextOnFocus = false, Font = Enum.Font.GothamMedium,
	TextSize = 13, TextColor3 = Theme.Text,
}, PgPlayers)
corner(search, 8)
new("UIPadding", {PaddingLeft = UDim.new(0, 10)}, search)
stroke(search, Theme.Off, 1, 0.5)

local list = new("ScrollingFrame", {
	Size = UDim2.new(1, 0, 0, 120), BackgroundColor3 = Theme.Item, BorderSizePixel = 0,
	ScrollBarThickness = 3, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
}, PgPlayers)
corner(list, 8)
stroke(list, Theme.Off, 1, 0.5)
new("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.Name}, list)
new("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 4)}, list)

local targetLbl = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Text = "Target: none",
	Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Left,
}, PgPlayers)
onAccent(function(c) targetLbl.TextColor3 = c end)

local refreshPlayers
local function selectTarget(plr)
	S.target = plr
	targetLbl.Text = plr and ("Target: " .. plr.DisplayName .. "  (@" .. plr.Name .. ")") or "Target: none"
	if S.spec and plr then
		local c = plr.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if h then cam().CameraSubject = h end
	end
	refreshPlayers()
end

refreshPlayers = function()
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end
	local q = search.Text:lower()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LP and (q == "" or plr.Name:lower():find(q, 1, true) or plr.DisplayName:lower():find(q, 1, true)) then
			local sel = S.target == plr
			local b = new("TextButton", {
				Name = plr.Name, Size = UDim2.new(1, 0, 0, 26),
				BackgroundColor3 = sel and Theme.Accent:Lerp(Theme.Item, 0.7) or Theme.Panel,
				Text = plr.DisplayName .. "   @" .. plr.Name, Font = Enum.Font.Gotham, TextSize = 12,
				TextColor3 = sel and Theme.Accent or Theme.Text, AutoButtonColor = false,
			}, list)
			corner(b, 6)
			b.MouseButton1Click:Connect(function() selectTarget(plr) end)
		end
	end
end
onAccent(function() if refreshPlayers then refreshPlayers() end end)
bind(search:GetPropertyChangedSignal("Text"), function() refreshPlayers() end)

local function needTarget()
	if not S.target then notify("Select a player first") end
	return S.target
end

section(PgPlayers, "Actions")
local plGrid = grid(PgPlayers)
button(plGrid, "Teleport To", function()
	local p = needTarget()
	local root = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	local hrp = getHRP()
	if root and hrp then hrp.CFrame = root.CFrame * CFrame.new(0, 1, 4) end
end)
modeBtns.sit = button(plGrid, "Sit On Head", function() setMode("sit") end)
modeBtns.piggy = button(plGrid, "Piggyback", function() setMode("piggy") end)
modeBtns.follow = button(plGrid, "Follow", function() setMode("follow") end)
modeBtns.orbit = button(plGrid, "Orbit", function() setMode("orbit") end)
modeBtns.behind = button(plGrid, "Stick Behind", function() setMode("behind") end)
modeBtns.face = button(plGrid, "Face Player", function() setMode("face") end)
local specBtn
specBtn = button(plGrid, "Spectate", function()
	local on = not S.spec
	if setSpectate(on) then setActive(specBtn, on) end
end)
button(plGrid, "Random Target", function()
	local all = {}
	for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then table.insert(all, p) end end
	if #all == 0 then notify("No other players") return end
	selectTarget(all[math.random(1, #all)])
end)
button(plGrid, "Copy Name", function()
	local p = needTarget()
	if p then
		if typeof(setclipboard) == "function" then setclipboard(p.Name) notify("Copied " .. p.Name)
		else notify("Clipboard not supported") end
	end
end)
button(plGrid, "Stop All", function()
	if S.mode then setMode(S.mode) end
	if S.spec then setSpectate(false) setActive(specBtn, false) end
end)

section(PgPlayers, "Tuning")
stepper(PgPlayers, "Head Height", S.headOffset, 0, 8, 0.2, function(v) S.headOffset = v end, function(v) return string.format("%.1f", v) end)
stepper(PgPlayers, "Follow Distance", S.dist, 1, 30, 1, function(v) S.dist = v end)
stepper(PgPlayers, "Orbit Radius", S.orbitRadius, 2, 50, 1, function(v) S.orbitRadius = v end)
stepper(PgPlayers, "Orbit Speed", S.orbitSpeed, 1, 20, 1, function(v) S.orbitSpeed = v end)

-- =============================================
-- PAGE: VISUAL
-- =============================================
section(PgVisual, "ESP")
T.esp = toggle(PgVisual, "Player ESP", false, setESP)
toggle(PgVisual, "Show Health", true, function(v) S.espHealth = v end)
toggle(PgVisual, "Show Distance", true, function(v) S.espDist = v end)

section(PgVisual, "Camera")
stepper(PgVisual, "Field of View", 70, 30, 120, 5, function(v) S.fov = v S.fovCustom = true end)
stepper(PgVisual, "Max Zoom", math.floor(LP.CameraMaxZoomDistance), 10, 2000, 50, function(v) LP.CameraMaxZoomDistance = v end)

section(PgVisual, "HUD")
local cross = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 14, 0, 14),
	BackgroundTransparency = 1, Visible = false,
}, ScreenGui)
local chH = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 2), BorderSizePixel = 0, BackgroundColor3 = Theme.Accent}, cross)
local chV = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 2, 1, 0), BorderSizePixel = 0, BackgroundColor3 = Theme.Accent}, cross)
onAccent(function(c) chH.BackgroundColor3 = c chV.BackgroundColor3 = c end)
T.cross = toggle(PgVisual, "Crosshair", false, function(v) cross.Visible = v end)

do -- FPS / ping counter
	local Stats = game:GetService("Stats")
	local hud = new("TextLabel", {
		Position = UDim2.new(0, 10, 0, 10), Size = UDim2.new(0, 150, 0, 24), BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.2, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Accent,
		Text = "", Visible = false,
	}, ScreenGui)
	corner(hud, 6)
	onAccent(function(c) hud.TextColor3 = c end)
	local frames, acc = 0, 0
	bind(RunService.RenderStepped, function(dt)
		if not hud.Visible then return end
		frames += 1
		acc += dt
		if acc >= 0.5 then
			local ping = 0
			pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
			hud.Text = math.floor(frames / acc) .. " FPS  ?  " .. ping .. " ms"
			frames, acc = 0, 0
		end
	end)
	T.hud = toggle(PgVisual, "FPS / Ping Counter", false, function(v) hud.Visible = v end)
end

-- =============================================
-- PAGE: WORLD
-- =============================================
section(PgWorld, "Lighting")
T.fullbright = toggle(PgWorld, "Fullbright", false, setFullbright)
toggle(PgWorld, "No Fog", false, function(v)
	S.nofog = v
	if v then saveLight() Lighting.FogEnd = 1e6 elseif lightSaved and not S.fullbright then Lighting.FogEnd = lightSaved.FogEnd end
end)
stepper(PgWorld, "Time of Day", math.floor(Lighting.ClockTime), 0, 24, 1, function(v) saveLight() Lighting.ClockTime = v end)

section(PgWorld, "Performance")
local wGrid = grid(PgWorld)
button(wGrid, "FPS Boost", function()
	pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
	Lighting.GlobalShadows = false
	for _, o in ipairs(workspace:GetDescendants()) do
		if o:IsA("BasePart") then o.Material = Enum.Material.Plastic o.CastShadow = false
		elseif o:IsA("ParticleEmitter") or o:IsA("Trail") then o.Enabled = false end
	end
	notify("FPS boost applied")
end)
button(wGrid, "Remove Effects", function()
	for _, o in ipairs(Lighting:GetChildren()) do
		if o:IsA("PostEffect") or o:IsA("Atmosphere") or o:IsA("BlurEffect") then o:Destroy() end
	end
	notify("Effects removed")
end)

-- =============================================
-- PAGE: SETTINGS
-- =============================================
if PgOwner then
	section(PgOwner, "Owner powers")
	local info = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = Theme.Item, TextWrapped = true,
		Text = "You are the riggnes owner. Owner tab unlocked.",
		Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = OWNER_GOLD,
	}, PgOwner)
	corner(info, 8)
	stroke(info, OWNER_GOLD, 1.5, 0.3)
	new("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}, info)

	T.setAura = function(on)
		if T.aura then T.aura:Destroy() T.aura = nil end
		local hrp = getHRP()
		if on and hrp then
			T.aura = new("ParticleEmitter", {
				Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 45, Lifetime = NumberRange.new(0.8, 1.4),
				Speed = NumberRange.new(2, 6), SpreadAngle = Vector2.new(180, 180), LightEmission = 1,
				Color = ColorSequence.new(OWNER_GOLD),
				Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0)}),
				Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)}),
			}, hrp)
		end
	end
	toggle(PgOwner, "Gold Aura", false, function(v) S.aura = v T.setAura(v) end)
	toggle(PgOwner, "Golden Fly Trail", false, function(v) S.goldFly = v end)
	stepper(PgOwner, "Owner Fly Speed", S.flySpeed, 10, 1500, 50, function(v) S.flySpeed = v end)
	stepper(PgOwner, "Boost Power", S.boostMult, 1.5, 12, 0.5, function(v) S.boostMult = v end, function(v) return string.format("%.1fx", v) end)
end

section(PgSettings, "Interface")
local scaleStep
scaleStep = stepper(PgSettings, "UI Scale", math.floor(S.uiScale * 100 + 0.5), 60, 160, 5, function(v)
	S.uiScale = v / 100
	cfg.uiScale = v
	saveCfg()
	tween(uiScale, 0.15, {Scale = S.uiScale})
end, function(v) return v .. "%" end)
button(PgSettings, "Reset UI Scale", function()
	scaleStep.set(100)
end, 30)

section(PgSettings, "Accent color")
local colorNameLbl
local swatchRow = new("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Theme.Item}, PgSettings)
corner(swatchRow, 8)
stroke(swatchRow, Theme.Off, 1, 0.5)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), VerticalAlignment = Enum.VerticalAlignment.Center, HorizontalAlignment = Enum.HorizontalAlignment.Center}, swatchRow)
colorNameLbl = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Text = "Cyan",
	Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Left,
}, PgSettings)
onAccent(function(c) colorNameLbl.TextColor3 = c end)
for _, e in ipairs({
	{"Cyan", Color3.fromRGB(0, 229, 255)}, {"Mint", Color3.fromRGB(0, 255, 140)}, {"Violet", Color3.fromRGB(170, 100, 255)},
	{"Pink", Color3.fromRGB(255, 80, 170)}, {"Orange", Color3.fromRGB(255, 150, 40)}, {"Red", Color3.fromRGB(255, 70, 70)},
	{"Gold", Color3.fromRGB(255, 210, 60)}, {"Lime", Color3.fromRGB(170, 255, 60)},
}) do
	local s = new("TextButton", {Size = UDim2.new(0, 24, 0, 24), BackgroundColor3 = e[2], Text = "", AutoButtonColor = false}, swatchRow)
	corner(s, 12)
	s.MouseEnter:Connect(function() tween(s, 0.12, {Size = UDim2.new(0, 28, 0, 28)}) end)
	s.MouseLeave:Connect(function() tween(s, 0.12, {Size = UDim2.new(0, 24, 0, 24)}) end)
	s.MouseButton1Click:Connect(function()
		setAccent(e[2])
		colorNameLbl.Text = e[1]
		cfg.accent = {math.floor(e[2].R * 255 + 0.5), math.floor(e[2].G * 255 + 0.5), math.floor(e[2].B * 255 + 0.5)}
		cfg.accentName = e[1]
		saveCfg()
	end)
end

local function getExecutor()
	local function g(name)
		local v
		pcall(function() v = getgenv and getgenv()[name] end)
		if v == nil then pcall(function() v = getfenv(0)[name] end) end
		if v == nil then pcall(function() v = _G[name] end) end
		return v
	end
	for _, fname in ipairs({"identifyexecutor", "getexecutorname", "whatexecutor"}) do
		local fn = g(fname)
		if type(fn) == "function" then
			local ok, name, ver = pcall(fn)
			if ok and name and tostring(name) ~= "" then
				return tostring(name), ver and tostring(ver) or nil
			end
		end
	end
	local known = {
		{"Xeno", "Xeno"}, {"Solara", "Solara"}, {"Wave", "Wave"}, {"Velocity", "Velocity"},
		{"Delta", "Delta"}, {"Fluxus", "Fluxus"}, {"fluxus", "Fluxus"}, {"syn", "Synapse X"},
		{"KRNL_LOADED", "KRNL"}, {"is_sirhurt_closure", "SirHurt"}, {"PROTOSMASHER_LOADED", "ProtoSmasher"},
		{"SENTINEL_V2", "Sentinel"}, {"Seliware", "Seliware"}, {"Potassium", "Potassium"},
		{"Swift", "Swift"}, {"Volcano", "Volcano"}, {"Bunni", "Bunni"},
	}
	for _, k in ipairs(known) do
		if g(k[1]) ~= nil then return k[2], nil end
	end
	return "Unknown", nil
end
local execName, execVer = getExecutor()
local execText = execVer and (execName .. " " .. execVer) or execName
T.execProf.Text = "Exec: " .. execText

section(PgSettings, "Executor")
local execRow = new("Frame", {Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Theme.Item}, PgSettings)
corner(execRow, 8)
stroke(execRow, Theme.Off, 1, 0.5)
new("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(0, 90, 1, 0),
	Text = "Running on", Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text,
	TextXAlignment = Enum.TextXAlignment.Left,
}, execRow)
local execLbl = new("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.new(0, 105, 0, 0), Size = UDim2.new(1, -117, 1, 0),
	Text = execText, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.Accent,
	TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
}, execRow)
onAccent(function(c) execLbl.TextColor3 = c end)

section(PgSettings, "Keybinds  (menu toggle is permanently RightControl)")
new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1,
	Text = "Menu Toggle: RIGHT CONTROL  ?  Always ON  ?  Cannot be disabled or rebound",
	Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Theme.Accent,
	TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
}, PgSettings)
if typeof(writefile) ~= "function" then
	new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, TextWrapped = true,
		Text = "Your executor has no writefile, so settings can't be saved between sessions.",
		Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Theme.Sub, TextXAlignment = Enum.TextXAlignment.Left,
	}, PgSettings)
end
do
	local function flip(t) return function() t.set(not t.get()) end end
	local binds = {
		{name = "Toggle Menu", key = Enum.KeyCode.RightControl, fn = function() toggleUI() end},
		{name = "Fly", key = Enum.KeyCode.F, fn = function() flyToggle.set(not flyToggle.get()) end},
		{name = "Noclip", key = Enum.KeyCode.N, fn = flip(T.noclip)},
		{name = "Aimbot", key = Enum.KeyCode.V, fn = flip(T.aim)},
		{name = "Player ESP", key = Enum.KeyCode.B, fn = flip(T.esp)},
		{name = "Fullbright", key = Enum.KeyCode.L, fn = flip(T.fullbright)},
		{name = "Infinite Jump", key = Enum.KeyCode.J, fn = flip(T.infJump)},
		{name = "Spin", key = Enum.KeyCode.K, fn = flip(T.spin)},
		{name = "Fly Barrel Roll", key = Enum.KeyCode.R, fn = function()
			if S.fly and not S.rollStart then
				S.rollStart = tick()
				local hrp = getHRP()
				if hrp then shockwave(hrp.Position, cam().CFrame.LookVector) end
				pcall(function() playSweep(SoundBank.open, 1.0, 2.4, 0.3, 0.7) end)
			end
		end},
		{name = "Crosshair", key = Enum.KeyCode.C, fn = flip(T.cross)},
		{name = "FPS Counter", key = Enum.KeyCode.P, fn = flip(T.hud)},
		{name = "Save Position", key = Enum.KeyCode.Z, fn = function()
			local hrp = getHRP()
			if hrp then S.savedPos = hrp.CFrame notify("Position saved") end
		end},
		{name = "Go To Saved", key = Enum.KeyCode.X, fn = function()
			local hrp = getHRP()
			if hrp and S.savedPos then hrp.CFrame = S.savedPos else notify("No saved position") end
		end},
		{name = "Stop Target Modes", key = Enum.KeyCode.H, fn = function()
			if S.mode then setMode(S.mode) end
			if S.spec then setSpectate(false) setActive(specBtn, false) end
		end},
	}
	local function persist()
		cfg.keys, cfg.off = {}, {}
		for _, b in ipairs(binds) do
			cfg.keys[b.name] = b.key and b.key.Name or false
			if not b.enabled then cfg.off[b.name] = true end
		end
		cfg.kbOn = true
		saveCfg()
	end
	T.persistKeys = persist
	local listening
	for _, b in ipairs(binds) do
		b.default = b.key
		if b.name ~= "Toggle Menu" then
			local sk = type(cfg.keys) == "table" and cfg.keys[b.name]
			if sk == false then
				b.key = nil
			elseif type(sk) == "string" then
				local ok, kc = pcall(function() return Enum.KeyCode[sk] end)
				if ok and kc then b.key = kc end
			end
			b.enabled = not (type(cfg.off) == "table" and cfg.off[b.name])
		else
			-- Ignore saved settings: the menu key is locked to RightControl.
			b.key = Enum.KeyCode.RightControl
			b.enabled = true
		end
		local row = new("Frame", {Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Theme.Item}, PgSettings)
		corner(row, 8)
		stroke(row, Theme.Off, 1, 0.5)
		new("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -175, 1, 0),
			Text = b.name, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
		}, row)
		b.btn = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0, 100, 0, 24),
			BackgroundColor3 = Theme.Off, Text = b.key and b.key.Name or "None", Font = Enum.Font.GothamBold,
			TextSize = 12, TextColor3 = Theme.Accent, AutoButtonColor = false,
		}, row)
		corner(b.btn, 6)
		onAccent(function(c) b.btn.TextColor3 = c end)
		-- per-keybind on/off switch
		b.onBtn = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -114, 0.5, 0), Size = UDim2.new(0, 44, 0, 24),
			BackgroundColor3 = Theme.Off, Text = b.enabled and "ON" or "OFF", Font = Enum.Font.GothamBold,
			TextSize = 11, TextColor3 = b.enabled and Theme.Accent or Theme.Sub, AutoButtonColor = false,
		}, row)
		corner(b.onBtn, 6)
		onAccent(function(c) if b.enabled then b.onBtn.TextColor3 = c end end)
		b.onBtn.MouseButton1Click:Connect(function()
			if b.name == "Toggle Menu" then
				b.enabled = true
				b.onBtn.Text = "ON"
				b.onBtn.TextColor3 = Theme.Accent
				notify("Menu key is locked ON")
				return
			end
			b.enabled = not b.enabled
			b.onBtn.Text = b.enabled and "ON" or "OFF"
			b.onBtn.TextColor3 = b.enabled and Theme.Accent or Theme.Sub
			playUI(b.enabled and 1.5 or 0.85, 0.5)
			persist()
		end)
		b.btn.MouseButton1Click:Connect(function()
			if b.name == "Toggle Menu" then
				notify("Menu key is locked to RightControl")
				return
			end
			if listening then return end
			listening = b
			b.btn.Text = "press a key..."
			playUI(1.3, 0.5)
		end)
	end
	local resetBtn = button(PgSettings, "Reset Keybinds", function()
		for _, b in ipairs(binds) do
			b.key = b.default
			b.btn.Text = b.key and b.key.Name or "None"
			b.enabled = true
			b.onBtn.Text = "ON"
			b.onBtn.TextColor3 = Theme.Accent
		end
		persist()
		notify("Keybinds reset")
	end, 32)
	bind(UIS.InputBegan, function(i, gp)
		if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if listening then
			local b = listening
			listening = nil
			b.key = (i.KeyCode ~= Enum.KeyCode.Escape) and i.KeyCode or nil
			b.btn.Text = b.key and b.key.Name or "None"
			playUI(1.6, 0.5)
			persist()
			return
		end
		if gp then return end
		for _, b in ipairs(binds) do
			if b.key and b.key == i.KeyCode and b.enabled and (S.keybindsOn or b.name == "Toggle Menu") then
				pcall(b.fn)
				playUI(1.4, 0.4)
			end
		end
	end)
end

section(PgSettings, "Scripts")
local scGrid = grid(PgSettings)
local function runRemote(name, url)
	notify("Loading " .. name .. "...")
	local ok, err = pcall(function() loadstring(game:HttpGet(url))() end)
	if not ok then notify(name .. " failed to load") warn(err) end
end
button(scGrid, "Run M7 Admin", function()
	runRemote("M7 Admin", "https://rawscripts.net/raw/Universal-Script-M7-ADMIN-202724")
end)
button(scGrid, "Run Novoline", function()
	runRemote("Novoline", "https://novoline.pro")
end)

section(PgSettings, "Utility")
local VirtualUser = game:GetService("VirtualUser")
bind(LP.Idled, function()
	if S.afk then
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end
end)
toggle(PgSettings, "Anti-AFK", false, function(v) S.afk = v end)
local stGrid = grid(PgSettings)
button(stGrid, "Rejoin Server", function() TeleportService:Teleport(game.PlaceId, LP) end)
button(stGrid, "Server Hop", function()
	notify("Finding a server...")
	local ok, res = pcall(function()
		return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
	end)
	if ok and res and res.data then
		for _, s in ipairs(res.data) do
			if s.id ~= game.JobId and s.playing < s.maxPlayers then
				TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LP)
				return
			end
		end
	end
	notify("No other server found")
end)
local destroyAll
button(stGrid, "Destroy riggnes", function() destroyAll() end)

-- =============================================
-- PLAYER TRACKING
-- =============================================
local function hookPlayer(plr)
	bind(plr.CharacterAdded, function()
		task.wait(0.4)
		applyESP(plr)
		refreshTag(plr)
	end)
end
for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
bind(Players.PlayerAdded, function(p) hookPlayer(p) refreshPlayers() end)
bind(Players.PlayerRemoving, function(p)
	clearESP(p)
	clearTag(p)
	S.tagged[p] = nil
	if S.target == p then
		if S.mode then setMode(S.mode) end
		if S.spec then setSpectate(false) setActive(specBtn, false) end
		selectTarget(nil)
		notify(p.DisplayName .. " left")
	else
		refreshPlayers()
	end
end)
refreshPlayers()

-- =============================================
-- INPUT
-- =============================================
bind(UIS.JumpRequest, function()
	if S.infJump then
		local h = getHum()
		if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end)

bind(UIS.InputBegan, function(i, gp)
	if gp then return end
	if i.KeyCode == Enum.KeyCode.Q and S.dash and tick() - S.lastDash > 0.5 then
		local hrp = getHRP()
		if hrp then
			S.lastDash = tick()
			local l = cam().CFrame.LookVector
			local flat = Vector3.new(l.X, 0, l.Z)
			if flat.Magnitude > 0 then
				hrp.AssemblyLinearVelocity = flat.Unit * 110 + Vector3.new(0, 15, 0)
			end
		end
	end
	if i.UserInputType == Enum.UserInputType.MouseButton1 and S.clickTP and UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
		local hrp = getHRP()
		if hrp then hrp.CFrame = CFrame.new(Mouse.Hit.Position + Vector3.new(0, 3, 0)) end
	end
end)

-- =============================================
-- MAIN LOOPS
-- =============================================
local orb, face, orbStroke
local t0, espTick = 0, 0
bind(RunService.Heartbeat, function(dt)
	t0 += dt
	topGrad.Offset = Vector2.new(math.sin(t0 * 1.2) * 0.5, 0)
	if orbStroke then orbStroke.Thickness = 2.5 + math.sin(t0 * 3) * 1 end
	if face then face.Rotation = (t0 * 120) % 360 end

	local hum, hrp = getHum(), getHRP()
	local typing = UIS:GetFocusedTextBox() ~= nil

	if hum and hrp then
		local voidY = workspace.FallenPartsDestroyHeight + 80
		if hum.FloorMaterial ~= Enum.Material.Air and hrp.Position.Y > voidY + 50 then S.lastSafe = hrp.CFrame end
		if S.antivoid and S.lastSafe and hrp.Position.Y < voidY then
			hrp.AssemblyLinearVelocity = Vector3.new()
			hrp.CFrame = S.lastSafe + Vector3.new(0, 3, 0)
			notify("Anti-Void saved you")
		end
	end

	if S.esp then
		espTick += dt
		if espTick > 0.2 then espTick = 0 updateESPText() end
	end
	if S.hitbox then applyHitboxes() end

	-- triggerbot
	if S.trigger and typeof(mouse1click) == "function" and tick() - S.lastTrig > 0.12 then
		local tgt = Mouse.Target
		local model = tgt and tgt:FindFirstAncestorOfClass("Model")
		local plr = model and Players:GetPlayerFromCharacter(model)
		if plr and plr ~= LP and not (S.teamCheck and LP.Team and plr.Team == LP.Team) then
			local h = model:FindFirstChildOfClass("Humanoid")
			if h and h.Health > 0 then
				S.lastTrig = tick()
				mouse1click()
			end
		end
	end

	if hum then
		if S.walkCustom and hum.WalkSpeed ~= S.walk then hum.WalkSpeed = S.walk end
		if S.jumpCustom then
			if hum.UseJumpPower == false then hum.UseJumpPower = true end
			if hum.JumpPower ~= S.jump then hum.JumpPower = S.jump end
		end
		if S.bhop and not typing and UIS:IsKeyDown(Enum.KeyCode.Space) and hum.FloorMaterial ~= Enum.Material.Air then
			hum.Jump = true
		end
	end
	if not S.fly then S.flyFovAdd += (0 - S.flyFovAdd) * math.min(1, dt * 6) end
	if S.fly or S.flyFovAdd > 0.05 then
		cam().FieldOfView = (S.fovCustom and S.fov or (S.flyBaseFov or 70)) + S.flyFovAdd
	elseif S.fovCustom then
		cam().FieldOfView = S.fov
	end

	-- fly
	if S.fly and hrp and bv and bv.Parent then
		local c = cam()
		local move = Vector3.new()
		if not typing then
			if UIS:IsKeyDown(Enum.KeyCode.W) then move += c.CFrame.LookVector end
			if UIS:IsKeyDown(Enum.KeyCode.S) then move -= c.CFrame.LookVector end
			if UIS:IsKeyDown(Enum.KeyCode.A) then move -= c.CFrame.RightVector end
			if UIS:IsKeyDown(Enum.KeyCode.D) then move += c.CFrame.RightVector end
			if UIS:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0, 1, 0) end
			if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then move -= Vector3.new(0, 1, 0) end
		end
		local boosting = (not typing) and UIS:IsKeyDown(Enum.KeyCode.E)
		if boosting and move.Magnitude == 0 then move = c.CFrame.LookVector end
		if boosting and not S.wasBoost then
			shockwave(hrp.Position, c.CFrame.LookVector)
			pcall(function() playSweep(SoundBank.open, 0.4, 2.2, 0.5, 1.0) end)
			notify("BOOST")
		end
		S.wasBoost = boosting
		local moving = move.Magnitude > 0
		local target = moving and move.Unit * S.flySpeed * (boosting and S.boostMult or 1) or Vector3.new()
		if not moving then target += Vector3.new(0, math.sin(t0 * 2.5) * 2.5, 0) end -- idle hover bob
		bv.Velocity = bv.Velocity:Lerp(target, math.min(1, dt * 7)) -- smooth acceleration
		local vel = bv.Velocity
		local speedFrac = math.clamp(vel.Magnitude / math.max(S.flySpeed, 1), 0, 1.8)

		local look = c.CFrame.LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		if flatLook.Magnitude > 0.01 then S.flyYaw = math.atan2(-look.X, -look.Z) end
		local fwdAmt = math.clamp(vel:Dot(look) / math.max(S.flySpeed, 1), 0, 1)
		local side = math.clamp(vel:Dot(c.CFrame.RightVector) / math.max(S.flySpeed, 1), -1, 1)
		local camPitch = math.asin(math.clamp(look.Y, -1, 1))
		local tPitch = (-math.rad(75) + camPitch) * fwdAmt          -- superman dive pose
		local tRoll = side * math.rad(50)  -- bank into turns (positive = right)
		local k = math.min(1, dt * 8)
		S.flyPitch += (tPitch - S.flyPitch) * k
		S.flyRoll += (tRoll - S.flyRoll) * k
		local rollAng = 0
		if S.rollStart then
			local u = (tick() - S.rollStart) / 0.7
			if u >= 1 then
				S.rollStart = nil
			else
				local e = u < 0.5 and 2 * u * u or 1 - ((-2 * u + 2) ^ 2) / 2  -- ease in/out
				rollAng = e * math.pi * 2
			end
		end
		if bg and bg.Parent then
			local p = fwdAmt
			bg.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, S.flyYaw, 0)
				* CFrame.Angles(0, 0, -S.flyRoll * (1 - p))
				* CFrame.Angles(S.flyPitch, 0, 0)
				* CFrame.Angles(0, S.flyRoll * p + rollAng, 0)
		end

		-- hero pose: fist forward, other arm swept back, legs together with pointed toes
		local js = T.joints
		if js then
			local f = fwdAmt
			local ph = t0 * 3
			local fl = 0.03 + speedFrac * 0.03   -- tiny cloth-like flutter, no leg swinging
			local lk = math.min(1, dt * 10)
			local function pose(name, rot)
				local d = js[name]
				if d and d.motor and d.motor.Parent then d.motor.C0 = d.motor.C0:Lerp(d.c0 * rot, lk) end
			end
			pose("LeftHip", CFrame.Angles(-0.1 * f + math.sin(ph) * fl, 0, 0.02))
			pose("RightHip", CFrame.Angles(-0.1 * f + math.sin(ph + 1.2) * fl, 0, -0.02))
			pose("LeftKnee", CFrame.Angles(-0.1 * f, 0, 0))
			pose("RightKnee", CFrame.Angles(-0.1 * f, 0, 0))
			pose("LeftAnkle", CFrame.Angles(-0.7 * f, 0, 0))
			pose("RightAnkle", CFrame.Angles(-0.7 * f, 0, 0))
			local rArm, lArm = 3.0, -0.15              -- Hero: one fist forward
			if S.flyStyle == "Superman" then rArm, lArm = 3.0, 3.0    -- both arms forward
			elseif S.flyStyle == "Jet" then rArm, lArm = -0.1, -0.1 end -- arms tight at the sides
			pose("RightShoulder", CFrame.Angles(rArm * f + math.sin(ph) * 0.03, 0, -0.3 * (1 - f)))
			pose("LeftShoulder", CFrame.Angles(lArm * f, 0, 0.1 * f + 0.3 * (1 - f)))
			pose("Neck", CFrame.Angles(0.75 * f, 0, 0))
		end

		local fx = T.fx
		if fx then
			fx.trail.Enabled = speedFrac > 0.2
			for _, key in ipairs({"wt_1", "wt_2"}) do if fx[key] then fx[key].Enabled = speedFrac > 0.55 end end
			fx.trail.Lifetime = 0.15 + speedFrac * 0.5
			fx.em.Rate = speedFrac * 70
			if S.rainbow or S.goldFly then
				local col = S.goldFly and OWNER_GOLD or Color3.fromHSV((t0 * 0.4) % 1, 0.8, 1)
				local cs = ColorSequence.new(col)
				fx.trail.Color = cs
				fx.em.Color = cs
				for _, key in ipairs({"wt_1", "wt_2"}) do if fx[key] then fx[key].Color = ColorSequence.new(Color3.new(1, 1, 1), col) end end
			end
		end
		S.flyFovAdd += (speedFrac * 22 - S.flyFovAdd) * math.min(1, dt * 5)  -- speed FOV kick
	end

	-- spin
	if S.spin and not S.mode and hrp then
		hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(S.spinSpeed * dt), 0)
	end

	-- spectate keep-alive
	if S.spec and S.target then
		local tc = S.target.Character
		local th = tc and tc:FindFirstChildOfClass("Humanoid")
		if th and cam().CameraSubject ~= th then cam().CameraSubject = th end
	end

	-- target modes
	local mode = S.mode
	if mode and hrp then
		local tc = S.target and S.target.Character
		local tRoot = tc and tc:FindFirstChild("HumanoidRootPart")
		if not tRoot then return end

		if mode == "sit" then
			local head = tc:FindFirstChild("Head") or tRoot
			hrp.CFrame = head.CFrame * CFrame.new(0, S.headOffset, 0)
			hrp.AssemblyLinearVelocity = Vector3.new()
			hrp.AssemblyAngularVelocity = Vector3.new()
			if hum and not hum.Sit then hum.Sit = true end
		elseif mode == "piggy" then
			hrp.CFrame = tRoot.CFrame * CFrame.new(0, 1.3, 0.9)
			hrp.AssemblyLinearVelocity = Vector3.new()
			hrp.AssemblyAngularVelocity = Vector3.new()
		elseif mode == "follow" then
			local goal = tRoot.CFrame * CFrame.new(0, 0, S.dist)
			hrp.CFrame = hrp.CFrame:Lerp(goal, math.min(1, dt * 10))
			hrp.AssemblyLinearVelocity = Vector3.new()
		elseif mode == "behind" then
			hrp.CFrame = tRoot.CFrame * CFrame.new(0, 0, S.dist)
			hrp.AssemblyLinearVelocity = Vector3.new()
		elseif mode == "orbit" then
			S.orbitAngle += S.orbitSpeed * dt
			local pos = tRoot.Position + Vector3.new(math.cos(S.orbitAngle) * S.orbitRadius, 0, math.sin(S.orbitAngle) * S.orbitRadius)
			hrp.CFrame = CFrame.lookAt(pos, Vector3.new(tRoot.Position.X, pos.Y, tRoot.Position.Z))
			hrp.AssemblyLinearVelocity = Vector3.new()
		elseif mode == "face" then
			local p = hrp.Position
			hrp.CFrame = CFrame.lookAt(p, Vector3.new(tRoot.Position.X, p.Y, tRoot.Position.Z))
		end
	end
end)

bind(RunService.Stepped, function()
	if S.noclip then
		local c = LP.Character
		if c then
			for _, part in ipairs(c:GetDescendants()) do
				if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
			end
		end
	end
end)

bind(LP.CharacterAdded, function()
	task.wait(0.6)
	if S.fly then startFly() end
	if S.spec then setSpectate(true) end
	if S.aura and T.setAura then T.setAura(true) end
end)

-- =============================================
-- OPEN / CLOSE + ORB
-- =============================================
local uiOpen = false
local function openUI()
	uiOpen = true
	Main.Visible = true
	Main.GroupTransparency = 1
	uiScale.Scale = 0.92 * S.uiScale
	pcall(playOpenSound)
	tween(Main, 0.25, {GroupTransparency = 0})
	tween(uiScale, 0.35, {Scale = S.uiScale}, Enum.EasingStyle.Back)
	task.delay(0.5, function()
		if uiOpen then
			Main.Visible = true
			Main.GroupTransparency = 0
			uiScale.Scale = S.uiScale
		end
	end)
end
local function closeUI()
	uiOpen = false
	pcall(playCloseSound)
	tween(Main, 0.2, {GroupTransparency = 1})
	tween(uiScale, 0.2, {Scale = 0.94 * S.uiScale})
	task.delay(0.22, function()
		if not uiOpen then Main.Visible = false end
	end)
end
toggleUI = function()
	if uiOpen then closeUI() else openUI() end
end
CloseBtn.MouseButton1Click:Connect(function() closeUI() end)

-- (menu toggle key is handled by the Keybinds system in Settings)

orb = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.0285, 0, 0.85, 0),
	Size = UDim2.new(0, 46, 0, 46),
	BackgroundColor3 = Theme.Bg, Text = "", AutoButtonColor = false,
}, ScreenGui)
corner(orb, 23)
orbStroke = stroke(orb, Theme.Accent, 2.5, 0)
onAccent(function(c) orbStroke.Color = c end)

face = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(0.74, 0, 0.74, 0), BackgroundTransparency = 1,
}, orb)

local function dot(parent, x, y, w, h, color, round)
	local f = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(x, 0, y, 0),
		Size = UDim2.new(w, 0, h, 0), BackgroundColor3 = color, BorderSizePixel = 0,
	}, parent)
	corner(f, round and 100 or 3)
	return f
end

local fur = Color3.fromRGB(28, 28, 34)
dot(face, 0.06, 0.45, 0.24, 0.24, fur, true)
dot(face, 0.94, 0.45, 0.24, 0.24, fur, true)
dot(face, 0.5, 0.5, 0.86, 0.9, fur, true)
dot(face, 0.5, 0.62, 0.62, 0.52, Color3.fromRGB(120, 92, 76), true)
dot(face, 0.5, 0.33, 0.7, 0.14, fur, false)
local eyeL = dot(face, 0.36, 0.42, 0.11, 0.11, Theme.Accent, true)
local eyeR = dot(face, 0.64, 0.42, 0.11, 0.11, Theme.Accent, true)
onAccent(function(c) eyeL.BackgroundColor3 = c eyeR.BackgroundColor3 = c end)
dot(face, 0.43, 0.6, 0.07, 0.07, fur, true)
dot(face, 0.57, 0.6, 0.07, 0.07, fur, true)
dot(face, 0.5, 0.76, 0.3, 0.05, fur, false)

local orbHit = new("TextButton", {
	Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 10, AutoButtonColor = false,
}, orb)
orbHit.MouseEnter:Connect(function() tween(orb, 0.15, {Size = UDim2.new(0, 54, 0, 54)}) end)
orbHit.MouseLeave:Connect(function() tween(orb, 0.15, {Size = UDim2.new(0, 46, 0, 46)}) end)
orbHit.MouseButton1Click:Connect(toggleUI)

-- =============================================
-- CLEANUP
-- =============================================
destroyAll = function()
	stopFly()
	S.mode = nil
	S.aim = false
	local h = getHum()
	if h then h.Sit = false h.PlatformStand = false end
	setSpectate(false)
	setESP(false)
	setFullbright(false)
	restoreHitboxes()
	pcall(function() RunService:UnbindFromRenderStep("riggnes_aim") end)
	workspace.Gravity = origGravity
	for p in pairs(tags) do clearTag(p) end
	for _, c in ipairs(conns) do c:Disconnect() end
	ScreenGui:Destroy()
end

selectTab(1)
if type(cfg.accent) == "table" and tonumber(cfg.accent[1]) and tonumber(cfg.accent[2]) and tonumber(cfg.accent[3]) then
	setAccent(Color3.fromRGB(cfg.accent[1], cfg.accent[2], cfg.accent[3]))
	if cfg.accentName and colorNameLbl then colorNameLbl.Text = cfg.accentName end
else
	setAccent(Theme.Accent)
end
for _, p in ipairs(Players:GetPlayers()) do refreshTag(p) end
if OWNER_LIST_URL ~= "" then
	task.spawn(function()
		local ok, body = pcall(function() return game:HttpGet(OWNER_LIST_URL) end)
		if ok and type(body) == "string" then
			for line in body:gmatch("[^\r\n]+") do
				local v = line:gsub("%s+", "")
				local id = tonumber(v)
				if id then ownerIdSet[id] = true elseif v ~= "" then ownerSet[string.lower(v)] = true end
			end
			for _, p in ipairs(Players:GetPlayers()) do refreshTag(p) end
		end
	end)
end
]=====]

local introRoot
local function runIntro()
	local skip = false
	local root = new("Frame", {Name = "Intro", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ZIndex = 1000, Active = true}, ScreenGui)
	introRoot = root
	local dim = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1000}, root)
	local stage = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ZIndex = 1001}, root)

	local skipConn = {Disconnect = function() end} -- cutscene can't be skipped
	local allSounds = {}
	local function finish(kill)
		skipConn:Disconnect()
		if kill then for _, sd in ipairs(allSounds) do pcall(function() sd:Stop() sd:Destroy() end) end end
		if root.Parent then root:Destroy() end
		introRoot = nil
	end
	local function wait_(t)
		local c = os.clock()
		while not skip and os.clock() - c < t do RunService.Heartbeat:Wait() end
	end

	-- ---------- sound helpers ----------
	local BOOM = {"rbxasset://sounds/impact_explosion_03.mp3", "rbxassetid://9125402735", "rbxassetid://5801257793"}
	local TICK = {"rbxasset://sounds/switch.mp3", "rbxasset://sounds/clickfast.wav", "rbxasset://sounds/snap.mp3"}
	local function mkSound(list, vol, speed, looped, reverb)
		for _, id in ipairs(list) do
			local sd = new("Sound", {SoundId = id, Volume = vol, PlaybackSpeed = speed, Looped = looped or false}, ScreenGui)
			pcall(function() ContentProvider:PreloadAsync({sd}) end)
			if sd.TimeLength > 0 then
				if reverb then new("ReverbSoundEffect", {DecayTime = 3.5, Density = 1, Diffusion = 1, DryLevel = 0, WetLevel = -2}, sd) end
				table.insert(allSounds, sd)
				if not looped then Debris:AddItem(sd, 12) end
				return sd
			end
			sd:Destroy()
		end
		return nil
	end
	local tickS, rumbleS, boomA, boomB, boomC
	task.spawn(function()
		tickS   = mkSound(TICK, 0.35, 1)
		rumbleS = mkSound(BOOM, 0, 0.2, true, true)
		boomA   = mkSound(BOOM, 10, 0.55, false, true)
		boomB   = mkSound(BOOM, 8, 0.95, false, true)
		boomC   = mkSound(BOOM, 10, 0.3, false, true)
	end)

	local GREEN  = Color3.fromRGB(0, 255, 120)
	local ORANGE = Color3.fromRGB(255, 140, 30)
	local PURPLE = Color3.fromRGB(170, 90, 255)
	local YELLOW = Color3.fromRGB(255, 220, 90)
	local WHITE  = Color3.new(1, 1, 1)

	local function circle(parent, size, z)
		local f = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0, size, 0, size), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = z}, parent)
		new("UICorner", {CornerRadius = UDim.new(0.5, 0)}, f)
		return f
	end

	-- ---------- command window (covers the whole screen) ----------
	local term = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(3, 5, 9), BorderSizePixel = 0,
		ClipsDescendants = true, ZIndex = 1001}, stage)
	local termCorner = new("UICorner", {CornerRadius = UDim.new(0, 0)}, term)
	local termStroke = stroke(term, GREEN, 2, 0)
	local bar = new("Frame", {Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Color3.fromRGB(20, 24, 32), BorderSizePixel = 0, ZIndex = 1004}, term)
	local barTitle = new("TextLabel", {Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0, 12, 0, 0), BackgroundTransparency = 1,
		Text = "C:\\Windows\\System32\\cmd.exe - riggnes", TextColor3 = Color3.fromRGB(190, 200, 220), Font = Enum.Font.Code,
		TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 1005}, bar)
	local out = new("TextLabel", {Position = UDim2.new(0, 14, 0, 36), Size = UDim2.new(1, -28, 1, -44), BackgroundTransparency = 1,
		Text = "", TextColor3 = GREEN, Font = Enum.Font.Code, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Bottom, ZIndex = 1002}, term)

	-- ---------- phase 1: type out ALL of the code ----------
	local lines = {"C:\\riggnes> inject riggnes.lua", "[riggnes] reading source...", ""}
	for ln in (INTRO_CODE .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = (ln:gsub("\t", "  ")) end
	local total = 0
	for _, ln in ipairs(lines) do total += #ln + 1 end

	local maxLines = math.ceil(cam().ViewportSize.Y / 15) + 2
	local li, ci, typed = 1, 0, 0
	local DUR = 8
	local t0 = os.clock()
	local lastTick = 0
	while not skip do
		RunService.Heartbeat:Wait()
		local p = math.clamp((os.clock() - t0) / DUR, 0, 1)
		local target = math.floor(total * p ^ 2.2)
		local n = target - typed
		typed = target
		if n > 0 and tickS and os.clock() - lastTick > 0.045 then
			lastTick = os.clock()
			tickS.PlaybackSpeed = 0.9 + math.random() * 0.9 + p * 0.6
			tickS.Volume = 0.25 + 0.25 * p
			tickS:Play()
		end
		while n > 0 and li <= #lines do
			local rem = #lines[li] - ci
			if n > rem then
				n -= rem + 1
				li += 1
				ci = 0
			else
				ci += n
				n = 0
			end
		end
		local parts = {}
		for k = math.max(1, li - maxLines + 1), math.min(li - 1, #lines) do parts[#parts + 1] = lines[k] end
		if li <= #lines then
			parts[#parts + 1] = lines[li]:sub(1, ci) .. ((os.clock() * 3) % 1 < 0.5 and "_" or "")
		end
		out.Text = table.concat(parts, "\n")
		if li > #lines or p >= 1 then break end
	end
	if skip then return finish(true) end
	wait_(0.35)
	if skip then return finish(true) end

	-- ---------- phase 2: compress into a black hole ----------
	local halo = circle(stage, 260, 1003)
	local haloStroke = new("UIStroke", {Thickness = 2, Color = ORANGE, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, halo)
	local disk = circle(stage, 260, 1003)
	local diskStroke = new("UIStroke", {Thickness = 8, Color = WHITE, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, disk)
	local diskGrad = new("UIGradient", {
		Color = ColorSequence.new({ColorSequenceKeypoint.new(0, ORANGE), ColorSequenceKeypoint.new(0.5, PURPLE), ColorSequenceKeypoint.new(1, ORANGE)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.15), NumberSequenceKeypoint.new(0.75, 0.95), NumberSequenceKeypoint.new(1, 0)}),
	}, diskStroke)

	-- debris being sucked in
	local pulling = true
	local parts = {}
	local function spawnPart(far)
		local f = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, math.random(2, 5), 0, math.random(2, 5)),
			BackgroundColor3 = ({ORANGE, YELLOW, PURPLE, GREEN, WHITE})[math.random(1, 5)], BorderSizePixel = 0, ZIndex = 1002}, stage)
		new("UICorner", {CornerRadius = UDim.new(0.5, 0)}, f)
		local vp = cam().ViewportSize
		return {f = f, a = math.random() * math.pi * 2, r = (far and 0.55 or math.random()) * vp.Magnitude * 0.5 + 40}
	end
	for _ = 1, 45 do parts[#parts + 1] = spawnPart(false) end
	local pullConn = RunService.Heartbeat:Connect(function(dt)
		for _, q in ipairs(parts) do
			q.r -= (q.r * 1.7 + 60) * dt
			q.a += (2.5 + 900 / (q.r + 60)) * dt
			if q.r < 10 then
				if pulling then
					local np = spawnPart(true)
					q.r, q.a = np.r, np.a
					np.f:Destroy()
				else
					q.f.Visible = false
				end
			end
			q.f.Position = UDim2.new(0.5, math.cos(q.a) * q.r, 0.5, math.sin(q.a) * q.r)
		end
	end)

	local COMP = 1.7
	if rumbleS then rumbleS:Play() tween(rumbleS, COMP, {Volume = 1.5}) end
	playSweep(SoundBank.close, 1.8, 0.3, COMP, 1.5)   -- sucked-in whoosh
	if boomC then boomC.Volume = 3 boomC.PlaybackSpeed = 0.2 boomC:Play() end -- deep "thud" as it starts to collapse
	tween(term, COMP, {Size = UDim2.new(0, 150, 0, 150), BackgroundColor3 = Color3.new(0, 0, 0)}, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
	tween(termCorner, COMP * 0.8, {CornerRadius = UDim.new(0.5, 0)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(termStroke, COMP, {Color = ORANGE, Thickness = 3})
	tween(out, 0.6, {TextTransparency = 1})
	tween(bar, 0.4, {BackgroundTransparency = 1})
	tween(barTitle, 0.4, {TextTransparency = 1})
	tween(dim, COMP, {BackgroundTransparency = 0.35})
	tween(diskStroke, COMP, {Transparency = 0.05})
	tween(haloStroke, COMP, {Transparency = 0.6})
	wait_(COMP)

	-- ---------- phase 3: black hole spins up, shakes ----------
	local HOLD = 1.8
	playSweep(SoundBank.open, 0.4, 2.8, HOLD, 1.2)    -- rising riser
	local h0 = os.clock()
	local spin = 0
	while not skip do
		local dt = RunService.Heartbeat:Wait()
		local el = os.clock() - h0
		local k = el / HOLD
		if k >= 1 then break end
		if rumbleS then rumbleS.PlaybackSpeed = 0.2 + 0.5 * k rumbleS.Volume = 1.5 + 2.5 * k end
		spin += dt * (240 + 900 * k)
		diskGrad.Rotation = spin
		local s = 150 + math.sin(el * (10 + 20 * k)) * (4 + 10 * k)
		term.Size = UDim2.new(0, s, 0, s)
		local ds = s * (1.7 + 0.5 * k)
		disk.Size = UDim2.new(0, ds, 0, ds)
		halo.Size = UDim2.new(0, ds * 1.45, 0, ds * 1.45)
		diskStroke.Thickness = 8 + 8 * k
		local amp = 2 + 10 * k
		stage.Position = UDim2.new(0, (math.random() * 2 - 1) * amp, 0, (math.random() * 2 - 1) * amp)
	end
	if skip then pullConn:Disconnect() return finish(true) end

	-- collapse right before the blast
	if rumbleS then rumbleS:Stop() end
	playSweep(SoundBank.close, 2.6, 0.25, 0.4, 1.5)   -- implosion
	tween(term, 0.35, {Size = UDim2.new(0, 30, 0, 30)}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	tween(disk, 0.35, {Size = UDim2.new(0, 40, 0, 40)}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	tween(halo, 0.35, {Size = UDim2.new(0, 60, 0, 60)}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	wait_(0.38)

	-- ---------- phase 4: BOOM ----------
	pulling = false
	pullConn:Disconnect()
	for _, q in ipairs(parts) do q.f:Destroy() end
	term.Visible, disk.Visible, halo.Visible = false, false, false

	local flash = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(1.4, 0, 1.4, 0),
		BackgroundColor3 = WHITE, BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 1100}, root)

	if not uiOpen then openUI() end  -- the script appears underneath the blast
	if boomA then boomA:Play() end
	if boomC then boomC.PlaybackSpeed = 0.3 boomC.Volume = 10 boomC:Play() end
	task.delay(0.10, function() if boomB and not skip then boomB:Play() end end)
	task.delay(0.28, function() if boomA and not skip then local e = mkSound(BOOM, 6, 0.75, false, true) if e then e:Play() end end end)
	playSweep(SoundBank.open, 3, 0.4, 1.3, 1.5)       -- shockwave sweep

	task.spawn(function() -- screen shake
		local N = 40
		for i = 1, N do
			local amp = 30 * (1 - i / N)
			stage.Position = UDim2.new(0, (math.random() * 2 - 1) * amp, 0, (math.random() * 2 - 1) * amp)
			RunService.Heartbeat:Wait()
		end
		stage.Position = UDim2.new(0, 0, 0, 0)
	end)

	-- glowing core
	local core = circle(stage, 40, 1050)
	core.BackgroundTransparency = 0
	core.BackgroundColor3 = YELLOW
	tween(core, 0.9, {Size = UDim2.new(0, 900, 0, 900), BackgroundTransparency = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	-- shockwave rings
	for i, col in ipairs({WHITE, ORANGE, PURPLE}) do
		task.delay((i - 1) * 0.09, function()
			local ring = circle(stage, 20, 1060)
			local rs = new("UIStroke", {Thickness = 10, Color = col, Transparency = 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, ring)
			local big = cam().ViewportSize.Magnitude * 1.6
			tween(ring, 1.1, {Size = UDim2.new(0, big, 0, big)}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			tween(rs, 1.1, {Transparency = 1, Thickness = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			task.delay(1.2, function() ring:Destroy() end)
		end)
	end

	-- flying debris streaks
	local reach = cam().ViewportSize.Magnitude
	for _ = 1, 90 do
		local a = math.random() * math.pi * 2
		local d = reach * (0.35 + math.random() * 0.8)
		local len = math.random(6, 22)
		local f = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, len, 0, math.random(2, 4)),
			Rotation = math.deg(a), BackgroundColor3 = ({ORANGE, YELLOW, PURPLE, WHITE, Theme.Accent})[math.random(1, 5)],
			BorderSizePixel = 0, ZIndex = 1055}, stage)
		local tt = 0.7 + math.random() * 0.8
		tween(f, tt, {Position = UDim2.new(0.5, math.cos(a) * d, 0.5, math.sin(a) * d), BackgroundTransparency = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.delay(tt + 0.1, function() f:Destroy() end)
	end

	-- white-out fades away, revealing the script
	wait_(0.12)
	tween(flash, 1.2, {BackgroundTransparency = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	tween(dim, 1.2, {BackgroundTransparency = 1})
	wait_(1.4)
	finish()
end

task.spawn(function()
	local ok = pcall(runIntro)
	if not ok and introRoot then introRoot:Destroy() end
	if not uiOpen then openUI() end
	notify("riggnes v2.0 loaded on " .. execName .. " — Right Ctrl to toggle")
end)

end, function(e)
	return tostring(e) .. "\n" .. debug.traceback("", 2)
end)

if not __ok then
	warn("[riggnes] FAILED TO LOAD: " .. tostring(__err))
	pcall(function()
		local lp = game:GetService("Players").LocalPlayer
		local pg = lp:WaitForChild("PlayerGui")
		local old = pg:FindFirstChild("riggnes_error")
		if old then old:Destroy() end
		local gui = Instance.new("ScreenGui")
		gui.Name = "riggnes_error"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.Parent = pg
		local box = Instance.new("TextLabel")
		box.AnchorPoint = Vector2.new(0.5, 0.5)
		box.Position = UDim2.new(0.5, 0, 0.5, 0)
		box.Size = UDim2.new(0.7, 0, 0.5, 0)
		box.BackgroundColor3 = Color3.fromRGB(60, 10, 14)
		box.TextColor3 = Color3.fromRGB(255, 220, 220)
		box.Font = Enum.Font.Code
		box.TextSize = 16
		box.TextWrapped = true
		box.TextXAlignment = Enum.TextXAlignment.Left
		box.TextYAlignment = Enum.TextYAlignment.Top
		box.Text = "riggnes failed to load - send this to Claude:\n\n" .. tostring(__err)
		box.Parent = gui
		task.delay(60, function() gui:Destroy() end)
	end)
else
	print("[riggnes] loaded OK")
end