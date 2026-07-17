# Ikemen GO Frameviewer Mod

An SF6-style Frame Meter for Ikemen GO training mode. This mod provides visual feedback on startup, active, and recovery frames directly during gameplay, helping players understand frame data intuitively.

## Installation

1. Copy `frameviewer.lua` to your `external/mods/` directory.
2. Copy the entire `frameviewer` folder to your `external/mods/` directory.
3. Launch Ikemen GO. The mod should load automatically.

## Usage

Once installed, enter Training Mode. The frame meter will automatically appear and start recording frame data for moves executed by both players.

## Configuration

You can customize the appearance of the frame meter by editing `framemeter.lua` inside the `frameviewer` directory. Adjustable settings include:
- `MAX_FRAMES`: Maximum number of frames displayed on the meter.
- `box_w`, `box_h`: Width and height of individual frame boxes.
- `colors`: Hex color codes for different frame states (Startup, Active, Recovery, etc.).
