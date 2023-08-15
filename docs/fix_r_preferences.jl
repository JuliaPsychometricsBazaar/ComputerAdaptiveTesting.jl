using CondaPkg
using Preferences
using Libdl
using PreferenceTools

function locate_libR(Rhome)
    @static if Sys.iswindows()
        libR = joinpath(Rhome, "bin", Sys.WORD_SIZE==64 ? "x64" : "i386", "R.dll")
    else
        libR = joinpath(Rhome, "lib", "libR.$(Libdl.dlext)")
    end
    return libR
end

CondaPkg.resolve()
target_rhome = "$(CondaPkg.envdir())/lib/R"
PreferenceTools.add(
    "RCall",
    "Rhome" => target_rhome,
    "libR" => locate_libR(target_rhome)
)
