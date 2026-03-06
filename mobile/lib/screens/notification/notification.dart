import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/notification.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<InAppNotification> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = NotificationService.loadInbox();
    if (!mounted) return;
    setState(() {
      _items = items;
    });
  }

  Future<void> _openNotification(InAppNotification item) async {
    await NotificationService.openInboxNotification(item);
    if (!mounted) return;
    setState(() {
      _items = _items
          .map((n) => n.id == item.id
              ? InAppNotification(
                  id: n.id,
                  title: n.title,
                  body: n.body,
                  kind: n.kind,
                  saleId: n.saleId,
                  createdAtMillis: n.createdAtMillis,
                  isRead: true,
                )
              : n)
          .toList();
    });
  }

  String _timeText(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _items.isEmpty
            ? ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: const [
                  SizedBox(height: 120),
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 72,
                    color: Color(0xFF94A3B8),
                  ),
                  SizedBox(height: 12),
                  Center(
                    child: Text(
                      'No notifications yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Center(
                    child: Text(
                      'New updates will appear here.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final n = _items[index];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _openNotification(n),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: n.isRead ? Colors.white : const Color(0xFFF8FBFF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFD9E1EE)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE5EEF9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.notifications,
                                size: 20,
                                color: Color(0xFF1E7DE8),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          n.title,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                      if (!n.isRead)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF1E7DE8),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    n.body,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF475569),
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _timeText(n.createdAtMillis),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
