import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';

void main() {
  runApp(DarkChatApp());
}

const String SERVER_URL = "https://darkchat-server-production.up.railway.app";

class DarkChatApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DarkChat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Color(0xFF0A0A0A),
        primaryColor: Color(0xFF7B2FBE),
        colorScheme: ColorScheme.dark(
          primary: Color(0xFF7B2FBE),
          secondary: Color(0xFF9D4EDD),
        ),
      ),
      home: SplashScreen(),
    );
  }
}

// ═══════════════════════════════
//         Splash Screen
// ═══════════════════════════════
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    Future.delayed(Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0xFF9D4EDD), Color(0xFF3C096C)],
                  ),
                ),
                child: Icon(Icons.dark_mode, size: 55, color: Colors.white),
              ),
              SizedBox(height: 20),
              Text(
                "DarkChat",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 3,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "E2E Encrypted",
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9D4EDD),
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════
//         Login Screen
// ═══════════════════════════════
class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isRegister = false;
  final _usernameController = TextEditingController();

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    final endpoint = _isRegister ? "/register" : "/login";
    final body = _isRegister
        ? {
            "email": _emailController.text.trim(),
            "username": _usernameController.text.trim(),
            "password": _passwordController.text,
          }
        : {
            "email": _emailController.text.trim(),
            "password": _passwordController.text,
          };

    try {
      final res = await http.post(
        Uri.parse("$SERVER_URL$endpoint"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
     Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (_) => ChatListScreen(
      userId: data["user_id"],
      username: data["username"],
      userCode: data["user_code"] ?? "",
    ),
  ),
);
      } else {
        _showError(data["error"] ?? "خطأ");
      }
    } catch (e) {
      _showError("تعذر الاتصال بالسيرفر");
    }
    setState(() => _isLoading = false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(28),
          child: Column(
            children: [
              Icon(Icons.dark_mode, size: 60, color: Color(0xFF9D4EDD)),
              SizedBox(height: 12),
              Text("DarkChat",
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              SizedBox(height: 4),
              Text(_isRegister ? "إنشاء حساب" : "تسجيل الدخول",
                  style: TextStyle(color: Color(0xFF9D4EDD), fontSize: 14)),
              SizedBox(height: 32),
              if (_isRegister)
                _buildField(_usernameController, "اسم المستخدم", Icons.person),
              SizedBox(height: 12),
              _buildField(_emailController, "الإيميل", Icons.email),
              SizedBox(height: 12),
              _buildField(_passwordController, "كلمة المرور", Icons.lock,
                  obscure: true),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF7B2FBE),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isRegister ? "إنشاء حساب" : "دخول",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                ),
              ),
              SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => _isRegister = !_isRegister),
                child: Text(
                  _isRegister
                      ? "لدي حساب - تسجيل الدخول"
                      : "ليس لدي حساب  - إنشاء حساب",
                  style: TextStyle(color: Color(0xFF9D4EDD)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
      TextEditingController controller, String hint, IconData icon,
      {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Color(0xFF9D4EDD)),
        filled: true,
        fillColor: Color(0xFF1A1A2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// ═══════════════════════════════
//         Chat List Screen
// ═══════════════════════════════
class ChatListScreen extends StatefulWidget {
  final String userId;
  final String username;
  final String userCode;
  const ChatListScreen({required this.userId, required this.username, required this.userCode});

  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final List<Map<String, dynamic>> _chats = [];
  final _searchController = TextEditingController();

  void _addFriend() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Color(0xFF1A1A2E),
        title: Text("إضافة صديق", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("أدخل معرف الشخص", style: TextStyle(color: Colors.grey)),
            SizedBox(height: 12),
            TextField(
              controller: _searchController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "مثال: DC-A3X9K2",
                hintStyle: TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Color(0xFF0A0A0A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("إلغاء", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = _searchController.text.trim();
              if (code.isEmpty) return;
              Navigator.pop(context);
              await _startChat(code);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF7B2FBE)),
            child: Text("إضافة", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _startChat(String friendCode) async {
    try {
      final res = await http.get(Uri.parse("$SERVER_URL/find_user/$friendCode"),
          headers: {"ngrok-skip-browser-warning": "true"});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final exists = _chats.any((c) => c['userId'] == data['user_id']);
        if (!exists) {
          setState(() {
            _chats.add({
              'userId': data['user_id'],
              'username': data['username'],
              'userCode': data['user_code'],
              'lastMsg': '',
              'time': '',
            });
          });
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              myId: widget.userId,
              myUsername: widget.username,
              friendId: data['user_id'],
              friendUsername: data['username'],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("المستخدم غير موجود"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطأ في الاتصال"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Color(0xFF0F0F1A),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("DarkChat", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text("معرفك: ${widget.userCode}",
                style: TextStyle(color: Color(0xFF9D4EDD), fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add, color: Color(0xFF9D4EDD)),
            onPressed: _addFriend,
          ),
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: CircleAvatar(
              backgroundColor: Color(0xFF7B2FBE),
              child: Text(
                widget.username[0].toUpperCase(),
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: _chats.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, color: Color(0xFF9D4EDD), size: 64),
                  SizedBox(height: 16),
                  Text("لا توجد محادثات بعد",
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  SizedBox(height: 8),
                  Text("اضغط + لإضافة صديق",
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _chats.length,
              itemBuilder: (_, i) {
                final chat = _chats[i];
                return ListTile(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        myId: widget.userId,
                        myUsername: widget.username,
                        friendId: chat['userId'],
                        friendUsername: chat['username'],
                      ),
                    ),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Color(0xFF7B2FBE),
                    child: Text(
                      chat['username'][0].toUpperCase(),
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(chat['username'],
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    chat['lastMsg'].isEmpty ? "ابدأ المحادثة..." : chat['lastMsg'],
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(chat['time'],
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFriend,
        backgroundColor: Color(0xFF7B2FBE),
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// ═══════════════════════════════
//         Chat Screen
// ═══════════════════════════════
class ChatScreen extends StatefulWidget {
  final String myId;
  final String myUsername;
  final String friendId;
  final String friendUsername;
  const ChatScreen({required this.myId, required this.myUsername, required this.friendId, required this.friendUsername});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isConnected = false;
  late IO.Socket socket;

  String get _roomId {
    final ids = [widget.myId, widget.friendId]..sort();
    return ids.join('_');
  }

  String _encrypt(String text) {
    const key = "DARKCHAT_SECRET_KEY_2024";
    List<int> encrypted = [];
    for (int i = 0; i < text.length; i++) {
      encrypted.add(text.codeUnitAt(i) ^ key.codeUnitAt(i % key.length));
    }
    return base64Encode(encrypted);
  }

  String _decrypt(String encrypted) {
    const key = "DARKCHAT_SECRET_KEY_2024";
    try {
      List<int> bytes = base64Decode(encrypted);
      String decrypted = '';
      for (int i = 0; i < bytes.length; i++) {
        decrypted += String.fromCharCode(bytes[i] ^ key.codeUnitAt(i % key.length));
      }
      return decrypted;
    } catch (_) {
      return encrypted;
    }
  }

  @override
  void initState() {
    super.initState();
    _connectSocket();
    _loadMessages();
  }

  void _connectSocket() {
    socket = IO.io(SERVER_URL, {
      'transports': ['polling'],
      'autoConnect': true,
    });

    socket.onConnect((_) {
      setState(() => _isConnected = true);
      socket.emit('user_join', {
        'user_id': widget.myId,
        'username': widget.myUsername,
        'room_id': _roomId,
      });
    });

    socket.onDisconnect((_) => setState(() => _isConnected = false));

    socket.on('new_message', (data) {
      if (data['room_id'] == _roomId) {
        setState(() {
          _messages.add({
            'sender': data['sender_id'],
            'text': _decrypt(data['encrypted_content']),
            'time': data['timestamp'],
            'mine': data['sender_id'] == widget.myId,
          });
        });
        _scrollToBottom();
      }
    });

    Future.doWhile(() async {
      await Future.delayed(Duration(seconds: 2));
      if (mounted) await _loadMessages();
      return mounted;
    });
  }

  Future<void> _loadMessages() async {
    try {
      final res = await http.get(
        Uri.parse("$SERVER_URL/messages/$_roomId"),
        headers: {"ngrok-skip-browser-warning": "true"},
      );
      if (res.statusCode == 200) {
        final List msgs = jsonDecode(res.body);
        setState(() {
          _messages.clear();
          for (var m in msgs) {
            _messages.add({
              'sender': m['sender_id'],
              'text': _decrypt(m['encrypted_content']),
              'time': m['timestamp'],
              'mine': m['sender_id'] == widget.myId,
            });
          }
        });
        _scrollToBottom();
      }
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();
    final encrypted = _encrypt(text);

    setState(() {
      _messages.add({
        'sender': widget.myId,
        'text': text,
        'time': DateTime.now().toIso8601String(),
        'mine': true,
      });
    });
    _scrollToBottom();

    try {
      await http.post(
        Uri.parse("$SERVER_URL/send"),
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "true",
        },
        body: jsonEncode({
          "sender_id": widget.myId,
          "encrypted_content": encrypted,
          "room_id": _roomId,
        }),
      );
    } catch (_) {}
  }

  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Color(0xFF0F0F1A),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Color(0xFF7B2FBE),
              radius: 18,
              child: Text(widget.friendUsername[0].toUpperCase(),
                  style: TextStyle(color: Colors.white)),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.friendUsername,
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isConnected ? Colors.greenAccent : Colors.grey,
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(_isConnected ? "متصل" : "غير متصل",
                        style: TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock, color: Color(0xFF9D4EDD), size: 40),
                        SizedBox(height: 8),
                        Text("المحادثة مشفرة E2E",
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _buildMessage(_messages[i]),
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    final isMine = msg['mine'] as bool;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFF3C096C),
              child: Text(widget.friendUsername[0].toUpperCase(),
                  style: TextStyle(color: Colors.white, fontSize: 11)),
            ),
            SizedBox(width: 6),
          ],
          Column(
            crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isMine
                      ? LinearGradient(colors: [Color(0xFF7B2FBE), Color(0xFF9D4EDD)])
                      : null,
                  color: isMine ? null : Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: isMine ? Radius.circular(18) : Radius.circular(4),
                    bottomRight: isMine ? Radius.circular(4) : Radius.circular(18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isMine ? Color(0xFF7B2FBE).withOpacity(0.3) : Colors.black26,
                      blurRadius: 8, offset: Offset(0, 2),
                    )
                  ],
                ),
                child: Text(msg['text'], style: TextStyle(color: Colors.white, fontSize: 15)),
              ),
              SizedBox(height: 2),
              Text(_formatTime(msg['time']), style: TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: Color(0xFF0F0F1A),
        boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Color(0xFF3C096C), width: 1),
              ),
              child: TextField(
                controller: _msgController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "اكتب رسالة...",
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF7B2FBE), Color(0xFF9D4EDD)],
                ),
                boxShadow: [
                  BoxShadow(color: Color(0xFF7B2FBE).withOpacity(0.5), blurRadius: 12, offset: Offset(0, 4))
                ],
              ),
              child: Icon(Icons.send_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    socket.disconnect();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}