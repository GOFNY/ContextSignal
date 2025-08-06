local ContextSignal = require(path.to.ContextSignal)
local Event = ContextSignal.GetEvent("MyEvent")

local conn = Event:Connect(function(msg)
    print("Received:", msg)
end)

Event:Fire("Hello World")