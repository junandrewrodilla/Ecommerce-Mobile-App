import 'package:capstone/components/chatbox.dart';
import 'package:capstone/components/botton_navbar.dart';
import 'package:capstone/components/navbar.dart'; // Import the Navbar component
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:flutter/foundation.dart'; // Import kIsWeb

class ChatListPage extends StatefulWidget {
  final String userId;
  final String userType;

  const ChatListPage({super.key, required this.userId, required this.userType});

  @override
  _ChatListPageState createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _chatList = [];
  final Map<String, String> _userNames = {}; // Cache for user names by userId
  bool _isApproved = true; // Track approval status
  late DatabaseReference _chatsRef;
  late StreamSubscription<DatabaseEvent> _chatSubscription;

  @override
  void initState() {
    super.initState();
    _checkApprovalStatus();
    _chatsRef = _database.child('chats');
    _listenToChatUpdates();
  }

  @override
  void dispose() {
    _chatSubscription
        .cancel(); // Clean up the listener when the widget is disposed
    super.dispose();
  }

  Future<void> _checkApprovalStatus() async {
    if (widget.userType == 'Seller') {
      final userSnapshot =
          await _database.child('users/${widget.userId}/userprofiles').get();
      if (userSnapshot.exists) {
        final userProfile = userSnapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _isApproved = userProfile['seller_approval'] ?? false;
        });
      }
    } else {
      _isApproved = true;
    }
  }

  void _listenToChatUpdates() {
    _chatSubscription = _chatsRef.onValue.listen((event) {
      if (event.snapshot.exists) {
        _updateChatList(event.snapshot);
      }
    });
  }

  Future<void> _updateChatList(DataSnapshot chatSnapshot) async {
    final chatData = chatSnapshot.value as Map<dynamic, dynamic>;
    List<Map<String, dynamic>> loadedChats = [];

    for (var chatId in chatData.keys) {
      final chat = chatData[chatId];
      if (chat['messages'] != null) {
        final messages = chat['messages'] as Map<dynamic, dynamic>;

        final relevantMessages = messages.entries
            .where((msg) =>
                msg.value['recipientId'] == widget.userId ||
                msg.value['senderId'] == widget.userId)
            .toList();

        if (relevantMessages.isNotEmpty) {
          relevantMessages.sort((a, b) => (b.value['timestamp'] as int)
              .compareTo(a.value['timestamp'] as int));

          final lastMessage = relevantMessages.first.value;
          final unreadCount = relevantMessages
              .where((msg) =>
                  msg.value['recipientId'] == widget.userId &&
                  msg.value['notification_read'] == false)
              .length;

          final recipientId =
              chatId.replaceAll(widget.userId, '').replaceAll('_', '');
          final recipientName = await _fetchUserName(recipientId);

          loadedChats.add({
            'chatId': chatId,
            'recipientId': recipientId,
            'recipientName': recipientName,
            'lastMessage': lastMessage['message'],
            'timestamp': lastMessage['timestamp'],
            'unreadCount': unreadCount,
          });
        }
      }
    }

    setState(() {
      _chatList = loadedChats;
    });
  }

  Future<String> _fetchUserName(String userId) async {
    if (_userNames.containsKey(userId)) {
      return _userNames[userId]!;
    }

    final userSnapshot =
        await _database.child('users/$userId/userprofiles').get();
    if (userSnapshot.exists) {
      final userProfile = userSnapshot.value as Map<dynamic, dynamic>;
      final fullName =
          '${userProfile['first_name']} ${userProfile['middle_name']} ${userProfile['last_name']}'
              .trim();

      _userNames[userId] = fullName;
      return fullName;
    } else {
      return 'Unknown User';
    }
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat.Hm().format(date);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: kIsWeb
            ? null // Hide AppBar on web
            : AppBar(
                title: const Text("Chats"),
                backgroundColor: Colors.red[900],
                automaticallyImplyLeading: false,
                actions: [
                  if (_isApproved)
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(
                              userId: widget.userId,
                              userType: widget.userType,
                              recipientId: '',
                              recipientName: 'Press Here to Select User',
                              onRecipientChange: (newRecipientId) {},
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
        body: Column(
          children: [
            if (kIsWeb) // Display Navbar only on web
              Navbar(
                userId: widget.userId,
                userType: widget.userType,
              ),
            Expanded(
              child: Stack(
                children: [
                  _chatList.isEmpty
                      ? const Center(child: Text("No chats available"))
                      : ListView.builder(
                          itemCount: _chatList.length,
                          itemBuilder: (context, index) {
                            final chat = _chatList[index];
                            return ListTile(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatPage(
                                      userId: widget.userId,
                                      userType: widget.userType,
                                      recipientId: chat['recipientId'],
                                      recipientName: chat['recipientName'],
                                      onRecipientChange: (newRecipientId) {},
                                    ),
                                  ),
                                );
                              },
                              title: Text(
                                chat['recipientName'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                chat['lastMessage'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              trailing: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _formatTimestamp(chat['timestamp']),
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12),
                                  ),
                                  if (chat['unreadCount'] > 0)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '${chat['unreadCount']}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                  if (widget.userType == 'Seller' && !_isApproved)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.7),
                        child: const Center(
                          child: Text(
                            'YOU\'RE NOT APPROVED YET',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: kIsWeb
            ? null // Hide BottomNavBar on web
            : BottomNavBar(
                userId: widget.userId,
                userType: widget.userType,
                selectedIndex: 4,
              ),
      ),
    );
  }
}
