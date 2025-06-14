assert(fs.EFS, "eli.fs.extra required")

local _, _ = fs.remove("bin", { content_only = true, recurse = true, follow_links = true })
local ok, err = fs.mkdirp("bin")
ami_assert(ok, string.join_strings("Failed to prepare bin dir: ", err), EXIT_APP_IO_ERROR)

local function download(url, dst)
    local tmp_file = os.tmpname()
    local ok, err = net.download_file(url, tmp_file, {follow_redirects = true})
    if not ok then
        fs.remove(tmp_file)
        ami_error("Failed to download: " .. tostring(err))
    end
    ami_assert(fs.copy_file(tmp_file, dst), "Failed to copy downloaded file into '" .. tostring(dst) .. "'!")
	fs.remove(tmp_file)
end

local wanted_binaries = am.app.get_model("WANTED_BINARIES")
ami_assert(type(wanted_binaries) == "table", "Invalid list of wanted binaries!")

local download_urls = am.app.get_model("DOWNLOAD_URLS")
ami_assert(type(download_urls) == "table", "Invalid download URLs!")

for _, binary_name in ipairs(wanted_binaries) do
	local source_url = download_urls[binary_name]
	-- next binaries are optional
	ami_assert(type(source_url) == "string" or binary_name:match("next"), "Missing source URL of " .. binary_name .. "!")
	if type(source_url) == "string" then
		log_info("Downloading " .. binary_name .. "...")
		download(source_url, "bin/" .. binary_name)
	end
end

local files, err = fs.read_dir("bin", { return_full_paths = true }) --[=[@as string[]]=]
ami_assert(files, "Failed to enumerate binaries", EXIT_APP_IO_ERROR)

for _, file in ipairs(files) do 
    if fs.file_type(file) == 'file' then 
        local ok, err = fs.chmod(file, "rwxr-xr-x")
        ami_assert(ok, "failed to set file permissions for " .. file .. " - " .. tostring(err), EXIT_APP_IO_ERROR)
    end
end