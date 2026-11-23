import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/offline_garden_store.dart';
import '../models/agro_supplier_models.dart';

/// Opens the Farm Contact Book (Suppliers & Buyers/Clients) + Agro-Dealer Search sheet.
/// Keeps farm contacts cleanly separated from the user's personal phonebook.
Future<void> showAgroSupplierSheet(
  BuildContext context, {
  required OfflineGardenStore store,
  String? recommendedInput,
  FarmContactCategory initialCategory = FarmContactCategory.supplier,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _AgroSupplierSheetBody(
      store: store,
      recommendedInput: recommendedInput,
      initialCategory: initialCategory,
    ),
  );
}

class _AgroSupplierSheetBody extends StatefulWidget {
  const _AgroSupplierSheetBody({
    required this.store,
    this.recommendedInput,
    required this.initialCategory,
  });

  final OfflineGardenStore store;
  final String? recommendedInput;
  final FarmContactCategory initialCategory;

  @override
  State<_AgroSupplierSheetBody> createState() => _AgroSupplierSheetBodyState();
}

class _AgroSupplierSheetBodyState extends State<_AgroSupplierSheetBody> {
  late FarmContactCategory _selectedCategory;
  bool _showAddForm = false;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _itemsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _areaCtrl.dispose();
    _itemsCtrl.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  void _saveContact() {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the contact name and phone number.')),
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
    final searchQuery = buildAgroSupplierSearchQuery(
      regionName: region,
      inputNeeded: widget.recommendedInput,
    );
    final callScript = buildPriceCheckScript(
      inputNeeded: widget.recommendedInput,
      regionName: region,
    );

    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final contacts = widget.store.contactsByCategory(_selectedCategory);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.contacts_outlined, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Farm Contacts ($region)',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => setState(() => _showAddForm = !_showAddForm),
                      icon: Icon(_showAddForm ? Icons.close : Icons.person_add_outlined),
                      label: Text(_showAddForm ? 'Cancel' : 'Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Two-category switcher: Suppliers vs. Buyers / Clients
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<FarmContactCategory>(
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
                ),

                if (isSupplier &&
                    widget.recommendedInput != null &&
                    widget.recommendedInput!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Chip(
                    avatar: const Icon(Icons.inventory_2_outlined, size: 16),
                    label: Text('Looking for: ${widget.recommendedInput}'),
                  ),
                ],

                if (isSupplier) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Call Before You Travel (Price & Stock Check)',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Copy message',
                              icon: const Icon(Icons.copy, size: 18),
                              onPressed: () => _copyToClipboard(callScript, 'Price-check message'),
                            ),
                          ],
                        ),
                        Text(callScript, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],

                if (_showAddForm) ...[
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSupplier ? 'Save Agro-Dealer / Supplier' : 'Save Buyer / Client',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _nameCtrl,
                            decoration: InputDecoration(
                              labelText: isSupplier ? 'Supplier / Agro-Dealer Name' : 'Buyer / Client Name',
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
                              labelText: 'Market / Town / Area',
                              hintText: isSupplier ? 'e.g., Majengo, $region' : 'e.g., Kariakoo / Sabasaba',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _itemsCtrl,
                            decoration: InputDecoration(
                              labelText: isSupplier ? 'Inputs Stocked' : 'Crops They Buy',
                              hintText: isSupplier
                                  ? 'DAP, CAN, Urea, NPK, Seedlings'
                                  : 'Tomatoes, Peppers, Cucumber',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _saveContact,
                              child: Text(isSupplier ? 'Save Supplier Contact' : 'Save Buyer Contact'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                Text(
                  isSupplier
                      ? 'Saved & Regional Suppliers (${contacts.length})'
                      : 'Saved Buyers & Clients (${contacts.length})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                if (contacts.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            isSupplier
                                ? 'No suppliers saved yet. Tap "Add" to save your local agro-dealer.'
                                : 'No buyers saved yet. Save your market buyers (e.g. Kariakoo, Dodoma, Arusha) here so you never lose their number in your personal phonebook.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...contacts.map(
                    (sup) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    sup.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (sup.isUserAdded)
                                  Chip(
                                    label: Text(isSupplier ? 'My Supplier' : 'My Buyer'),
                                    visualDensity: VisualDensity.compact,
                                  )
                                else if (sup.isDemoPlaceholder)
                                  const Chip(
                                    label: Text('Sample'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                            Text(
                              '${sup.townOrArea}, ${sup.regionName}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${isSupplier ? "Stocks" : "Buys"}: ${sup.inputsStocked.join(", ")}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (sup.notes != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                sup.notes!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            FilledButton.tonalIcon(
                              onPressed: () => _copyToClipboard(sup.phoneNumber, 'Phone number'),
                              icon: const Icon(Icons.phone_outlined, size: 18),
                              label: Text(sup.phoneNumber),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                if (isSupplier) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _copyToClipboard(searchQuery, 'Google search query'),
                    icon: const Icon(Icons.search),
                    label: Text('Copy Google Search: "$searchQuery"'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
