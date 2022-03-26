using Mmap, SparseMatricesCSR, SparseArrays
@from "../Responses.jl" using Responses: Response

function mmap_vec(path, typ)
	io = open(path);
	vec_len = filesize(path) ÷ sizeof(typ);
	mmap(io, Vector{typ}, (vec_len,))
end;

function read_dims_file(path)
	meta = mmap_vec(path, UInt64);
	(meta[1], meta[2])
end

function load_td(dir)
	meta = mmap_vec(dir * "/dims", UInt64);
	num_docs, vocab_len = read_dims_file(dir * "/dims")
	use_64bit_indices = meta[3]
	if use_64bit_indices > 0
		ind_dt = UInt64
	else
		ind_dt = UInt32
	end
	indptr = mmap_vec(dir * "/indptr", ind_dt);
	indices = mmap_vec(dir * "/indices", ind_dt);
	data_counts = mmap_vec(dir * "/data_counts", UInt32);
	SparseMatrixCSR{0}(num_docs, vocab_len, indptr, indices, data_counts)
end

function save_gridify(xs, ys, out_dir)
    mkpath(out_dir)
    xs_io = open(joinpath(out_dir, "xs.mat"), "w")
	write(xs_io, xs)
    close(xs_io)
    ys_io = open(joinpath(out_dir, "ys.mat"), "w")
	write(ys_io, ys)
    close(ys_io)
	d_io = open(joinpath(out_dir, "dims"), "w")
    for d in size(ys)
        write(d_io, d)
    end
    close(d_io)
end

function load_gridify(in_dir)
	d_io = open(joinpath(in_dir, "dims"))
	num_grid_points = read(d_io, UInt64)
	num_words = read(d_io, UInt64)
    xs_io = open(joinpath(in_dir, "xs.mat"))
    xs = mmap(xs_io, Vector{Float64}, (num_grid_points,))
    ys_io = open(joinpath(in_dir, "ys.mat"))
    ys = mmap(ys_io, Matrix{Float64}, (num_grid_points, num_words))
	(xs, ys)
end