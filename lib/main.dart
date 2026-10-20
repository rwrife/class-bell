import 'package:dynamic_color/dynamic_color.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';

import 'state/roster_store.dart';
import 'state/tool_session.dart';
import 'ui/adaptive.dart';
import 'ui/roster_page.dart';
import 'ui/tool_input.dart';
import 'ui/tool_pages.dart';

void main() => runApp(const ClassBellApp());

class ClassBellApp extends StatefulWidget {
  const ClassBellApp({super.key, this.rosterStore});

  final RosterStore? rosterStore;

  @override
  State<ClassBellApp> createState() => _ClassBellAppState();
}

class _ClassBellAppState extends State<ClassBellApp> {
  late final RosterStore _store = widget.rosterStore ?? RosterStore();

  @override
  void dispose() {
    if (widget.rosterStore == null) _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shell = ClassBellShell(store: _store);
    // The root widget owns the platform seam; descendants never probe the
    // package-specific theme of whichever app shell was chosen here.
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return cupertino.CupertinoApp(
          title: 'Class Bell',
          debugShowCheckedModeBanner: false,
          home: AdaptiveScope(platform: BellPlatform.ios, child: shell),
        );
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return fluent.FluentApp(
          title: 'Class Bell',
          debugShowCheckedModeBanner: false,
          home: AdaptiveScope(platform: BellPlatform.windows, child: shell),
        );
      case TargetPlatform.android:
        // Material 3 with Android dynamic color when the OS supplies it;
        // falls back to the Class Bell seed otherwise (and on non-Android hosts).
        return DynamicColorBuilder(
          builder:
              (
                material.ColorScheme? lightDynamic,
                material.ColorScheme? darkDynamic,
              ) => material.MaterialApp(
                title: 'Class Bell',
                debugShowCheckedModeBanner: false,
                theme: material.ThemeData(
                  useMaterial3: true,
                  colorScheme:
                      lightDynamic ??
                      material.ColorScheme.fromSeed(
                        seedColor: const Color(0xFF315AA4),
                      ),
                ),
                darkTheme: material.ThemeData(
                  useMaterial3: true,
                  colorScheme:
                      darkDynamic ??
                      material.ColorScheme.fromSeed(
                        seedColor: const Color(0xFF315AA4),
                        brightness: Brightness.dark,
                      ),
                ),
                home: AdaptiveScope(
                  platform: BellPlatform.android,
                  child: shell,
                ),
              ),
        );
    }
  }
}

class ClassBellShell extends StatefulWidget {
  const ClassBellShell({required this.store, super.key});

  final RosterStore store;

  @override
  State<ClassBellShell> createState() => _ClassBellShellState();
}

class _ClassBellShellState extends State<ClassBellShell> {
  int _index = 0;
  late final ToolSession _session = ToolSession(widget.store);
  static const _labels = ['Classes', 'Timer', 'Picker', 'Praise', 'Quiet'];

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (_session.locked) return;
    setState(() => _index = index);
  }

  Widget _screen() => _index == 0
      ? RosterPage(store: widget.store)
      : ToolPage(index: _index, session: _session);

  Widget _projector() => PopScope(
    canPop: false,
    child: ToolInput(
      session: _session,
      onSelectTool: (tool) => setState(() => _index = tool),
      child: Stack(
        children: [
          Positioned.fill(
            child: ToolPage(index: _index, session: _session),
          ),
          Positioned(top: 0, right: 0, child: LockChip(session: _session)),
          Positioned(
            left: 10,
            bottom: 8,
            right: 10,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 6,
              children: [
                for (var i = 1; i <= 4; i++)
                  AdaptiveButton(
                    key: Key('projector-tool-$i'),
                    label: _labels[i],
                    onPressed: () => setState(() => _index = i),
                  ),
                if (!_session.locked)
                  AdaptiveButton(
                    key: const Key('leave-projector'),
                    label: 'Exit projector',
                    onPressed: _session.leaveProjector,
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _session,
    builder: (context, _) => _session.projector
        ? _projector()
        : ToolInput(
            session: _session,
            onSelectTool: _select,
            child: _normalShell(context),
          ),
  );

  Widget _normalShell(BuildContext context) {
    final platform = bellPlatform(context);
    final width = MediaQuery.sizeOf(context).width;
    if (platform == BellPlatform.windows) {
      return fluent.NavigationView(
        key: const Key('fluent-navigation'),
        pane: fluent.NavigationPane(
          displayMode: width >= 1008
              ? fluent.PaneDisplayMode.expanded
              : fluent.PaneDisplayMode.compact,
          selected: _index,
          onChanged: _select,
          header: const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Class Bell'),
          ),
          items: [
            fluent.PaneItem(
              icon: const Icon(fluent.FluentIcons.people),
              title: const Text('Classes'),
              body: _windowsPage(),
            ),
            fluent.PaneItem(
              icon: const Icon(fluent.FluentIcons.timer),
              title: const Text('Timer'),
              body: _windowsPage(),
            ),
            fluent.PaneItem(
              icon: const Icon(fluent.FluentIcons.contact),
              title: const Text('Picker'),
              body: _windowsPage(),
            ),
            fluent.PaneItem(
              icon: const Icon(fluent.FluentIcons.favorite_star),
              title: const Text('Praise'),
              body: _windowsPage(),
            ),
            fluent.PaneItem(
              icon: const Icon(fluent.FluentIcons.ringer_off),
              title: const Text('Quiet'),
              body: _windowsPage(),
            ),
          ],
        ),
      );
    }
    if (platform == BellPlatform.ios) {
      if (width >= 700) {
        return Row(
          key: const Key('tablet-sidebar'),
          children: [
            SizedBox(
              width: 240,
              child: SafeArea(
                right: false,
                child: ListView(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Class Bell',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    for (var i = 0; i < _labels.length; i++)
                      cupertino.CupertinoListTile(
                        title: Text(_labels[i]),
                        trailing: i == _index
                            ? const Icon(cupertino.CupertinoIcons.check_mark)
                            : null,
                        onTap: () => _select(i),
                      ),
                  ],
                ),
              ),
            ),
            const material.VerticalDivider(width: 1),
            Expanded(child: _iosPage()),
          ],
        );
      }
      return cupertino.CupertinoTabScaffold(
        key: const Key('cupertino-tabs'),
        tabBar: cupertino.CupertinoTabBar(
          currentIndex: _index,
          onTap: _select,
          items: const [
            cupertino.BottomNavigationBarItem(
              icon: Icon(cupertino.CupertinoIcons.person_2),
              label: 'Classes',
            ),
            cupertino.BottomNavigationBarItem(
              icon: Icon(cupertino.CupertinoIcons.timer),
              label: 'Timer',
            ),
            cupertino.BottomNavigationBarItem(
              icon: Icon(cupertino.CupertinoIcons.shuffle),
              label: 'Picker',
            ),
            cupertino.BottomNavigationBarItem(
              icon: Icon(cupertino.CupertinoIcons.heart),
              label: 'Praise',
            ),
            cupertino.BottomNavigationBarItem(
              icon: Icon(cupertino.CupertinoIcons.bell_slash),
              label: 'Quiet',
            ),
          ],
        ),
        tabBuilder: (context, index) =>
            cupertino.CupertinoTabView(builder: (_) => _iosPage()),
      );
    }
    return material.Scaffold(
      key: const Key('material-shell'),
      body: width >= 700
          ? Row(
              children: [
                material.NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: _select,
                  extended: width >= 1100,
                  destinations: const [
                    material.NavigationRailDestination(
                      icon: Icon(material.Icons.people_outline),
                      label: Text('Classes'),
                    ),
                    material.NavigationRailDestination(
                      icon: Icon(material.Icons.timer_outlined),
                      label: Text('Timer'),
                    ),
                    material.NavigationRailDestination(
                      icon: Icon(material.Icons.shuffle),
                      label: Text('Picker'),
                    ),
                    material.NavigationRailDestination(
                      icon: Icon(material.Icons.favorite_border),
                      label: Text('Praise'),
                    ),
                    material.NavigationRailDestination(
                      icon: Icon(material.Icons.notifications_off_outlined),
                      label: Text('Quiet'),
                    ),
                  ],
                ),
                const material.VerticalDivider(width: 1),
                Expanded(child: _androidPage()),
              ],
            )
          : _androidPage(),
      bottomNavigationBar: width < 700
          ? material.NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _select,
              destinations: const [
                material.NavigationDestination(
                  icon: Icon(material.Icons.people_outline),
                  label: 'Classes',
                ),
                material.NavigationDestination(
                  icon: Icon(material.Icons.timer_outlined),
                  label: 'Timer',
                ),
                material.NavigationDestination(
                  icon: Icon(material.Icons.shuffle),
                  label: 'Picker',
                ),
                material.NavigationDestination(
                  icon: Icon(material.Icons.favorite_border),
                  label: 'Praise',
                ),
                material.NavigationDestination(
                  icon: Icon(material.Icons.notifications_off_outlined),
                  label: 'Quiet',
                ),
              ],
            )
          : null,
    );
  }

  Widget _windowsPage() =>
      AdaptiveScaffold(title: _labels[_index], body: _screen());

  Widget _iosPage() => cupertino.CupertinoPageScaffold(
    child: CustomScrollView(
      slivers: [
        cupertino.CupertinoSliverNavigationBar(
          largeTitle: Text(_labels[_index]),
        ),
        SliverFillRemaining(child: _screen()),
      ],
    ),
  );

  Widget _androidPage() => Column(
    children: [
      material.AppBar(title: Text(_labels[_index])),
      Expanded(child: _screen()),
    ],
  );
}
