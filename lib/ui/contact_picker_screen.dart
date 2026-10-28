import 'package:flutter/material.dart';
import '../services/contacts_service.dart';
import '../services/family_board_service.dart';
import '../services/localization.dart';
import '../theme/app_theme.dart';

class ContactPickerScreen extends StatefulWidget {
  final List<FamilyMember> existingMembers;

  const ContactPickerScreen({
    super.key,
    required this.existingMembers,
  });

  @override
  State<ContactPickerScreen> createState() => _ContactPickerScreenState();
}

class _ContactPickerScreenState extends State<ContactPickerScreen> {
  final _contactsService = ContactsService();
  final _searchController = TextEditingController();

  List<ContactEntry> _allContacts = [];
  List<ContactEntry> _filteredContacts = [];
  final Set<String> _selectedPhoneKeys = {};
  late final Set<String> _existingPhoneKeys;

  bool _loading = true;
  bool _permissionDenied = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _existingPhoneKeys = widget.existingMembers
        .map((m) => _normalizePhone(m.phone))
        .where((p) => p.isNotEmpty)
        .toSet();
    _loadContacts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^\d+]'), '');
  }

  Future<void> _loadContacts() async {
    setState(() {
      _loading = true;
      _permissionDenied = false;
    });

    final hasPerm = await _contactsService.hasPermission();
    if (!hasPerm) {
      final granted = await _contactsService.requestPermission();
      if (!granted) {
        if (mounted) {
          setState(() {
            _loading = false;
            _permissionDenied = true;
          });
        }
        return;
      }
    }

    final contacts = await _contactsService.getContacts();
    if (mounted) {
      setState(() {
        _allContacts = contacts;
        _filterContacts();
        _loading = false;
      });
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
      _filterContacts();
    });
  }

  void _filterContacts() {
    if (_searchQuery.isEmpty) {
      _filteredContacts = List.from(_allContacts);
    } else {
      _filteredContacts = _allContacts.where((c) {
        final matchesName = c.name.toLowerCase().contains(_searchQuery);
        final matchesPhone = c.phone.contains(_searchQuery);
        return matchesName || matchesPhone;
      }).toList();
    }
  }

  void _toggleSelect(ContactEntry contact) {
    final key = _normalizePhone(contact.phone);
    setState(() {
      if (_selectedPhoneKeys.contains(key)) {
        _selectedPhoneKeys.remove(key);
      } else {
        _selectedPhoneKeys.add(key);
      }
    });
  }

  void _selectAll() {
    setState(() {
      for (final c in _filteredContacts) {
        final key = _normalizePhone(c.phone);
        if (!_existingPhoneKeys.contains(key)) {
          _selectedPhoneKeys.add(key);
        }
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedPhoneKeys.clear();
    });
  }

  void _confirmSelection() {
    final selectedContacts = _allContacts.where((c) {
      final key = _normalizePhone(c.phone);
      return _selectedPhoneKeys.contains(key) && !_existingPhoneKeys.contains(key);
    }).toList();

    Navigator.pop(context, selectedContacts);
  }

  @override
  Widget build(BuildContext context) {
    final hi = AppLang.hindi;
    final selectedCount = _selectedPhoneKeys.length;

    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        title: Text(
          hi ? 'संपर्क से चुनें' : 'SELECT FROM CONTACTS',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        actions: [
          if (!_loading && !_permissionDenied && _filteredContacts.isNotEmpty)
            TextButton(
              onPressed: selectedCount > 0 ? _clearSelection : _selectAll,
              child: Text(
                selectedCount > 0 ? (hi ? 'हटाएं' : 'Clear') : (hi ? 'सभी चुनें' : 'Select All'),
                style: const TextStyle(color: AppTheme.saffronLight, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _buildBody(hi),
      bottomNavigationBar: !_loading && !_permissionDenied
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  border: Border(top: BorderSide(color: AppTheme.surfaceLight)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hi ? '$selectedCount संपर्क चुने गए' : '$selectedCount contact${selectedCount == 1 ? "" : "s"} selected',
                            style: const TextStyle(
                              color: AppTheme.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            hi ? 'परिवार बोर्ड में जोड़ने के लिए' : 'To add to Family Board',
                            style: const TextStyle(color: AppTheme.grey, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedCount > 0 ? AppTheme.saffron : AppTheme.surfaceLight,
                        foregroundColor: selectedCount > 0 ? AppTheme.navy : AppTheme.grey,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: selectedCount > 0 ? _confirmSelection : null,
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(
                        hi ? 'जोड़ें ($selectedCount)' : 'Import ($selectedCount)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(bool hi) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.saffronLight));
    }

    if (_permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.contact_phone_outlined, size: 60, color: AppTheme.saffron),
              const SizedBox(height: 16),
              Text(
                hi ? 'संपर्क अनुमति की आवश्यकता है' : 'Contacts Permission Needed',
                style: const TextStyle(color: AppTheme.white, fontSize: 17, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                hi
                    ? 'अपने परिवार के नंबर आसानी से चुनने के लिए संपर्क पढ़ने की अनुमति दें।'
                    : 'Grant contact read permission to quickly import and monitor your family members without typing.',
                style: const TextStyle(color: AppTheme.grey, fontSize: 13, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadContacts,
                icon: const Icon(Icons.security, size: 18),
                label: Text(hi ? 'अनुमति दें' : 'Grant Permission'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.all(12),
          color: AppTheme.surface,
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: AppTheme.white),
            decoration: InputDecoration(
              hintText: hi ? 'नाम या नंबर खोजें…' : 'Search name or phone…',
              hintStyle: const TextStyle(color: AppTheme.grey),
              prefixIcon: const Icon(Icons.search, color: AppTheme.saffronLight),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppTheme.grey),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.navy,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        // List
        Expanded(
          child: _filteredContacts.isEmpty
              ? Center(
                  child: Text(
                    hi ? 'कोई संपर्क नहीं मिला' : 'No contacts found',
                    style: const TextStyle(color: AppTheme.grey),
                  ),
                )
              : ListView.separated(
                  itemCount: _filteredContacts.length,
                  separatorBuilder: (_, __) => const Divider(color: AppTheme.surfaceLight, height: 1),
                  itemBuilder: (context, index) {
                    final contact = _filteredContacts[index];
                    final key = _normalizePhone(contact.phone);
                    final isAlreadyAdded = _existingPhoneKeys.contains(key);
                    final isSelected = _selectedPhoneKeys.contains(key);

                    return InkWell(
                      onTap: isAlreadyAdded ? null : () => _toggleSelect(contact),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        color: isSelected
                            ? AppTheme.saffronLight.withValues(alpha: 0.08)
                            : Colors.transparent,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: isAlreadyAdded
                                  ? AppTheme.grey.withValues(alpha: 0.2)
                                  : isSelected
                                      ? AppTheme.saffron.withValues(alpha: 0.25)
                                      : AppTheme.tealLight.withValues(alpha: 0.15),
                              child: Text(
                                contact.initials,
                                style: TextStyle(
                                  color: isAlreadyAdded
                                      ? AppTheme.grey
                                      : isSelected
                                          ? AppTheme.saffronLight
                                          : AppTheme.tealLight,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    contact.name,
                                    style: TextStyle(
                                      color: isAlreadyAdded ? AppTheme.grey : AppTheme.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    contact.phone,
                                    style: const TextStyle(
                                      color: AppTheme.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isAlreadyAdded)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  hi ? 'पहले से मौजूद' : 'Already in Family',
                                  style: const TextStyle(color: AppTheme.green, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              )
                            else
                              Checkbox(
                                value: isSelected,
                                activeColor: AppTheme.saffron,
                                checkColor: AppTheme.navy,
                                onChanged: (_) => _toggleSelect(contact),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
