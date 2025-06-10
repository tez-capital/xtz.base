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

    local wanted_binaries = am.app.get_model("WANTED_BINARIES", {})
    ami_assert(type(wanted_binaries) == "table", "Invalid list of wanted binaries!")

    for _, binary_name in ipairs(wanted_binaries) do
        local result, err = proc.spawn("bin/" .. binary_name, {
            args = { "--version" },
            stdio = "pipe",
            wait = true,
            env = { HOME = path.combine(os.cwd(), "data") }
        }) --[[@as SpawnResult]]
        if not result then
            collected[binary_name] = "unknown (spawn error - " .. tostring(err) .. ")"
            goto continue
        end
        if result.exit_code ~= 0 then
            collected[binary_name] = "unknown (exit code: ".. tostring(result.exit_code) .. ")"
            goto continue
        end
        local output = result.stdout_stream:read("a")
        collected[binary_name] = output:match("^%s*(.-)%s*$")
        ::continue::
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
