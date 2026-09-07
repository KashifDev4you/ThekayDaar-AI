import 'package:flutter/material.dart';
import 'package:ali_app/services/gemini_service.dart';

class AiSupportChatScreen extends StatefulWidget {
  const AiSupportChatScreen({super.key});

  @override
  State<AiSupportChatScreen> createState() => _AiSupportChatScreenState();
}

class _AiSupportChatScreenState extends State<AiSupportChatScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _loading = false;

  static const _emerald = Color(0xFF0E3B2E);
  static const _gold = Color(0xFFC9A227);
  static const _bg = Color(0xFFF7F5EF);
  static const _text = Color(0xFF1F2A26);
  static const _muted = Color(0xFF5D6B64);
  static const _border = Color(0xFFE3E0D5);

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _loading = true;
    });
    _scrollToBottom();

    try {
      final answer = await GeminiService.answerSupport(text);
      if (!mounted) return;
      setState(() => _messages.add({'role': 'bot', 'text': answer}));
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.add({'role': 'bot', 'text': 'Sorry, I could not answer that. Error: $e'}));
    } finally {
      if (mounted) setState(() => _loading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _emerald,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: _gold, size: 20),
            SizedBox(width: 8),
            Text('AI Support'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_messages.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.support_agent_rounded, size: 56, color: _gold.withValues(alpha: 0.6)),
                      const SizedBox(height: 16),
                      const Text(
                        'Ask me anything about Thekaydaar.pk',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Projects, connects, bidding, contracts, payments, roles...',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final msg = _messages[i];
                  final isUser = msg['role'] == 'user';
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.78,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isUser ? _emerald : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: isUser
                            ? null
                            : Border.all(color: _border),
                      ),
                      child: Text(
                        msg['text'] ?? '',
                        style: TextStyle(
                          color: isUser ? Colors.white : _text,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: _gold),
              ),
            ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: _border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      textInputAction: TextInputAction.send,
                      decoration: const InputDecoration(
                        hintText: 'Ask a question...',
                        hintStyle: TextStyle(color: _muted),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: _emerald,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      onPressed: _send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
