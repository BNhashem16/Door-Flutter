import 'package:flutter/material.dart';

/// Hand-written localization (Arabic + English). No code-gen.
///
/// Resolve in widgets with `AppStrings.of(context)`. The active locale is
/// driven by `MaterialApp.locale` / `supportedLocales`; switching the locale
/// rebuilds the tree and re-resolves every string. RTL/LTR direction comes
/// from `flutter_localizations` global delegates wired in `main.dart`.
abstract class AppStrings {
  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings)!;

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  /// Resolve strings without a [BuildContext] (e.g. headless widget callbacks).
  static AppStrings forLanguageCode(String code) =>
      code == 'en' ? const _En() : const _Ar();

  static const List<Locale> supportedLocales = [Locale('ar'), Locale('en')];

  // App
  String get appTitle;

  /// Tooltip on the language toggle — names the language it switches TO.
  String get languageToggleTooltip;

  // Auth gate — logged out elsewhere
  String get loggedOutElsewhereTitle;
  String get loggedOutElsewhereBody;

  // Login
  String get loginTitle;
  String get signInButton;
  String get noAccountRegister;

  // Register
  String get registerTitle;
  String get registerButton;

  // Shared form fields
  String get name;
  String get email;
  String get password;
  String get enterName;
  String get emailInvalid;
  String get passwordTooShort;

  // Pending / rejected
  String get pendingTitle;
  String get pendingBody;
  String get rejectedTitle;
  String get rejectedBody;

  // Admin
  String get adminTitle;
  String get loadUsersError;
  String get noUsers;
  String get noName;
  String get approve;
  String get reject;
  String get makeAdmin;
  String get removeAdmin;
  String get edit;
  String get delete;
  String get cancel;
  String get deleteUserTitle;
  String deleteUserConfirm(String name);
  String get userDeleted;
  String get userDeleteFailed;

  // Admin edit
  String get editUserTitle;
  String get enterNameField;
  String get roleLabel;
  String get statusLabel;

  // Gate control
  String get gateTitle;
  String get profileTooltip;
  String get lightMode;
  String get darkMode;
  String get signOut;
  String get connecting;
  String get connected;
  String get disconnected;
  String get gateOpen;
  String get gateClosed;
  String get tapToOpen;
  String get tapToClose;
  String get openGate;
  String get closeGate;
  String get gateOpened;
  String get gateClosedMsg;
  String get systemInfo;
  String get connectionStatusLabel;
  String get gateStatusLabel;
  String get stateOpen;
  String get stateClosed;
  String get syncLabel;
  String get syncLive;

  // Home-screen widget
  String get widgetLoginRequired;

  // Profile
  String get profileTitle;
  String get noUser;
  String get loadProfileError;
  String get apartment;
  String get bio;
  String get notAddedYet;
  String get editProfile;

  // Profile edit
  String get saveChangesSuccess;
  String get saveChangesError;
  String get save;

  // Status badge
  String get roleAdmin;
  String get roleUser;
  String get statusApproved;
  String get statusRejected;
  String get statusPending;
  String get statusUnknown;

  // Dynamic messages
  String get unexpectedError;
  String connectionError(Object error);
  String signInError(String code);
  String registerError(String code);
}

class _Ar implements AppStrings {
  const _Ar();

  @override
  String get appTitle => 'تحكم البوابة';
  @override
  String get languageToggleTooltip => 'English';

  @override
  String get loggedOutElsewhereTitle => 'تم تسجيل الدخول على جهاز آخر';
  @override
  String get loggedOutElsewhereBody => 'هذا الحساب يُستخدم الآن على جهاز آخر.';

  @override
  String get loginTitle => 'تسجيل الدخول';
  @override
  String get signInButton => 'دخول';
  @override
  String get noAccountRegister => 'ليس لديك حساب؟ سجّل الآن';

  @override
  String get registerTitle => 'إنشاء حساب';
  @override
  String get registerButton => 'تسجيل';

  @override
  String get name => 'الاسم';
  @override
  String get email => 'البريد الإلكتروني';
  @override
  String get password => 'كلمة المرور';
  @override
  String get enterName => 'أدخل اسمك';
  @override
  String get emailInvalid => 'أدخل بريدًا إلكترونيًا صحيحًا';
  @override
  String get passwordTooShort => 'كلمة المرور 6 أحرف على الأقل';

  @override
  String get pendingTitle => 'بانتظار الموافقة';
  @override
  String get pendingBody =>
      'تم إنشاء حسابك بنجاح. سيتمكن المسؤول من الموافقة عليه قريبًا.';
  @override
  String get rejectedTitle => 'تم رفض الحساب';
  @override
  String get rejectedBody =>
      'تم رفض حسابك. تواصل مع المسؤول لمزيد من المعلومات.';

  @override
  String get adminTitle => 'إدارة المستخدمين';
  @override
  String get loadUsersError => 'تعذّر تحميل المستخدمين';
  @override
  String get noUsers => 'لا يوجد مستخدمون';
  @override
  String get noName => '(بدون اسم)';
  @override
  String get approve => 'موافقة';
  @override
  String get reject => 'رفض';
  @override
  String get makeAdmin => 'تعيين مسؤول';
  @override
  String get removeAdmin => 'إزالة المسؤول';
  @override
  String get edit => 'تعديل';
  @override
  String get delete => 'حذف';
  @override
  String get cancel => 'إلغاء';
  @override
  String get deleteUserTitle => 'حذف المستخدم';
  @override
  String deleteUserConfirm(String name) =>
      'هل تريد حذف «$name»؟ لا يمكن التراجع عن هذا الإجراء.';
  @override
  String get userDeleted => 'تم حذف المستخدم';
  @override
  String get userDeleteFailed => 'فشل حذف المستخدم';

  @override
  String get editUserTitle => 'تعديل المستخدم';
  @override
  String get enterNameField => 'أدخل الاسم';
  @override
  String get roleLabel => 'الصلاحية';
  @override
  String get statusLabel => 'الحالة';

  @override
  String get gateTitle => 'تحكم البوابة';
  @override
  String get profileTooltip => 'الملف الشخصي';
  @override
  String get lightMode => 'الوضع المضيء';
  @override
  String get darkMode => 'الوضع المظلم';
  @override
  String get signOut => 'تسجيل الخروج';
  @override
  String get connecting => 'جارٍ الاتصال';
  @override
  String get connected => 'متصل';
  @override
  String get disconnected => 'غير متصل';
  @override
  String get gateOpen => 'البوابة مفتوحة';
  @override
  String get gateClosed => 'البوابة مغلقة';
  @override
  String get tapToOpen => 'اضغط للفتح';
  @override
  String get tapToClose => 'اضغط للإغلاق';
  @override
  String get openGate => 'فتح البوابة';
  @override
  String get closeGate => 'إغلاق البوابة';
  @override
  String get gateOpened => 'تم فتح البوابة';
  @override
  String get gateClosedMsg => 'تم إغلاق البوابة';
  @override
  String get systemInfo => 'معلومات النظام';
  @override
  String get connectionStatusLabel => 'حالة الاتصال';
  @override
  String get gateStatusLabel => 'حالة البوابة';
  @override
  String get stateOpen => 'مفتوحة';
  @override
  String get stateClosed => 'مغلقة';
  @override
  String get syncLabel => 'المزامنة';
  @override
  String get syncLive => 'مباشرة (لحظية)';

  @override
  String get widgetLoginRequired => 'سجّل الدخول أولاً';

  @override
  String get profileTitle => 'الملف الشخصي';
  @override
  String get noUser => 'لا يوجد مستخدم';
  @override
  String get loadProfileError => 'تعذّر تحميل الملف';
  @override
  String get apartment => 'رقم الشقة';
  @override
  String get bio => 'نبذة';
  @override
  String get notAddedYet => 'لم يُضف بعد';
  @override
  String get editProfile => 'تعديل الملف';

  @override
  String get saveChangesSuccess => 'تم حفظ التغييرات';
  @override
  String get saveChangesError => 'فشل حفظ التغييرات';
  @override
  String get save => 'حفظ';

  @override
  String get roleAdmin => 'مسؤول';
  @override
  String get roleUser => 'مستخدم';
  @override
  String get statusApproved => 'مقبول';
  @override
  String get statusRejected => 'مرفوض';
  @override
  String get statusPending => 'قيد الانتظار';
  @override
  String get statusUnknown => 'غير معروف';

  @override
  String get unexpectedError => 'حدث خطأ غير متوقع';
  @override
  String connectionError(Object error) => 'خطأ في الاتصال: $error';
  @override
  String signInError(String code) => switch (code) {
        'invalid-email' => 'البريد الإلكتروني غير صحيح',
        'user-disabled' => 'تم تعطيل هذا الحساب',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'البريد الإلكتروني أو كلمة المرور غير صحيحة',
        _ => 'فشل تسجيل الدخول',
      };
  @override
  String registerError(String code) => switch (code) {
        'email-already-in-use' => 'هذا البريد مسجّل بالفعل',
        'invalid-email' => 'البريد الإلكتروني غير صحيح',
        'weak-password' => 'كلمة المرور ضعيفة',
        _ => 'فشل إنشاء الحساب',
      };
}

class _En implements AppStrings {
  const _En();

  @override
  String get appTitle => 'Gate Control';
  @override
  String get languageToggleTooltip => 'العربية';

  @override
  String get loggedOutElsewhereTitle => 'Logged in on another device';
  @override
  String get loggedOutElsewhereBody =>
      'This account is now in use on another device.';

  @override
  String get loginTitle => 'Sign in';
  @override
  String get signInButton => 'Sign in';
  @override
  String get noAccountRegister => "Don't have an account? Register now";

  @override
  String get registerTitle => 'Create account';
  @override
  String get registerButton => 'Register';

  @override
  String get name => 'Name';
  @override
  String get email => 'Email';
  @override
  String get password => 'Password';
  @override
  String get enterName => 'Enter your name';
  @override
  String get emailInvalid => 'Enter a valid email';
  @override
  String get passwordTooShort => 'Password must be at least 6 characters';

  @override
  String get pendingTitle => 'Awaiting approval';
  @override
  String get pendingBody =>
      'Your account was created successfully. An administrator will approve it soon.';
  @override
  String get rejectedTitle => 'Account rejected';
  @override
  String get rejectedBody =>
      'Your account was rejected. Contact the administrator for more information.';

  @override
  String get adminTitle => 'Manage users';
  @override
  String get loadUsersError => 'Failed to load users';
  @override
  String get noUsers => 'No users';
  @override
  String get noName => '(No name)';
  @override
  String get approve => 'Approve';
  @override
  String get reject => 'Reject';
  @override
  String get makeAdmin => 'Make admin';
  @override
  String get removeAdmin => 'Remove admin';
  @override
  String get edit => 'Edit';
  @override
  String get delete => 'Delete';
  @override
  String get cancel => 'Cancel';
  @override
  String get deleteUserTitle => 'Delete user';
  @override
  String deleteUserConfirm(String name) =>
      'Delete "$name"? This action cannot be undone.';
  @override
  String get userDeleted => 'User deleted';
  @override
  String get userDeleteFailed => 'Failed to delete user';

  @override
  String get editUserTitle => 'Edit user';
  @override
  String get enterNameField => 'Enter the name';
  @override
  String get roleLabel => 'Role';
  @override
  String get statusLabel => 'Status';

  @override
  String get gateTitle => 'Gate control';
  @override
  String get profileTooltip => 'Profile';
  @override
  String get lightMode => 'Light mode';
  @override
  String get darkMode => 'Dark mode';
  @override
  String get signOut => 'Sign out';
  @override
  String get connecting => 'Connecting';
  @override
  String get connected => 'Connected';
  @override
  String get disconnected => 'Disconnected';
  @override
  String get gateOpen => 'Gate open';
  @override
  String get gateClosed => 'Gate closed';
  @override
  String get tapToOpen => 'Tap to open';
  @override
  String get tapToClose => 'Tap to close';
  @override
  String get openGate => 'Open gate';
  @override
  String get closeGate => 'Close gate';
  @override
  String get gateOpened => 'Gate opened';
  @override
  String get gateClosedMsg => 'Gate closed';
  @override
  String get systemInfo => 'System info';
  @override
  String get connectionStatusLabel => 'Connection status';
  @override
  String get gateStatusLabel => 'Gate status';
  @override
  String get stateOpen => 'Open';
  @override
  String get stateClosed => 'Closed';
  @override
  String get syncLabel => 'Sync';
  @override
  String get syncLive => 'Live (instant)';

  @override
  String get widgetLoginRequired => 'Sign in first';

  @override
  String get profileTitle => 'Profile';
  @override
  String get noUser => 'No user';
  @override
  String get loadProfileError => 'Failed to load profile';
  @override
  String get apartment => 'Apartment number';
  @override
  String get bio => 'Bio';
  @override
  String get notAddedYet => 'Not added yet';
  @override
  String get editProfile => 'Edit profile';

  @override
  String get saveChangesSuccess => 'Changes saved';
  @override
  String get saveChangesError => 'Failed to save changes';
  @override
  String get save => 'Save';

  @override
  String get roleAdmin => 'Admin';
  @override
  String get roleUser => 'User';
  @override
  String get statusApproved => 'Approved';
  @override
  String get statusRejected => 'Rejected';
  @override
  String get statusPending => 'Pending';
  @override
  String get statusUnknown => 'Unknown';

  @override
  String get unexpectedError => 'An unexpected error occurred';
  @override
  String connectionError(Object error) => 'Connection error: $error';
  @override
  String signInError(String code) => switch (code) {
        'invalid-email' => 'Invalid email',
        'user-disabled' => 'This account has been disabled',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'Incorrect email or password',
        _ => 'Sign-in failed',
      };
  @override
  String registerError(String code) => switch (code) {
        'email-already-in-use' => 'This email is already registered',
        'invalid-email' => 'Invalid email',
        'weak-password' => 'Password is too weak',
        _ => 'Account creation failed',
      };
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'ar' || locale.languageCode == 'en';

  @override
  Future<AppStrings> load(Locale locale) async =>
      locale.languageCode == 'en' ? const _En() : const _Ar();

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}
