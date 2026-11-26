Future<T> retryAiRequest<T>({
  required Future<T> Function() request,
  required bool Function(Exception error) shouldRetry,
  List<Duration> retryDelays = const [Duration(seconds: 1)],
}) async {
  var retryCount = 0;
  while (true) {
    try {
      return await request();
    } on Exception catch (error) {
      if (!shouldRetry(error) || retryCount >= retryDelays.length) {
        rethrow;
      }
      await Future<void>.delayed(retryDelays[retryCount]);
      retryCount++;
    }
  }
}
