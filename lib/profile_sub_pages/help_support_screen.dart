// lib/screens/help_support_screen.dart

import 'package:flutter/material.dart';
import 'package:ali_app/model/help_support_model.dart';
import 'package:ali_app/utils/app_theme.dart';
import 'package:ali_app/services/firestore_service.dart';
import 'package:ali_app/profile_sub_pages/ai_support_chat_screen.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const List<String> _categories = ['Client', 'Contractor', 'General'];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _categories.length,
      child: Scaffold(
       appBar: AppBar(
  title: const Text('Help & Support'),
  bottom: TabBar(
    labelColor: AppTheme.gold,
    unselectedLabelColor: Colors.white70,
    indicatorColor: AppTheme.gold,
    tabs: _categories.map((c) => Tab(text: c)).toList(),
  ),
),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AiSupportChatScreen()),
          ),
          backgroundColor: AppTheme.emerald,
          icon: const Icon(Icons.auto_awesome_rounded, color: AppTheme.gold),
          label: const Text(
            'AI Support',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
        body: StreamBuilder<List<HelpSupportModel>>(
          stream: FirestoreService.instance.streamHelpSupport(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return const Center(child: Text('No help topics available.'));
            }

            return TabBarView(
              children: _categories.map((category) {
                final filtered = items
                    .where((item) =>
                        (item.category ?? 'General').toLowerCase() ==
                        category.toLowerCase())
                    .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text('No $category topics available.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        title: Text(
                          item.question,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(item.answer),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}