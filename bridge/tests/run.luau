local fs = require("@lune/fs")
local process = require("@lune/process")

local DIR = "bridge/tests"

local modules = {}
for _, file in fs.readDir(DIR) do
	if file:match("%.luau$") and file ~= "run.luau" and not file:match("_e2e%.luau$") and fs.isFile(DIR .. "/" .. file) then
		table.insert(modules, (file:gsub("%.luau$", "")))
	end
end
table.sort(modules)

local passed, failed = 0, 0
for _, module in modules do
	local loaded, tests = pcall(require, "./" .. module)
	if not loaded or type(tests) ~= "table" then
		failed += 1
		print(`FAIL {module}: {if loaded then "does not return a table of tests" else tostring(tests)}`)
		continue
	end
	local names = {}
	for name in tests do
		table.insert(names, name)
	end
	table.sort(names)
	local p, f = 0, 0
	for _, name in names do
		local ok, err = pcall(tests[name])
		if ok then
			p += 1
		else
			f += 1
			print(`FAIL {module} > {name}: {err}`)
		end
	end
	print(`{module}: {p} passed, {f} failed`)
	passed += p
	failed += f
end

print(`RESULT {passed} passed, {failed} failed`)
process.exit(if failed == 0 and passed > 0 then 0 else 1)
