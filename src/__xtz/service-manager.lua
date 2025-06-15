local system_distro = am.app.get_model("SYSTEM_DISTRO", "unknown")
local default_system_backend = system_distro == "MacOS" and "launchd" or "systemd"
local backend = am.app.get_configuration("backend",
	os.getenv("SERVICE_BACKEND") ~= nil and "ascend" or default_system_backend)

local service_manager = {}
local service_file_extension = "service"
if backend == "ascend" then
	local asctl, err = am.plugin.get("asctl")
	ami_assert(asctl, "Failed to load asctl plugin - " .. tostring(err), EXIT_PLUGIN_LOAD_ERROR)
	service_manager = asctl
	service_file_extension = "ascend.hjson"
elseif system_distro == "MacOS" then
	local launchctl, err = am.plugin.get("launchctl")
	ami_assert(launchctl, "Failed to load launchctl plugin - " .. tostring(err), EXIT_PLUGIN_LOAD_ERROR)
	service_manager = launchctl.with_options({
		setup_newsyslog = true
	})
	service_file_extension = "plist"
else
	local systemctl, err = am.plugin.get("systemctl")
	ami_assert(systemctl, "Failed to load systemctl plugin - " .. tostring(err), EXIT_PLUGIN_LOAD_ERROR)
	service_manager = systemctl
end

---@param services_definition table<string, string>
---@param backend string
function service_manager.install_services(services_definition)
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

---@param names string[]|table<string, string>
function service_manager.start_services(names)
	for _, service in pairs(names) do
		-- skip false values
		if type(service) ~= "string" then
			log_warn("skipping invalid service name: " .. tostring(service) .. ", type: " .. type(service))
			goto CONTINUE
		end
		local ok, err = service_manager.safe_start_service(service)
		ami_assert(ok, "Failed to start " .. service .. ": " .. (err or ""))
		::CONTINUE::
	end
end

---@param names string[]|table<string, string>
function service_manager.stop_services(names)
	for _, service in pairs(names) do
		-- skip false values
		if type(service) ~= "string" then
			log_warn("skipping invalid service name: " .. tostring(service) .. ", type: " .. type(service))
			goto CONTINUE
		end
		local ok, err = service_manager.safe_stop_service(service)
		ami_assert(ok, "Failed to start " .. service .. ": " .. (err or ""))
		::CONTINUE::
	end
end

---@param names string[]|table<string, string>
---@return table<string, { status: string, started: string }> statuses
---@return boolean are_all_running
function service_manager.get_services_status(names)
	local result = {}
	local all_running = true
	for k, service in pairs(names) do
		if type(service) ~= "string" then
			log_warn("skipping invalid service name: " .. tostring(service) .. ", type: " .. type(service))
			goto CONTINUE
		end
		local ok, status, started = service_manager.safe_get_service_status(service)
		ami_assert(ok, "failed to get status of " .. service .. " - " .. tostring(status or ""), EXIT_PLUGIN_EXEC_ERROR)
		local alias = service
		if type(k) == "string" then alias = k end
		result[alias] = {
			status = status,
			started = started
		}
		if status ~= "running" then
			all_running = false
		end
		::CONTINUE::
	end
	return result, all_running
end

---@param names string[]|table<string, string>
---@param expected_status string
---@return boolean
function service_manager.has_any_service_status(names, expected_status)
	for _, service in pairs(names) do
		if type(service) ~= "string" then
			log_warn("skipping invalid service name: " .. tostring(service) .. ", type: " .. type(service))
			goto CONTINUE
		end
		local _, status, _ = service_manager.safe_get_service_status(service)
		if status == expected_status then
			return true
		end
		::CONTINUE::
	end
end

---@param names string[]|table<string, string>
---@param expected_status string
---@return boolean
function service_manager.have_all_services_status(names, expected_status)
	for _, service in pairs(names) do
		if type(service) ~= "string" then
			log_warn("skipping invalid service name: " .. tostring(service) .. ", type: " .. type(service))
			goto CONTINUE
		end
		local _, status, _ = service_manager.safe_get_service_status(service)
		if status ~= expected_status then
			return false
		end
		::CONTINUE::
	end
	return true
end

---@param names string[]|table<string, string>
function service_manager.remove_services(names)
	for _, service in pairs(names) do
		if type(service) ~= "string" then goto CONTINUE end
		local ok, err = service_manager.safe_remove_service(service)
		ami_assert(ok, "failed to remove service '" .. service .. "': " .. tostring(err))
		::CONTINUE::
	end
end

---@param names string[]|table<string, string>
---@param options? table
function service_manager.logs(names, options)
	if type(options) ~= "table" then
		options = {}
	end

	---// TODO: ascend logs
	if backend == "launchd" then
		local log_dir = "/usr/local/var/log/"
		local follow = options.follow
		local seek_end = options["end"]
		local streams = {}

		-- Open all log files as non-blocking streams
		for _, v in pairs(names) do
			local log_path = log_dir .. v .. ".log"
			local f = io.open_fstream(log_path, "r")
			if f then
				f:set_nonblocking(true)
				if seek_end then
					f:seek("end")
				end
				table.insert(streams, { name = v, f = f })
			end
		end

		while true do
			local any_read = false
			for _, s in ipairs(streams) do
				while true do
					local line = s.f:read("l")
					if not line then
						break
					end
					any_read = true
					print("[" .. s.name .. "] " .. line)
				end
			end
			if not follow then
				break
			end
			if not any_read then
				os.sleep(10, "ms")
			end
		end
		return
	end

	local journalctl_args = { "journalctl" }
	if options.follow then table.insert(journalctl_args, "-f") end
	if options['end'] then table.insert(journalctl_args, "-e") end
	if options.since then
		table.insert(journalctl_args, "--since")
		table.insert(journalctl_args, '"' .. tostring(options.since) .. '"')
	end
	if options["until"] then
		table.insert(journalctl_args, "--until")
		table.insert(journalctl_args, '"' .. tostring(options["until"]) .. '"')
	end
	for _, v in pairs(names) do
		table.insert(journalctl_args, "-u")
		table.insert(journalctl_args, v)
	end

	os.execute(string.join(" ", table.unpack(journalctl_args)))
end

return service_manager
