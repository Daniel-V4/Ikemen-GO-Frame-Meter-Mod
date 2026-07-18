# Ikemen GO Framemeter Mod

**Version:** 0.1.0 (Beta)  
**Tested on:** Ikemen GO Nightly (Build 2025-04-05)

An SF6-style Frame Meter for Ikemen GO training mode. This mod provides visual feedback on startup, active, and recovery frames directly during gameplay for an easier time labbing.

> **Disclaimer**: This mod is still a very early work in progress. The static information (the numbers displayed above the bar) is currently very unstable. It is highly recommended to use this mod alongside the POTS Attack Data Display or a dedicated training character. It also stands untested for online play, and while it only affects the training mode, it is not recommended to use it online. Please use at your own risk. 

If you're also interested in having control over the dummy's reversals and a comprehensive command list for your character, check out its sister mod: [Ikemen GO Reversal Mod](../reversal_mod/README.md).

## Color Legend

Here's the standard convention for the mod:

- **Gray**: Idle (can act)
- **Green**: Startup frames
- **Red**: Active frames
- **Blue**: Recovery frames
- **Purple**: The first frame of idle where you still cannot input anything (effectively your last frame of recovery)
- **Cyan**: Special movement frames (e.g., dashes, jump startup, etc.)
- **Yellow**: Blockstun and Hitstun

## Compatibilit

Because characters in Ikemen GO/M.U.G.E.N can be coded in vastly different ways, compatibility varies:

- **Fully Compatible**: Tested and working well with **POTS** and **CvS2** style characters.
- **Partially Incompatible**: Characters with highly custom state machines (like **Toaru** style characters) may not parse perfectly. However, the meter will still accurately show when you are in a move versus when you are not, so it's still useful for labbing things like pressure strings.

**Requirements for full compatibility:**
To have frame data (startup/active/recovery) parsed perfectly, a character must use standard M.U.G.E.N state definitions (`[StateDef]`), standard hit definitions (`HitDef`), and standard animation clsn (hitbox) definitions without heavy reliance on external custom helper-based physics or completely overridden state controllers for basic attacks.

## Screenpack Requirements

Currently, there are no specific screenpack requirements. The frame meter draws directly on the screen using the engine's built-in drawing functions and scales to fit most standard resolutions.

## Installation

1. Copy `frameviewer.lua` to your `external/mods/` directory.
2. Copy the entire `frameviewer` folder to your `external/mods/` directory.
3. Launch Ikemen GO. The mod should load automatically when you enter Training Mode.

## Configuration

You can customize the appearance of the frame meter by editing `framemeter.lua` inside the `frameviewer` directory. Adjustable settings include:
- `MAX_FRAMES`: Maximum number of frames displayed on the meter.
- `box_w`, `box_h`: Width and height of individual frame boxes.
- `colors`: Hex color codes for the different frame states.

## Bug Reporting

If you encounter issues, bugs, or characters that severely break the frame meter, please open an **Issue** on the GitHub repository for this mod. Be sure to include:
- The character you were testing (with a download link if possible).
- The specific move or action that caused the issue.
- A screenshot of the frame meter if it behaves unexpectedly.
