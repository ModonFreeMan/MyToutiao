import 'dart:convert';
import 'dart:io';

import 'search_video_document.dart';

abstract interface class SearchBusinessStore {
  Future<void> upsert(SearchVideoDocument document);

  Future<SearchVideoDocument?> findByVideoId(String videoId);
}

class JsonSearchBusinessStore implements SearchBusinessStore {
  JsonSearchBusinessStore({required this.file});

  final File file;

  @override
  Future<void> upsert(SearchVideoDocument document) async {
    final documents = await _readAll();
    final index = documents.indexWhere(
      (item) => item.videoId == document.videoId,
    );
    if (index == -1) {
      documents.add(document);
    } else {
      documents[index] = document;
    }

    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(
      encoder.convert(documents.map((item) => item.toJson()).toList()),
    );
  }

  @override
  Future<SearchVideoDocument?> findByVideoId(String videoId) async {
    final documents = await _readAll();
    for (final document in documents) {
      if (document.videoId == videoId) {
        return document;
      }
    }

    return null;
  }

  Future<List<SearchVideoDocument>> _readAll() async {
    if (!await file.exists()) {
      return <SearchVideoDocument>[];
    }

    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      return <SearchVideoDocument>[];
    }

    final json = jsonDecode(content) as List<Object?>;
    return json
        .cast<Map<String, Object?>>()
        .map(SearchVideoDocument.fromJson)
        .toList();
  }
}
