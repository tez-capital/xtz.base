local backend = am.app.get_configuration("backend", os.getenv("ASCEND_SERVICES") ~= nil and "ascend" or "systemd")

local service_manager = nil
if backend == "ascend" then
	local ok, asctl = am.plugin.safe_get("asctl")
	ami_assert(ok, "Failed to load asctl plugin")
	service_manager = asctl
else
	local ok, systemctl = am.plugin.safe_get("systemctl")
	ami_assert(ok, "Failed to load systemctl plugin")
	service_manager = systemctl
end

return service_manager