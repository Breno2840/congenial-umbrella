import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:encrypt/encrypt.dart' as encrypt;
import '../main.dart';
import 'chat_screen.dart';
import 'welcome_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final Stream<List<Map<String, dynamic>>> _messagesStream;
  late final Stream<List<Map<String, dynamic>>> _onlineUsersStream;
  String _userName = 'Carregando...';
  String _myKey = '';
  String _friendKey = '';
  List<Map<String, dynamic>> _uniqueUsers = [];
  List<Map<String, dynamic>> _onlineUsers = [];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _pasteKeyController = TextEditingController();
  int _currentIndex = 0; // 0 para conversas, 1 para online

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserPrefs();
    _messagesStream = supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
    
    _onlineUsersStream = supabase
        .from('user_presence')
        .stream(primaryKey: ['id'])
        .eq('is_online', true);
    
    _loadConversations();
    _setUserOnline();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    _pasteKeyController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setUserOnline();
    } else if (state == AppLifecycleState.paused) {
      _setUserOffline();
    }
  }

  Future<void> _loadUserPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUsername = prefs.getString('username') ?? 'Usuário';
    final currentKey = prefs.getString('myKey') ?? generateSecureKey();
    final currentFriendKey = prefs.getString('friendKey') ?? '';

    if (mounted) {
      setState(() {
        _userName = currentUsername;
        _myKey = currentKey;
        _friendKey = currentFriendKey;
        _nameController.text = _userName;
      });
    }
  }

  String generateSecureKey() {
    final key = encrypt.Key.fromSecureRandom(32);
    return key.base64;
  }

  Future<void> _setUserOnline() async {
    try {
      await supabase.from('user_presence').upsert({
        'username': _userName,
        'is_online': true,
        // CORREÇÃO AQUI
        'last_seen': DateTime.now().toIso8601String(),
      }, onConflict: 'username');
    } catch (e) {
      // Silenciosamente ignora erros de presença
    }
  }

  Future<void> _setUserOffline() async {
    try {
      await supabase.from('user_presence').update({
        'is_online': false,
        // E CORREÇÃO AQUI
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('username', _userName);
    } catch (e) {
      // Silenciosamente ignora erros de presença
    }
  }

  Future<void> _saveUsername() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', _userName);
  }

  Future<void> _saveFriendKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('friendKey', key);
  }

  Future<void> _loadConversations() async {
    try {
      final response = await supabase
          .from('messages')
          .select('*')
          .order('created_at', ascending: false);

      final Map<String, Map<String, dynamic>> lastMessages = {};
      
      for (var message in response) {
        final username = message['username'] as String?;
        if (username != null && username != _userName) {
          if (!lastMessages.containsKey(username)) {
            lastMessages[username] = {
              'name': username,
              'lastMessage': message['message'] as String? ?? 'Sem mensagem',
              'time': _formatTime(message['created_at'] as String? ?? ''),
              'avatar': username.length > 1 ? username.substring(0, 2).toUpperCase() : '??',
            };
          }
        }
      }

      if (mounted) {
        setState(() {
          _uniqueUsers = lastMessages.values.toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar conversas: $e')),
        );
      }
    }
  }

  String _formatTime(String? dateTimeString) {
    try {
      if (dateTimeString == null || dateTimeString.isEmpty) {
        return '';
      }
      
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      
      if (dateTime.day == now.day && 
          dateTime.month == now.month && 
          dateTime.year == now.year) {
        return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } else if (dateTime.day == now.day - 1) {
        return 'Ontem';
      } else {
        return '${dateTime.day}/${dateTime.month}';
      }
    } catch (e) {
      return '';
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
                if (newName.isNotEmpty && newName != _userName) {
                  setState(() {
                    _userName = newName;
                  });
                  _saveUsername();
                  Navigator.of(context).pop();
                  
                  _updateMessagesWithNewName(newName);
                  _setUserOnline();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nome atualizado!')),
                  );
                } else {
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

  Future<void> _updateMessagesWithNewName(String newName) async {
    try {
      await supabase
          .from('messages')
          .update({'username': newName})
          .eq('username', _userName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar mensagens: $e')),
        );
      }
    }
  }

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

  void _logout() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2F2F3D),
          title: const Text('Sair'),
          content: const Text('Tem certeza que deseja sair?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCELAR'),
            ),
            TextButton(
              onPressed: () async {
                _setUserOffline();
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('username');
                await prefs.remove('myKey');
                await prefs.remove('friendKey');
                
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                  );
                }
              },
              child: const Text('SAIR'),
            ),
          ],
        );
      },
    );
  }

  String _truncateMessage(String message) {
    if (message.contains(':')) {
      return '[Mensagem criptografada]';
    }
    return message.length > 30 ? '${message.substring(0, 30)}...' : message;
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
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('ByteChat'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit_name':
                    _editUsernameDialog();
                    break;
                  case 'show_key':
                    _showMyKeyDialog();
                    break;
                  case 'paste_key':
                    _pasteFriendKeyDialog();
                    break;
                  case 'logout':
                    _logout();
                    break;
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(value: 'edit_name', child: Text('Editar Nome')),
                const PopupMenuItem<String>(value: 'show_key', child: Text('Ver Minha Chave')),
                const PopupMenuItem<String>(value: 'paste_key', child: Text('Colar Chave do Amigo')),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(value: 'logout', child: Text('Sair')),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Olá, $_userName',
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white70,
                ),
              ),
            ),
            
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF2F2F3D),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentIndex = 0;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _currentIndex == 0 
                              ? Theme.of(context).colorScheme.primary 
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: Text(
                            'Conversas',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentIndex = 1;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _currentIndex == 1 
                              ? Theme.of(context).colorScheme.primary 
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: Text(
                            'Online',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: _currentIndex == 0 
                  ? _buildConversationsTab()
                  : _buildOnlineTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          _loadConversations();
        }
        
        if (_uniqueUsers.isEmpty) {
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
                  'Nenhuma conversa ainda',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Toque em um usuário online para começar!',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: _uniqueUsers.length,
          itemBuilder: (context, index) {
            final user = _uniqueUsers[index];
            return Card(
              color: const Color(0xFF2F2F3D),
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    user['avatar'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                title: Text(
                  user['name'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  _truncateMessage(user['lastMessage']),
                  style: const TextStyle(color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  user['time'],
                  style: const TextStyle(color: Colors.white54),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        contactName: user['name'],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOnlineTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _onlineUsersStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Erro: ${snapshot.error}', style: const TextStyle(color: Colors.white)),
          );
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final onlineUsers = snapshot.data ?? [];
        final otherOnlineUsers = onlineUsers.where((user) => user['username'] != _userName).toList();

        if (otherOnlineUsers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 60,
                  color: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Ninguém online no momento',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: otherOnlineUsers.length,
          itemBuilder: (context, index) {
            final user = otherOnlineUsers[index];
            final username = user['username'] as String? ?? 'Desconhecido';

            return Card(
              color: const Color(0xFF2F2F3D),
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  child: Text(
                    username.length > 1 ? username.substring(0, 2).toUpperCase() : '??',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                title: Text(
                  username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        contactName: username,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
