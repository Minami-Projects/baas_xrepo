-- DirectML Binaries xmake package definition
-- inspired by directml-bin from MaaDeps
-- @MaaAssistantArknights/MaaDeps/files/vcpkg-overlay/ports/directml-bin

local function _baas_release_base(package)
    local tag = package:config("prebuilt_tag") or "latest"
    if tag == "latest" then
        return "https://github.com/Nanboom233/baas_xrepo/releases/latest/download"
    end
    return "https://github.com/Nanboom233/baas_xrepo/releases/download/" .. tag
end

local function _baas_try_install_prebuilt(package)
    if package:config("source") or not package:is_plat("windows") then
        return false
    end

    local arch_map = {
        ["x64"] = "x64",
        ["x86"] = "x86",
        ["arm64"] = "arm64"
    }
    local arch = arch_map[package:arch()] or package:arch()
    local mode = package:debug() and "debug" or "release"
    local version = tostring(package:version()):gsub("^v", "")
    local asset_name = string.format("%s-%s-windows-%s-%s.zip", package:name(), version, arch, mode)
    local asset_path = path.absolute(asset_name)
    local extract_dir = path.join(os.tmpdir(), package:name() .. "-" .. arch .. "-" .. mode)
    local url = _baas_release_base(package) .. "/" .. asset_name

    import("net.http")
    import("utils.archive")

    local ok = try {
        function ()
            os.tryrm(asset_path)
            http.download(url, asset_path)
        end
    }

    if not ok then
        cprint("${yellow}[baas-xrepo] prebuilt asset unavailable, fallback to upstream binary: %s", url)
        return false
    end

    os.rm(extract_dir)
    if not archive.extract(asset_path, extract_dir) then
        raise("failed to extract prebuilt package archive: %s", asset_path)
    end

    os.cp(path.join(extract_dir, "*"), package:installdir())
    return true
end

package("directml-bin")
    set_homepage("https://www.nuget.org/packages/Microsoft.AI.DirectML")
    set_description("DirectML (standalone) - High-performance, hardware-accelerated DirectX 12 machine learning library.")
    set_license("MIT")

    set_urls("https://www.nuget.org/api/v2/package/Microsoft.AI.DirectML/$(version)", {alias = "nupkg"})

    add_versions("1.15.4", "4e7cb7ddce8cf837a7a75dc029209b520ca0101470fcdf275c1f49736a3615b9")

    add_configs("source", {description = "Download from the upstream NuGet package instead of BAAS release artifacts.", default = false, type = "boolean"})
    add_configs("prebuilt_tag", {description = "GitHub release tag that stores prebuilt assets. Use latest to track the newest release.", default = "latest", type = "string"})

    on_download(function (package, opt)
        import("net.http")
        import("utils.archive")

        local url = opt.url
        local sourcedir = opt.sourcedir
        local packagefile = package:name() .. ".zip"
        local sourcehash = package:sourcehash(opt.url_alias)

        local cached = true
        if not os.isfile(packagefile) or sourcehash ~= hash.sha256(packagefile) then
            cached = false

            -- attempt to remove package file first
            os.tryrm(packagefile)
            http.download(url, packagefile)

            -- check hash
            if sourcehash and sourcehash ~= hash.sha256(packagefile) then
                raise("unmatched checksum, current hash(%s) != original hash(%s)", hash.sha256(packagefile):sub(1, 8), sourcehash:sub(1, 8))
            end
        end

        -- extract package file
        local sourcedir_tmp = sourcedir .. ".tmp"
        os.rm(sourcedir_tmp)
        if not archive.extract(packagefile, sourcedir_tmp) then
            raise("failed to extract package file: %s", packagefile)
        end
        os.rm(sourcedir)
        os.mv(sourcedir_tmp, sourcedir)
        os.rm(sourcedir_tmp)

        -- save original file path
        package:originfile_set(path.absolute(packagefile))
    end)

    on_install(function (package)
        if _baas_try_install_prebuilt(package) then
            return
        end

        local arch_map = {
            ["x64"] = "x64-win",
            ["x86"] = "x86-win",
            ["arm64"] = "arm64-win"
        }

        local nuget_arch = arch_map[package:arch()]
        if not nuget_arch then
            raise("Unsupported architecture: " .. package:arch())
        end

        -- install to include/
        os.cp("include", package:installdir())

        local bin_source = path.join("bin", nuget_arch)

        -- install library
        os.cp(path.join(bin_source, "*.lib"), package:installdir("lib"))

        -- copy dlls and pdbs to bin/
        os.cp(path.join(bin_source, "*.dll"), package:installdir("bin"))
        os.cp(path.join(bin_source, "*.pdb"), package:installdir("bin"))

        -- install copyright
        os.cp("LICENSE.txt", package:installdir("share/directml-bin/copyright"))

        -- add links config
        package:add("links", "DirectML")
    end)
