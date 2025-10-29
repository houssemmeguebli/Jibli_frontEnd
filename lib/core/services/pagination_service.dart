class PaginationService {
  final int itemsPerPage;

  PaginationService({this.itemsPerPage = 10});

  /// Get paginated items from a list
  List<T> getPageItems<T>(List<T> items, int pageNumber) {
    final startIndex = (pageNumber - 1) * itemsPerPage;
    final endIndex = startIndex + itemsPerPage;

    if (startIndex >= items.length) return [];
    if (endIndex > items.length) {
      return items.sublist(startIndex);
    }
    return items.sublist(startIndex, endIndex);
  }

  /// Get total number of pages
  int getTotalPages(int itemsCount) {
    return (itemsCount / itemsPerPage).ceil();
  }

  /// Validate if page number is valid
  bool isValidPage(int pageNumber, int totalItems) {
    return pageNumber > 0 && pageNumber <= getTotalPages(totalItems);
  }
}

/// Model to manage pagination state
class PaginationState {
  final int currentPage;
  final int totalItems;
  final int itemsPerPage;

  PaginationState({
    required this.currentPage,
    required this.totalItems,
    this.itemsPerPage = 10,
  });

  int get totalPages => (totalItems / itemsPerPage).ceil();
  bool get hasNextPage => currentPage < totalPages;
  bool get hasPreviousPage => currentPage > 1;
  int get startIndex => (currentPage - 1) * itemsPerPage;
  int get endIndex {
    final end = startIndex + itemsPerPage;
    return end > totalItems ? totalItems : end;
  }

  String get pageInfo => totalItems == 0 ? '0' : '${startIndex + 1}-$endIndex de $totalItems';

  PaginationState copyWith({
    int? currentPage,
    int? totalItems,
    int? itemsPerPage,
  }) {
    return PaginationState(
      currentPage: currentPage ?? this.currentPage,
      totalItems: totalItems ?? this.totalItems,
      itemsPerPage: itemsPerPage ?? this.itemsPerPage,
    );
  }
}