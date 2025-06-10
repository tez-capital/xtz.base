local user = am.app.get("user", "root")
ami_assert(type(user) == "string", "User not specified...", EXIT_INVALID_CONFIGURATION)

local platform_plugin, err = am.plugin.get("platform")
ami_assert(platform_plugin, "Failed to load platform plugin - " .. tostring(err), EXIT_PLUGIN_LOAD_ERROR)

local identified, platform = platform_plugin.get_platform()
ami_assert(identified, "Failed to identify platform - " .. tostring(platform), EXIT_PLATFORM_IDENTIFICATION_ERROR)
ami_assert(platform.OS == "unix", "Only unix-like platforms are supported", EXIT_UNSUPPORTED_PLATFORM)

local user_plugin, err = am.plugin.get("user")
ami_assert(user_plugin, "Failed to load user plugin - " .. tostring(err), EXIT_PLUGIN_LOAD_ERROR)

log_info("Checking user '" .. user .. "' availability...")
local ok = user_plugin.add(user, { disable_login = true, disable_password = true, gecos = "" })
ami_assert(ok, "Failed to create user - " .. user)