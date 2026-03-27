# Octane Assets Per Frame Range Analyzer

Scans all nodes in the currently loaded Octane scene for file-based assets referenced via `A_FILENAME` and produces a JSON manifest describing which assets are required for each frame chunk.

This is useful for render-farm workflows where you want to stage only the assets needed for a given frame range.

## Command Line (headless)

```bat
octane.exe --no-gui --script "OctaneAssetsPerFrameRangeAnalyzer.lua" ^
  <output_directory> <start_frame> <end_frame> <chunk_size> [verbose]
```

### Arguments

- `<output_directory>`: where the JSON manifest will be written
- `<start_frame>`: first frame to analyze (default: `0`)
- `<end_frame>`: last frame to analyze (default: scene end)
- `<chunk_size>`: frames per chunk (default: `1`)
- `[verbose]`: `true` for per-frame details (default: `false`)

## GUI Mode

Run the script normally in Octane without arguments to show a settings dialog.

## Output

`<output_directory>/octane_assets_manifest.json`

