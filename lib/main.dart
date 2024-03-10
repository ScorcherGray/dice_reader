// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:dice_reader/model/user.dart';
import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  var rollTotal = 0;
  var rollBonus = 0;
  late Sse _sse;
  var bonuses = [];
  late StreamSubscription _sseStreamSubscription;
  String buttonText = 'No roll selected: ';

  GlobalKey? historyListKey;

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
    notifyListeners();
  }

  void handleBonusAndText(var value) {
    switch (value) {
      case 0:
        updateBonus(0, 'No Bonus: ');
        print('Rolling with no bonus');  
        break;
      case 1:
        updateBonus(bonuses[0].attackBonus, 'Attack Roll: ');
        print('Bonus set to Attack roll');   
        break;
      case 2:
        updateBonus(bonuses[0].fortBonus, 'Fortitude Save: ');
        print('Bonus set to Fortitude Save');   
        break;
      case 3:
        updateBonus(bonuses[0].reflexBonus, 'Reflex Save: ');
        print('Bonus set to Reflex Save');  
        break; 
      case 4:
        updateBonus(bonuses[0].willBonus, 'Will Save: ');
        print('Bonus set to Will Save');  
        break;
      default:
        break;
    }
  }

  void connectToSse() async {
      final sseUri = Uri.parse(':5000/listen'); // Include ip if on same network
      print('Before sse await connect');
      try{
        _sse = await Sse.connect(uri: sseUri);
        print('first connection');
        // I know connection is getting called and the listen endpoint is being hit
        // Yet this _sse.stream.listen event is not getting the value.
        _sseStreamSubscription = _sse.stream.listen((event) {
          print('Listening on stream');
          String eventData = event;
          print('Before Mapping');
          Map<String, dynamic> eventDataMap = convert.jsonDecode(eventData);
          print('After mapping');
          int? roll = eventDataMap['roll'];
          print('Received eventData $eventData');
          if (roll != null) {
            // Use the integer
            rollTotal = roll + rollBonus;
            print('received roll: $roll');
            notifyListeners();
          }
          else if(roll == null){
            print('parse to int failed and roll is null');
          }
          else{
            print('parse failed for non-null reason');
          }
          // Handle received events
          // print('Received event: $event');
          }, onError: (error) {
            // Handle SSE stream errors
            print('SSE error: $error');
          }, onDone: () {
            // Handle SSE stream completion
            print('SSE stream closed. Reconnecting');
            connectToSse();
      });
      } catch (e) {
        print('Error initializing SSE connection: $e');
        // Possible future error handling
      }
    }

  
  @override
  void dispose() {
    _sse.close();
    _sseStreamSubscription.cancel();
    super.dispose();
  }

  Future<void> getBonusesFromSheet() async {
    bonuses.clear();
    var raw = await http.get(Uri.parse('https://script.google.com/macros/s//exec')); // include path for google sheet
    
    var jsonBonuses = convert.jsonDecode(raw.body);
    print('These are the json bonuses $jsonBonuses');
    print(jsonBonuses.runtimeType);
    RollBonuses rollBonuses = RollBonuses();
    rollBonuses.attackBonus = jsonBonuses['attackBonus'];
    rollBonuses.fortBonus = jsonBonuses['fortBonus'];
    rollBonuses.reflexBonus = jsonBonuses['refBonus'];
    rollBonuses.willBonus = jsonBonuses['willBonus'];

    jsonBonuses.forEach((key, value){
      print('Single bonus $key, $value');
    });

    bonuses.add(rollBonuses);

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
    return Consumer<MyAppState>(
      builder: (context, myAppState, child) {
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
              child: MergeSemantics(
                child: Wrap(
                  children: [
                    Text(
                      myAppState.buttonText, 
                      style: style.copyWith(fontWeight: FontWeight.w200),
                    ),
                    Text(
                      myAppState.rollTotal.toString(), 
                      style: style.copyWith(fontWeight: FontWeight.w200),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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

class _ToggleButtonsRollState extends State<ToggleButtonsRolls>{
  bool vertical = false;
  Map<String, dynamic> map = {
    "No bonus": Icons.square,
    "Attack": Icons.api,
    "Fortitude": Icons.local_pharmacy,
    "Reflex": Icons.call_missed_outgoing,
    "Will": Icons.auto_fix_high_sharp
  };
  late List<bool> _selectedRolls;
  var currentBonus = 0;
  var totalRoll = 0;
  var bonusType = '';
  List<RollBonuses> bonuses = <RollBonuses>[];

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MyAppState>();
    _selectedRolls = List.filled(map.length, false);
    return Wrap(
      children: [
        ToggleButtons(
          isSelected: _selectedRolls,        
          selectedColor: Colors.blueGrey,
          children: map.entries.map((ele) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(ele.value),
                Text(ele.key),
              ],
            );
          }).toList(),
          onPressed: (value) async{            
            await appState.getBonusesFromSheet();
            setState(() {
              appState.handleBonusAndText(value);
              _selectedRolls = List.filled(map.length, false);
              _selectedRolls[value] = true;
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
