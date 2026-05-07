// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Habit Loop';

  @override
  String get dashboardTitle => 'Главная';

  @override
  String get todayShowups => 'Сегодняшние визиты';

  @override
  String get noPactsYet => 'Нет пактов';

  @override
  String get noPactsDescription => 'Создайте первый пакт, чтобы начать формировать привычку.';

  @override
  String get createPact => 'Создать пакт';

  @override
  String get noShowupsForDay => 'Нет визитов в этот день';

  @override
  String get showupDone => 'Выполнено';

  @override
  String get showupFailed => 'Пропущено';

  @override
  String get showupPending => 'Ожидается';

  @override
  String get pactCreationTitle => 'Новый пакт';

  @override
  String get habitNameLabel => 'Название привычки';

  @override
  String get habitNameHint => 'например, Медитация, Пробежка, Чтение…';

  @override
  String get pactDurationStep => 'Длительность пакта';

  @override
  String get startDateLabel => 'Дата начала';

  @override
  String get endDateLabel => 'Дата окончания';

  @override
  String get showupDurationStep => 'Длительность визита';

  @override
  String get showupDurationLabel => 'Как долго длится каждый визит?';

  @override
  String showupDurationMinutes(int minutes) {
    return '$minutes мин';
  }

  @override
  String get scheduleStep => 'Расписание';

  @override
  String get scheduleTypeLabel => 'Когда вы хотите появляться?';

  @override
  String get scheduleDaily => 'Каждый день';

  @override
  String get scheduleWeekday => 'Определённые дни недели';

  @override
  String get scheduleMonthlyByWeekday => 'Ежемесячно по дню недели';

  @override
  String get scheduleMonthlyByDate => 'Ежемесячно по числу';

  @override
  String get timeOfDayLabel => 'Время';

  @override
  String get addEntry => 'Добавить ещё';

  @override
  String get removeEntry => 'Удалить';

  @override
  String get weekdayMon => 'Пн';

  @override
  String get weekdayTue => 'Вт';

  @override
  String get weekdayWed => 'Ср';

  @override
  String get weekdayThu => 'Чт';

  @override
  String get weekdayFri => 'Пт';

  @override
  String get weekdaySat => 'Сб';

  @override
  String get weekdaySun => 'Вс';

  @override
  String get occurrenceFirst => '1-й';

  @override
  String get occurrenceSecond => '2-й';

  @override
  String get occurrenceThird => '3-й';

  @override
  String get occurrenceFourth => '4-й';

  @override
  String get dayOfMonthLabel => 'День месяца';

  @override
  String get reminderStep => 'Напоминание';

  @override
  String get reminderLabel => 'Напомнить перед визитом';

  @override
  String get reminderNone => 'Без напоминания';

  @override
  String get reminderAtStart => 'В момент начала';

  @override
  String reminderMinutesBefore(int minutes) {
    return 'За $minutes мин';
  }

  @override
  String get summaryHabit => 'Привычка';

  @override
  String get summaryDuration => 'Длительность пакта';

  @override
  String get summaryShowupDuration => 'Длительность визита';

  @override
  String get summarySchedule => 'Расписание';

  @override
  String get summaryReminder => 'Напоминание';

  @override
  String get commitmentStep => 'Обязательство';

  @override
  String get commitmentWarning =>
      'Пропущенный визит считается провалом. Исключений и пауз нет. Создавая этот пакт, вы обязуетесь появляться каждый раз.';

  @override
  String get commitmentAccept => 'Понимаю и обязуюсь';

  @override
  String get createPactConfirm => 'Создать пакт';

  @override
  String get next => 'Далее';

  @override
  String get back => 'Назад';

  @override
  String get cancel => 'Отмена';

  @override
  String get tooManyPactsTitle => 'Слишком много активных пактов';

  @override
  String tooManyPactsBody(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Можно иметь только $max активных пакта одновременно. Создать ещё?',
      many: 'Можно иметь только $max активных пактов одновременно. Создать ещё?',
      few: 'Можно иметь только $max активных пакта одновременно. Создать ещё?',
      one: 'Можно иметь только 1 активный пакт одновременно. Создать ещё один?',
    );
    return '$_temp0';
  }

  @override
  String get tooManyPactsConfirm => 'Да, создать ещё';

  @override
  String get pactDetailTitle => 'Детали пакта';

  @override
  String get sectionStats => 'Статистика';

  @override
  String get sectionTimeline => 'Хронология';

  @override
  String get sectionStopReason => 'Причина остановки';

  @override
  String get stopPactError => 'Не удалось остановить пакт. Попробуйте ещё раз.';

  @override
  String get statsDone => 'Выполнено';

  @override
  String get statsFailed => 'Пропущено';

  @override
  String get statsRemaining => 'Осталось';

  @override
  String get statsCancelled => 'Остановлено';

  @override
  String get statsStreak => 'Серия';

  @override
  String statsShowups(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count визита',
      many: '$count визитов',
      few: '$count визита',
      one: '$count визит',
    );
    return '$_temp0';
  }

  @override
  String get pactStartDate => 'Начало';

  @override
  String get pactEndDate => 'Конец';

  @override
  String get pactEndedDate => 'Завершено';

  @override
  String daysRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Осталось $count дня',
      many: 'Осталось $count дней',
      few: 'Осталось $count дня',
      one: 'Остался 1 день',
    );
    return '$_temp0';
  }

  @override
  String get pactStatusActive => 'Активен';

  @override
  String get pactStatusStopped => 'Остановлен';

  @override
  String get pactStatusCompleted => 'Завершён';

  @override
  String get stopPact => 'Остановить пакт';

  @override
  String get stopPactTitle => 'Остановить пакт?';

  @override
  String get stopPactBody => 'Это действие необратимо. Вы сможете просмотреть историю пакта позже.';

  @override
  String get stopPactReasonHint => 'Причина (необязательно)';

  @override
  String get stopPactConfirm => 'Остановить';

  @override
  String pactsActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count активных пакта',
      many: '$count активных пактов',
      few: '$count активных пакта',
      one: '1 активный пакт',
      zero: 'Нет активных пактов',
    );
    return '$_temp0';
  }

  @override
  String pactsDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count завершённых пакта',
      many: '$count завершённых пактов',
      few: '$count завершённых пакта',
      one: '1 завершённый пакт',
      zero: 'Нет завершённых пактов',
    );
    return '$_temp0';
  }

  @override
  String pactsCancelled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count остановленных пакта',
      many: '$count остановленных пактов',
      few: '$count остановленных пакта',
      one: '1 остановленный пакт',
      zero: 'Нет остановленных пактов',
    );
    return '$_temp0';
  }

  @override
  String get addPact => 'Добавить пакт';

  @override
  String get pactListTitle => 'Пакты';

  @override
  String get filterActive => 'Активные';

  @override
  String get filterDone => 'Завершённые';

  @override
  String get filterCancelled => 'Остановленные';

  @override
  String pactNextShowup(String date) {
    return 'Следующий: $date';
  }

  @override
  String pactEndedOn(String date) {
    return 'Завершён $date';
  }

  @override
  String pactCancelledOn(String date) {
    return 'Остановлен $date';
  }

  @override
  String get showupDetailTitle => 'Детали визита';

  @override
  String get showupDetailHabit => 'Привычка';

  @override
  String get showupDetailScheduledAt => 'Запланировано на';

  @override
  String get showupDetailDuration => 'Длительность';

  @override
  String get showupDetailStatus => 'Статус';

  @override
  String get markDone => 'Отметить выполненным';

  @override
  String get markFailed => 'Отметить пропущенным';

  @override
  String get showupAutoFailed =>
      'Этот визит автоматически отмечен как пропущенный, так как был открыт после запланированного времени.';

  @override
  String get showupNoteLabel => 'Заметка';

  @override
  String get showupNoteSave => 'Сохранить заметку';

  @override
  String get showupNoteError => 'Не удалось сохранить заметку. Попробуйте ещё раз.';

  @override
  String get showupMarkError => 'Не удалось обновить статус визита. Попробуйте ещё раз.';

  @override
  String get showupHabitDeleted => '(привычка удалена)';

  @override
  String get languagePickerTitle => 'Язык';

  @override
  String get languageEnglish => 'Английский';

  @override
  String get languageFrench => 'Французский';

  @override
  String get languageGerman => 'Немецкий';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageSystem => 'Использовать язык системы';

  @override
  String notificationReminderTitle(String habitName) {
    return '$habitName, время для визита!';
  }

  @override
  String get notificationReminderBody => 'Нажмите, чтобы отметить визит.';

  @override
  String notificationDeadlineTitle(String habitName) {
    return '$habitName: отметьте визит выполненным';
  }

  @override
  String notificationDeadlineBody(String time) {
    return 'Окно закрывается в $time.';
  }

  @override
  String notificationTimeLimitTitle(String habitName) {
    return '$habitName: время визита!';
  }

  @override
  String notificationTimeLimitBody(String duration) {
    return 'У вас $duration, чтобы отметить визит.';
  }

  @override
  String get notificationMissedTitle => 'Вы пропустили этот визит';

  @override
  String get notificationMissedBody => 'Ничего страшного — появитесь в следующий раз.';

  @override
  String notificationDurationMinutes(int count) {
    return '$count мин';
  }

  @override
  String notificationDurationHours(int count) {
    return '$count ч';
  }
}
