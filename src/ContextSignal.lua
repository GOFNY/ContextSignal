--[[
	ContextSignal by GOFNY

	A lightweight event, query, and promise system for Roblox, designed as a faster and cleaner alternative to BindableEvent and BindableFunction.

	Features:
	- Event system based on GoodSignal (https://gist.github.com/stravant/b75a322e0919d60dde8a0316d1f09d2f)
	- Typed, reusable interface for events and async queries
	- Promise system with Deferred support, including cancellation
	- Context-based access to named Events and Queries
	- GC-free coroutine runner for event handling
	- No Roblox instance dependencies

	Usage example:

	local ContextSignal = require(path.to.ContextSignal)

	local event = ContextSignal.GetEvent("TestEvent")
	local connection = event:Connect(function(...)
		print("Event fired with:", ...)
	end)

	event:Fire("Hello", "World")
	
	---

	local query = ContextSignal.GetQuery("Add")
	query:OnRequest(function(deferred, a, b)
		deferred:Resolve(a + b)
	end)

	query:Request(3, 4)
		:AndThen(function(result)
			print("Result:", result)
		end)

	For more infos: https://github.com/GOFNY/ContextSignal
]]

--Types
export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean
}
export type Event = {
	Fire: (self: Event, ...any) -> ...any,
	DisconnectAll: (self: Event) -> (),
	
	Connect: (self: Event, fn: (...any) -> ()) -> Connection,
	Once: (self: Event, fn: (...any) -> ()) -> Connection,
	Wait: (self: Event) -> ...any
}

export type Deferred = {
	Resolve: (self: Deferred, ...any) -> (),
	Reject: (self: Deferred, ...any) -> (),
	Cancel: (self: Deferred, ...any) -> ()
}

export type Promise = {
	--Resolve: (...any) -> Promise,
	Reject: (...any) -> Promise,
	
	AndThen: (self: Promise, fn: (...any) -> ()) -> Promise,
	Canceled: (self: Promise, fn: (...any) -> ()) -> Promise,
	Catch: (self: Promise, fn: (...any) -> ()) -> Promise,
	Await: (self: Promise) -> (boolean, ...any),
	AwaitWithNoResult: (self: Promise) -> ...any,
	Finally: (self: Promise, fn: (...any) -> ()) -> Promise
}
export type Query = {
	OnRequest: (self: Query, fn: (Deferred: Deferred, ...any) -> ()) -> (),
	Request: (self: Query, ...any) -> Promise,
}

export type ContextSignal = {
	GetEvent: (Name: string) -> Event,
	GetQuery: (Name: string) -> Query
}

--Event
local FreeRunnerThread = nil

local function AcquireFreeRunnerThreadAndCallEventHandler(fn, ...)
	local AcquiredRunnerThread = FreeRunnerThread
	FreeRunnerThread = nil
	
	fn(...)
	FreeRunnerThread = AcquiredRunnerThread
end

local function RunEventHandlerInFreeThread()
	while true do
		AcquireFreeRunnerThreadAndCallEventHandler(coroutine.yield())
	end
end

local Connection: Connection = {}
local Event: Event = {}
Connection.__index = Connection
Event.__index = Event

Connection.__tostring = function() return "Connection" end
Event.__tostring = function() return "Event" end

--<Connection>
function Connection.new(event: Event, fn: (...any) -> ...any): Connection
	local self = setmetatable({}, Connection)
	
	self.Connected = true
	self._event = event
	self._next = false
	self._fn = fn
	
	return self
end

function Connection:Disconnect(): ()
	if not self.Connected then return end
	self.Connected = false
	
	local event = self._event
	local next = self._next
	
	if self == event._handlerListHead then
		event._handlerListHead = next
		return
	end
	
	local prev = event._handlerListHead
	while prev and prev._next ~= self do
		prev = prev._next
	end
	if prev then
		prev._next = self._next
	end
end

--<Event>
function Event.new(): Event
	return setmetatable({_handlerListHead = nil}, Event)
end

function Event:Fire(...: any): ()
	local Handler = self._handlerListHead
	
	while Handler do
		if Handler.Connected then
			if not FreeRunnerThread then
				FreeRunnerThread = coroutine.create(RunEventHandlerInFreeThread)
				coroutine.resume(FreeRunnerThread)
			end
			task.spawn(FreeRunnerThread, Handler._fn, ...)
		end
		Handler = Handler._next
	end
end

function Event:Connect(fn: (...any) -> ()): Connection
	local connection = Connection.new(self, fn)
	
	if self._handlerListHead then
		connection._next = self._handlerListHead
	end
	
	self._handlerListHead = connection
	return connection
end

function Event:Once(fn: (...any) -> ()): Connection
	local connection 
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	
	return connection
end

function Event:Wait(): ...any
	local Waiting = coroutine.running()
	self:Once(function(...)
		task.spawn(Waiting, ...)
	end)
	
	return coroutine.yield()
end

function Event:DisconnectAll(): ()
	self._handlerListHead = nil
end

--Query
local Deferred: Deferred = {}
local Promise: Promise = {}
local Query: Query = {}
Deferred.__index = Deferred
Promise.__index = Promise
Query.__index = Query

Deferred.__tostring = function() return "Deferred" end
Promise.__tostring = function() return "Promise" end
Query.__tostring = function() return "Query" end

--<Deferred>
function Deferred.new(promise: Promise): Deferred
	local finished = false
	
	return setmetatable({
		_promise = promise,
		_finished = function()
			if finished then return end
			task.defer(promise._finished, promise)
			finished = true
			
			for _, fn in promise._finally do
				task.spawn(fn)
			end
		end,
	}, Deferred)
end

function Deferred:Resolve(...: any): ()
	local promise = self._promise
	if promise._state ~= "pending" then return end
	
	task.defer(self._finished)
	
	promise._state = "resolved"
	promise._value = {...}
	
	for _, fn in promise._andThen do
		task.spawn(fn, ...)
	end
end

function Deferred:Reject(...: any): ()
	local promise = self._promise
	if promise._state ~= "pending" then return end

	task.defer(self._finished)

	promise._state = "rejected"
	promise._error = {...}

	for _, fn in promise._catch do
		task.spawn(fn, ...)
	end
end

function Deferred:Cancel(...: any): ()
	local promise = self._promise
	if promise._state ~= "pending" then return end
	
	task.defer(self._finished)
	
	promise._state = "canceled"
	promise._canceled = {...}
	
	for _, fn in promise._cancel do
		task.spawn(fn, ...)
	end
end

--<Promise>
function Promise.new(): Promise
	local self = setmetatable({}, Promise)
	
	self._state = "pending"
	self._canceled = {}
	self._value = {}
	self._error = {}
	
	self._finally = {}
	self._andThen = {}
	self._cancel = {}
	self._catch = {}
	
	self._finished = function()
		self._finally = nil
		self._andThen = nil
		self._cancel = nil
		self._catch = nil
	end
	
	return self
end

--[[function Promise.Resolve(...: any): Promise
	local promise = Promise.new()
	local deferred = Deferred.new(promise)
	
	deferred:Resolve(...)
	return promise
end]]

function Promise.Reject(...: any): Promise
	local promise = Promise.new()
	local deferred = Deferred.new(promise)

	deferred:Reject(...)
	return promise
end

function Promise:AndThen(fn: (...any) -> ()): Promise
	if self._state == "resolved" then
		task.spawn(fn, table.unpack(self._value))
	else
		table.insert(self._andThen, fn)
	end
	return self
end

function Promise:Canceled(fn: (...any) -> ()): Promise
	if self._state == "canceled" then
		task.spawn(fn, table.unpack(self._canceled))
	else
		table.insert(self._cancel, fn)
	end
	return self
end

function Promise:Catch(fn: (...any) -> ()): Promise
	if self._state == "rejected" then
		task.spawn(fn, table.unpack(self._error))
	else
		table.insert(self._catch, fn)
	end
	return self
end

function Promise:Await(): (boolean, ...any)
	if self._state == "resolved" then
		return true, table.unpack(self._value)
	end
	
	if self._state == "rejected" then
		return false, table.unpack(self._error)
	end
	
	local Thread = coroutine.running()
	
	self:AndThen(function(...)
		task.spawn(Thread, true, ...)
	end)
	
	self:Catch(function(...)
		task.spawn(Thread, false, ...)
	end)
	
	return coroutine.yield()
end

function Promise:AwaitWithNoResult(): ...any
	local Value = {self:Await()}
	table.remove(Value, 1)
	
	return table.unpack(Value)
end

function Promise:Finally(fn: (...any) -> ()): Promise
	if self._state ~= "pending" then
		task.spawn(fn)
	else
		table.insert(self._finally, fn)
	end
	return self
end

--<Query>
function Query.new(): Query
	return setmetatable({
		_onRequest = nil
	}, Query)
end

function Query:OnRequest(fn: (...any) -> ()): ()
	self._onRequest = fn
end

function Query:Request(...: any): Promise
	local OnRequest = self._onRequest
	if not OnRequest then
		local Timeout = tick() + 3
		repeat
			OnRequest = self._onRequest
			task.wait()
		until OnRequest or tick() >= Timeout

		if not OnRequest then
			return Promise.Reject("Request timeout (did you forget to implement OnRequest?)")
		end
	end

	local promise = Promise.new()
	local deferred = Deferred.new(promise)

	local Arguments = {...}

	task.spawn(function()
		local Ok, Message = pcall(OnRequest, deferred, table.unpack(Arguments))
		if Ok then return end

		deferred:Reject(Message)
	end)
	
	return promise
end

--ContextSignal
local ContextSignal: ContextSignal = {
	_Event = {},
	_Query = {}
}

function ContextSignal.__get(Name: string, Type: "Event" | "Query")
	local FuncsTable = Type == "Event" and Event or Query
	local ContainerTable = ContextSignal[`_{Type}`]
	
	if ContainerTable[Name] then
		return ContainerTable[Name]
	end
	
	local NewObject = FuncsTable.new()
	ContainerTable[Name] = NewObject
	
	return NewObject
end

function ContextSignal.GetEvent(Name: string)
	return ContextSignal.__get(Name, "Event")
end

function ContextSignal.GetQuery(Name: string)
	return ContextSignal.__get(Name, "Query")
end

return ContextSignal :: ContextSignal