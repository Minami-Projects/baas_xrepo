-- onnxruntime with DirectML, CUDA, or CoreML support xmake package definition
-- inspired by maa-onnxruntime from MaaDeps
-- @MaaAssistantArknights/MaaDeps/files/vcpkg-overlay/ports/maa-onnxruntime
-- most copied from official onnxruntime xmake package
-- @xmake-io/xmake-repo/blob/4cfbaa42adc11fcfe6c3efe9136ac2a30025c83a/packages/o/onnxruntime/xmake.lua
package("baas-onnxruntime")
    set_homepage("https://www.onnxruntime.ai")
    set_description("ONNX Runtime: cross-platform, high performance ML inferencing and training accelerator")
    set_license("MIT")

    add_urls("https://github.com/microsoft/onnxruntime/archive/refs/tags/v$(version).zip")

    add_versions("1.19.2", "4cc07c157e1cbbc1bce24b2e96f04dc6e340909b1fa2d22b566854148cdaefa9")
    add_versions("1.23.2", "a3a84466ed40a1027e164bd8b2ce54e36feb1490271e065da5b5a030fd724af9")

    -- feature-like options
    add_configs("cuda", {description = "Build with CUDA support", default = false, type = "boolean"})
    add_configs("tensorrt", {description = "Build with TensorRT support", default = false, type = "boolean"})
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
        if package:config("tensorrt") then
            package:add("deps", "tensorrt-bin")
        end
        if package:is_plat("windows") and package:config("directml") then
            package:add("deps", "directml-bin")
        end
    end)

    on_install("windows", "linux", "macosx", function (package)
        local configs = {}

        -- override xmake injection of ndebug configs
        -- fix C4709 warnings on new msvc toolset versions
        table.insert(configs, "-DCMAKE_BUILD_TYPE=" .. (package:debug() and "Debug" or "Release"))
        if package:is_plat("windows") then
            table.insert(configs, "-DCMAKE_C_FLAGS_DEBUG=/Zi /Ob0 /Od /RTC1 /wd4709 /GR " .. (package:debug() and "/MDd" or "/MD"))
            table.insert(configs, "-DCMAKE_CXX_FLAGS_DEBUG=/Zi /Ob0 /Od /RTC1 /wd4709 /GR " .. (package:debug() and "/MDd" or "/MD"))
            table.insert(configs, "-DCMAKE_MSVC_RUNTIME_LIBRARY=" .. (package:debug() and "MultiThreadedDebugDLL" or "MultiThreadedDLL"))
            table.insert(configs, "-DCMAKE_POLICY_DEFAULT_CMP0091=NEW")
        end

        -- fix path too long issues on windows
        table.insert(configs, "-DCMAKE_OBJECT_PATH_MAX=512")
        table.insert(configs, "-DCMAKE_C_USE_RESPONSE_FILE_FOR_OBJECTS=1")
        table.insert(configs, "-DCMAKE_CXX_USE_RESPONSE_FILE_FOR_OBJECTS=1")
        table.insert(configs, "-DCMAKE_C_RESPONSE_FILE_LINK_FLAG=@")
        table.insert(configs, "-DCMAKE_CXX_RESPONSE_FILE_LINK_FLAG=@")
        if os.host() == "windows" then
            local srcdir = os.curdir()
            -- must leave B: before deleting the mapping, otherwise subst /D fails
            -- because the current process holds a reference to the drive
            os.cd(os.tmpdir())
            try { function () os.exec("subst B: /D") end }
            -- map B: to the source root and cd into it
            os.cd(srcdir)
            os.exec("subst B: " .. srcdir)
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
            -- only target consumer GPUs: Pascal(GTX10xx) / Turing(RTX20xx) / Ampere(RTX30xx) / Ada(RTX40xx) / Blackwell(RTX50xx)
            -- datacenter-only archs (sm_60/70/80/90a/120a) are dropped to reduce CUDA compile time
            table.insert(configs, "-DCMAKE_CUDA_ARCHITECTURES=61;75;86;89;100")
            -- onnxruntime uses its own cache var for nvcc --threads (default 1), not CMAKE_CUDA_FLAGS
            -- @see cmake/onnxruntime_providers_cuda.cmake: onnxruntime_NVCC_THREADS
            table.insert(configs, "-Donnxruntime_NVCC_THREADS=4")
        end
        if package:config("tensorrt") then
            table.insert(configs, "-Donnxruntime_USE_TENSORRT=ON")
            local trt_root = package:dep("tensorrt-bin"):installdir()
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
            os.cd(os.tmpdir())
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
