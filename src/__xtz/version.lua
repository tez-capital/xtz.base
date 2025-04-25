local needs_json_output = am.options.OUTPUT_FORMAT == "json"

local options = ...
local print_all_versions = options.all

if not print_all_versions then
    print(am.app.get_version())
    return
end

local function get_dependency_versions(package)
    local collected = {}
    if table.is_array(package.dependencies) then
        for _, dependency in ipairs(package.dependencies) do
            if type(dependency) ~= "table" then
                goto continue
            end
            table.insert(collected, { id = dependency.id, version = dependency.version })
            collected = util.merge_arrays(collected, get_dependency_versions(dependency), { merge_strategy = "combine" })
            ::continue::
        end
    end
    return collected
end

local function get_binary_versions()
    local collected = {}
    local binaries = fs.read_dir("bin")

    for _, binary in ipairs(binaries) do
        local result = proc.spawn("bin/" .. binary, { 
            args = { "--version" },
            stdio = "pipe",
            wait = true,
            env = { HOME = path.combine(os.cwd(), "data") }
        }) --[[@as SpawnResult]]
        ami_assert(result and result.exit_code == 0, "failed to check version of " .. binary)
        local output = result.stdout_stream:read("a")
        collected[binary] = output:match("^%s*(.-)%s*$")
    end
    return collected
end

local version_tree = am.app.get_version_tree()

local versions = {
    id = version_tree.id,
    version = version_tree.version,
    binaries = get_binary_versions(),
    dependencies = get_dependency_versions(version_tree)
}

if needs_json_output then
    print(hjson.stringify_to_json(versions, { indent = false }))
else
    print(hjson.stringify(versions, { sort_keys = true }))
end
