// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:dice_reader/model/user.dart';
import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import'package:dice_reader/pixel_calls/pixel_calls.dart';
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
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        ),
        home: MyHomePage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  var current = WordPair.random();
  var history = <WordPair>[];

  GlobalKey? historyListKey;

  void getNext() {
    history.insert(0, current);
    var animatedList = historyListKey?.currentState as AnimatedListState?;
    animatedList?.insertItem(0);
    current = WordPair.random();
    notifyListeners();
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
        break;
      case 1:
        page = FavoritesPage();
        break;
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
    var appState = context.watch<MyAppState>();
    var pair = appState.current;

    IconData icon;  //TODO: Change if statement. Just toggle icon and clear bonus
    if (appState.savedRolls.contains(pair)) {
      icon = Icons.done_rounded;
    } else {
      icon = Icons.square;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: HistoryListView(),
          ),
          SizedBox(height: 10),
          BigCard(pair: pair),
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
  const BigCard({
    Key? key,
    required this.pair,
  }) : super(key: key);

  final WordPair pair;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var style = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );

    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: AnimatedSize(
          duration: Duration(milliseconds: 200),
          // Make sure that the compound word wraps correctly when the window
          // is too narrow.
          child: MergeSemantics(
            child: Wrap(
              children: [
                Text(
                  pair.first,
                  style: style.copyWith(fontWeight: FontWeight.w200),
                ),
                Text(
                  pair.second,
                  style: style.copyWith(fontWeight: FontWeight.bold),
                )
              ],
            ),
          ),
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
              for (var pair in appState.savedRolls)
                ListTile(
                  leading: IconButton(
                    icon: Icon(Icons.delete_outline, semanticLabel: 'Delete'),
                    color: theme.colorScheme.primary,
                    onPressed: () {
                      appState.removeRoll(pair);
                    },
                  ),
                  title: Text(
                    pair.asLowerCase,
                    semanticsLabel: pair.asPascalCase,
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

class _ToggleButtonsRollState extends State<ToggleButtonsRolls>{
  late Sse _sse;
  late StreamSubscription _sseStreamSubscription;
  bool vertical = false;
  int? roll = 0;
  Map<String, dynamic> map = {
    "No bonus": Icons.square,
    "Attack": Icons.api,
    "Fortitude": Icons.local_pharmacy,
    "Reflex": Icons.call_missed_outgoing,
    "Will": Icons.auto_fix_high_sharp
  };
  List<bool> _selectedRolls = [];
  var currentBonus = 0;
  var totalRoll = 0;
  var bonuseType = '';
  List<RollBonuses> bonuses = <RollBonuses>[];

  @override
  void initState() {
    super.initState();
    _selectedRolls = List.filled(map.length, false);
    getBonusesFromSheet();
    print('attempting to connect');
    _connectToSse();        
  }

  void _connectToSse() async {
      final sseUri = Uri.parse(''); // Include ip if on same network
      print('Before sse await connect');
      _sse = await Sse.connect(uri: sseUri);
      print('first connection');

      _sseStreamSubscription = _sse.stream.listen((event) {
        print('Listening on /listen');
        String eventData = event;
        int? roll = int.tryParse(eventData);
        if (roll != null) {
          // Use the integer
          setState(() {
            totalRoll = roll + currentBonus;
          });
          print('received roll: $roll');
          print('$bonuseType  $totalRoll');
        }
        // Handle received events
        // print('Received event: $event');
        }, onError: (error) {
          // Handle SSE stream errors
          print('SSE error: $error');
        }, onDone: () {
          // Handle SSE stream completion
          // print('SSE stream closed. Reconnecting');
          _connectToSse();
      });
    }

  
  @override
  void dispose() {
    _sse.close();
    _sseStreamSubscription.cancel();
    super.dispose();
  }

  getBonusesFromSheet() async {
    bonuses.clear();
    var raw = await http.get(Uri.parse(''));
    
    var jsonBonuses = convert.jsonDecode(raw.body);
    print('These are the json bonuses $jsonBonuses');
    print(jsonBonuses.runtimeType);
    RollBonuses rollBonuses = RollBonuses();
    rollBonuses.attackBonus = jsonBonuses['attackBonus'];
    rollBonuses.fortBonus = jsonBonuses['fortBonus'];
    rollBonuses.reflexBonus = jsonBonuses['refBonus'];
    rollBonuses.willBonus = jsonBonuses['willBonus'];
    jsonBonuses.forEach((key, value){
      print('Single bonus $key, $value');});

    bonuses.add(rollBonuses);

  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: [
        ToggleButtons(
          isSelected: _selectedRolls,        
          selectedColor: Colors.blueGrey,
          children: [
            ...map.entries.map((ele) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(ele.value),
                  Text(ele.key),
                ],
              );
            }).toList(),
          ],
          onPressed: (value) {
            setState(() { // Add call to update bonuses
              getBonusesFromSheet().then((_){
                  switch (value){
                    case 0:
                      currentBonus = 0;
                      bonuseType = 'No bonus';
                      print('Rolling with no bonus ');  
                    case 1:
                      currentBonus = bonuses[0].attackBonus;
                      bonuseType = 'Attack roll: ';
                      print('Bonuse set to Attack roll');  
                    case 2:
                      // Set bonus value = fort
                      currentBonus = bonuses[0].fortBonus;
                      bonuseType = 'Foritude Save: ';
                      print('Bonuse set to Fortitude Save');  
                    case 3:
                      // Set bonus value = ref
                      currentBonus = bonuses[0].reflexBonus;
                      bonuseType = 'Reflex Save: ';
                      bonuseType = 'Attack';
                      print('Bonuse set to Reflex Save');  
                    case 4:
                      // Set bonus value = will   
                      currentBonus = bonuses[0].willBonus;
                      bonuseType = 'Will Save: ';
                      print('Bonuse set to Will Save');                  
                    default:
                      break;
            }
              _selectedRolls = List.filled(map.length, false);
              _selectedRolls[value] = true;
            });
          });
          },
        ),
      ],
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
