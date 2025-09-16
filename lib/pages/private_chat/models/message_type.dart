enum MessageType {
  text,
  image,
  video,
  voice,
  music,
  doc;

  static MessageType fromString(String type) {
    return MessageType.values.firstWhere(
      (e) => e.name == type,
      orElse: () => MessageType.doc,
    );
  }
}