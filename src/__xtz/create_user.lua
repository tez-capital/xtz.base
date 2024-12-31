local user = am.app.get("user", "root")
ami_assert(type(user) == "string", "User not specified...", EXIT_INVALID_CONFIGURATION)

local ok, user_plugin = am.plugin.safe_get("user")
ami_assert(ok, "Failed to load user plugin - " .. tostring(user_plugin), EXIT_PLUGIN_LOAD_ERROR)

log_info("Checking user '" .. user .. "' availability...")
local ok = user_plugin.add(user, { disable_login = true, disable_password = true, gecos = "" })
ami_assert(ok, "Failed to create user - " .. user)