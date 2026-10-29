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
