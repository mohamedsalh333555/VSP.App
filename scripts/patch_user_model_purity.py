import os

# 1. Patch user_model.dart
model_path = os.path.join("lib", "core", "models", "user_model.dart")
with open(model_path, "r", encoding="utf-8") as f:
    model_content = f.read()

target_getters = """  bool get isOwner => role == 'owner' || isOwnerRole;
  bool get isPlayer => !isOwner;
  bool get isOwnerRole => role == 'owner' || hasStadium || additionalData?['role'] == 'owner' || additionalData?['is_owner'] == true;
  bool get isPlayerRole => !isOwnerRole;"""

clean_getters = """  bool get isOwner => role == 'owner';
  bool get isPlayer => !isOwner;
  bool get isOwnerRole => role == 'owner';
  bool get isPlayerRole => !isOwnerRole;"""

if target_getters in model_content:
    model_content = model_content.replace(target_getters, clean_getters)
    with open(model_path, "w", encoding="utf-8") as f:
        f.write(model_content)
    print("✅ user_model.dart role getters purified: 100% Single Source of Truth!")
else:
    print("Notice: target getters not found or already purified in user_model.dart")

# 2. Clean auth_provider.dart fallback
auth_path = os.path.join("lib", "core", "providers", "auth_provider.dart")
with open(auth_path, "r", encoding="utf-8") as f:
    auth_content = f.read()

fallback_block = """ // 1.5 Persist role in additional_data to guarantee resilience across sessions
 try {
 final existingAddData = Map<String, dynamic>.from(userData['additional_data'] ?? {});
 existingAddData['role'] = effectiveRole;
 existingAddData['is_owner'] = (effectiveRole == 'owner');
 await Supabase.instance.client.from('users').update({
 'additional_data': existingAddData,
 if (effectiveRole == 'owner') 'has_stadium': (userData['has_stadium'] ?? false),
 }).eq('id', user.id);
 userData['additional_data'] = existingAddData;
 } catch (e) {
 VSPLogger.w('Notice: resilient role sync fallback: ');
 }"""

clean_auth_sync = """ // 1.5 Sync role directly to Supabase Auth metadata for single source of truth
 try {
 await Supabase.instance.client.auth.updateUser(UserAttributes(data: {'role': effectiveRole}));
 } catch (_) {}"""

if fallback_block in auth_content:
    auth_content = auth_content.replace(fallback_block, clean_auth_sync)
    with open(auth_path, "w", encoding="utf-8") as f:
        f.write(auth_content)
    print("✅ auth_provider.dart purified: removed additional_data role hack!")
else:
    print("Notice: fallback block not found or already cleaned in auth_provider.dart")
