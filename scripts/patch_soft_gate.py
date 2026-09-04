import os

path = os.path.join("lib", "features", "owner", "screens", "facility_onboarding_screen.dart")
with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

for idx, line in enumerate(lines):
    if "isAr ? 'إضافة ملعب' : 'Add stadium'" in line:
        # Find the closing of the SizedBox button
        target_idx = idx + 4
        button_code = [
            "  const SizedBox(height: 10),\n",
            "  TextButton(\n",
            "    onPressed: () async {\n",
            "      final uid = authProvider.currentUser?.uid;\n",
            "      final updatedAdditional = Map<String, dynamic>.from(\n",
            "        authProvider.userModel?.additionalData ?? {},\n",
            "      )..['isOnboardingConfirmed'] = true;\n",
            "      if (uid != null) {\n",
            "        try {\n",
            "          await Supabase.instance.client.from('users').update({\n",
            "            'has_stadium': true,\n",
            "            'additional_data': updatedAdditional,\n",
            "            'updated_at': DateTime.now().toUtc().toIso8601String(),\n",
            "          }).eq('id', uid);\n",
            "        } catch (_) {}\n",
            "      }\n",
            "      await authProvider.updateProfile({'additionalData': updatedAdditional});\n",
            "      if (context.mounted) {\n",
            "        context.go('/owner');\n",
            "      }\n",
            "    },\n",
            "    child: Text(\n",
            "      isAr ? 'استكشاف لوحة التحكم أولاً' : 'Explore Dashboard First',\n",
            "      style: const TextStyle(\n",
            "        color: VSPColors.textSecondary,\n",
            "        fontSize: 14,\n",
            "        fontWeight: FontWeight.w600,\n",
            "      ),\n",
            "    ),\n",
            "  ),\n"
        ]
        lines[target_idx:target_idx] = button_code
        with open(path, "w", encoding="utf-8") as f_out:
            f_out.writelines(lines)
        print("✅ Successfully patched facility_onboarding_screen.dart with Soft-Gate explore button!")
        break
