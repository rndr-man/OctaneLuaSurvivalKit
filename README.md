# OctaneLuaSurvivalKit

Collection of small [Octane Render] Lua scripts built on the Octane Lua API. Each tool is designed to be drop-in for use from Octane's scripting UI or (where supported) from the `octane.exe --no-gui` command line.

## Quick Start

1. Copy the tool folder(s) you want to use into Octane's Lua scripts directory.
2. Restart Octane (or reload scripts if your Octane version supports it).
3. Run from the Octane `Scripts` menu (or via keyboard shortcut if provided by the tool).

## Tools

### Animate Float Nodes
Folder: `OctaneAnimateFloatNodes/`
Entry point: `OctaneAnimateFloatNodes/Animate Float Nodes.lua`

What it does: applies keyframe animation to selected Octane Float Value nodes, supporting:
- Segment-based animation with easing
- Custom value sequences (paste or JSON import/export)
- Optional 4-channel support via exported/imported JSON

Requires: Octane 2026.1+ (per script header)

### Octane Assets Per Frame Range Analyzer
Folder: `OctaneAssetsPerFrameRangeAnalyzer/`
Entry point: `OctaneAssetsPerFrameRangeAnalyzer/OctaneAssetsPerFrameRangeAnalyzer.lua`

What it does: scans the loaded scene for nodes that reference file-based assets (via `A_FILENAME`) and generates a JSON manifest optimized for render-farm chunking.

CLI (example):
```bat
octane.exe --no-gui --script "OctaneAssetsPerFrameRangeAnalyzer.lua" ^
  <output_directory> <start_frame> <end_frame> <chunk_size> [verbose]
```

Output: `<output_directory>/octane_assets_manifest.json`

### Octane Render Scene Anvil
Folder: `OctaneSceneAnvil/`
Entry point: `OctaneSceneAnvil/OctaneRenderSceneAnvil.lua`

What it does: combines multiple ORBX sources into a destination scene, with geometry merging and optional USD material mapping.

CLI (example):
```bat
octane.exe --no-gui --script "OctaneRenderSceneAnvil.lua" ^
  -A "C:\temp\saveAsScene.orbx" ^
     "C:\temp\destinationScene.orbx" ^
     "C:\temp\sourceScene1.orbx" ^
     "C:\temp\sourceScene2.orbx::RenderTarget2" ^
     "usd=yourTargetName.usd::mat=C:\path\to\sourceScene_mat.orbx::geo=C:\path\to\sourceScene_geo.orbx"
```

### Gaussian Splat Sequence Animation
Folder: `OctaneSplatsSequence/`
Entry point: `OctaneSplatsSequence/OctaneSplatsSequence.lua`

What it does: GUI tool that finds Gaussian Splat nodes and assigns an animator using an absolute-file sequence (PLY/SPZ) by auto-detecting the naming pattern and frame range from disk.

## Developer Notes (Octane Lua API)

- All scripts expect Octane's Lua runtime (`octane.*` global).
- GUI tools use Octane's `octane.gui` / `octane.gridlayout` APIs.
- For headless scripts, the tools check argument lists (`arg` / `arg[2] ...`) and avoid creating GUI windows.

## Attribution

`OctaneAnimateFloatNodes/AnimateFloatNodes_bin/widget.lua` includes an MIT license header for the widget abstraction layer it is based on.

## Contributing

Open an issue for bugs or workflow requests, or submit a PR with:
- a description of expected Octane behavior
- any command line / GUI usage changes
- (if relevant) updates to README files

