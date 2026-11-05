local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local task = require("@lune/task")

local function text(path: string): string
	return (fs.readFile(path):gsub("\r\n", "\n"))
end

local function replace(s: string, from: string, to: string): string
	local i, j = s:find(from, 1, true)
	assert(i and j, "missing " .. from)
	return s:sub(1, i - 1) .. to .. s:sub(j + 1)
end

local function assemble(port: number, token: string): string
	local stub = replace(text("bridge/stub.luau"), "__PORT__", tostring(port))
	stub = replace(stub, "__TOKEN__", token)
	return replace(stub, "--[[HMAC]]", text("bridge/hmac.luau"))
end

local function runBridge(frames: { any })
	local inbox, sent, closed = {}, {}, false
	for _, frame in frames do
		table.insert(inbox, serde.encode("json", frame))
	end
	local ctx = {
		send = function(s)
			table.insert(sent, serde.decode("json", s))
		end,
		recv = function()
			local m = table.remove(inbox, 1)
			closed = closed or m == nil
			return m
		end,
		close = function()
			closed = true
		end,
		isClosed = function()
			return closed
		end,
	}
	local genv = { __ethosBridgeLoadout = "job-1" }
	local Http = {
		JSONEncode = function(_, v)
			return serde.encode("json", v)
		end,
		JSONDecode = function(_, s)
			return serde.decode("json", s)
		end,
	}
	local services = { HttpService = Http, Players = { LocalPlayer = { UserId = 123456789, Name = "PetFarm01" } } }
	local env = {
		game = {
			PlaceId = 8737899170,
			GameId = 3317771874,
			JobId = "job-1",
			GetService = function(_, name)
				return services[name]
			end,
		},
		getgenv = function()
			return genv
		end,
		identifyexecutor = function()
			return "FakeExec", "0.1.0"
		end,
		loadstring = function(src, chunk)
			local ok, fn = pcall(luau.load, src, { debugName = chunk:gsub("^=", "") })
			if ok then
				return fn
			end
			return nil, fn
		end,
		task = task,
	}
	luau.load(text("bridge/bridge.luau"), { debugName = "EthosBridge", environment = env })(ctx)
	local byType = {}
	for _, frame in sent do
		byType[frame.type] = byType[frame.type] or {}
		table.insert(byType[frame.type], frame)
	end
	return sent, byType
end

local tests = {}

tests["stub.luau is the spec's 3.6 stub source"] = function()
	local block = text("docs/bridge-protocol.md"):match("### 3%.6 Stub source.-```lua\n(.-)```")
	assert(block, "no 3.6 lua block")
	assert(block == text("bridge/stub.luau"), "bridge/stub.luau differs from spec 3.6")
end

tests["the assembled stub compiles with every placeholder filled"] = function()
	local token = string.rep("ab", 32)
	local stub = assemble(20001, token)
	assert(not stub:find("__PORT__", 1, true) and not stub:find("__TOKEN__", 1, true) and not stub:find("--[[HMAC]]", 1, true))
	assert(stub:find('local PORT, TOKEN = 20001, "' .. token .. '"', 1, true))
	luau.compile(stub)
end

tests["the starter bridge is ASCII and starts with local ctx = ..."] = function()
	local src = text("bridge/bridge.luau")
	assert(not src:find("[\128-\255]"), "non-ASCII byte")
	assert(src:sub(1, 15) == "local ctx = ...")
end

tests["the starter bridge says hello first, with the alt's identity"] = function()
	local sent = runBridge({})
	local hello = sent[1]
	assert(hello and hello.type == "hello", "first frame is not hello")
	assert(hello.userId == 123456789 and hello.userName == "PetFarm01" and hello.placeId == 8737899170)
	assert(hello.gameId == 3317771874 and hello.jobId == "job-1" and hello.v == 1 and hello.loadout == true)
	assert(hello.executor.name == "FakeExec" and hello.executor.version == "0.1.0")
end

tests["the starter bridge answers run with the returned values"] = function()
	local _, byType = runBridge({
		{ type = "ping" },
		{ type = "run", id = "d17", name = "Agent", code = "return 1 + 1, 'x', nil" },
	})
	local result = byType.result and byType.result[1]
	assert(result and result.re == "d17" and result.ok == true and result.error == nil, "no ok result")
	assert(#result.value == 3 and result.value[1] == "2" and result.value[2] == "x" and result.value[3] == "nil")
end

tests["the starter bridge answers a bad run with ok false"] = function()
	local _, byType = runBridge({
		{ type = "run", id = "d18", code = "return (" },
		{ type = "run", id = "d19", code = "error('boom', 0)" },
	})
	local results = byType.result or {}
	assert(#results == 2, "expected two results")
	for _, r in results do
		assert(r.ok == false and type(r.error) == "string" and r.value == nil)
	end
	assert(results[2].error == "boom")
end

return tests
