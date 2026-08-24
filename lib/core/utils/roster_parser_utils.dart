import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ui/tokens/vsp_tokens.dart';

class RosterParserUtils {
 /// Street-smart WhatsApp / Notes multiline squad list parser.
 /// Converts copied raw text lines like:
 /// 1- أحمد محمود
 /// 2. كابتن علي
 /// • محمد شعبان
 /// into a clean list: ["أحمد محمود", "علي", "محمد شعبان"]
 static List<String> parseSquadText(String rawText) {
 if (rawText.trim().isEmpty) return [];

 final lines = rawText.split(RegExp(r'\r?\n'));
 final Set<String> namesSet = {};
 final List<String> result = [];

 // Prefix stripping regexes
 final numberingRegex = RegExp(r'^\s*(?:\(?\d+[\.\-\/\)]|\d+\s*[\-\.]|[•\-\*\+\#\[\]])\s*');
 final captainPrefixRegex = RegExp(r'^(?:كابتن|اللاعب\s*:?|لاعب\s*:?)\s*', caseSensitive: false);

 for (var line in lines) {
 String clean = line.trim();
 if (clean.isEmpty) continue;

 // 1. Strip leading numbering and bullets: 1-, 1., (1), -, •, *, etc.
 clean = clean.replaceAll(numberingRegex, '').trim();

 // 2. Strip title prefixes if present at start: "كابتن أحمد" -> "أحمد", "اللاعب: علي" -> "علي"
 clean = clean.replaceAll(captainPrefixRegex, '').trim();

 // 3. Ignore header/footer lines if they are pure headers (e.g. "تشكيلة الفريق:")
 if (clean.isEmpty) continue;
 if ((clean.startsWith('تشكيلة') || clean.startsWith('قائمة') || clean.startsWith('أسماء')) && clean.endsWith(':')) {
 continue;
 }

 // 4. Clean duplicate spaces inside name
 clean = clean.replaceAll(RegExp(r'\s+'), ' ');

 if (clean.length >= 2 && !namesSet.contains(clean.toLowerCase())) {
 namesSet.add(clean.toLowerCase());
 result.add(clean);
 }
 }

 return result;
 }

 /// Displays the squad import dialog and reads clipboard or manual input text.
 static Future<List<String>> showImportSquadDialog(BuildContext context) async {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 String textToParse = '';

 try {
 final data = await Clipboard.getData(Clipboard.kTextPlain);
 if (data != null && data.text != null && data.text!.trim().isNotEmpty) {
 textToParse = data.text!;
 }
 } catch (_) {}

 if (textToParse.trim().isEmpty && context.mounted) {
 textToParse = await showDialog<String>(
 context: context,
 builder: (ctx) {
 final controller = TextEditingController();
 return AlertDialog(
 backgroundColor: VSPColors.surface,
 title: Text(
 isArabic ? 'لصق نص تشكيلة واتساب ' : 'Paste WhatsApp Squad List ',
 style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
 ),
 content: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 TextField(
 controller: controller,
 maxLines: 6,
 style: const TextStyle(color: Colors.white, fontSize: 13),
 decoration: InputDecoration(
 hintText: isArabic ? '1- أحمد\n2- علي\n3- محمود...' : '1- Player 1\n2- Player 2...',
 filled: true,
 fillColor: VSPColors.background,
 ),
 ),
 ],
 ),
 actions: [
 TextButton(onPressed: () => Navigator.pop(ctx, null), child: Text(isArabic ? 'إلغاء' : 'Cancel')),
 ElevatedButton(
 style: ElevatedButton.styleFrom(backgroundColor: VSPColors.accent, foregroundColor: Colors.black),
 onPressed: () => Navigator.pop(ctx, controller.text),
 child: Text(isArabic ? 'استخراج الأسماء ' : 'Extract Names '),
 ),
 ],
 );
 },
 ) ?? '';
 }

 return parseSquadText(textToParse);
 }
}
