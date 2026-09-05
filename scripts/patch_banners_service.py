import sys

banners_service_path = r'k:\.gemini\antigravity\scratch\vsp_admin_panel\src\services\bannersService.js'
with open(banners_service_path, 'r', encoding='utf-8') as f:
    content = f.read()

if 'import { classifyError }' not in content:
    target = "import { supabase, supabaseAdmin } from '../lib/supabase';"
    replacement = "import { supabase, supabaseAdmin } from '../lib/supabase';\nimport { classifyError } from './adminService';"
    content = content.replace(target, replacement)

# Replace fetchBanners error
old_fetch = "return { success: false, error: e.message, data: [] };"
new_fetch = "const err = classifyError(e);\n      return { success: false, error: err.message, errorType: err.type, data: [] };"
content = content.replace(old_fetch, new_fetch)

# Replace generic return { success: false, error: e.message };
old_pattern = 'return { success: false, error: e.message };'
new_pattern = 'const err = classifyError(e);\n      return { success: false, error: err.message, errorType: err.type };'
content = content.replace(old_pattern, new_pattern)

old_pattern2 = 'return { success: false, error: e.message || \'Failed to upload image\' };'
new_pattern2 = 'const err = classifyError(e);\n      return { success: false, error: err.message, errorType: err.type };'
content = content.replace(old_pattern2, new_pattern2)

with open(banners_service_path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Updated bannersService.js successfully')
