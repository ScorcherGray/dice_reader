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

  DateTime? _lastBonusRefresh;
  static const Duration refreshInterval = Duration(minutes: 2);  // Adjust as needed

  static const int maxHistoryLength = 12;

  MyAppState() {
    connectToSse();
    refreshBonuses();  // Prefetch bonuses immediately
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
      const url = 'https://script.google.com/macros/s/AKfycbx--IxOTsnO25o5rz5zRfMyz0epkLlXZPCcSr3nHrGuqMFBruw5nikzLHpN-KpBGidR/exec';
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
        final jsonBonuses = convert.jsonDecode(response.body);
        _currentBonuses = RollBonuses.fromJson(jsonBonuses);
        _lastBonusRefresh = DateTime.now();
        print('Successfully updated bonuses: $_currentBonuses');
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
        updateBonus(bonuses.fortBonus, 'Fortitude Save: ');
      case 3:
        updateBonus(bonuses.reflexBonus, 'Reflex Save: ');
      case 4:
        updateBonus(bonuses.willBonus, 'Will Save: ');
    }
  }

  void connectToSse() async {
    connectionStatus = 'Connecting...';
    notifyListeners();
    
    final sseUri = Uri.parse('http://192.168.1.107:5000/listen');
    try {
      if (_sseStreamSubscription != null) {
        await _sseStreamSubscription!.cancel();
      }
      
      _sse = await Sse.connect(uri: sseUri);
      isConnected = true;
      connectionStatus = 'Connected';
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
    var colorScheme = Theme.of(context).colorScheme;
    var appState = context.watch<MyAppState>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Roll Bonuses'),
        actions: [
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
                      appState.history.remove(rollHistory);
                      appState.notifyListeners();
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

class HistoryListView extends StatefulWidget {
  const HistoryListView({Key? key}) : super(key: key);

  @override
  State<HistoryListView> createState() => _HistoryListViewState();
}

class _ToggleButtonsRollState extends State<ToggleButtonsRolls> {
  // Split the buttons into two maps for two rows
  final Map<String, dynamic> topRowMap = {
    "No bonus": Icons.square,
    "Attack": Icons.api,
  };
  
  final Map<String, dynamic> bottomRowMap = {
    "Fortitude": Icons.local_pharmacy,
    "Reflex": Icons.call_missed_outgoing,
    "Will": Icons.auto_fix_high_sharp
  };

  late List<bool> _selectedRolls;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MyAppState>();
    _selectedRolls = List.filled(5, false);  // Total number of buttons
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(  // Changed from Wrap to Column
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Top row
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: ToggleButtons(
              isSelected: _selectedRolls.sublist(0, 2),  // First two buttons
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
                  _selectedRolls = List.filled(5, false);
                  _selectedRolls[value] = true;
                });
              },
            ),
          ),
          // Bottom row
          ToggleButtons(
            isSelected: _selectedRolls.sublist(2, 5),  // Last three buttons
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
                appState.handleBonusAndText(value + 2);  // Offset by 2 for bottom row
                _selectedRolls = List.filled(5, false);
                _selectedRolls[value + 2] = true;
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
