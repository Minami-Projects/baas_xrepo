-- TensorRT pre-built SDK xmake package definition
-- Downloads official NVIDIA TensorRT binaries for Linux and Windows
package("tensorrt-bin")
    set_homepage("https://developer.nvidia.com/tensorrt")
    set_description("NVIDIA TensorRT - High-performance deep learning inference optimizer and runtime.")

    -- dummy URL so xmake has something; actual download is handled by on_download
    set_urls("https://developer.nvidia.com/tensorrt")
    add_versions("10.14.1", "ignore")

    on_download(function (package, opt)
        import("net.http")
        import("utils.archive")

        local version = package:version_str()
        local url, filename

        if package:is_plat("linux") then
            -- full build version: 10.14.1 -> 10.14.1.48
            url = format("https://developer.nvidia.com/downloads/compute/machine-learning/tensorrt/%s/tars/TensorRT-%s.48.Linux.x86_64-gnu.cuda-12.9.tar.gz", version, version)
            filename = format("TensorRT-%s.48.Linux.x86_64-gnu.cuda-12.9.tar.gz", version)
        elseif package:is_plat("windows") then
            url = format("https://developer.nvidia.com/downloads/compute/machine-learning/tensorrt/%s/zip/TensorRT-%s.48.Windows.win10.cuda-12.9.zip", version, version)
            filename = format("TensorRT-%s.48.Windows.win10.cuda-12.9.zip", version)
        else
            raise("tensorrt-bin: unsupported platform %s", package:plat())
        end

        local sourcedir = opt.sourcedir
        local packagefile = path.join(path.directory(sourcedir), filename)

        -- download if not cached
        if not os.isfile(packagefile) then
            os.tryrm(packagefile)
            print("downloading %s ...", url)
            http.download(url, packagefile)
        end

        -- extract
        local sourcedir_tmp = sourcedir .. ".tmp"
        os.rm(sourcedir_tmp)
        if not archive.extract(packagefile, sourcedir_tmp) then
            raise("failed to extract: %s", packagefile)
        end
        os.rm(sourcedir)
        os.mv(sourcedir_tmp, sourcedir)
        os.rm(sourcedir_tmp)

        package:originfile_set(path.absolute(packagefile))
    end)

    on_install("linux", function (package)
        -- TensorRT tar extracts to TensorRT-<version>/ subdirectory
        local trt_dir
        for _, dir in ipairs(os.dirs("TensorRT-*")) do
            trt_dir = dir
            break
        end
        if not trt_dir then trt_dir = "." end

        os.cp(path.join(trt_dir, "include", "*"), package:installdir("include"))
        os.cp(path.join(trt_dir, "lib", "*"), package:installdir("lib"))

        package:add("links", "nvinfer", "nvinfer_plugin", "nvonnxparser")
    end)

    on_install("windows", function (package)
        local trt_dir
        for _, dir in ipairs(os.dirs("TensorRT-*")) do
            trt_dir = dir
            break
        end
        if not trt_dir then trt_dir = "." end

        os.cp(path.join(trt_dir, "include", "*"), package:installdir("include"))
        os.cp(path.join(trt_dir, "lib", "*.lib"), package:installdir("lib"))
        os.cp(path.join(trt_dir, "lib", "*.dll"), package:installdir("bin"))

        package:add("links", "nvinfer_10", "nvinfer_plugin_10", "nvonnxparser_10")
    end)
