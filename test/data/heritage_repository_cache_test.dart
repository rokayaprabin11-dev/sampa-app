import 'package:flutter_test/flutter_test.dart';
import 'package:sampada/data/datasources/local/heritage_local_datasource.dart';
import 'package:sampada/data/datasources/remote/heritage_remote_datasource.dart';
import 'package:sampada/data/models/heritage_site_model.dart';
import 'package:sampada/data/repositories/heritage_repository.dart';
import 'package:sampada/data/repositories/heritage_repository_impl.dart';

HeritageSiteModel _site(String id) => HeritageSiteModel(
      id: id,
      name: 'Site $id',
      nameNepali: 'स्थल $id',
      description: '',
      descriptionNepali: '',
      location: 'Kathmandu',
      latitude: 27.7,
      longitude: 85.3,
      category: 'temple',
      district: 'Kathmandu',
      districtId: '1',
    );

/// Remote source that fails the test if it is touched at all — this is how we
/// prove the cache-only path issues no HTTP request.
class _ForbiddenRemote implements HeritageRemoteDataSource {
  bool wasCalled = false;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    wasCalled = true;
    throw StateError(
        'remote datasource must not be called: ${invocation.memberName}');
  }
}

/// Remote source that always fails, to exercise the fallback-to-cache path.
class _FailingRemote implements HeritageRemoteDataSource {
  int callCount = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    callCount++;
    return Future<Never>.error(Exception('network down'));
  }
}

class _WorkingRemote implements HeritageRemoteDataSource {
  int callCount = 0;

  @override
  Future<List<HeritageSiteModel>> getHeritageSites({
    String? query,
    String? category,
    String? district,
    double? lat,
    double? lng,
    double? radius,
    int? page,
    int? pageSize,
    String? bbox,
    String? sortBy,
  }) async {
    callCount++;
    return [_site('remote-1')];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeLocal implements HeritageLocalDataSource {
  _FakeLocal(this.cached);

  final List<HeritageSiteModel> cached;
  int? lastRequestedLimit;

  @override
  Future<List<HeritageSiteModel>> getLastHeritageSites({
    int limit = 20,
    int offset = 0,
  }) async {
    lastRequestedLimit = limit;
    return cached.take(limit).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  group('getCachedHeritageSites (cache-only)', () {
    test('reads from SQLite and never calls the remote datasource', () async {
      final remote = _ForbiddenRemote();
      final local = _FakeLocal([_site('cached-1'), _site('cached-2')]);
      final repository =
          HeritageRepositoryImpl(remoteDataSource: remote, localDataSource: local);

      final result = await repository.getCachedHeritageSites();

      expect(remote.wasCalled, isFalse);
      expect(result.sites.map((s) => s.id), ['cached-1', 'cached-2']);
      expect(result.source, HeritageDataSource.cache);
      expect(result.isFromCache, isTrue);
    });

    test('honours the limit it is given', () async {
      final local = _FakeLocal([_site('a'), _site('b'), _site('c')]);
      final repository = HeritageRepositoryImpl(
        remoteDataSource: _ForbiddenRemote(),
        localDataSource: local,
      );

      final result = await repository.getCachedHeritageSites(limit: 2);

      expect(local.lastRequestedLimit, 2);
      expect(result.sites, hasLength(2));
    });

    test('an empty cache yields an empty result, not a throw', () async {
      final repository = HeritageRepositoryImpl(
        remoteDataSource: _ForbiddenRemote(),
        localDataSource: _FakeLocal([]),
      );

      final result = await repository.getCachedHeritageSites();

      expect(result.sites, isEmpty);
      expect(result.isFromCache, isTrue);
    });
  });

  group('getHeritageSites (remote-first)', () {
    test('reports the remote source on success', () async {
      final remote = _WorkingRemote();
      final repository = HeritageRepositoryImpl(
        remoteDataSource: remote,
        localDataSource: _FakeLocal([_site('cached-1')]),
      );

      final result = await repository.getHeritageSites();

      expect(remote.callCount, 1);
      expect(result.source, HeritageDataSource.remote);
      expect(result.sites.single.id, 'remote-1');
    });

    test('falls back to cache when the request fails, and says so', () async {
      final repository = HeritageRepositoryImpl(
        remoteDataSource: _FailingRemote(),
        localDataSource: _FakeLocal([_site('cached-1')]),
      );

      final result = await repository.getHeritageSites();

      expect(result.isFromCache, isTrue);
      expect(result.sites.single.id, 'cached-1');
    });

    test('rethrows when the request fails and the cache is empty', () async {
      final repository = HeritageRepositoryImpl(
        remoteDataSource: _FailingRemote(),
        localDataSource: _FakeLocal([]),
      );

      expect(() => repository.getHeritageSites(), throwsA(isA<Exception>()));
    });
  });
}
