import ".just/console.just"
import ".just/git.just"
import ".just/git-test.just"

project_name := "Mnemonica"
source_dir := "source"
output_dir := "builds"
pdx_file := output_dir / project_name + ".pdx"
luarocks_bin := env_var("HOME") / ".luarocks/bin"

# 📋 List all recipes (default)
default:
    @just --list --unsorted

# `mise install`
mise:
    mise install --quiet
    mise current

# 🧰 Install busted and luacheck into ~/.luarocks
lua-tools:
    luarocks install --local busted 2.3.0-1
    luarocks install --local luacheck 1.2.0-1

# 🔨 Build the Playdate project
build:
    mkdir -p "{{ output_dir }}"
    pdc "{{ source_dir }}" "{{ pdx_file }}"

# 🎮 Run the Playdate Simulator
run: build
    open -a "Playdate Simulator" "{{ pdx_file }}"

# 🧹 Clean build artifacts
clean: _clean-git
    rm -rf "{{ output_dir }}"

# 🧪 Run host-side specs
test:
    "{{ luarocks_bin }}/busted"

# 🔍 Lint Lua sources
lint:
    "{{ luarocks_bin }}/luacheck" .

# `stylua source spec`
format:
    stylua source spec

# `stylua --check source spec`
format-check:
    stylua --check source spec

# ✅ Run pre-commit hooks, lint, specs, and build
verify:
    pre-commit run --all-files
    just lint
    just test
    just build

# 📸 Capture every screen from the Simulator
screenshots output="builds/screenshots":
    tools/screenshots/run.sh tour "{{ output }}"
    tools/screenshots/run.sh complete "{{ output }}"
    tools/screenshots/run.sh complete_many "{{ output }}"
    tools/screenshots/run.sh perfect "{{ output }}"
    tools/screenshots/run.sh review "{{ output }}"
    tools/screenshots/run.sh simon "{{ output }}"
    tools/screenshots/run.sh menu_dpad "{{ output }}"

# 💨 Play through the game in the Simulator and fail on any crash
smoke: screenshots

# 🔬 Build the game with an on-screen input readout, for input bugs that only happen on a device
input-debug:
    tools/input-debug/build.sh
    open -a "Playdate Simulator" "{{ output_dir }}/MnemonicaInputDebug.pdx"

# Override this with a command called `woof` which notifies you in whatever ways you prefer.
# My `woof` command uses `echo`, `say`, and sends a Pushover notification.
echo_command := env('ECHO_COMMAND', "echo")
