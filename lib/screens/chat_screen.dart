import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  late int _servicioId;
  late String _pasajero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    _servicioId = args?['servicioId'] as int? ?? 0;
    _pasajero = args?['pasajero']?.toString() ?? 'Pasajero';
    if (_servicioId > 0) {
      final chat = context.read<ChatProvider>();
      final auth = context.read<AuthProvider>();
      chat.startPolling(_servicioId, auth.userId);
      chat.loadMessages(_servicioId, auth.userId);
    }
  }

  @override
  void dispose() {
    context.read<ChatProvider>().stopPolling();
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: Text('Chat con $_pasajero')),
      body: Column(
        children: [
          Expanded(
            child: chat.messages.isEmpty
                ? const Center(child: Text('Sin mensajes aún'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: chat.messages.length,
                    itemBuilder: (_, i) {
                      final m = chat.messages[i];
                      final isMine = m.emisor == 'Conductor' || m.emisor == 'Sistema';
                      return Align(
                        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMine ? AppTheme.primary : AppTheme.bgLight,
                            borderRadius: BorderRadius.circular(16).copyWith(
                              bottomRight: isMine ? Radius.zero : const Radius.circular(16),
                              bottomLeft: isMine ? const Radius.circular(16) : Radius.zero,
                            ),
                          ),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          child: Column(
                            crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Text(m.mensaje ?? '', style: TextStyle(color: isMine ? Colors.white : AppTheme.textDark)),
                              if (m.fechaEnvio != null) Text(m.fechaEnvio!, style: TextStyle(fontSize: 10, color: isMine ? Colors.white70 : AppTheme.textLight)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -1))]),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    decoration: const InputDecoration(hintText: 'Escribe un mensaje...', border: InputBorder.none, filled: false),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: AppTheme.primary),
                  onPressed: () async {
                    if (_msgCtrl.text.trim().isEmpty) return;
                    await chat.sendMessage(_servicioId, auth.userId, _msgCtrl.text.trim());
                    _msgCtrl.clear();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
