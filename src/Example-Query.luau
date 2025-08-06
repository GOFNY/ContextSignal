local ContextSignal = require(path.to.ContextSignal)
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