using Libdl
using CondaPkg
using Preferences
using UUIDs

const RCALL_UUID = UUID("6f49c342-dc21-5d91-9882-a32aef131414")

CondaPkg.add("r")
target_rhome = joinpath(CondaPkg.envdir(), "lib", "R")
if Sys.iswindows()
    target_libr = joinpath(target_rhome, "bin", Sys.WORD_SIZE==64 ? "x64" : "i386", "R.dll")
else
    target_libr = joinpath(target_rhome, "lib", "libR.$(Libdl.dlext)")
end
set_preferences!(RCALL_UUID, "Rhome" => target_rhome, "libR" => target_libr)
