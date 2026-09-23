project_name := "Mnemonica"
source_dir := "source"
output_dir := "builds"
pdx_file := output_dir / "Mnemonica.pdx"

# 📋 List all recipes (default)
default:
    @just --list --unsorted

# 🔨 Build the Playdate project
build:
    mkdir -p "{{ output_dir }}"
    pdc "{{ source_dir }}" "{{ pdx_file }}"

# 🎮 Run the Playdate Simulator
run: build
    open -a "Playdate Simulator" "{{ pdx_file }}"

# 🧹 Clean build artifacts
clean:
    rm -rf "{{ output_dir }}"

# ✅ Pre-commit checks
precommit: build
