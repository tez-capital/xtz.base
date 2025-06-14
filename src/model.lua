local platform_plugin, err = am.plugin.get("platform")
ami_assert(platform_plugin, "failed to load platform plugin - " .. tostring(err), EXIT_PLUGIN_LOAD_ERROR)

local identified, platform = platform_plugin.get_platform()
ami_assert(identified, "failed to identify platform - " .. tostring(platform), EXIT_PLATFORM_IDENTIFICATION_ERROR)

am.app.set_model(
    {
        SYSTEM_OS = platform.OS,
        SYSTEM_DISTRO = platform.DISTRO,
        SYSTEM_TYPE = platform.SYSTEM_TYPE,
    },
    { merge = true, overwrite = true }
)