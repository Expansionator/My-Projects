--!nocheck
-- @fattah412

--[[

MouseHover:
An alternative to Gui.MouseEnter, Gui.MouseLeave and Gui.MouseMoved.

-----------------------------------------

Notes:

- All callback functions yield when reinvoking events
- :OnMouseMove() runs only when the mouse has entered the Gui object
- 'ExcludeActiveObjects' if set to true, will ignore all Gui objects that are active such as a TextButton and Functions will not execute if the game is currently being processed (such as Chat)
- 'HandleSuddenTouchLoss' if set to true, will call all cached callbacks that used the function :OnMouseLeave() when the user stops touching a Gui object while in the hovering state
- This module only works with touch-enabled and/or mouse-enabled devices

-----------------------------------------

Usage:
--> Functions

MouseHover.Listen(GuiObject: GuiBase2d, ExcludeActiveObjects: boolean?, HandleSuddenTouchLoss: boolean?)
> Description: Constructs the main handler which consists of events and functions
> Returns: Mouse: {@metatable}

Mouse:OnMouseEnter(Callback: (x: number, y: number) -> nil): ScriptConnection
> Description: Executes when the mouse has entered the Gui element
> Returns: ScriptConnection: {:Disconnect()}

Mouse:OnMouseLeave(Callback: (x: number, y: number) -> nil): ScriptConnection
> Description: Executes when the mouse has left the Gui element
> Returns: ScriptConnection: {:Disconnect()}

Mouse:OnMouseMove(Callback: (x: number, y: number) -> nil): ScriptConnection
> Description: Executes when the mouse is moving within the Gui element
> Returns: ScriptConnection: {:Disconnect()}

Mouse:StopListening()
> Description: Stops all events and clears all cached data; rendering the constructor unusable
> Returns: nil | void

-----------------------------------------

Example Usage:

local MouseHover = require(game.ReplicatedStorage.MouseHover)
local ScreenGui = script.Parent

local Button: TextButton = ScreenGui.Frame.Button
local Listener = MouseHover.Listen(Button)

local Template = Instance.new("Frame", ScreenGui)
Template.Size = UDim2.fromScale(0.01, 0.025)
Template.BackgroundColor3 = Color3.fromRGB(130, 255, 130)
Template.AnchorPoint = Vector2.new(0.5, 0.5)
Template.Visible = false

Listener:OnMouseEnter(function(x: number, y: number): nil 
	print('Mouse entered!', ("X: %i | Y: %i"):format(x, y))
	Template.Visible = true
end)

Listener:OnMouseLeave(function(x: number, y: number): nil 
	print('Mouse left!', ("X: %i | Y: %i"):format(x, y))
	Template.Visible = false
end)

Listener:OnMouseMove(function(x: number, y: number): nil 
	Template.Position = UDim2.fromOffset(x, y)	
end)

-----------------------------------------

]]

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

assert(RunService:IsClient(), "Module cannot be ran on the server!")

local Signal --> Imported from my Signal V2 Module
do
	Signal = {__data = {registered = {}}}
	Signal.__index = Signal

	local Connection
	do
		Connection = {}
		Connection.__index = Connection

		function Connection.new(cb, cb2)
			return setmetatable({
				__data = {
					destroyed = false;
					callback = cb;
					callback2 = cb2;
				};
			}, Connection)
		end

		function Connection:Disconnect()
			if not self or not self.__data or self.__data.destroyed then 
				return 
			end

			local activeThread = self.__data.callback2
			self.__data.destroyed = true

			table.clear(self)
			activeThread()
		end
	end

	function Signal.Create()
		local self 
		self = {
			Environment = (RunService:IsServer() and "Server") or (RunService:IsClient() and "Client");
			WaitUntilFinished = false;
			Destroyed = false;

			__data = {
				funcIndex = 0; waitIndex = 0;
				getIndex = function(method)
					self.__data[method.."Index"] += 1
					return self.__data[method.."Index"]
				end;

				functions = {};
				activeThreads = {};
			}
		}

		return setmetatable(self, Signal)
	end

	function Signal:Connect(Callback: () -> nil)
		if self.Destroyed then return end
		local index = self.__data.getIndex("func")

		if typeof(Callback) == "function" then
			local conn = Connection.new(Callback, function()
				self.__data.functions[index] = nil
			end)

			self.__data.functions[index] = conn
			return conn
		end
	end

	function Signal:Once(Callback: () -> nil)
		if self.Destroyed then return end

		local conn
		conn = self:Connect(function(...)
			conn:Disconnect()
			Callback(...)
		end)

		return conn
	end

	function Signal:Wait(Timeout: number?): number
		if self.Destroyed then return end

		local thread, t = coroutine.running(), os.clock()
		local conn
		conn = self:Connect(function()
			conn:Disconnect()
			coroutine.resume(thread)
		end)

		local scheduler: thread
		if Timeout and typeof(Timeout) == "number" then
			scheduler = coroutine.create(function()
				task.wait(Timeout)
				if coroutine.status(thread) == "suspended" then
					coroutine.resume(thread)
					conn:Disconnect()
				end
			end)
			coroutine.resume(scheduler)
		end

		local index = self.__data.getIndex("wait")
		self.__data.activeThreads[index] = thread

		coroutine.yield() self.__data.activeThreads[index] = nil	
		if scheduler and (coroutine.status(scheduler) == "running" or coroutine.status(scheduler) == "suspended") then
			coroutine.close(scheduler) 
		end

		return os.clock() - t
	end

	function Signal:Fire(...: any)
		if self.Destroyed then return end
		for _, callback in self.__data.functions do
			local thread = callback.__data.callback

			if self.WaitUntilFinished then
				thread(...) continue
			end
			task.spawn(thread, ...)
		end
	end

	function Signal:DisconnectAll()
		if self.Destroyed then return end
		for index, _ in self.__data.functions do
			self.__data.functions[index] = nil
		end
	end

	function Signal:Destroy()
		if self.Destroyed then return end
		self:DisconnectAll()

		for _, thread in self.__data.activeThreads do
			if coroutine.status(thread) == "suspended" then
				coroutine.resume(thread)
			end
		end

		table.clear(self)
		self.Destroyed = true
	end
end

local MouseHover = {}
MouseHover.__index = MouseHover

export type ScriptConnection = {
	Disconnect: () -> nil
}

local player: Player = Players.LocalPlayer
local guiOffset: Vector2 = GuiService:GetGuiInset()

local function getMousePosition(): Vector2
	local mousePosition = UserInputService:GetMouseLocation()
	local offsetPosition = Vector2.new(mousePosition.X, mousePosition.Y - guiOffset.Y)

	return offsetPosition
end

local function isMouseHoveringObject(gui: GuiObject, pos: Vector2): boolean
	local playerGui: PlayerGui = player.PlayerGui
	local guisAtPosition: {Instance} = playerGui:GetGuiObjectsAtPosition(pos.X, pos.Y)

	for _, guiObject in guisAtPosition do
		if guiObject == gui then
			return true
		end
	end
	return false
end

local function isDeviceCompatible(): boolean
	if UserInputService.TouchEnabled or UserInputService.MouseEnabled then
		return true
	end
end

function MouseHover.Listen(GuiObject: GuiBase2d, ExcludeActiveObjects: boolean?, HandleSuddenTouchLoss: boolean?)	
	local self = {
		obj = GuiObject;
		exclude = ExcludeActiveObjects;
		loss = HandleSuddenTouchLoss;

		isHovering = false;

		mouseEnter = Signal.Create();
		mouseLeave = Signal.Create();
		mouseMove = Signal.Create();

		connections = {};
	}

	self.mouseEnter.WaitUntilFinished = true
	self.mouseLeave.WaitUntilFinished = true
	self.mouseMove.WaitUntilFinished = true

	self.onMouseHovering = function(mousePosition: Vector2)
		if self.isHovering then return end
		self.isHovering = true
		self.mouseEnter:Fire(mousePosition.X, mousePosition.Y)
	end

	self.onMouseStopHovering = function(mousePosition: Vector2)
		if not self.isHovering then return end
		self.isHovering = false
		self.mouseLeave:Fire(mousePosition.X, mousePosition.Y)
	end

	if UserInputService.MouseEnabled then
		self.connections["Mouse"] = UserInputService.InputChanged:Connect(function(input, gp)
			if not isDeviceCompatible() then return end
			if self.exclude and gp then
				return
			end

			if input.UserInputType == Enum.UserInputType.MouseMovement then
				local mousePosition = getMousePosition()
				if isMouseHoveringObject(self.obj, mousePosition) then
					self.onMouseHovering(mousePosition)
					return self.mouseMove:Fire(mousePosition.X, mousePosition.Y)
				end
				self.onMouseStopHovering(mousePosition)
			end
		end)
	end

	if UserInputService.TouchEnabled then
		self.connections["Touch"] = UserInputService.TouchMoved:Connect(function(touch, gp)
			if not isDeviceCompatible() then return end
			if self.exclude and gp then
				return
			end

			local mousePosition = getMousePosition()
			if isMouseHoveringObject(self.obj, mousePosition) then
				self.onMouseHovering(mousePosition)
				return self.mouseMove:Fire(mousePosition.X, mousePosition.Y)
			end
			self.onMouseStopHovering(mousePosition)
		end)

		if self.loss then
			self.connections["TouchEnded"] = UserInputService.TouchEnded:Connect(function(input, gp)
				if not isDeviceCompatible() then return end
				if self.exclude and gp then
					return
				end

				local mousePosition = getMousePosition()
				if isMouseHoveringObject(self.obj, mousePosition) then
					self.onMouseStopHovering(mousePosition)
				end
			end)
		end
	end

	return setmetatable({__data = self}, MouseHover)
end

function MouseHover:OnMouseEnter(Callback: (x: number, y: number) -> nil): ScriptConnection
	if not self.__data then return end
	local connection = self.__data.mouseEnter:Connect(Callback)
	return connection
end

function MouseHover:OnMouseLeave(Callback: (x: number, y: number) -> nil): ScriptConnection
	if not self.__data then return end
	local connection = self.__data.mouseLeave:Connect(Callback)
	return connection
end

function MouseHover:OnMouseMove(Callback: (x: number, y: number) -> nil): ScriptConnection
	if not self.__data then return end
	local connection = self.__data.mouseMove:Connect(Callback)
	return connection
end

function MouseHover:StopListening()
	if not self.__data then return end

	self.__data.mouseEnter:DisconnectAll()
	self.__data.mouseLeave:DisconnectAll()
	self.__data.mouseMove:DisconnectAll()

	self.__data.mouseEnter:Destroy()
	self.__data.mouseLeave:Destroy()
	self.__data.mouseMove:Destroy()

	for index, _ in self.__data.connections do
		self.__data.connections[index]:Disconnect()
		self.__data.connections[index] = nil
	end

	table.clear(self.__data)
	self.__data = nil
end

return MouseHover