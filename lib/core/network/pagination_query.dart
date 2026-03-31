class PaginationQuery {
  const PaginationQuery({
    this.page = 0,
    this.size = 10,
    this.search,
    this.sortBy = 'createdAt',
    this.sortDir = 'desc',
  });

  final int page;
  final int size;
  final String? search;
  final String sortBy;
  final String sortDir;

  PaginationQuery copyWith({
    int? page,
    int? size,
    String? search,
    String? sortBy,
    String? sortDir,
    bool clearSearch = false,
  }) {
    return PaginationQuery(
      page: page ?? this.page,
      size: size ?? this.size,
      search: clearSearch ? null : (search ?? this.search),
      sortBy: sortBy ?? this.sortBy,
      sortDir: sortDir ?? this.sortDir,
    );
  }

  Map<String, dynamic> toQueryParameters([Map<String, dynamic> extra = const {}]) {
    final params = <String, dynamic>{
      'page': page,
      'size': size,
      'sortBy': sortBy,
      'sortDir': sortDir,
    };

    if (search != null && search!.trim().isNotEmpty) {
      params['search'] = search!.trim();
    }

    for (final entry in extra.entries) {
      if (entry.value != null) {
        params[entry.key] = entry.value;
      }
    }

    return params;
  }
}
