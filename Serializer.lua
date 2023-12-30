-- @fattah412

--[[

Serializer:
This module serializes CFrames and other data types into strings/numbers for tasks such as storing them in Datastores. 
It also supports the deserialization of the serialized content.

---------------------------------------------------------------------------------

Notes:

- Attempting to serialize data types that aren't in the list will result in an error.
- Serialize only actual data types, and deserialize only serialized data.
- This works best with Datastores.

---------------------------------------------------------------------------------

Usage:

--> Functions:

Serializer.Serialize(DataType: any)
> Description: Serializes the data type into a table format
> Returns: SerializedContent: {DataType: string, Data: {}}

Serializer.Deserialize(SerializedData: {DataType: string, Data: {}})
> Description: Deserializes the serialized content and converting it into the original format
> Returns: DataType: any

---------------------------------------------------------------------------------

Example Usage:

local ServerScriptService = game:GetService("ServerScriptService")
local Serializer = require(ServerScriptService:WaitForChild("Serializer"))

local NewPart = Instance.new("Part", workspace)
NewPart.Anchored = true

local MyCFrame = NewPart.CFrame
local SerializedData = Serializer.Serialize(MyCFrame)
local DeserializedData: CFrame = Serializer.Deserialize(SerializedData)

print(DeserializedData, SerializedData)

---------------------------------------------------------------------------------

]]

local Serializer = {}
local Roblox_Data_Types = {
	
	["Vector3"] = function(Action, Data)
		local objectProperties
		if Action == "Start" then
			objectProperties = {}
			objectProperties.Data = {
				Position = {
					X = Data.X, Y = Data.Y, Z = Data.Z	
				};
			}
		elseif Action == "End" then
			local position = Data.Data.Position
			objectProperties = Vector3.new(position.X, position.Y, position.Z)
		end
		return objectProperties
	end,
	
	["Vector2"] = function(Action, Data)
		local objectProperties
		if Action == "Start" then
			objectProperties = {}
			objectProperties.Data = {
				Position = {
					X = Data.X, Y = Data.Y
				}
			}
		elseif Action == "End" then
			local position = Data.Data.Position
			objectProperties = Vector2.new(position.X, position.Y)
		end
		return objectProperties
	end,
	
	["UDim2"] = function(Action, Data)
		local objectProperties
		if Action == "Start" then
			objectProperties = {}
			objectProperties.Data = {
				X = {
					Scale = Data.X.Scale;
					Offset = Data.X.Offset;
				};
				
				Y = {
					Scale = Data.Y.Scale;
					Offset = Data.Y.Offset;
				};
			}
		elseif Action == "End" then
			local X, Y = Data.Data.X, Data.Data.Y
			objectProperties = UDim2.new(X.Scale, X.Offset, Y.Scale, Y.Offset)
		end
		return objectProperties
	end,
	
	["UDim"] = function(Action, Data)
		local objectProperties
		if Action == "Start" then
			objectProperties = {}
			objectProperties.Data = {
				Scale = Data.Scale;
				Offset = Data.Offset;
			}
		elseif Action == "End" then
			local newData = Data.Data
			objectProperties = UDim.new(newData.Scale, newData.Offset)
		end
		return objectProperties
	end,
	
	["CFrame"] = function(Action, Data)
		local objectProperties
		if Action == "Start" then
			objectProperties = {}
			objectProperties.Data = {
				Data:GetComponents()
			}
		elseif Action == "End" then
			objectProperties = CFrame.new(unpack(Data.Data))
		end
		return objectProperties
	end,
	
	["EnumItem"] = function(Action, Data: EnumItem)
		local objectProperties
		if Action == "Start" then
			objectProperties = {}
			objectProperties.Data = {
				StringVersion = tostring(Data)
			}
		elseif Action == "End" then
			local contents = string.split(Data.Data.StringVersion, ".")
			objectProperties = Enum[contents[2]][contents[3]]
		end
		return objectProperties
	end,
	
	["Color3"] = function(Action, Data: Color3)
		local objectProperties
		if Action == "Start" then
			objectProperties = {}
			objectProperties.Data = {
				R = Data.R * 255, G = Data.G * 255, B = Data.B * 255
			}
		elseif Action == "End" then
			local myData = Data.Data
			objectProperties = Color3.fromRGB(myData.R, myData.G, myData.B)
		end
		return objectProperties
	end,
	
	["BrickColor"] = function(Action, Data)
		local objectProperties
		if Action == "Start" then
			objectProperties = {}
			objectProperties.Data = {
				Name = Data.Name
			}
		elseif Action == "End" then
			objectProperties = BrickColor.new(Data.Data.Name)
		end
		return objectProperties
	end,
		
}

function Serializer.Serialize(dataType: any)
	local type = typeof(dataType)
	if not Roblox_Data_Types[type] then
		return error(type.." is not in the table!")
	end
	
	local serializedData = Roblox_Data_Types[type]("Start", dataType)
	if serializedData then
		serializedData["DataType"] = type
		return serializedData
	end
end

function Serializer.Deserialize(serializedData: {})
	if typeof(serializedData) ~= "table" then return error("Serialized data isn't a table!") end
	if not serializedData.DataType or not Roblox_Data_Types[serializedData.DataType] then 
		return error("DataType can't be found!") 
	end
	
	local deSerializedData = Roblox_Data_Types[serializedData.DataType]("End", serializedData)
	return deSerializedData
end

return Serializer