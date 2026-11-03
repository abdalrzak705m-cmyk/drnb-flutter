import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const SecretChatApp());
}

class SecretChatApp extends StatelessWidget {
  const SecretChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secret Chat',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late IO.Socket socket;
  String? myUserId;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _recipientController = TextEditingController();
  final List<String> _messages = [];

  @override
  void initState() {
    super.initState();
    _initializeUserAndSocket();
  }

  // 1. توليد أو استرجاع معرف UUID الخاص بالمستخدم محلياً
  Future<void> _initializeUserAndSocket() async {
    final prefs = await SharedPreferences.getInstance();
    String? storedUuid = prefs.getString('user_uuid');

    if (storedUuid == null) {
      storedUuid = const Uuid().v4();
      await prefs.setString('user_uuid', storedUuid);
    }

    setState(() {
      myUserId = storedUuid;
    });

    _connectToServer();
  }

  // 2. الاتصال بسيرفرك المباشر على Render
  void _connectToServer() {
    socket = IO.io(
      'https://drnb-1.onrender.com', // رابط سيرفرك المباشر
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket.connect();

    socket.onConnect((_) {
      print('تم الاتصال بالسيرفر بنجاح');
      // تسجيل المستخدم بغرفته الخاصة باستخدام الـ UUID
      socket.emit('register_user', myUserId);
    });

    // استقبال الرسائل العادية
    socket.on('receive_standard_message', (data) {
      setState(() {
        _messages.add('رسالة عادية من [${data['senderId'].toString().substring(0, 6)}]: ${data['message']}');
      });
    });

    // استقبال الرسائل السرية
    socket.on('receive_secret_message', (data) {
      setState(() {
        _messages.add('🔒 رسالة سرية من [${data['senderId'].toString().substring(0, 6)}]: ${data['message']}');
      });
    });

    socket.onDisconnect((_) => print('انقطع الاتصال بالسيرفر'));
  }

  // إرسال رسالة عادية
  void _sendStandardMessage() {
    if (_recipientController.text.isEmpty || _messageController.text.isEmpty) return;
    
    final data = {
      'senderId': myUserId,
      'receiverId': _recipientController.text.trim(),
      'message': _messageController.text.trim(),
    };

    socket.emit('send_standard_message', data);
    setState(() {
      _messages.add('أنت (عادي): ${_messageController.text}');
    });
    _messageController.clear();
  }

  // إرسال رسالة سرية
  void _sendSecretMessage() {
    if (_recipientController.text.isEmpty || _messageController.text.isEmpty) return;

    final data = {
      'senderId': myUserId,
      'receiverId': _recipientController.text.trim(),
      'message': _messageController.text.trim(),
    };

    socket.emit('send_secret_message', data);
    setState(() {
      _messages.add('🔒 أنت (سري): ${_messageController.text}');
    });
    _messageController.clear();
  }

  @override
  void dispose() {
    socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('معرفك: ${myUserId?.substring(0, 8) ?? 'جاري التحميل...'}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _recipientController,
              decoration: const InputDecoration(
                labelText: 'معرف المستلم (UUID الخاص به)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_messages[index]),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'اكتب رسالتك...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _sendStandardMessage,
                  child: const Text('إرسال عادٍ'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                  onPressed: _sendSecretMessage,
                  child: const Text('إرسال سري 🔒'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
