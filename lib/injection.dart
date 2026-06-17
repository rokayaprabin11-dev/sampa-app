import 'package:get_it/get_it.dart';
import 'data/repositories/i_location_repository.dart';
import 'data/repositories/location_repository_impl.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Repositories
  sl.registerLazySingleton<ILocationRepository>(() => LocationRepositoryImpl());
}







