#!/usr/bin/env python3
"""Cheple Private Cloud - your Mac answers Cheo's questions, privately.

The phone seals every question with AES-256-GCM using a key that only your phone and this Mac
have (made when you pair). This program opens it, asks Ollama (an AI that runs on your Mac),
seals the answer and sends it back. Nothing is stored, nothing is logged (unless --debug).

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

VERSION = "1.0.0"
CONF = os.path.expanduser("~/.cheple/privatecloud.json")
PAIR_ITER = 50000          # PBKDF2 rounds for the pairing code (slow on purpose)
PAIR_WINDOW = 10 * 60      # --pair works for 10 minutes
MAX_BODY = 64 * 1024
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
    ollama = "http://localhost:11434"
    debug = False
    pair_code = None
    pair_until = 0
    pair_tries = 0
    seen = {}                 # request ids already answered (no replays)
    lock = threading.Lock()
    calls = []                # times of recent requests (rate limit)


def ollama_ok():
    try:
        with urllib.request.urlopen(State.ollama + "/api/tags", timeout=2) as r:
            return r.status == 200
    except Exception:
        return False


def ask_ollama(messages, max_tokens, temperature):
    body = json.dumps({"model": State.model, "messages": messages, "stream": False,
                       "options": {"num_predict": int(max_tokens), "temperature": float(temperature)}}).encode()
    req = urllib.request.Request(State.ollama + "/api/chat", data=body, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read())["message"]["content"].strip()


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
            return self.reply(200, json.dumps({"cheple": 1, "version": VERSION, "model": State.model,
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
            a = ask_ollama(msgs, min(int(q.get("max_tokens", 220)), 800), q.get("temperature", 0.6))
            if State.debug:
                print(f"[debug] answered in {time.time() - t0:.1f} s")
        except Exception as e:
            print("Ollama didn't answer:", type(e).__name__, "- is it running?  (ollama serve)")
            return self.reply(502, '{"error":"ollama"}')
        out = json.dumps({"id": rid, "t": int(time.time()), "model": State.model, "content": a}).encode()
        self.reply(200, seal(State.key, b"cheple-reply-v1", out), "text/plain")


def main():
    ap = argparse.ArgumentParser(description="Cheple Private Cloud")
    ap.add_argument("--pair", action="store_true", help="show a pairing code (works for 10 minutes)")
    ap.add_argument("--port", type=int, default=8787)
    ap.add_argument("--model", default="llama3.2:3b", help="any model you've pulled with ollama")
    ap.add_argument("--ollama", default="http://localhost:11434")
    ap.add_argument("--new-key", action="store_true", help="forget every paired phone (makes a new key)")
    ap.add_argument("--debug", action="store_true", help="print timings (never the questions)")
    a = ap.parse_args()
    if a.new_key and os.path.exists(CONF):
        os.remove(CONF)
    State.key = load_key()
    State.model, State.ollama, State.debug = a.model, a.ollama.rstrip("/"), a.debug
    print(f"Cheple Private Cloud {VERSION}  (code SHA-256 {SELF_SHA[:16]}...)")
    print(f"  On the phone: Settings > Private AI > At Home:  {lan_ip()}")
    print(f"  AI model: {State.model}" + ("" if ollama_ok() else "   ** Ollama isn't running - start the Ollama app **"))
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
