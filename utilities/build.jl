
"""
    build(;release::Bool = false)
Utility function to build RSIS libraries.
# Arguments
- `release::Bool`: Set to `true` for optimized builds
"""
function build(;release :: Bool = false) :: Nothing
    # build the core library
    root = normpath(joinpath(pwd(), ".."));
    cd(joinpath(root, "src", "core"))
    if (release)
        run(`cargo build --release`)
    else
        run(`cargo build`)
    end
    return;
end
