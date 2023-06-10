local _user = am.app.get("user", "root")
ami_assert(type(_user) == "string", "User not specified...", EXIT_INVALID_CONFIGURATION)

local _ok, _userPlugin = am.plugin.safe_get("user")
ami_assert(_ok, "Failed to load user plugin - " .. tostring(_userPlugin), EXIT_PLUGIN_LOAD_ERROR)

log_info("Checking user '" .. _user .. "' availability...")
local _ok = _userPlugin.add(_user, { disableLogin = true, disablePassword = true, gecos = "" })
ami_assert(_ok, "Failed to create user - " .. _user)