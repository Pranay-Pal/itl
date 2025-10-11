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
  List<dynamic> _searchResults = [];
  bool _isLoading = true;
  bool _showSearch = false;
  bool _isCreatingDM = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final groups = await _apiService.getChatGroups();
      final unreadCountsData = await _apiService.getUnreadCounts();

      final unreadMap = <int, int>{};
      if (unreadCountsData != null && unreadCountsData['groups'] is List) {
        for (var item in (unreadCountsData['groups'] as List)) {
          if (item is Map && item.containsKey('group_id') && item.containsKey('unread_count')) {
            unreadMap[item['group_id']] = item['unread_count'];
          }
        }
      }

      final updatedGroups = groups.map((group) {
        final groupId = group['id'];
        group['unread_count'] = unreadMap[groupId] ?? 0;
        return group;
      }).toList();

      if (!mounted) return;
      setState(() {
        _chatGroups = updatedGroups;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showCreateGroupDialog() {
    final TextEditingController groupNameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Group'),
          content: TextField(
            controller: groupNameController,
            decoration: const InputDecoration(hintText: "Enter group name"),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                final name = groupNameController.text.trim();
                if (name.isNotEmpty) {
                  final newGroup = await _apiService.createGroup(name);
                  if (newGroup != null) {
                    Navigator.of(context).pop();
                    _fetchData();
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  String _formatTime(dynamic raw) {
    try {
      final t = raw.toString();
      if (t.contains('T')) {
        return t.split('T')[1].split('.').first.substring(0, 5);
      }
      return t;
    } catch (e) {
      return '';
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
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
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
                      Future.delayed(const Duration(milliseconds: 100), () => _searchFocus.requestFocus());
                    } else {
                      _searchController.clear();
                      _searchFocus.unfocus();
                      _searchResults = [];
                    }
                  });
                },
              ),
            ],
          ),
        ),
        flexibleSpace: Container(decoration: BoxDecoration(gradient: kBlueGradient)),
        elevation: 2,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
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
                        suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear()),
                        filled: true,
                        fillColor: kWhite,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onChanged: (q) async {
                        if (q.length > 2) {
                          final results = await _apiService.searchUsers(q);
                          final currentUserId = _apiService.currentUserId;
                          setState(() {
                            _searchResults = results.where((user) => user['id'] != currentUserId).toList();
                          });
                        } else {
                          setState(() => _searchResults = []);
                        }
                      },
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _showSearch ? _buildSearchResults() : _buildChatList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateGroupDialog(),
        backgroundColor: kPrimaryBlue,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      itemCount: _chatGroups.length,
      itemBuilder: (context, index) {
        final group = _chatGroups[index];
        final name = group['name'] ?? 'Group';
        final id = group['id'] ?? 0;
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: ListTile(
            onTap: () {
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (context) => ChatScreen(groupId: id, groupName: name)))
                  .then((_) => _fetchData());
            },
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: kPrimaryBlue,
              backgroundImage: const AssetImage('assets/images/grp.png'),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              group['latest']?['content'] ?? 'No messages yet',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  group['latest']?['created_at'] != null ? _formatTime(group['latest']['created_at']) : '',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                if ((group['unread_count'] ?? 0) > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: kPrimaryBlue, borderRadius: BorderRadius.circular(12)),
                    child: Text('${group['unread_count']}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (_isCreatingDM) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return ListTile(
          title: Text(user['name'] ?? ''),
          subtitle: Text(user['email'] ?? ''),
          onTap: () async {
            setState(() {
              _isCreatingDM = true;
            });
            final newGroup = await _apiService.createDirectMessage(user['id']);
            if (mounted) {
              setState(() {
                _isCreatingDM = false;
              });
              if (newGroup != null) {
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (context) => ChatScreen(groupId: newGroup['id'], groupName: newGroup['name'])))
                    .then((_) => _fetchData());
              }
            }
          },
          onLongPress: () {
            if (_apiService.userType == 'admin') {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Set Chat Admin'),
                  content: Text('Set ${user['name']} as a chat admin?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () async {
                        await _apiService.setChatAdmin(user['id'], true);
                        Navigator.of(context).pop();
                      },
                      child: const Text('Set Admin'),
                    ),
                  ],
                ),
              );
            }
          },
        );
      },
    );
  }
}
