local K = {
	0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
	0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
	0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
	0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
	0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
	0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
	0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
	0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}
local band, bxor, bnot, rrot, rsh, swap = bit32.band, bit32.bxor, bit32.bnot, bit32.rrotate, bit32.rshift, bit32.byteswap

local function sha256(msg)
	local len = #msg
	local size = (len + 72) // 64 * 64
	local b = buffer.create(size)
	buffer.writestring(b, 0, msg)
	buffer.writeu8(b, len, 0x80)
	buffer.writeu32(b, size - 8, swap(len // 0x20000000))
	buffer.writeu32(b, size - 4, swap(len * 8 % 0x100000000))
	local h0, h1, h2, h3 = 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
	local h4, h5, h6, h7 = 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
	local w = table.create(64, 0)
	for at = 0, size - 1, 64 do
		for i = 1, 16 do
			w[i] = swap(buffer.readu32(b, at + i * 4 - 4))
		end
		for i = 17, 64 do
			local x, y = w[i - 15], w[i - 2]
			w[i] = (w[i - 16] + bxor(rrot(x, 7), rrot(x, 18), rsh(x, 3)) + w[i - 7] + bxor(rrot(y, 17), rrot(y, 19), rsh(y, 10))) % 0x100000000
		end
		local a, c, d, e, f, g, h, bb = h0, h2, h3, h4, h5, h6, h7, h1
		for i = 1, 64 do
			local t1 = h + bxor(rrot(e, 6), rrot(e, 11), rrot(e, 25)) + bxor(band(e, f), band(bnot(e), g)) + K[i] + w[i]
			local t2 = bxor(rrot(a, 2), rrot(a, 13), rrot(a, 22)) + bxor(band(a, bb), band(a, c), band(bb, c))
			h, g, f, e, d, c, bb, a = g, f, e, (d + t1) % 0x100000000, c, bb, a, (t1 + t2) % 0x100000000
		end
		h0, h1, h2, h3 = (h0 + a) % 0x100000000, (h1 + bb) % 0x100000000, (h2 + c) % 0x100000000, (h3 + d) % 0x100000000
		h4, h5, h6, h7 = (h4 + e) % 0x100000000, (h5 + f) % 0x100000000, (h6 + g) % 0x100000000, (h7 + h) % 0x100000000
	end
	return string.format("%08x%08x%08x%08x%08x%08x%08x%08x", h0, h1, h2, h3, h4, h5, h6, h7)
end

local function unhex(s)
	return (s:gsub("..", function(x) return string.char(tonumber(x, 16)) end))
end

local function hmac(key, msg)
	if #key > 64 then key = unhex(sha256(key)) end
	key ..= string.rep(string.char(0), 64 - #key)
	local i, o = key:gsub(".", function(ch) return string.char(bxor(ch:byte(), 0x36)) end), key:gsub(".", function(ch) return string.char(bxor(ch:byte(), 0x5c)) end)
	return sha256(o .. unhex(sha256(i .. msg)))
end

return sha256, hmac
