# Gaussian Splat Sequence Animation

GUI tool to animate Gaussian Splat sequences using an absolute-file sequence (PLY/SPZ).

Entry point:
`OctaneSplatsSequence.lua` (folder: `OctaneSplatsSequence/`)

## Workflow

1. Open the script in Octane (Scripts menu, or wherever your Octane maps it).
2. Select a Gaussian Splat node from the dropdown.
3. Click `Browse...` and select *any* frame file from your sequence (PLY or SPZ).
4. The script will:
   - Detect the on-disk filename pattern
   - Scan the directory for matching frames
   - Auto-fill `Start Frame` / `End Frame`
5. Click `Apply Animation`.

## Naming Pattern

The script expects frame numbers embedded in the filename, for example:
- `my_splats_0001.ply`
- `my_splats_0042.spz`

Padding width is inferred from the digits in the filename you pick.

