# جهازي — DeviceMonitor

تطبيق آيفون بلغة Swift (SwiftUI) يعرض حالة الجهاز مباشرة: البطارية، التخزين، الذاكرة، المعالج، حرارة الجهاز، الشاشة، ومدة التشغيل.

## طريقة استخراج ملف IPA

البناء يصير على سيرفر ماك من GitHub Actions، ما تحتاج جهاز ماك.

1. ارفع المشروع على مستودع في GitHub (فرع `main`).
2. كل ما ترفع تعديل، البناء يشتغل تلقائياً. أو من تبويب **Actions** اختر **Build IPA** ثم **Run workflow**.
3. بعد ما يخلص (تقريباً ٣–٥ دقائق) افتح التشغيلة، وانزل لقسم **Artifacts** ونزّل `DeviceMonitor-ipa`.
4. فك الضغط عن الملف المنزّل، بتلقى داخله `DeviceMonitor.ipa`، ارفعه للمتجر عشان يوقعه.

الملف غير موقّع (عليه توقيع ad-hoc بس)، والتوقيع الحقيقي يصير من المتجر.

## الملفات

- `DeviceMonitor/` — كود التطبيق بلغة Swift.
- `project.yml` — إعدادات المشروع (XcodeGen يحولها لمشروع Xcode وقت البناء).
- `.github/workflows/build-ipa.yml` — خطوات البناء وتغليف IPA.

## تعديلات سريعة

- **اسم التطبيق تحت الأيقونة:** `CFBundleDisplayName` في `Support/Info.plist`.
- **Bundle ID:** `PRODUCT_BUNDLE_IDENTIFIER` في `project.yml`.
- **الأيقونة:** استبدل `DeviceMonitor/Assets.xcassets/AppIcon.appiconset/AppIcon.png` بصورة 1024×1024 بدون شفافية.
