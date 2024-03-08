import 'package:animated_size_and_fade/animated_size_and_fade.dart';
import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatPage extends StatefulWidget {
  ChatPage({Key? key}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  List<String> chatHistory = [];
  final _openAI = OpenAI.instance.build(
    token: 'API-KEY-GPT',
    baseOption: HttpSetup(
      receiveTimeout: const Duration(
        seconds: 5,
      ),
    ),
    enableLog: true,
  );

  final ChatUser _currentUser = ChatUser(id: '1', firstName: 'You');
  final ChatUser _gptChatUser = ChatUser(id: '2', firstName: 'CogniCompanion');

  List<ChatMessage> _messages = <ChatMessage>[];
  List<ChatUser> _typingUsers = <ChatUser>[];

  String appBarTitle = 'CogniCompanion';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color.fromARGB(255, 6, 129, 217),
        title: Text(
          appBarTitle,
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Clear Chat',
            onPressed: () {
              setState(() {
                _messages.clear();
                appBarTitle = 'CogniCompanion';
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: () {
              _showHistory();
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save to History',
            onPressed: () {
              _saveToHistory();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: DashChat(
              currentUser: _currentUser,
              typingUsers: _typingUsers,
              messageOptions: const MessageOptions(
                currentUserContainerColor: Colors.black,
                containerColor: Color.fromRGBO(
                  0,
                  166,
                  126,
                  1,
                ),
                textColor: Colors.white,
              ),
              onSend: (ChatMessage m) {
                getChatResponse(m);
              },
              messages: _messages,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> getChatResponse(ChatMessage m) async {
    setState(() {
      _messages.insert(0, m);
      if (_messages.length == 1) {
        appBarTitle = generateTitle(m.text);
      }
      _typingUsers.add(_gptChatUser);
    });

    if (m.user == _currentUser) {
      List<Messages> _messagesHistory = _messages.reversed.map((m) {
        return Messages(role: Role.user, content: m.text);
      }).toList();

      try {
        final request = ChatCompleteText(
          model: GptTurbo0301ChatModel(),
          messages: _messagesHistory,
          maxToken: 200,
        );
        final response = await _openAI.onChatCompletion(request: request);
        print(response);

        for (var element in response!.choices) {
          if (element.message != null) {
            setState(() {
              _messages.insert(
                0,
                ChatMessage(
                  user: _gptChatUser,
                  createdAt: DateTime.now(),
                  text: element.message!.content,
                ),
              );
            });
          }
        }

        // Remover apenas uma vez após processar toda a resposta
        setState(() {
          _typingUsers.remove(_gptChatUser);
        });
      } catch (e) {
        print('Error processing Chat-Bot response: $e');
      }
    }
  }

  String generateTitle(String keywords) {
    final cleanKeywords = keywords
        .replaceAll("import 'package:", '')
        .replaceAll("';", '')
        .replaceAll('.', ' ')
        .trim();
    return cleanKeywords.isNotEmpty ? cleanKeywords : 'CogniCompanion';
  }

  Future<void> _saveToHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> chatHistory = prefs.getStringList('chatHistory') ?? [];

    String chat = '';
    for (ChatMessage message in _messages.reversed) {
      chat += message.createdAt.toIso8601String() +
          '|' +
          message.user.id +
          '|' +
          message.text +
          '\n';
    }

    chatHistory.add(chat);
    await prefs.setStringList('chatHistory', chatHistory);
  }

  Future<void> _showHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> chatHistory = prefs.getStringList('chatHistory') ?? [];

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return AnimatedSizeAndFade(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(16.0),
                  child: ListView.builder(
                    itemCount: chatHistory.length,
                    itemBuilder: (BuildContext context, int index) {
                      String question = _extractQuestion(chatHistory[index]);
                      return ListTile(
                        title: Text(question),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            IconButton(
                              icon: Icon(Icons.delete),
                              onPressed: () {
                                _deleteFromHistory(index);
                              },
                            ),
                          ],
                        ),
                        onTap: () {
                          _restoreChat(chatHistory[index]);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.all(16.0),
                child: ListTile(
                  title: Center(
                    child: Text(
                      'Delete All',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  onTap: () {
                    _deleteAllChatsFromHistory();
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _extractQuestion(String chat) {
    List<String> lines = chat.split('\n');
    if (lines.isNotEmpty) {
      return lines.first;
    }
    return '';
  }

  void _restoreChat(String chat) {
    setState(() {
      _messages.clear();
      List<String> messageList = chat.split('\n').reversed.toList();
      for (String message in messageList) {
        List<String> parts = message.split('|');
        if (parts.length == 3) {
          DateTime createdAt = DateTime.parse(parts[0]);
          String userId = parts[1];
          String text = parts[2];
          ChatUser user = (userId == '1') ? _currentUser : _gptChatUser;
          _messages.add(ChatMessage(
            user: user,
            createdAt: createdAt,
            text: text,
          ));
        }
      }
    });
  }

  void _deleteAllChatsFromHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('chatHistory');

    setState(() {
      chatHistory = [];
      _messages.clear();
      appBarTitle = 'CogniCompanion';
    });
  }

  void _deleteAllFromHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('chatHistory');

    setState(() {
      chatHistory = [];
    });

    Navigator.of(context).pop();
  }

  void _deleteFromHistory(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> chatHistory = prefs.getStringList('chatHistory') ?? [];

    chatHistory.removeAt(index);
    await prefs.setStringList('chatHistory', chatHistory);

    setState(() {
      chatHistory = prefs.getStringList('chatHistory') ?? [];
    });

    Navigator.of(context).pop();
  }
}
