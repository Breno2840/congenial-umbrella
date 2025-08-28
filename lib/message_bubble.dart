// message_bubble.dart - ATUALIZADO
import 'package:flutter/material.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.data,
    required this.myKey,
    required this.friendKey, // NOVO: Chave do amigo adicionada
    required this.isMe,
  });

  final Map<String, dynamic> data;
  final String myKey;
  final String friendKey; // NOVO: Chave do amigo adicionada
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final user = data['username']?.toString() ?? 'Anônimo';
    final payload = data['message']?.toString() ?? '';

    String msgDecrypted;
    // ALTERADO: A chave de descriptografia agora depende de quem enviou a mensagem
    final keyForDecryption = isMe ? myKey : friendKey;

    try {
      if (keyForDecryption.isEmpty || payload.isEmpty || !payload.contains(':')) {
         msgDecrypted = '[🔒 Chave não definida]'; // Mensagem mais clara
      } else {
        final parts = payload.split(':');
        if (parts.length != 2) {
          throw Exception('Formato de mensagem inválido');
        }

        final iv = encrypt.IV.fromBase64(parts[0]);
        final encryptedMessage = parts[1];
        // Usa a chave correta para descriptografar
        final key = encrypt.Key.fromBase64(keyForDecryption); 
        final encrypter = encrypt.Encrypter(encrypt.AES(key));

        msgDecrypted = encrypter.decrypt64(encryptedMessage, iv: iv);
      }
    } catch (e) {
      msgDecrypted = '[🔒 Mensagem criptografada]';
    }

    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color = isMe ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary;
    final textColor = isMe ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSecondary;

    final borderRadius = isMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(24),
            bottomLeft: Radius.circular(24),
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(5),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(24),
            bottomLeft: Radius.circular(5),
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
          );

    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
      ),
      child: Text(
        msgDecrypted,
        style: TextStyle(color: textColor, fontSize: 16),
      ),
    );

    if (!isMe) {
      return Padding(
        padding: const EdgeInsets.only(left: 8.0, right: 40.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondary.withAlpha(150),
              child: Text(
                user.length > 1 ? user.substring(0, 2).toUpperCase() : '??',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(child: bubble), 
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 40.0, right: 8.0),
      child: Column(
        crossAxisAlignment: align,
        children: [bubble],
      ),
    );
  }
}
