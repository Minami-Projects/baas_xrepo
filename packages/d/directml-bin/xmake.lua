-- DirectML Binaries xmake package definition
-- inspired by directml-bin from MaaDeps
-- @MaaAssistantArknights/MaaDeps/files/vcpkg-overlay/ports/directml-bin
package("directml-bin")
    set_homepage("https://www.nuget.org/packages/Microsoft.AI.DirectML")
    set_description("DirectML (standalone) - High-performance, hardware-accelerated DirectX 12 machine learning library.")
    set_license("MIT")

    set_urls("https://www.nuget.org/api/v2/package/Microsoft.AI.DirectML/$(version)", {alias = "nupkg"})

    add_versions("1.15.4", "4e7cb7ddce8cf837a7a75dc029209b520ca0101470fcdf275c1f49736a3615b9")

    on_download(function (package, opt)
        import("net.http")
        import("utils.archive")

        local url = opt.url
        local sourcedir = opt.sourcedir
        local packagefile = path.filename(url)
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
        archive.extract(packagefile, sourcedir_tmp)
        os.mv(sourcedir_tmp, sourcedir)
        os.rm(sourcedir_tmp)

        -- save original file path
        package:originfile_set(path.absolute(packagefile))
    end)

    on_install(function (package)
        import("utils.archive")
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
        os.cp("source/include", package:installdir("include"))

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

    on_test(function (package)
        assert(package:has_cfuncs("DMLCreateDevice", {includes = "DirectML.h"}))
    end)