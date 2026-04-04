-- copied from https://github.com/xmake-io/xmake-repo/blob/886bb0c11433a8cfd7cde408c6dbe8d9b6f1e318/packages/p/pybind11/xmake.lua
-- gives options to use system python installation
-- and use python executable instead of python3
package("pybind11-fix")
    set_kind("library", {headeronly = true})
    set_homepage("https://github.com/pybind/pybind11")
    set_description("Seamless operability between C++11 and Python.")
    set_license("BSD-3-Clause")

    add_urls("https://github.com/pybind/pybind11/archive/refs/tags/$(version).zip",
             "https://github.com/pybind/pybind11.git")

    add_versions("v3.0.1", "20fb420fe163d0657a262a8decb619b7c3101ea91db35f1a7227e67c426d4c7e")
    add_versions("v3.0.0", "dfe152af2f454a9d8cd771206c014aecb8c3977822b5756123f29fd488648334")
    add_versions("v2.13.6", "d0a116e91f64a4a2d8fb7590c34242df92258a61ec644b79127951e821b47be6")
    add_versions("v2.13.5", "0b4f2d6a0187171c6d41e20cbac2b0413a66e10e014932c14fae36e64f23c565")
    add_versions("v2.5.0", "1859f121837f6c41b0c6223d617b85a63f2f72132bae3135a2aa290582d61520")
    add_versions("v2.6.2", "0bdb5fd9616fcfa20918d043501883bf912502843d5afc5bc7329a8bceb157b3")
    add_versions("v2.7.1", "350ebf8f4c025687503a80350897c95d8271bf536d98261f0b8ed2c1a697070f")
    add_versions("v2.8.1", "90907e50b76c8e04f1b99e751958d18e72c4cffa750474b5395a93042035e4a3")
    add_versions("v2.9.1", "ef9e63be55b3b29b4447ead511a7a898fdf36847f21cec27a13df0db051ed96b")
    add_versions("v2.9.2", "d1646e6f70d8a3acb2ddd85ce1ed543b5dd579c68b8fb8e9638282af20edead8")
    add_versions("v2.10.0", "225df6e6dea7cea7c5754d4ed954e9ca7c43947b849b3795f87cb56437f1bd19")
    add_versions("v2.12.0", "411f77380c43798506b39ec594fc7f2b532a13c4db674fcf2b1ca344efaefb68")
    add_versions("v2.13.1", "a3c9ea1225cb731b257f2759a0c12164db8409c207ea5cf851d4b95679dda072")

    add_deps("cmake")

    add_configs("python_executable_path",{description = "Python executable path (if specific-python is on)", type = "string"})
    add_configs("python_root_path",{description = "Python root path (if specific-python is on)", type = "string"})
    add_configs("python_include_path",{description = "Python include path (if specific-python is on)", type = "string"})

    on_load("macosx", function (package)
        -- fix segmentation fault for macosx
        -- @see https://github.com/xmake-io/xmake/issues/2177#issuecomment-1209398292
        package:add("shflags", "-undefined dynamic_lookup", {force = true})
    end)

    on_install(function (package)
        local configs = {"-DPYBIND11_TEST=OFF"}

        -- override xmake injection of ndebug configs
        table.insert(configs, "-DCMAKE_BUILD_TYPE=" .. (package:debug() and "Debug" or "Release"))
        if package:is_plat("windows") then
            table.insert(configs, "-DCMAKE_C_FLAGS_DEBUG=/Zi /Ob0 /Od /RTC1 " .. (package:debug() and "/MDd" or "/MD"))
            table.insert(configs, "-DCMAKE_CXX_FLAGS_DEBUG=/Zi /Ob0 /Od /RTC1 " .. (package:debug() and "/MDd" or "/MD"))
            table.insert(configs, "-DCMAKE_MSVC_RUNTIME_LIBRARY=" .. (package:debug() and "MultiThreadedDebugDLL" or "MultiThreadedDLL"))
            table.insert(configs, "-DCMAKE_POLICY_DEFAULT_CMP0091=NEW")
        end

        -- force new find_python implement
        table.insert(configs, "-DPYBIND11_FINDPYTHON=ON")

        if package:config("python_executable_path") ~= nil and package:config("python_root_path") ~= nil and package:config("python_include_path") ~= nil then
            table.insert(configs, "-DPython_EXECUTABLE=" .. package:config("python_executable_path"))
            table.insert(configs, "-DPython_ROOT_DIR=" .. package:config("python_root_path"))
            table.insert(configs, "-DPython_INCLUDE_DIR=" .. package:config("python_include_path"))
        end

        print(configs)
        import("package.tools.cmake").install(package, configs)
    end)

-- disabled post test because python includes were not injected and it would fail
--     on_test(function (package)
--         assert(package:check_cxxsnippets({test = [[
--             #include <pybind11/pybind11.h>
--             int add(int i, int j) {
--                 return i + j;
--             }
--             PYBIND11_MODULE(example, m) {
--                 m.def("add", &add, "A function which adds two numbers");
--             }
--         ]]}, {configs = {languages = "c++11"}}))
--     end)
