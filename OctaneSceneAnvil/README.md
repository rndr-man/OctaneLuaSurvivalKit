# Octane Render Scene Anvil

Combines multiple ORBX scenes into a destination scene, merging geometry under a generated geometry group node. Supports:

- Selecting a specific render target from a source scene
- Applying a frame offset to a source ORBX via `[...]`
- Optional USD node material mapping via CLI arguments

## Command Line (headless)

The script expects an `-A` argument list:

```bat
octane.exe --no-gui --script "OctaneRenderSceneAnvil.lua" ^
  -A "<saveAsScene>" "<destinationScene>" "<source1>" "<source2>" ...
```

### Argument Formats (Sources)

- Regular scene:
  - `C:\path\to\scene.orbx`
- Scene with render target:
  - `C:\path\to\scene.orbx::RenderTarget2`
- Scene with frame offset:
  - `C:\path\to\scene.orbx[100]`
- USD material mapping:
  - `usd=<targetName>.usd::mat=<sourceMat.orbx>::geo=<targetGeo.orbx>[::srcnode=<customSourceNodeName>]`

### Example

```bat
octane.exe --no-gui --script "OctaneRenderSceneAnvil.lua" ^
  -A "C:\temp\saveAsScene.orbx" "C:\temp\destinationScene.orbx" ^
     "C:\temp\sourceScene1.orbx" ^
     "C:\temp\sourceScene2.orbx::RenderTarget2" ^
     "usd=yourTargetName.usd::mat=C:\path\to\sourceScene_mat.orbx::geo=C:\path\to\sourceScene_geo.orbx"
```

