// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import '../widgets/loading_spinner.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import '../models/chat_model.dart';
import '../models/competition_model.dart';
import '../services/firestore_service.dart';
import 'direct_chat_screen.dart';

class OrganizerChatListScreen extends StatefulWidget {
  final CompetitionModel competition;

  const OrganizerChatListScreen({super.key, required this.competition});

  @override
  State<OrganizerChatListScreen> createState() =>
      _OrganizerChatListScreenState();
}

class _OrganizerChatListScreenState extends State<OrganizerChatListScreen> {
  final Set<String> _selectedChatIds = {};
  bool _isSelectionMode = false;

  void _toggleSelection(String chatId) {
    setState(() {
      if (_selectedChatIds.contains(chatId)) {
        _selectedChatIds.remove(chatId);
        if (_selectedChatIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedChatIds.add(chatId);
      }
    });
  }

  Future<void> _deleteSelectedChats() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chats'),
        content: Text(
          'Are you sure you want to delete ${_selectedChatIds.length} selected chat(s)? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );
      try {
        for (final chatId in _selectedChatIds) {
          await firestoreService.deleteDirectChat(
            competitionId: widget.competition.id,
            participantId: chatId,
          );
        }
        setState(() {
          _selectedChatIds.clear();
          _isSelectionMode = false;
        });
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Selected chats deleted')));
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting chats: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          _isSelectionMode ? '${_selectedChatIds.length} selected' : 'Messages',
        ),
        backgroundColor: AppColors.primaryGreen,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedChatIds.clear();
                  });
                },
              )
            : null,
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteSelectedChats,
            ),
        ],
      ),
      body: StreamBuilder<List<ChatModel>>(
        stream: firestoreService.getOrganizerChats(widget.competition.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LoadingSpinner());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: AppColors.error),
              ),
            );
          }

          final chats = snapshot.data ?? [];

          if (chats.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.message_outlined,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No messages yet',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (_, __) =>
                const Divider(color: AppColors.dividerColor, height: 1),
            itemBuilder: (context, index) {
              final chat = chats[index];
              final isUnread = chat.organizerUnreadCount > 0;
              final isSelected = _selectedChatIds.contains(chat.participantId);

              return ListTile(
                tileColor: isSelected
                    ? AppColors.accentGreen.withValues(alpha: 0.2)
                    : (isUnread
                          ? AppColors.accentGreen.withValues(alpha: 0.1)
                          : Colors.transparent),
                leading: Stack(
                  children: [
                    CircleAvatar(
                      backgroundColor: isSelected
                          ? AppColors.accentGreen
                          : AppColors.primaryGreenLight,
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white)
                          : Text(
                              chat.participantName.isNotEmpty
                                  ? chat.participantName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(color: Colors.white),
                            ),
                    ),
                  ],
                ),
                title: Text(
                  chat.participantName,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  chat.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isUnread
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatDate(chat.lastMessageTime),
                      style: TextStyle(
                        color: isUnread
                            ? AppColors.accentGreen
                            : AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (isUnread && !isSelected)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.accentGreen,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          chat.organizerUnreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                onLongPress: () {
                  if (!_isSelectionMode) {
                    setState(() {
                      _isSelectionMode = true;
                      _selectedChatIds.add(chat.participantId);
                    });
                  }
                },
                onTap: () {
                  if (_isSelectionMode) {
                    _toggleSelection(chat.participantId);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DirectChatScreen(
                          competitionId: widget.competition.id,
                          participantId: chat.participantId,
                          participantName: chat.participantName,
                          amIOrganizer: true,
                        ),
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    if (DateTime.now().difference(date).inDays > 0) {
      return DateFormat('MMM d').format(date);
    }
    return DateFormat('h:mm a').format(date);
  }
}
