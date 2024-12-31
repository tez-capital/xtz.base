local hjson = require"hjson"
local io = require"io"

local specs_raw = fs.read_file("./src/specs.json")
local specs = hjson.parse(specs_raw)

print("ID=" .. specs.id)
print("VERSION=" .. specs.version)

local command = 'git tag -l "' .. specs.version .. '"'
local handle = io.popen(command)
local result = handle:read("*a")
handle:close()

if result == "" then
	print("NEEDS_RELEASE=true")
end