// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:dice_reader/model/user.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dice_reader/pixel_calls/pixel_calls.dart';
import 'dart:convert' as convert;

Future main() async{
  WidgetsFlutterBinding.ensureInitialized();

  runApp(MyApp());
}

// Add this class near the top of the file
class RollHistory {
  final int total;
  final int roll;
  final int bonus;
  final String rollType;
  final DateTime timestamp;

  RollHistory({
    required this.total,
    required this.roll,
    required this.bonus,
    required this.rollType,
    required this.timestamp,
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'Roll Bonuses',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
            brightness: Brightness.dark,  // Dark theme
            primary: Colors.green[700],   // Darker green
          ),
        ),
        home: MyHomePage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  var history = <RollHistory>[];  // Initialize as empty RollHistory list
  var rollTotal = 0;
  var rollBonus = 0;
  Sse? _sse;
  StreamSubscription<String>? _sseStreamSubscription;
  String buttonText = 'No roll selected: ';

  GlobalKey? historyListKey;

  int _retryCount = 0;
  static const int maxRetries = 5;
  
  bool isConnected = false;
  String connectionStatus = 'Connecting...';
  
  RollBonuses? _currentBonuses;
  bool _isLoadingBonuses = false;
  String _bonusError = '';

  // Local health state (derived from sheet max values on first load)
  int currentHp = 0;
  int currentTempHp = 0;
  bool _healthInitialized = false;

  DateTime? _lastBonusRefresh;
  static const Duration refreshInterval = Duration(minutes: 2);  // Adjust as needed

  static const int maxHistoryLength = 12;

  MyAppState() {
    connectToSse();
    refreshBonuses();  // Prefetch bonuses immediately
  }

  void removeFromHistory(RollHistory rollHistory) {
    history.remove(rollHistory);
    notifyListeners();
  }

  void updateBonus(var bonus, String newText) {
    rollBonus = bonus;
    buttonText = newText;
    print('Updated bonus to : $rollBonus'); // Debug Log
    notifyListeners();
  }

  Future<void> refreshBonuses() async {
    print('Starting refresh. Current bonuses: $_currentBonuses');
    print('Last refresh: $_lastBonusRefresh');
    
    if (_lastBonusRefresh != null && 
        DateTime.now().difference(_lastBonusRefresh!) < refreshInterval) {
      print('Using cached bonuses, skipping refresh');
      return;
    }

    _isLoadingBonuses = true;
    _bonusError = '';
    notifyListeners();

    try {
      const url = 'https://script.google.com/macros/s/AKfycbyNawZh2ZHKJqdJH0YwzlbvPSXU17AHyVEbPam0GLY7uo47foP8bogbcTDl637PaMCC/exec';
      print('Fetching bonuses from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Connection timed out. Please check your internet connection.');
        },
      );
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty || (!body.startsWith('{') && !body.startsWith('['))) {
          _bonusError = 'Google Script returned an error page instead of data. Check your script (e.g. getSheetByName).';
          print('Response is not JSON (starts with: ${body.length > 50 ? body.substring(0, 50) : body})');
        } else {
          try {
            final jsonBonuses = convert.jsonDecode(response.body) as Map<String, dynamic>;
            _currentBonuses = RollBonuses.fromJson(jsonBonuses);
            _syncHealthFromBonuses();
            _lastBonusRefresh = DateTime.now();
            print('Successfully updated bonuses: $_currentBonuses');
          } on FormatException catch (e) {
            _bonusError = 'Google Script returned invalid data. Check your script.';
            print('JSON parse error: $e');
          }
        }
      } else if (response.statusCode == 403) {
        _bonusError = 'Access denied: Google Script not publicly accessible. Check script deployment settings.';
        print('403 Error: Google Apps Script access denied. Ensure the script is deployed with "Anyone" access.');
      } else {
        _bonusError = 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      print('Error refreshing bonuses: $e');
      _bonusError = 'Error: $e';
    } finally {
      _isLoadingBonuses = false;
      notifyListeners();
    }
  }

  int get maxHp => _currentBonuses?.maxHp ?? 0;
  int get maxTempHp => _currentBonuses?.maxTempHp ?? 0;

  void _syncHealthFromBonuses() {
    final maxHpLocal = maxHp;
    final maxTempLocal = maxTempHp;

    if (!_healthInitialized) {
      currentHp = maxHpLocal;
      currentTempHp = maxTempLocal;
      _healthInitialized = true;
      return;
    }

    // If max values change, clamp current values so they remain valid.
    if (maxHpLocal > 0) {
      currentHp = currentHp.clamp(0, maxHpLocal);
    }
    if (maxTempLocal > 0) {
      currentTempHp = currentTempHp.clamp(0, maxTempLocal);
    }
  }

  void applyHpChange(int delta) {
    if (maxHp <= 0) return;
    if (delta == 0) return;

    currentHp = (currentHp + delta).clamp(0, maxHp);
    notifyListeners();
  }

  void applyTempHpChange(int delta) {
    if (maxTempHp <= 0) return;
    if (delta == 0) return;

    currentTempHp = (currentTempHp + delta).clamp(0, maxTempHp);
    notifyListeners();
  }

  void applyHealthChange(int delta) {
    if (maxHp <= 0 && maxTempHp <= 0) return; // Why prevent adjustments when maxHp and maxTempHp are 0?
    if (delta == 0) return;

    if (delta > 0) {
      final healed = delta;
      currentHp = (currentHp + healed).clamp(0, maxHp);
      notifyListeners();
      return;
    }

    var dmg = -delta; // flip negative delta into positive damage amount

    // Temp HP first
    final tempUsed = dmg.clamp(0, currentTempHp); // What happens when currentTempHp is 0?
    currentTempHp -= tempUsed;
    dmg -= tempUsed;

    // Remaining to HP
    if (dmg > 0) {
      currentHp = (currentHp - dmg).clamp(0, maxHp);
    }

    notifyListeners();
  }

  void handleBonusAndText(int value) async {
    // Update UI immediately with loading state
    buttonText = 'Loading...';
    rollTotal = 0;  // Reset the roll total when a new button is pressed
    notifyListeners();
    
    // Refresh bonuses in background
    await refreshBonuses();
    
    if (_bonusError.isNotEmpty) {
      print('Error refreshing bonuses: $_bonusError');
      return;
    }

    final bonuses = _currentBonuses;
    if (bonuses == null) {
      print('No bonuses available');
      return;
    }

    // Update with actual bonus
    switch (value) {
      case 0:
        updateBonus(0, 'No Bonus: ');
      case 1:
        updateBonus(bonuses.attackBonus, 'Attack Roll: ');
      case 2:
        updateBonus(bonuses.casterLevel, 'Caster Level: ');
      case 3:
        updateBonus(bonuses.fortBonus, 'Fortitude Save: ');
      case 4:
        updateBonus(bonuses.reflexBonus, 'Reflex Save: ');
      case 5:
        updateBonus(bonuses.willBonus, 'Will Save: ');
    }
  }

  void connectToSse() async {
    connectionStatus = 'Connecting...';
    print("Connecting to SSE....");
    notifyListeners();
    
    final sseUri = Uri.parse('http://10.211.117.249:8080/listen');
    try {
      if (_sseStreamSubscription != null) {
        await _sseStreamSubscription!.cancel();
      }
      
      _sse = await Sse.connect(uri: sseUri);
      isConnected = true;
      connectionStatus = 'Connected';
      print('!!!!Connected to SSE!!!!');
      notifyListeners();
      _retryCount = 0;
      
      _sseStreamSubscription = _sse!.stream.listen(
        (String eventData) {
          try {
            print('Received event data: $eventData');
            Map<String, dynamic> eventDataMap = convert.jsonDecode(eventData);
            int roll = eventDataMap['roll'] ?? -1;
            print('Parsed roll: $roll, current bonus: $rollBonus');
            if (roll != -1) {
              rollTotal = roll + rollBonus;
              addToHistory(roll);  // Add to history when roll is received
              print('New total: $rollTotal');
              notifyListeners();
            }
          } catch (e) {
            print('Error parsing event data: $e');
          }
        },
        onError: (error) {
          print('SSE error: $error');
          _handleReconnect();
        },
        onDone: () {
          print('SSE connection closed');
          _handleReconnect();
        },
      );
    } catch (e) {
      print('Connection error: $e');
      connectionStatus = 'Connection failed';
      isConnected = false;
      notifyListeners();
      _handleReconnect();
    }
  }

  void _handleReconnect() {
    if (_retryCount < maxRetries) {
      int delaySeconds = 1 << _retryCount;
      connectionStatus = 'Reconnecting in $delaySeconds seconds...';
      notifyListeners();
      
      Future.delayed(
        Duration(seconds: delaySeconds),
        () {
          _retryCount++;
          connectToSse();
        },
      );
    } else {
      connectionStatus = 'Connection failed. Please check your connection.';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sseStreamSubscription?.cancel();
    _sse?.close();
    super.dispose();
  }

  void addToHistory(int roll) {
    if (history.length >= maxHistoryLength) {
      history.removeLast();
    }
    
    history.insert(0, RollHistory(
      total: rollTotal,
      roll: roll,
      bonus: rollBonus,
      rollType: buttonText.replaceAll(':', '').trim(),
      timestamp: DateTime.now(),
    ));
    
    var animatedList = historyListKey?.currentState as AnimatedListState?;
    if (animatedList != null) {
      animatedList.insertItem(0);
    }
    notifyListeners();
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class ToggleButtonsRolls extends StatefulWidget {
  const ToggleButtonsRolls({super.key});


  @override
  State<ToggleButtonsRolls> createState () => _ToggleButtonsRollState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Roll Bonuses'),
        actions: [
          IconButton(
            icon: Icon(Icons.psychology),
            tooltip: 'Ability Scores',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => AbilityScoresPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Refresh Bonuses',
            onPressed: () async {
              // Force clear all cached data
              appState._lastBonusRefresh = null;
              appState._currentBonuses = null;
              appState._bonusError = '';
              appState._isLoadingBonuses = false;
              
              // Force refresh
              await appState.refreshBonuses();
              
              // Print debug info
              print('Current bonuses after refresh: ${appState._currentBonuses}');
              print('Last refresh time: ${appState._lastBonusRefresh}');
              
              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    appState._bonusError.isEmpty 
                      ? 'Bonuses refreshed!' 
                      : 'Error: ${appState._bonusError}'
                  ),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: BigCard(),
          ),
          Expanded(
            flex: 3,
            child: HistoryListView(),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ToggleButtonsRolls(),
          ),
        ],
      ),
    );
  }
}

class GeneratorPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: HistoryListView(),
          ),
          SizedBox(height: 10),
          BigCard(),
          SizedBox(height: 10),
          Row(
            
            mainAxisSize: MainAxisSize.min,
            children: [
              ToggleButtonsRolls()
            ],
          ),
          Spacer(flex: 2),
        ],
      ),
    );
  }
}

class BigCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      elevation: 8,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        constraints: BoxConstraints.expand(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            if (appState._isLoadingBonuses)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: CircularProgressIndicator(),
              ),
            if (appState._bonusError.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  appState._bonusError,
                  style: TextStyle(color: Colors.red[300]),
                ),
              ),
            AnimatedSize(
              duration: Duration(milliseconds: 200),
              child: MergeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      appState.buttonText, 
                      style: Theme.of(context).textTheme.headlineLarge!.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 32,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      appState.rollTotal.toString(),
                      style: Theme.of(context).textTheme.headlineLarge!.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 32,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FavoritesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var appState = context.watch<MyAppState>();

    if (appState.history.isEmpty) {
      return Center(
        child: Text('No rolls yet.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(30),
          child: Text('You have ${appState.history.length} rolls:'),
        ),
        Expanded(
          child: GridView(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              childAspectRatio: 400 / 80,
            ),
            children: [
              for (var rollHistory in appState.history)
                ListTile(
                  leading: IconButton(
                    icon: Icon(Icons.delete_outline, semanticLabel: 'Delete'),
                    color: theme.colorScheme.primary,
                    onPressed: () {
                      appState.removeFromHistory(rollHistory);
                    },
                  ),
                  title: Text(
                    rollHistory.rollType,
                    semanticsLabel: rollHistory.rollType,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// D&D ability scores screen: STR, CON, DEX, INT, WIS, CHA (score + modifier each).
class AbilityScoresPage extends StatefulWidget {
  static const List<Map<String, dynamic>> _stats = [
    {'label': 'STR', 'name': 'Strength'},
    {'label': 'CON', 'name': 'Constitution'},
    {'label': 'DEX', 'name': 'Dexterity'},
    {'label': 'INT', 'name': 'Intelligence'},
    {'label': 'WIS', 'name': 'Wisdom'},
    {'label': 'CHA', 'name': 'Charisma'},
  ];

  @override
  State<AbilityScoresPage> createState() => _AbilityScoresPageState();
}

enum HealthTarget { auto, hp, tempHp}

class _AbilityScoresPageState extends State<AbilityScoresPage> {
  final TextEditingController _hpDeltaController = TextEditingController();
  HealthTarget _target = HealthTarget.auto;

  @override
  void dispose() {
    _hpDeltaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    var theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Ability Scores'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Refresh from sheet',
            onPressed: () async {
              appState._lastBonusRefresh = null;
              await appState.refreshBonuses();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(appState._bonusError.isEmpty
                        ? 'Ability scores refreshed'
                        : 'Error: ${appState._bonusError}'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: appState._isLoadingBonuses && appState._currentBonuses == null
          ? Center(child: CircularProgressIndicator())
          : appState._bonusError.isNotEmpty && appState._currentBonuses == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      appState._bonusError,
                      style: TextStyle(color: theme.colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    _buildHpCard(context, appState),
                    SizedBox(height: 8),
                    ...AbilityScoresPage._stats.asMap().entries.map((entry) {
                      final i = entry.key;
                      final info = entry.value;
                      final score = _getScore(appState._currentBonuses, i);
                      final mod = _getMod(appState._currentBonuses, i);
                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            '${info['label']} — ${info['name']}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text('Score: $score  •  Modifier: ${_formatMod(mod)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _statChip(context, 'Score', score.toString()),
                              SizedBox(width: 8),
                              _statChip(context, 'Mod', _formatMod(mod)),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
    );
  }

  Widget _buildHpCard(BuildContext context, MyAppState appState) {
    final theme = Theme.of(context);
    final maxHp = appState.maxHp;
    final maxTempHp = appState.maxTempHp;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Health',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _statChip(context, 'HP', '${appState.currentHp} / $maxHp'),
                _statChip(context, 'Temp HP', '${appState.currentTempHp} / $maxTempHp'),
              ],
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text('Auto'),
                  selected: _target == HealthTarget.auto,
                  onSelected: (_) => setState(() => _target = HealthTarget.auto),
                ),
                ChoiceChip(
                  label: Text('HP'),
                  selected: _target == HealthTarget.hp,
                  onSelected: (_) => setState(() => _target = HealthTarget.hp),
                ),
                ChoiceChip(
                  label: Text('Temp HP'),
                  selected: _target == HealthTarget.tempHp,
                  onSelected: (_) => setState(() => _target = HealthTarget.tempHp),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hpDeltaController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Damage / Heal',
                      hintText: '-8 for damage, 5 for healing',
                      border: OutlineInputBorder(),
                      isDense: true,
                    )
                  ),
                ),
                SizedBox(width: 12),
                FilledButton(
                  onPressed: () {
                    final raw = _hpDeltaController.text.trim();
                    final delta = int.tryParse(raw);
                    if (delta == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Enter a whole number like -8 or 5'),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    switch (_target) {
                      case HealthTarget.auto:
                        appState.applyHealthChange(delta);
                      case HealthTarget.hp:
                        appState.applyHpChange(delta);
                      case HealthTarget.tempHp:
                        appState.applyTempHpChange(delta);
                    }

                    _hpDeltaController.clear();
                  },
                  child: Text('Apply'),
                ),
              ],
            ),
            SizedBox(height: 6),
            Text(
              _target == HealthTarget.auto
                ? 'Auto: damage hits Temp HP then HP. Healing affects HP only.'
                : _target == HealthTarget.hp
                  ? 'HP: damage and healing affect HP only.'
                  : 'Temp HP: damage and healing affect Temp HP only.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getScore(RollBonuses? b, int index) {
    if (b == null) return 0;
    switch (index) {
      case 0: return b.strScore;
      case 1: return b.conScore;
      case 2: return b.dexScore;
      case 3: return b.intScore;
      case 4: return b.wisScore;
      case 5: return b.chaScore;
      default: return 0;
    }
  }

  int _getMod(RollBonuses? b, int index) {
    if (b == null) return 0;
    switch (index) {
      case 0: return b.strMod;
      case 1: return b.conMod;
      case 2: return b.dexMod;
      case 3: return b.intMod;
      case 4: return b.wisMod;
      case 5: return b.chaMod;
      default: return 0;
    }
  }
  

  String _formatMod(int mod) => mod >= 0 ? '+$mod' : '$mod';

  Widget _statChip(BuildContext context, String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryListView extends StatefulWidget {
  const HistoryListView({Key? key}) : super(key: key);

  @override
  State<HistoryListView> createState() => _HistoryListViewState();
}

class _ToggleButtonsRollState extends State<ToggleButtonsRolls> {
  // Two rows of 3 buttons each
  final Map<String, dynamic> topRowMap = {
    "No bonus": Icons.square,
    "Attack": Icons.api,
    "Caster Lvl": Icons.auto_awesome,
  };

  final Map<String, dynamic> bottomRowMap = {
    "Fortitude": Icons.local_pharmacy,
    "Reflex": Icons.call_missed_outgoing,
    "Will": Icons.auto_fix_high_sharp,
  };

  late List<bool> _selectedRolls;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MyAppState>();
    _selectedRolls = List.filled(6, false);  // Total number of buttons
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(  // Changed from Wrap to Column
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Top row (No bonus, Attack, Caster Lvl)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: ToggleButtons(
              isSelected: _selectedRolls.sublist(0, 3),
              selectedColor: Theme.of(context).colorScheme.onPrimary,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fillColor: Theme.of(context).colorScheme.primary,
              borderColor: Theme.of(context).colorScheme.primary,
              borderWidth: 2,
              borderRadius: BorderRadius.circular(8),
              constraints: BoxConstraints(minHeight: 80, minWidth: 100),
              children: topRowMap.entries.map((ele) => _buildButtonContent(ele)).toList(),
              onPressed: (value) async {
                await appState.refreshBonuses();
                setState(() {
                  appState.handleBonusAndText(value);
                  _selectedRolls = List.filled(6, false);
                  _selectedRolls[value] = true;
                });
              },
            ),
          ),
          // Bottom row (Fortitude, Reflex, Will)
          ToggleButtons(
            isSelected: _selectedRolls.sublist(3, 6),
            selectedColor: Theme.of(context).colorScheme.onPrimary,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fillColor: Theme.of(context).colorScheme.primary,
            borderColor: Theme.of(context).colorScheme.primary,
            borderWidth: 2,
            borderRadius: BorderRadius.circular(8),
            constraints: BoxConstraints(minHeight: 80, minWidth: 100),
            children: bottomRowMap.entries.map((ele) => _buildButtonContent(ele)).toList(),
            onPressed: (value) async {
              await appState.refreshBonuses();
              setState(() {
                appState.handleBonusAndText(value + 3);  // Offset by 3 for bottom row
                _selectedRolls = List.filled(6, false);
                _selectedRolls[value + 3] = true;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildButtonContent(MapEntry<String, dynamic> ele) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            ele.value,
            size: 32,  // Larger icons
          ),
          SizedBox(height: 4),  // Space between icon and text
          Text(
            ele.key,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryListViewState extends State<HistoryListView> {
  /// Needed so that [MyAppState] can tell [AnimatedList] below to animate
  /// new items.
  final _key = GlobalKey();

  /// Used to "fade out" the history items at the top, to suggest continuation.
  static const Gradient _maskingGradient = LinearGradient(
    // This gradient goes from fully transparent to fully opaque black...
    colors: [Colors.transparent, Colors.black],
    // ... from the top (transparent) to half (0.5) of the way to the bottom.
    stops: [0.0, 0.5],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MyAppState>();
    appState.historyListKey = _key;
    final theme = Theme.of(context);

    return ShaderMask(
      shaderCallback: (bounds) => _maskingGradient.createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: AnimatedList(
        key: _key,
        reverse: true,
        padding: EdgeInsets.only(top: 100),
        initialItemCount: appState.history.length,
        itemBuilder: (context, index, animation) {
          final rollHistory = appState.history[index];
          return SizeTransition(
            sizeFactor: animation,
            child: Card(
              margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                leading: CircleAvatar( //TODO: make this a dice icon
                  child: Text(
                    rollHistory.roll.toString(),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: theme.colorScheme.primaryContainer,
                ),
                title: Text(
                  '${rollHistory.rollType} Total: ${rollHistory.total}',
                  style: theme.textTheme.bodyLarge,
                ),
                subtitle: Text(
                  'Bonus: ${rollHistory.bonus}',
                  style: theme.textTheme.bodyMedium,
                ),
                trailing: Text(
                  _formatTimestamp(rollHistory.timestamp),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
