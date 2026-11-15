enum PhotoBucket {
  pending('Chưa hoàn tất OCR'),
  queue('Trong hàng đợi OCR'),
  matched('Đã khớp BIB'),
  ready('Chờ công khai'),
  published('Đã công khai'),
  review('Cần kiểm tra'),
  discarded('Đã loại');

  const PhotoBucket(this.label);

  final String label;
}

class PhotoAnalytics {
  final Map<PhotoBucket, int> counts;

  PhotoAnalytics(Map<PhotoBucket, int> counts)
    : counts = Map.unmodifiable(counts);

  int count(PhotoBucket bucket) => counts[bucket]!;

  // Pending includes queue, and matched includes ready and published.
  int get total => count(PhotoBucket.pending) + processed;

  int get processed =>
      count(PhotoBucket.matched) +
      count(PhotoBucket.review) +
      count(PhotoBucket.discarded);

  double ocrRate(PhotoBucket bucket) => _percent(count(bucket), processed);

  double get estimatedPrecision => _percent(
    count(PhotoBucket.matched),
    count(PhotoBucket.matched) + count(PhotoBucket.review),
  );

  double _percent(int value, int total) => total == 0 ? 0 : value * 100 / total;
}
