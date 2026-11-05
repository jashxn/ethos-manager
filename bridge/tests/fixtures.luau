local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

local ROOT = "bridge/fixtures"
local sha256, hmac = luau.load(fs.readFile("bridge/hmac.luau"), { debugName = "hmac" })()

local function unhex(s: string): string
	assert(#s % 2 == 0 and not s:find("[^0-9a-f]"), "not lowercase hex")
	return (s:gsub("..", function(x)
		return string.char(tonumber(x, 16) :: number)
	end))
end

local function walk(dir: string, out: { string }): { string }
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path, out)
		elseif name:match("%.json$") then
			table.insert(out, path)
		end
	end
	return out
end

local function read(path: string)
	return serde.decode("json", fs.readFile(ROOT .. "/" .. path))
end

local judges = {}

function judges.crypto(v): boolean
	if v.kind == "sha256" then
		return sha256(unhex(v.messageHex)) == v.expected
	elseif v.kind == "hmac" then
		return hmac(unhex(v.keyHex), unhex(v.messageHex)) == v.expected
	elseif v.kind == "handshake" then
		local t = v.port .. "\n" .. v.nc .. "\n" .. v.ns
		return sha256(v.source) == v.sourceHash
			and hmac(v.token, "ethos-bridge/1 client\n" .. t) == v.clientProof
			and hmac(v.token, "ethos-bridge/1 server\n" .. t .. "\n" .. sha256(v.source)) == v.serverProof
	end
	error("unknown crypto kind " .. tostring(v.kind))
end

function judges.ws(v): boolean
	for _, n in v do
		if type(n) ~= "number" or n % 1 ~= 0 or n <= 0 then
			return false
		end
	end
	return next(v) ~= nil
end

local tests = {}
local pending = {}

local paths = walk(ROOT, {})
table.sort(paths)
for _, path in paths do
	local rel = path:sub(#ROOT + 2)
	local group, name = path:match("([^/]+)/([^/]+)%.json$")
	local fixture = serde.decode("json", fs.readFile(path))
	tests[rel .. " is named by its path"] = function()
		local keys = 0
		for _ in fixture do
			keys += 1
		end
		assert(keys == 3 and fixture.value ~= nil, "not {id, valid, value}")
		assert(fixture.id == `bridge.{group}.{name}`, "id is " .. tostring(fixture.id))
	end
	tests[rel .. " ends in -valid exactly when valid"] = function()
		assert(type(fixture.valid) == "boolean", "valid is not a boolean")
		assert((name:sub(-6) == "-valid") == fixture.valid)
	end
	local judge = judges[group]
	if judge then
		tests[rel .. " is judged " .. (if fixture.valid then "valid" else "invalid")] = function()
			assert(judge(fixture.value, name) == fixture.valid)
		end
	else
		pending[group] = (pending[group] or 0) + 1
	end
end

tests["the spec's worked vector is crypto/handshake-valid"] = function()
	local spec = fs.readFile("docs/bridge-protocol.md"):gsub("\r\n", "\n")
	local v = read("ws/crypto/handshake-valid.json").value
	assert(spec:match("\nTOKEN%s+(%x+)") == v.token, "TOKEN")
	assert(tonumber(spec:match("\nPORT%s+(%d+)")) == v.port, "PORT")
	assert(spec:match("\nNc%s+(%x+)") == v.nc, "Nc")
	assert(spec:match("\nNs%s+(%x+)") == v.ns, "Ns")
	assert(spec:match("\nSOURCE%s+([^\n]+)") == v.source, "SOURCE")
	assert(spec:match("\nH%(SOURCE%)%s+(%x+)") == v.sourceHash, "H(SOURCE)")
	assert(spec:match("\nPc%s+(%x+)") == v.clientProof, "Pc")
	assert(spec:match("\nPs%s+(%x+)") == v.serverProof, "Ps")
	local wrong = read("ws/crypto/handshake-wrong-port-invalid.json").value
	assert(spec:match("\nPs @ PORT 51735 %(must reject%)%s+(%x+)") == wrong.serverProof, "Ps @ PORT 51735")
end

for group, n in pending do
	print(`fixtures: {n} {group} fixture(s) wait for a judge`)
end

return tests
