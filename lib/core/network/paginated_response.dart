class PaginatedResponse<T> {
  const PaginatedResponse({
    required this.items,
    required this.page,
    required this.size,
    required this.totalItems,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrevious,
    required this.sortBy,
    required this.sortDir,
    required this.filters,
  });

  final List<T> items;
  final int page;
  final int size;
  final int totalItems;
  final int totalPages;
  final bool hasNext;
  final bool hasPrevious;
  final String sortBy;
  final String sortDir;
  final Map<String, dynamic> filters;

  factory PaginatedResponse.empty({
    int page = 0,
    int size = 10,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
    Map<String, dynamic> filters = const {},
  }) {
    return PaginatedResponse(
      items: const [],
      page: page,
      size: size,
      totalItems: 0,
      totalPages: 1,
      hasNext: false,
      hasPrevious: false,
      sortBy: sortBy,
      sortDir: sortDir,
      filters: filters,
    );
  }

  PaginatedResponse<T> copyWith({
    List<T>? items,
    int? page,
    int? size,
    int? totalItems,
    int? totalPages,
    bool? hasNext,
    bool? hasPrevious,
    String? sortBy,
    String? sortDir,
    Map<String, dynamic>? filters,
  }) {
    return PaginatedResponse(
      items: items ?? this.items,
      page: page ?? this.page,
      size: size ?? this.size,
      totalItems: totalItems ?? this.totalItems,
      totalPages: totalPages ?? this.totalPages,
      hasNext: hasNext ?? this.hasNext,
      hasPrevious: hasPrevious ?? this.hasPrevious,
      sortBy: sortBy ?? this.sortBy,
      sortDir: sortDir ?? this.sortDir,
      filters: filters ?? this.filters,
    );
  }
}
