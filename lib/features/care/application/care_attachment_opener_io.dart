import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<void> openCareAttachmentFile(List<int> bytes, String fileName) async {
  final directory = await getTemporaryDirectory();
  final file = File(p.join(directory.path, fileName));
  await file.writeAsBytes(bytes, flush: true);
  await OpenFilex.open(file.path);
}
