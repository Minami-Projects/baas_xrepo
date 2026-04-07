-- TensorRT SDK (headers + import libs) for CI builds
-- Hosted on GitHub Release: Nanboom233/baas_xrepo vendor-sdks
package("tensorrt-bin")
    set_homepage("https://developer.nvidia.com/tensorrt")
    set_description("NVIDIA TensorRT - High-performance deep learning inference SDK (headers + import libs only)")

    set_urls("https://github.com/Nanboom233/baas_xrepo/releases/download/vendor-sdks/tensorrt-sdk-$(version)-windows-x64.zip")
    add_versions("10.14.1", "0779e4e83af61704fd37e4464b94ed1fabbbf8d1e3523942e17d8beedfd31184")

    on_install("windows", function (package)
        os.cp("include", package:installdir())
        os.cp("lib", package:installdir())
    end)
