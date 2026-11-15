import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class ChatMessage {
  final String text;
  final bool fromUser;
  final DateTime time;
  ChatMessage(this.text, {this.fromUser = false}) : time = DateTime.now();
}

class ChatbotResult {
  final String? intent;
  final String? summary;
  final String reply;
  final Map<String, dynamic>? suggestedActions;
  ChatbotResult(
      {this.intent, this.summary, required this.reply, this.suggestedActions});
}

class ChatbotWidget extends StatefulWidget {
  const ChatbotWidget({super.key});
  @override
  State<ChatbotWidget> createState() => _ChatbotWidgetState();
}

class _ChatbotWidgetState extends State<ChatbotWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  final List<ChatMessage> _messages = [];
  final List<String> _userMemory = [];
  static const int _memoryLimit = 12;

  ChatbotResult? _lastResult;
  bool _isTyping = false;
  bool _loadingKnowledge = false;

  String _policeNumber = '100';
  String _ambulanceNumber = '102';
  String _fireNumber = '101';

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
        '👋 Hi — I’m your assistant. Ask about the app, report an incident, or ask a general question.'));
  }

  void _remember(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    _userMemory.add(t);
    if (_userMemory.length > _memoryLimit) _userMemory.removeAt(0);
  }

  ChatbotResult _localKnowledgeAnswer(String text) {
    final t = text.toLowerCase();

    if (t.contains('report') || t.contains('how do i report')) {
      return ChatbotResult(
        intent: 'app_help',
        reply:
            '📝 To report: open Report → confirm location → add a short description → attach photo if safe → submit. Want me to prefill a sample report?',
      );
    }
    if (t.contains('password') || t.contains('change password')) {
      return ChatbotResult(
        intent: 'app_help',
        reply:
            '🔑 Change password: Settings → Account → Change Password. You will need your current password to confirm.',
      );
    }
    if (t.contains('notifications') || t.contains('notify')) {
      return ChatbotResult(
        intent: 'app_help',
        reply:
            '🔔 Notifications are in Settings → Notifications. Toggle alerts for emergencies, updates, and tips.',
      );
    }

    if (t == 'hi' || t == 'hello' || t == 'hey') {
      return ChatbotResult(reply: 'Hello 👋 — how can I help you today?');
    }
    if (t.contains('how are you')) {
      return ChatbotResult(reply: 'I’m ready to help. Tell me what you need.');
    }
    if (t.contains('thank')) {
      return ChatbotResult(reply: 'You’re welcome — glad to help.');
    }

    final fire = RegExp(r'\b(fire|smoke|burn|burning)\b');
    final medical = RegExp(r'\b(injury|injured|bleeding|hurt|unconscious)\b');
    final crime = RegExp(r'\b(robbery|theft|attack|assault|stolen)\b');

    if (fire.hasMatch(t)) {
      return ChatbotResult(
        intent: 'fire',
        summary: 'Possible fire reported',
        reply:
            'It sounds like there may be a fire. If people are in danger, move to safety and call emergency services now.',
        suggestedActions: {
          'call_police': true,
          'call_ambulance': true,
          'call_fire_brigade': true,
          'police_number': _policeNumber,
          'ambulance_number': _ambulanceNumber,
          'fire_number': _fireNumber,
          'safetyTips': [
            'Move to a safe distance upwind',
            'Call emergency services immediately',
            'Do not attempt to fight large fires yourself'
          ]
        },
      );
    }

    if (medical.hasMatch(t)) {
      return ChatbotResult(
        intent: 'medical',
        summary: 'Possible medical emergency',
        reply:
            'This sounds like a medical emergency. Is the person conscious and breathing? If not, call an ambulance immediately.',
        suggestedActions: {
          'call_ambulance': true,
          'ambulance_number': _ambulanceNumber,
          'safetyTips': [
            'Check responsiveness and breathing',
            'Apply pressure to severe bleeding',
            'If trained, begin CPR if not breathing'
          ]
        },
      );
    }

    if (crime.hasMatch(t)) {
      return ChatbotResult(
        intent: 'crime',
        summary: 'Possible crime in progress',
        reply:
            'If you are in danger, find a safe place and call the police. Do you want me to call the police for you?',
        suggestedActions: {
          'call_police': true,
          'police_number': _policeNumber,
          'safetyTips': [
            'Move to a safe location if possible',
            'Avoid confrontation',
            'Provide a description to police when safe'
          ]
        },
      );
    }

    return ChatbotResult(intent: 'unknown', reply: '');
  }

  bool _looksLikeGeneralQuestion(String text) {
    final t = text.trim().toLowerCase();
    if (t.isEmpty) return false;
    final questionWords = [
      'what',
      'who',
      'when',
      'where',
      'why',
      'how',
      'explain',
      'define'
    ];
    if (questionWords.any((w) => t.startsWith(w))) return true;
    if (t.endsWith('?')) return true;
    if (t.startsWith('tell me about') || t.startsWith('explain')) return true;
    return false;
  }

  Future<String?> _fetchKnowledgeDirect(String q) async {
    try {
      final ddgUrl = Uri.parse(
          'https://api.duckduckgo.com/?q=${Uri.encodeComponent(q)}&format=json&no_html=1&skip_disambig=1');
      final ddgResp =
          await http.get(ddgUrl).timeout(const Duration(seconds: 6));
      if (ddgResp.statusCode == 200) {
        final ddgJson = jsonDecode(ddgResp.body) as Map<String, dynamic>;
        final abstract = (ddgJson['AbstractText'] as String?)?.trim() ?? '';
        final answer = (ddgJson['Answer'] as String?)?.trim() ?? '';
        if (abstract.isNotEmpty) return abstract;
        if (answer.isNotEmpty) return answer;
      }
    } on TimeoutException {
    } on SocketException {
      return null;
    } catch (_) {}

    try {
      final searchUrl = Uri.parse(
          'https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=${Uri.encodeComponent(q)}&format=json&srlimit=1');
      final sResp =
          await http.get(searchUrl).timeout(const Duration(seconds: 6));
      if (sResp.statusCode == 200) {
        final sJson = jsonDecode(sResp.body) as Map<String, dynamic>;
        final hits = (sJson['query']?['search']) as List<dynamic>?;
        if (hits != null && hits.isNotEmpty) {
          final title = (hits[0]['title'] as String?) ?? '';
          if (title.isNotEmpty) {
            final summaryUrl = Uri.parse(
                'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(title)}');
            final sumResp =
                await http.get(summaryUrl).timeout(const Duration(seconds: 6));
            if (sumResp.statusCode == 200) {
              final sumJson = jsonDecode(sumResp.body) as Map<String, dynamic>;
              final extract = (sumJson['extract'] as String?)?.trim() ?? '';
              if (extract.isNotEmpty) return extract;
            }
          }
        }
      }
    } on TimeoutException {
      return null;
    } on SocketException {
      return null;
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<void> _sendMessage(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty) return;

    _focusNode.unfocus();
    FocusScope.of(context).unfocus();

    setState(() {
      _messages.insert(0, ChatMessage(text, fromUser: true));
      _isTyping = true;
    });

    _controller.clear();

    await Future.delayed(const Duration(milliseconds: 80));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }

    _remember(text);

    await Future.delayed(const Duration(milliseconds: 120));

    final local = _localKnowledgeAnswer(text);
    if (local.intent != null &&
        local.intent != 'unknown' &&
        local.reply.isNotEmpty) {
      _insertResult(local);
      return;
    }

    if (_looksLikeGeneralQuestion(text)) {
      setState(() => _loadingKnowledge = true);
      final summary = await _fetchKnowledgeDirect(text);
      setState(() => _loadingKnowledge = false);
      if (summary != null && summary.isNotEmpty) {
        final result = ChatbotResult(intent: 'knowledge', reply: summary);
        _insertResult(result);
        return;
      }
    }

    final fallback = _localFallbackReply(text);
    _insertResult(fallback);
  }

  ChatbotResult _localFallbackReply(String text) {
    final t = text.trim();
    if (_userMemory.isNotEmpty) {
      final last = _userMemory.length >= 2
          ? _userMemory[_userMemory.length - 2]
          : _userMemory.last;
      if (last.isNotEmpty && last.length < 80 && t.length < 80) {
        return ChatbotResult(
            reply:
                'Thanks — based on what you said earlier ("$last") and now ("$text"), could you confirm whether anyone needs immediate help?');
      }
    }

    final reply =
        'I hear you: "$text". I can help with app tasks (reports, settings) or general questions. Try asking "What is X?" or "How do I change Y?"';
    return ChatbotResult(intent: 'fallback', reply: reply);
  }

  void _insertResult(ChatbotResult result) {
    if (!mounted) return;
    setState(() {
      _messages.insert(0, ChatMessage(result.reply, fromUser: false));
      _lastResult = result;
      _isTyping = false;
    });

    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _callNumber(String number) async {
    final sanitized = number.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final uri = Uri(scheme: 'tel', path: sanitized);

    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the phone dialer.')),
        );
      }
    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid phone number: $e')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open dialer: $e')),
      );
    }
  }

  Future<void> _showDialerDialog() async {
    final TextEditingController customCtrl = TextEditingController();
    String selected = '';
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Emergency Dialer',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                    IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close))
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Quick call options. Tap a row to call, or enter a custom number below.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red.shade100,
                          child:
                              const Icon(Icons.local_police, color: Colors.red),
                        ),
                        title: const Text('Police'),
                        subtitle: Text(_policeNumber),
                        trailing: ElevatedButton(
                          onPressed: () {
                            selected = _policeNumber;
                            Navigator.of(ctx).pop();
                            _callNumber(selected);
                          },
                          child: const Text('Call'),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.shade100,
                          child: const Icon(Icons.local_hospital,
                              color: Colors.orange),
                        ),
                        title: const Text('Ambulance'),
                        subtitle: Text(_ambulanceNumber),
                        trailing: ElevatedButton(
                          onPressed: () {
                            selected = _ambulanceNumber;
                            Navigator.of(ctx).pop();
                            _callNumber(selected);
                          },
                          child: const Text('Call'),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepOrange.shade100,
                          child: const Icon(Icons.local_fire_department,
                              color: Colors.deepOrange),
                        ),
                        title: const Text('Fire Brigade'),
                        subtitle: Text(_fireNumber),
                        trailing: ElevatedButton(
                          onPressed: () {
                            selected = _fireNumber;
                            Navigator.of(ctx).pop();
                            _callNumber(selected);
                          },
                          child: const Text('Call'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: customCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'Enter custom number (e.g., +911234567890)',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final n = customCtrl.text.trim();
                      if (n.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Enter a number first')),
                        );
                        return;
                      }
                      selected = n;
                      Navigator.of(ctx).pop();
                      _callNumber(selected);
                    },
                    child: const Text('Call'),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () async {
                          await _showEditDefaultsDialog();
                          if (mounted) setState(() {});
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit default emergency numbers'),
                      ),
                    ),
                  ],
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEditDefaultsDialog() async {
    final policeCtrl = TextEditingController(text: _policeNumber);
    final ambCtrl = TextEditingController(text: _ambulanceNumber);
    final fireCtrl = TextEditingController(text: _fireNumber);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit default numbers'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: policeCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Police number'),
                ),
                TextField(
                  controller: ambCtrl,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(labelText: 'Ambulance number'),
                ),
                TextField(
                  controller: fireCtrl,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(labelText: 'Fire brigade number'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () {
                  final p = policeCtrl.text.trim();
                  final a = ambCtrl.text.trim();
                  final f = fireCtrl.text.trim();
                  if (p.isNotEmpty) _policeNumber = p;
                  if (a.isNotEmpty) _ambulanceNumber = a;
                  if (f.isNotEmpty) _fireNumber = f;
                  Navigator.of(ctx).pop();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Default numbers updated')),
                    );
                  }
                },
                child: const Text('Save')),
          ],
        );
      },
    );
  }

  Widget _buildEscalationCard() {
    final actions = _lastResult?.suggestedActions ?? {};
    final List<Widget> rows = [];

    if (actions['call_police'] == true) {
      final num = (actions['police_number'] as String?) ?? _policeNumber;
      rows.add(ListTile(
        leading: CircleAvatar(
            backgroundColor: Colors.red.shade50,
            child: const Icon(Icons.local_police, color: Colors.red)),
        title: const Text('Call Police'),
        subtitle: Text('Number: $num'),
        trailing: ElevatedButton(
            onPressed: () => _callNumber(num), child: const Text('Call')),
      ));
    }

    if (actions['call_ambulance'] == true) {
      final num = (actions['ambulance_number'] as String?) ?? _ambulanceNumber;
      rows.add(ListTile(
        leading: CircleAvatar(
            backgroundColor: Colors.orange.shade50,
            child: const Icon(Icons.local_hospital, color: Colors.orange)),
        title: const Text('Call Ambulance'),
        subtitle: Text('Number: $num'),
        trailing: ElevatedButton(
            onPressed: () => _callNumber(num), child: const Text('Call')),
      ));
    }

    if (actions['call_fire_brigade'] == true) {
      final num = (actions['fire_number'] as String?) ?? _fireNumber;
      rows.add(ListTile(
        leading: CircleAvatar(
            backgroundColor: Colors.deepOrange.shade50,
            child: const Icon(Icons.local_fire_department,
                color: Colors.deepOrange)),
        title: const Text('Call Fire Brigade'),
        subtitle: Text('Number: $num'),
        trailing: ElevatedButton(
            onPressed: () => _callNumber(num), child: const Text('Call')),
      ));
    }

    if (actions['safetyTips'] is List) {
      final tips = (actions['safetyTips'] as List).cast<String>();
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Safety tips',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ...tips.map((t) => Text('• $t')).toList(),
        ]),
      ));
    }

    if (rows.isEmpty) return const SizedBox.shrink();
    return Card(
        color: Colors.red.shade50,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: rows));
  }

  Widget _buildQuickReplies() {
    final suggestions = [
      'Report fire',
      'How to change password',
      'I need help now',
      'What is CPR'
    ];
    return Wrap(
        spacing: 8,
        runSpacing: 6,
        children: suggestions
            .map((s) => ActionChip(
                  label: Text(s),
                  onPressed: () {
                    _controller.text = s;

                    _focusNode.requestFocus();
                    _sendMessage(s);
                  },
                ))
            .toList());
  }

  Widget _buildMessageBubble(ChatMessage m) {
    return Align(
      alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: m.fromUser ? Colors.blueAccent : Colors.white,
          gradient: m.fromUser
              ? const LinearGradient(
                  colors: [Color(0xFF2E86DE), Color(0xFF5DADE2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: const Offset(2, 2),
            )
          ],
          border: m.fromUser ? null : Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              m.text,
              style: TextStyle(
                  color: m.fromUser ? Colors.white : Colors.black87,
                  fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              _formatTimestamp(m.time),
              style: TextStyle(
                color: (m.fromUser ? Colors.white70 : Colors.black45),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final typingWidget = _isTyping
        ? Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: const [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Assistant is typing...'),
              ],
            ),
          )
        : const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        _focusNode.unfocus();
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text('Assistant'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF5B2C6F), Color(0xFF2E86DE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          elevation: 2,
          actions: [
            IconButton(
              tooltip: 'Emergency dialer',
              icon: const Icon(Icons.local_phone),
              onPressed: _showDialerDialog,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _messages.isEmpty
                    ? const Center(child: Text('Say something to start'))
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length + (_isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_isTyping && index == 0) return typingWidget;
                          final msg = _messages[index - (_isTyping ? 1 : 0)];
                          return _buildMessageBubble(msg);
                        },
                      ),
              ),
              if (_lastResult != null) _buildEscalationCard(),
              if (_loadingKnowledge) const LinearProgressIndicator(),
              AnimatedPadding(
                duration: const Duration(milliseconds: 120),
                padding: EdgeInsets.only(bottom: bottomInset),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: const Offset(0, -2),
                      )
                    ],
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildQuickReplies(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (v) {
                                _sendMessage(v);
                              },
                              decoration: InputDecoration(
                                hintText:
                                    'Ask about the app, report, or ask a question',
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: Colors.deepPurple,
                            shape: const CircleBorder(),
                            child: IconButton(
                              icon: const Icon(Icons.send, color: Colors.white),
                              onPressed: () {
                                final text = _controller.text.trim();
                                if (text.isEmpty) return;
                                _sendMessage(text);
                              },
                            ),
                          ),
                        ],
                      ),
                      if (_lastResult != null &&
                          (_lastResult!.summary != null ||
                              _lastResult!.intent != null))
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.playlist_add_check),
                            label:
                                const Text('Use suggestion to prefill report'),
                            onPressed: () {
                              Navigator.of(context).pop(_lastResult);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
