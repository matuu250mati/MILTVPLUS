/// Fetches a PostgREST result in bounded pages instead of silently stopping at
/// the server's default row limit. A limit is useful for lightweight home rails.
Future<List<T>> fetchAllPages<T>({
  required Future<List<T>> Function(int from, int to) fetchPage,
  int? limit,
  int pageSize = 250,
}) async {
  if (pageSize <= 0) {
    throw ArgumentError.value(pageSize, 'pageSize', 'Must be positive.');
  }
  if (limit != null && limit < 0) {
    throw ArgumentError.value(limit, 'limit', 'Must not be negative.');
  }
  if (limit == 0) return <T>[];

  final items = <T>[];
  var offset = 0;

  while (true) {
    final remaining = limit == null ? pageSize : limit - items.length;
    final requested = remaining < pageSize ? remaining : pageSize;
    final page = await fetchPage(offset, offset + requested - 1);
    items.addAll(page);

    if (page.length < requested || (limit != null && items.length >= limit)) {
      break;
    }
    // Advance by the actual count returned so a short page cannot create gaps.
    offset += page.length;
  }

  return items;
}
