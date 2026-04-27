class JourneyChatMessage {
  const JourneyChatMessage({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, dynamic> toJson() {
    return {'role': role, 'content': content};
  }
}
