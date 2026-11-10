import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';

class ProServicesScreen extends StatelessWidget {
  const ProServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes services')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un service'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirebaseService().streamMyServices(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return _message(
              'Impossible de charger les services. Vérifiez la connexion et les règles Firestore.',
            );
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final services = snapshot.data!;
          if (services.isEmpty)
            return _message(
              'Aucun service pour le moment. Ajoutez votre première offre.',
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
                  title: Text(service['name'] as String? ?? 'Service'),
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
                            title: const Text('Supprimer ce service ?'),
                            content: const Text('Cette action est définitive.'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                child: const Text('Annuler'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                child: const Text('Supprimer'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && context.mounted) {
                          try {
                            await FirebaseService().deleteMyService(
                              service['id'] as String,
                            );
                            _snack(context, 'Service supprimé.');
                          } catch (e) {
                            _snack(context, _error(e));
                          }
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Modifier')),
                      PopupMenuItem(value: 'delete', child: Text('Supprimer')),
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

  static String _error(Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'Accès Firestore refusé : configurez les règles de la collection services.';
    }
    return 'Opération impossible : $error';
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
          existing == null ? 'Nouveau service' : 'Modifier le service',
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Nom du service',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Champ obligatoire'
                      : null,
                ),
                TextFormField(
                  controller: description,
                  decoration: const InputDecoration(labelText: 'Description'),
                  minLines: 2,
                  maxLines: 4,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Champ obligatoire'
                      : null,
                ),
                TextFormField(
                  controller: price,
                  decoration: const InputDecoration(labelText: 'Prix (TND)'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) =>
                      double.tryParse((v ?? '').replaceAll(',', '.')) == null
                      ? 'Entrez un prix valide'
                      : null,
                ),
                TextFormField(
                  controller: photo,
                  decoration: const InputDecoration(
                    labelText: 'URL de la photo (facultatif)',
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
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate())
                Navigator.pop(dialogContext, true);
            },
            child: const Text('Enregistrer'),
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
        if (context.mounted) _snack(context, 'Service enregistré.');
      } catch (e) {
        if (context.mounted) _snack(context, _error(e));
      }
    }
    name.dispose();
    description.dispose();
    price.dispose();
    photo.dispose();
  }
}
