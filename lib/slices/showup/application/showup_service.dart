import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';

class ShowupService {
  final PactRepository _pactRepository;
  final ShowupRepository _showupRepository;

  ShowupService({
    required PactRepository pactRepository,
    required ShowupRepository showupRepository,
  })  : _pactRepository = pactRepository,
        _showupRepository = showupRepository;

  Future<Showup?> getShowupById(String id) => _showupRepository.getShowupById(id);

  Future<Pact?> getPactById(String id) => _pactRepository.getPactById(id);

  Future<void> updateShowup(Showup showup) => _showupRepository.updateShowup(showup);
}
