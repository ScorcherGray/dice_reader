// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:dice_reader/model/user.dart';
import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dice_reader/pixel_calls/pixel_calls.dart';
import 'dart:convert' as convert;

Future main() async{
  WidgetsFlutterBinding.ensureInitialized();

  runApp(MyApp());
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
  var current = WordPair.random();
  var history = <WordPair>[];
  var rollTotal = 0;
  var rollBonus = 0;
  Sse? _sse;
  var bonuses = [];
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

  MyAppState() {
    connectToSse();
  }

  void getNext() {
    history.insert(0, current);
    var animatedList = historyListKey?.currentState as AnimatedListState?;
    animatedList?.insertItem(0);
    current = WordPair.random();
    notifyListeners();
  }

  void updateBonus(var bonus, String newText) {
    rollBonus = bonus;
    buttonText = newText;
    print('Updated bonus to : $rollBonus'); // Debug Log
    notifyListeners();
  }

  Future<void> refreshBonuses() async {
    _isLoadingBonuses = true;
    _bonusError = '';
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('https://script.google.com/macros/s/AKfycbzaSs3mrDRmOtfGcZEpDu4BAle8f6h8VBRfEoribPsDHqsCkM6zC2ntelhcdtmf21le-A/exec'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final jsonBonuses = convert.jsonDecode(response.body);
        _currentBonuses = RollBonuses.fromJson(jsonBonuses);
      } else {
        _bonusError = 'Failed to load bonuses: ${response.statusCode}';
      }
    } catch (e) {
      print('Error details: $e');
      _bonusError = 'Error loading bonuses: $e';
    } finally {
      _isLoadingBonuses = false;
      notifyListeners();
    }
  }

  void handleBonusAndText(int value) async {
    // Refresh bonuses before applying selection
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
    if (_sseStreamSubscription != null) {
      _sseStreamSubscription!.cancel();
    }
    _sse?.close();
    super.dispose();
  }

  var savedRolls = <WordPair>[];

  void toggleFavorite([WordPair? pair]) {
    pair = pair ?? current;
    if (savedRolls.contains(pair)) {
      savedRolls.remove(pair);
    } else {
      savedRolls.add(pair);
    }
    notifyListeners();
  }

  void removeRoll(WordPair pair) {
    savedRolls.remove(pair);
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
  var selectedIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var colorScheme = Theme.of(context).colorScheme;

    Widget page;
    switch (selectedIndex) {
      case 0:
        page = GeneratorPage();
      case 1:
        page = FavoritesPage();
      default:
        throw UnimplementedError('no widget for $selectedIndex');
    }

    // The container for the current page, with its background color
    // and subtle switching animation.
    var mainArea = ColoredBox(
      color: colorScheme.surfaceVariant,
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: 200),
        child: page,
      ),
    );

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 450) {
            // Use a more mobile-friendly layout with BottomNavigationBar
            // on narrow screens.
            return Column(
              children: [
                Expanded(child: mainArea),
                SafeArea(
                  child: BottomNavigationBar(
                    items: [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.home),
                        label: 'Home',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.book_online_sharp),
                        label: 'History',
                      ),
                    ],
                    currentIndex: selectedIndex,
                    onTap: (value) {
                      setState(() {
                        selectedIndex = value;
                      });
                    },
                  ),
                )
              ],
            );
          } else {
            return Row(
              children: [
                SafeArea(
                  child: NavigationRail(
                    extended: constraints.maxWidth >= 600,
                    destinations: [
                      NavigationRailDestination(
                        icon: Icon(Icons.home),
                        label: Text('Home'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.book_online_sharp),
                        label: Text('History'),
                      ),
                    ],
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (value) {
                      setState(() {
                        selectedIndex = value;
                      });
                    },
                  ),
                ),
                Expanded(child: mainArea),
              ],
            );
          }
        },
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
      color: Theme.of(context).colorScheme.primaryContainer,  // Dark background
      elevation: 8,  // Add some shadow
      margin: EdgeInsets.all(16),  // Add some margin
      child: Column(
        children: [
          if (appState._isLoadingBonuses)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          if (appState._bonusError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                appState._bonusError,
                style: TextStyle(color: Colors.red[300]),  // Lighter red for dark theme
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(24),  // Increased padding
            child: AnimatedSize(
              duration: Duration(milliseconds: 200),
              child: MergeSemantics(
                child: Wrap(
                  spacing: 12,  // Add space between text elements
                  children: [
                    Text(
                      appState.buttonText, 
                      style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,  // Make text bolder
                      ),
                    ),
                    Text(
                      appState.rollTotal.toString(), 
                      style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,  // Make text bolder
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FavoritesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var appState = context.watch<MyAppState>();

    if (appState.savedRolls.isEmpty) {
      return Center(
        child: Text('No rolls yet.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(30),
          child: Text('You have '
              '${appState.savedRolls.length} rolls:'),
        ),
        Expanded(
          // Make better use of wide windows with a grid.
          child: GridView(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              childAspectRatio: 400 / 80,
            ),
            children: [
              for (var rollTotal in appState.savedRolls)
                ListTile(
                  leading: IconButton(
                    icon: Icon(Icons.delete_outline, semanticLabel: 'Delete'),
                    color: theme.colorScheme.primary,
                    onPressed: () {
                      appState.removeRoll(rollTotal);
                    },
                  ),
                  title: Text(
                    rollTotal.asLowerCase,
                    semanticsLabel: rollTotal.asPascalCase,
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

    return ShaderMask(
      shaderCallback: (bounds) => _maskingGradient.createShader(bounds),
      // This blend mode takes the opacity of the shader (i.e. our gradient)
      // and applies it to the destination (i.e. our animated list).
      blendMode: BlendMode.dstIn,
      child: AnimatedList(
        key: _key,
        reverse: true,
        padding: EdgeInsets.only(top: 100),
        initialItemCount: appState.history.length,
        itemBuilder: (context, index, animation) {
          final pair = appState.history[index];
          return SizeTransition(
            sizeFactor: animation,
            child: Center(
              child: TextButton.icon(
                onPressed: () {
                  appState.toggleFavorite(pair);
                },
                icon: appState.savedRolls.contains(pair)
                    ? Icon(Icons.favorite, size: 12)
                    : SizedBox(),
                label: Text(
                  pair.asLowerCase,
                  semanticsLabel: pair.asPascalCase,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
