import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/modal/modal.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../../../utils/dev_logger.dart';
import '../contacts_api.dart';
import '../play_models.dart';
import '../friend_match_invite_api.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Host-side invite setup: search Contacts by username and request an inviteId.
///
/// Returns [InviteSetupResult], or null if cancelled/dismissed.
Future<InviteSetupResult?> showInviteSetupModal({
  required BuildContext context,
  required WidgetRef ref,
}) {
  return AppModal.showCenteredShell<InviteSetupResult?>(
    context,
    title: 'Create invite',
    barrierDismissible: true,
    showCloseButton: true,
    child: _InviteSetupBody(ref: ref),
  );
}

class _InviteSetupBody extends ConsumerStatefulWidget {
  const _InviteSetupBody({required this.ref});

  final WidgetRef ref;

  @override
  ConsumerState<_InviteSetupBody> createState() => _InviteSetupBodyState();
}

class _InviteSetupBodyState extends ConsumerState<_InviteSetupBody> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  bool _submittingInvite = false;
  bool _loadingContacts = true;
  bool _searching = false;

  List<ContactUser> _searchResults = const [];
  List<ContactUser> _contacts = const [];

  ContactUser? _selectedRecipient;
  bool _wasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_refreshContacts());
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshContacts() async {
    final token = widget.ref.read(authProvider).accessToken ?? '';
    final messenger = ScaffoldMessenger.of(context);

    if (token.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sign in to create invites')),
      );
      if (mounted) {
        setState(() => _loadingContacts = false);
      }
      return;
    }

    setState(() => _loadingContacts = true);

    final api = ContactsApiClient();
    final outcome = await api.fetchMyContacts(accessToken: token);

    if (!mounted) return;

    if (!outcome.isSuccess) {
      messenger.showSnackBar(
        SnackBar(content: Text(outcome.error?.message ?? 'Load contacts failed')),
      );
      setState(() => _loadingContacts = false);
      return;
    }

    setState(() {
      _contacts = outcome.data ?? const [];
      // Clear selection if the user was removed from Contacts.
      if (_selectedRecipient != null &&
          !_contacts.any((c) => c.userId == _selectedRecipient!.userId)) {
        _selectedRecipient = null;
      }
      _loadingContacts = false;
    });
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      if (!mounted) return;
      setState(() {
        _searchResults = const [];
        _searching = false;
      });
      return;
    }

    final token = widget.ref.read(authProvider).accessToken ?? '';
    if (token.isEmpty) return;

    setState(() => _searching = true);
    final api = ContactsApiClient();
    final outcome = await api.searchContactsByUsername(
      accessToken: token,
      query: q,
    );
    if (!mounted) return;

    if (!outcome.isSuccess) {
      setState(() => _searching = false);
      return;
    }

    setState(() {
      _searchResults = outcome.data ?? const [];
      _searching = false;
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final q = value.trim();

    if (q.length < 2) {
      setState(() {
        _searchResults = const [];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_search(q));
    });
  }

  Future<void> _selectRecipient(ContactUser user) async {
    final token = widget.ref.read(authProvider).accessToken ?? '';
    if (token.isEmpty) return;

    setState(() => _searching = true);
    final api = ContactsApiClient();
    final addOutcome = await api.addContact(
      accessToken: token,
      contactUserId: user.userId,
    );
    if (!mounted) return;

    if (!addOutcome.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(addOutcome.error?.message ?? 'Add failed')),
      );
      setState(() => _searching = false);
      return;
    }

    await _refreshContacts();
    if (!mounted) return;

    setState(() {
      _selectedRecipient = user;
      _searching = false;
      // Clear results to make it feel like a concrete choice.
      _searchResults = const [];
      _searchController.clear();
    });
  }

  Future<void> _removeContact(ContactUser user) async {
    final token = widget.ref.read(authProvider).accessToken ?? '';
    if (token.isEmpty) return;

    setState(() => _loadingContacts = true);
    final api = ContactsApiClient();
    final out = await api.removeContact(
      accessToken: token,
      contactUserId: user.userId,
    );
    if (!mounted) return;

    if (!out.isSuccess) {
      setState(() => _loadingContacts = false);
      return;
    }

    await _refreshContacts();
    if (!mounted) return;

    setState(() {
      if (_selectedRecipient?.userId == user.userId) {
        _selectedRecipient = null;
      }
      _loadingContacts = false;
    });
  }

  Future<void> _createInvite() async {
    if (_submittingInvite) return;
    final recipient = _selectedRecipient;
    if (recipient == null) return;

    final token = widget.ref.read(authProvider).accessToken ?? '';
    if (token.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);

    setState(() => _submittingInvite = true);
    try {
      if (LOGGING_SWITCH) {
        customlog(
          'invite_setup: createInvite invitedUserId=${recipient.userId} '
          'username=${recipient.username}',
        );
      }
      final api = FriendMatchInviteApiClient();
      final outcome = await api.createInvite(
        accessToken: token,
        invitedUserId: recipient.userId,
      );

      if (!mounted) return;
      if (!outcome.isSuccess) {
        if (LOGGING_SWITCH) {
          customlog(
            'invite_setup: createInvite failed network=${outcome.isNetworkError} '
            'code=${outcome.error?.rawCode ?? '-'}',
          );
        }
        messenger.showSnackBar(
          SnackBar(content: Text(outcome.error?.message ?? 'Request failed')),
        );
        return;
      }

      if (LOGGING_SWITCH) {
        customlog(
          'invite_setup: createInvite ok inviteId=${outcome.data} '
          'invitedUserId=${recipient.userId}',
        );
      }
      AppModal.dismiss(
        context,
        InviteSetupResult(
          inviteId: outcome.data!,
          invitedUserId: recipient.userId,
        ),
      );
    } finally {
      if (mounted) setState(() => _submittingInvite = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    if (!_wasAuthenticated && authState.isAuthenticated) {
      _wasAuthenticated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Auth transitioned to authenticated while modal is open.
        unawaited(_refreshContacts());
      });
    } else if (_wasAuthenticated && !authState.isAuthenticated) {
      _wasAuthenticated = false;
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Search Contacts by username',
            style: context.appTypography.bodySmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Type 2+ characters',
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 8),
          if (_searching) const LinearProgressIndicator(minHeight: 2),
          if (_searchResults.isNotEmpty)
            SizedBox(
              height: 160,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, i) {
                  final user = _searchResults[i];
                  return ListTile(
                    title: Text(user.displayName),
                    subtitle: Text(user.username),
                    leading: const Icon(Icons.person_add),
                    onTap: () => _selectRecipient(user),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Contacts',
            style: context.appTypography.bodySmall,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: _loadingContacts
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _contacts.length,
                    itemBuilder: (context, i) {
                      final c = _contacts[i];
                      final isSelected =
                          _selectedRecipient?.userId == c.userId;
                      return ListTile(
                        title: Text(c.displayName),
                        subtitle: Text(c.username),
                        selected: isSelected,
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => _removeContact(c),
                        ),
                        onTap: isSelected
                            ? null
                            : () {
                                setState(() {
                                  _selectedRecipient = c;
                                });
                              },
                      );
                    },
                  ),
          ),
          if (_selectedRecipient != null) ...[
            const SizedBox(height: 8),
            Text(
              'Inviting: ${_selectedRecipient!.displayName}',
              style: context.appTypography.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed:
                _selectedRecipient == null || _submittingInvite ? null : _createInvite,
            child: _submittingInvite
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create invite'),
          ),
        ],
      ),
    );
  }
}

