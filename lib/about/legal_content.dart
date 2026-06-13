/// Static legal copy for the privacy-policy and terms screens, in both
/// locales. Kept out of [AppStrings] so the long-form text doesn't bloat the
/// localization interface.
class LegalSection {
  const LegalSection({required this.title, required this.body});

  final String title;
  final String body;
}

List<LegalSection> privacySections({required bool arabic}) =>
    arabic ? _privacyAr : _privacyEn;

List<LegalSection> termsSections({required bool arabic}) =>
    arabic ? _termsAr : _termsEn;

const _privacyAr = [
  LegalSection(
    title: 'البيانات التي نجمعها',
    body: 'عند إنشاء حسابك نقوم بتخزين: الاسم، البريد الإلكتروني، رقم الشقة، '
        'ومعرّف الجهاز المستخدم لتسجيل الدخول. كما يسجّل التطبيق عمليات فتح '
        'وإغلاق البوابة (الوقت والمستخدم) لأغراض الأمان، ويحتفظ برمز '
        'الإشعارات الخاص بجهازك لإرسال التنبيهات.',
  ),
  LegalSection(
    title: 'كيف نستخدم بياناتك',
    body: 'تُستخدم البيانات حصريًا لتشغيل خدمة التحكم في بوابة المبنى: '
        'التحقق من هويتك، عرض سجل النشاط، إدارة تصاريح الزوار، وإرسال '
        'الإشعارات المتعلقة بالبوابة وحسابك. لا نستخدم بياناتك لأي أغراض '
        'إعلانية أو تسويقية.',
  ),
  LegalSection(
    title: 'مشاركة البيانات',
    body: 'لا نبيع بياناتك ولا نشاركها مع أي طرف ثالث. تُخزَّن البيانات على '
        'خوادم Firebase من Google وفق معايير الحماية الخاصة بها. يطّلع مدير '
        'المبنى فقط على بيانات الحسابات لمراجعتها وإدارتها.',
  ),
  LegalSection(
    title: 'تصاريح الزوار',
    body: 'عند إنشاء تصريح زائر يُنشأ رابط مؤقت يتيح فتح البوابة دون تطبيق. '
        'أنت المسؤول عن مشاركة هذا الرابط، ويُسجَّل كل استخدام له باسمك.',
  ),
  LegalSection(
    title: 'حذف الحساب',
    body: 'يمكنك حذف حسابك نهائيًا من شاشة الملف الشخصي. الحذف يزيل بياناتك '
        'الشخصية، تصاريحك، إشعاراتك، وبلاغاتك من قاعدة البيانات.',
  ),
  LegalSection(
    title: 'التواصل',
    body: 'لأي استفسار حول الخصوصية تواصل مع مطور التطبيق عبر صفحة '
        '«عن المطور».',
  ),
];

const _privacyEn = [
  LegalSection(
    title: 'Data we collect',
    body: 'When you create an account we store: your name, email address, '
        'apartment number, and the identifier of the device you sign in '
        'with. The app also records gate open/close actions (time and user) '
        'for security purposes, and keeps your device push-notification '
        'token to deliver alerts.',
  ),
  LegalSection(
    title: 'How we use your data',
    body: 'Your data is used exclusively to operate the building-gate '
        'service: verifying your identity, showing activity history, '
        'managing guest passes, and sending notifications about the gate '
        'and your account. We never use your data for advertising or '
        'marketing.',
  ),
  LegalSection(
    title: 'Data sharing',
    body: 'We do not sell your data or share it with any third party. Data '
        'is stored on Google Firebase servers under their security '
        'standards. Only the building administrator can review and manage '
        'account data.',
  ),
  LegalSection(
    title: 'Guest passes',
    body: 'Creating a guest pass generates a temporary link that opens the '
        'gate without an app. You are responsible for sharing that link, '
        'and every use of it is logged under your name.',
  ),
  LegalSection(
    title: 'Account deletion',
    body: 'You can permanently delete your account from the profile screen. '
        'Deletion removes your personal data, passes, notifications, and '
        'reports from the database.',
  ),
  LegalSection(
    title: 'Contact',
    body: 'For any privacy question, contact the app developer via the '
        '"About the developer" page.',
  ),
];

const _termsAr = [
  LegalSection(
    title: 'قبول الشروط',
    body: 'باستخدامك هذا التطبيق فأنت توافق على هذه الشروط. التطبيق مخصص '
        'لسكان المبنى المصرّح لهم فقط للتحكم في بوابة المبنى.',
  ),
  LegalSection(
    title: 'الحساب والموافقة',
    body: 'تُفعَّل الحسابات الجديدة تلقائيًا بعد التحقق من البريد الإلكتروني، '
        'ويحتفظ مدير المبنى بحق مراجعة أي حساب أو إيقافه في أي وقت. يعمل '
        'الحساب على جهاز واحد فقط في نفس الوقت — تسجيل الدخول من جهاز جديد '
        'ينهي الجلسة السابقة.',
  ),
  LegalSection(
    title: 'الاستخدام المسؤول',
    body: 'أنت مسؤول عن كل عملية فتح للبوابة تتم من حسابك أو عبر تصاريح '
        'الزوار التي تنشئها. يُمنع مشاركة بيانات الدخول أو استخدام التطبيق '
        'للسماح بدخول أشخاص غير مصرّح لهم.',
  ),
  LegalSection(
    title: 'توفر الخدمة',
    body: 'تعتمد الخدمة على اتصال الإنترنت وخوادم خارجية، لذلك لا نضمن '
        'عملها دون انقطاع. عند تعطل الخدمة استخدم الوسائل البديلة لفتح '
        'البوابة.',
  ),
  LegalSection(
    title: 'إنهاء الاستخدام',
    body: 'يحق لمدير المبنى إيقاف أي حساب يخالف هذه الشروط. كما يمكنك حذف '
        'حسابك في أي وقت من شاشة الملف الشخصي.',
  ),
  LegalSection(
    title: 'تعديل الشروط',
    body: 'قد تُحدَّث هذه الشروط مع تطور التطبيق، وسيُعلن عن أي تغيير جوهري '
        'داخل التطبيق. استمرارك في الاستخدام بعد التحديث يعني موافقتك.',
  ),
];

const _termsEn = [
  LegalSection(
    title: 'Acceptance of terms',
    body: 'By using this app you agree to these terms. The app is intended '
        'only for authorized building residents to control the building '
        'gate.',
  ),
  LegalSection(
    title: 'Account and approval',
    body: 'New accounts are activated automatically after email '
        'verification, and the building administrator may review or '
        'suspend any account at any time. An account works on a single '
        'device at a time — signing in on a new device ends the previous '
        'session.',
  ),
  LegalSection(
    title: 'Responsible use',
    body: 'You are responsible for every gate opening made from your '
        'account or through guest passes you create. Sharing credentials '
        'or using the app to admit unauthorized people is prohibited.',
  ),
  LegalSection(
    title: 'Service availability',
    body: 'The service depends on internet connectivity and external '
        'servers, so uninterrupted operation is not guaranteed. When the '
        'service is down, use alternative means to open the gate.',
  ),
  LegalSection(
    title: 'Termination',
    body: 'The building administrator may suspend any account that '
        'violates these terms. You may also delete your account at any '
        'time from the profile screen.',
  ),
  LegalSection(
    title: 'Changes to terms',
    body: 'These terms may be updated as the app evolves; any material '
        'change will be announced in the app. Continued use after an '
        'update means you accept it.',
  ),
];
