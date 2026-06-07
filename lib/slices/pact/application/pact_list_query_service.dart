import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';

class PactListQueryService {
  final PactRepository _pactRepository;
  final ShowupRepository _showupRepository;

  PactListQueryService({
    required PactRepository pactRepository,
    required ShowupRepository showupRepository,
  })  : _pactRepository = pactRepository,
        _showupRepository = showupRepository;

  Future<List<Pact>> getAllPacts() => _pactRepository.getAllPacts();

  Future<List<Showup>> getShowupsForPact(String pactId) => _showupRepository.getShowupsForPact(pactId);

  Future<bool> hasActivePacts() async {
    final active = await _pactRepository.getActivePacts();
    return active.isNotEmpty;
  }
}
