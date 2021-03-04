# smbdataset
Super Mario Bros. (NES) gameplay dataset for machine learning.

While I don't upload it here, you can download it from here: https://drive.google.com/file/d/1htB9qCxbeD2xCHqtzCt3ITFdd1CDrWjl/view?usp=sharing

## Features
- 256x240 8bit indexed PNG images with RAM snapshot into metadata
- 256 actions (all possible NES controler input combinations, including START and SELECT), stored as an integer on each PNG metadata
- 737,134 frames
- 32 levels (normal mode)
- 141 wins + 139 failures = 280 episodes
- 889MB compressed, 3.4GB uncompressed
- 1 player
- 60 FPS
- Includes warps
- Game beaten

## How to Use
Each PNG contains relevant information in its name itself and in its metadata.

### Filename Format
Folder: &lt;name>_&lt;SESSID>_e&lt;episode>_WORLD-LEVEL_&lt;outcome> 

Frame: &lt;name>_&lt;SESSID>_e&lt;episode>_WORLD-LEVEL_f&lt;frame>_a&lt;action>_&lt;datetime>.&lt;outcome>.png

- name: The logged user who recorded that gameplay. Currently there is only 1 player (me: Rafael);
- SESSID: Session ID. Just to differentiate between different gameplay sessions;
- episode: Episode number in current session. An episode is 1 level, be it a completion or a failed (death) run;
- WORLD: Current world from 1 to 8;
- LEVEL: Current level from 1 to 4;
- frame: Frame number in a single episode / run (starting from 1);
- action: An 8 bit integer from 0 to 255. Each bit corresponds to a button in the following order (from MSB to LSB): up, down, left, right, A, B, start, select;
- datetime: Date and time the frame was captured (YYYY-MM-DD_HH-mm-SS);
- outcome: Does this folder / frame corresponds to a completion (win) or a failed / death (fail) run / episode?

### PNG Metadata Format
The PNG format supports metadata <a href="https://www.w3.org/TR/PNG-Chunks.html">chunks</a> after the IEND token. After each chunk token there is a \0 and then the corresponding data. We use 3 custom chunks for storing game data inside the image:

- tEXtRAM: RAM snapshot at that frame, consisting of 2048 bytes;
- tEXtBP1: Player 1 input buttons at that frame, same format as in the filename (1 byte);
- tEXtOUTCOME: Does this frame corresponds to a completion (win) or a failed / death (fail) run / episode? fail = 1, win =2 (1 byte).

#### Useful References for Reading PNG Chunks
- https://pypng.readthedocs.io/
- https://stackoverflow.com/questions/48631908/python-extract-metadata-from-png

## How to Cite

<pre>
@misc{Pinto2021,
  author = {Pinto, R.C.},
  title = {Super Mario Bros. Gameplay Dataset},
  year = {2021},
  publisher = {GitHub},
  journal = {GitHub repository},
  howpublished = {\url{https://github.com/rafaelcp/smbdataset}}
}
</pre>
