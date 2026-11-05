local ctx = ...
local Http = game:GetService("HttpService")
local player = game:GetService("Players").LocalPlayer

local function send(frame)
	ctx.send(Http:JSONEncode(frame))
end

local function result(id, ok, value)
	if ok then
		send({ type = "result", re = id, ok = true, value = value })
	else
		send({ type = "result", re = id, ok = false, error = string.sub(tostring(value), 1, 4096) })
	end
end

local function run(m)
	local fn, err = loadstring(m.code, "=" .. (m.name or "Run"))
	if not fn then
		return result(m.id, false, err)
	end
	local r = table.pack(pcall(fn))
	if not r[1] then
		return result(m.id, false, r[2])
	end
	local out = {}
	for i = 2, r.n do
		out[i - 1] = tostring(r[i])
	end
	result(m.id, true, out)
end

local name, version = (identifyexecutor or function() end)()
send({
	type = "hello",
	userId = player.UserId,
	userName = player.Name,
	placeId = game.PlaceId,
	gameId = game.GameId,
	jobId = game.JobId,
	executor = { name = string.sub(tostring(name or "Unknown"), 1, 40), version = string.sub(tostring(version or ""), 1, 40) },
	v = 1,
	loadout = getgenv().__ethosBridgeLoadout == game.JobId,
})

task.spawn(function()
	while not ctx.isClosed() do
		send({ type = "status" })
		task.wait(5)
	end
end)

while true do
	local text = ctx.recv(30)
	if not text then
		break
	end
	local ok, m = pcall(Http.JSONDecode, Http, text)
	if ok and type(m) == "table" and m.type == "run" and type(m.code) == "string" then
		task.spawn(run, m)
	end
end
