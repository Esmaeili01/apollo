import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message_type.dart';

class FileService {
  static ({String bucket, String type}) getFileInfo(String? extension) {
    final ext = extension?.toLowerCase() ?? '';
    if (['jpg', 'jpeg', 'png', 'gif'].contains(ext))
      return (bucket: 'pics', type: MessageType.image.name);
    if (['mp4', 'mov', 'avi', 'webm'].contains(ext))
      return (bucket: 'vids', type: MessageType.video.name);
    if (['mp3', 'wav', 'ogg'].contains(ext))
      return (bucket: 'musics', type: MessageType.music.name);
    if (ext == 'm4a' || ext == 'webm')
      return (bucket: 'voices', type: MessageType.voice.name);
    return (bucket: 'docs', type: MessageType.doc.name);
  }

  static Future<String> uploadFileToSupabase(PlatformFile file, String bucket) async {
    final storage = Supabase.instance.client.storage.from(bucket);
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final fileExt = file.extension ?? 'bin';
    final filePath =
        '$userId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final bytes = file.bytes;
    if (bytes == null) throw 'File data is empty.';
    await storage.uploadBinary(
      filePath,
      bytes,
      fileOptions: const FileOptions(upsert: false),
    );
    return storage.getPublicUrl(filePath);
  }
}