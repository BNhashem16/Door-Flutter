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

  // Verify email (4-digit OTP)
  String get verifyEmailTitle;
  String verifyEmailBody(String email);
  String get verifyEmailWaiting;
  String get verifyEmailResend;
  String verifyEmailResendIn(int seconds);
  String get verifyEmailResent;
  String get verifyEmailCheckButton;
  String get verifyEmailNotYet;
  String get verifyEmailVerified;
  String get enterCodeHint;
  String get otpSentToast;
  String get otpSendFailed;
  String get accountCreated;
  String otpWrong(int attemptsLeft);
  String get otpExpired;
  String get otpTooManyAttempts;
  String otpCooldown(int seconds);
  String get verifyCodeButton;
  String get verifyEmailSpamHint;
  String get openEmailAppButton;
  String get openEmailAppFailed;

  // Forgot password (signed out) + change password (signed in)
  String get forgotPassword;
  String get forgotPasswordTitle;
  String get forgotPasswordBody;
  String get sendResetLinkButton;
  String get resetLinkSent;
  String get newPassword;
  String get confirmPassword;
  String get passwordsDoNotMatch;
  String get changePassword;
  String get changePasswordTitle;
  String get currentPassword;
  String get updatePasswordButton;
  String get passwordChanged;
  String changePasswordError(String code);

  // Pending / rejected
  String get pendingTitle;
  String get pendingBody;
  String get rejectedTitle;
  String get rejectedBody;
  String get accessCodeLabel;
  String get activateCodeButton;
  String get requestCodeButton;
  String get codeRequested;
  String get codeRequestError;
  String get codeInvalid;
  String get codeExpired;
  String get codeUsed;
  String get codeNetworkError;
  // Admin: issue access code
  String get issueCodeButton;
  String get issueCodeTitle;
  String issueCodeBody(String code);
  String get issueCodeError;
  String get copyCode;
  String get codeCopied;

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

  // Gate device offline (heartbeat stale)
  String get gateOfflineTitle;
  String get gateOfflineBody;
  String gateLastSeen(String when);

  // Activity / last-open
  String greeting(String name);
  String get activityTitle;
  String get lastOpenLabel;
  String get opensTodayLabel;
  String get neverOpened;
  String get timeJustNow;
  String timeMinutesAgo(int n);
  String timeHoursAgo(int n);
  String timeDaysAgo(int n);

  // Home-screen widget
  String get widgetLoginRequired;

  // Gate access logs
  String get logsTitle;
  String get logsLoadError;
  String get noLogs;
  String get logActionOpen;
  String get logActionClose;
  String get logSourceApp;
  String get logSourceWidget;
  String get logSourceGuest;
  String get myLogsButton;
  String get allLogsTooltip;

  // Guest passes
  String get guestPassesTitle;
  String get guestPassesSubtitle;
  String get guestPassesEmpty;
  String get guestPassesEmptyHint;
  String get guestPassLoadError;
  String get newGuestPass;
  String get guestStatusActive;
  String get guestStatusExpired;
  String get guestStatusRevoked;
  String get guestStatusUsedUp;
  String guestValidUntil(String when);
  String get guestUsesUnlimited;
  String guestUsesLeft(int n);
  String get guestShare;
  String get guestQr;
  String get guestRevoke;
  String get guestCopyLink;
  String get guestLinkCopied;
  String get guestRevokeTitle;
  String guestRevokeConfirm(String label);
  String get guestRevoked;
  String get guestDeleteTitle;
  String guestDeleteConfirm(String label);
  String get guestDeleted;
  String get guestDeleteAllTitle;
  String get guestDeleteAllConfirm;
  String get guestDeleteAll;
  String get guestAllDeleted;
  // Create sheet
  String get guestLabelLabel;
  String get guestLabelHint;
  String get guestLabelRequired;
  String get guestDurationLabel;
  String get guestDur1h;
  String get guestDur3h;
  String get guestDurTonight;
  String get guestDurCustom;
  String guestHours(int n);
  String get guestCustomHoursLabel;
  String get guestMaxUsesLabel;
  String get guestUsesOnce;
  String get guestUsesFive;
  String get guestUsesUnlimitedOption;
  String get createGuestPass;
  // Share view
  String get guestShareTitle;
  String get guestShareHint;
  String guestShareMessage(String label, String url);
  String get guestClose;

  // Profile
  String get profileTitle;
  String get noUser;
  String get loadProfileError;
  String get apartment;
  String get bio;
  String get notAddedYet;
  String get editProfile;

  // Biometric lock
  String get biometricLockLabel;
  String get biometricLockSubtitle;
  String get biometricUnavailable;
  String get biometricEnableScanReason;
  String get biometricUnlockReason;
  String get signInWithFingerprint;
  String get lockTitle;
  String get unlockWithFingerprint;
  String get usePasswordInstead;
  String get wrongPassword;
  String get enableBiometricPasswordPrompt;
  String get confirm;

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

  // Connectivity (offline blocker)
  String get offlineTitle;
  String get offlineBody;
  String get retry;

  // Recurring guest passes
  String get guestRecurringToggle;
  String get guestRecurringHint;
  String get guestWeekdaysLabel;
  String get guestWeekdaysRequired;
  String get guestWindowLabel;
  String get guestWindowFrom;
  String get guestWindowTo;
  String get guestEndDateLabel;
  String guestRepeatUntil(String when);

  /// Short weekday name for `DateTime.weekday` (1 = Mon … 7 = Sun).
  String weekdayShort(int weekday);

  // Gate-open fingerprint guard
  String get gateBiometricLabel;
  String get gateBiometricSubtitle;
  String get gateBiometricReason;
  String get gateBiometricFailed;

  // Analytics dashboard
  String get analyticsTitle;
  String get analyticsButton;
  String get analyticsLast7;
  String get analyticsLast30;
  String get analyticsTotalOpens;
  String get analyticsBusiestDay;
  String get analyticsDailyAvg;
  String get analyticsOpensPerDay;
  String get analyticsBySource;
  String get analyticsNoData;

  // Audit log (admin action history)
  String get auditLogTooltip;
  String get auditLogTitle;
  String get auditLogEmpty;
  String auditAction(String action);

  // Notification center
  String get notificationsTitle;
  String get notificationsEmpty;
  String get notificationsMarkAllRead;
  String get notificationsClear;
  String get notificationsClearTitle;
  String get notificationsClearConfirm;

  // Announcements (admin broadcast)
  String get announcementTitle;
  String get announcementSubject;
  String get announcementSubjectHint;
  String get announcementBody;
  String get announcementBodyHint;
  String get announcementSend;
  String get announcementSent;
  String get announcementError;

  // Doorbell (ring resident)
  String get ringTitle;
  String get ringBody;
  String get ringOpen;
  String get ringIgnore;

  // Notification preferences
  String get notifPrefsTitle;
  String get notifPrefsButton;
  String get notifPrefGuest;
  String get notifPrefBroadcast;
  String get notifPrefRing;

  // My reports + ticket reply
  String get myReportsTitle;
  String get myReportsButton;
  String get myReportsEmpty;
  String get ticketReply;
  String get ticketReplyHint;
  String get ticketReplySend;
  String get ticketAdminReply;

  // Delete account (self-service)
  String get deleteAccountButton;
  String get deleteAccountTitle;
  String get deleteAccountWarning;
  String get deleteAccountPasswordHint;
  String get deleteAccountConfirm;
  String get deleteAccountError;
  String get deleteAccountWrongPassword;

  // Support / report an issue
  String get supportTitle;
  String get supportInboxTooltip;
  String get supportEmpty;
  String get supportLoadError;
  String get supportOpen;
  String get supportResolved;
  String get supportMarkResolved;
  String get supportReopen;
  String get reportIssueTitle;
  String get reportIssueButton;
  String get reportIssueHint;
  String get reportIssueRequired;
  String get reportIssueSend;
  String get reportIssueSent;
  String get reportIssueError;
  String get reportCategoryLabel;
  String get reportCategoryBug;
  String get reportCategorySuggestion;
  String get reportCategoryOther;

  // Onboarding
  String get onboardingSkip;
  String get onboardingNext;
  String get onboardingStart;
  String get ob1Title;
  String get ob1Body;
  String get ob2Title;
  String get ob2Body;
  String get ob3Title;
  String get ob3Body;

  // App update (in-app version gate)
  String get updateRequiredTitle;
  String get updateRequiredBody;
  String get updateAvailableTitle;
  String get updateAvailableBody;
  String get updateDownloadButton;
  String get updateLaterButton;
  String get updateOpenFailed;

  // Drawer (sidebar)
  String get drawerFeaturesSection;
  String get drawerSettingsSection;
  String get drawerAboutSection;
  String get drawerHome;

  // Legal + about developer
  String get privacyPolicyTitle;
  String get termsTitle;
  String get aboutDeveloperTitle;
  String get developerName;
  String get developerRole;
  String get aboutContactHint;
  String get aboutCallAction;
  String get aboutEmailAction;
  String get aboutLaunchFailed;

  // Admin user detail (per-user account view)
  String get adminUserDetailTitle;
  String get userOverviewTitle;
  String get joinedLabel;
  String get activeDeviceLabel;
  String get deviceBound;
  String get deviceNone;
  String get totalClosesLabel;
  String get guestPassesCountLabel;
  String get guestArrivalsTitle;
  String get guestArrivalsEmpty;
  String guestArrivalsCount(int n);
  String get recentActivityTitle;
  String get viewFullLog;
  String get emailVerifiedLabel;
  String get yesLabel;
  String get noLabel;

  // Admin: search / filter / bulk actions / resident directory
  String get adminTabUsers;
  String get adminTabDirectory;
  String get adminSearchHint;
  String get filterAll;
  String get noMatchingResults;
  String get unspecifiedUnit;
  String unitResidents(int n);
  String selectedCount(int n);
  String get bulkApprove;
  String get bulkSuspend;
  String get bulkClear;
  String get bulkApproveTitle;
  String bulkApproveConfirm(int n);
  String get bulkSuspendTitle;
  String bulkSuspendConfirm(int n);
  String bulkApplied(int n);
  String get bulkFailed;

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
  String get verifyEmailTitle => 'تأكيد البريد الإلكتروني';
  @override
  String verifyEmailBody(String email) =>
      'أرسلنا رمزًا مكوّنًا من 4 أرقام إلى\n$email\nأدخل الرمز أدناه لتفعيل حسابك.';
  @override
  String get verifyEmailWaiting => 'بانتظار التأكيد…';
  @override
  String get verifyEmailResend => 'إعادة إرسال الرمز';
  @override
  String verifyEmailResendIn(int seconds) => 'إعادة الإرسال خلال $seconds ث';
  @override
  String get verifyEmailResent => 'تم إرسال الرمز';
  @override
  String get verifyEmailCheckButton => 'تأكيد';
  @override
  String get verifyEmailNotYet => 'لم يتم تأكيد البريد بعد';
  @override
  String get verifyEmailVerified => 'تم تأكيد بريدك بنجاح';
  @override
  String get enterCodeHint => 'أدخل الرمز المكوّن من 4 أرقام';
  @override
  String get otpSentToast => 'تم إرسال الرمز إلى بريدك';
  @override
  String get otpSendFailed => 'تعذّر إرسال الرمز. تحقّق من بريدك وحاول مجددًا';
  @override
  String get accountCreated => 'تم إنشاء حسابك بنجاح';
  @override
  String otpWrong(int attemptsLeft) =>
      'رمز غير صحيح. المحاولات المتبقية: $attemptsLeft';
  @override
  String get otpExpired => 'انتهت صلاحية الرمز. أعد طلب رمز جديد';
  @override
  String get otpTooManyAttempts => 'محاولات كثيرة جدًا. أعد طلب رمز جديد';
  @override
  String otpCooldown(int seconds) => 'انتظر $seconds ث قبل إعادة الإرسال';
  @override
  String get verifyCodeButton => 'تأكيد الرمز';
  @override
  String get verifyEmailSpamHint =>
      'وصلت الرسالة؟ رائع. إن لم تجدها خلال دقيقة أو دقيقتين، تحقّق من مجلد الرسائل غير المرغوب فيها (Spam) — قد تصل الرسالة هناك أحيانًا، وهذا أمر طبيعي تمامًا.';
  @override
  String get openEmailAppButton => 'فتح تطبيق البريد';
  @override
  String get openEmailAppFailed =>
      'لم يتم العثور على تطبيق بريد على هذا الجهاز';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';
  @override
  String get forgotPasswordTitle => 'إعادة تعيين كلمة المرور';
  @override
  String get forgotPasswordBody =>
      'أدخل بريدك الإلكتروني وسنرسل لك رابطًا لإعادة تعيين كلمة المرور.';
  @override
  String get sendResetLinkButton => 'إرسال الرابط';
  @override
  String get resetLinkSent =>
      'إذا كان هذا البريد مسجّلاً، فسيصلك رابط إعادة تعيين كلمة المرور.';
  @override
  String get newPassword => 'كلمة المرور الجديدة';
  @override
  String get confirmPassword => 'تأكيد كلمة المرور';
  @override
  String get passwordsDoNotMatch => 'كلمتا المرور غير متطابقتين';
  @override
  String get changePassword => 'تغيير كلمة المرور';
  @override
  String get changePasswordTitle => 'تغيير كلمة المرور';
  @override
  String get currentPassword => 'كلمة المرور الحالية';
  @override
  String get updatePasswordButton => 'تحديث كلمة المرور';
  @override
  String get passwordChanged => 'تم تغيير كلمة المرور بنجاح';
  @override
  String changePasswordError(String code) => switch (code) {
        'wrong-password' ||
        'invalid-credential' =>
          'كلمة المرور الحالية غير صحيحة',
        'weak-password' => 'كلمة المرور الجديدة ضعيفة',
        'requires-recent-login' => 'يرجى تسجيل الدخول مجددًا ثم المحاولة',
        _ => 'تعذّر تغيير كلمة المرور',
      };

  @override
  String get pendingTitle => 'بانتظار التفعيل';
  @override
  String get pendingBody =>
      'تم إنشاء حسابك. أدخل رمز الدخول الذي حصلت عليه من إدارة المبنى لتفعيل حسابك.';
  @override
  String get rejectedTitle => 'تم رفض الحساب';
  @override
  String get rejectedBody =>
      'تم رفض حسابك. تواصل مع المسؤول لمزيد من المعلومات.';
  @override
  String get accessCodeLabel => 'رمز الدخول';
  @override
  String get activateCodeButton => 'تفعيل';
  @override
  String get requestCodeButton => 'اطلب رمز دخول';
  @override
  String get codeRequested => 'تم إرسال طلبك. سيصلك رمز قريبًا من الإدارة.';
  @override
  String get codeRequestError => 'تعذّر إرسال الطلب. حاول مرة أخرى.';
  @override
  String get codeInvalid => 'رمز غير صحيح.';
  @override
  String get codeExpired => 'انتهت صلاحية الرمز. اطلب رمزًا جديدًا.';
  @override
  String get codeUsed => 'تم استخدام هذا الرمز من قبل.';
  @override
  String get codeNetworkError =>
      'تعذّر الاتصال. تأكد من الإنترنت وحاول مجددًا.';
  @override
  String get issueCodeButton => 'إصدار رمز';
  @override
  String get issueCodeTitle => 'رمز الدخول';
  @override
  String issueCodeBody(String code) =>
      'الرمز: $code\nصالح لمدة ٢٤ ساعة ولمرة واحدة. سلّمه للمستخدم لتفعيل حسابه.';
  @override
  String get issueCodeError => 'تعذّر إصدار الرمز. حاول مرة أخرى.';
  @override
  String get copyCode => 'نسخ الرمز';
  @override
  String get codeCopied => 'تم نسخ الرمز';

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
  String get gateOfflineTitle => 'البوابة غير متصلة';
  @override
  String get gateOfflineBody =>
      'جهاز التحكم في البوابة لا يستجيب حاليًا. قد لا تعمل أوامر الفتح — تواصل مع إدارة المبنى.';
  @override
  String gateLastSeen(String when) => 'آخر اتصال بالجهاز: $when';

  @override
  String greeting(String name) => 'أهلاً، $name';
  @override
  String get activityTitle => 'النشاط';
  @override
  String get lastOpenLabel => 'آخر فتح للباب';
  @override
  String get opensTodayLabel => 'مرات الفتح اليوم';
  @override
  String get neverOpened => 'لا يوجد بعد';
  @override
  String get timeJustNow => 'الآن';
  @override
  String timeMinutesAgo(int n) => 'منذ $n دقيقة';
  @override
  String timeHoursAgo(int n) => 'منذ $n ساعة';
  @override
  String timeDaysAgo(int n) => 'منذ $n يوم';

  @override
  String get widgetLoginRequired => 'سجّل الدخول أولاً';

  @override
  String get logsTitle => 'سجل الوصول';
  @override
  String get logsLoadError => 'تعذّر تحميل السجل';
  @override
  String get noLogs => 'لا يوجد سجل بعد';
  @override
  String get logActionOpen => 'فتح';
  @override
  String get logActionClose => 'إغلاق';
  @override
  String get logSourceApp => 'من التطبيق';
  @override
  String get logSourceWidget => 'من الأداة';
  @override
  String get logSourceGuest => 'من زائر';
  @override
  String get myLogsButton => 'سجل وصولي';
  @override
  String get allLogsTooltip => 'سجل وصول الجميع';

  @override
  String get guestPassesTitle => 'تصاريح الزوار';
  @override
  String get guestPassesSubtitle => 'افتح البوابة لزائر برابط مؤقت';
  @override
  String get guestPassesEmpty => 'لا توجد تصاريح بعد';
  @override
  String get guestPassesEmptyHint => 'أنشئ تصريحًا مؤقتًا لزائرك';
  @override
  String get guestPassLoadError => 'تعذّر تحميل التصاريح';
  @override
  String get newGuestPass => 'تصريح جديد';
  @override
  String get guestStatusActive => 'فعّال';
  @override
  String get guestStatusExpired => 'منتهٍ';
  @override
  String get guestStatusRevoked => 'ملغى';
  @override
  String get guestStatusUsedUp => 'مُستخدم';
  @override
  String guestValidUntil(String when) => 'صالح حتى $when';
  @override
  String get guestUsesUnlimited => 'فتح غير محدود';
  @override
  String guestUsesLeft(int n) => 'المتبقي $n مرة';
  @override
  String get guestShare => 'مشاركة';
  @override
  String get guestQr => 'رمز QR';
  @override
  String get guestRevoke => 'إلغاء التصريح';
  @override
  String get guestCopyLink => 'نسخ الرابط';
  @override
  String get guestLinkCopied => 'تم نسخ الرابط';
  @override
  String get guestRevokeTitle => 'إلغاء التصريح';
  @override
  String guestRevokeConfirm(String label) =>
      'إلغاء تصريح «$label»؟ لن يعمل الرابط بعد ذلك.';
  @override
  String get guestRevoked => 'تم إلغاء التصريح';
  @override
  String get guestDeleteTitle => 'حذف التصريح';
  @override
  String guestDeleteConfirm(String label) =>
      'حذف تصريح «$label» نهائيًا؟ لا يمكن التراجع عن هذا الإجراء.';
  @override
  String get guestDeleted => 'تم حذف التصريح';
  @override
  String get guestDeleteAllTitle => 'حذف كل التصاريح';
  @override
  String get guestDeleteAllConfirm =>
      'سيتم حذف جميع التصاريح نهائيًا وستتوقف كل الروابط التي شاركتها. متابعة؟';
  @override
  String get guestDeleteAll => 'حذف الكل';
  @override
  String get guestAllDeleted => 'تم حذف جميع التصاريح';
  @override
  String get guestLabelLabel => 'اسم الزائر';
  @override
  String get guestLabelHint => 'مثال: أخويا، الدليفري';
  @override
  String get guestLabelRequired => 'أدخل اسم الزائر';
  @override
  String get guestDurationLabel => 'المدة';
  @override
  String get guestDur1h => 'ساعة';
  @override
  String get guestDur3h => '3 ساعات';
  @override
  String get guestDurTonight => 'حتى الليل';
  @override
  String get guestDurCustom => 'مخصص';
  @override
  String guestHours(int n) => '$n ساعة';
  @override
  String get guestCustomHoursLabel => 'عدد الساعات';
  @override
  String get guestMaxUsesLabel => 'عدد مرات الفتح';
  @override
  String get guestUsesOnce => 'مرة واحدة';
  @override
  String get guestUsesFive => '5 مرات';
  @override
  String get guestUsesUnlimitedOption => 'غير محدود';
  @override
  String get createGuestPass => 'إنشاء التصريح';
  @override
  String get guestShareTitle => 'شارك التصريح';
  @override
  String get guestShareHint => 'أرسل الرابط للزائر عبر واتساب أو الرسائل';
  @override
  String guestShareMessage(String label, String url) =>
      'تصريح دخول مؤقت للبوابة ($label):\n$url';
  @override
  String get guestClose => 'إغلاق';

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
  String get biometricLockLabel => 'قفل البصمة';
  @override
  String get biometricLockSubtitle => 'افتح التطبيق ببصمتك';
  @override
  String get biometricUnavailable => 'لا توجد بصمة مسجّلة على هذا الجهاز';
  @override
  String get biometricEnableScanReason => 'أكّد بصمتك لتفعيل القفل';
  @override
  String get biometricUnlockReason => 'افتح التطبيق ببصمتك';
  @override
  String get signInWithFingerprint => 'الدخول بالبصمة';
  @override
  String get lockTitle => 'التطبيق مقفول';
  @override
  String get unlockWithFingerprint => 'افتح بالبصمة';
  @override
  String get usePasswordInstead => 'استخدم كلمة المرور';
  @override
  String get wrongPassword => 'كلمة المرور غير صحيحة';
  @override
  String get enableBiometricPasswordPrompt => 'أدخل كلمة المرور لتفعيل القفل';
  @override
  String get confirm => 'تأكيد';

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
  String get offlineTitle => 'لا يوجد اتصال بالإنترنت';
  @override
  String get offlineBody =>
      'تحقّق من اتصالك بالشبكة وحاول مرة أخرى. التطبيق متوقف حتى يعود الاتصال.';
  @override
  String get retry => 'إعادة المحاولة';

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

  @override
  String get guestRecurringToggle => 'تصريح متكرر (أسبوعي)';
  @override
  String get guestRecurringHint => 'صالح في أيام وأوقات محددة كل أسبوع';
  @override
  String get guestWeekdaysLabel => 'أيام الأسبوع';
  @override
  String get guestWeekdaysRequired => 'اختر يومًا واحدًا على الأقل';
  @override
  String get guestWindowLabel => 'وقت الصلاحية';
  @override
  String get guestWindowFrom => 'من';
  @override
  String get guestWindowTo => 'إلى';
  @override
  String get guestEndDateLabel => 'يتكرر حتى تاريخ';
  @override
  String guestRepeatUntil(String when) => 'يتكرر حتى $when';
  @override
  String weekdayShort(int weekday) => const [
        'إثنين',
        'ثلاثاء',
        'أربعاء',
        'خميس',
        'جمعة',
        'سبت',
        'أحد',
      ][(weekday - 1).clamp(0, 6)];

  @override
  String get gateBiometricLabel => 'تأكيد بالبصمة قبل فتح البوابة';
  @override
  String get gateBiometricSubtitle => 'اطلب بصمتك في كل مرة تفتح فيها البوابة';
  @override
  String get gateBiometricReason => 'أكّد بصمتك لفتح البوابة';
  @override
  String get gateBiometricFailed => 'فشل التحقق بالبصمة';

  @override
  String get analyticsTitle => 'إحصاءات الوصول';
  @override
  String get analyticsButton => 'الإحصاءات';
  @override
  String get analyticsLast7 => 'آخر 7 أيام';
  @override
  String get analyticsLast30 => 'آخر 30 يوم';
  @override
  String get analyticsTotalOpens => 'إجمالي مرات الفتح';
  @override
  String get analyticsBusiestDay => 'أكثر يوم نشاطًا';
  @override
  String get analyticsDailyAvg => 'المتوسط اليومي';
  @override
  String get analyticsOpensPerDay => 'مرات الفتح يوميًا';
  @override
  String get analyticsBySource => 'حسب المصدر';
  @override
  String get analyticsNoData => 'لا توجد بيانات بعد';

  @override
  String get auditLogTooltip => 'سجل الإجراءات';
  @override
  String get auditLogTitle => 'سجل إجراءات المسؤولين';
  @override
  String get auditLogEmpty => 'لا توجد إجراءات بعد';
  @override
  String auditAction(String action) => switch (action) {
        'approve' => 'وافق على',
        'reject' => 'رفض',
        'make_admin' => 'عيّن كمسؤول',
        'remove_admin' => 'أزال صلاحية المسؤول عن',
        'edit_user' => 'عدّل بيانات',
        'delete_user' => 'حذف',
        'resolve_ticket' => 'حلّ بلاغًا من',
        _ => action,
      };
  @override
  String get notificationsTitle => 'الإشعارات';
  @override
  String get notificationsEmpty => 'لا توجد إشعارات';
  @override
  String get notificationsMarkAllRead => 'تحديد الكل كمقروء';
  @override
  String get notificationsClear => 'مسح الكل';
  @override
  String get notificationsClearTitle => 'مسح الإشعارات';
  @override
  String get notificationsClearConfirm => 'هل تريد حذف كل الإشعارات؟';
  @override
  String get announcementTitle => 'إعلان للسكان';
  @override
  String get announcementSubject => 'العنوان';
  @override
  String get announcementSubjectHint => 'اكتب عنوان الإعلان';
  @override
  String get announcementBody => 'نص الإعلان';
  @override
  String get announcementBodyHint => 'اكتب نص الإعلان';
  @override
  String get announcementSend => 'إرسال للجميع';
  @override
  String get announcementSent => 'تم إرسال الإعلان';
  @override
  String get announcementError => 'تعذّر إرسال الإعلان';
  @override
  String get ringTitle => 'طلب فتح الباب';
  @override
  String get ringBody => 'يوجد زائر عند البوابة يطلب الدخول. هل تفتح؟';
  @override
  String get ringOpen => 'افتح';
  @override
  String get ringIgnore => 'تجاهل';
  @override
  String get notifPrefsTitle => 'إعدادات الإشعارات';
  @override
  String get notifPrefsButton => 'إعدادات الإشعارات';
  @override
  String get notifPrefGuest => 'إشعار استخدام تصريح ضيف';
  @override
  String get notifPrefBroadcast => 'إعلانات المبنى';
  @override
  String get notifPrefRing => 'طلبات فتح الباب';
  @override
  String get myReportsTitle => 'بلاغاتي';
  @override
  String get myReportsButton => 'بلاغاتي';
  @override
  String get myReportsEmpty => 'لم ترسل أي بلاغ بعد';
  @override
  String get ticketReply => 'رد';
  @override
  String get ticketReplyHint => 'اكتب ردك للمستخدم';
  @override
  String get ticketReplySend => 'إرسال الرد';
  @override
  String get ticketAdminReply => 'رد الإدارة';
  @override
  String get deleteAccountButton => 'حذف الحساب';
  @override
  String get deleteAccountTitle => 'حذف الحساب نهائيًا';
  @override
  String get deleteAccountWarning =>
      'سيتم حذف حسابك وكل بياناتك نهائيًا ولا يمكن التراجع. أدخل كلمة المرور للتأكيد.';
  @override
  String get deleteAccountPasswordHint => 'كلمة المرور';
  @override
  String get deleteAccountConfirm => 'حذف';
  @override
  String get deleteAccountError => 'تعذّر حذف الحساب';
  @override
  String get deleteAccountWrongPassword => 'كلمة المرور غير صحيحة';
  @override
  String get supportTitle => 'بلاغات المستخدمين';
  @override
  String get supportInboxTooltip => 'البلاغات';
  @override
  String get supportEmpty => 'لا توجد بلاغات';
  @override
  String get supportLoadError => 'تعذّر تحميل البلاغات';
  @override
  String get supportOpen => 'مفتوح';
  @override
  String get supportResolved => 'محلول';
  @override
  String get supportMarkResolved => 'تعليم كمحلول';
  @override
  String get supportReopen => 'إعادة فتح';
  @override
  String get reportIssueTitle => 'إبلاغ عن مشكلة';
  @override
  String get reportIssueButton => 'إبلاغ عن مشكلة';
  @override
  String get reportIssueHint => 'اشرح المشكلة أو اقترح تحسينًا…';
  @override
  String get reportIssueRequired => 'اكتب رسالتك';
  @override
  String get reportIssueSend => 'إرسال';
  @override
  String get reportIssueSent => 'تم إرسال بلاغك. شكرًا لك';
  @override
  String get reportIssueError => 'تعذّر إرسال البلاغ';
  @override
  String get reportCategoryLabel => 'النوع';
  @override
  String get reportCategoryBug => 'مشكلة';
  @override
  String get reportCategorySuggestion => 'اقتراح';
  @override
  String get reportCategoryOther => 'أخرى';

  @override
  String get onboardingSkip => 'تخطّي';
  @override
  String get onboardingNext => 'التالي';
  @override
  String get onboardingStart => 'ابدأ';
  @override
  String get ob1Title => 'تحكّم في بوابتك';
  @override
  String get ob1Body => 'افتح وأغلق البوابة بضغطة واحدة من أي مكان.';
  @override
  String get ob2Title => 'تصاريح الزوار';
  @override
  String get ob2Body => 'أنشئ رابطًا مؤقتًا ليدخل زائرك دون الحاجة لتطبيق.';
  @override
  String get ob3Title => 'أمان ببصمتك';
  @override
  String get ob3Body => 'اقفل التطبيق وافتح البوابة ببصمتك لمزيد من الأمان.';
  @override
  String get updateRequiredTitle => 'تحديث مطلوب';
  @override
  String get updateRequiredBody =>
      'هذه النسخة لم تعد مدعومة. حمّل التحديث الجديد — سيتم تثبيته فوق النسخة الحالية مباشرةً دون حذف التطبيق أو فقدان بياناتك.';
  @override
  String get updateAvailableTitle => 'تحديث جديد متاح';
  @override
  String get updateAvailableBody =>
      'نسخة أحدث من التطبيق متاحة الآن. حمّلها لتحصل على آخر التحسينات.';
  @override
  String get updateDownloadButton => 'تحميل التحديث';
  @override
  String get updateLaterButton => 'لاحقًا';
  @override
  String get updateOpenFailed => 'تعذّر فتح رابط التحديث';
  @override
  String get drawerFeaturesSection => 'المميزات';
  @override
  String get drawerSettingsSection => 'الإعدادات';
  @override
  String get drawerAboutSection => 'حول التطبيق';
  @override
  String get drawerHome => 'الرئيسية';
  @override
  String get privacyPolicyTitle => 'سياسة الخصوصية';
  @override
  String get termsTitle => 'الشروط والأحكام';
  @override
  String get aboutDeveloperTitle => 'عن المطور';
  @override
  String get developerName => 'أحمد هاشم';
  @override
  String get developerRole => 'مطور التطبيق';
  @override
  String get aboutContactHint => 'لأي استفسار أو مشكلة، تواصل مباشرةً:';
  @override
  String get aboutCallAction => 'اتصال';
  @override
  String get aboutEmailAction => 'مراسلة بالبريد';
  @override
  String get aboutLaunchFailed => 'تعذّر فتح التطبيق المطلوب';

  @override
  String get adminUserDetailTitle => 'تفاصيل المستخدم';
  @override
  String get userOverviewTitle => 'نظرة عامة';
  @override
  String get joinedLabel => 'تاريخ الانضمام';
  @override
  String get activeDeviceLabel => 'الجهاز النشط';
  @override
  String get deviceBound => 'مربوط بجهاز';
  @override
  String get deviceNone => 'لا يوجد';
  @override
  String get totalClosesLabel => 'إجمالي مرات الإغلاق';
  @override
  String get guestPassesCountLabel => 'تصاريح الزوار';
  @override
  String get guestArrivalsTitle => 'سجل الوصول';
  @override
  String get guestArrivalsEmpty => 'لم يصل أحد بعد';
  @override
  String guestArrivalsCount(int n) => 'عدد مرات الوصول: $n';
  @override
  String get recentActivityTitle => 'آخر النشاط';
  @override
  String get viewFullLog => 'عرض السجل كاملاً';
  @override
  String get emailVerifiedLabel => 'تأكيد البريد';
  @override
  String get yesLabel => 'نعم';
  @override
  String get noLabel => 'لا';

  @override
  String get adminTabUsers => 'المستخدمون';
  @override
  String get adminTabDirectory => 'دليل السكان';
  @override
  String get adminSearchHint => 'ابحث بالاسم أو البريد أو الشقة';
  @override
  String get filterAll => 'الكل';
  @override
  String get noMatchingResults => 'لا توجد نتائج مطابقة';
  @override
  String get unspecifiedUnit => 'شقة غير محددة';
  @override
  String unitResidents(int n) => '$n ساكن';
  @override
  String selectedCount(int n) => 'تم تحديد $n';
  @override
  String get bulkApprove => 'موافقة على المحدد';
  @override
  String get bulkSuspend => 'تعليق المحدد';
  @override
  String get bulkClear => 'إلغاء التحديد';
  @override
  String get bulkApproveTitle => 'موافقة جماعية';
  @override
  String bulkApproveConfirm(int n) => 'الموافقة على $n مستخدم؟';
  @override
  String get bulkSuspendTitle => 'تعليق جماعي';
  @override
  String bulkSuspendConfirm(int n) => 'تعليق (رفض) $n مستخدم؟';
  @override
  String bulkApplied(int n) => 'تم تحديث $n مستخدم';
  @override
  String get bulkFailed => 'تعذّر تنفيذ الإجراء الجماعي';
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
  String get verifyEmailTitle => 'Verify your email';
  @override
  String verifyEmailBody(String email) =>
      'We sent a 4-digit code to\n$email\nEnter the code below to activate your account.';
  @override
  String get verifyEmailWaiting => 'Waiting for confirmation…';
  @override
  String get verifyEmailResend => 'Resend code';
  @override
  String verifyEmailResendIn(int seconds) => 'Resend in ${seconds}s';
  @override
  String get verifyEmailResent => 'Code sent';
  @override
  String get verifyEmailCheckButton => 'Verify';
  @override
  String get verifyEmailNotYet => 'Email not verified yet';
  @override
  String get verifyEmailVerified => 'Your email has been verified';
  @override
  String get enterCodeHint => 'Enter the 4-digit code';
  @override
  String get otpSentToast => 'Code sent to your email';
  @override
  String get otpSendFailed =>
      'Could not send the code. Check your email and try again';
  @override
  String get accountCreated => 'Your account has been created';
  @override
  String otpWrong(int attemptsLeft) =>
      'Wrong code. Attempts left: $attemptsLeft';
  @override
  String get otpExpired => 'The code expired. Request a new one';
  @override
  String get otpTooManyAttempts => 'Too many attempts. Request a new code';
  @override
  String otpCooldown(int seconds) => 'Wait ${seconds}s before resending';
  @override
  String get verifyCodeButton => 'Verify code';
  @override
  String get verifyEmailSpamHint =>
      "Got the email? Great. If it doesn't arrive within a minute or two, check your Spam folder — messages occasionally land there, and that's completely normal.";
  @override
  String get openEmailAppButton => 'Open email app';
  @override
  String get openEmailAppFailed => 'No email app found on this device';

  @override
  String get forgotPassword => 'Forgot password?';
  @override
  String get forgotPasswordTitle => 'Reset password';
  @override
  String get forgotPasswordBody =>
      "Enter your email and we'll send you a link to reset your password.";
  @override
  String get sendResetLinkButton => 'Send link';
  @override
  String get resetLinkSent =>
      'If that email is registered, a password reset link is on its way.';
  @override
  String get newPassword => 'New password';
  @override
  String get confirmPassword => 'Confirm password';
  @override
  String get passwordsDoNotMatch => 'Passwords do not match';
  @override
  String get changePassword => 'Change password';
  @override
  String get changePasswordTitle => 'Change password';
  @override
  String get currentPassword => 'Current password';
  @override
  String get updatePasswordButton => 'Update password';
  @override
  String get passwordChanged => 'Password changed successfully';
  @override
  String changePasswordError(String code) => switch (code) {
        'wrong-password' ||
        'invalid-credential' =>
          'Current password is incorrect',
        'weak-password' => 'The new password is too weak',
        'requires-recent-login' => 'Please sign in again, then try',
        _ => 'Could not change the password',
      };

  @override
  String get pendingTitle => 'Awaiting activation';
  @override
  String get pendingBody =>
      'Your account was created. Enter the access code you received from the building admin to activate it.';
  @override
  String get rejectedTitle => 'Account rejected';
  @override
  String get rejectedBody =>
      'Your account was rejected. Contact the administrator for more information.';
  @override
  String get accessCodeLabel => 'Access code';
  @override
  String get activateCodeButton => 'Activate';
  @override
  String get requestCodeButton => 'Request a code';
  @override
  String get codeRequested =>
      'Request sent. The admin will send you a code soon.';
  @override
  String get codeRequestError => 'Could not send the request. Try again.';
  @override
  String get codeInvalid => 'Invalid code.';
  @override
  String get codeExpired => 'The code expired. Request a new one.';
  @override
  String get codeUsed => 'This code was already used.';
  @override
  String get codeNetworkError =>
      'Connection failed. Check your internet and retry.';
  @override
  String get issueCodeButton => 'Issue code';
  @override
  String get issueCodeTitle => 'Access code';
  @override
  String issueCodeBody(String code) =>
      'Code: $code\nValid for 24 hours, single use. Hand it to the user to activate their account.';
  @override
  String get issueCodeError => 'Could not issue the code. Try again.';
  @override
  String get copyCode => 'Copy code';
  @override
  String get codeCopied => 'Code copied';

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
  String get gateOfflineTitle => 'Gate offline';
  @override
  String get gateOfflineBody =>
      "The gate controller isn't responding. Open commands may not work — "
      'contact building management.';
  @override
  String gateLastSeen(String when) => 'Device last seen: $when';

  @override
  String greeting(String name) => 'Hi, $name';
  @override
  String get activityTitle => 'Activity';
  @override
  String get lastOpenLabel => 'Last gate opening';
  @override
  String get opensTodayLabel => 'Opens today';
  @override
  String get neverOpened => 'None yet';
  @override
  String get timeJustNow => 'Just now';
  @override
  String timeMinutesAgo(int n) => '${n}m ago';
  @override
  String timeHoursAgo(int n) => '${n}h ago';
  @override
  String timeDaysAgo(int n) => '${n}d ago';

  @override
  String get widgetLoginRequired => 'Sign in first';

  @override
  String get logsTitle => 'Access log';
  @override
  String get logsLoadError => 'Failed to load the log';
  @override
  String get noLogs => 'No log entries yet';
  @override
  String get logActionOpen => 'Open';
  @override
  String get logActionClose => 'Close';
  @override
  String get logSourceApp => 'From app';
  @override
  String get logSourceWidget => 'From widget';
  @override
  String get logSourceGuest => 'From guest';
  @override
  String get myLogsButton => 'My access log';
  @override
  String get allLogsTooltip => 'All access logs';

  @override
  String get guestPassesTitle => 'Guest passes';
  @override
  String get guestPassesSubtitle => 'Let a visitor in with a temporary link';
  @override
  String get guestPassesEmpty => 'No passes yet';
  @override
  String get guestPassesEmptyHint => 'Create a temporary pass for your visitor';
  @override
  String get guestPassLoadError => 'Failed to load passes';
  @override
  String get newGuestPass => 'New pass';
  @override
  String get guestStatusActive => 'Active';
  @override
  String get guestStatusExpired => 'Expired';
  @override
  String get guestStatusRevoked => 'Revoked';
  @override
  String get guestStatusUsedUp => 'Used up';
  @override
  String guestValidUntil(String when) => 'Valid until $when';
  @override
  String get guestUsesUnlimited => 'Unlimited opens';
  @override
  String guestUsesLeft(int n) => '$n left';
  @override
  String get guestShare => 'Share';
  @override
  String get guestQr => 'QR code';
  @override
  String get guestRevoke => 'Revoke';
  @override
  String get guestCopyLink => 'Copy link';
  @override
  String get guestLinkCopied => 'Link copied';
  @override
  String get guestRevokeTitle => 'Revoke pass';
  @override
  String guestRevokeConfirm(String label) =>
      'Revoke the pass for "$label"? The link will stop working.';
  @override
  String get guestRevoked => 'Pass revoked';
  @override
  String get guestDeleteTitle => 'Delete pass';
  @override
  String guestDeleteConfirm(String label) =>
      'Permanently delete the pass for "$label"? This cannot be undone.';
  @override
  String get guestDeleted => 'Pass deleted';
  @override
  String get guestDeleteAllTitle => 'Delete all passes';
  @override
  String get guestDeleteAllConfirm =>
      'All passes will be permanently deleted and every shared link will stop working. Continue?';
  @override
  String get guestDeleteAll => 'Delete all';
  @override
  String get guestAllDeleted => 'All passes deleted';
  @override
  String get guestLabelLabel => 'Visitor name';
  @override
  String get guestLabelHint => 'e.g. brother, delivery';
  @override
  String get guestLabelRequired => "Enter the visitor's name";
  @override
  String get guestDurationLabel => 'Duration';
  @override
  String get guestDur1h => '1 hour';
  @override
  String get guestDur3h => '3 hours';
  @override
  String get guestDurTonight => 'Until tonight';
  @override
  String get guestDurCustom => 'Custom';
  @override
  String guestHours(int n) => '${n}h';
  @override
  String get guestCustomHoursLabel => 'Hours';
  @override
  String get guestMaxUsesLabel => 'Allowed opens';
  @override
  String get guestUsesOnce => 'Once';
  @override
  String get guestUsesFive => '5 times';
  @override
  String get guestUsesUnlimitedOption => 'Unlimited';
  @override
  String get createGuestPass => 'Create pass';
  @override
  String get guestShareTitle => 'Share pass';
  @override
  String get guestShareHint =>
      'Send the link to your visitor via WhatsApp or SMS';
  @override
  String guestShareMessage(String label, String url) =>
      'Temporary gate access ($label):\n$url';
  @override
  String get guestClose => 'Close';

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
  String get biometricLockLabel => 'Fingerprint lock';
  @override
  String get biometricLockSubtitle => 'Unlock the app with your fingerprint';
  @override
  String get biometricUnavailable => 'No fingerprint enrolled on this device';
  @override
  String get biometricEnableScanReason =>
      'Confirm your fingerprint to enable the lock';
  @override
  String get biometricUnlockReason => 'Unlock the app with your fingerprint';
  @override
  String get signInWithFingerprint => 'Sign in with fingerprint';
  @override
  String get lockTitle => 'App locked';
  @override
  String get unlockWithFingerprint => 'Unlock with fingerprint';
  @override
  String get usePasswordInstead => 'Use password instead';
  @override
  String get wrongPassword => 'Incorrect password';
  @override
  String get enableBiometricPasswordPrompt =>
      'Enter your password to enable the lock';
  @override
  String get confirm => 'Confirm';

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
  String get offlineTitle => 'No internet connection';
  @override
  String get offlineBody =>
      'Check your network connection and try again. The app is paused until '
      "you're back online.";
  @override
  String get retry => 'Retry';

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

  @override
  String get guestRecurringToggle => 'Recurring (weekly)';
  @override
  String get guestRecurringHint => 'Valid on set days and times each week';
  @override
  String get guestWeekdaysLabel => 'Days of week';
  @override
  String get guestWeekdaysRequired => 'Pick at least one day';
  @override
  String get guestWindowLabel => 'Active hours';
  @override
  String get guestWindowFrom => 'From';
  @override
  String get guestWindowTo => 'To';
  @override
  String get guestEndDateLabel => 'Repeat until';
  @override
  String guestRepeatUntil(String when) => 'Repeats until $when';
  @override
  String weekdayShort(int weekday) => const [
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun',
      ][(weekday - 1).clamp(0, 6)];

  @override
  String get gateBiometricLabel => 'Require fingerprint to open the gate';
  @override
  String get gateBiometricSubtitle =>
      'Ask for your fingerprint each time you open the gate';
  @override
  String get gateBiometricReason => 'Confirm your fingerprint to open the gate';
  @override
  String get gateBiometricFailed => 'Fingerprint verification failed';

  @override
  String get analyticsTitle => 'Access analytics';
  @override
  String get analyticsButton => 'Analytics';
  @override
  String get analyticsLast7 => 'Last 7 days';
  @override
  String get analyticsLast30 => 'Last 30 days';
  @override
  String get analyticsTotalOpens => 'Total opens';
  @override
  String get analyticsBusiestDay => 'Busiest day';
  @override
  String get analyticsDailyAvg => 'Daily average';
  @override
  String get analyticsOpensPerDay => 'Opens per day';
  @override
  String get analyticsBySource => 'By source';
  @override
  String get analyticsNoData => 'No data yet';

  @override
  String get auditLogTooltip => 'Audit log';
  @override
  String get auditLogTitle => 'Admin action log';
  @override
  String get auditLogEmpty => 'No actions yet';
  @override
  String auditAction(String action) => switch (action) {
        'approve' => 'approved',
        'reject' => 'rejected',
        'make_admin' => 'made admin',
        'remove_admin' => 'removed admin from',
        'edit_user' => 'edited',
        'delete_user' => 'deleted',
        'resolve_ticket' => 'resolved a report from',
        _ => action,
      };
  @override
  String get notificationsTitle => 'Notifications';
  @override
  String get notificationsEmpty => 'No notifications';
  @override
  String get notificationsMarkAllRead => 'Mark all read';
  @override
  String get notificationsClear => 'Clear all';
  @override
  String get notificationsClearTitle => 'Clear notifications';
  @override
  String get notificationsClearConfirm => 'Delete all notifications?';
  @override
  String get announcementTitle => 'Announcement';
  @override
  String get announcementSubject => 'Title';
  @override
  String get announcementSubjectHint => 'Enter the announcement title';
  @override
  String get announcementBody => 'Message';
  @override
  String get announcementBodyHint => 'Enter the announcement text';
  @override
  String get announcementSend => 'Send to all';
  @override
  String get announcementSent => 'Announcement sent';
  @override
  String get announcementError => 'Failed to send announcement';
  @override
  String get ringTitle => 'Door open request';
  @override
  String get ringBody => 'A visitor at the gate is requesting entry. Open?';
  @override
  String get ringOpen => 'Open';
  @override
  String get ringIgnore => 'Ignore';
  @override
  String get notifPrefsTitle => 'Notification settings';
  @override
  String get notifPrefsButton => 'Notification settings';
  @override
  String get notifPrefGuest => 'Guest pass used';
  @override
  String get notifPrefBroadcast => 'Building announcements';
  @override
  String get notifPrefRing => 'Door open requests';
  @override
  String get myReportsTitle => 'My reports';
  @override
  String get myReportsButton => 'My reports';
  @override
  String get myReportsEmpty => 'You have not sent any reports yet';
  @override
  String get ticketReply => 'Reply';
  @override
  String get ticketReplyHint => 'Write your reply to the user';
  @override
  String get ticketReplySend => 'Send reply';
  @override
  String get ticketAdminReply => 'Admin reply';
  @override
  String get deleteAccountButton => 'Delete account';
  @override
  String get deleteAccountTitle => 'Delete account permanently';
  @override
  String get deleteAccountWarning =>
      'Your account and all data will be permanently deleted and cannot be recovered. Enter your password to confirm.';
  @override
  String get deleteAccountPasswordHint => 'Password';
  @override
  String get deleteAccountConfirm => 'Delete';
  @override
  String get deleteAccountError => 'Failed to delete account';
  @override
  String get deleteAccountWrongPassword => 'Incorrect password';
  @override
  String get supportTitle => 'User reports';
  @override
  String get supportInboxTooltip => 'Reports';
  @override
  String get supportEmpty => 'No reports';
  @override
  String get supportLoadError => 'Failed to load reports';
  @override
  String get supportOpen => 'Open';
  @override
  String get supportResolved => 'Resolved';
  @override
  String get supportMarkResolved => 'Mark resolved';
  @override
  String get supportReopen => 'Reopen';
  @override
  String get reportIssueTitle => 'Report an issue';
  @override
  String get reportIssueButton => 'Report an issue';
  @override
  String get reportIssueHint => 'Describe the issue or suggest an improvement…';
  @override
  String get reportIssueRequired => 'Write your message';
  @override
  String get reportIssueSend => 'Send';
  @override
  String get reportIssueSent => 'Your report was sent. Thank you';
  @override
  String get reportIssueError => 'Could not send the report';
  @override
  String get reportCategoryLabel => 'Type';
  @override
  String get reportCategoryBug => 'Bug';
  @override
  String get reportCategorySuggestion => 'Suggestion';
  @override
  String get reportCategoryOther => 'Other';

  @override
  String get onboardingSkip => 'Skip';
  @override
  String get onboardingNext => 'Next';
  @override
  String get onboardingStart => 'Get started';
  @override
  String get ob1Title => 'Control your gate';
  @override
  String get ob1Body => 'Open and close the gate with one tap, from anywhere.';
  @override
  String get ob2Title => 'Guest passes';
  @override
  String get ob2Body =>
      'Create a temporary link to let visitors in — no app needed.';
  @override
  String get ob3Title => 'Secured by fingerprint';
  @override
  String get ob3Body =>
      'Lock the app and open the gate with your fingerprint for extra security.';
  @override
  String get updateRequiredTitle => 'Update required';
  @override
  String get updateRequiredBody =>
      'This version is no longer supported. Download the update — it installs over the current version without deleting the app or losing your data.';
  @override
  String get updateAvailableTitle => 'Update available';
  @override
  String get updateAvailableBody =>
      'A newer version of the app is available. Download it to get the latest improvements.';
  @override
  String get updateDownloadButton => 'Download update';
  @override
  String get updateLaterButton => 'Later';
  @override
  String get updateOpenFailed => 'Could not open the update link';
  @override
  String get drawerFeaturesSection => 'Features';
  @override
  String get drawerSettingsSection => 'Settings';
  @override
  String get drawerAboutSection => 'About';
  @override
  String get drawerHome => 'Home';
  @override
  String get privacyPolicyTitle => 'Privacy policy';
  @override
  String get termsTitle => 'Terms & conditions';
  @override
  String get aboutDeveloperTitle => 'About the developer';
  @override
  String get developerName => 'Ahmed Hashem';
  @override
  String get developerRole => 'App developer';
  @override
  String get aboutContactHint =>
      'For any question or issue, reach out directly:';
  @override
  String get aboutCallAction => 'Call';
  @override
  String get aboutEmailAction => 'Email';
  @override
  String get aboutLaunchFailed => 'Could not open the requested app';

  @override
  String get adminUserDetailTitle => 'User details';
  @override
  String get userOverviewTitle => 'Overview';
  @override
  String get joinedLabel => 'Joined';
  @override
  String get activeDeviceLabel => 'Active device';
  @override
  String get deviceBound => 'Bound to a device';
  @override
  String get deviceNone => 'None';
  @override
  String get totalClosesLabel => 'Total closes';
  @override
  String get guestPassesCountLabel => 'Guest passes';
  @override
  String get guestArrivalsTitle => 'Arrivals';
  @override
  String get guestArrivalsEmpty => 'No arrivals yet';
  @override
  String guestArrivalsCount(int n) => '$n arrivals';
  @override
  String get recentActivityTitle => 'Recent activity';
  @override
  String get viewFullLog => 'View full log';
  @override
  String get emailVerifiedLabel => 'Email verified';
  @override
  String get yesLabel => 'Yes';
  @override
  String get noLabel => 'No';

  @override
  String get adminTabUsers => 'Users';
  @override
  String get adminTabDirectory => 'Directory';
  @override
  String get adminSearchHint => 'Search by name, email, or unit';
  @override
  String get filterAll => 'All';
  @override
  String get noMatchingResults => 'No matching results';
  @override
  String get unspecifiedUnit => 'Unspecified unit';
  @override
  String unitResidents(int n) => n == 1 ? '1 resident' : '$n residents';
  @override
  String selectedCount(int n) => '$n selected';
  @override
  String get bulkApprove => 'Approve selected';
  @override
  String get bulkSuspend => 'Suspend selected';
  @override
  String get bulkClear => 'Clear';
  @override
  String get bulkApproveTitle => 'Bulk approve';
  @override
  String bulkApproveConfirm(int n) => 'Approve $n users?';
  @override
  String get bulkSuspendTitle => 'Bulk suspend';
  @override
  String bulkSuspendConfirm(int n) => 'Suspend (reject) $n users?';
  @override
  String bulkApplied(int n) => 'Updated $n users';
  @override
  String get bulkFailed => 'Bulk action failed';
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
