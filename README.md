# Simple Sandbox VR

A standalone VR physics sandbox for PICO 4, built with Godot 4 and OpenXR.

## Current starter build

This repository now contains the first Godot project scaffold:

- Godot project configuration using the Mobile renderer
- A simple test room with a physical floor
- Two physics cubes (red and blue)
- OpenXR initialization attempt and PICO-style left/right controller nodes
- Procedural low-poly hand meshes attached to the controllers
- A desktop preview camera when OpenXR is unavailable

## Controls and implementation status

The current hand meshes are visual placeholders. Finger animation, trigger/grip input mapping, grabbing, releasing, and hand/object collision are not implemented yet.

## Target

- Headset: PICO 4 standalone
- Runtime: OpenXR
- Engine: Godot 4
- Input: PICO 4 controllers (not optical hand tracking)
- Hand style: low-poly 3D hands, bare wrists

## Project layout

- `project.godot` — project settings
- `scenes/main.tscn` — main scene
- `scripts/main.gd` — initial room, props, XR setup, and placeholder hand meshes

## Next milestones

1. Confirm the project opens and runs in the Godot editor.
2. Configure and verify the PICO 4 OpenXR Android export.
3. Animate fingers from controller trigger/grip input.
4. Implement reliable object grabbing, carrying, and releasing.
5. Add more tools and sandbox interactions.

No APK has been built or tested on a headset yet. The first milestone is a minimal, verifiable project before expanding the mechanics.
