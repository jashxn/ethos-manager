local PORT, TOKEN = __PORT__, "__TOKEN__"
local env = getgenv and getgenv() or _G
local gen = (env.__ethosBridgeGen or 0) + 1
env.__ethosBridgeGen = gen
local connect = (type(WebSocket) == "table" and WebSocket.connect)
	or (type(syn) == "table" and type(syn.websocket) == "table" and syn.websocket.connect)
if type(connect) ~= "function" or type(loadstring) ~= "function" then return end
local Http = game:GetService("HttpService")
local sha256, hmac = (function() --[[HMAC]] end)()
local MAX = 1048576

local function hex64(s) return type(s) == "string" and #s == 64 and not s:find("[^0-9a-f]") end
local function decode(s)
	if not s then return nil end
	local ok, v = pcall(Http.JSONDecode, Http, s)
	return ok and type(v) == "table" and v or nil
end
local function entropy()
	local ok, bytes = pcall(function() return crypt.generatebytes(32) end)
	return tostring(ok and bytes) .. Random.new():NextNumber() .. os.clock() .. game.JobId .. tostring({})
end

local function session()
	local ok, ws = pcall(connect, "ws://127.0.0.1:" .. PORT .. "/")
	if not ok or not ws then return end
	local inbox, closed = {}, false
	local function close() closed = true; pcall(ws.Close, ws) end
	ws.OnMessage:Connect(function(m)
		if closed then return end
		if type(m) ~= "string" or #m > MAX or #inbox >= 256 then return close() end
		table.insert(inbox, m)
	end)
	ws.OnClose:Connect(function() closed = true end)
	local function recv(timeout)
		local waited = 0
		while #inbox == 0 and not closed and waited < timeout do waited += task.wait(0.05) end
		return table.remove(inbox, 1)
	end
	local nc = sha256(entropy())
	ws:Send(Http:JSONEncode({ v = 1, type = "auth.begin", nonce = nc }))
	local c = decode(recv(10))
	if not (c and c.v == 1 and c.type == "auth.challenge" and hex64(c.nonce)) then return close() end
	local t = PORT .. "\n" .. nc .. "\n" .. c.nonce
	ws:Send(Http:JSONEncode({ v = 1, type = "auth.proof", proof = hmac(TOKEN, "ethos-bridge/1 client\n" .. t) }))
	local w = decode(recv(10))
	if not (w and w.v == 1 and w.type == "auth.ok" and hex64(w.proof) and type(w.source) == "string") then return close() end
	if hmac(TOKEN, "ethos-bridge/1 server\n" .. t .. "\n" .. sha256(w.source)) ~= w.proof then return close() end
	local run = loadstring(w.source, "=EthosBridge")
	if not run then return close() end
	pcall(run, {
		send = function(s) if not closed then ws:Send(s) end end,
		recv = recv, close = close, isClosed = function() return closed end,
		sha256 = sha256, hmac = hmac,
	})
	close()
end

task.spawn(function()
	if not game:IsLoaded() then game.Loaded:Wait() end
	while env.__ethosBridgeGen == gen do
		local started = time()
		pcall(session)
		if env.__ethosBridgeGen ~= gen then break end
		local delay = (time() - started > 60) and 2 or math.min((env.__eb_delay or 2) * 2, 60)
		env.__eb_delay = delay
		task.wait(delay * (0.8 + math.random() * 0.4))
	end
end)
