import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

// ===================== MODELOS E ESTADO =====================
class Contact {
  String id, name, email, phone, notes, city, company;
  DateTime? birthday;
  DateTime created;
  bool favorite;
  Set<String> categories;
  Uint8List? photo;
  Contact({
    required this.id,
    required this.name,
    this.email = '',
    this.phone = '',
    this.notes = '',
    this.city = '',
    this.company = '',
    this.birthday,
    DateTime? created,
    this.favorite = false,
    Set<String>? categories,
    this.photo,
  })  : created = created ?? DateTime.now(),
        categories = categories ?? {};
}

class AppState extends ChangeNotifier {
  final contacts = <Contact>[];
  final categories = <String>['Família', 'Amigos', 'Trabalho', 'Clientes'];
  final groups = <String, Set<String>>{}; // nome -> ids dos contatos
  bool dark = false, autoBackup = false, ascending = true;
  String userName = '';

  List<Contact> get sorted {
    final l = [...contacts];
    l.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return ascending ? l : l.reversed.toList();
  }

  void update() => notifyListeners();

  void save(Contact c) {
    final i = contacts.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      contacts[i] = c;
    } else {
      contacts.add(c);
    }
    notifyListeners();
  }

  void remove(Contact c) {
    contacts.removeWhere((x) => x.id == c.id);
    for (final g in groups.values) {
      g.remove(c.id);
    }
    notifyListeners();
  }
}

final app = AppState();

String fmt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

void go(BuildContext c, Widget w) =>
    Navigator.push(c, MaterialPageRoute(builder: (_) => w));

Widget avatar(Contact c, {double r = 22}) => CircleAvatar(
      radius: r,
      backgroundImage: c.photo != null ? MemoryImage(c.photo!) : null,
      child: c.photo == null
          ? Text(c.name.isEmpty ? '?' : c.name[0].toUpperCase())
          : null,
    );

int daysToBirthday(DateTime b) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  var next = DateTime(now.year, b.month, b.day);
  if (next.isBefore(today)) next = DateTime(now.year + 1, b.month, b.day);
  return next.difference(today).inDays;
}

// ===================== APP =====================
void main() {
  // Contatos de exemplo
  app.contacts.addAll([
    Contact(
        id: '1',
        name: 'Ana Souza',
        email: 'ana@email.com',
        phone: '(79) 99999-1111',
        city: 'Aracaju',
        company: 'Acme',
        birthday: DateTime(1995, DateTime.now().month, 15),
        categories: {'Amigos'},
        favorite: true),
    Contact(
        id: '2',
        name: 'Bruno Lima',
        email: 'bruno@email.com',
        phone: '(79) 98888-2222',
        city: 'Recife',
        company: 'Globex',
        categories: {'Trabalho', 'Clientes'}),
    Contact(
        id: '3',
        name: 'Carlos Pereira',
        email: 'carlos@email.com',
        phone: '(79) 97777-3333',
        city: 'Aracaju',
        categories: {'Família'}),
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (_, __) => MaterialApp(
          title: 'Agenda de Contatos',
          debugShowCheckedModeBanner: false,
          themeMode: app.dark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
              colorSchemeSeed: Colors.red,
              useMaterial3: true,
              brightness: Brightness.light),
          darkTheme: ThemeData(
              colorSchemeSeed: Colors.red,
              useMaterial3: true,
              brightness: Brightness.dark),
          home: const HomePage(),
        ),
      );
}

PreferredSizeWidget bar(String t, {List<Widget>? actions}) => AppBar(
      title: Text(t),
      centerTitle: true,
      backgroundColor: Colors.red,
      foregroundColor: Colors.white,
      actions: actions,
    );

// ===================== LISTA REUTILIZÁVEL (com busca) =====================
class ContactListBody extends StatefulWidget {
  final List<Contact> Function() source;
  final bool showSearch;
  const ContactListBody({super.key, required this.source, this.showSearch = true});
  @override
  State<ContactListBody> createState() => _ContactListBodyState();
}

class _ContactListBodyState extends State<ContactListBody> {
  String q = '';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (_, __) {
          final list = widget.source().where((c) {
            final s = q.toLowerCase();
            return c.name.toLowerCase().contains(s) ||
                c.email.toLowerCase().contains(s) ||
                c.phone.toLowerCase().contains(s);
          }).toList();
          return Column(children: [
            if (widget.showSearch)
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Buscar por nome, e-mail ou telefone',
                      border: OutlineInputBorder()),
                  onChanged: (v) => setState(() => q = v),
                ),
              ),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('Nenhum contato encontrado'))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final c = list[i];
                        return ListTile(
                          leading: avatar(c),
                          title: Text(c.name),
                          subtitle: Text(c.phone.isEmpty ? c.email : c.phone),
                          trailing: IconButton(
                            icon: Icon(
                                c.favorite ? Icons.star : Icons.star_border,
                                color: c.favorite ? Colors.amber : null),
                            onPressed: () {
                              c.favorite = !c.favorite;
                              app.update();
                            },
                          ),
                          onTap: () => go(context, DetailsPage(id: c.id)),
                        );
                      },
                    ),
            ),
          ]);
        },
      );
}

// ===================== 1. LISTAGEM =====================
class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    Widget item(IconData i, String t, Widget page) => ListTile(
        leading: Icon(i),
        title: Text(t),
        onTap: () {
          Navigator.pop(context);
          go(context, page);
        });
    return Scaffold(
      appBar: bar('Contatos'),
      drawer: Drawer(
        child: ListView(children: [
          const DrawerHeader(
              decoration: BoxDecoration(color: Colors.red),
              child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text('Agenda de Contatos',
                      style: TextStyle(color: Colors.white, fontSize: 24)))),
          item(Icons.star, 'Favoritos', const FavoritesPage()),
          item(Icons.label, 'Categorias', const CategoriesPage()),
          item(Icons.group, 'Grupos', const GroupsPage()),
          item(Icons.cake, 'Aniversários', const BirthdaysPage()),
          item(Icons.manage_search, 'Pesquisa avançada', const AdvancedSearchPage()),
          item(Icons.import_export, 'Importar / Exportar', const ImportExportPage()),
          item(Icons.settings, 'Configurações', const SettingsPage()),
        ]),
      ),
      body: ContactListBody(source: () => app.sorted),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        onPressed: () => go(context, const ContactFormPage()),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ===================== CADASTRO / 3. EDIÇÃO =====================
class ContactFormPage extends StatefulWidget {
  final Contact? contact;
  const ContactFormPage({super.key, this.contact});
  @override
  State<ContactFormPage> createState() => _ContactFormPageState();
}

class _ContactFormPageState extends State<ContactFormPage> {
  final _key = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.contact?.name);
  late final email = TextEditingController(text: widget.contact?.email);
  late final phone = TextEditingController(text: widget.contact?.phone);
  late final city = TextEditingController(text: widget.contact?.city);
  late final company = TextEditingController(text: widget.contact?.company);
  late final notes = TextEditingController(text: widget.contact?.notes);
  late DateTime? birthday = widget.contact?.birthday;
  late Set<String> cats = {...?widget.contact?.categories};
  late Uint8List? photo = widget.contact?.photo;

  Future<void> pickPhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x != null) {
      final b = await x.readAsBytes();
      setState(() => photo = b);
    }
  }

  void submit() {
    if (!_key.currentState!.validate()) return;
    final old = widget.contact;
    app.save(Contact(
      id: old?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.text.trim(),
      email: email.text.trim(),
      phone: phone.text.trim(),
      city: city.text.trim(),
      company: company.text.trim(),
      notes: notes.text.trim(),
      birthday: birthday,
      created: old?.created,
      favorite: old?.favorite ?? false,
      categories: cats,
      photo: photo,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.contact != null;
    return Scaffold(
      appBar: bar(editing ? 'Editar Contato' : 'Novo Contato',
          actions: [
            if (editing)
              IconButton(
                  tooltip: 'Cancelar',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
          ]),
      body: Form(
        key: _key,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          Center(
            child: GestureDetector(
              onTap: pickPhoto,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: photo != null ? MemoryImage(photo!) : null,
                child: photo == null ? const Icon(Icons.person, size: 60) : null,
              ),
            ),
          ),
          Center(
              child: TextButton(
                  onPressed: pickPhoto, child: const Text('Alterar foto'))),
          TextFormField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o nome' : null),
          TextFormField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email')),
          TextFormField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone')),
          TextFormField(
              controller: city,
              decoration: const InputDecoration(labelText: 'Cidade')),
          TextFormField(
              controller: company,
              decoration: const InputDecoration(labelText: 'Empresa')),
          TextFormField(
              controller: notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Observações')),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cake),
            title: Text(birthday == null
                ? 'Data de aniversário'
                : fmt(birthday!)),
            trailing: birthday == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => birthday = null)),
            onTap: () async {
              final d = await showDatePicker(
                  context: context,
                  initialDate: birthday ?? DateTime(2000),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now());
              if (d != null) setState(() => birthday = d);
            },
          ),
          const Text('Categorias'),
          Wrap(
            spacing: 8,
            children: app.categories
                .map((c) => FilterChip(
                      label: Text(c),
                      selected: cats.contains(c),
                      onSelected: (s) =>
                          setState(() => s ? cats.add(c) : cats.remove(c)),
                    ))
                .toList(),
          ),
          if (editing)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar alterações')),
            ),
          const SizedBox(height: 80),
        ]),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        onPressed: submit,
        child: const Icon(Icons.save),
      ),
    );
  }
}

// ===================== 2. DETALHES =====================
class DetailsPage extends StatelessWidget {
  final String id;
  const DetailsPage({super.key, required this.id});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (_, __) {
          final i = app.contacts.indexWhere((c) => c.id == id);
          if (i < 0) return const Scaffold(body: SizedBox());
          final c = app.contacts[i];
          Widget row(IconData ic, String t, String v) => v.isEmpty
              ? const SizedBox()
              : ListTile(leading: Icon(ic), title: Text(v), subtitle: Text(t));
          return Scaffold(
            appBar: bar('Detalhes', actions: [
              IconButton(
                  icon: Icon(c.favorite ? Icons.star : Icons.star_border),
                  onPressed: () {
                    c.favorite = !c.favorite;
                    app.update();
                  }),
              IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => go(context, ContactFormPage(contact: c))),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (d) => AlertDialog(
                      title: const Text('Excluir contato?'),
                      content: Text('Deseja excluir ${c.name}?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(d, false),
                            child: const Text('Cancelar')),
                        TextButton(
                            onPressed: () => Navigator.pop(d, true),
                            child: const Text('Excluir')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    app.remove(c);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            ]),
            body: ListView(children: [
              const SizedBox(height: 16),
              Center(child: avatar(c, r: 55)),
              Center(
                  child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(c.name,
                    style: Theme.of(context).textTheme.headlineSmall),
              )),
              row(Icons.phone, 'Telefone', c.phone),
              row(Icons.email, 'E-mail', c.email),
              row(Icons.location_city, 'Cidade', c.city),
              row(Icons.business, 'Empresa', c.company),
              row(Icons.cake, 'Aniversário',
                  c.birthday == null ? '' : fmt(c.birthday!)),
              row(Icons.notes, 'Observações', c.notes),
              row(Icons.event, 'Cadastrado em', fmt(c.created)),
              if (c.categories.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                      spacing: 8,
                      children: c.categories
                          .map((e) => Chip(label: Text(e)))
                          .toList()),
                ),
            ]),
          );
        },
      );
}

// ===================== 4. FAVORITOS =====================
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: bar('Favoritos'),
        body: ContactListBody(
            source: () => app.sorted.where((c) => c.favorite).toList(),
            showSearch: false),
      );
}

// ===================== 5. CATEGORIAS =====================
class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (_, __) => Scaffold(
          appBar: bar('Categorias'),
          body: ListView(
            children: app.categories.map((cat) {
              final n = app.contacts.where((c) => c.categories.contains(cat)).length;
              return ListTile(
                leading: const Icon(Icons.label),
                title: Text(cat),
                subtitle: Text('$n contato(s)'),
                trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      app.categories.remove(cat);
                      for (final c in app.contacts) {
                        c.categories.remove(cat);
                      }
                      app.update();
                    }),
                onTap: () => go(
                    context,
                    Scaffold(
                      appBar: bar(cat),
                      body: ContactListBody(
                          source: () => app.sorted
                              .where((c) => c.categories.contains(cat))
                              .toList(),
                          showSearch: false),
                    )),
              );
            }).toList(),
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            onPressed: () async {
              final t = await askText(context, 'Nova categoria');
              if (t != null && t.isNotEmpty && !app.categories.contains(t)) {
                app.categories.add(t);
                app.update();
              }
            },
            child: const Icon(Icons.add),
          ),
        ),
      );
}

Future<String?> askText(BuildContext context, String title) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: TextField(controller: ctrl, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
        TextButton(
            onPressed: () => Navigator.pop(d, ctrl.text.trim()),
            child: const Text('Salvar')),
      ],
    ),
  );
}

// ===================== 6. GRUPOS =====================
class GroupsPage extends StatelessWidget {
  const GroupsPage({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (_, __) => Scaffold(
          appBar: bar('Grupos'),
          body: app.groups.isEmpty
              ? const Center(child: Text('Nenhum grupo criado'))
              : ListView(
                  children: app.groups.keys
                      .map((g) => ListTile(
                            leading: const Icon(Icons.group),
                            title: Text(g),
                            subtitle: Text('${app.groups[g]!.length} membro(s)'),
                            trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  app.groups.remove(g);
                                  app.update();
                                }),
                            onTap: () => go(context, GroupMembersPage(group: g)),
                          ))
                      .toList()),
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            onPressed: () async {
              final t = await askText(context, 'Novo grupo');
              if (t != null && t.isNotEmpty) {
                app.groups.putIfAbsent(t, () => <String>{});
                app.update();
              }
            },
            child: const Icon(Icons.add),
          ),
        ),
      );
}

class GroupMembersPage extends StatelessWidget {
  final String group;
  const GroupMembersPage({super.key, required this.group});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (_, __) {
          final members = app.groups[group] ?? <String>{};
          return Scaffold(
            appBar: bar(group),
            body: ListView(
              children: app.sorted
                  .map((c) => CheckboxListTile(
                        secondary: avatar(c),
                        title: Text(c.name),
                        value: members.contains(c.id),
                        onChanged: (v) {
                          v == true ? members.add(c.id) : members.remove(c.id);
                          app.update();
                        },
                      ))
                  .toList(),
            ),
          );
        },
      );
}

// ===================== 7. ANIVERSÁRIOS =====================
class BirthdaysPage extends StatelessWidget {
  const BirthdaysPage({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (_, __) {
          final withBday = app.contacts.where((c) => c.birthday != null).toList();
          final month = withBday
              .where((c) => c.birthday!.month == DateTime.now().month)
              .toList()
            ..sort((a, b) => a.birthday!.day.compareTo(b.birthday!.day));
          final soon = withBday
              .where((c) => daysToBirthday(c.birthday!) <= 7)
              .toList()
            ..sort((a, b) => daysToBirthday(a.birthday!)
                .compareTo(daysToBirthday(b.birthday!)));
          Widget head(String t) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(t, style: Theme.of(context).textTheme.titleMedium));
          return Scaffold(
            appBar: bar('Aniversários'),
            body: ListView(children: [
              head('Lembretes (próximos 7 dias)'),
              if (soon.isEmpty)
                const ListTile(title: Text('Nenhum aniversário próximo')),
              ...soon.map((c) {
                final d = daysToBirthday(c.birthday!);
                return Card(
                  color: Colors.amber.shade100,
                  child: ListTile(
                    leading: const Icon(Icons.notifications_active,
                        color: Colors.orange),
                    title: Text(c.name,
                        style: const TextStyle(color: Colors.black)),
                    subtitle: Text(
                        d == 0 ? 'É hoje! 🎉' : 'Faltam $d dia(s)',
                        style: const TextStyle(color: Colors.black87)),
                  ),
                );
              }),
              head('Aniversariantes do mês'),
              if (month.isEmpty)
                const ListTile(title: Text('Ninguém faz aniversário este mês')),
              ...month.map((c) => ListTile(
                    leading: avatar(c),
                    title: Text(c.name),
                    subtitle: Text(
                        '${c.birthday!.day.toString().padLeft(2, '0')}/${c.birthday!.month.toString().padLeft(2, '0')}'),
                    onTap: () => go(context, DetailsPage(id: c.id)),
                  )),
            ]),
          );
        },
      );
}

// ===================== 8. PESQUISA AVANÇADA =====================
class AdvancedSearchPage extends StatefulWidget {
  const AdvancedSearchPage({super.key});
  @override
  State<AdvancedSearchPage> createState() => _AdvancedSearchPageState();
}

class _AdvancedSearchPageState extends State<AdvancedSearchPage> {
  String? cat;
  String city = '', company = '';
  DateTimeRange? range;

  @override
  Widget build(BuildContext context) {
    final res = app.sorted.where((c) {
      if (cat != null && !c.categories.contains(cat)) return false;
      if (city.isNotEmpty && !c.city.toLowerCase().contains(city.toLowerCase())) {
        return false;
      }
      if (company.isNotEmpty &&
          !c.company.toLowerCase().contains(company.toLowerCase())) {
        return false;
      }
      if (range != null &&
          (c.created.isBefore(range!.start) ||
              c.created.isAfter(range!.end.add(const Duration(days: 1))))) {
        return false;
      }
      return true;
    }).toList();
    return Scaffold(
      appBar: bar('Pesquisa Avançada'),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            DropdownButtonFormField<String?>(
              value: cat,
              decoration: const InputDecoration(labelText: 'Categoria'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todas')),
                ...app.categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c))),
              ],
              onChanged: (v) => setState(() => cat = v),
            ),
            TextField(
                decoration: const InputDecoration(labelText: 'Cidade'),
                onChanged: (v) => setState(() => city = v)),
            TextField(
                decoration: const InputDecoration(labelText: 'Empresa'),
                onChanged: (v) => setState(() => company = v)),
            Row(children: [
              Expanded(
                  child: Text(range == null
                      ? 'Data de cadastro: qualquer'
                      : '${fmt(range!.start)} - ${fmt(range!.end)}')),
              TextButton(
                  onPressed: () async {
                    final r = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (r != null) setState(() => range = r);
                  },
                  child: const Text('Período')),
              if (range != null)
                IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => range = null)),
            ]),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
              children: res
                  .map((c) => ListTile(
                        leading: avatar(c),
                        title: Text(c.name),
                        subtitle: Text(
                            [c.city, c.company].where((e) => e.isNotEmpty).join(' • ')),
                        onTap: () => go(context, DetailsPage(id: c.id)),
                      ))
                  .toList()),
        ),
      ]),
    );
  }
}

// ===================== 9. IMPORTAR / EXPORTAR =====================
class ImportExportPage extends StatefulWidget {
  const ImportExportPage({super.key});
  @override
  State<ImportExportPage> createState() => _ImportExportPageState();
}

class _ImportExportPageState extends State<ImportExportPage> {
  final importCtrl = TextEditingController();
  String exported = '';
  String clean(String s) => s.replaceAll(',', ' ').replaceAll('\n', ' ');

  void doExport() {
    final b = StringBuffer('nome,email,telefone,cidade,empresa,observacoes,aniversario\n');
    for (final c in app.sorted) {
      b.writeln([
        c.name,
        c.email,
        c.phone,
        c.city,
        c.company,
        c.notes,
        c.birthday == null ? '' : c.birthday!.toIso8601String().substring(0, 10)
      ].map(clean).join(','));
    }
    setState(() => exported = b.toString());
  }

  void doImport() {
    final lines = importCtrl.text.trim().split('\n');
    var n = 0;
    for (final l in lines) {
      final p = l.split(',').map((e) => e.trim()).toList();
      if (p.isEmpty || p[0].isEmpty || p[0].toLowerCase() == 'nome') continue;
      String g(int i) => i < p.length ? p[i] : '';
      app.contacts.add(Contact(
        id: '${DateTime.now().microsecondsSinceEpoch}$n',
        name: g(0),
        email: g(1),
        phone: g(2),
        city: g(3),
        company: g(4),
        notes: g(5),
        birthday: DateTime.tryParse(g(6)),
      ));
      n++;
    }
    app.update();
    importCtrl.clear();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$n contato(s) importado(s)')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: bar('Importar / Exportar'),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          Text('Importar (CSV)', style: Theme.of(context).textTheme.titleMedium),
          const Text(
              'Cole o conteúdo do arquivo CSV (abra o Excel e salve como CSV). '
              'Colunas: nome,email,telefone,cidade,empresa,observacoes,aniversario(AAAA-MM-DD)'),
          TextField(
              controller: importCtrl,
              maxLines: 6,
              decoration: const InputDecoration(border: OutlineInputBorder())),
          const SizedBox(height: 8),
          ElevatedButton.icon(
              onPressed: doImport,
              icon: const Icon(Icons.upload),
              label: const Text('Importar')),
          const Divider(height: 32),
          Text('Exportar (backup)', style: Theme.of(context).textTheme.titleMedium),
          ElevatedButton.icon(
              onPressed: doExport,
              icon: const Icon(Icons.download),
              label: const Text('Gerar CSV')),
          if (exported.isNotEmpty) ...[
            Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(border: Border.all()),
                child: SelectableText(exported)),
            OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: exported));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copiado! Cole em um arquivo .csv')));
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copiar')),
          ],
        ]),
      );
}

// ===================== 10. CONFIGURAÇÕES =====================
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (_, __) => Scaffold(
          appBar: bar('Configurações'),
          body: ListView(children: [
            SwitchListTile(
              secondary: const Icon(Icons.dark_mode),
              title: const Text('Tema escuro'),
              value: app.dark,
              onChanged: (v) {
                app.dark = v;
                app.update();
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.backup),
              title: const Text('Backup automático'),
              subtitle: const Text('Lembrar de exportar os contatos periodicamente'),
              value: app.autoBackup,
              onChanged: (v) {
                app.autoBackup = v;
                app.update();
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.sort_by_alpha),
              title: const Text('Ordem alfabética (A-Z)'),
              value: app.ascending,
              onChanged: (v) {
                app.ascending = v;
                app.update();
              },
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextFormField(
                initialValue: app.userName,
                decoration: const InputDecoration(
                    labelText: 'Seu nome', border: OutlineInputBorder()),
                onChanged: (v) => app.userName = v,
              ),
            ),
          ]),
        ),
      );
}