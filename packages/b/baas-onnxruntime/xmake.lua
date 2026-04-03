-- onnxruntime with DirectML, CUDA, or CoreML support xmake package definition
-- inspired by maa-onnxruntime from MaaDeps
-- @MaaAssistantArknights/MaaDeps/files/vcpkg-overlay/ports/maa-onnxruntime
-- most copied from official onnxruntime xmake package
-- @xmake-io/xmake-repo/blob/4cfbaa42adc11fcfe6c3efe9136ac2a30025c83a/packages/o/onnxruntime/xmake.lua

local function _baas_prebuilt_plat(package)
    if package:is_plat("windows") then
        return "windows"
    elseif package:is_plat("linux") then
        return "linux"
    elseif package:is_plat("macosx") then
        return "macos"
    end
end

local function _baas_prebuilt_arch(package)
    if package:is_arch("x86_64", "x64") then
        return "x64"
    elseif package:is_arch("arm64") then
        return "arm64"
    end
    return package:arch()
end

local function _baas_prebuilt_mode(package)
    return package:debug() and "debug" or "release"
end

local function _baas_prebuilt_version(package)
    return tostring(package:version()):gsub("^v", "")
end

local function _baas_release_base(package)
    local tag = package:config("prebuilt_tag") or "latest"
    if tag == "latest" then
        return "https://github.com/Nanboom233/baas_xrepo/releases/latest/download"
    end
    return "https://github.com/Nanboom233/baas_xrepo/releases/download/" .. tag
end

local function _baas_prebuilt_variant(package)
    if package:is_plat("windows") and package:config("directml") then
        return "directml"
    end
    return "cpu"
end

local function _baas_try_install_prebuilt(package)
    if package:config("source") or package:config("cuda") or package:config("tensorrt") then
        return false
    end

    local plat = _baas_prebuilt_plat(package)
    if not plat then
        return false
    end

    local arch = _baas_prebuilt_arch(package)
    local mode = _baas_prebuilt_mode(package)
    local version = _baas_prebuilt_version(package)
    local variant = _baas_prebuilt_variant(package)
    local ext = package:is_plat("windows") and "zip" or "tar.gz"
    local asset_name = string.format("%s-%s-%s-%s-%s-%s.%s",
            package:name(), version, plat, arch, mode, variant, ext)
    local asset_path = path.absolute(asset_name)
    local extract_dir = path.join(os.tmpdir(), package:name() .. "-" .. plat .. "-" .. mode)
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
        cprint("${yellow}[baas-xrepo] prebuilt asset unavailable, fallback to source: %s", url)
        return false
    end

    os.rm(extract_dir)
    if not archive.extract(asset_path, extract_dir) then
        raise("failed to extract prebuilt package archive: %s", asset_path)
    end

    os.cp(path.join(extract_dir, "*"), package:installdir())
    return true
end

package("baas-onnxruntime")
    set_homepage("https://www.onnxruntime.ai")
    set_description("ONNX Runtime: cross-platform, high performance ML inferencing and training accelerator")
    set_license("MIT")

    add_urls("https://github.com/microsoft/onnxruntime/archive/refs/tags/v$(version).zip")

    add_versions("1.19.2", "4cc07c157e1cbbc1bce24b2e96f04dc6e340909b1fa2d22b566854148cdaefa9")
    add_versions("1.23.2", "a3a84466ed40a1027e164bd8b2ce54e36feb1490271e065da5b5a030fd724af9")

    -- feature-like options
    add_configs("source", {description = "Build from source even if a GitHub release asset exists.", default = false, type = "boolean"})
    add_configs("prebuilt_tag", {description = "GitHub release tag that stores prebuilt assets. Use latest to track the newest release.", default = "latest", type = "string"})
    add_configs("cuda", {description = "Build with CUDA support", default = false, type = "boolean"})
    add_configs("tensorrt", {description = "Build with TensorRT support", default = false, type = "boolean"})
    add_configs("tensorrt_root", {description = "TensorRT root path (Required if TensorRT feature is ON)", type = "string"})
    add_configs("directml", {description = "Build with DirectML support", default = false, type = "boolean"})
    add_configs("coreml", {description = "Build with CoreML support", default = false, type = "boolean"})
    add_configs("onnx_shared", {description = "Download onnxruntime shared binaries.", default = true, type = "boolean", readonly = true})
    add_configs("shared", {description = "Not building shared protobuf/onnx", default = false, type = "boolean", readonly = true})

    on_load(function (package)
        package:add("deps", "cmake")
        package:add("deps", "ninja")
        package:add("deps", "zlib")
        -- TODO: make use of xmake deps so cmake won't download/build them again
        if package:config("cuda") then
            package:add("deps", "cuda", {configs = {utils = {"cudart", "nvrtc"}}})
        end
        if package:is_plat("windows") and package:config("directml") then
            package:add("deps", "directml-bin")
        end
    end)

    on_install("windows", "linux", "macosx", function (package)
        if _baas_try_install_prebuilt(package) then
            return
        end

        local configs = {}

        -- override xmake injection of ndebug configs
        table.insert(configs, "-DCMAKE_BUILD_TYPE=" .. (package:debug() and "Debug" or "Release"))
        table.insert(configs, "-DCMAKE_C_FLAGS_DEBUG=/Zi /Ob0 /Od /RTC1 " .. (package:debug() and "-MDd" or "MD"))
        table.insert(configs, "-DCMAKE_CXX_FLAGS_DEBUG=/Zi /Ob0 /Od /RTC1 " .. (package:debug() and "-MDd" or "MD"))
        table.insert(configs, "-DCMAKE_MSVC_RUNTIME_LIBRARY=" .. (package:debug() and "MultiThreadedDebugDLL" or "MultiThreadedDLL"))
        table.insert(configs, "-DCMAKE_POLICY_DEFAULT_CMP0091=NEW")

        -- fix path too long issues on windows
        table.insert(configs, "-DCMAKE_OBJECT_PATH_MAX=512")
        table.insert(configs, "-DCMAKE_C_USE_RESPONSE_FILE_FOR_OBJECTS=1")
        table.insert(configs, "-DCMAKE_CXX_USE_RESPONSE_FILE_FOR_OBJECTS=1")
        table.insert(configs, "-DCMAKE_C_RESPONSE_FILE_LINK_FLAG=@")
        table.insert(configs, "-DCMAKE_CXX_RESPONSE_FILE_LINK_FLAG=@")
        if os.host() == "windows" then
            try {
                 function ()
                    os.exec("subst B: /D")
                 end
            }
            os.exec("subst B: " .. package:cachedir() .. "/source")
            os.cd("B:/")
        end

        table.insert(configs, "-Donnxruntime_BUILD_SHARED_LIB=" .. (package:config("onnx_shared") and "ON" or "OFF"))
        table.insert(configs, "-DONNX_USE_PROTOBUF_SHARED_LIBS=" .. (package:config("shared") and "ON" or "OFF"))
        table.insert(configs, "-DONNX_USE_LITE_PROTO=" .. (package:config("shared") and "ON" or "OFF"))
        table.insert(configs, "-Donnxruntime_USE_FULL_PROTOBUF=" .. (package:config("shared") and "OFF" or "ON"))

        -- make protobuf build with -MD instead of -MT on msvc
        table.insert(configs, "-Dprotobuf_MSVC_STATIC_RUNTIME=OFF")

        table.insert(configs, "-Donnxruntime_USE_VCPKG=OFF")
        table.insert(configs, "-Donnxruntime_ENABLE_PYTHON=OFF")
        table.insert(configs, "-Donnxruntime_ENABLE_TRAINING=OFF")
        table.insert(configs, "-Donnxruntime_ENABLE_TRAINING_APIS=OFF")
        table.insert(configs, "-Donnxruntime_ENABLE_MICROSOFT_INTERNAL=OFF")
        table.insert(configs, "-Donnxruntime_BUILD_UNIT_TESTS=OFF")

        table.insert(configs, "-Donnxruntime_ENABLE_MEMLEAK_CHECKER=OFF")
        table.insert(configs, "-Donnxruntime_ENABLE_MEMORY_PROFILE=OFF")
        table.insert(configs, "-Donnxruntime_DEBUG_NODE_INPUTS_OUTPUTS=OFF")

        -- cuda / directml / coreml feature options
        if package:config("cuda") then
            table.insert(configs, "-Donnxruntime_USE_CUDA=ON")
            table.insert(configs, "-Donnxruntime_USE_CUDA_NHWC_OPS=ON")
        end
        if package:config("tensorrt") then
            table.insert(configs, "-Donnxruntime_USE_TENSORRT=ON")
            local trt_root = package:config("tensorrt_root")
            table.insert(configs, "-DTENSORRT_ROOT=" .. trt_root)
            table.insert(configs, "-DCMAKE_PREFIX_PATH=" .. trt_root)
        end
        if package:config("directml") then
            table.insert(configs, "-Donnxruntime_USE_DML=ON")
            table.insert(configs, "-Donnxruntime_USE_CUSTOM_DIRECTML=ON")

            -- get DirectML include/lib paths from directml-bin package and transfer them to cmake
            local dml_root = package:dep("directml-bin"):installdir()
            local dml_include = path.join(dml_root, "include")
            local dml_lib = path.join(dml_root, "lib")
            table.insert(configs, "-Ddml_INCLUDE_DIR=" .. dml_include)
            table.insert(configs, "-Ddml_LIB_DIR=" .. dml_lib)
        end
        if package:config("coreml") then
            table.insert(configs, "-Donnxruntime_USE_COREML=ON")
        end

        print(configs)

        -- cmake files are in cmake subfolder
        os.cd("cmake")
        import("package.tools.cmake").install(package, configs)

        -- move cuda provider dll to bin folder
        if package:is_plat("windows") then
            os.mv(package:installdir("lib").."/*.dll", package:installdir("bin"))
        end

        -- handle incorrect include paths
        os.mv(package:installdir("include/onnxruntime/*"), package:installdir("include/"))
        os.rm(package:installdir("include/onnxruntime"))

        if os.host() == "windows" then
            try {
                 function ()
                    os.exec("subst B: /D")
                 end
            }
        end
    end)

    on_test(function (package)
        assert(package:check_cxxsnippets({test = [[
            #include <array>
            #include <cstdint>
            void test() {
                std::array<float, 2> data = {0.0f, 0.0f};
                std::array<int64_t, 1> shape{2};

                Ort::Env env;

                auto memory_info = Ort::MemoryInfo::CreateCpu(OrtDeviceAllocator, OrtMemTypeCPU);
                auto tensor = Ort::Value::CreateTensor<float>(memory_info, data.data(), data.size(), shape.data(), shape.size());
            }
        ]]}, {configs = {languages = "c++17"}, includes = "onnxruntime_cxx_api.h"}))
    end)
