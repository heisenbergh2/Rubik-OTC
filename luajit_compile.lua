-- LuaJIT bytecode compiler helper (used by build_pak.py).
-- Usage: luajit luajit_compile.lua <src.lua> <out.bc> <chunkname>
-- Compiles source to LuaJIT 2.1 bytecode (keeps the chunk name for readable tracebacks),
-- standard LuaJIT bytecode protection for .lua assets.
local src = assert(io.open(arg[1], "rb")):read("*a")
local f = assert(load(src, "@" .. arg[3]))
local out = assert(io.open(arg[2], "wb"))
out:write(string.dump(f))
out:close()
