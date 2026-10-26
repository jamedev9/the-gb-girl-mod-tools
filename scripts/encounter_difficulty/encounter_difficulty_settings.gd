extends RefCounted
class_name EncounterDifficultySettings

### The master switch of the whole encounter difficulty feature. While it is false NOTHING of it runs in the game
### (currently ON, so the stars can be tried on the encounter description display):
### EncounterDifficultyService doesn't bind to the save, calculate, listen for rewards or write its debug log,
### the Ctrl+1-4 debug keys aren't added, and the map nodes show no stars (whatever their own
### show_difficulty_stars says). The offline tools in tools/encounter_difficulty still work when you run them.
### To turn the feature back on, set this to true (one line, and it applies to the prototype and the rework alike).
const ENABLED: bool = true
