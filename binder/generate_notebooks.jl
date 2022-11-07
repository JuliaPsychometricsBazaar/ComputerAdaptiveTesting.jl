using Pkg

cd(@__DIR__)
Pkg.activate("../docs")


using Literate


const src_dir = "../docs/examples/examples"
const dest_dir = "notebooks"
mkdir(dest_dir)

for path in readdir(src_dir)
    Literate.notebook("$(src_dir)/$(path)", dest_dir, execute=false)
end
