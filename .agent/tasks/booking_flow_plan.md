# 📋 خطة تنفيذ تدفق الحجز (Booking Flow)

## 🎯 الهدف
بناء تدفق حجز كامل للملاعب يبدأ من شاشة تفاصيل الملعب وينتهي بتأكيد الحجز بنجاح.

## 📱 الشاشات المطلوبة

### المهمة 4.2.1: شاشة تفاصيل الملعب (Stadium Details Screen)
**الملف:** `stadium_details_screen.dart`

**المكونات:**
- ✅ صورة الملعب الكبيرة في الأعلى
- ✅ أيقونة القلب (Favorite) في الزاوية
- ✅ 3 تبويبات (Tabs):
  - **Information**: معلومات الملعب، الوصف، المميزات، السياسات
  - **Pitch Conditions**: حالة الملعب
  - **Ratings**: التقييمات والمراجعات
- ✅ زر "Book Now" في الأسفل
- ✅ عرض السعر بالساعة

---

### المهمة 4.2.2: شاشة اختيار نوع الحجز (Choose What Suits You)
**الملف:** `booking_type_screen.dart`

**الخيارات:**
1. **Create A New Team** (مع زر "Create" أخضر)
   - يفتح نافذة منبثقة لإنشاء فريق
2. **Personal Booking** (حجز شخصي)
3. **Your Team** (إذا كان لديك فريق)
4. **Challenge** (تحدي فريق آخر)

**النافذة المنبثقة:** `create_team_modal.dart`
- اسم الفريق
- نوع الرياضة
- رفع صورة الفريق
- إضافة أعضاء الفريق (6 من 8)
- أزرار Cancel و Confirm

---

### المهمة 4.2.3: شاشة اختيار الوقت والتاريخ (Slot Selection Screen)
**الملف:** `slot_selection_screen.dart`

**المكونات:**
- ✅ اختيار التاريخ (Date Picker)
- ✅ عرض الأيام بشكل أفقي
- ✅ اختيار الوقت (Time Slots)
  - الأوقات المتاحة باللون الأخضر
  - الأوقات المحجوزة باللون الرمادي
- ✅ خيار "Private" (Toggle)
- ✅ خيار "Rent Ball" (مع السعر +20 EGP)
- ✅ عرض السعر الإجمالي
- ✅ زر "Booking Confirmation"

---

### المهمة 4.2.4: نافذة تأكيد الحجز (Confirm Booking Modal)
**الملف:** `confirm_booking_modal.dart`

**المكونات:**
- ✅ عرض تفاصيل الحجز:
  - التاريخ
  - الوقت
  - السعر
- ✅ خيارات الدفع:
  - **Pay Upon Arrival** (رمادي)
  - **Pay Now** (أخضر)

---

### المهمة 4.2.5: نافذة نجاح الحجز (Successful Reservation Modal)
**الملف:** `booking_success_modal.dart`

**المكونات:**
- ✅ أيقونة النجاح مع الزخارف
- ✅ رسالة "Your reservation has been completed successfully"
- ✅ رابط المشاركة (Share Link)
- ✅ زر "Home" للعودة للصفحة الرئيسية

---

## 🔄 تدفق التنقل

```
Player Home Screen
    ↓ (النقر على بطاقة ملعب)
Stadium Details Screen
    ↓ (النقر على Book Now)
Choose What Suits You Screen
    ↓ (اختيار نوع الحجز)
    ├─→ Create Team Modal (إذا اختار Create New Team)
    └─→ Slot Selection Screen
            ↓ (اختيار الوقت والتاريخ)
        Confirm Booking Modal
            ↓ (اختيار طريقة الدفع)
        Booking Success Modal
            ↓ (النقر على Home)
        Player Home Screen
```

---

## 📦 الملفات المطلوب إنشاؤها

### 1. Models
- `lib/data/booking_models.dart` - نماذج بيانات الحجز

### 2. Screens
- `lib/features/player/screens/stadium_details_screen.dart`
- `lib/features/player/screens/booking_type_screen.dart`
- `lib/features/player/screens/slot_selection_screen.dart`

### 3. Modals/Dialogs
- `lib/features/player/widgets/create_team_modal.dart`
- `lib/features/player/widgets/confirm_booking_modal.dart`
- `lib/features/player/widgets/booking_success_modal.dart`

### 4. Widgets
- `lib/features/player/widgets/stadium_info_tab.dart`
- `lib/features/player/widgets/pitch_conditions_tab.dart`
- `lib/features/player/widgets/ratings_tab.dart`

---

## ✅ معايير الإنجاز

- [ ] جميع الشاشات تتبع التصميم المرفق بدقة
- [ ] التنقل بين الشاشات يعمل بسلاسة
- [ ] البيانات التجريبية (Mock Data) متوفرة لجميع الأقسام
- [ ] دعم اللغتين (عربي/إنجليزي)
- [ ] التصميم Dark Premium مع الألوان النيون الخضراء
- [ ] جميع الأزرار والتفاعلات تعمل بشكل صحيح

---

## 🚀 البدء بالتنفيذ

سأبدأ الآن بتنفيذ المهام بالترتيب:
1. ✅ إنشاء نماذج البيانات
2. ✅ بناء شاشة تفاصيل الملعب (4.2.1)
3. ✅ بناء شاشة اختيار نوع الحجز (4.2.2)
4. ✅ بناء شاشة اختيار الوقت (4.2.3)
5. ✅ بناء النوافذ المنبثقة للتأكيد والنجاح (4.2.4 & 4.2.5)
