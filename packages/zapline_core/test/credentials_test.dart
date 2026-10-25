import 'package:test/test.dart';
import 'package:zapline_core/zapline_core.dart';

void main() {
  test('credentials leave stored URLs and come back to play', () {
    final live = Uri.parse('http://p.example:8080/live/mario/s3cret/123.ts');
    final hidden = hideCredentials(live, 'mario', 's3cret');
    expect(hidden.toString(), isNot(contains('s3cret')));
    expect(hidden.toString(), isNot(contains('mario')));
    expect(hasCredentialPlaceholders(hidden), isTrue);
    expect(revealCredentials(hidden, 'mario', 's3cret'), live);

    final short = Uri.parse('http://p.example/mario/s3cret/7');
    expect(
        revealCredentials(
            hideCredentials(short, 'mario', 's3cret'), 'mario', 's3cret'),
        short);

    final query = Uri.parse(
      'http://p.example/get.php?username=mario&password=s3cret&type=ts',
    );
    final q = hideCredentials(query, 'mario', 's3cret');
    expect(q.toString(), isNot(contains('s3cret')));
    expect(revealCredentials(q, 'mario', 's3cret').queryParameters,
        query.queryParameters);
  });

  test('other addresses are left alone', () {
    final u = Uri.parse('http://cdn.example/rai1/index.m3u8');
    expect(hideCredentials(u, 'mario', 's3cret'), u);
    expect(revealCredentials(u, 'mario', 's3cret'), u);
    expect(hideCredentials(u, '', ''), u);
  });

  test('a playlist link tells its credentials', () {
    expect(
      credentialsInLink(
        'http://p.example/get.php?username=mario&password=s3cret&type=m3u',
      ),
      ('mario', 's3cret'),
    );
    expect(credentialsInLink('http://p.example/list.m3u'), isNull);
  });

  test('errors and logs lose the credentials', () {
    final msg = redactSecrets(
      'ClientException: Connection reset, '
      'uri=http://p.example/player_api.php?username=mario&password=s3cret '
      'and http://p.example/live/mario/s3cret/1.ts',
    );
    expect(msg, isNot(contains('s3cret')));
    expect(msg, isNot(contains('mario')));
    expect(msg, contains('p.example'));
  });
}
