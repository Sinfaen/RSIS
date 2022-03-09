using Logging
using Pkg
using Pkg.Artifacts

function release_shared_environment(name::String="RSIS", path::String="./") :: Nothing
    @info "Changing directory to root"
    cd("..")

    debug_dir = joinpath(pwd(), "install", "debug")
    hash = create_artifact() do dir
        for (root, ~, files) in walkdir(debug_dir)
            for file in files
                apath = joinpath(root, file)
                if isfile(apath)
                    @info "Adding $(apath) to artifact"
                    cp(apath, joinpath(dir, file))
                end
            end
        end
    end

    @info "Generated Artifact Hash: $(hash)"
    tarball_hash = archive_artifact(hash, "rsis.tar.gz");

    bind_artifact!("Artifacts.toml", "rsis", hash, 
        download_info=[("file:" * joinpath(pwd(), "rsis.tar.gz"), tarball_hash)], force=true)
    @info "Artifact bound"

    @info "Releasing RSIS package to shared environment: $(name)"
    Pkg.activate(name; shared=true)
    Pkg.add(Pkg.PackageSpec(; path=path))
    @info "Successfully released RSIS"
    return
end
