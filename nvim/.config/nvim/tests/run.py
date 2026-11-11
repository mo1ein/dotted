#!/usr/bin/env python3
"""Copy config into an isolated XDG fixture and run the Neovim regressions."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--fixture", type=Path, required=True, help="Dedicated scratch directory outside this configuration")
parser.add_argument("--full", action="store_true", help="Also run original appearance/search/keymap regressions")
parser.add_argument("tests", nargs="*", help="Optional Lua test filenames")
args = parser.parse_args()
source = Path(__file__).resolve().parent.parent
fixture = args.fixture.expanduser().resolve()
if fixture == source or fixture in source.parents or source in fixture.parents:
    parser.error("The fixture must not overlap the real configuration")
config = fixture / "config/nvim"
shutil.copytree(source, config, dirs_exist_ok=True)
plugins = fixture / "data/nvim/lazy"
if not plugins.exists():
    shutil.copytree(Path.home() / ".local/share/nvim/lazy", plugins, symlinks=True)
adapter = fixture / "data/nvim/debugpy"
if not adapter.exists() and (Path.home() / ".local/share/nvim/debugpy").exists():
    adapter.symlink_to(Path.home() / ".local/share/nvim/debugpy", target_is_directory=True)
env = os.environ.copy()
for key, directory in [("XDG_CONFIG_HOME", "config"), ("XDG_DATA_HOME", "data"), ("XDG_CACHE_HOME", "cache"), ("XDG_STATE_HOME", "state")]:
    env[key] = str(fixture / directory)
env.pop("NVIM_APPNAME", None)
env.update(NVIM_TEST_ISOLATED="1", TERM="xterm-256color")
unit = [
    "onedark.lua", "statusline.lua", "bundled.lua", "preview.lua", "colors.lua",
    "vscode.lua", "selection.lua", "confirm.lua", "git_colors.lua", "cheatsheet.lua", "debug_starting.lua",
    "keymap_table.lua", "keymap_aliases.lua", "recent_keymaps.lua", "debug_keymaps.lua", "python_interpreter.lua", "replace.lua", "run_detect.lua",
]
integration = [
    "feats.lua", "feats_tui.lua", "interaction_fixes.lua", "widget_ownership.lua", "undo_terminal.lua", "run_latency.lua", "project_run.lua", "run_rerun.lua", "go_rerun.lua", "server_rerun.lua", "workspace.lua", "recent_release.lua", "recent_colors.lua", "recent_terminal.lua", "breadcrumbs.lua", "breadcrumb_icons.lua", "menu.lua", "explorer_selection.lua", "tree_search.lua", "picker_selection.lua", "finder_colors.lua", "tools.lua", "tools_layout.lua", "output_runner.lua", "workspace_tui.lua", "hover_controls.lua", "git_graph.lua",
    "dap_ui.lua", "dap_python.lua", "dap_go.lua", "smoke.lua", "startup_tui.lua", "tui.lua",
]
tests = args.tests or ((unit + ["diagnostics.lua", "gitsigns.lua", "replace_project.lua"]) if args.full else []) + integration
failed = []
for test in tests:
    path = config / "tests" / test
    if Path(test).name != test or not path.is_file() or path.suffix != ".lua":
        parser.error("Unknown Lua test: " + test)
    if test in unit:
        command = ["nvim", "--headless", "-u", "NONE", "-l", str(path)]
    else:
        lua = "local ok,e=xpcall(function() dofile(" + json.dumps(str(path)) + ") end,debug.traceback);"
        lua += 'if not ok then print(e);pcall(function() require("dap").terminate() end);vim.cmd("cquit 1") else vim.cmd("qa!") end'
        command = ["nvim", "--headless", "+lua " + lua]
    try:
        result = subprocess.run(command, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
        print(test, "PASS" if result.returncode == 0 else "FAIL", flush=True)
        print(result.stdout.strip(), flush=True)
        if result.returncode:
            failed.append(test)
    except subprocess.TimeoutExpired:
        print(test, "TIMEOUT", flush=True)
        failed.append(test)
print("Result:", len(tests) - len(failed), "passed,", len(failed), "failed", flush=True)
sys.exit(bool(failed))
