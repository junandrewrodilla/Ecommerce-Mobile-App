import 'package:capstone/components/botton_navbar.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart'; // Import kIsWeb
import 'chat_list.dart';

class ChatPage extends StatefulWidget {
  final String userId;
  final String userType;
  final String recipientId;
  final String recipientName;
  final Function(String newRecipientId) onRecipientChange;

  ChatPage({
    required this.userId,
    required this.userType,
    required this.recipientId,
    required this.recipientName,
    required this.onRecipientChange,
  });

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();
  final _database = FirebaseDatabase.instance.reference();
  DatabaseReference? _chatRef;
  late DatabaseReference _usersRef;

  String? _selectedRecipientId;
  String? _selectedRecipientName;
  String? _chatId;
  List<Map<String, String>> _userList = [];
  List<Map<String, String>> _filteredUserList = [];
  bool _isDropdownOpen = false;
  List<Map<String, dynamic>> _messageList = []; // Local messages for bot

  final String _botId = "handimerce_bot";
  final String _botName = "Handimerce Bot";
  final Map<String, String> _botResponses = {
    "What is Handimerce?":
        "Handimerce is an e-commerce platform designed to connect buyers with local sellers.",
    "What are the advantages of using Handimerce?":
        "Handimerce offers advantages like supporting local businesses, seamless transactions, and personalized services.",
    "How to use Handimerce?":
        "To use Handimerce, create an account, browse products, and connect with sellers for purchases.",
  };

  @override
  void initState() {
    super.initState();
    _usersRef = _database.child('users');

    _selectedRecipientId = widget.recipientId;
    _selectedRecipientName = widget.recipientName;

    _fetchUsers();
    _initializeChat();
    _searchController.addListener(_filterUsers);
    _markMessagesAsRead();
  }

  Future<void> _fetchUsers() async {
    final snapshot = await _usersRef.get();
    final usersMap = snapshot.value as Map<dynamic, dynamic>;

    final List<Map<String, String>> users = [];

    for (var entry in usersMap.entries) {
      final key = entry.key;
      final value = entry.value as Map<dynamic, dynamic>;

      if (key != widget.userId && value.containsKey('userprofiles')) {
        final userProfile = value['userprofiles'] as Map<dynamic, dynamic>;
        final firstName = userProfile['first_name'] ?? '';
        final middleName = userProfile['middle_name'] ?? '';
        final lastName = userProfile['last_name'] ?? '';
        final userType = userProfile['user_type'] ?? 'User';

        if ((widget.userType == 'Buyer' && userType == 'Seller') ||
            (widget.userType == 'Seller' && userType == 'Buyer')) {
          final fullName =
              '$firstName $middleName $lastName ($userType)'.trim();

          users.add({
            'userId': key,
            'username': fullName.isNotEmpty ? fullName : 'Unknown User',
            'userType': userType,
          });
        }
      }
    }

    users.add({
      'userId': _botId,
      'username': _botName,
      'userType': 'Bot',
    });

    setState(() {
      _userList = users;
      _filteredUserList = List.from(users);
    });
  }

  void _filterUsers() {
    setState(() {
      _filteredUserList = _userList
          .where((user) => user['username']!
              .toLowerCase()
              .contains(_searchController.text.toLowerCase()))
          .toList();
    });
  }

  void _initializeChat() {
    if (_selectedRecipientId == null) return;

    if (_selectedRecipientId == _botId) {
      _chatRef = null;
      setState(() {
        _messageList.clear();
      });
    } else {
      final sortedIds = [widget.userId, _selectedRecipientId!]..sort();
      _chatId = "${sortedIds[0]}_${sortedIds[1]}";
      _chatRef = _database.child('chats/$_chatId/messages');
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final messageText = _messageController.text.trim();

    _addLocalMessage(widget.userId, messageText);
    _messageController.clear();

    if (_selectedRecipientId == _botId) {
      String response = _botResponses[messageText] ??
          "I'm here to help with any questions you have about Handimerce!";
      Future.delayed(Duration(seconds: 1), () {
        _addLocalMessage(_botId, response);
      });
    } else {
      final message = {
        'senderId': widget.userId,
        'recipientId': _selectedRecipientId!,
        'message': messageText,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'notification_read': false,
      };
      _chatRef?.push().set(message);
    }
  }

  void _addLocalMessage(String senderId, String message) {
    setState(() {
      _messageList.add({
        'senderId': senderId,
        'message': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  void _markMessagesAsRead() {
    if (_selectedRecipientId == _botId) return;
    _chatRef
        ?.orderByChild('recipientId')
        .equalTo(widget.userId)
        .onValue
        .listen((event) {
      final messages = event.snapshot.value as Map<dynamic, dynamic>?;

      if (messages != null) {
        messages.forEach((key, value) {
          final message = Map<String, dynamic>.from(value);

          if (message['notification_read'] == false &&
              message['recipientId'] == widget.userId) {
            _chatRef?.child(key).update({'notification_read': true});
          }
        });
      }
    });
  }

  void _confirmDeleteMessage(Map<String, dynamic> msg) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Delete Message"),
          content: Text("Are you sure you want to delete this message?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Cancel
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
                _deleteMessage(msg);
              },
              child: Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _deleteMessage(Map<String, dynamic> msg) {
    final messageKey = msg['key'];
    if (messageKey != null && _chatRef != null) {
      _chatRef!.child(messageKey).remove();
    }

    setState(() {
      _messageList.remove(msg);
    });
  }

  int getChatTabIndex() {
    switch (widget.userType) {
      case 'Admin':
        return 2;
      case 'Seller':
        return 4;
      case 'Buyer':
        return 3;
      default:
        return 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          leading: kIsWeb
              ? IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatListPage(
                          userId: widget.userId,
                          userType: widget.userType,
                        ),
                      ),
                    );
                  },
                )
              : null,
          title: Text(
            _selectedRecipientName == null || _selectedRecipientName!.isEmpty
                ? 'Select User'
                : 'Chat',
            style: TextStyle(fontSize: 16),
          ),
          backgroundColor: Colors.red[900],
          centerTitle: true,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatListPage(
                      userId: widget.userId,
                      userType: widget.userType,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isDropdownOpen = !_isDropdownOpen;
                    if (!_isDropdownOpen) {
                      _searchController.clear();
                      _filteredUserList = List.from(_userList);
                    }
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isDropdownOpen
                            ? "Press here to select user"
                            : _selectedRecipientName ?? "Select User to Chat",
                        style: TextStyle(color: Colors.red[700]),
                      ),
                      Icon(
                        _isDropdownOpen
                            ? Icons.arrow_drop_up
                            : Icons.arrow_drop_down,
                        color: Colors.red[700],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isDropdownOpen)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search user...',
                          prefixIcon:
                              Icon(Icons.search, color: Colors.red[700]),
                          filled: true,
                          fillColor: Colors.red[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        style: TextStyle(color: Colors.red[900]),
                      ),
                      SizedBox(height: 8),
                      Container(
                        height: 200,
                        child: _filteredUserList.isNotEmpty
                            ? ListView.builder(
                                itemCount: _filteredUserList.length,
                                itemBuilder: (context, index) {
                                  final user = _filteredUserList[index];
                                  return ListTile(
                                    title: Text(
                                      user['username']!,
                                      style: TextStyle(color: Colors.red[900]),
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedRecipientId = user['userId'];
                                        _selectedRecipientName =
                                            user['username'];
                                        _isDropdownOpen = false;
                                        _initializeChat();
                                      });
                                    },
                                  );
                                },
                              )
                            : Center(
                                child: Text(
                                  'No users found',
                                  style: TextStyle(color: Colors.red[700]),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: _selectedRecipientId == _botId
                  ? ListView(
                      children: [
                        ..._botResponses.keys.map((question) {
                          return ListTile(
                            title: Text(
                              question,
                              style: TextStyle(color: Colors.red[900]),
                            ),
                            onTap: () {
                              setState(() {
                                _messageController.text = question;
                              });
                              _sendMessage();
                            },
                          );
                        }),
                        ..._messageList.map((msg) => Align(
                              alignment: msg['senderId'] == widget.userId
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: EdgeInsets.symmetric(
                                    vertical: 6, horizontal: 12),
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: msg['senderId'] == widget.userId
                                      ? Colors.red[700]
                                      : Colors.red[100],
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      offset: Offset(0, 4),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  msg['message'],
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: msg['senderId'] == widget.userId
                                        ? Colors.white
                                        : Colors.red[900],
                                  ),
                                ),
                              ),
                            )),
                      ],
                    )
                  : _chatRef == null
                      ? Center(child: Text("Select a user to start chatting"))
                      : StreamBuilder(
                          stream: _chatRef!.orderByChild('timestamp').onValue,
                          builder:
                              (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(child: CircularProgressIndicator());
                            } else if (!snapshot.hasData ||
                                snapshot.data!.snapshot.value == null) {
                              return Center(
                                child: Text(
                                  'Start a conversation!',
                                  style: TextStyle(
                                      color: Colors.red[900], fontSize: 18),
                                ),
                              );
                            } else {
                              Map<dynamic, dynamic> messages = snapshot.data!
                                  .snapshot.value as Map<dynamic, dynamic>;
                              List<Map<String, dynamic>> messageList =
                                  messages.entries.map((entry) {
                                final msg =
                                    Map<String, dynamic>.from(entry.value);
                                msg['key'] = entry.key; // Attach Firebase key
                                return msg;
                              }).toList();
                              messageList.sort((a, b) =>
                                  a['timestamp'].compareTo(b['timestamp']));

                              return ListView.builder(
                                itemCount: messageList.length,
                                itemBuilder: (context, index) {
                                  final msg = messageList[index];
                                  final isMe = msg['senderId'] == widget.userId;

                                  return GestureDetector(
                                    onDoubleTap: () => isMe
                                        ? _confirmDeleteMessage(msg)
                                        : null, // Only allow deletion for user's own messages
                                    child: Align(
                                      alignment: isMe
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: Container(
                                        margin: EdgeInsets.symmetric(
                                            vertical: 6, horizontal: 12),
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isMe
                                              ? Colors.red[700]
                                              : Colors.red[100],
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.05),
                                              offset: Offset(0, 4),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          msg['message'],
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: isMe
                                                ? Colors.white
                                                : Colors.red[900],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            }
                          },
                        ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Colors.red[300]),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        style: TextStyle(color: Colors.red[900]),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.red[900],
                    child: IconButton(
                      icon: Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: kIsWeb
            ? null
            : BottomNavBar(
                userId: widget.userId,
                userType: widget.userType,
                selectedIndex: 4,
              ),
      ),
    );
  }
}
