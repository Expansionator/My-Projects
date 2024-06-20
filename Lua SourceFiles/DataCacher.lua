--!nocheck
-- @fattah412

--[[

DataCacher:
A datastore extension module that behaves similarly to a normal datastore.

------------------------------------------------------

Notes:

- This system caches the player's data into a table which can be easily modified
- Tables that are returned from Listeners will be a duplicate and is meant to be viewed only
- Listeners can return different types of values
- If 'AllowClientSideToRead' is true, you have to invoke the RemoteFunction that is located inside ReplicatedStorage to retrieve the client data
- If 'ViewRawData' is true, you cannot modify that data
- You can only migrate/import ('MigratedData') new data if it had not been saved

------------------------------------------------------

PS:

- I didn't add Session Locking as the idea of it is relatively stupid

------------------------------------------------------

Usage:

--> Functions:

DataCacher.CreateDatastore(DatastoreKey: string, DatastoreOptions: DatastoreOptions?)
> Description: Creates and Registers a datastore object
> Returns: Datastore: {@metatable}

DataCacher.GetRegisteredDatastore(DatastoreKey: string, Timeout: number?)
> Description: Gets a registered datastore, with all raw table-sets (self)
> Returns: Datastore: {@metatable}

Datastore:Load(player: Player, MigratedData: {}?): {}
> Description: Loads the player's data, with an option to use an existing data as a 'template'
> Returns: Data: {}

Datastore:Save(player: Player, Callback: (data: {}, oldData: {}) -> nil?, AutoSaving: boolean?): boolean
> Description: Saves the player's data using UpdateAsync, with an option to configure what it should save
> Returns: Success: boolean

Datastore:Get(player: Player, ViewRawData: boolean?): {}
> Description: Gets the player's cached data, or if 'ViewRawData' is true, returns a duplicate of the raw data
> Returns: Data: {} | Raw Data: {}

Datastore:GetDataOffline(UserId: number): {}
> Description: Returns a duplicate of the player's saved data (if any), which can be saved (offline) later
> Returns: Data: {}

Datastore:SaveDataOffline(UserId: number, Data: {}): boolean
> Description: Saves the provided data using SetAsync, preferably data from GetDataOffline() 
> Returns: Success: boolean

Datastore:Wipe(player: Player)
> Description: Clears the player's data and replacing it with a fresh one, and using the method SetAsync to overwrite the player's data
> Returns: nil | void

Datastore:View(player: Player)
> Description: Prints the contents within the player's data
> Returns: nil | void

Datastore:GetListener(ListenerType: Listeners, Callback: (player: Player, ...any) -> nil)
> Description: Listens to when the player's data is added, modified or removed
> Returns: nil | void
> Methods [Listener Type]: Changed | Loaded | Released | Wiped

Datastore:RemoveListener(ListenerType: Listeners)
> Description: Stops listening to an existing active listener
> Returns: nil | void
> Methods [Listener Type]: Changed | Loaded | Released | Wiped

Datastore:ClearListeners()
> Description: Similar to RemoveListener(), except that it's for all listener types
> Returns: nil | void

Datastore:GetDataSizeInBytes(player: Player): (number, boolean)
> Description: Checks whether if the player's raw data is within the size range (4 MB)
> Returns: Size: number (In Bytes), boolean

------------------------------------------------------

Example Usage:

local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local DataCacher = require(ServerScriptService.DataCacher)

local TemplateData = {
	Coins = 0;
	Str = "Value";
	Temp = {
		["Cool"] = "My Data"
	}
}

local DatastoreOptions = {
	CreateListeners = true;
	TemplateData = TemplateData;
}

local DatastoreKey = "Coins"
local Datastore = DataCacher.CreateDatastore(DatastoreKey, DatastoreOptions)

Players.PlayerAdded:Connect(function(player)
	local data = Datastore:Load(player)
	if data then
		local rawData = Datastore:Get(player, true)
		print('Data Loaded! - Version: '..(rawData and rawData.Version or "?"))
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local success = Datastore:Save(player)
	if success then
		print('Data Saved!')
	end
end)

local unusedTable = {}
Datastore:GetListener("Changed", function(player: Player, oldData: {}, newData: {})
	table.insert(unusedTable, 
		"Data changed!".." Old: "..oldData.Coins.." | New: "..newData.Coins)
	
	if #unusedTable % 30 == 0 then
		print('Data has reached '..newData.Coins..' coins!')
	end
end)

Datastore:GetListener("Loaded", function(player: Player, newData: {})
	print(player.Name.."'s data has been loaded!", newData)
end)

Datastore:GetListener("Released", function(player: Player)
	print(player.Name.."'s data has now been removed!")
end)

while true do
	for _, player: Player in Players:GetPlayers() do
		local data = Datastore:Get(player)
		if data then
			data.Coins += 1
		end
	end
	
	task.wait(1)
end

------------------------------------------------------

]]

local print = function(...) local vargs = "" for _, arg in {...} do 
		if typeof(arg) == "table" then print(script.Name.." [Table]:", arg) else vargs = vargs..tostring(arg).." " end end if vargs ~= "" then return print(script.Name..": "..vargs)
	end
end

local warn = function(...) local vargs = "" for _, arg in {...} do 
		if typeof(arg) == "table" then warn(script.Name.." [Table]:", arg) else vargs = vargs..tostring(arg).." " end end if vargs ~= "" then return print(script.Name..": "..vargs)
	end
end

local error = function(...) local vargs = "" for _, arg in {...} do 
		if typeof(arg) == "table" then error(script.Name.." [Table]:", arg) else vargs = vargs..tostring(arg).." " end end if vargs ~= "" then return print(script.Name..": "..vargs)
	end
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DatastoreService = game:GetService("DataStoreService")
local TextService = game:GetService("TextService")
local HTTPService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local DataCacher = {}
DataCacher.__index = DataCacher

--------------------------------------

--// The total decimal places to round for
local DECIMAL_PLACES: number = 3

--// Uses this string if the text fails to filter
local FILTERED_RESULT: string = "###?"

--------------------------------------

local TemplateOptions = {
	--// The key used to save the player's data (%i is the player's userid)
	Key = "Player_%i";

	--// The default data assigned to the player
	TemplateData = {};

	--// Creates a signal that are tasked to listen to when data is modified, loaded or released
	CreateListeners = false;

	--// Pauses the current thread if the 'GET' or 'UPDATE' asynchronous calls exceeds the limit (60 + numOfPlayers * 10)
	ThrottleRequests = false;

	--// Compresses/Rounds floating point numbers (like 3.142) to the nearest ('x') decimal places
	CompressFloatNumbers = false;

	--// Auto saves the player's data every few minutes (used to prevent data loss)
	AutoSaving = false;

	--// The duration (in minutes) for the auto save to occur (number must be >= 1)
	AutoSavingDuration = 5;

	--// Filters out the strings that are in the player's data when it is loaded
	FilterStringContent = false;

	--// Filtering Options for 'FilterStringContent'
	FilterStringContentOptions = {
		--// Allows only certain string indexes to be filtered
		WhiteListEnabled = false;

		--// Allows it to filter every string indexes except the ones that are mentioned in the list
		BlackListEnabled = false;

		--// The list (array of strings) for WhiteList/BlackList
		StringIndexList = {};
	};

	--// Creates a RemoteFunction to allow clients to *read* their *own* data
	AllowClientSideToRead = false;

	--// The name for the RemoteEvent ('AllowClientSideToRead')
	ClientSideAgent = "DataCacherRemote";

	--// If true, data will be saved inside Roblox Studio
	SaveInStudio = false;

	--// If data fails to save/load, it will retry for a specified amount of attempts before it is considered to be a failure
	RecursiveCalls = true;

	--// The amount of attempts to save/load data ('RecursiveCalls')
	CallAttempts = 5;

	--// The delay between each saving/loading attempt
	RetryCallDelay = 1;
}

export type Listeners = "Changed" | "Loaded" | "Released" | "Wiped"
export type DatastoreOptions = {
	Key: string?;
	ClientSideAgent: string?;

	TemplateData: {}?;

	CreateListeners: boolean?;
	ThrottleRequests: boolean?;
	CompressFloatNumbers: boolean?;
	AutoSaving: boolean?;
	AutoSavingDuration: number?;
	FilterStringContent: boolean?;
	AllowClientSideToRead: boolean?;
	SaveInStudio: boolean?;
	RecursiveCalls: boolean?;

	FilterStringContentOptions: {
		WhiteListEnabled: boolean?;
		BlackListEnabled: boolean?;

		StringIndexList: {}?;
	}?;

	CallAttempts: number?;
	RetryCallDelay: number?;
}

if RunService:IsClient() then
	return error("Module cannot be required by the client!")
end

local Globals
do
	Globals = {
		ClientRemote = nil;
		RegisteredDataStores = {};
	}

	local decimal_place = DECIMAL_PLACES
	if decimal_place > 0 then
		local fp_numbers = string.rep("0", decimal_place - 1).."1"
		local total_decimal_places = tonumber("0."..fp_numbers)

		Globals.DecimalPlace = total_decimal_places
	end

	Globals.New = function(className: string, objectProperties: {})
		local object = Instance.new(className)
		if objectProperties then
			for propertyName, propertyValue in objectProperties do
				object[propertyName] = propertyValue
			end
		end
		return object
	end

	Globals.Reconcile = function(tab: {}, template: {})
		local function reconcileTable(t, tt)
			local reconciledTable = Globals.Duplicate(tt)
			for index, value in t do
				if reconciledTable[index] ~= nil then
					if typeof(value) == "table" then
						reconciledTable[index] = reconcileTable(value, reconciledTable[index])
					else
						reconciledTable[index] = value
					end
				else
					reconciledTable[index] = value
				end
			end
			return reconciledTable
		end

		local reconciledTable = reconcileTable(tab, template)
		return reconciledTable
	end

	Globals.Duplicate = function(t: {})
		local newTable = {}
		for index, value in t do
			if typeof(value) == "table" then
				value = Globals.Duplicate(value)
			end
			newTable[index] = value
		end
		return newTable
	end

	Globals.CountDictionary = function(t: {})
		local index = 0
		for _, _ in t do
			index += 1
		end
		return index
	end

	Globals.IsTableIdentical = function(old: {}, new: {})
		if Globals.CountDictionary(old) ~= Globals.CountDictionary(new) then
			return false
		end

		for key, value in old do
			if type(value) == "table" then
				if not Globals.IsTableIdentical(value, new[key]) then
					return false
				end
			elseif new[key] ~= value then
				return false
			end
		end

		return true
	end

	Globals.FilterText = function(player: Player, text: string)
		local success, result = pcall(function()
			local str_result = TextService:FilterStringAsync(text, player.UserId)
			local filtered_text = str_result:GetNonChatStringForBroadcastAsync()
			return filtered_text
		end)
		return success and result or FILTERED_RESULT
	end
end

local Signal
do
	Signal = {
		signal_stored_connections = {};
	}

	Signal.Connect = function(agent, callback)
		if not Signal.signal_stored_connections[agent] then
			Signal.signal_stored_connections[agent] = {
				connection = function(...)
					task.spawn(callback, ...)
				end,
			}
		end
	end

	Signal.Fire = function(agent, ...)
		if Signal.signal_stored_connections[agent] then
			Signal.signal_stored_connections[agent].connection(...)
		end
	end

	Signal.Disconnect = function(agent)
		if Signal.signal_stored_connections[agent] then
			Signal.signal_stored_connections[agent] = nil
		end
	end
end

local function getPlayerKey(player, key)
	return key:format(typeof(player) == "Instance" and player.UserId or player)
end

local function handleNestedTableWithOperation(t, callback)
	local function iterateTable(tab)
		for index, value in tab do
			if typeof(value) == "table" then
				iterateTable(value)
				continue
			end
			callback(index, value)
		end
	end
	iterateTable(t)
end

local function loopTableWithValuesAsDefault(t, callback)
	local newTable = {}
	for index, value in t do
		if typeof(value) == "table" then
			value = loopTableWithValuesAsDefault(value, callback)
		else
			value = callback and callback(value, index) or value
		end
		newTable[index] = value
	end
	return newTable
end

local function checkForArguments(options: DatastoreOptions)
	if options.AutoSaving and options.AutoSavingDuration < 1 then
		return error("AutoSavingDuration cannot be less than 1 minute!")
	end

	if options.RecursiveCalls then
		if options.CallAttempts < 1 then
			return error("CallAttempts cannot be less than 1 attempt(s)!")
		else
			local totalDuration = options.RetryCallDelay * options.CallAttempts
			if totalDuration >= 30 then
				return error("CallAttempts exceeded more than 29 seconds!")
			end
		end
	end
end

local function getRequestsLimit()
	return 60 + #Players:GetPlayers() * 10
end

function DataCacher.CreateDatastore(DatastoreKey: string, DatastoreOptions: DatastoreOptions?)
	if Globals.RegisteredDataStores[DatastoreKey] then
		return
	end

	local options = Globals.Duplicate(DatastoreOptions or {})
	options = Globals.Reconcile(options, TemplateOptions)

	checkForArguments(options)

	if options.AllowClientSideToRead then
		if not Globals.ClientRemote then
			local RemoteFunction: RemoteFunction = Globals.New("RemoteFunction", {
				Parent = ReplicatedStorage,
				Name = options.ClientSideAgent
			})

			Globals.ClientRemote = {
				Event = RemoteFunction,
				Registered = {};
			}

			RemoteFunction.OnServerInvoke = function(player: Player, key: string)
				if typeof(key) ~= "string" then return end
				if Globals.ClientRemote.Registered[key] then
					local datastore = DataCacher.GetRegisteredDatastore(key, 1)
					if datastore then
						local data = datastore:Get(player)
						local dupeTable = data and Globals.Duplicate(data)
						return dupeTable
					end
				end
			end
		end

		if not Globals.ClientRemote.Registered[DatastoreKey] then
			Globals.ClientRemote.Registered[DatastoreKey] = DatastoreKey
		end
	end

	local self = {
		__raw = {
			name = DatastoreKey,
			options = options,

			playerData = {},
			events = {},
			changed = {},
			auto_save = {},
			requests = {},

			datastore = DatastoreService:GetDataStore(DatastoreKey),
		},
	}

	self.__raw.waitForThrottle = function(method)
		if options.ThrottleRequests then
			if not self.__raw.requests[method] then
				self.__raw.requests[method] = {
					requests = 1;
					timer = task.spawn(function()
						task.wait(1 * 60) while true do
							self.__raw.requests[method].requests = 0
							task.wait(1 * 60)
						end
					end)
				}
			else
				self.__raw.requests[method].requests += 1
				if self.__raw.requests[method].requests > getRequestsLimit() then
					repeat RunService.Heartbeat:Wait()
					until self.__raw.requests[method].requests <= getRequestsLimit()
				end
			end
		end
	end

	self.__raw.fire = function(Listener, ...)
		if self.__raw.events[Listener] then
			local vargs, args = {}, {...}
			for index = 1, #args do
				local value = args[index]
				if value ~= nil then
					if typeof(value) == "table" then
						local dupe = Globals.Duplicate(value)
						table.insert(vargs, dupe)
					else
						table.insert(vargs, value)
					end
				end
			end

			Signal.Fire(Listener, table.unpack(vargs, 1, #vargs))
		end
	end

	self.__raw.addChangeSpeaker = function(player: Player)
		if options.CreateListeners and self.__raw.events["Changed"] then
			if self.__raw.playerData[player] and not self.__raw.changed[player] then
				local previousData = Globals.Duplicate(self.__raw.playerData[player].data)
				self.__raw.changed[player] = RunService.Heartbeat:Connect(function()
					local newData = self.__raw.playerData[player]
					newData = newData and newData.data

					if newData and not Globals.IsTableIdentical(previousData, newData) then
						self.__raw.fire("Changed", player, previousData, newData)
						previousData = Globals.Duplicate(newData)
					end
				end)
			end
		end
	end

	local Datastore = setmetatable(self, DataCacher)
	Globals.RegisteredDataStores[DatastoreKey] = Datastore

	return Datastore
end

function DataCacher.GetRegisteredDatastore(DatastoreKey: string, Timeout: number?)
	if not Globals.RegisteredDataStores[DatastoreKey] then
		local timeNow = os.time()
		Timeout = Timeout or math.huge

		repeat
			local tab = Globals.RegisteredDataStores[DatastoreKey]
			RunService.Heartbeat:Wait()
		until tab or (os.time() - timeNow) >= Timeout
	end

	return Globals.RegisteredDataStores[DatastoreKey]
end

function DataCacher:Load(player: Player, MigratedData: {}?): {}
	if self.__raw.playerData[player] then
		return
	end

	local key = getPlayerKey(player, self.__raw.options.Key)
	local function UpdateAsynchronous()
		local success, result = pcall(function()
			self.__raw.waitForThrottle("GET")
			return self.__raw.datastore:GetAsync(key)
		end)
		return success, result
	end

	local success, result = UpdateAsynchronous()
	if self.__raw.options.RecursiveCalls and not success then
		for _ = 1, self.__raw.options.CallAttempts do
			success, result = UpdateAsynchronous()
			if success then 
				break 
			end

			task.wait(self.__raw.options.RetryCallDelay)
		end
	end

	if result and result.data then
		local data = self.__raw.options.FilterStringContent and loopTableWithValuesAsDefault(result.data, function(value, index)
			if typeof(index) == "string" and typeof(value) == "string" then
				local filteringOptions = self.__raw.options.FilterStringContentOptions
				if filteringOptions.WhiteListEnabled then
					if table.find(filteringOptions.StringIndexList, index) then
						return Globals.FilterText(player, value)
					end
				elseif filteringOptions.BlackListEnabled then
					if not table.find(filteringOptions.StringIndexList, index) then
						return Globals.FilterText(player, value)
					end
				else
					return Globals.FilterText(player, value)
				end
			end
			return value
		end) or result.data

		result.data = Globals.Reconcile(data, self.__raw.options.TemplateData)
	end

	local existing_data
	if MigratedData and typeof(MigratedData) == "table" then
		existing_data = Globals.Reconcile(MigratedData, self.__raw.options.TemplateData)
	end

	self.__raw.playerData[player] = result or {data = existing_data or self.__raw.options.TemplateData}
	self.__raw.playerData[player]["LastJoined"] = os.time()

	self.__raw.addChangeSpeaker(player)

	if self.__raw.options.AutoSaving and not self.__raw.auto_save[player] then
		self.__raw.auto_save[player] = task.spawn(function()
			local auto_saving_duration = self.__raw.options.AutoSavingDuration * 60
			task.wait(auto_saving_duration)

			while player and player:IsDescendantOf(game) do				
				self:Save(player, nil, true)
				task.wait(auto_saving_duration)
			end
		end)
	end

	self.__raw.fire("Loaded", player, self.__raw.playerData[player]["data"])
	return self.__raw.playerData[player]["data"]
end

function DataCacher:Save(player: Player, Callback: (data: {}, oldData: {}) -> nil?, AutoSaving: boolean?): boolean
	if not self.__raw.playerData[player] then
		return
	end

	local key = getPlayerKey(player, self.__raw.options.Key)
	local data = Globals.Duplicate(self.__raw.playerData[player])

	data["LastLeft"] = not AutoSaving and os.time() or data["LastLeft"]
	data["Version"] = data.Version or 1

	if self.__raw.options.CompressFloatNumbers then
		data = loopTableWithValuesAsDefault(data, function(value)
			if typeof(value) == "number" then
				return math.floor(value / Globals.DecimalPlace) * Globals.DecimalPlace
			end
			return value
		end)
	end

	if not AutoSaving then	
		self.__raw.playerData[player] = nil
		if self.__raw.changed[player] then
			self.__raw.changed[player]:Disconnect()
			self.__raw.changed[player] = nil
		end

		if self.__raw.auto_save[player] then
			task.cancel(self.__raw.auto_save[player])
			self.__raw.auto_save[player] = nil
		end
	end

	local function UpdateAsynchronous()
		local success, err = pcall(function()
			if RunService:IsStudio() and not self.__raw.options.SaveInStudio then
				return
			end

			self.__raw.waitForThrottle("UPDATE")
			self.__raw.datastore:UpdateAsync(key, Callback or function(oldData: {})
				local previousData = oldData or data
				previousData["Version"] = previousData.Version or 1

				if AutoSaving then
					return data
				end

				if data.Version == previousData.Version then
					data.Version += 1
					return data
				end
				return nil
			end)
		end)
		return success, err
	end

	local success, err = UpdateAsynchronous()
	if self.__raw.options.RecursiveCalls and not success then
		for _ = 1, self.__raw.options.CallAttempts do
			success, err = UpdateAsynchronous()
			if success then 
				break 
			end

			task.wait(self.__raw.options.RetryCallDelay)
		end
	end

	if not AutoSaving then self.__raw.fire("Released", player) end
	return success
end

function DataCacher:Get(player: Player, ViewRawData: boolean?): {}
	return self.__raw.playerData[player] and 
		(ViewRawData and Globals.Duplicate(self.__raw.playerData[player]) or
			self.__raw.playerData[player]["data"])
end

function DataCacher:GetDataOffline(UserId: number): {}?
	local key = getPlayerKey(UserId, self.__raw.options.Key)
	local success, result = pcall(function()
		self.__raw.waitForThrottle("GET")
		return self.__raw.datastore:GetAsync(key)
	end)

	return result and Globals.Duplicate(result)
end

function DataCacher:SaveDataOffline(UserId: number, Data: {}): boolean
	local key = getPlayerKey(UserId, self.__raw.options.Key)
	local success, result = pcall(function()
		self.__raw.waitForThrottle("UPDATE")
		self.__raw.datastore:UpdateAsync(key, function(...)
			return Data
		end)
	end)
	return success
end

function DataCacher:Wipe(player: Player)
	if self.__raw.playerData[player] then
		self.__raw.playerData[player] = {data = self.__raw.options.TemplateData}
		self.__raw.playerData[player]["LastJoined"] = os.time()
		self.__raw.playerData[player]["LastLeft"] = nil
		self.__raw.playerData[player]["Version"] = 1

		if not RunService:IsStudio() or self.__raw.options.SaveInStudio then
			local success, err = pcall(function()
				local key = getPlayerKey(player.UserId, self.__raw.options.Key)
				self.__raw.datastore:SetAsync(key, self.__raw.playerData[player])
			end)

			if not success then
				warn("Error when wiping: "..err)
			end
		end

		self.__raw.fire("Wiped", player)
	end
end

function DataCacher:View(player: Player)
	local data = self:Get(player)
	if data then
		handleNestedTableWithOperation(data, function(index, value)
			print(("%s's Data: [Index] = %s | [Value] = %s"):format(
				player.Name, tostring(index), tostring(value)
				))
		end)
	end
end

function DataCacher:GetListener(ListenerType: Listeners, Callback: (player: Player, ...any) -> nil)
	if self.__raw.options.CreateListeners then
		local validListeners = {
			["Changed"] = true;
			["Loaded"] = true;
			["Released"] = true;
			["Wiped"] = true;
		}

		if validListeners[ListenerType] then
			if not self.__raw.events[ListenerType] then
				self.__raw.events[ListenerType] = {Functions = {}}

				Signal.Connect(ListenerType, function(...)
					for _, callback in self.__raw.events[ListenerType].Functions do
						callback(...)
					end
				end)

				if ListenerType == "Changed" then
					for _, player: Player in Players:GetPlayers() do
						self.__raw.addChangeSpeaker(player)
					end
				end
			end

			table.insert(self.__raw.events[ListenerType].Functions, Callback)
		end
	end
end

function DataCacher:RemoveListener(ListenerType: Listeners)
	if self.__raw.events[ListenerType] then
		Signal.Disconnect(ListenerType)

		table.clear(self.__raw.events[ListenerType].Functions)
		self.__raw.events[ListenerType] = nil

		if ListenerType == "Changed" and Globals.CountDictionary(self.__raw.changed) >= 1 then
			for player: Player, _ in self.__raw.changed do
				self.__raw.changed[player]:Disconnect()
				self.__raw.changed[player] = nil
			end
		end
	end
end

function DataCacher:ClearListeners()
	for listener, _ in self.__raw.events do
		self:RemoveListener(listener)
	end
end

function DataCacher:GetDataSizeInBytes(player: Player): (number, boolean)
	local data = self.__raw.playerData[player]
	if data then
		local maxSize = 4 * (10 ^ 6)
		local size = #HTTPService:JSONEncode(data)

		return size, size >= maxSize
	end
end

game:BindToClose(function()
	local total_requests_needed = 0
	local requests_made = 0

	for key, _ in Globals.RegisteredDataStores do
		local datastore = DataCacher.GetRegisteredDatastore(key, 1)
		if datastore then
			if RunService:IsStudio() and not datastore.__raw.options.SaveInStudio then
				continue
			end

			for _, player in Players:GetPlayers() do
				total_requests_needed += 1
				coroutine.wrap(function()
					pcall(datastore.Save, datastore, player)
					requests_made += 1
				end)()
			end
		end
	end

	while requests_made ~= total_requests_needed do
		RunService.Heartbeat:Wait()
	end
end)

return DataCacher