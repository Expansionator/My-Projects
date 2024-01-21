--!nocheck
-- @fattah412

--[[

Reconciler:
A module that can fill in any missing values in a table using a template.

---------------------------------------------------------------------------------

Notes:

- This module will not fill in values if the value from the template is nil. For example: ["Test"] = nil
- Any new data that is not in the template but is for the main table, will also be included.
- Once requiring the module, it will behave like a function.
- Both the main table and the template must be a table.

---------------------------------------------------------------------------------

Example Usage:

local ServerScriptService = game:GetService("ServerScriptService")
local Reconcile = require(ServerScriptService:WaitForChild("Reconciler"))

local TemplateData = {
	["Temp"] = {1, 2};
	[1] = 1;
	[2] = 1;
	["Whatever Data"] = nil;
	["Coordinate"] = {
		["Extra Data"] = false;
		["Sub"] = {
			{"Lol", "Cool"};
			["Test"] = "Sure";
			{1,2,3,4,5};
			["Data"] = {
				["Examples"] = {};
				["Test"] = 1
			}
		}
	}
}

local MainData = {
	[1] = "Ran";
	[3] = "Yes!";
	["Temp"] = nil;
	["Coordinate"] = {
		{"Foo", "Poop"};
		["Some Index"] = {"Woah!"};
		["Sub"] = {
			{"Admin", "HD"};
			{1000, 2000, 3000, 4000};
			["Data"] = {}
		}
	}
}

local newTable = Reconcile(MainData, TemplateData)
print(newTable)

---------------------------------------------------------------------------------

Output / Result:

[1] = "Ran",
[2] = 1,
[3] = "Yes!",
["Coordinate"] =  ?  {
   [1] =  ?  {
      [1] = "Foo",
      [2] = "Poop"
   },
   ["Extra Data"] = false,
   ["Some Index"] =  ?  {
      [1] = "Woah!"
   },
   ["Sub"] =  ?  {
      [1] =  ?  {
         [1] = "Admin",
         [2] = "HD"
      },
      [2] =  ?  {
         [1] = 1000,
         [2] = 2000,
         [3] = 3000,
         [4] = 4000,
         [5] = 5
      },
      ["Data"] =  ?  {
         ["Examples"] = {},
         ["Test"] = 1
      },
      ["Test"] = "Sure"
   }
},
["Temp"] =  ?  {
   [1] = 1,
   [2] = 2
}

]]

return function(mainTable: {}, templateTable: {})	
	if typeof(mainTable) ~= "table" or typeof(templateTable) ~= "table" then
		return error("Parameters aren't a table!")
	end
	
	local function cloneTable(x: {})
		local copy = {}
		for k, v in pairs(x) do
			if type(v) == "table" then
				v = cloneTable(v)
			end
			copy[k] = v
		end
		return copy
	end
	
	local function reconcileTable(t, tt)
		local reconciled_table = cloneTable(tt)
		for index, value in pairs(t) do
			if reconciled_table[index] ~= nil then
				if typeof(value) == "table" then
					reconciled_table[index] = reconcileTable(value, reconciled_table[index])
				else
					reconciled_table[index] = value
				end
			else
				reconciled_table[index] = value
			end
		end
		return reconciled_table
	end
	
	local reconciled_table = reconcileTable(mainTable, templateTable)
	return reconciled_table
end