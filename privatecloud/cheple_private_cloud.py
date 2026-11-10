#!/usr/bin/env python3
"""Cheple Private Cloud - your Mac answers Cheo's questions, privately.

The phone seals every question with AES-256-GCM using a key that only your phone and this Mac
have (made when you pair). This program opens it, asks Ollama (an AI that runs on your Mac),
seals the answer and sends it back. Nothing is stored, nothing is logged (unless --debug).

1.2: Backup to your Mac. The phone sends its notes, messages, contacts, settings (and photos if you
want) sealed with the same key. They're kept sealed in ~/.cheple/backup - only your phone's key
opens them. Only files that changed are sent again.

  pip3 install cryptography
  ollama pull llama3.2:3b
  python3 cheple_private_cloud.py --pair      # the first time: shows a pairing code
  python3 cheple_private_cloud.py             # after that

The phone checks this file's SHA-256 against the one published on GitHub
(privatecloud/version.json), so you can see it's running the published code.
"""
import argparse, base64, hashlib, json, os, secrets, socket, sys, threading, time, urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

try:
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
except ImportError:
    sys.exit("Needs the cryptography package:  pip3 install cryptography")

VERSION = "1.2.0"
CONF = os.path.expanduser("~/.cheple/privatecloud.json")
PAIR_ITER = 50000          # PBKDF2 rounds for the pairing code (slow on purpose)
PAIR_WINDOW = 10 * 60      # --pair works for 10 minutes
MAX_BODY = 64 * 1024
BK_BODY = 96 * 1024                                  # 1.2: a backup chunk (24 KB of file) + sealing
BK_DIR = os.path.expanduser("~/.cheple/backup")
BK_MAX_FILE = 9 * 1024 * 1024
CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"   # no 0/O/1/I mix-ups

SELF_SHA = hashlib.sha256(open(os.path.abspath(__file__), "rb").read()).hexdigest()


def load_key():
    try:
        with open(CONF) as f:
            k = base64.b64decode(json.load(f)["key"])
            if len(k) == 32:
                return k
    except Exception:
        pass
    k = secrets.token_bytes(32)
    os.makedirs(os.path.dirname(CONF), exist_ok=True)
    fd = os.open(CONF, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)   # only you can read it
    with os.fdopen(fd, "w") as f:
        json.dump({"key": base64.b64encode(k).decode()}, f)
    return k


def seal(key, aad, data):
    n = secrets.token_bytes(12)
    return base64.b64encode(n + AESGCM(key).encrypt(n, data, aad)).decode()


def unseal(key, aad, b64):
    raw = base64.b64decode(b64, validate=False)
    if len(raw) < 28:
        raise ValueError("short")
    return AESGCM(key).decrypt(raw[:12], raw[12:], aad)


def lan_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("10.255.255.255", 1))
        return s.getsockname()[0]
    except Exception:
        return "127.0.0.1"
    finally:
        s.close()


class State:
    key = None
    model = "llama3.2:3b"
    lite = ""                 # 1.1: smaller model for when the phone is hot or low on battery
    ollama = "http://localhost:11434"
    debug = False
    pair_code = None
    pair_until = 0
    pair_tries = 0
    seen = {}                 # request ids already answered (no replays)
    lock = threading.Lock()
    calls = []                # times of recent requests (rate limit)
    bk_calls = []             # 1.2: backups send many small requests
    bk_cache = (None, b"")    # the last file read back (restore asks for it in pieces)


def ollama_ok():
    try:
        with urllib.request.urlopen(State.ollama + "/api/tags", timeout=2) as r:
            return r.status == 200
    except Exception:
        return False


def ask_ollama(messages, max_tokens, temperature, model):
    body = json.dumps({"model": model, "messages": messages, "stream": False,
                       "options": {"num_predict": int(max_tokens), "temperature": float(temperature)}}).encode()
    req = urllib.request.Request(State.ollama + "/api/chat", data=body, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read())["message"]["content"].strip()


# ---------------------------------------------------------------- 1.2: Backup
# ~/.cheple/backup/manifest.bin   sealed JSON {path: [size, crc, dp]}
# ~/.cheple/backup/f/<sha256>.bin each file, sealed (names are hashed, so no paths on disk)
# ~/.cheple/backup/part/<sha256>  a file while it's arriving (removed when it's complete)
def bk_name(path):
    return hashlib.sha256(path.encode()).hexdigest()


def bk_ok_path(p):
    return isinstance(p, str) and 0 < len(p) < 300 and "\x00" not in p and ".." not in p and (p.startswith("/") or p == "cheple/settings.txt")


def bk_write(path, data):
    tmp = path + ".tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "wb") as f:
        f.write(data)
    os.replace(tmp, path)


def bk_manifest():
    try:
        with open(os.path.join(BK_DIR, "manifest.bin")) as f:
            return json.loads(unseal(State.key, b"cheple-bk-store", f.read()))
    except FileNotFoundError:
        return {}


def bk_save_manifest(m):
    bk_write(os.path.join(BK_DIR, "manifest.bin"), seal(State.key, b"cheple-bk-store", json.dumps(m).encode()).encode())


def bk_handle(q):
    op = q.get("op")
    for d in ("f", "part"):
        os.makedirs(os.path.join(BK_DIR, d), mode=0o700, exist_ok=True)
    if op == "list":
        return {"files": bk_manifest()}
    path = q.get("path")
    if op in ("put", "get") and not bk_ok_path(path):
        return {"error": "bad name"}
    if op == "put":
        data = base64.b64decode(q.get("data", ""))
        off, size = int(q.get("off", 0)), int(q.get("size", 0))
        if size > BK_MAX_FILE:
            return {"error": "too big"}
        part = os.path.join(BK_DIR, "part", bk_name(path))
        have = os.path.getsize(part) if os.path.exists(part) else 0
        if off == 0:
            have = 0
        if off != have:
            return {"error": "out of order - back up again"}
        fd = os.open(part, os.O_WRONLY | os.O_CREAT | (os.O_TRUNC if off == 0 else os.O_APPEND), 0o600)
        with os.fdopen(fd, "wb") as f:
            f.write(data)
        if have + len(data) > BK_MAX_FILE:
            os.remove(part)
            return {"error": "too big"}
        if q.get("last"):
            with open(part, "rb") as f:
                whole = f.read()
            bk_write(os.path.join(BK_DIR, "f", bk_name(path) + ".bin"), seal(State.key, b"cheple-bk-file", whole).encode())
            os.remove(part)
            with State.lock:
                m = bk_manifest()
                m[path] = [size, int(q.get("crc", 0)), bool(q.get("dp"))]
                bk_save_manifest(m)
                State.bk_cache = (None, b"")
        return {"ok": 1}
    if op == "get":
        off, n = int(q.get("off", 0)), min(int(q.get("len", 24576)), 32768)
        name, data = State.bk_cache
        if name != path:
            try:
                with open(os.path.join(BK_DIR, "f", bk_name(path) + ".bin")) as f:
                    data = unseal(State.key, b"cheple-bk-file", f.read())
            except FileNotFoundError:
                return {"error": "not in the backup"}
            State.bk_cache = (path, data)
        return {"data": base64.b64encode(data[off:off + n]).decode(), "size": len(data)}
    if op == "done":   # the phone's whole list: anything else was deleted on the phone
        keep = set(p for p in q.get("keep", []) if isinstance(p, str))
        with State.lock:
            m = bk_manifest()
            for p in [p for p in m if p not in keep and (q.get("photos") or not p.startswith("/photos/"))]:
                try:
                    os.remove(os.path.join(BK_DIR, "f", bk_name(p) + ".bin"))
                except FileNotFoundError:
                    pass
                del m[p]
            bk_save_manifest(m)
        print(time.strftime("%b %d %H:%M") + f"  Backup from your Cheple: {len(m)} files kept.")
        return {"ok": 1, "files": len(m)}
    return {"error": "unknown"}


class Handler(BaseHTTPRequestHandler):
    server_version = "CheplePrivateCloud/" + VERSION

    def log_message(self, fmt, *args):   # quiet: no addresses or content in the log
        if State.debug:
            sys.stderr.write("[debug] " + (fmt % args) + "\n")

    def reply(self, code, body, ctype="application/json"):
        b = body.encode() if isinstance(body, str) else body
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        if self.path == "/status":
            return self.reply(200, json.dumps({"cheple": 1, "version": VERSION, "model": State.model, "lite": State.lite,
                                               "sha256": SELF_SHA, "ollama": ollama_ok()}))
        if self.path == "/pair":
            with State.lock:
                if not State.pair_code or time.time() > State.pair_until or State.pair_tries >= 10:
                    return self.reply(403, '{"error":"not pairing"}')
                State.pair_tries += 1
                salt = secrets.token_bytes(16)
                pk = hashlib.pbkdf2_hmac("sha256", State.pair_code.encode(), salt, PAIR_ITER, 32)
                box = seal(pk, b"cheple-pair", State.key)
            print("A phone asked to pair (if it has the right code, it's paired now).")
            return self.reply(200, json.dumps({"salt": base64.b64encode(salt).decode(), "iter": PAIR_ITER, "box": box}))
        self.reply(404, '{"error":"no"}')

    def do_POST(self):
        if self.path == "/v1/backup":
            return self.do_backup()
        if self.path != "/v1/ask":
            return self.reply(404, '{"error":"no"}')
        n = int(self.headers.get("Content-Length", 0) or 0)
        if n <= 0 or n > MAX_BODY:
            return self.reply(413, '{"error":"size"}')
        raw = self.rfile.read(n).decode(errors="replace").strip()
        now = time.time()
        with State.lock:
            State.calls = [t for t in State.calls if now - t < 60]
            if len(State.calls) >= 30:
                return self.reply(429, '{"error":"slow down"}')
            State.calls.append(now)
        try:
            q = json.loads(unseal(State.key, b"cheple-ask-v1", raw))
        except Exception:
            return self.reply(403, '{"error":"not sealed with the paired key"}')   # someone else, or not paired
        rid = str(q.get("id", ""))
        t = int(q.get("t", 0) or 0)
        with State.lock:
            for k in [k for k, v in State.seen.items() if now - v > 900]:
                del State.seen[k]
            if not rid or rid in State.seen or (t and abs(now - t) > 600):
                return self.reply(403, '{"error":"old or repeated"}')
            State.seen[rid] = now
        msgs = [{"role": str(m.get("role", "user")), "content": str(m.get("content", ""))}
                for m in q.get("messages", [])][:12]
        try:
            t0 = time.time()
            model = State.lite if (q.get("lite") and State.lite) else State.model
            a = ask_ollama(msgs, min(int(q.get("max_tokens", 220)), 800), q.get("temperature", 0.6), model)
            if State.debug:
                print(f"[debug] answered in {time.time() - t0:.1f} s")
        except Exception as e:
            print("Ollama didn't answer:", type(e).__name__, "- is it running?  (ollama serve)")
            return self.reply(502, '{"error":"ollama"}')
        out = json.dumps({"id": rid, "t": int(time.time()), "model": model, "content": a}).encode()
        self.reply(200, seal(State.key, b"cheple-reply-v1", out), "text/plain")


def _do_backup(self):
    n = int(self.headers.get("Content-Length", 0) or 0)
    if n <= 0 or n > BK_BODY:
        return self.reply(413, '{"error":"size"}')
    raw = self.rfile.read(n).decode(errors="replace").strip()
    now = time.time()
    with State.lock:
        State.bk_calls = [t for t in State.bk_calls if now - t < 60]
        if len(State.bk_calls) >= 600:
            return self.reply(429, '{"error":"slow down"}')
        State.bk_calls.append(now)
    try:
        q = json.loads(unseal(State.key, b"cheple-bk-v1", raw))
    except Exception:
        return self.reply(403, '{"error":"not sealed with the paired key"}')
    rid = str(q.get("id", ""))
    t = int(q.get("t", 0) or 0)
    with State.lock:
        for k in [k for k, v in State.seen.items() if now - v > 900]:
            del State.seen[k]
        if not rid or rid in State.seen or (t and abs(now - t) > 600):
            return self.reply(403, '{"error":"old or repeated"}')
        State.seen[rid] = now
    try:
        out = bk_handle(q)
    except Exception as e:
        print("Backup problem:", type(e).__name__)
        out = {"error": "the Mac couldn't save it (" + type(e).__name__ + ")"}
    out["id"] = rid
    self.reply(200, seal(State.key, b"cheple-bk-reply-v1", json.dumps(out).encode()), "text/plain")


Handler.do_backup = _do_backup


def main():
    ap = argparse.ArgumentParser(description="Cheple Private Cloud")
    ap.add_argument("--pair", action="store_true", help="show a pairing code (works for 10 minutes)")
    ap.add_argument("--port", type=int, default=8787)
    ap.add_argument("--model", default="llama3.2:3b", help="any model you've pulled with ollama")
    ap.add_argument("--lite-model", default="", help="smaller model used when the phone is hot or low on battery, e.g. llama3.2:1b")
    ap.add_argument("--ollama", default="http://localhost:11434")
    ap.add_argument("--new-key", action="store_true", help="forget every paired phone (makes a new key)")
    ap.add_argument("--debug", action="store_true", help="print timings (never the questions)")
    a = ap.parse_args()
    if a.new_key and os.path.exists(CONF):
        os.remove(CONF)
    State.key = load_key()
    State.model, State.lite, State.ollama, State.debug = a.model, a.lite_model, a.ollama.rstrip("/"), a.debug
    print(f"Cheple Private Cloud {VERSION}  (code SHA-256 {SELF_SHA[:16]}...)")
    print(f"  On the phone: Settings > Private AI > At Home:  {lan_ip()}")
    print(f"  AI model: {State.model}" + (f"  (low battery: {State.lite})" if State.lite else "") +
          ("" if ollama_ok() else "   ** Ollama isn't running - start the Ollama app **"))
    if a.pair:
        State.pair_code = "".join(secrets.choice(CODE_CHARS) for _ in range(8))
        State.pair_until = time.time() + PAIR_WINDOW
        print(f"\n  Pairing code:  {State.pair_code[:4]}-{State.pair_code[4:]}   (works for 10 minutes)\n")
    srv = ThreadingHTTPServer(("0.0.0.0", a.port), Handler)
    print(f"  Listening on port {a.port}.  Ctrl+C to stop.")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")


if __name__ == "__main__":
    main()
