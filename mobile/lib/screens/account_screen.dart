import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/offline_garden_store.dart';
import '../models/agro_supplier_models.dart';
import '../services/photo_picker.dart';

/// `/account` — Personal Account settings + Dedicated Farm Contact Book
/// (only 2 categories: Suppliers & Buyers/Clients, kept separate from personal phonebook).
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.store});

  final OfflineGardenStore store;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  FarmContactCategory _selectedCategory = FarmContactCategory.supplier;
  bool _showAddForm = false;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _itemsCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _areaCtrl.dispose();
    _itemsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickProfilePhoto() async {
    final picked = await pickPlantPhoto(PhotoPickMode.galleryOrFile);
    if (picked == null) return;
    await widget.store.updateProfilePhoto(picked.bytes);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated.')),
      );
    }
  }

  void _copyPhone(String phone) {
    Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Phone number copied: $phone')),
    );
  }

  void _saveContact() {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both contact name and phone number.')),
      );
      return;
    }
    final region = widget.store.activePlot?.regionName ?? 'Dodoma';
    final items = _itemsCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    widget.store.addCustomSupplier(
      name: name,
      regionName: region,
      townOrArea: _areaCtrl.text.trim().isEmpty ? region : _areaCtrl.text.trim(),
      phoneNumber: phone,
      inputsStocked: items.isEmpty
          ? (_selectedCategory == FarmContactCategory.supplier
              ? const ['DAP / CAN / Seeds']
              : const ['Vegetables / Harvest'])
          : items,
      category: _selectedCategory,
    );

    _nameCtrl.clear();
    _phoneCtrl.clear();
    _areaCtrl.clear();
    _itemsCtrl.clear();
    setState(() => _showAddForm = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final region = widget.store.activePlot?.regionName ?? 'Dodoma';
    final isSupplier = _selectedCategory == FarmContactCategory.supplier;

    return Scaffold(
      appBar: AppBar(title: const Text('My Account & Farm Contacts')),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final contacts = widget.store.contactsByCategory(_selectedCategory);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Account & Privacy Card (Google Sign-In ready)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Tooltip(
                            message: 'Upload profile photo',
                            child: InkWell(
                              onTap: _pickProfilePhoto,
                              borderRadius: BorderRadius.circular(32),
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: cs.primaryContainer,
                                    backgroundImage: widget.store.userPhotoBytes != null
                                        ? MemoryImage(widget.store.userPhotoBytes!)
                                        : (widget.store.userPhotoUrl != null &&
                                                widget.store.userPhotoUrl!.isNotEmpty
                                            ? NetworkImage(widget.store.userPhotoUrl!)
                                                as ImageProvider
                                            : null),
                                    child: (widget.store.userPhotoBytes == null &&
                                            (widget.store.userPhotoUrl == null ||
                                                widget.store.userPhotoUrl!.isEmpty))
                                        ? Icon(Icons.person_outline, color: cs.onPrimaryContainer)
                                        : null,
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: CircleAvatar(
                                      radius: 10,
                                      backgroundColor: cs.primary,
                                      child: Icon(Icons.camera_alt, size: 12, color: cs.onPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.store.userDisplayName ?? 'Personal Farm Account',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${widget.store.userEmail ?? "Signed in"} • Region: $region',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Free Pilot Trial — your plots, crop schedules, diagnosis photos, and farm contacts stay private to your account.',
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.store.signOut();
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Log Out'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Farm Contact Book Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Farm Contact Book',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => setState(() => _showAddForm = !_showAddForm),
                    icon: Icon(_showAddForm ? Icons.close : Icons.person_add_outlined),
                    label: Text(_showAddForm ? 'Cancel' : 'Add Contact'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Keep farm suppliers and harvest buyers separate from your personal phonebook.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),

              // 2 Categories Only: Suppliers & Buyers / Clients
              SegmentedButton<FarmContactCategory>(
                segments: const [
                  ButtonSegment(
                    value: FarmContactCategory.supplier,
                    icon: Icon(Icons.storefront_outlined),
                    label: Text('Suppliers'),
                  ),
                  ButtonSegment(
                    value: FarmContactCategory.buyer,
                    icon: Icon(Icons.shopping_bag_outlined),
                    label: Text('Buyers / Clients'),
                  ),
                ],
                selected: {_selectedCategory},
                onSelectionChanged: (sel) => setState(() => _selectedCategory = sel.first),
              ),

              if (_showAddForm) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSupplier ? 'New Supplier / Agro-Dealer' : 'New Buyer / Client',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(
                            labelText: isSupplier ? 'Supplier Name' : 'Buyer / Client Name',
                            hintText: isSupplier ? 'e.g., Mama Juma Agro-Vet' : 'e.g., Hassan — Kariakoo Tomatoes',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            hintText: 'e.g., 0712 345 678',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _areaCtrl,
                          decoration: InputDecoration(
                            labelText: 'Location / Market Area',
                            hintText: isSupplier ? 'e.g., Majengo, $region' : 'e.g., Kariakoo / Sabasaba',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _itemsCtrl,
                          decoration: InputDecoration(
                            labelText: isSupplier ? 'Inputs Supplied' : 'Crops They Buy',
                            hintText: isSupplier ? 'DAP, CAN, Urea, Seedlings' : 'Tomatoes, Peppers, Cucumber',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _saveContact,
                            child: Text(isSupplier ? 'Save Supplier' : 'Save Buyer / Client'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              if (contacts.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      isSupplier
                          ? 'No suppliers saved yet. Tap "Add Contact" to save your local agro-dealer.'
                          : 'No buyers saved yet. Save your Kariakoo, Dodoma, or Arusha buyers here so you never lose their numbers.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ...contacts.map(
                  (c) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${c.townOrArea}, ${c.regionName}\n'
                        '${isSupplier ? "Supplies" : "Buys"}: ${c.inputsStocked.join(", ")}',
                      ),
                      isThreeLine: true,
                      trailing: OutlinedButton.icon(
                        onPressed: () => _copyPhone(c.phoneNumber),
                        icon: const Icon(Icons.phone_outlined, size: 16),
                        label: const Text('Copy #'),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
