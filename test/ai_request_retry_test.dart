import 'package:dar_plus/services/ai_request_retry.dart';
import 'package:flutter_test/flutter_test.dart';

class _TemporaryFailure implements Exception {}

void main() {
  group('retryAiRequest', () {
    test(
      'retries temporary failures and returns the first successful result',
      () async {
        var attempts = 0;

        final result = await retryAiRequest<String>(
          request: () async {
            attempts++;
            if (attempts < 3) throw _TemporaryFailure();
            return 'answer';
          },
          shouldRetry: (error) => error is _TemporaryFailure,
          retryDelays: const [Duration.zero, Duration.zero],
        );

        expect(result, 'answer');
        expect(attempts, 3);
      },
    );

    test('does not retry non-transient failures', () async {
      var attempts = 0;

      await expectLater(
        retryAiRequest<void>(
          request: () async {
            attempts++;
            throw ArgumentError('invalid request');
          },
          shouldRetry: (error) => error is _TemporaryFailure,
          retryDelays: const [Duration.zero],
        ),
        throwsArgumentError,
      );

      expect(attempts, 1);
    });
  });
}
