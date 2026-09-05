import sys

admin_service_path = r'k:\.gemini\antigravity\scratch\vsp_admin_panel\src\services\adminService.js'
with open(admin_service_path, 'r', encoding='utf-8') as f:
    content = f.read()

classify_code = """export function classifyError(e) {
  if (typeof navigator !== 'undefined' && !navigator.onLine) {
    return { type: 'offline', message: 'لا يوجد اتصال بالإنترنت' };
  }
  const msg = e?.message || e?.error_description || String(e || '');
  if (msg.includes('Failed to fetch') || msg.includes('NetworkError') || msg.includes('Network request failed')) {
    return { type: 'network', message: 'تعذر الوصول للخادم، تحقق من اتصالك' };
  }
  if (e?.code === '57014' || msg.toLowerCase().includes('timeout')) {
    return { type: 'timeout', message: 'استغرق الطلب وقتاً طويلاً، حاول مرة أخرى' };
  }
  return { type: 'server', message: msg || 'حدث خطأ غير متوقع' };
}

"""

if 'export function classifyError' not in content:
    target = "import { supabase, supabaseAdmin } from '../lib/supabase';"
    content = content.replace(target, target + "\n\n" + classify_code)

old_pattern = 'return { success: false, error: e.message };'
new_pattern = 'const err = classifyError(e);\n      return { success: false, error: err.message, errorType: err.type };'
count = content.count(old_pattern)
content = content.replace(old_pattern, new_pattern)

with open(admin_service_path, 'w', encoding='utf-8') as f:
    f.write(content)

print(f'Updated adminService.js successfully. Replaced {count} instances of error returns.')
