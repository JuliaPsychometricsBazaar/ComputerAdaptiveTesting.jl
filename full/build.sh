#!/bin/sh

julia --project=. ../install_pkgs.jl

cat << HEADER > Project.toml.tmp
name = "ComputerAdaptiveTestingFull"
uuid = "dcfddea1-f665-4ffb-8979-b04b0e81fb28"
authors = ["Frankie Robertson"]
version = "0.1.0"

$(cat Project.toml)
HEADER

mv Project.toml.tmp Project.toml
