import os

path = os.path.join("lib", "features", "owner", "screens", "facility_onboarding_screen.dart")
with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

# Remove the incorrectly inserted lines
start_idx = None
end_idx = None
for idx, line in enumerate(lines):
    if "const SizedBox(height: 10)," in line:
        start_idx = idx
    if start_idx is not None and "Explore Dashboard First" in line:
        end_idx = idx + 8
        break

if start_idx is not None and end_idx is not None:
    del lines[start_idx:end_idx]

# Now find the closing of the SizedBox(width: double.infinity, height: 56, ...)
# In Column.children:
target_idx = None
for idx, line in enumerate(lines):
    if "isAr ? 'إضافة ملعب' : 'Add stadium'" in line:
        # line idx is Text('Add stadium')
        # idx + 1: ' ),\n' (Text)
        # idx + 2: ' ),\n' (ElevatedButton)
        # idx + 3: ' ),\n' (SizedBox)
        target_idx = idx + 4
        break

if target_idx is not None:
    button_code = [
        "              const SizedBox(height: 12),\n",
        "              TextButton(\n",
        "                onPressed: () async {\n",
        "                  final uid = authProvider.currentUser?.uid;\n",
        "                  final updatedAdditional = Map<String, dynamic>.from(\n",
        "                    authProvider.userModel?.additionalData ?? {},\n",
        "                  )..['isOnboardingConfirmed'] = true;\n",
        "                  if (uid != null) {\n",
        "                    try {\n",
        "                      await Supabase.instance.client.from('users').update({\n",
        "                        'has_stadium': true,\n",
        "                        'additional_data': updatedAdditional,\n",
        "                        'updated_at': DateTime.now().toUtc().toIso8601String(),\n",
        "                      }).eq('id', uid);\n",
        "                    } catch (_) {}\n",
        "                  }\n",
        "                  await authProvider.updateProfile({'additionalData': updatedAdditional});\n",
        "                  if (context.mounted) {\n",
        "                    context.go('/owner');\n",
        "                  }\n",
        "                },\n",
        "                child: Text(\n",
        "                  isAr ? 'استكشاف لوحة التحكم أولاً' : 'Explore Dashboard First',\n",
        "                  style: const TextStyle(\n",
        "                    color: VSPColors.textSecondary,\n",
        "                    fontSize: 14,\n",
        "                    fontWeight: FontWeight.w600,\n",
        "                  ),\n",
        "                ),\n",
        "              ),\n"
    ]
    lines[target_idx:target_idx] = button_code
    with open(path, "w", encoding="utf-8") as f_out:
        f_out.writelines(lines)
    print("Fixed facility_onboarding_screen.dart button placement!")
