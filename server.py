from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_socketio import SocketIO, emit, join_room, leave_room
from datetime import datetime
import uuid
import sqlite3
import bcrypt
import random
import string
import os

app = Flask(__name__)
app.config['SECRET_KEY'] = os.urandom(24).hex()
CORS(app, origins="*")
socketio = SocketIO(app, cors_allowed_origins="*")

connected_users = {}

def generate_user_code():
    chars = string.ascii_uppercase + string.digits
    return "DC-" + ''.join(random.choices(chars, k=7))

def init_db():
    conn = sqlite3.connect('darkchat.db')
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        user_code TEXT UNIQUE NOT NULL,
        created_at TEXT NOT NULL
    )''')
    c.execute('''CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        sender_id TEXT NOT NULL,
        receiver_id TEXT,
        room_id TEXT,
        encrypted_content TEXT NOT NULL,
        timestamp TEXT NOT NULL
    )''')
    conn.commit()
    conn.close()

def get_db():
    conn = sqlite3.connect('darkchat.db')
    conn.row_factory = sqlite3.Row
    return conn

@app.route("/")
def home():
    return jsonify({
        "server": "DarkChat Server",
        "status": "running",
        "connected_users": len(connected_users)
    })

@app.route("/register", methods=["POST", "OPTIONS"])
def register():
    if request.method == "OPTIONS":
        return jsonify({}), 200
    data = request.get_json()
    email = data.get("email", "").strip().lower()
    username = data.get("username", "").strip()
    password = data.get("password", "")

    if not email or not username or not password:
        return jsonify({"error": "جميع الحقول مطلوبة"}), 400
    if len(password) < 8:
        return jsonify({"error": "كلمة المرور يجب أن تكون 8 أحرف على الأقل"}), 400

    password_hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
    user_id = str(uuid.uuid4())
    user_code = generate_user_code()
    created_at = datetime.utcnow().isoformat()

    try:
        conn = get_db()
        conn.execute(
            "INSERT INTO users (id, email, username, password_hash, user_code, created_at) VALUES (?, ?, ?, ?, ?, ?)",
            (user_id, email, username, password_hash, user_code, created_at)
        )
        conn.commit()
        conn.close()
        return jsonify({
            "status": "success",
            "user_id": user_id,
            "username": username,
            "user_code": user_code
        })
    except sqlite3.IntegrityError:
        return jsonify({"error": "الإيميل أو اسم المستخدم مستخدم مسبقاً"}), 409

@app.route("/login", methods=["POST", "OPTIONS"])
def login():
    if request.method == "OPTIONS":
        return jsonify({}), 200
    data = request.get_json()
    email = data.get("email", "").strip().lower()
    password = data.get("password", "")

    conn = get_db()
    user = conn.execute("SELECT * FROM users WHERE email = ?", (email,)).fetchone()
    conn.close()

    if not user or not bcrypt.checkpw(password.encode(), user["password_hash"].encode()):
        return jsonify({"error": "إيميل أو كلمة مرور خاطئة"}), 401

    return jsonify({
        "status": "success",
        "user_id": user["id"],
        "username": user["username"],
        "user_code": user["user_code"]
    })

@app.route("/find_user/<user_code>", methods=["GET"])
def find_user(user_code):
    conn = get_db()
    user = conn.execute("SELECT * FROM users WHERE user_code = ?", (user_code,)).fetchone()
    conn.close()

    if not user:
        return jsonify({"error": "المستخدم غير موجود"}), 404

    return jsonify({
        "user_id": user["id"],
        "username": user["username"],
        "user_code": user["user_code"]
    })

@app.route("/send", methods=["POST", "OPTIONS"])
def send_message():
    if request.method == "OPTIONS":
        return jsonify({}), 200
    data = request.get_json()
    sender_id = data.get("sender_id")
    encrypted_content = data.get("encrypted_content")
    receiver_id = data.get("receiver_id")
    room_id = data.get("room_id")

    if not sender_id or not encrypted_content:
        return jsonify({"error": "بيانات ناقصة"}), 400

    msg_id = str(uuid.uuid4())
    timestamp = datetime.utcnow().isoformat()

    conn = get_db()
    conn.execute(
        "INSERT INTO messages (id, sender_id, receiver_id, room_id, encrypted_content, timestamp) VALUES (?, ?, ?, ?, ?, ?)",
        (msg_id, sender_id, receiver_id, room_id, encrypted_content, timestamp)
    )
    conn.commit()
    conn.close()

    socketio.emit('new_message', {
        "id": msg_id,
        "sender_id": sender_id,
        "encrypted_content": encrypted_content,
        "room_id": room_id,
        "timestamp": timestamp
    }, room=room_id)

    return jsonify({"status": "sent", "id": msg_id, "timestamp": timestamp})

@app.route("/messages/<room_id>", methods=["GET"])
def get_messages(room_id):
    conn = get_db()
    msgs = conn.execute(
        "SELECT * FROM messages WHERE room_id = ? ORDER BY timestamp ASC LIMIT 50",
        (room_id,)
    ).fetchall()
    conn.close()

    return jsonify([{
        "id": m["id"],
        "sender_id": m["sender_id"],
        "encrypted_content": m["encrypted_content"],
        "timestamp": m["timestamp"]
    } for m in msgs])

@app.route("/stats")
def stats():
    return jsonify({
        "connected_now": len(connected_users),
        "users": [{"username": u["username"]} for u in connected_users.values()]
    })

@socketio.on('connect')
def on_connect():
    print(f"[+] اتصال جديد | {request.sid}")

@socketio.on('user_join')
def on_user_join(data):
    user_id = data.get("user_id")
    username = data.get("username")
    room_id = data.get("room_id")

    connected_users[request.sid] = {
        "user_id": user_id,
        "username": username,
    }

    join_room(user_id)
    if room_id:
        join_room(room_id)

    emit('server_stats', {"connected_count": len(connected_users)}, broadcast=True)
    print(f"[✓] {username} انضم | المتصلون: {len(connected_users)}")

@socketio.on('disconnect')
def on_disconnect():
    user = connected_users.pop(request.sid, None)
    if user:
        emit('server_stats', {"connected_count": len(connected_users)}, broadcast=True)
        print(f"[-] {user['username']} غادر | المتصلون: {len(connected_users)}")

if __name__ == "__main__":
    init_db()
    print("=" * 45)
    print("   🌑 DarkChat Server - E2E Encrypted")
    print("=" * 45)
    socketio.run(app, host="0.0.0.0", port=5000, debug=True)