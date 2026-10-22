"""Native Gen1/Gen2/Gen3 damage and real 1025Dex formula integration checks.
Usage: python tools/test_ohko_native.py ENGINE 1025DEX [--source BASELINE_SOURCE]
Requires Lupa with lua53 and luajit21. No player saves/options are touched.
"""
from pathlib import Path
import argparse
import os

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument("engine",type=Path)
parser.add_argument("dex",type=Path)
parser.add_argument("--source",type=Path)
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
engine=args.engine.resolve();dex=args.dex.resolve()
if (dex/"battle-mechanics").is_dir():dex=dex/"battle-mechanics"
source=(args.source or root).resolve()
fixture=(root/"tests/ohko_native.lua").read_text(encoding="utf-8")
os.chdir(engine)
failures=[];total=0
for vm in ("lua53","luajit21"):
 LuaRuntime=__import__(f"lupa.{vm}",fromlist=["LuaRuntime"]).LuaRuntime
 for game in ("red","blue","yellow","gold","silver","crystal","firered","leafgreen","ruby","sapphire","emerald"):
  lua=LuaRuntime(unpack_returned_tuples=True)
  if vm=="lua53":
   lua.execute("""
    package.preload.bit=function()
      local B={}
      function B.band(a,b,...)local n=a & b;if select('#',...)>0 then return B.band(n,...)end;return n end
      function B.bor(a,b,...)local n=a | b;if select('#',...)>0 then return B.bor(n,...)end;return n end
      function B.bxor(a,b,...)local n=a ~ b;if select('#',...)>0 then return B.bxor(n,...)end;return n end
      function B.bnot(a)return (~a)&0xffffffff end
      function B.lshift(a,b)return(a<<b)&0xffffffff end
      function B.rshift(a,b)return(a&0xffffffff)>>b end
      function B.tobit(a)a=a&0xffffffff;if a>=0x80000000 then return a-0x100000000 end;return a end
      return B
    end
   """)
  lua.globals().arg=lua.table_from([root.as_posix(),game,dex.as_posix(),source.as_posix()])
  try:
   if game in ("firered","leafgreen","ruby","sapphire","emerald"):
    lua.globals().arg=lua.table_from([root.as_posix(),game,source.as_posix()])
    total+=lua.execute((root/"tests/ohko_native_gen3.lua").read_text(encoding="utf-8"))
   else:total+=lua.execute(fixture)
  except Exception as exc:failures.append(f"{vm}/{game}: {exc}")
for failure in failures:print("FAIL",failure)
if failures:raise SystemExit(1)
print(f"PASS: 22 native damage/real-1025Dex cases, {total} assertions")
