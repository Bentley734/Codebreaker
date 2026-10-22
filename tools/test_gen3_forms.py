"""Check this checkout's form picker/spawn hooks with real 1025Dex data.

Usage: python tools/test_gen3_forms.py ENGINE [1025DEX_OR_WORKSPACE]
The optional fixture path is read-only; defaults to the installed 1025Dex mod.
Uses synthetic base ROM data plus the supplied real 1025Dex registry;
checks identities and dispatch, not downloaded art or live battle rendering.
"""
from pathlib import Path
import os
import sys
from test_runtime import new_runtime

root = Path(__file__).resolve().parents[1]
engine = Path(sys.argv[1]).resolve()
fixture = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else Path(os.environ["APPDATA"]) / "pokemon-love2d/mods/1025dex"
for candidate in (fixture, fixture / "1025Dex", fixture / "mods/1025dex"):
    if (candidate / "dex/src/gen3shape.lua").is_file():
        dex = candidate
        break
else:
    raise SystemExit(f"1025Dex fixture not found beneath {fixture}")
source = (root / "main.lua").read_text(encoding="utf-8")
def section(start, end):
    offset = source.index(start)
    return source[offset:source.index(end, offset)]
menu = section('  local function g3SelectedSpecies()', '  local function g3GiveItem')
menu += section('  local function g3StartBattle()', '  local function g3Teleport')
menu += section('  local function g3Rows()', '  local function g3Clamp')
menu += section('  local function g3Activate()', '  function G3Menu.handleInput')
start = source.index('  mod.hooks:wrap("encounter.roll"')
end = source.index('\n  end)', start) + len('\n  end)')
menu += source[start:end]
menu += section('  mod.exports.setSelectedSpecies=function(id)', '  mod.exports.getWildGender=')
menu += section('  mod.exports.spawn=function(n,level,game)', '  startItemsHook=function')
menu += '\nreturn function(test)test(g3Rows,g3Activate,g3StartBattle,g3SelectedSpecies)end'
os.chdir(engine)
print("1025Dex fixture:", dex, flush=True)
for vm in ("lua53", "luajit21"):
    for game in ("firered", "leafgreen", "ruby", "sapphire", "emerald"):
        lua = new_runtime(vm)
        lua.globals().arg = lua.table_from([dex.as_posix(), game])
        lua.globals().testLove = lua.execute((root / "tests/headless_love.lua").read_text(encoding="utf-8"))
        lua.globals().menuSource = menu
        lua.execute('assert(load(...))', source)
        lua.execute((root / "tests/gen3_forms.lua").read_text(encoding="utf-8"))
    print("PASS form runtime:", vm, flush=True)
