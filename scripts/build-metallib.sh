#!/bin/bash
# Compiles MLX's Metal shaders into mlx.metallib. `swift build` cannot do this itself,
# and MLX looks for the file next to the executable. Needs the Metal Toolchain:
#   xcodebuild -downloadComponent MetalToolchain
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=.build/checkouts/mlx-swift/Source/Cmlx/mlx-generated/metal
OUT=.build/metallib
[ -d "$SRC" ] || { echo "MLX sources not found; run swift build first" >&2; exit 1; }
mkdir -p "$OUT"
rm -f "$OUT"/*.air

while IFS= read -r file; do
    name=$(echo "${file#$SRC/}" | tr '/' '_')
    xcrun -sdk macosx metal -Wno-everything -O2 -I "$SRC" -c "$file" -o "$OUT/${name%.metal}.air"
done < <(find "$SRC" -name '*.metal')

xcrun -sdk macosx metallib "$OUT"/*.air -o "$OUT/mlx.metallib"
echo "Built $OUT/mlx.metallib"
