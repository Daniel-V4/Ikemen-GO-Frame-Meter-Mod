# Ikemen GO Frameviewer Mod

Here is a SF6-style Frame Meter for Ikemen GO training mode! You can finally see your startup, active, and recovery frames directly during gameplay instead of just guessing. It takes hard work to put this together and have it make sense, so I hope you all enjoy it!

> [!WARNING]
> **DISCLAIMER**: Listen, this is still a very early work in progress. The static information (the numbers above the bar) is still very unstable and jank right now. I highly recommend using this alongside POTS training information if you want the most accurate data.

## Color Legend

Here's how to read the heat of battle on the meter:

- **Gray**: Idle (you can act!)
- **Green**: Startup frames
- **Red**: Active frames
- **Blue**: Recovery frames
- **Purple**: That first frame of idle where you still can't input anything (effectively your last frame of recovery before you can move)
- **Cyan**: Movement stuff (dashes, jump startup, etc.)
- **Yellow**: Blockstun and Hitstun (when you're locked down!)

## Compatibility

M.U.G.E.N and Ikemen characters are coded in all sorts of crazy ways, so it's not perfect for everyone:

- **Works Great**: Tested and working well with POTS and CvS2 style characters.
- **Incompatible but Still Useful**: Characters with completely custom state machines (like Toaru style) might not parse perfectly. But the meter will still accurately show when you're in a move and when you're not, which is still super useful for timing!

**Requirements for full compatibility:**
To have the frame data parsed perfectly without garbage, a character needs to use standard M.U.G.E.N state definitions (`[StateDef]`), standard `HitDef`s, and standard animation clsn (hitboxes). If a char relies heavily on custom helper-based physics or completely overrides state controllers for basic attacks, it's gonna be jank.

## Screenpack Requirements

None! It doesn't matter what screenpack you use, the frame meter draws directly on the screen using the engine's built-in functions. 

## Installation

1. Copy `frameviewer.lua` into your `external/mods/` directory.
2. Copy the entire `frameviewer` folder into your `external/mods/` directory as well.
3. Launch Ikemen GO, hop into Training Mode, and feel the burn!

## Configuration

You can customize the appearance of the frame meter by editing `framemeter.lua` inside the `frameviewer` directory. Adjustable settings include:
- `MAX_FRAMES`: Maximum number of frames displayed on the meter.
- `box_w`, `box_h`: Width and height of individual frame boxes.
- `colors`: Hex color codes for the different frame states.

## Bug Reporting

If you find bugs or some char that completely breaks the meter, please open an Issue on the GitHub repository. Try to include the character you were using (with a download link if you can), what move caused it, and a screenshot so I can see what kind of garbage is happening. 
