# Cheple Store

The App Store for the Cheple phone (cOS 4.4+). The phone downloads `store.json`, shows every app in it,
and installs an app by downloading its `.lua` file to the SD card.

## Adding an app
1. Put the app in the `apps` folder (for example `apps/myapp.lua`). The top of the file needs:
   ```
   -- name: My App      (14 letters max)
   -- icon: Ma          (1-3 letters)
   -- color: #2D9CDB
   ```
2. Add it to the `apps` list in `store.json`:
   ```json
   {"id": "myapp", "name": "My App", "icon": "Ma", "color": "#2D9CDB", "category": "Games",
    "version": "1.0", "author": "you", "featured": false,
    "desc": "What it does.", "file": "apps/myapp.lua", "size": 1234}
   ```
   `id` = the file name without `.lua`. `size` = the file size in bytes.
3. Commit. Phones see it next time the App Store opens (GitHub can take up to 5 minutes).

## Updating an app
Change the file, then raise its `"version"` in `store.json` (for example `"1.0"` -> `"1.1"`).
Phones that have it show an **Update** button.

## Wallpapers (cOS 4.6+)
1. Put a 320x480 JPEG in `wallpapers/` and a small 96x144 JPEG with the same name in `wallpapers/thumbs/`.
2. Add it to the `wallpapers` list in `store.json`:
   ```json
   {"id": "beach", "name": "Beach", "file": "wallpapers/beach.jpg", "thumb": "wallpapers/thumbs/beach.jpg", "size": 15000}
   ```

## Ringtones and alert tones (cOS 4.6+)
1. Put a WAV file in `sounds/` (mono, 22050 Hz, 16-bit, under 1 MB).
2. Add it to the `sounds` list in `store.json`. `"kind"` is `"ringtone"` (alarms and timers) or `"alert"` (notifications):
   ```json
   {"id": "chime", "name": "Chime", "kind": "alert", "file": "sounds/chime.wav", "size": 20000}
   ```

## cOS updates (cOS 4.6+)
Phones check `cos/version.json`. To release a new cOS:
1. In Arduino IDE: Sketch > Export Compiled Binary. Rename the `.ino.bin` (not the merged one) to `cheple_cos.bin`
   and upload it to `cos/`, replacing the old one.
2. In `cos/version.json`, raise `"version"` (for example `"4.6.1"`), and change `"size"` and `"notes"`.
   Upload the .bin FIRST, then version.json, so no phone downloads a half-uploaded file.
