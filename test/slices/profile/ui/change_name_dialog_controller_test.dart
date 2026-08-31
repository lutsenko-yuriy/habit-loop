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

    test('seeds an empty text controller when currentName is empty', () {
      final controller = ChangeNameDialogController('');
      expect(controller.textController.text, isEmpty);
      controller.dispose();
    });

    test('dispose does not throw, and further text changes throw (controller is disposed)', () {
      final controller = ChangeNameDialogController('Alex');
      controller.dispose();
      expect(() => controller.textController.text = 'ignored, controller is disposed', throwsFlutterError);
    });
  });
}
