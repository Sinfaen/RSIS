
@enum Lang RUST CPP FORTRAN

struct LibraryInstall
    location::Vector{String}
    language::Lang
end

_libraries = [
    LibraryInstall(["src", "core", "modellib", "cpp-meson-lib"], CPP),
    LibraryInstall(["src", "core", "modellib"], RUST),
    LibraryInstall(["src", "core"], RUST)
]

function _clean(data::LibraryInstall) :: Nothing
    if data.language == RUST
        run(`cargo clean`)
    elseif data.language == CPP
        if isdir("build")
            rm("build"; recursive = true) # Meson does not provide this functionality
        end
    else
        throw(ErrorException("Unsupported:"))
    end
    return
end

"""
# Assumptions
- Runs within the top level of the sub-project
"""
function _compile_release(data::LibraryInstall, install::String, for_release=false) :: Nothing
    if data.language == RUST
        if for_release
            run(`cargo build --release`)
            basepath = joinpath("target", "release")
        else
            run(`cargo build`)
            basepath = joinpath("target", "debug")
        end
        # kludge: --out-dir is unstable and nightly-only
        # copy all possible file extensions instead
        for path in readdir(basepath)
            bp = joinpath(basepath, path)
            if isfile(bp) && endswith(bp, r"\.so|\.dll|\.dylib|\.rlib")
                np = joinpath(install, path)
                println("Installing $path to $np")
                cp(bp, np)
            end
        end
    elseif data.language == CPP
        if for_release
            run(`meson setup build -Dbuildtype=release --prefix /`)
            cd("build")
            run(`meson compile`)
            run(`meson install --destdir $install`)
        else
            run(`meson setup build -Dbuildtype=debug --prefix /`)
            cd("build")
            run(`meson compile`)
            run(`meson install --destdir $install`)
        end
        cd("..")
    else
        throw(ErrorException("Unsupported"))
    end
    return
end

"""
Utility function to build RSIS libraries and release them
to the install/[debug/release] folders.
# Arguments
- `release::Bool`: Set to `true` for optimized builds
- `clean::Bool` : If set to `true`, clean all build directories first
"""
function build(;release :: Bool = false, clean::Bool = false) :: Nothing
    # build the core library
    root = normpath(joinpath(pwd(), ".."));
    if release
        install = joinpath(root, "install", "release")
    else
        install = joinpath(root, "install", "debug")
    end
    for lib in _libraries
        if clean
            cd(joinpath(cat([root], lib.location, dims=(1,))))
            _clean(lib)
        end
        _compile_release(lib, install, release)
    end
    return;
end
