assert(fs.EFS, "eli.fs.extra required")

local _, _ = fs.safe_remove("bin", { contentOnly = true, recurse = true, followLinks = true })
local _ok, _error = fs.safe_mkdirp("bin")
ami_assert(_ok, string.join_strings("Failed to prepare bin dir: ", _error), EXIT_APP_IO_ERROR)

local function _download(url, dst, options)
    local _tmpFile = os.tmpname()
    local _ok, _error = net.safe_download_file(url, _tmpFile, {followRedirects = true})
    if not _ok then
        fs.remove(_tmpFile)
        ami_error("Failed to download: " .. tostring(_error))
    end
    ami_assert(fs.safe_copy_file(_tmpFile, dst), "Failed to copy downloaded file into '" .. tostring(dst) .. "'!")
	fs.safe_remove(_tmpFile)
end

local _wantedBinaries = am.app.get_model("WANTED_BINARIES")
ami_assert(type(_wantedBinaries) == "table", "Invalid list of wanted binaries!")

local _urls = am.app.get_model("DOWNLOAD_URLS")
ami_assert(type(_urls) == "table", "Invalid download URLs!")

for _, _binaryName in ipairs(_wantedBinaries) do 
	local _source = _urls[_binaryName]
	-- next binaries are optional
	ami_assert(type(_source) == "string" or _binaryName:match("next"), "Missing source URL of " .. _binaryName .. "!")
	if type(_source) == "string" then
		log_info("Downloading " .. _binaryName .. "...")
		_download(_source, "bin/" .. _binaryName)
	end
end

local _ok, _files = fs.safe_read_dir("bin", { returnFullPaths = true})
ami_assert(_ok, "Failed to enumerate binaries", EXIT_APP_IO_ERROR)

for _, file in ipairs(_files) do 
    if fs.file_type(file) == 'file' then 
        local _ok, _error = fs.safe_chmod(file, "rwxrwxrwx")
        if not _ok then 
            ami_error("Failed to set file permissions for " .. file .. " - " .. _error, EXIT_APP_IO_ERROR)
        end
    end
end