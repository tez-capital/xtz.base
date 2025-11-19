local utils = {}

function utils.setup_file_ownership()
	local user = am.app.get("user", "root")
	ami_assert(type(user) == "string", "user not specified...", EXIT_INVALID_CONFIGURATION)

	local uid, err = fs.getuid(user)
	ami_assert(uid, "failed to get " .. user .. "uid - " .. tostring(err))

    local custom_ownership = am.app.get_model("CUSTOM_FILE_OWNERSHIP", {})
    ami_assert(type(custom_ownership) == "table", "invalid CUSTOM_FILE_OWNERSHIP configuration")

	log_info("Granting access to " .. user .. "(" .. tostring(uid) .. ")...")
	local ok, error = fs.chown(os.cwd(), uid, uid, { recurse = true, recurse_ignore_errors = true, filter = function(path)
        if custom_ownership[path] ~= nil then
            return false
        end
        return true
    end })
    ami_assert(ok, "failed to chown data - " .. (error or ""))

    for path, ownership in pairs(custom_ownership) do
        if not fs.exists(path) then
            goto continue
        end
        local custom_uid, err = fs.getuid(ownership.user)
        ami_assert(custom_uid, "failed to get " .. ownership.user .. " uid - " .. tostring(err))
        local custom_gid, err = fs.getgid(ownership.group)
        ami_assert(custom_gid, "failed to get " .. ownership.group .. " gid - " .. tostring(err))
        log_info("Setting custom ownership for " .. path .. " to " .. ownership.user .. "(" .. tostring(custom_uid) .. "):" .. ownership.group .. "(" .. tostring(custom_gid) .. ")")
        local ok, error = fs.chown(path, custom_uid, custom_gid, { recurse = true, recurse_ignore_errors = true })
        ami_assert(ok, "failed to chown " .. path .. " - " .. (error or ""))
        ::continue::
    end	
end

function utils.setup_file_permissions()
    utils.setup_file_ownership()

    local custom_ownership = am.app.get_model("CUSTOM_FILE_PERMISSIONS", {})
    ami_assert(type(custom_ownership) == "table", "invalid CUSTOM_FILE_PERMISSIONS configuration")
    for path, permissions in pairs(custom_ownership) do
        if not fs.exists(path) then
            goto continue
        end
        log_info("Setting custom permissions for " .. path .. " to " .. permissions)
        local ok, error = fs.chmod(path, permissions, { recurse = true })
        ami_assert(ok, "failed to chmod " .. path .. " - " .. (error or ""))
        ::continue::
    end
end

-- Converts URLs to "host:port" format as described:
-- should be used only for RPC_ADDR and REMOTE_SIGNER_ADDR
-- "http://127.0.0.1/"        -> "127.0.0.1:80"
-- "https://127.0.0.1/"       -> "127.0.0.1:443"
-- "http://127.0.0.1:2090/"   -> "127.0.0.1:2090"
-- "127.0.0.1:90"             -> "127.0.0.1:90"
---@param input string
---@return string
function utils.extract_host_and_port(input, default_port)
    if not input or input == "" then
        return input
    end
    -- Try to match URLs starting with "http://" or "https://"
    local protocol, host, port = string.match(input, "^(https?)://([^/:]+):?(%d*)")
    if protocol then
        -- Assign the default port when no port is provided
        if port == "" then
            if protocol == "http" then
                port = "80"
            elseif protocol == "https" then
                port = "443"
            end
        end
        return host .. ":" .. port
    else
        -- For strings without http(s)://, try matching a host:port pattern
        local host_only, port_only = string.match(input, "^([^/:]+):(%d+)")
        if host_only and port_only then
            return host_only .. ":" .. port_only
        else
            -- If the input doesn't match expected patterns, return it unchanged.
            local port_suffix = default_port and ":" .. default_port or ""
            return input .. port_suffix
        end
    end
end

return utils
