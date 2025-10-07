import 'package:flutter/material.dart';
import 'package:itl/api_service.dart';
import 'package:itl/chat_screen.dart';
import 'package:itl/constants.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _chatGroups = [];
  bool _isLoading = true;
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _fetchChatGroups();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _fetchChatGroups() async {
    try {
      final groups = await _apiService.getChatGroups();
      setState(() {
        _chatGroups = groups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Chats',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    SizedBox(height: 2),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (_showSearch) {
                      // focus after frame
                      Future.delayed(Duration(milliseconds: 100), () {
                        _searchFocus.requestFocus();
                      });
                    } else {
                      _searchController.clear();
                      _searchFocus.unfocus();
                    }
                  });
                },
              ),
            ],
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: kBlueGradient),
        ),
        elevation: 2,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchChatGroups,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _showSearch
                  ? TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      decoration: InputDecoration(
                        hintText: 'Search chats or people',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        ),
                        filled: true,
                        fillColor: kWhite,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (q) async {
                        // TODO: run search
                      },
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8.0,
                        horizontal: 12.0,
                      ),
                      itemCount: _chatGroups.length,
                      itemBuilder: (context, index) {
                        final group = _chatGroups[index];
                        final name = group['name'] ?? 'Group';
                        final id = group['id'] ?? 0;
                        return Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 4,
                          ),
                          child: ListTile(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ChatScreen(groupId: id, groupName: name),
                                ),
                              );
                            },
                            leading: CircleAvatar(
                              radius: 28,
                              backgroundColor: kPrimaryBlue,
                              backgroundImage: const AssetImage(
                                'assets/images/grp.png',
                              ),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              group['last_message'] ?? 'No messages yet',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  group['updated_at'] != null
                                      ? _formatTime(group['updated_at'])
                                      : '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if ((group['unread_count'] ?? 0) > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: kPrimaryBlue,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${group['unread_count']}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: New chat action
        },
        backgroundColor: kPrimaryBlue,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  String _formatTime(dynamic raw) {
    try {
      final t = raw.toString();
      // Expecting ISO date, return short date/time simple
      if (t.contains('T'))
        return t.split('T')[1].split('.').first.substring(0, 5);
      return t;
    } catch (e) {
      return '';
    }
  }
}

// Legacy per-item widgets removed — modern ListTile/Card UI is used above.
