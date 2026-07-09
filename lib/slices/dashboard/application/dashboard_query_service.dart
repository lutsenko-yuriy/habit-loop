import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';

class DashboardQueryService {
  final PactRepository _pactRepository;
  final ShowupRepository _showupRepository;

  DashboardQueryService({
    required PactRepository pactRepository,
    required ShowupRepository showupRepository,
  })  : _pactRepository = pactRepository,
        _showupRepository = showupRepository;

  Future<List<Pact>> getAllPacts() => _pactRepository.getAllPacts();

  Future<List<Pact>> getActivePacts() => _pactRepository.getActivePacts();

  Future<DateTime?> getLatestScheduledAtForPact(String pactId) => _showupRepository.getLatestScheduledAtForPact(pactId);

  Future<List<Showup>> getShowupsForDateRange(DateTime start, DateTime end) =>
      _showupRepository.getShowupsForDateRange(start, end);

  Future<List<Showup>> getShowupsForPact(String pactId) => _showupRepository.getShowupsForPact(pactId);
}
