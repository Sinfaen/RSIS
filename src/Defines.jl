module MDefines

export ProjectType, RUST, CPP, FORTRAN
export BuildTarget, DEBUG, RELEASE

abstract type BuildTarget end
struct DEBUG   <: BuildTarget end
struct RELEASE <: BuildTarget end

Base.print(io::IO, ::DEBUG)   = print(io, "debug")
Base.print(io::IO, ::RELEASE) = print(io, "release")

abstract type ProjectType end
struct RUST    <: ProjectType end
struct CPP     <: ProjectType end
struct FORTRAN <: ProjectType end

Base.print(io::IO, ::RUST)    = print(io, "rust")
Base.print(io::IO, ::CPP)     = print(io, "cpp")
Base.print(io::IO, ::FORTRAN) = print(io, "fortran")

end
