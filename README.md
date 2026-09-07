# The Gangbang Girl Mod Tools
## Installation
Download the project, then download Godot 4.5.1 and open the project in Godot.

## Setup
Open the mod_info_config.gd scipt. Add your name and the name of the mod, then run the script (ctrl+shift+x).
The tool comes with an example mod with 2 video clips and a character definition, these can safely be deleted.

## How to
The project contains the relevant files required to make mods and content for the game.
Current capabilities of the mod tool:
* Adding custom video clips
* Making custom character definitions

## Video clips
Move your video files to mod_export_data/videos. In the same folder, for each clip, create a VideoClip resource. Add the correct tags to the resource and drag the correct video clip to it. The name of the resource itself is not important.

## Custom character definitions
In mod_export_data/characters, create a new CharacterDefinition resource. You can place a custom portrait in mod_export_data/images, then link the path of the image in the CharacterDefinition resource.

## Passive Effects
New passives can be created. The unique ID you assign to the ID can be added to your custom character definitions.

## Event Cards
Event cards can be made to add new Combo Cards or to add as starting cards for custom characters.

## Image overrides
In mod_export_data/image_replacements, create a new ImageReplacementSet resource. Inside this resource, add multiple ImageReplacement resources. Each ImageReplacement needs a ReplacementType, an ID for the replacement target, and a path to the image inside mod_export_data/images.
Image sets can be set to only work for a single character ID.
Replacement IDs can be found on the development drive: https://docs.google.com/spreadsheets/d/e/2PACX-1vS0aepLrAZGfHcRobEaPLUdP8xXHzH_OUY8UHhFPbBQc0GqeXn04vKqrSlPEnaxqp0oyUpT6hqi_ElN/pubhtml
The currently supported image replacements are:
* Event Card Image: set the ID in ReplacementType to the ID of the event card.
* Action Card Image: Use the ID of the corresponding action (bj, vaginal, anal, right_hj, left_hj)
* Opponent Type Image: use ID of corresponding opponent type.

## Exporting the mod
When you are ready to build the mod, open and run the "mod_exporter.gd" script (ctrl+shift+x). This will convert your resources into the correct format for the mod inside the mod_build_output folder.
The output folder can then be moved to the mods folder of the game:
Users\username\AppData\Roaming\Godot\app_userdata\The Gangbang Girl\mods
To share the mod with others, add the entire mod folder into a .zip file and share it.