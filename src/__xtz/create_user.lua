local user = am.app.get("user", "root")
ami_assert(type(user) == "string", "user not specified...", EXIT_INVALID_CONFIGURATION)

local system_os = am.app.get_model("SYSTEM_OS", "unknown")
ami_assert(system_os == "unix", "only unix-like platforms are supported right now", EXIT_UNSUPPORTED_PLATFORM)

local user_plugin, err = am.plugin.get("user")
ami_assert(user_plugin, "failed to load user plugin - " .. tostring(err), EXIT_PLUGIN_LOAD_ERROR)

log_info("checking user '" .. user .. "' availability...")
local ok = user_plugin.add(user, { disable_login = true, disable_password = true, gecos = "" })
ami_assert(ok, "failed to create user - " .. user)

local ok = user_plugin.add_group(user)
ami_assert(ok, "failed to create group - " .. user)