from flask import Flask, send_from_directory, abort, request, jsonify
import os
import hmac
import hashlib
import time

app = Flask(__name__)
BACKUPS_DIR = os.environ.get("CAIXA_BACKUP_DIR", os.path.join(os.path.dirname(__file__), "backups"))
SECRET = os.environ.get("CAIXA_BACKUP_SECRET", None)

# Generate a signed URL token
def generate_token(filename: str, expires_in: int = 60) -> str:
    expiry = int(time.time()) + expires_in
    if not SECRET:
        return f"{expiry}:"
    msg = f"{filename}:{expiry}".encode("utf-8")
    sig = hmac.new(SECRET.encode("utf-8"), msg, hashlib.sha256).hexdigest()
    return f"{expiry}:{sig}"

# Validate token
def validate_token(filename: str, token: str) -> bool:
    try:
        parts = token.split(":")
        if len(parts) != 2:
            return False
        expiry = int(parts[0])
        if time.time() > expiry:
            return False
        if not SECRET:
            return True
        expected = hmac.new(SECRET.encode("utf-8"), f"{filename}:{expiry}".encode("utf-8"), hashlib.sha256).hexdigest()
        return hmac.compare_digest(expected, parts[1])
    except Exception:
        return False

@app.route("/backups/<path:filename>")
def serve_backup(filename):
    token = request.args.get("token")
    if SECRET and not token:
        return abort(401)
    if token and not validate_token(filename, token):
        return abort(403)
    path = os.path.join(BACKUPS_DIR, filename)
    if not os.path.exists(path):
        return abort(404)
    return send_from_directory(BACKUPS_DIR, filename, as_attachment=True)

@app.route("/backups/generate/<path:filename>")
def generate(filename):
    if not SECRET:
        return jsonify({"url": f"/backups/{filename}"})
    token = generate_token(filename)
    return jsonify({"url": f"/backups/{filename}?token={token}"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("BACKUPS_PORT", 5001)))
