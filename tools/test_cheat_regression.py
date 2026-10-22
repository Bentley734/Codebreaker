"""Run full CodeBreaker entrypoint/cheat fixtures on each supported title.

Usage: python tools/test_cheat_regression.py /path/to/gen1recomp/engine
Requires lupa (both Lua 5.3 and LuaJIT 2.1 wheels are included in Lupa).
These tests never read or write player saves, options, or imported assets.
"""
from pathlib import Path
import os
import sys

root = Path(__file__).resolve().parents[1]
engine = Path(sys.argv[1]).resolve()
source_root = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else root
os.chdir(engine)
test = (root / "tests/cheat_regression.lua").read_text(encoding="utf-8")
failures = []
for vm in ("lua53", "luajit21"):
    LuaRuntime = __import__(f"lupa.{vm}", fromlist=["LuaRuntime"]).LuaRuntime
    for game in ("red", "blue", "yellow", "gold", "silver", "crystal",
                 "firered", "leafgreen", "ruby", "sapphire", "emerald"):
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
        lua.globals().arg = lua.table_from([source_root.as_posix(), game])
        try:
            lua.execute(test)
        except Exception as exc:
            failures.append(f"{vm}/{game}: {exc}")
for failure in failures:
    print("FAIL", failure)
if failures:
    raise SystemExit(1)
print("PASS: 22 full-entrypoint title/runtime cases")
