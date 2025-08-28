// chat_screen.dart - COMPLETAMENTE ATUALIZADO
// Importações de pacotes
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Importações dos nossos arquivos
import '../main.dart';
import '../widgets/message_bubble.dart';

// Listas e funções de ajuda (sem alterações)
final List<String> natureAdjectives = [
  'Florestal','Aquático','Montanhoso','Solar','Lunar','Eólico',
  'Verde','Selvagem','Oceânico','Desértico','Glacial','Vulcânico',
];
final List<String> natureNouns = [
  'Panda','Golfinho','Águia','Lobo','Urso','Tigre',
  'Carvalho','Bambu','Cacto','Orquídea','Girassol','Samambaia',
];
String generateRandomNatureName() {
  final random = Random();
  final adjective = natureAdjectives[random.nextInt(natureAdjectives.length)];
  final noun = natureNouns[random.nextInt(natureNouns.length)];
  final number = random.nextInt(100);
  return '$adjective$noun$number';
}
String generateSecureKey() {
  final key = encrypt.Key.fromSecureRandom(32);
  return key.base64;
}

class ChatScreen extends StatefulWidget {
  final String contactName; // Novo parâmetro
  
  const ChatScreen({super.key, required this.contactName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final _nameController = TextEditingController();
  final _pasteKeyController = TextEditingController(); // Controller para colar a chave

  late final Stream<List<Map<String, dynamic>>> _messagesStream;

  String _userName = 'Carregando...';
  String _myKey = '';
  String _friendKey = ''; // NOVO: Variável para armazenar a chave do amigo

  @override
  void initState() {
    super.initState();
    _loadUserPrefs();
    _messagesStream = supabase
        .from('messages')
        .stream(primaryKey: ['id']).order('created_at', ascending: false);
  }

  @override
  void dispose() {
    _textController.dispose();
    _nameController.dispose();
    _pasteKeyController.dispose(); // Limpa o controller
    super.dispose();
  }

  Future<void> _loadUserPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUsername = prefs.getString('username') ?? generateRandomNatureName();
    final currentKey = prefs.getString('myKey') ?? generateSecureKey();
    final currentFriendKey = prefs.getString('friendKey') ?? ''; // Carrega a chave do amigo

    if (mounted) {
      setState(() {
        _userName = currentUsername;
        _myKey = currentKey;
        _friendKey = currentFriendKey; // Define a chave do amigo no estado
        _nameController.text = _userName;
      });
    }

    await prefs.setString('username', currentUsername);
    await prefs.setString('myKey', currentKey);
  }
  
  // Salva apenas o nome do usuário
  Future<void> _saveUsername() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', _userName);
  }

  // NOVO: Função para salvar a chave do amigo
  Future<void> _saveFriendKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('friendKey', key);
  }

  Future<void> _sendMessage() async {
    // Lógica de envio permanece a mesma
    final text = _textController.text.trim();
    if (text.isEmpty || _myKey.isEmpty) return;
    try {
      final key = encrypt.Key.fromBase64(_myKey);
      final iv = encrypt.IV.fromLength(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final encrypted = encrypter.encrypt(text, iv: iv);
      final payload = '${iv.base64}:${encrypted.base64}';
      
      await supabase.from('messages').insert({ 'username': _userName, 'message': payload });
      _textController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao enviar: $e')));
      }
    }
  }
  
  void _showMyKeyDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2F2F3D),
          title: const Text('Minha Chave'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _myKey,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 10),
              const Text(
                'Compartilhe esta chave com seu amigo para que ele possa ler suas mensagens.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('FECHAR'),
            ),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _myKey));
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chave copiada!')),
                );
              },
              child: const Text('COPIAR'),
            ),
          ],
        );
      },
    );
  }

  void _editUsernameDialog() {
    _nameController.text = _userName;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2F2F3D),
          title: const Text('Editar Nome'),
          content: TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Novo nome'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCELAR'),
            ),
            TextButton(
              onPressed: () {
                final newName = _nameController.text.trim();
                if (newName.isNotEmpty) {
                  setState(() {
                    _userName = newName;
                  });
                  _saveUsername();
                  Navigator.of(context).pop();
                }
              },
              child: const Text('SALVAR'),
            ),
          ],
        );
      },
    );
  }

  // NOVO: Diálogo para colar e salvar a chave do amigo (lógica restaurada)
  void _pasteFriendKeyDialog() {
    _pasteKeyController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2F2F3D),
          title: const Text('Chave do Amigo'),
          content: TextField(
            controller: _pasteKeyController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Cole a chave aqui'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCELAR'),
            ),
            TextButton(
              onPressed: () {
                final friendKey = _pasteKeyController.text.trim();
                if (friendKey.isNotEmpty) {
                  setState(() {
                    _friendKey = friendKey;
                  });
                  _saveFriendKey(friendKey);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chave do amigo salva!')),
                  );
                }
              },
              child: const Text('SALVAR'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2A214A), Color(0xFF1C1B25)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        // === APPBAR SIMPLIFICADA ===
        appBar: AppBar(
          title: Text(widget.contactName), // Mostra o nome do contato
          centerTitle: true,
          backgroundColor: Colors.transparent,
          actions: [
            // Menu de configurações com as opções corretas
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit_name') _editUsernameDialog();
                if (value == 'show_key') _showMyKeyDialog();
                if (value == 'paste_key') _pasteFriendKeyDialog(); // Opção de colar chave
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(value: 'edit_name', child: Text('Editar Nome')),
                const PopupMenuItem<String>(value: 'show_key', child: Text('Ver Minha Chave')),
                const PopupMenuItem<String>(value: 'paste_key', child: Text('Colar Chave do Amigo')),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _messagesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Erro: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 60,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Nenhuma mensagem ainda',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Envie uma mensagem para ${widget.contactName}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  final messages = snapshot.data!;
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      return MessageBubble(
                        data: messages[index],
                        myKey: _myKey,
                        friendKey: _friendKey, // Passa a chave do amigo para o bubble
                        isMe: messages[index]['username'] == _userName,
                      );
                    },
                  );
                },
              ),
            ),
            _buildMessageComposer(),
          ],
        ),
      ),
    );
  }

  // === CAMPO DE MENSAGEM SIMPLIFICADO ===
  Widget _buildMessageComposer() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.mood, color: Colors.white70), // Ícone de Emoji
              onPressed: () {},
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Escreva aqui...', // Texto em português
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                  filled: true,
                  fillColor: const Color(0xFF2F2F3D),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Colors.white70), // Ícone de enviar
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}