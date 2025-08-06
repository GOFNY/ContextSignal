
# ContextSignal - Lightweight Event, Query & Promise System

A lightweight alternative to Roblox’s `BindableEvent` and `BindableFunction`, offering better performance, cleaner API, and full support for asynchronous requests through `Query`, `Deferred`, and `Promise`.

The Event system inherits the proven GC-free design from [GoodSignal](https://gist.github.com/stravant/b75a322e0919d60dde8a0316d1f09d2f) by Stravant, and extends it with a typed, reusable interface suitable for large-scale modular projects, offering isolation and a cleaner API.
- Context-based access by name
- Cancelable Promise-like system
- GC-free coroutine runner (`freeRunnerThread`)
- Zero dependencies

## API Overview

### Event

A pub/sub signal system with multiple listeners.

```lua
local Event = ContextSignal.GetEvent("MyEvent")

local conn = Event:Connect(function(msg)
    print("Received:", msg)
end)

Event:Fire("Hello World")
```

Methods:
- `Fire(...)`
- `Connect(fn)`
- `Once(fn)`
- `Wait()`
- `DisconnectAll()`

### Query + Promise

An async alternative to BindableFunction, using Deferred objects.

```lua
local Query = ContextSignal.GetQuery("Sum")

Query:OnRequest(function(Deferred, a, b)
    if type(a) ~= "number" or type(b) ~= "number" then
        return Deferred:Reject("Invalid arguments")
    end

    task.wait(1)
    Deferred:Resolve(a + b)
end)

Query:Request(1, 2)
    :AndThen(function(Result)
        print("Result:", Result)
    end)
    :Catch(function(Error)
        warn("Error:", Error)
    end)
    :Finally(function()
        print("Done")
    end)
```

Query:
- `OnRequest(fn)` — receives `(Deferred, ...args)`
- `Request(...)` — returns a `Promise`

Deferred:
- `Resolve(...)`
- `Reject(...)`
- `Cancel(...)`

Promise:
- `AndThen(fn)`
- `Catch(fn)`
- `Canceled(fn)`
- `Finally(fn)`
- `Await()` / `AwaitWithNoResult()`

### ContextSignal

The global context-based manager.

```lua
local ev = ContextSignal.GetEvent("Notify")
local q = ContextSignal.GetQuery("Process")
```

Methods:
- `GetEvent(Name: string)`
- `GetQuery(Name: string)`

## Structure

```
ContextSignal/
├── ContextSignal.lua
├── Event.lua
├── Query.lua
├── Promise.lua
├── Deferred.lua
└── Internal/
    └── freeRunnerThread.lua
```

## Why Use This?

- 100% written in pure Luau
- No reliance on Roblox instances
- Low memory and GC footprint
- Built-in Promise canceling
- Safe in concurrent environments
- Based on proven performance patterns

## Inspirations

- GoodSignal by stravant
- Roblox BindableEvent / BindableFunction
- JS-style Promises, adapted for Luau

## Requirements

- Roblox Luau runtime
- No Roblox object dependencies
