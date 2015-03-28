-- Created by LNETeam
-- Private Operations

---------------------------------------------------------------------------------------
-- Creates a coroutine based on a supplied function.
-- @param fist: First function
-- @param (...): Any other supplied functions will be converted
-- Returns: table<coroutines>
---------------------------------------------------------------------------------------
local function create( first, ... ) --Derived from parallel API
	if first ~= nil then
		if type( first ) ~= "function" then
			error( "Expected function, got "..type( first ), 3 )
		end
		return coroutine.create(first), create( ... )
	end
	return nil
end

---------------------------------------------------------------------------------------
-- Runs a sandbox based on supplied routines and limit.
-- @param _routines: Table of routines to be run within sandbox
-- @param _limit: How many routines must finish to terminate sandbox
-- Returns: void
---------------------------------------------------------------------------------------
local function runSandbox( _routines, _limit ) --Derived from parallel API
	local count = #_routines
	local living = count

	local tFilters = {}
	local eventData = {}
	while true do
		for n=1,count do
			local r = _routines[n]
			if r then
				if tFilters[r] == nil or tFilters[r] == eventData[1] or eventData[1] == "terminate" then
					local ok, param = coroutine.resume( r, unpack(eventData) )
					if not ok then
						error( param, 0 )
					else
						tFilters[r] = param
					end
					if coroutine.status( r ) == "dead" then
						_routines[n] = nil
						living = living - 1
						if living <= _limit then
							return n
						end
					end
				end
			end
		end
		for n=1,count do
			local r = _routines[n]
			if r and coroutine.status( r ) == "dead" then
				_routines[n] = nil
				living = living - 1
				if living <= _limit then
					return n
				end
			end
		end
		eventData = { os.pullEventRaw() }
	end
end

-- Class System

---------------------------------------------------------------------------------------
-- Generates classes to be used as object orientation.
-- @param base: A function initializing the object (Can be used for inheritance):
--
-- local object = class(function(table_name,...) 
--		inner.key = value --Inner will be the table that is associated with metamethods
--	end) 
--
-- function object:Method()
--
--  end
--
--  local programObject = object(...)
--  programObject:Method()
--
-- @param init: Function extending base (See examples below)
-- Returns: class
---------------------------------------------------------------------------------------
function class(base, init)
   local c = {}    -- a new class instance
   if not init and type(base) == 'function' then
      init = base
      base = nil
   elseif type(base) == 'table' then
    -- our new class is a shallow copy of the base class!
      for i,v in pairs(base) do
         c[i] = v
      end
      c._base = base
   end
   -- the class will be the metatable for all its objects,
   -- and they will look up their methods in it.
   c.__index = c

   -- expose a constructor which can be called by <classname>(<args>)
   local mt = {}
   mt.__call = function(class_tbl, ...)
   local obj = {}
   setmetatable(obj,c)
   if init then
      init(obj,...)
   else 
      -- make sure that any stuff from the base class is initialized!
      if base and base.init then
      base.init(obj, ...)
      end
   end
   return obj
   end
   c.init = init
   c.is_a = function(self, klass)
      local m = getmetatable(self)
      while m do 
         if m == klass then return true end
         m = m._base
      end
      return false
   end
   setmetatable(c, mt)
   return c
end


-- Class Definitons
---------------------------------------------------------------------------------------
-- List class definition.
-- Returns: object
---------------------------------------------------------------------------------------
List = class(function(inner) 
		inner.items = {}
	end)

---------------------------------------------------------------------------------------
-- Stack class definition. Stack is a system to "stack" items in a list 
-- and "pop" off an object from the stack.
-- Returns: object
---------------------------------------------------------------------------------------
Stack = class(function(inner)
		inner.internal = {}
		inner.value = ""
		inner.filo = true --First in, last out
	end)

---------------------------------------------------------------------------------------
-- Dictionary class definition. A system to store values with a specified
-- key. Includes prebuilt methods to index these items.
-- Returns: object
---------------------------------------------------------------------------------------
Dictionary = class(function(inner) 
		inner.keys = {}
	end)

---------------------------------------------------------------------------------------
-- Container class definition.
-- @param set: Function set (as a table of functions) to be executed
-- @param args(Deprecated): Arguments for the functions in @set
-- @param env: Function environment for all programs in @set
-- @param locked: A path all functions in @set are restricted to as the top level
-- Returns: object
---------------------------------------------------------------------------------------
Container = class(function(inner,set,args,env,locked)

	if (type(set) ~= "table") then error("Handle set is not table! Is: "..type(set)) end
	inner.environment = env
	inner.status = {}
	inner.local_dir = locked
	inner.args = args
	inner.progs = {}
	inner.instSet = set
	end)

---------------------------------------------------------------------------------------
-- AppContainer class definition. Similar to Container, just simplifies arguments.
-- @param set: Function set (as a table of functions) to be executed
-- @param args(Deprecated): Arguments for the functions in @set
-- @param env: Function environment for all programs in @set
-- @param locked: A path all functions in @set are restricted to as the top level
-- Returns: object
---------------------------------------------------------------------------------------
AppContainer = function(set,args,env,locked)
		return Container(set,args or {},env or _G,locked or "")
	end

-- End Class Definitions

-- Start Stack Methods

---------------------------------------------------------------------------------------
-- Looks at the next value to be active after current value is popped.
-- Returns: item or nil
---------------------------------------------------------------------------------------
function Stack:Peek()
    if (self.internal ~= nil and #self.internal ~= 0) then
        return self.internal[#self.internal-1]
    end
    return nil
end

---------------------------------------------------------------------------------------
-- Pops or removes the top level value from a stack.
-- Returns: void
---------------------------------------------------------------------------------------
function Stack:Pop()
    if (self.internal ~= nil and #self.internal ~= 0) then
        table.remove(self.internal,#self.internal-1)
		self.value = self.internal[#self.internal-1]
    end
end

---------------------------------------------------------------------------------------
-- Adds an item to either the top or bottom of stack depending on mode.
-- @param item: Item to be added to the stack
-- Returns: bool
---------------------------------------------------------------------------------------
function Stack:Push(item)
    if (self.internal ~= nil) then
        table.insert(self.internal,item)
		self.value = item
		return true
    end
    return false
end

---------------------------------------------------------------------------------------
-- Purges stack of all values.
-- Returns: void
---------------------------------------------------------------------------------------
function Stack:Clear()
    self.internal = {}
end

---------------------------------------------------------------------------------------
-- Returns number of items in stack.
-- Returns: int
---------------------------------------------------------------------------------------
function Stack:Count()
    return #self.internal
end

---------------------------------------------------------------------------------------
-- Queries stack for item.
-- @param item: Search through stack for specified item.
-- Returns: bool, elementId (if it exists)
---------------------------------------------------------------------------------------
function Stack:Contains(item)
    if (item == nil) then return false,nil end
    for k,v in ipairs(self.internal) do
    	if (v == item) then
    		return true,k
    	end 
    end
    return false,nil
end
-- End Stack Methods

-- Start Dictionary Methods

---------------------------------------------------------------------------------------
-- Adds a key value to the dictionary.
-- @param key: Key name
-- @param value: Value associated with key
-- Returns: void
---------------------------------------------------------------------------------------
function Dictionary:Add(key,value)
	if (not self.keys.key) then
		self.keys.key = value
	else
		error("An item with the same key has already been added!",2)
	end
end

---------------------------------------------------------------------------------------
-- Retrieves value from key.
-- @param key: Key name
-- Returns: value
---------------------------------------------------------------------------------------
function Dictionary:GetValueFromKey(key)
	return self.keys.key
end
-- End Dictionary Methods

-- Start App Handle Methods

---------------------------------------------------------------------------------------
-- Registers function coroutines to internal controller.
-- Returns: void
---------------------------------------------------------------------------------------
function Container:AddSandboxDefinition()
	local controller = {}
	for k,v in pairs(self.instSet) do
		local t = create(v)
		table.insert(controller,t)
	end
	self.progs = controller
end

---------------------------------------------------------------------------------------
-- Retrieves list of all processes.
-- Returns: table<coroutines>
---------------------------------------------------------------------------------------
function Container:GetProcess()
	return self.progs
end

---------------------------------------------------------------------------------------
-- Gets statuses of all routines in controller.
-- Returns: table<coroutine.status>
---------------------------------------------------------------------------------------
function Container:GetStatus()
	self.status = coroutine.status(self.progs)
	return self.status
end

---------------------------------------------------------------------------------------
-- Resumes all processes in event of yield.
-- Returns: void
---------------------------------------------------------------------------------------
function Container:ResumeContainer()
	for k,v in pairs(self.progs) do
		coroutine.resume(v)
	end
end

---------------------------------------------------------------------------------------
-- Starts all processes with. MUST be started with this method or event handling
-- will not function properly.
-- Returns: void
---------------------------------------------------------------------------------------
function Container:StartContainer()
	runSandbox(self.progs,1)
end

-- End App Handle Methods

-- Public Functions

-- Text Align Methods

---------------------------------------------------------------------------------------
-- Gets center x-coordinate for specified string.
-- @param st: string to be centered
-- Returns: x-coordinate
---------------------------------------------------------------------------------------
function getCenterX(st)
	local x,y = term.getSize()
	local strH = math.floor(string.len(st)/2)
	return math.floor((x/2)-strH)
end

---------------------------------------------------------------------------------------
-- Gets center y-coordinate
-- Returns: y-coordinate
---------------------------------------------------------------------------------------
function getCenterY()
	local x,y = term.getSize()
	return math.floor(y/2)
end

---------------------------------------------------------------------------------------
-- Centers text dead center by writing.
-- @param st: string to be centered
-- Returns: void
---------------------------------------------------------------------------------------
function writeCenterText(str)
	x = getCenterX(str)
	y = getCenterY()
	term.setCursorPos(x,y)
	term.write(str)
end

---------------------------------------------------------------------------------------
-- Centers text dead center by printing.
-- @param st: string to be centered
-- Returns: void
---------------------------------------------------------------------------------------
function printCenterText(str)
	x = getCenterX(str)
	y = getCenterY()
	term.setCursorPos(x,y)
	print(str)
end
-- End Text Align Methods

---------------------------------------------------------------------------------------
-- Imports api and returns global reference.
-- @param path: path to desired api
-- Returns: global reference (ex: local api = kernel.import("api.lua"))
---------------------------------------------------------------------------------------
function import(path)
   if fs.exists(path) then
		prog = ""
        os.loadAPI(path)
		if path:find("/") < 0 then prog = path
		else
			path = path:reverse()
			a,b = path:find("/")
			prog = string.sub(path,0,a-1)
			prog = prog:reverse()
		end
		return _G[prog]
    else
       error("Referenced: "..path.."; not found") 
    end
end

---------------------------------------------------------------------------------------
-- Logs data to a file.
-- @param content: content to be logged
-- Returns: void
---------------------------------------------------------------------------------------
function log(content)
	if (type(content)=="table") then
		local file = io.open("log_"..shell.getRunningProgram().."_"..os.time(),"w")
		file:write(textutils.serialize(content))
		file:close()
	else
		local file = io.open("log_"..shell.getRunningProgram().."_"..os.time(),"w")
		file:write(content)
		file:close()
	end
end


-- End Public Functions

--[[
Class System Examples:

Animal = class(function(a,name)
   a.name = name
end)

function Animal:__tostring()
  return self.name..': '..self:speak()
end

Dog = class(Animal)

function Dog:speak()
  return 'bark'
end

Cat = class(Animal, function(c,name,breed)
         Animal.init(c,name)  -- must init base!
         c.breed = breed
      end)

function Cat:speak()
  return 'meow'
end

Lion = class(Cat)

function Lion:speak()
  return 'roar'
end

fido = Dog('Fido')
felix = Cat('Felix','Tabby')
leo = Lion('Leo','African')

]]
