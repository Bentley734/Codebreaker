"""Native Frontier rules with this checkout's cheat wrapper.

Usage: python tools/test_frontier_legends.py ENGINE
"""
from pathlib import Path
import os
import sys
from test_runtime import new_runtime

root = Path(__file__).resolve().parents[1]
engine = Path(sys.argv[1]).resolve()
source = (root / "main.lua").read_text(encoding="utf-8")
start = source.index('    wrap("src.core.game3.rse.frontier.util","isBanned"')
end = source.index('\n    end)', start) + len('\n    end)')
os.chdir(engine)
for vm in ("lua53", "luajit21"):
    lua = new_runtime(vm)
    lua.globals().testLove = lua.execute((root / "tests/headless_love.lua").read_text(encoding="utf-8"))
    lua.globals().cheatSource = source[start:end]
    lua.execute((root / "tests/frontier_legends.lua").read_text(encoding="utf-8"))
    print("PASS Frontier runtime:", vm, flush=True)
