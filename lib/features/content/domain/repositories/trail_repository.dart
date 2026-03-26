import 'package:evolua_frontend/features/content/domain/entities/trail.dart';

abstract class TrailRepository {
  Future<List<Trail>> list();

  Future<Trail> create({
    required String title,
    required String description,
    required String category,
    required bool premium,
  });
}
