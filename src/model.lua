local platform_plugin, err = am.plugin.get("platform")
ami_assert(platform_plugin, "failed to load platform plugin - " .. tostring(err), EXIT_PLUGIN_LOAD_ERROR)

local identified, platform = platform_plugin.get_platform()
ami_assert(identified, "failed to identify platform - " .. tostring(platform), EXIT_PLATFORM_IDENTIFICATION_ERROR)

local download_links = hjson.parse(fs.read_file("__xtz/sources.hjson"))

-- Select platform
local platform_key = nil
if platform.OS == "unix" then
    if platform.DISTRO == "MacOS" then
        platform_key = "darwin-arm64"
    else
        platform_key = "linux-x86_64"
        if platform.SYSTEM_TYPE:match("[Aa]arch64") then
            platform_key = "linux-arm64"
        end
    end
end
ami_assert(platform_key ~= nil,
    "no platform found for: " .. platform.OS .. " " .. platform.DISTRO .. " " .. platform.SYSTEM_TYPE)

local download_urls = download_links[platform_key]
ami_assert(download_urls ~= nil, "no download URLs found for platform: " .. platform_key)

-- Merge with update sources if available (per-binary version comparison)
local update_content = fs.read_file("__xtz/sources.update.hjson")
if update_content then
    local update_sources = hjson.parse(update_content)
    if update_sources and update_sources[platform_key] then
        local update_platform = update_sources[platform_key]
        for binary_name, update_entry in pairs(update_platform) do
            if type(update_entry) == "table" and update_entry.version then
                local base_entry = download_urls[binary_name]
                local base_version = (type(base_entry) == "table" and base_entry.version) or "0.0.0"
                -- ver.compare: returns 1 if v1 > v2
                if ver.compare(update_entry.version, base_version) > 0 then
                    log_debug("Using updated " ..
                        binary_name .. " (version " .. update_entry.version .. " > " .. base_version .. ")")
                    download_urls[binary_name] = update_entry
                end
            end
        end
    end
end

am.app.set_model(
    {
        SYSTEM_OS = platform.OS,
        SYSTEM_DISTRO = platform.DISTRO,
        SYSTEM_TYPE = platform.SYSTEM_TYPE,
        DOWNLOAD_URLS = util.merge_tables(download_urls, am.app.get_configuration("SOURCES", {})),
    },
    { merge = true, overwrite = true }
)
