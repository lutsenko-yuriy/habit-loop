import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/slices/profile/ui/generic/change_name_dialog_controller.dart';

void main() {
  group('ChangeNameDialogController', () {
    test('seeds the text controller with currentName and places the cursor at the end', () {
      final controller = ChangeNameDialogController('Alex');
      expect(controller.textController.text, 'Alex');
      expect(controller.textController.selection.baseOffset, 4);
      controller.dispose();
    });

    test('canSave starts true when currentName is non-empty', () {
      final controller = ChangeNameDialogController('Alex');
      expect(controller.canSave.value, isTrue);
      controller.dispose();
    });

    test('canSave starts true when currentName is empty', () {
      final controller = ChangeNameDialogController('');
      expect(controller.canSave.value, isTrue);
      controller.dispose();
    });

    test('canSave stays true when the field is cleared — clearing saves an empty name', () {
      final controller = ChangeNameDialogController('Alex');
      controller.textController.text = '   ';
      expect(controller.canSave.value, isTrue);
      controller.dispose();
    });

    test('canSave stays true once non-whitespace text is entered', () {
      final controller = ChangeNameDialogController('');
      controller.textController.text = 'Sam';
      expect(controller.canSave.value, isTrue);
      controller.dispose();
    });

    test('dispose does not throw, and further text changes throw (controller is disposed)', () {
      final controller = ChangeNameDialogController('Alex');
      controller.dispose();
      expect(() => controller.textController.text = 'ignored, controller is disposed', throwsFlutterError);
    });
  });
}
