import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'vsp_feedback.dart';

/// Centralized Error Handler for VSP Application
class VSPErrorHandler {
 static Future<T?> tryCatch<T>(
 BuildContext context, {
 required Future<T> Function() action,
 required String actionContext,
 bool showFeedback = true,
 }) async {
 try {
 return await action();
 } on SocketException catch (e) {
 _handleNetworkError(context, actionContext, showFeedback, e);
 return null;
 } on PostgrestException catch (e) {
 _handleDatabaseError(context, actionContext, showFeedback, e);
 return null;
 } catch (e) {
 _handleGenericError(context, actionContext, showFeedback, e);
 return null;
 }
 }

 static void _handleNetworkError(
 BuildContext context,
 String actionContext,
 bool showFeedback,
 SocketException error,
 ) {
 debugPrint(' Network Error in $actionContext: $error');
 if (showFeedback && context.mounted) {
 VSPFeedback.showError(
 context,
 "فقدان الاتصال بالإنترنت\nتحقق من الاتصال وحاول مجدداً",
 );
 }
 }

 static void _handleDatabaseError(
 BuildContext context,
 String actionContext,
 bool showFeedback,
 PostgrestException error,
 ) {
 debugPrint(' DB Error in $actionContext: [${error.code}] ${error.message}');
 if (!showFeedback || !context.mounted) return;

 if (error.code == '23505') {
 VSPFeedback.showError(context, "هذا العنصر موجود بالفعل.");
 } else if (error.code == '42501') {
 VSPFeedback.showError(context, "ليس لديك صلاحية لإجراء هذا التغيير.");
 } else {
 VSPFeedback.showError(
 context,
 "خطأ في تحميل البيانات ($actionContext).\nيرجى المحاولة مجدداً.",
 );
 }
 }

 static void _handleGenericError(
 BuildContext context,
 String actionContext,
 bool showFeedback,
 dynamic error,
 ) {
 debugPrint(' Error in $actionContext: $error');
 if (showFeedback && context.mounted) {
 VSPFeedback.showError(
 context,
 "حدث خطأ غير متوقع ($actionContext).\nإذا استمرت المشكلة يرجى الاتصال بالدعم.",
 );
 }
 }
}
