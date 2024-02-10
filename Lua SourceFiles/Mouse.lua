--!nocheck
-- @fattah412

--[[

Mouse:
An alternative for the :GetMouse() function.

-----------------------------------------------------------------------------

Notes:

- If 'StopCreatingEvents' is set to true, functions like :OnButton1Down() would not work 
	> There would be no need to destroy the Mouse object if this is set to true

-----------------------------------------------------------------------------

Usage:

--> Functions:

Cursor.GetMouse(StopCreatingEvents: boolean)
> Description: Creates the mouse object. Returning 'Mouse'
> Returns: Mouse

Mouse:X()
> Description: The X coordinate of the screen
> Returns: number

Mouse:Y()
> Description: The Y coordinate of the screen
> Returns: number

Mouse:XY()
> Description: The X and Y coordinate of the screen
> Returns: Vector2

Mouse:GetTarget(Distance: number?, IgnorePlayer: boolean?)
> Description: Gets the target part that the player clicked on
> Returns: BasePart?

Mouse:GetHitPosition(Distance: number?, IgnorePlayer: boolean?)
> Description: Gets the target part position if any
> Returns: Vector3?

Mouse:SetIcon(Icon: string)
> Description: Sets the mouse cursor icon with the provided one
> Returns: void | nil

Mouse:GetOrigin()
> Description: The origin from the camera to the clicked position
> Returns: CFrame?

Mouse:GetUnitRay()
> Description: The unit ray from the camera
> Returns: Ray?

Mouse:OnMouseMoved(func: (gameProcessed: boolean) -> nil)
> Description: Executes the function when the mouse moves
> Returns: void | nil

| Mouse:OnButton1Down(func: (gameProcessed: boolean) -> nil)
| Mouse:OnButton2Down(func: (gameProcessed: boolean) -> nil)
| Mouse:OnButton3Down(func: (gameProcessed: boolean) -> nil)
> Description: Executes the function when the mouse key is pressed (touch supported for OnButton1Down)
> Returns: void | nil

| Mouse:OnButton1Up(func: (gameProcessed: boolean) -> nil)
| Mouse:OnButton2Up(func: (gameProcessed: boolean) -> nil)
| Mouse:OnButton3Up(func: (gameProcessed: boolean) -> nil)
> Description: Executes the function when the mouse key is released (touch supported for OnButton1Up)
> Returns: void | nil

Mouse:Destroy()
> Description: Destroys the Mouse object, rendering it useless
> Returns: void | nil

-----------------------------------------------------------------------------

Example Usage:

local Cursor = require(script.Mouse)
local Mouse = Cursor.GetMouse()

Mouse:OnButton1Down(function(gameProcessed: boolean) 
	if not gameProcessed then
		local target = Mouse:GetTarget(nil, true)
		print(target or "Target does not exist!")
	end
end)

-----------------------------------------------------------------------------

]]

local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Mouse = {}
Mouse.__index = Mouse

function Mouse.GetMouse(StopCreatingEvents: boolean)
	local self = {}

	if not StopCreatingEvents then
		self._InputConnections = {}
		self._MoveConnection = nil

		self._InputBegan = Instance.new("BindableEvent")
		self._InputEnded = Instance.new("BindableEvent")

		self._InputBeganConnection = UIS.InputBegan:Connect(function(input, gp)
			self._InputBegan:Fire(input, gp)
		end)

		self._InputEndedConnection = UIS.InputEnded:Connect(function(input, gp)
			self._InputEnded:Fire(input, gp)
		end)
	end

	self._CountTable = function()
		local count = 0
		for _, _ in self._InputConnections do
			count += 1
		end
		return count + 1
	end

	return setmetatable(self, Mouse)
end

function Mouse:X(): number
	local mouseLocation = UIS:GetMouseLocation()
	return mouseLocation.X
end

function Mouse:Y(): number
	local mouseLocation = UIS:GetMouseLocation()
	return mouseLocation.Y
end

function Mouse:XY(): Vector2
	local mouseLocation = UIS:GetMouseLocation()
	return mouseLocation
end

function Mouse:GetTarget(Distance: number?, IgnorePlayer: boolean?): BasePart?
	local raycastParams: RaycastParams = IgnorePlayer and RaycastParams.new()
	if raycastParams and player.Character then
		raycastParams:AddToFilter({player.Character})
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	end

	local mouseLocation = UIS:GetMouseLocation()
	local screenToWorldRay = Camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
	local raycastResult = workspace:Raycast(screenToWorldRay.Origin, screenToWorldRay.Direction * (Distance or 1000), raycastParams)

	return raycastResult and raycastResult.Instance:IsA("BasePart") and raycastResult.Instance
end

function Mouse:GetHitPosition(Distance: number?, IgnorePlayer: boolean?): Vector3?
	local raycastParams: RaycastParams = IgnorePlayer and RaycastParams.new()
	if raycastParams and player.Character then
		raycastParams:AddToFilter({player.Character})
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	end

	local mouseLocation = UIS:GetMouseLocation()
	local mouseRay = Camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
	local raycastResult = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * (Distance or 1000), raycastParams)

	return raycastResult and raycastResult.Position
end

function Mouse:SetIcon(Icon: string)
	UIS.MouseIcon = Icon
end

function Mouse:GetOrigin(): CFrame?
	local mouseLocation = UIS:GetMouseLocation()
	local unitRay = Camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)

	return unitRay and CFrame.new(unitRay.Origin, unitRay.Origin + unitRay.Direction)
end

function Mouse:GetUnitRay(): Ray?
	local mouseLocation = UIS:GetMouseLocation()
	local unitRay = Camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)

	return unitRay
end

function Mouse:OnMouseMoved(func: (gameProcessed: boolean) -> nil)
	if not self._MoveConnection then
		self._MoveConnection = UIS.InputChanged:Connect(function(input, gp)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				func(gp)
			end
		end)
	end
end

function Mouse:OnButton1Down(func: (gameProcessed: boolean) -> nil)
	self._InputConnections[self._CountTable()] = self._InputBegan.Event:Connect(function(input: InputObject, gp)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			func(gp)
		end
	end)
end

function Mouse:OnButton1Up(func: (gameProcessed: boolean) -> nil)
	self._InputConnections[self._CountTable()] = self._InputEnded.Event:Connect(function(input: InputObject, gp)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			func(gp)
		end
	end)
end

function Mouse:OnButton2Down(func: (gameProcessed: boolean) -> nil)
	self._InputConnections[self._CountTable()] = self._InputBegan.Event:Connect(function(input: InputObject, gp)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			func(gp)
		end
	end)
end

function Mouse:OnButton2Up(func: (gameProcessed: boolean) -> nil)
	self._InputConnections[self._CountTable()] = self._InputEnded.Event:Connect(function(input: InputObject, gp)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			func(gp)
		end
	end)
end

function Mouse:OnButton3Down(func: (gameProcessed: boolean) -> nil)
	self._InputConnections[self._CountTable()] = self._InputBegan.Event:Connect(function(input: InputObject, gp)
		if input.UserInputType == Enum.UserInputType.MouseButton3 then
			func(gp)
		end
	end)
end

function Mouse:OnButton3Up(func: (gameProcessed: boolean) -> nil)
	self._InputConnections[self._CountTable()] = self._InputEnded.Event:Connect(function(input: InputObject, gp)
		if input.UserInputType == Enum.UserInputType.MouseButton3 then
			func(gp)
		end
	end)
end

function Mouse:Destroy()
	if self._InputBegan then
		self._InputBegan:Destroy()
		self._InputBegan = nil
	end

	if self._InputEnded then
		self._InputEnded:Destroy()
		self._InputEnded = nil
	end

	if self._InputBeganConnection and self._InputBeganConnection.Connected then
		self._InputBeganConnection:Disconnect()
		self._InputBeganConnection = nil
	end

	if self._InputEndedConnection and self._InputEndedConnection.Connected then
		self._InputEndedConnection:Disconnect()
		self._InputEndedConnection = nil
	end

	if self._MoveConnection and self._MoveConnection.Connected then
		self._MoveConnection:Disconnect()
		self._MoveConnection = nil
	end

	if self._InputConnections then
		for i, _ in self._InputConnections do
			self._InputConnections[i]:Disconnect()
			self._InputConnections[i] = nil
		end

		self._InputConnections = nil
	end

	self._CountTable = nil
end

return Mouse