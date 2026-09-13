import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/repositories/user_repository.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../shared/widgets/vsp_back_button.dart';

/// Search delegate allowing owners to search for players or users to start direct chats.
class UserSearchDelegate extends SearchDelegate<UserModel?> {
  final String currentUserId;
  final String currentUserRole;
  final UserRepository? _userRepository;

  UserSearchDelegate({
    required this.currentUserId,
    required this.currentUserRole,
    UserRepository? userRepository,
  }) : _userRepository = userRepository;

  UserRepository get _userRepo => _userRepository ?? UserRepository();

  @override
  String? get searchFieldLabel => 'بحث عن لاعبين...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: VSPColors.surface,
        iconTheme: IconThemeData(color: VSPColors.textPrimary),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: VSPColors.textSecondary),
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Iconsax.close_circle_copy),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return VSPBackButton(
      onTap: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return FutureBuilder<List<UserModel>>(
      future: _searchUsers(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: VSPColors.accent),
          );
        }

        final users = snapshot.data ?? [];
        final filteredUsers = currentUserRole == 'owner'
            ? users
                .where((u) => u.role == 'player' && !u.hasStadium && u.uid != currentUserId)
                .toList()
            : users.where((u) => u.uid != currentUserId).toList();

        if (filteredUsers.isEmpty) {
          return Center(
            child: Text(
              query.isEmpty
                  ? (isArabic
                      ? 'ابحث عن لاعبين لبدء المحادثة...'
                      : 'Search for players to start a chat...')
                  : (isArabic
                      ? 'لم يتم العثور على لاعبين بهذا الاسم'
                      : 'No players found'),
              style: const TextStyle(color: VSPColors.textSecondary),
            ),
          );
        }

        return ListView.builder(
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            final user = filteredUsers[index];
            final roleLabel = user.isOwnerRole
                ? (isArabic ? 'مالك ملعب' : 'Stadium Owner')
                : (isArabic ? 'لاعب' : 'Player');

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: VSPColors.surfaceAlt,
                backgroundImage:
                    (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty)
                        ? CachedNetworkImageProvider(user.profileImageUrl!)
                        : null,
                child: (user.profileImageUrl == null || user.profileImageUrl!.isEmpty)
                    ? const Icon(Iconsax.user_copy, color: VSPColors.accent)
                    : null,
              ),
              title: Text(
                user.name ?? user.email,
                style: const TextStyle(
                  color: VSPColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                roleLabel,
                style: TextStyle(
                  color: user.isOwnerRole ? VSPColors.accent : VSPColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              onTap: () {
                close(context, user);
              },
            );
          },
        );
      },
    );
  }

  Future<List<UserModel>> _searchUsers(String query) async {
    return _userRepo.searchUsers(
      currentUserId: currentUserId,
      role: currentUserRole == 'owner' ? 'player' : null,
      query: query,
    );
  }
}
