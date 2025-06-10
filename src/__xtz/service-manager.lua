local backend = am.app.get_configuration("backend", os.getenv("ASCEND_SERVICES") ~= nil and "ascend" or "systemd")

local platform_plugin, err = am.plugin.get("platform")
ami_assert(platform_plugin, "Failed to load platform plugin - " .. tostring(err), EXIT_PLUGIN_LOAD_ERROR)

local identified, platform = platform_plugin.get_platform()
ami_assert(identified, "Failed to identify platform - " .. tostring(platform), EXIT_PLATFORM_IDENTIFICATION_ERROR)
ami_assert(platform.OS == "unix", "Only unix-like platforms are supported", EXIT_UNSUPPORTED_PLATFORM)

local service_manager = nil
if backend == "ascend" then
	local asctl, err = am.plugin.get("asctl")
	ami_assert(asctl, "Failed to load asctl plugin - " .. tostring(err), EXIT_PLUGIN_LOAD_ERROR)
	service_manager = asctl
else
	if platform.DISTRO == "MacOS" then
		local launchctl, err = am.plugin.get("launchctl")
		ami_assert(launchctl, "Failed to load launchctl plugin - " .. tostring(err), EXIT_PLUGIN_LOAD_ERROR)
		service_manager = launchctl
	else
		local systemctl, err = am.plugin.get("systemctl")
		ami_assert(systemctl, "Failed to load systemctl plugin - " .. tostring(err), EXIT_PLUGIN_LOAD_ERROR)
		service_manager = systemctl
	end
end

return service_manager