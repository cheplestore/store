# Cheple Private Cloud

Your Mac answers Cheo's questions, so they never go to an AI company.

```
Cheple phone  --(sealed with your key)-->  your Mac  -->  Ollama (AI on your Mac)
```

- **Locked end to end.** Every question is sealed with AES-256-GCM using a key that only your
  phone and your Mac have. Wi-Fi, your router and a tunnel (Tailscale, ngrok) see only scrambled
  bytes. A question with the wrong key, an old one, or a replayed one is refused.
- **Nothing is kept.** The server holds nothing on disk except its key, and logs no questions.
- **Code you can check.** This file is public here on GitHub. `version.json` holds its SHA-256,
  and the phone compares it with what your Mac reports (Settings > Private AI > Test Connection).
  This catches an edited or out-of-date copy. It's a check, not a proof: a computer someone else
  controls could lie about it.

## Set up (about 10 minutes, once)

1. **Install Ollama** from https://ollama.com (the Mac app), then in Terminal:
   ```
   ollama pull llama3.2:3b
   ollama pull llama3.2:1b
   ```
   (the small 1b one answers when the phone is hot or under 20% battery)
   Any model works (for example `qwen2.5:7b` if your Mac has 16 GB of memory). Start the server
   with `--model qwen2.5:7b` to use it.
2. **Download this folder** (`cheple_private_cloud.py` plus the two `.command` files).
3. **Pair:** double-click `pair_cheple_cloud.command`. The first time, right-click > Open. If macOS
   asks whether Python can accept incoming connections, click **Allow**. It shows:
   ```
   On the phone: Settings > Private AI > At Home:  192.168.1.20
   Pairing code:  K7QX-M2PA
   ```
4. On the Cheple: **Settings > Private AI > Pair with My Mac**. Type the address, then the code.
5. From now on, double-click `start_cheple_cloud.command` to run it. It keeps the Mac awake while
   it runs.

## Away from home (optional)

The phone needs a web address to reach your Mac over 4G. Either of these is free:

- **Tailscale Funnel:** install Tailscale on the Mac, then run `tailscale funnel 8787`. It gives
  `https://your-mac.something.ts.net`.
- **ngrok:** `ngrok http 8787 --url=your-name.ngrok-free.app`

Put that address in **Settings > Private AI > Away**. Because the questions are sealed with your
key, the tunnel company can't read them.

## Options

| | |
|---|---|
| `--pair` | show a pairing code (10 minutes, 10 tries) |
| `--model NAME` | which Ollama model to use (default `llama3.2:3b`) |
| `--lite-model NAME` | a smaller one for when the phone is hot or under 20% (for example `llama3.2:1b`, after `ollama pull llama3.2:1b`) |
| `--port N` | default 8787 |
| `--new-key` | forget every paired phone |
| `--debug` | print timings (never the questions) |
