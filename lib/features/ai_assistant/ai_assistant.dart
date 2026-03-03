import 'package:flutter/material.dart';
import 'dart:math';
class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final List<ChatMessage> _messages = [
    ChatMessage(
      text: 'Hello! I\'m your AI Drawing Assistant. How can I help you today?',
      isUser: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
    ),
  ];

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  final List<QuickQuestion> _quickQuestions = [
    QuickQuestion('How to use air drawing?', 'Air drawing uses your camera to track finger movements. Enable it in Mode Selection, then move your finger in front of the camera.'),
    QuickQuestion('What can AI correct?', 'AI can correct basic shapes like circles, squares, triangles, and straight lines. It also suggests improvements.'),
    QuickQuestion('How to save my drawing?', 'Tap the save icon in the top right corner. You can save as PNG or share directly.'),
    QuickQuestion('Best practices for drawing?', '1. Start with basic shapes\n2. Use light strokes first\n3. Let AI correct shapes\n4. Add details last'),
  ];

  @override
  void initState() {
    super.initState();
    // Add welcome message
    _messages.insert(0, ChatMessage(
      text: 'Welcome to AI Sketch Assistant! I\'m here to help with all your drawing questions.',
      isUser: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
    ));
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // Add user message
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isTyping = true;
    });

    _textController.clear();
    _scrollToBottom();

    // Simulate AI thinking
    Future.delayed(const Duration(seconds: 1), () {
      _generateAIReply(text);
    });
  }

  void _generateAIReply(String userMessage) {
    String reply = '';
    final lowerMessage = userMessage.toLowerCase();

    // Pre-programmed responses based on keywords
    if (lowerMessage.contains('air') && lowerMessage.contains('draw')) {
      reply = 'Air drawing works by using your phone\'s camera to track finger movements. Make sure you have good lighting and hold your hand steady. You can find it in the Mode Selection screen.';
    } else if (lowerMessage.contains('ai') || lowerMessage.contains('correct')) {
      reply = 'Our AI analyzes your drawings in real-time and suggests corrections for shapes like circles, squares, and triangles. It helps make your sketches look more polished.';
    } else if (lowerMessage.contains('save') || lowerMessage.contains('export')) {
      reply = 'You can save drawings from the canvas screen using the save icon. Options include PNG format, sharing, or saving to your gallery.';
    } else if (lowerMessage.contains('brush') || lowerMessage.contains('color')) {
      reply = 'We offer 8 different brush types and 12 colors. You can adjust brush size and opacity in the tools panel on the canvas.';
    } else if (lowerMessage.contains('help') || lowerMessage.contains('how')) {
      reply = 'I can help with:\n• Using air drawing\n• AI correction features\n• Saving and sharing\n• Drawing tips\n• App navigation\n\nTry asking about specific features!';
    } else {
      // Generic helpful responses
      final genericResponses = [
        'That\'s a great question! For drawing assistance, try our AI correction feature that automatically improves shapes.',
        'I recommend checking the tutorial in the guide section. It shows how to use all features effectively.',
        'As your AI drawing assistant, I can help you with techniques, tool usage, and getting the most from our app features.',
        'For hands-on help, try the canvas drawing mode first. The AI will guide you with real-time suggestions.',
        'Our app is designed to make drawing easy for everyone. Would you like specific help with air drawing or canvas tools?'
      ];
      reply = genericResponses[DateTime.now().millisecond % genericResponses.length];
    }

    setState(() {
      _messages.add(ChatMessage(
        text: reply,
        isUser: false,
        timestamp: DateTime.now(),
      ));
      _isTyping = false;
    });
    _scrollToBottom();
  }

  void _askQuickQuestion(QuickQuestion question) {
    _textController.text = question.question;
    _sendMessage();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.amber),
            SizedBox(width: 10),
            Text('AI Drawing Assistant'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('About AI Assistant'),
                  content: const Text(
                    'This is a demonstration AI assistant that provides helpful responses about the drawing app. '
                        'It simulates real AI interactions with pre-programmed knowledge about app features.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick Questions Bar
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).primaryColor.withOpacity(0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Questions:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _quickQuestions.length,
                    itemBuilder: (context, index) {
                      final question = _quickQuestions[index];
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: ElevatedButton(
                          onPressed: () => _askQuickQuestion(question),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Theme.of(context).primaryColor,
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: Text(
                            question.question,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Chat Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < _messages.length) {
                  final message = _messages[index];
                  return _ChatBubble(message: message);
                } else {
                  return _TypingIndicator();
                }
              },
            ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            decoration: const InputDecoration(
                              hintText: 'Ask about drawing tips, features...',
                              border: InputBorder.none,
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.mic),
                          onPressed: () {
                            // Would integrate voice input here
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Voice input simulation'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class QuickQuestion {
  final String question;
  final String answer;

  QuickQuestion(this.question, this.answer);
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 20,
                color: Colors.amber,
              ),
            )
          else
            const SizedBox(width: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: message.isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: message.isUser
                        ? Theme.of(context).primaryColor.withOpacity(0.9)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: message.isUser
                          ? const Radius.circular(18)
                          : const Radius.circular(4),
                      bottomRight: message.isUser
                          ? const Radius.circular(4)
                          : const Radius.circular(18),
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          if (message.isUser)
            const SizedBox(width: 12),
          if (message.isUser)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                size: 20,
                color: Colors.blue,
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 20,
              color: Colors.amber,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDot(0),
                  _buildDot(1),
                  _buildDot(2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.8 + 0.4 * sin(value * 2 * pi + index * 0.5),
            child: child,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}