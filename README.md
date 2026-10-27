# The Gangbang Girl Mod Tools

## Installation
Download the project, then download Godot 4.7.2 and open the project in Godot.

## Setup
1. Open the `mod_info_config.gd` script. Add your name and the name of the mod, then run the script (Ctrl+Shift+X).
2. To make maps, make sure the map editor plugin is enabled: **Project > Project Settings > Plugins**, tick **Encounter Map Editor**. An "Encounter Map" tab appears at the top of the editor, next to 2D / 3D / Script.

The tool comes with a bunch of examples for the different resources. These can be safely deleted.

## How to
The project contains the files needed to make mods and content for the game.
Current capabilities of the mod tool:
* Adding custom video clips
* Making custom character definitions
* Making passive effects
* Making status effects
* Making event cards
* Replacing images
* Making encounters
* Making map regions
* Making maps (your own overworld map, picked in-game from a dropdown)
* Adding custom rewards

Your content refers to other content by its ID: the IDs of the base game's content, or the IDs of content in your mod.

### Resource IDs
IDs for the main game's resources can be found here: https://docs.google.com/spreadsheets/d/1OT9ggGOfzt4Y84_ii2bFYrO-xegaMyqTZXvsb6jgrfA/edit?usp=sharing

### Text
Names and descriptions in your mod are shown in the game exactly as you write them. They are not translated.

## Video clips
Move your video files to `mod_export_data/videos`. In the same folder, create a VideoClip resource for each clip. Add the correct tags to the resource and drag the video clip onto it. The name of the resource itself is not important.
Accepted file formats: *.mp4, *.m4v, *.mov, *.mkv, *.webm, *.avi, *.ogv

## Custom character definitions
In `mod_export_data/characters`, create a new CharacterDefinition resource. You can place a custom portrait in `mod_export_data/images`, then link the image in the CharacterDefinition resource.

## Status effects
Go to `mod_export_data/status_effects` and create a new StatusEffectDefinition resource.

Fill in:
* **Status Id**: a unique ID. It must not be the ID of one of the game's statuses (such a status is skipped).
* **Status Name** and **Status Description**: shown exactly as written.
* **Status Picture**: any image in the project. It is copied into the mod when you export.
* **Status Category**: Buff or Debuff.
* **Stackable** / **Max Stacks**: whether applying the status again adds a stack (Max Stacks 0 = no limit).
* The effect components: what the status does while it is active, each turn, or when something happens.

Cards, Moves and passives apply a status by its ID: the **Status Id** field of an **Apply Status Effect**. The field has a dropdown of the statuses in your mod, and you can type the ID of one of the game's statuses.

## Passive effects
Go to `mod_export_data/passives` and create a new PassiveEffectDefinition resource. These are made in the same way as status effects.

## Event cards
Event cards can be made to add new Combo Cards, or to use as starting cards for custom characters.
* **Translation Id**: not used by mods, leave it empty.

## Image overrides
In `mod_export_data/image_replacements`, create a new ImageReplacementSet resource. Inside this resource, add one or more ImageReplacement resources. Each ImageReplacement needs a ReplacementType, the ID of the replacement target, and a path to the image inside `mod_export_data/images`.
Image sets can be set to only work for a single character ID.
Replacement IDs can be found on the development drive: https://docs.google.com/spreadsheets/d/e/2PACX-1vS0aepLrAZGfHcRobEaPLUdP8xXHzH_OUY8UHhFPbBQc0GqeXn04vKqrSlPEnaxqp0oyUpT6hqi_ElN/pubhtml
The currently supported image replacements are:
* Event Card Image: set the ID to the ID of the event card.
* Action Card Image: use the ID of the action (bj, vaginal, anal, right_hj, left_hj).
* Opponent Type Image: use the ID of the opponent type.

## Encounters
Go to `mod_export_data/encounters` and create a new EncounterDefinition resource for each encounter. A mod encounter is only played from a modded map (see "Modded maps"); it never appears on the game's own map.

Fill in:
* **Encounter Id**: a unique ID. It must not be the ID of one of the game's encounters (such an encounter is skipped).
* **Encounter Display Name** and **Encounter Description**: shown exactly as written.
* **Encounter Picture**: any image in the project. It is copied into the mod when you export.
* Music, one of:
  * **Encounter Music**: your own `.ogg`, `.mp3` or `.wav` file. Other formats can't be loaded by the game. It is copied into the mod when you export.
  * **Music Track Id**: one of the game's soundtracks, by its ID (see "Resource IDs"). Leave Encounter Music empty when you use it: your own file wins if both are set.
* **Opponents In Encounter Reserves**: the Partners in the encounter, as opponent type ID -> how many. At least one is needed.
* **Min / Max Simultaneous Opponents**: how many Partners can be active at once (Max 0 = the game's default).
* Optional:
  * **Fixed Spawn Order**: spawn number -> opponent type ID, for Partners that must come at a set point.
  * **Event Cards Starting Hand**: card ID -> how many.
  * **Temporary Player Passives**: passive IDs the player has for this encounter only.
  * **Rewards Granted By Clearing**: reward IDs.
  * **Forbid All Summons / Forbidden Ally Summons**.
* **Map Region Id**: the ID of a map region, yours (see "Map regions") or one of the game's (for example `college`, `office`). It sets the encounter's colour on the map and its legend entry.

**Unlock Conditions** and **Branch Index** on the encounter itself are not used for mod encounters. On a modded map, the map decides what unlocks an encounter (see below).

If your encounter uses content that isn't installed for the player (for example a card or music track from another mod they removed), that content is left out. An encounter with no installed Partner left is skipped.

## Modded maps
A modded map is your own overworld map. When the player has a mod with a map installed, a dropdown appears at the top right of the game's map. It lists "Main game" and every installed modded map. Each save remembers the map that was picked. If the mod is removed later, the save opens on "Main game" again.

## Map regions
Go to `mod_export_data/map_regions` and create a new MapRegionDefinition resource for each region.

Fill in:
* **Region Id**: a unique ID. It must not be the ID of one of the game's regions (such a region is skipped).
* **Region Name**: shown in the map's legend exactly as written.
* **Background Color**: the region's colour on the map.

Put an encounter in a region by setting its **Map Region Id** (see "Encounters"). Encounters can use your regions or the game's.

### Making a map
1. Make sure the Encounter Map Editor plugin is enabled (see Setup).
2. Go to `mod_export_data/maps` and create a new EncounterMap resource.
3. In the Inspector, set:
   * **Map Id**: a unique ID. The game remembers the player's choice by it, so don't change it after release.
   * **Map Name**: the name shown in the dropdown.
4. Double-click the map resource in the FileSystem dock to open it in the **Encounter Map** tab.

### Placing encounters
* The list on the left and the "Encounters not on the map" panel on the right show every encounter in `mod_export_data/encounters`. Drag one onto the graph, or double-click it, to place it.
* To place one of the base game's encounters, type its ID into the box under the list and press **Add by id**. These nodes show only their ID, since the base game's encounter files aren't part of the mod tools.
* Drag nodes to move them. Leave some space between them: the game's map nodes can be wider than the ones in the editor.
* Select nodes and press Delete to remove them.

### Unlocking encounters
* Drag from a node's **right** dot to another node's **left** dot to draw a line: clearing the first encounter unlocks the second. Drag a line off its left end to remove it.
* A node with **no lines and no conditions** is open from the start. Every map needs at least one.
* Select a node to edit it in the Inspector:
  * **Line Requirement**: **ALL** = every encounter with a line into this node must be cleared. **ANY** = clearing one of them is enough (for paths that join up).
  * **Unlock Conditions**: extra requirements on top of the lines (for example "win by turn N"). A "clear encounters in region" condition here counts only the encounters on your map.
* Progress is shared with the rest of the save: an encounter the player has already cleared on another map counts as cleared on yours.

## Rewards
Go to `mod_export_data/rewards` and create a reward resource for each reward. Pick the reward type that does what you want (for example Reward_GivePlayerEventCards, Reward_GivePlayerPassive, Reward_UnlockPlayerActions, Reward_IncreasePlayerStats).

Fill in:
* **Reward Id**: a unique ID. It must not be the ID of one of the game's rewards (such a reward is skipped).
* **Reward Name** and **Reward Description**: shown exactly as written.
* **Reward Picture**: any image in the project. It is copied into the mod when you export.
* **Unlock Conditions**: what the player must do to earn it (for example clear an encounter, win by turn N).
* The fields of the reward type: what it gives, by ID (card, passive, Action or character IDs).

A reward is skipped if it gives content that isn't installed for the player (for example a card from another mod they removed). An encounter can hand out your reward directly through its **Rewards Granted By Clearing**.

### Saving
Press **Save** in the tab, or save the project (Ctrl+S).

## Exporting the mod
When you are ready to build the mod, open and run the `mod_exporter.gd` script (Ctrl+Shift+X). This converts your resources into the right format inside the `mod_build_output` folder:
* Pictures (encounters, status effects, characters, passives, cards) go into `images`, and encounter music into `music`.
* Status effects, map regions, encounters and maps each get their own folder.
* A map without a Map Id, or with a node that has no encounter, is not exported. The same goes for any resource that fails its checks. The Output panel says which file and why.

Move the output folder into the game's mods folder:
`Users\username\AppData\Roaming\Godot\app_userdata\The Gangbang Girl\mods`

To share the mod, put the whole mod folder into a .zip file and share that.