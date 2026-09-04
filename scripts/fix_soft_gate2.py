import os

path = os.path.join("lib", "features", "owner", "screens", "facility_onboarding_screen.dart")
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Replace the block around line 129
old_block = """ child: Text(
 isAr ? 'إضافة ملعب' : 'Add stadium',
 style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
 ),
 ),
              const SizedBox(height: 12),"""

new_block = """ child: Text(
 isAr ? 'إضافة ملعب' : 'Add stadium',
 style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
 ),
 ),
 ),
              const SizedBox(height: 12),"""

if old_block in content:
    content = content.replace(old_block, new_block, 1)
    # And remove the extra closing paren at the end of TextButton
    content = content.replace("""              ),
 ),
 const SizedBox(height: 16),""", """              ),
 const SizedBox(height: 16),""", 1)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print("Fixed closing paren in facility_onboarding_screen.dart!")
else:
    print("Old block not found!")
