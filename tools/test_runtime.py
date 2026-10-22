"""Small portable Lua runtime setup shared by headless integration tests."""
def new_runtime(vm):
    LuaRuntime = __import__(f"lupa.{vm}", fromlist=["LuaRuntime"]).LuaRuntime
    lua = LuaRuntime(unpack_returned_tuples=True)
    if vm == "lua53":
        lua.execute("""
          package.preload.bit=function()
            local B={}
            function B.band(a,b,...) local n=a & b;if select('#',...)>0 then return B.band(n,...) end;return n end
            function B.bor(a,b,...) local n=a | b;if select('#',...)>0 then return B.bor(n,...) end;return n end
            function B.bxor(a,b,...) local n=a ~ b;if select('#',...)>0 then return B.bxor(n,...) end;return n end
            function B.bnot(a) return (~a) & 0xffffffff end
            function B.lshift(a,b) return (a << b) & 0xffffffff end
            function B.rshift(a,b) return (a & 0xffffffff) >> b end
            function B.tobit(a) a=a & 0xffffffff;if a>=0x80000000 then return a-0x100000000 end;return a end
            return B
          end
        """)
    lua.execute("bit=require('bit')")
    return lua
