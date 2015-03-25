--Developed by Laney Network Technologies for use with M-Tech Operating System. Any other use without consent of the owning party is prohibited.
new = {}
local _tagTypes = {}
_tagTypes.Text = ""
_tagTypes.Tag = ""

local _tokenTypes = {}
_tokenTypes.OPENTAG = ""
_tokenTypes.ENDTAG = ""
_tokenTypes.SINGLEClOSE = ""
_tokenTypes.PARAMNAME = ""
_tokenTypes.PARAMVALUE = ""
_tokenTypes.TEXT = ""
_tokenTypes.ERROR = ""

--Private Operations
local function create( first, ... ) --Derived from parallel API
	if first ~= nil then
		if type( first ) ~= "function" then
			error( "Expected function, got "..type( first ), 3 )
		end
		return coroutine.create(first), create( ... )
	end
	return nil
end

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

--Class System
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


--Class Definitons
List = class(function(inner) 
		inner.items = {}
	end)

Stack = class(function(inner)
		inner.internal = {}
		inner.value = ""
		inner.filo = true
	end)

Dictionary = class(function(inner) 
		inner.keys = {}
	end)

Container = class(function(inner,set,args,env,locked)

	if (type(set) ~= "table") then error("Handle set is not table! Is: "..type(set)) end
	inner.process = nil
	inner.environment = env
	inner.status = nil
	inner.local_dir = locked or ""
	inner.args = args or {}
	inner.progs = {}
	inner.controller = nil
	inner.instSet = set
	end)

AppContainer = function(func,args,env,locked)
		return Container(func,args or {},env or _G,locked)
	end

--End Class Definitions

--Start Stack Methods
function Stack:Peek()
    if (self.internal ~= nil and #self.internal ~= 0) then
        return self.internal[#self.internal-1]
    end
end
function Stack:Pop()
        if (self.internal ~= nil and #self.internal ~= 0) then
            table.remove(self.internal,#self.internal-1)
			self.value = self.internal[#self.internal-1]
        end
end
function Stack:Push(item)
    if (self.internal ~= nil) then
        table.insert(self.internal,item)
		self.value = item
    end
end
function Stack:Clear()
    
end
function Stack:Count()
    
end
function Stack:Contains()
    
end
--End Stack Methods

--Start Dictionary Methods
function Dictionary:Add(key,value)
	if (not self.keys.key) then
		self.keys.key = value
	else
		error("An item with the same key has already been added!",2)
	end
end
function Dictionary:GetValueFromKey(key)
	return self.keys.key
end
--End Dictionary Methods

--Start App Handle Methods
function Container:AddSandboxDefinition()
	local controller = {}
	for k,v in pairs(self.instSet) do
		local t = create(v)
		table.insert(controller,t)
	end
	self.progs = controller
	--self.status = coroutine.status(self.process)
end

function Container:GetProcess()
	return self.prog
end

function Container:GetStatus()
	self.status = coroutine.status(self.process)
	return self.status
end

function Container:ResumeContainer()
	coroutine.resume(self.process)
end

function Container:StartContainer()
	runSandbox(self.progs,1)
end
--End App Handle Methods

--Public Functions
function import(path)
   if fs.exists(path) then
		prog =""
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

-- local function new.AppHandle(path,func,args,locked) --Temporally Suspended
-- 	local container = {
-- 		AddSandboxDefinition = function(self)
-- 			local controller = {}
-- 			for k,v in pairs(self.instSet) do
-- 				local t = create(v)
-- 				table.insert(controller,t)
-- 			end
-- 			self.progs = controller
-- 			--self.status = coroutine.status(self.process)
-- 		end,
-- 		GetProcess = function(self)
-- 			return self.process
-- 		end,
-- 		GetStatus = function(self)
-- 			self.status = coroutine.status(self.process)
-- 			return self.status
-- 		end,
-- 		ResumeContainer = function(self)
-- 			coroutine.resume(self.progs)
-- 		end,
-- 		StartContainer = function(self)
-- 			runSandbox(self.progs,1)
-- 		end,
-- 	}
-- 	local function createContainer( env,locked_dir,program,args,set )
-- 		if (type(set) ~= "table") then error("Handle set not table",2) end
-- 		local temp = 
-- 		{
-- 			process = nil,
-- 			environment = env,
-- 			status = nil,
-- 			local_dir = "",
-- 			args = args and args or {},
-- 			--prog = program,
-- 			progs = {},
-- 			controller = nil,
-- 			instSet = set

-- 		}
-- 		setmetatable(temp, {__index = container})
-- 		return temp
-- 	end
-- 	local _container = createContainer(_G,locked,path,args,func)

-- 	_container:AddSandboxDefinition()
-- 	return _container
-- end


--Unit Test: Uncomment to run

function testStack()
   local s = new.Stack()
   s:Push("/boot")
   s:Push("/demo")
   if (s.value ~= "/demo") then error(s.value) end
   if (s:Peek() ~= "/boot") then error(s:Peek()) end
   s:Pop()
   if (s.value ~= "/boot") then error(s.value) end
   s:Pop()
   if (self.value == nil) then error("Should pass") end
end

function testXML()
	local s = new.Stack()
	local ex = "<derp><stuff /><moar></moar></derp>"
end

function testDictionary()
	local d = new.Dictionary()
	d:Add("demo","butt")
	if (d:GetValueFromKey("demo") ~= "butt") then error("Should pass") end
	print(d:GetValueFromKey("demo"))
end
