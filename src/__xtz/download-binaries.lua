assert(fs.EFS, "eli.fs.extra required")

-- local _, _ = fs.remove("bin", { content_only = true, recurse = true, follow_links = true })
local ok, err = fs.mkdirp("bin")
ami_assert(ok, string.join_strings("Failed to prepare bin dir: ", err), EXIT_APP_IO_ERROR)

local function download(url, dst)
    local tmp_file = os.tmpname()
    local ok, err = net.download_file(url, tmp_file, { follow_redirects = true })
    if not ok then
        fs.remove(tmp_file)
        ami_error("Failed to download: " .. tostring(err))
    end
    ami_assert(fs.copy_file(tmp_file, dst), "Failed to copy downloaded file into '" .. tostring(dst) .. "'!")
    fs.remove(tmp_file)
end

-- download url into dst and verify sha256, returning ok, err (never raises)
local function try_download(url, dst, sha256)
    local tmp_file = os.tmpname()
    local ok, err = net.download_file(url, tmp_file, { follow_redirects = true })
    if not ok then
        fs.remove(tmp_file)
        return false, "download failed: " .. tostring(err)
    end
    if sha256 and not hash.equals(fs.hash_file(tmp_file, { hex = true }), sha256) then
        fs.remove(tmp_file)
        return false, "invalid SHA256"
    end
    if not fs.copy_file(tmp_file, dst) then
        fs.remove(tmp_file)
        return false, "failed to copy into '" .. tostring(dst) .. "'"
    end
    fs.remove(tmp_file)
    return true
end

local wanted_binaries = am.app.get_model("WANTED_BINARIES")
ami_assert(type(wanted_binaries) == "table", "Invalid list of wanted binaries!")

local download_urls = am.app.get_model("DOWNLOAD_URLS")
ami_assert(type(download_urls) == "table", "Invalid download URLs!")

for _, binary_name in ipairs(wanted_binaries) do
    local source = download_urls[binary_name]
    -- next binaries are optional
    if type(source) == "string" then
        log_info("Downloading " .. binary_name .. "...")
        download(source, "bin/" .. binary_name)
    elseif type(source) == "table" then
        local sha256 = source.sha256
        local dst = "bin/" .. binary_name
        local existing = fs.hash_file(dst, { hex = true })
        if sha256 and existing and hash.equals(existing, sha256, true) then
            log_info("Skipping " .. binary_name .. " (already downloaded)")
            goto continue
        end

        -- build ordered list of candidate urls: preferred mirror first, then primary, then remaining mirrors
        local candidates = {}
        local function add(name, url)
            if type(url) == "string" and #url > 0 then
                table.insert(candidates, { name = name, url = url })
            end
        end
        local mirror_name = os.getenv("OCTEZ_RELEASES_MIRROR")
        local mirrors = type(source.mirrors) == "table" and source.mirrors or {}
        if mirror_name and #mirror_name > 0 then
            add(mirror_name, mirrors[mirror_name])
        else
            add("primary", source.url)
            for name, url in pairs(mirrors) do
                add(name, url)
            end
        end
        ami_assert(#candidates > 0, "No valid URL of " .. binary_name .. "!")

        local downloaded = false
        for _, candidate in ipairs(candidates) do
            log_info("Downloading " .. binary_name .. " from " .. candidate.name .. "...")
            local ok, err = try_download(candidate.url, dst, sha256)
            if ok then
                downloaded = true
                break
            end
            log_warn("Failed to download " .. binary_name .. " from " .. candidate.name .. ": " .. tostring(err))
        end
        ami_assert(downloaded, "Failed to download " .. binary_name .. " from all sources!")
    else
        ami_error("Invalid source URL of " .. binary_name .. "!")
    end
    ::continue::
end

local files, err = fs.read_dir("bin", { return_full_paths = true }) --[=[@as string[]]=]
ami_assert(files, "Failed to enumerate binaries - " .. tostring(err), EXIT_APP_IO_ERROR)

for _, file in ipairs(files) do
    if fs.file_type(file) == 'file' then
        local ok, err = fs.chmod(file, "rwxr-xr-x")
        ami_assert(ok, "failed to set file permissions for " .. file .. " - " .. tostring(err), EXIT_APP_IO_ERROR)
    end
end
