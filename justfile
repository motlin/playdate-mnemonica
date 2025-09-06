project_name := "Hex Flip"
source_dir := "source"
output_dir := "builds"
pdx_file := output_dir / "Hex Flip.pdx"

# 📋 List all recipes (default)
default:
    @just --list --unsorted

# 🔨 Build the Playdate project
build:
    pdc "{{source_dir}}" "{{pdx_file}}"

# 🎮 Run the Playdate Simulator
run: build
    open -a "Playdate Simulator" "{{pdx_file}}"

# 🧹 Clean build artifacts
clean:
    rm -rf "{{output_dir}}"