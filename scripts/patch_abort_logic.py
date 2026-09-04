import os

def patch_auth_provider():
    path = os.path.join("lib", "core", "providers", "auth_provider.dart")
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    for idx, line in enumerate(lines):
        if "Future<void> abortRegistration()" in line:
            print("abortRegistration() already present in auth_provider.dart")
            return

    target_idx = None
    for idx, line in enumerate(lines):
        if "Future<void> signOut() async {" in line:
            target_idx = idx
            break

    if target_idx is None:
        print("Could not find 'Future<void> signOut() async {' in auth_provider.dart")
        return

    # Check if previous line is a comment for signOut
    if target_idx > 0 and "Sign out" in lines[target_idx - 1]:
        target_idx -= 1

    abort_code = [
        "  /// Abort an incomplete registration and purge the uncompleted account.\n",
        "  ///\n",
        "  /// Called when a user taps \"Cancel / Back\" during onboarding before completing\n",
        "  /// registration. Safely calls the server-side RPC [delete_user_permanently]\n",
        "  /// to remove the uncompleted user from [public.users] and [auth.users].\n",
        "  Future<void> abortRegistration() async {\n",
        "    final uid = _firebaseUser?.id;\n",
        "    if (uid != null) {\n",
        "      if (_userModel?.isRegistrationComplete != true) {\n",
        "        try {\n",
        "          await Supabase.instance.client.rpc('delete_user_permanently', params: {'p_user_id': uid});\n",
        "          VSPLogger.i('abortRegistration: Incomplete account successfully purged from Supabase for UID: $uid');\n",
        "        } catch (e) {\n",
        "          VSPLogger.w('abortRegistration RPC error: $e');\n",
        "          try {\n",
        "            await _authService.deleteAccount(uid);\n",
        "          } catch (_) {}\n",
        "        }\n",
        "      } else {\n",
        "        VSPLogger.w('abortRegistration called on a completed account - falling back to normal signOut.');\n",
        "      }\n",
        "    }\n",
        "    await signOut();\n",
        "  }\n\n"
    ]

    lines[target_idx:target_idx] = abort_code
    with open(path, "w", encoding="utf-8") as f:
        f.writelines(lines)
    print("Successfully patched auth_provider.dart with abortRegistration()!")

if __name__ == "__main__":
    patch_auth_provider()
