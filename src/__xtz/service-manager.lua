local backend = am.app.get_configuration("backend", os.getenv("ASCEND_SERVICES") ~= nil and "ascend" or "systemd")

local serviceManager = nil
if backend == "ascend" then
	local ok, asctl = am.plugin.safe_get("asctl")
	ami_assert(ok, "Failed to load asctl plugin")
	serviceManager = asctl
else
	local ok, systemctl = am.plugin.safe_get("systemctl")
	ami_assert(ok, "Failed to load systemctl plugin")
	serviceManager = systemctl
end

return serviceManager