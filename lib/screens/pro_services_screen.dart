import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';

class ProServicesScreen extends StatelessWidget {
  const ProServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('pro_services_title'.tr())),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: Text('pro_services_add'.tr()),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirebaseService().streamMyServices(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return _message(
              'pro_services_load_error'.tr(),
            );
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final services = snapshot.data!;
          if (services.isEmpty)
            return _message(
              'pro_services_empty'.tr(),
            );
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: services.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final service = services[index];
              final image = service['photoUrl'] as String? ?? '';
              return Card(
                child: ListTile(
                  leading: image.isEmpty
                      ? const CircleAvatar(child: Icon(Icons.handyman_outlined))
                      : CircleAvatar(backgroundImage: NetworkImage(image)),
                  title: Text(
                    service['name'] as String? ?? 'pro_services_default'.tr(),
                  ),
                  subtitle: Text(
                    '${service['description'] ?? ''}\n${_price(service['price'])} TND',
                    maxLines: 3,
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) async {
                      if (action == 'edit') {
                        await _edit(context, service);
                      } else if (action == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: Text('pro_services_delete_confirm'.tr()),
                            content: Text('pro_services_delete_warning'.tr()),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                child: Text('cancel'.tr()),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                child: Text('pro_services_delete'.tr()),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && context.mounted) {
                          try {
                            await FirebaseService().deleteMyService(
                              service['id'] as String,
                            );
                            _snack(context, 'pro_services_deleted'.tr());
                          } catch (e) {
                            _snack(context, _error(context, e));
                          }
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('pro_services_edit'.tr()),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('pro_services_delete'.tr()),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static Widget _message(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );

  static String _price(dynamic value) =>
      value is num ? value.toStringAsFixed(value % 1 == 0 ? 0 : 2) : '0';

  static String _error(BuildContext context, Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'pro_services_permission_error'.tr();
    }
    return 'pro_services_operation_error'.tr(args: [error.toString()]);
  }

  static void _snack(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  static Future<void> _edit(
    BuildContext context, [
    Map<String, dynamic>? existing,
  ]) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(
      text: existing?['name'] as String? ?? '',
    );
    final description = TextEditingController(
      text: existing?['description'] as String? ?? '',
    );
    final price = TextEditingController(
      text: existing?['price']?.toString() ?? '',
    );
    final photo = TextEditingController(
      text: existing?['photoUrl'] as String? ?? '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          existing == null
              ? 'pro_services_new'.tr()
              : 'pro_services_edit_title'.tr(),
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: InputDecoration(
                    labelText: 'pro_services_name'.tr(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'pro_services_required'.tr()
                      : null,
                ),
                TextFormField(
                  controller: description,
                  decoration: InputDecoration(
                    labelText: 'pro_services_description'.tr(),
                  ),
                  minLines: 2,
                  maxLines: 4,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'pro_services_required'.tr()
                      : null,
                ),
                TextFormField(
                  controller: price,
                  decoration: InputDecoration(
                    labelText: 'pro_services_price'.tr(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) =>
                      double.tryParse((v ?? '').replaceAll(',', '.')) == null
                      ? 'pro_services_invalid_price'.tr()
                      : null,
                ),
                TextFormField(
                  controller: photo,
                  decoration: InputDecoration(
                    labelText: 'pro_services_photo_url'.tr(),
                  ),
                  keyboardType: TextInputType.url,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate())
                Navigator.pop(dialogContext, true);
            },
            child: Text('save'.tr()),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      try {
        await FirebaseService().saveMyService(
          id: existing?['id'] as String?,
          name: name.text,
          description: description.text,
          price: double.parse(price.text.replaceAll(',', '.')),
          photoUrl: photo.text,
        );
        if (context.mounted) _snack(context, 'pro_services_saved'.tr());
      } catch (e) {
        if (context.mounted) _snack(context, _error(context, e));
      }
    }
    name.dispose();
    description.dispose();
    price.dispose();
    photo.dispose();
  }
}
