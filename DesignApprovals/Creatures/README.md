# Eclipse creature artwork — approval set

These are concept vectors for review only. They are deliberately not connected to the app yet; the existing in-app artwork and selector remain unchanged until the designs are approved.

## Included concepts
- Toothless — full-body Night Fury silhouette, wings, tail fins and green eyes
- Phoenix — full-body firebird with layered wings, crest, talons and flame feathers
- Wolf — full-body athletic wolf with detailed fur, tail and paws
- Kitsune — nine flowing tails, fox mask markings and flame ornament
- Paw — dimensional paw emblem with engraved detail
- Siren — full-body sea siren with flowing hair, scaled tail and water ribbons

## Quality and colour plan
SVG paths are resolution-independent. They can be rendered at 4K (3840×2160 output canvas) or larger without pixelation. The artwork uses its own original gradient palette and can be adapted to three app modes after approval:
1. Original — preserve each design's authored colours.
2. Custom — apply the user's selected colour while retaining the shape's highlights and shadows.
3. Silver — use a metallic silver gradient with light/dark bevel shading.

The 4K setting should apply to the export/rendering pipeline, not force a 4K bitmap to be decoded for every small on-screen animation. The app should use the vector source at device scale for smooth, sharp rendering and export at 4K when a 4K output is requested.

## Review
Open approval-board.svg or inspect the individual SVGs in this folder. Please approve or request changes before these are installed into the app asset catalog or exposed in the app selector.
