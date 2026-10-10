# SECURITY_TASKS.md — مهام تأمين مشروع VSP

Production: mktqkddbcddrxjxabdua
Staging: vtwgqyxglevcsxwdmhop (INACTIVE)

## شروط التنفيذ
- اعرض عليا نص الـ SQL أو الكود قبل ما تطبقه على production، وأنا أوافق.
- بعد كل مهمة شغّل نفس الـ query اللي بتثبت بيها إنها اتنفذت، والصق النتيجة.
- أي مهمة من غير دليل تعتبر غير منفذة.
- Leaked password protection مؤجل، ما تعملش فيه حاجة.

## المهمة 1: حذف الـ functions التجريبية
احذف test_deploy_check_mcp و owner_documents_bucket_hardening_once بعد ما تتأكد بالـ grep إن مفيش كود بيناديهم.
الدليل: list_edge_functions من غيرهم.

## المهمة 2: process_tournament_refund (الأهم)
حالياً verify_jwt=false والنسخة v15.
1. اقرا الكود كامل واكتبلي: مين بيناديها، بتحرك فلوس إزاي، وهل فيها idempotency (نفس الطلب ما يتنفذش مرتين).
2. ضيف تحقق هوية جوه الكود: مسموح بس أدمن أو service role أو استدعاء داخلي موثوق.
3. غيّر verify_jwt إلى true.
4. اختبرها على staging الأول باسترداد وهمي صغير.
الدليل: طلب بدون token يرجع 401، وطلب من مستخدم عادي يرجع 403، ونفس طلب الاسترداد مرتين ما يرجّعش الفلوس مرتين.

## المهمة 3: create_owner_web_checkout و get_owner_web_checkout_status
- create_owner_web_checkout: يتحقق إن المستخدم مالك، والخطة والسعر يتحددوا على السيرفر مش من الطلب.
- get_owner_web_checkout_status: يتحقق إن الطلب بتاع نفس المستخدم.
- بعدها verify_jwt=true.
الدليل: نفس اختبار 401 و403.

## المهمة 4: fcm_push
اتأكد إنه بيتنادى من triggers أو داخلياً بس، وقفله بـ secret header أو service role.
الدليل: طلب خارجي من غير المفتاح يترفض.

## المهمة 5: paymob_webhook
verify_jwt يفضل false. اقرا الكود واعرض عليا الجزء اللي بيتحقق من HMAC SHA-512 قبل أي تعديل على الداتابيز. لو مفيش أو ناقص، ضيفه.
الدليل: السطور اللي فيها التحقق + طلب بتوقيع غلط يترفض.

## المهمة 6: جدول teams (المرحلة أ بس دلوقتي)
المشكلة: أي مستخدم مسجل بيقرا captain_phone و active_invite_code لكل الفرق.
1. grep في Flutter على from('teams') و captain_phone و active_invite_code، واعرض كل مكان.
2. اتأكد من أعمدة team_members الفعلية قبل ما تكتب SQL.
3. اكتب migration فيها:
   - view اسمها teams_public فيها الأعمدة العامة بس.
   - RPC اسمها get_team_invite_code(p_team_id) بتتحقق إن auth.uid() هو الكابتن.
4. اعرض الـ migration عليا قبل التطبيق.
ما تشيلش سياسة teams_select دلوقتي، لأن التطبيق بيقرا منها مباشرة. دي المرحلة ب بعد تعديل الـ Flutter.
الدليل: teams_public و get_team_invite_code موجودين، ومستخدم مش كابتن ما يقدرش ياخد الكود من الـ RPC.

## المهمة 7: سياسات verification-documents
السياستين الحاليتين: verification_documents_owner_insert و verification_documents_owner_admin_read.
اعرض نصهم الكامل، وتأكد إن المالك يرفع ويشوف ملفاته بس، والأدمن يشوف الكل، ومفيش قراءة عامة.
الدليل: نص السياسات بعد التعديل + اختبار قراءة ملف مستخدم تاني يفشل.

## المهمة 8: دوال SECURITY DEFINER
اقرا كود الدوال دي بالترتيب وللكل اكتب: محمية / مفتوحة / داخلية، والتصليح:
admin_wipe_1v1_data_atomic، delete_user_permanently، admin_set_admin_role_atomic، admin_register_owner_on_behalf، create_owner_on_behalf، confirm_1v1_payment_atomic، confirm_cash_booking_atomic، activate_vsp_pro، admin_record_payout_settlement_atomic، approve_payout_settlement_atomic، get_admin_metrics، get_owner_financial_summary، get_collective_invite_credentials، get_private_collective_invite_by_code.
بعدها كل دوال admin_* وأي دالة فيها payout أو refund أو subscription.
الدوال الداخلية اللي مش بيناديها التطبيق (اتأكد بالـ grep): REVOKE EXECUTE FROM authenticated.
الناتج: جدول بالنتيجة لكل دالة.

## المهمة 9: staging
1. شغّل vsp-staging وانتظر ACTIVE_HEALTHY.
2. طبّق migrations الـ production عليه (من غير بيانات حقيقية).
3. اعمل مستخدم وملعب تجريبيين عليه.
4. شغّل scripts/stress_concurrency_test.dart بـ URL و anon key الخاصين بـ staging.
المطلوب: Granted = 1 و Rejected = 19 بـ SLOT_LOCKED_OR_TAKEN.
الدليل: الـ output الكامل للسكريبت.
