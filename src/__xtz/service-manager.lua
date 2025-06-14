local backend = am.app.get_configuration("backend", os.getenv("ASCEND_SERVICES") ~= nil and "ascend" or "systemd")

local system_distro = am.app.get_model("SYSTEM_DISTRO", "unknown")

local service_manager = {}
if backend == "ascend" then
	local asctl, err = am.plugin.get("asctl")
	ami_assert(asctl, "Failed to load asctl plugin - " .. tostring(err), EXIT_PLUGIN_LOAD_ERROR)
	service_manager = asctl
elseif system_distro == "MacOS" then
	local launchctl, err = am.plugin.get("launchctl")
	ami_assert(launchctl, "Failed to load launchctl plugin - " .. tostring(err), EXIT_PLUGIN_LOAD_ERROR)
	service_manager = launchctl.with_options({
		setup_newsyslog = true
	})
else
	local systemctl, err = am.plugin.get("systemctl")
	ami_assert(systemctl, "Failed to load systemctl plugin - " .. tostring(err), EXIT_PLUGIN_LOAD_ERROR)
	service_manager = systemctl
end

local default_system_backend = system_distro == "MacOS" and "launchd" or "systemd"

---@param services_definition table<string, string>
---@param backend string
function service_manager.install_services(services_definition, backend)
	local backend = am.app.get_configuration("backend", backend and "ascend" or default_system_backend)

	local service_file_extension = "service"
	if backend == "ascend" then
		service_file_extension = "ascend.hjson"
	elseif backend == "launchd" then
		service_file_extension = "plist"
	end

	for k, v in pairs(services_definition) do
		local service_id = k
		local source_file = string.interpolate("${file}.${extension}", {
			file = v,
			extension = service_file_extension
		})
		local ok, err = service_manager.safe_install_service(source_file, service_id)
		ami_assert(ok, "failed to install " .. service_id .. ".service " .. (err or ""))
	end
end

---@param names string[]
function service_manager.remove_services(names)
	for _, service in ipairs(names) do
		if type(service) ~= "string" then goto CONTINUE end
		local ok, err = service_manager.safe_remove_service(service)
		ami_assert(ok, "failed to remove service '" .. service .. "': " .. tostring(err))
		::CONTINUE::
	end
end

return service_manager