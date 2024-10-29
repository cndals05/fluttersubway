import 'dart:convert';
import 'dart:ui';
import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:async';
import 'package:xml/xml.dart' as xml;
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' show pi;
import 'dart:io' show Platform;
import 'ad_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(HomeScreen());
}

class HomeScreen extends StatefulWidget {
  bool isDarkMode;
  final Function(bool)? toggleDarkMode;

  HomeScreen({this.isDarkMode = false, this.toggleDarkMode});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late bool _isDarkMode;
  late bool _isSystemMode;
  bool _isAdLoaded = false;
  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isDarkMode = widget.isDarkMode;
    _isSystemMode = false;
    _loadPreferences();
    /* 광고 AdManager().getBannerAdWidget() ?? Container(),  AdManager _setupBannerAd();*/
  }
 /* void _setupBannerAd() {
    _bannerAd = AdManager().createBannerAd();
    _bannerAd?.load().then((value) {
      setState(() {
        _isAdLoaded = true;
      });
    });
  }*/

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (_isSystemMode) {
      _updateThemeMode();
    }
  }


  void _updateThemeMode() {
    if (_isSystemMode) {
      final window = View.of(context).platformDispatcher;
      setState(() {
        _isDarkMode = window.platformBrightness == Brightness.dark;
      });
      widget.toggleDarkMode?.call(_isDarkMode);
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isSystemMode = prefs.getBool('isSystemMode') ?? false;
      if (_isSystemMode) {
        final window = View.of(context).platformDispatcher;
        _isDarkMode = window.platformBrightness == Brightness.dark;
        widget.toggleDarkMode?.call(_isDarkMode);
      } else {
        _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      }
    });
  }


  void _toggleDarkMode(bool value) async {
    setState(() {
      _isDarkMode = value;
      if (value) {
        _isSystemMode = false;
      }
    });
    widget.toggleDarkMode?.call(_isDarkMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isSystemMode', false);
    await prefs.setBool('isDarkMode', value);
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Color(0xFFF5F5F5),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.black,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blueGrey,
        scaffoldBackgroundColor: Color(0xff242323),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blueGrey,
          foregroundColor: Colors.white,
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
        ),
      ),
      themeMode: _isSystemMode
          ? ThemeMode.system
          : (_isDarkMode ? ThemeMode.dark : ThemeMode.light),
      home: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: CombinedScreen(
                toggleDarkMode: _toggleDarkMode,
                isDarkMode: _isDarkMode,
              ),
            ),
            if (_isAdLoaded && _bannerAd != null)
              Container(
                alignment: Alignment.center,
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
          ],
        ),
      ),
    );
  }
}

class CombinedScreen extends StatefulWidget {
  final Function(bool) toggleDarkMode;
  final bool isDarkMode;

  CombinedScreen({required this.toggleDarkMode, required this.isDarkMode});

  @override
  _CombinedScreenState createState() => _CombinedScreenState();
}

class _CombinedScreenState extends State<CombinedScreen> {
  List<dynamic> allStations = [];
  List<Map<String, dynamic>> favoriteStations = [];
  List<dynamic> filteredStations = [];
  List<Map<String, dynamic>> searchHistory = [];
  Set<String> favorites = Set<String>();
  bool isLoading = false;
  TextEditingController _searchController = TextEditingController();


  Widget _buildFavoriteStationItem(Map<String, dynamic> station, int index) {
    final lineColor = _getLineColor(station['lineNum']);
    final displayLineNum = station['lineNum'].replaceFirst(RegExp(r'^0'), '');

    return InkWell(
      onTap: () {
        addSearchHistory(station['stationName'], station['lineNum']);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StationInfoScreen(
              stationName: station['stationName'],
              lineNum: station['lineNum'],
              stations: allStations
                  .where((s) => s['line_num'] == station['lineNum'])
                  .toList(),
            ),
          ),
        );
      },
      onLongPress: () => removeFromFavorites(index),
      child: Container(
        width: 80,
        height: 68,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 2,
              offset: Offset(4, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 9,
              decoration: BoxDecoration(
                color: lineColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        station['stationName'],
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      displayLineNum,  // 여기서 수정된 호선 번호를 사용합니다
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
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

  Widget _buildAddFavoriteButton() {
    return InkWell(
      onTap: () => _showSearchBottomSheet(
          forFavorites: true, favoriteIndex: favoriteStations.length),
      child: Container(
        width: 80,
        height: 68,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 2,
              offset: Offset(4, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 9,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add,
                    color: Colors.grey[600],
                    size: 24,
                  ),
                  SizedBox(height: 2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    loadJsonData();
    loadSearchHistory();
    loadFavorites();
    loadFavoriteStations();
  }

  Future<void> loadJsonData() async {
    setState(() {
      isLoading = true;
    });

    try {
      String jsonString =
      await rootBundle.loadString('assets/seoul_subway.json');
      final jsonResponse = json.decode(jsonString);

      if (jsonResponse['DATA'] != null) {
        setState(() {
          allStations = jsonResponse['DATA'];
          allStations
              .sort((a, b) => a['station_cd'].compareTo(b['station_cd']));
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        print('JSON 데이터에 "DATA" 키가 없습니다.');
      }
    } catch (error) {
      setState(() {
        isLoading = false;
      });
      print('JSON 데이터를 불러오는 중 오류 발생: $error');
    }
  }

  Future<void> loadSearchHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? history = prefs.getStringList('searchHistory');
    if (history != null) {
      setState(() {
        searchHistory = history.map((item) {
          final parts = item.split('|');
          return {
            'stationName': parts[0],
            'lineNum': parts[1],
          };
        }).toList();
      });
    }
  }

  Future<void> loadFavorites() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Set<String>? favs = prefs.getStringList('favorites')?.toSet();
    if (favs != null) {
      setState(() {
        favorites = favs;
      });
    }
  }

  Future<void> loadFavoriteStations() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? favStationsJson = prefs.getString('favoriteStations');
    if (favStationsJson != null) {
      List<dynamic> decodedList = json.decode(favStationsJson);
      setState(() {
        favoriteStations = decodedList.map((item) =>
        Map<String, dynamic>.from(item)
        ).toList();
      });
    }
  }


  void saveSearchHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final history = searchHistory
        .map((item) => '${item['stationName']}|${item['lineNum']}')
        .toList();
    await prefs.setStringList('searchHistory', history);
  }

  void saveFavorites() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorites', favorites.toList());
  }

  Future<void> saveFavoriteStations() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String favStationsJson = json.encode(favoriteStations);
    await prefs.setString('favoriteStations', favStationsJson);
  }

  void addSearchHistory(String stationName, String lineNum) {
    final entry = {
      'stationName': stationName,
      'lineNum': lineNum,
    };

    setState(() {
      searchHistory.removeWhere((item) =>
      item['stationName'] == stationName && item['lineNum'] == lineNum);
      searchHistory.insert(0, entry);
      if (searchHistory.length > 10) {
        searchHistory.removeLast();
      }
      saveSearchHistory();
    });
  }

  void removeFromSearchHistory(int index) {
    setState(() {
      searchHistory.removeAt(index);
      saveSearchHistory();
    });
  }

  void toggleFavorite(String stationName, String lineNum) {
    setState(() {
      String key = '$stationName|$lineNum';
      if (favorites.contains(key)) {
        favorites.remove(key);
      } else {
        favorites.add(key);
      }
      saveFavorites();
    });
  }

  void searchStations(String query) {
    final lowerCaseQuery = query.toLowerCase();
    setState(() {
      filteredStations = allStations.where((station) {
        final stationName = station['station_nm'].toLowerCase();
        final lineNum = station['line_num'].toLowerCase();
        return stationName.contains(lowerCaseQuery) ||
            lineNum.contains(lowerCaseQuery);
      }).toList();
    });
  }

  void addToFavorites(String stationName, String lineNum) {
    setState(() {
      if (favoriteStations.length < 4) {
        favoriteStations.add({
          'stationName': stationName,
          'lineNum': lineNum,
        });
        saveFavoriteStations();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('즐겨찾기는 최대 4개까지만 추가할 수 있습니다.')),
        );
      }
    });
  }

  void _showSearchBottomSheet({bool forFavorites = false, int? favoriteIndex}) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final Color backgroundColor = isDarkMode ? Colors.grey[800]! : Colors.white;

    _searchController.text = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: (query) {
                        setModalState(() {
                          searchStations(query);
                        });
                      },
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: '역 검색',
                        labelStyle: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                        suffixIcon: Icon(Icons.search, color: textColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredStations.length,
                      itemBuilder: (context, index) {
                        final station = filteredStations[index];
                        final stationName = station['station_nm'];
                        final lineNum = station['line_num'];
                        final lineColor = _getLineColor(lineNum);

                        return ListTile(
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                stationName,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: lineColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  lineNum.replaceFirst(RegExp(r'^0'), ''),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            if (forFavorites) {
                              addToFavorites(stationName, lineNum);
                              Navigator.pop(context);
                            } else {
                              // 현재 context를 변수에 저장
                              final currentContext = context;
                              addSearchHistory(stationName, lineNum);

                              // 바텀시트를 닫고 나서 새로운 화면으로 이동
                              Navigator.pop(currentContext);

                              // 약간의 딜레이 후 새 화면으로 이동
                              Future.delayed(Duration(milliseconds: 100), () {
                                if (currentContext.mounted) {
                                  Navigator.push(
                                    currentContext,
                                    MaterialPageRoute(
                                      builder: (context) => StationInfoScreen(
                                        stationName: stationName,
                                        lineNum: lineNum,
                                        stations: allStations
                                            .where((s) => s['line_num'] == lineNum)
                                            .toList(),
                                      ),
                                    ),
                                  );
                                }
                              });
                            }
                          },
                        );
                      },
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      _searchController.clear();
      setState(() {
        filteredStations = [];
      });
    });
  }


  void removeFromFavorites(int index) {
    setState(() {
      favoriteStations.removeAt(index);
      saveFavoriteStations();
    });
  }

  Color _getLineColor(String lineNum) {
    final Map<String, Color> lineColors = {
      '01호선': Color(0XFF374A96),
      '02호선': Color(0xFF45B450),
      '03호선': Color(0xFFF56540),
      '04호선': Color(0xFF50BEDF),
      '05호선': Color(0xFF85559F),
      '06호선': Color(0xFF9E5D37),
      '07호선': Color(0xFF67743F),
      '08호선': Color(0xFFE43274),
      '09호선': Color(0xFF9B873D),
      '중앙선': Color(0xFF45B450),
      '경의중앙선': Color(0xFF58C3D2),
      '경춘선': Color(0xFF359697),
      '수인분당선': Color(0xFFEAB036),
      'GTX-A': Color(0xFF986293),
      '공항철도': Color(0xFF5094FF),
    };
    return lineColors[lineNum] ?? Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(right: 8, top: 5),
              child: Icon(
                Icons.subway_outlined,
                color: Colors.blue,
                size: 30,
              ),
            ),
            Text(
              '지어디?',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 19, fontWeight: FontWeight.bold),
            )
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            SizedBox(
              width: double.infinity,
              height: 80,
              child: DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.blue,
                ),
                child: Row(
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('설정'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(
                      toggleDarkMode: widget.toggleDarkMode,
                      isDarkMode: widget.isDarkMode,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView(
        children: [
          // 검색 필드
          Padding(
            padding: EdgeInsets.all(8.0),
            child: GestureDetector(
              onTap: _showSearchBottomSheet,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: -10,
                      blurRadius: 4,
                      offset: Offset(3, 10),
                    ),
                  ],
                ),
                child: Builder(
                  builder: (BuildContext context) {
                    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
                    final Color backgroundColor = isDarkMode ? Colors.grey[800]! : Colors.white;
                    final Color textColor = isDarkMode ? Colors.white : Colors.black;

                    return TextField(
                      controller: _searchController,
                      enabled: false,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: '역 검색',
                        labelStyle: TextStyle(color: textColor),
                        suffixIcon: Icon(Icons.search, color: textColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(
                            color: backgroundColor,
                            width: 2.0,
                          ),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(
                            color: backgroundColor,
                            width: 1.0,
                          ),
                        ),
                        filled: true,
                        fillColor: backgroundColor,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // 즐겨찾기 섹션
          Padding(
            padding: const EdgeInsets.only(left: 15.0, top: 10.0, bottom: 5.0),
            child: Text(
              '즐겨찾기',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
              ),
            ),
          ),

          // 즐겨찾기 컨테이너
          Center(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: Offset(3, 10),
                  ),
                ],
              ),
              width: 380,
              height: 120,
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  ...List.generate(
                    favoriteStations.length,
                        (index) => Container(
                      width: 75,
                      height: 68,
                      margin: EdgeInsets.symmetric(horizontal: 9),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            margin: EdgeInsets.only(left: 8.0),
                            child: _buildFavoriteStationItem(favoriteStations[index], index),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (favoriteStations.length < 4)
                    Container(
                      width: 75,
                      height: 68,
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            margin: EdgeInsets.only(left: 8.0),
                            child: _buildAddFavoriteButton(),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 최근기록 섹션
          Padding(
            padding: const EdgeInsets.only(left: 15.0, top: 15.0, bottom: 5.0),
            child: Text(
              '최근기록',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
              ),
            ),
          ),
          Container(
            margin: EdgeInsets.symmetric(vertical: 0, horizontal: 12.0),
            height: 400, // 화면 높이의 50%로 고정
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[600]! : Colors.grey[300]!,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: Offset(7, 8),
                ),
              ],
            ),
            child: ListView.builder(
              // shrinkWrap과 NeverScrollableScrollPhysics 제거
              padding: const EdgeInsets.only(top: 15.0),
              itemCount: searchHistory.length,
              itemBuilder: (context, index) {
                final item = searchHistory[index];
                final Color lineColor = _getLineColor(item['lineNum']);
                final displayLineNum = item['lineNum'].replaceFirst(RegExp(r'^0'), '');

                return Container(
                  margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[600]! : Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                    title: Text(
                      item['stationName'],
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: lineColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        displayLineNum,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    onTap: () {
                      final stationName = item['stationName'];
                      final lineNum = item['lineNum'];
                      addSearchHistory(stationName, lineNum);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StationInfoScreen(
                            stationName: stationName,
                            lineNum: lineNum,
                            stations: allStations
                                .where((s) => s['line_num'] == lineNum)
                                .toList(),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
         /* Container(
            child: AdManager().getBannerAdWidget() ?? Container(),
          ),*/
        ],
      ),
    );
  }
}

class StationInfoScreen extends StatefulWidget {
  final String stationName;
  final String lineNum;
  final List<dynamic> stations;

  StationInfoScreen({
    required this.stationName,
    required this.lineNum,
    required this.stations,
  });

  @override
  _StationInfoScreenState createState() => _StationInfoScreenState();
}

class _StationInfoScreenState extends State<StationInfoScreen> {
  late PageController _pageController;
  late int selectedIndex;
  List<Map<String, dynamic>> trainInfoList = [];
  List<dynamic> allStations = [];
  bool isLoading = true;
  Timer? _timer;
  String? selectedTrainNo;
  Map<String, dynamic>? selectedTrain;
  bool showNotification = false;
  late String currentLine;
  List<Map<String, dynamic>> arrivalInfo = [];
  Timer? _arrivalTimer;


  @override
  void initState() {
    super.initState();
    currentLine = widget.lineNum;
    _loadInitialData();
    // 실시간 도착 정보 타이머 추가
    _arrivalTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        fetchStationArrivalInfo();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _arrivalTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> fetchStationArrivalInfo() async {
    String apiKey = '6f77695050636e64333568746d5370';
    String url = 'http://swopenAPI.seoul.go.kr/api/subway/$apiKey/json/realtimeStationArrival/0/10/${widget.stationName}';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        var decodedBody = utf8.decode(response.bodyBytes);
        Map<String, dynamic> data = json.decode(decodedBody);

        if (data.containsKey('realtimeArrivalList')) {
          List<Map<String, dynamic>> newArrivalInfo = [];
          List<dynamic> arrivals = data['realtimeArrivalList'];

          // 현재 선택된 호선의 도착 정보만 필터링
          final currentSubwayId = _getSubwayId(currentLine);
          print('Current Line: $currentLine');
          print('Current SubwayId: $currentSubwayId');

          arrivals = arrivals.where((arrival) {
            String subwayId = arrival['subwayId'] ?? '';
            print('Arrival SubwayId: $subwayId');
            // currentLine과 subwayId가 일치하는 정보만 선택
            return subwayId == currentSubwayId;
          }).toList();

          print('Filtered Arrivals Count: ${arrivals.length}');

          DateTime now = DateTime.now();

          for (var arrival in arrivals) {
            String recptnDt = arrival['recptnDt'] ?? '';
            String timeUntilArrival = '정보 없음';

            if (recptnDt.isNotEmpty) {
              try {
                DateTime arrivalTime = DateTime.parse(recptnDt);
                Duration difference = arrivalTime.difference(now);
                int minutes = difference.inMinutes.abs();

                if (minutes == 0) {
                  timeUntilArrival = '곧 도착';
                } else {
                  timeUntilArrival = '$minutes분 후 도착';
                }
              } catch (e) {
                print('Error parsing date: $e');
                timeUntilArrival = '시간 정보 오류';
              }
            }

            newArrivalInfo.add({
              'trainLineNm': arrival['trainLineNm'] ?? '',
              'btrainNo': arrival['btrainNo'] ?? '',
              'barvlDt': timeUntilArrival,
            });
          }

          if (mounted) {
            setState(() {
              arrivalInfo = newArrivalInfo;
              print('Updated arrival info count: ${arrivalInfo.length}');
            });
          }
        }
      }
    } catch (e) {
      print('Error fetching arrival info: $e');
      if (mounted) {
        setState(() {
          arrivalInfo = [];
        });
      }
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // 전체 데이터 로드
      String jsonString = await rootBundle.loadString('assets/seoul_subway.json');
      final jsonResponse = json.decode(jsonString);

      if (jsonResponse['DATA'] != null) {
        allStations = jsonResponse['DATA'];
        // 현재 노선의 역들만 필터링
        List<dynamic> currentLineStations = allStations
            .where((station) => station['line_num'] == currentLine)
            .toList();

        // 현재 역의 인덱스 찾기
        selectedIndex = currentLineStations.indexWhere(
                (station) => station['station_nm'] == widget.stationName
        );

        if (selectedIndex == -1) selectedIndex = 0;

        // PageController를 먼저 초기화
        _pageController = PageController(
          initialPage: selectedIndex,
          viewportFraction: 0.3,
        );

        setState(() {
          isLoading = false;
        });

        // 페이지 로드 후에 스크롤 실행
        if (mounted) {
          await Future.delayed(Duration(milliseconds: 100));
          _pageController.animateToPage(
            selectedIndex,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }

      // API 호출은 데이터 로드 후에 실행
      await fetchStationInfo();
      await fetchStationArrivalInfo();

    } catch (e) {
      print('Error loading station data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _changeLine(String newLine) async {
    setState(() {
      currentLine = newLine;
      isLoading = true;
      trainInfoList = [];
    });

    // 새로운 호선의 역 목록 필터링
    List<dynamic> newLineStations = allStations
        .where((station) => station['line_num'] == newLine)
        .toList();

    // 현재 역의 새로운 인덱스 찾기
    int newIndex = newLineStations.indexWhere(
            (station) => station['station_nm'] == widget.stationName
    );

    if (newIndex == -1) newIndex = 0;

    // PageController 재설정
    _pageController.dispose();
    _pageController = PageController(
      initialPage: newIndex,
      viewportFraction: 0.3,
    );

    // 새로운 데이터 로드
    await fetchStationInfo();

    setState(() {
      selectedIndex = newIndex;
      isLoading = false;
      selectedTrainNo = null;
      selectedTrain = null;
    });

    // 화면 갱신 후 스크롤
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _pageController.animateToPage(
          newIndex,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });

    // Timer 재설정
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        fetchStationInfo();
      }
    });
  }

  void _scrollToStation(String stationName) {
    List<dynamic> currentLineStations = allStations
        .where((station) => station['line_num'] == currentLine)
        .toList();

    final stationIndex = currentLineStations.indexWhere(
            (station) => station['station_nm'] == stationName
    );

    if (stationIndex != -1 && mounted) {
      _pageController.animateToPage(
        stationIndex,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  String _getSubwayId(String lineNum) {
    final Map<String, String> subwayIds = {
      '01호선': '1001',
      '02호선': '1002',
      '03호선': '1003',
      '04호선': '1004',
      '05호선': '1005',
      '06호선': '1006',
      '07호선': '1007',
      '08호선': '1008',
      '09호선': '1009',
      '중앙선': '1061',
      '경의중앙선': '1063',
      '공항철도': '1065',
      '경춘선': '1067',
      '수인분당선': '1075',
      '신분당선': '1077',
      '우이신설선': '1092',
      'GTX-A': '1032'
    };
    return subwayIds[lineNum] ?? '';
  }

  Future<void> fetchStationInfo() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    String apiKey = '66614b6f41636e643530506a755858';
    String formattedLineNum = currentLine.replaceFirst(RegExp(r'^0'), '');
    String url = 'http://swopenAPI.seoul.go.kr/api/subway/$apiKey/xml/realtimePosition/0/100/$formattedLineNum';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        var decodedBody = utf8.decode(response.bodyBytes);
        var document = xml.XmlDocument.parse(decodedBody);

        var resultCode = document.findAllElements('RESULT.CODE').firstOrNull?.text;
        var resultMessage = document.findAllElements('RESULT.MESSAGE').firstOrNull?.text;

        if (resultCode != null && resultCode != 'INFO-000') {
          throw Exception('API Error: $resultCode - $resultMessage');
        }

        var items = document.findAllElements('row');
        Set<String> uniqueTrainNos = Set<String>();
        List<Map<String, dynamic>> newTrainInfoList = [];

        for (var item in items) {
          String trainNo = _findElementText(item, 'trainNo');
          if (!uniqueTrainNos.contains(trainNo)) {
            uniqueTrainNos.add(trainNo);
            newTrainInfoList.add({
              'subwayId': _findElementText(item, 'subwayId'),
              'subwayNm': _findElementText(item, 'subwayNm'),
              'statnId': _findElementText(item, 'statnId'),
              'statnNm': _findElementText(item, 'statnNm'),
              'trainNo': trainNo,
              'lastRecptnDt': _findElementText(item, 'lastRecptnDt'),
              'recptnDt': _findElementText(item, 'recptnDt'),
              'updnLine': _findElementText(item, 'updnLine'),
              'statnTid': _findElementText(item, 'statnTid'),
              'statnTnm': _findElementText(item, 'statnTnm'),
              'directAt': _findElementText(item, 'directAt'),
              'lstcarAt': _findElementText(item, 'lstcarAt'),
              'trainSttus': _findElementText(item, 'trainSttus'),
            });
          }
        }

        if (mounted) {
          setState(() {
            trainInfoList = newTrainInfoList;
            isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to load train info: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      print('Error fetching station info: $e');
    }
  }

  String _findElementText(xml.XmlElement element, String tagName) {
    return element.findElements(tagName).firstOrNull?.text ?? '';
  }

  void _centerTrainIcon(String trainNo) {
    setState(() {
      selectedTrainNo = trainNo;
      selectedTrain = trainInfoList.firstWhere((train) => train['trainNo'] == trainNo);
    });

    // 선택된 열차의 현재 역 찾기
    final selectedTrainStation = selectedTrain?['statnNm'] ?? '';

    // 현재 호선의 역 목록에서 해당 역의 인덱스 찾기
    List<dynamic> currentStations = allStations
        .where((station) => station['line_num'] == currentLine)
        .toList();

    final stationIndex = currentStations.indexWhere(
            (station) => station['station_nm'] == selectedTrainStation
    );

    if (stationIndex != -1) {
      // 해당 역으로 스크롤
      _pageController.animateToPage(
        stationIndex,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  String _getTrainStatus(String? status) {
    switch (status) {
      case '0':
        return '진입';
      case '1':
        return '도착';
      case '2':
        return '출발';
      case '3':
        return '전역출발';
      default:
        return '알 수 없음';
    }
  }
  Color _getLineColor(String lineNum) {
    final Map<String, Color> lineColors = {
      '01호선': Color(0XFF374A96),
      '02호선': Color(0xFF45B450),
      '03호선': Color(0xFFF56540),
      '04호선': Color(0xFF50BEDF),
      '05호선': Color(0xFF85559F),
      '06호선': Color(0xFF9E5D37),
      '07호선': Color(0xFF67743F),
      '08호선': Color(0xFFE43274),
      '09호선': Color(0xFF9B873D),
      '중앙선': Color(0xFF45B450),
      '경의중앙선': Color(0xFF58C3D2),
      '경춘선': Color(0xFF359697),
      '수인분당선': Color(0xFFEAB036),
      'GTX-A': Color(0xFF986293),
      '공항철도': Color(0xFF5094FF),
    };
    return lineColors[lineNum] ?? Colors.grey;
  }

  Widget _buildStationView(BuildContext context, int index) {
    List<dynamic> currentStations = allStations
        .where((station) => station['line_num'] == currentLine)
        .toList();

    final station = currentStations[index];
    final stationName = station['station_nm'];

    final matchingTrains = trainInfoList
        .where((train) => train['statnNm'] == stationName)
        .toList();
    final upwardTrain = matchingTrains.firstWhere(
          (train) => train['updnLine'] == '0',
      orElse: () => <String, dynamic>{},
    );
    final downwardTrain = matchingTrains.firstWhere(
          (train) => train['updnLine'] == '1',
      orElse: () => <String, dynamic>{},
    );

    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(MediaQuery.of(context).size.width, 50),
                painter: LinePainter(
                  isLeftStation: index > 0,
                  isRightStation: index < currentStations.length - 1,
                  lineColor: _getLineColor(currentLine),  // currentLine 사용
                ),
              ),
              StationMarker(
                stationName: stationName,
                isSelected: stationName == widget.stationName,
                trainInfoList: trainInfoList,
                stations: currentStations,  // currentStations 사용
                lineColor: _getLineColor(currentLine),  // currentLine 사용
              ),
              if (upwardTrain.isNotEmpty)
                _buildTrainIcon(upwardTrain, true),
              if (downwardTrain.isNotEmpty)
                _buildTrainIcon(downwardTrain, false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrainIcon(Map<String, dynamic> train, bool isUpward) {
    final isExpress = train['directAt'] == '1' || train['directAt'] == '7';
    final isSelected = train['trainNo'] == selectedTrainNo;

    final verticalSpacing = 20.0;
    final baseTopMargin = isUpward ? 30.0 : 150.0;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;

    return Positioned(
      top: baseTopMargin,
      child: GestureDetector(
        onTap: () => _selectTrain(train['trainNo'] ?? ''),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(2),
              child: Text(
                '${train['statnTnm'] ?? ''}행',
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 2),
            TrainIcon(
              lineColor: _getLineColor(currentLine),  // currentLine 사용
              isExpress: isExpress,
              isUpward: isUpward,
              isSelected: isSelected,
              trainNo: train['trainNo'] ?? '',
              destination: train['statnTnm'] ?? '',
              stations: widget.stations,
            ),
          ],
        ),
      ),
    );
  }

  void _selectTrain(String trainNo) {
    setState(() {
      selectedTrainNo = trainNo;
      selectedTrain =
          trainInfoList.firstWhere((train) => train['trainNo'] == trainNo);
      _centerTrainIcon(trainNo);
    });
  }

  List<Map<String, dynamic>> _getUniqueTrains(
      List<Map<String, dynamic>> trains) {
    final Map<String, Map<String, dynamic>> uniqueTrains = {};
    for (var train in trains) {
      final trainNo = train['trainNo'];
      if (!uniqueTrains.containsKey(trainNo)) {
        uniqueTrains[trainNo] = train;
      }
    }
    return uniqueTrains.values.toList();
  }

  int _getStationIndex(String stationName) {
    return widget.stations
        .indexWhere((station) => station['station_nm'] == stationName);
  }

  List<Map<String, dynamic>> _sortTrainsByDistance(
      List<Map<String, dynamic>> trains, bool isUpward) {
    final selectedStationIndex = _getStationIndex(widget.stationName);
    trains.sort((a, b) {
      final aIndex = _getStationIndex(a['statnNm']);
      final bIndex = _getStationIndex(b['statnNm']);
      final aDist = (aIndex - selectedStationIndex).abs();
      final bDist = (bIndex - selectedStationIndex).abs();
      if (isUpward) {
        return aDist.compareTo(bDist);
      } else {
        return bDist.compareTo(aDist);
      }
    });
    return trains;
  }

  Widget _buildTrainList(bool isUpward) {
    final filteredTrains = trainInfoList
        .where((train) =>
    (isUpward && train['updnLine'] == '0') ||
        (!isUpward && train['updnLine'] == '1'))
        .toList();

    final uniqueTrains = _getUniqueTrains(filteredTrains);
    final sortedTrains = _sortTrainsByDistance(uniqueTrains, isUpward);

    if (sortedTrains.isEmpty) {
      return Center(child: Text('현재 ${isUpward ? '상행' : '하행'} 열차 정보가 없습니다.'));
    }

    return ListView.builder(
      itemCount: sortedTrains.length,
      itemBuilder: (context, index) {
        final train = sortedTrains[index];
        final isSelected = train['trainNo'] == selectedTrainNo;
        return GestureDetector(
          onTap: () => _selectTrain(train['trainNo'] ?? ''),
          child: Card(
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: isSelected ? Colors.blue.shade100 : null,
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue[600]),
          SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 16, color: Colors.black87),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> currentStations = allStations
        .where((station) => station['line_num'] == currentLine)
        .toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(widget.stationName),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView(
        children: [
          _buildTransferInfo(),
          SizedBox(height: 12),
          Container(
            height: 250,
            child: PageView.builder(
              controller: _pageController,
              itemCount: currentStations.length,
              itemBuilder: (context, index) => _buildStationView(
                context,
                index,
              ),
            ),
          ),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[300]!, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '실시간 도착 정보',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                ),
                SizedBox(height: 8),
                if (arrivalInfo.isEmpty)
                  Text(
                    '도착 예정인 열차가 없습니다.',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  )
                else
                  ...arrivalInfo.map((info) => Container(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.train, color: Colors.orange[700]),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${info['trainLineNm']}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '열차번호: ${info['btrainNo']}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                '${info['barvlDt']}', // '초' 제거, 메시지 그대로 표시
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
              ],
            ),
          ),
          Card(
            margin: EdgeInsets.all(16),
            elevation: 4,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '열차 정보',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                      Icon(Icons.train, color: Colors.blue[700], size: 28),
                    ],
                  ),
                  Divider(thickness: 1.5, height: 24),
                  if (selectedTrain == null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          '열차를 선택해주세요.',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        _buildInfoRow(
                          Icons.confirmation_number,
                          '열차 번호',
                          selectedTrain!['trainNo'] ?? '정보 없음',
                        ),
                        _buildInfoRow(
                          Icons.location_on,
                          '현재 위치',
                          selectedTrain!['statnNm'] ?? '정보 없음',
                        ),
                        _buildInfoRow(
                          Icons.flash_on,
                          '급행 여부',
                          _getExpressStatus(selectedTrain!['directAt'] ?? ''),
                        ),
                        _buildInfoRow(
                          Icons.last_page,
                          '막차 여부',
                          selectedTrain!['lstcarAt'] == '1' ? '막차' : '아님',
                        ),
                        _buildInfoRow(
                          Icons.info_outline,
                          '상태',
                          _getTrainStatus(selectedTrain!['trainSttus']),
                        ),
                        _buildInfoRow(
                          Icons.flag,
                          '종착역',
                          selectedTrain!['statnTnm'] ?? '정보 없음',
                        ),
                        if (showNotification)
                          Container(
                            padding: EdgeInsets.all(8),
                            margin: EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[500]!, width: 2),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.notifications_active, color: Colors.blue[700]),
                                SizedBox(width: 8),
                                Text(
                                  '역을 선택하시면 됨니다!',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
         /* AdManager().getBannerAdWidget() ?? Container(),
          SizedBox(height: 16),*/
        ],
      ),
    );
  }

  String _getExpressStatus(String? directAt) {
    switch (directAt) {
      case '1':
        return '급행';
      case '7':
        return '특급';
      default:
        return '일반';
    }
  }
  List<String> getTransferLines() {
    if (allStations.isEmpty) {
      return [];
    }

    Set<String> lines = {};
    for (var station in allStations) {
      if (station['station_nm'] == widget.stationName) {
        String lineNum = station['line_num'];
        lines.add(lineNum);
      }
    }

    List<String> sortedLines = lines.toList()
      ..sort((a, b) {
        bool aIsNumeric = a.startsWith(RegExp(r'[0-9]'));
        bool bIsNumeric = b.startsWith(RegExp(r'[0-9]'));

        if (aIsNumeric && bIsNumeric) {
          int aNum = int.parse(a.replaceAll(RegExp(r'[^0-9]'), ''));
          int bNum = int.parse(b.replaceAll(RegExp(r'[^0-9]'), ''));
          return aNum.compareTo(bNum);
        } else if (aIsNumeric) {
          return -1;
        } else if (bIsNumeric) {
          return 1;
        } else {
          return a.compareTo(b);
        }
      });

    return sortedLines;
  }

  Widget _buildTransferInfo() {
    final transferLines = getTransferLines();
    if (transferLines.isEmpty) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: transferLines.map((line) {
          String displayNum = line;
          if (line.contains('호선')) {
            displayNum = line.replaceFirst(RegExp(r'^0'), '').replaceAll('호선', '');
          } else if (line == '경의중앙선') {
            displayNum = '경의';
          } else if (line == '수인분당선') {
            displayNum = '분당';
          } else if (line == '공항철도') {
            displayNum = '공항';
          }

          bool isSelected = currentLine == line;

          return GestureDetector(
            onTap: () {
              if (!isSelected) {
                _changeLine(line);
              }
            },
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 4),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getLineColor(line),
                shape: BoxShape.circle,
                border: isSelected ? Border.all(
                  color: Colors.yellow,
                  width: 3,
                ) : null,
              ),
              child: Text(
                displayNum,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 16,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

} // _StationInfoScreenState의 끝

class TrainIcon extends StatelessWidget {
  final Color lineColor;
  final bool isExpress;
  final bool isUpward;
  final String trainNo;
  final String destination;
  final List<dynamic> stations;
  final bool isSelected;

  const TrainIcon({
    required this.lineColor,
    required this.isExpress,
    required this.isUpward,
    required this.trainNo,
    required this.destination,
    required this.stations,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    return Container(
      width: 50,
      height: 50,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(isUpward ? 0 : pi),
            child: Image.asset(
              'assets/train.png',
              color: isSelected
                  ? Colors.yellow
                  : (isExpress ? Colors.red : lineColor),
              width: 50,
              height: 50,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                print('Error loading image: $error');
                return Container(
                  width: 50,
                  height: 50,
                  color: Colors.grey[300],
                  child: Icon(Icons.train, color: Colors.grey[600]),
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              trainNo,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LinePainter extends CustomPainter {
  final bool isLeftStation;
  final bool isRightStation;
  final Color lineColor;

  LinePainter({
    required this.isLeftStation,
    required this.isRightStation,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class StationMarker extends StatelessWidget {
  final String stationName;
  final bool isSelected;
  final List<Map<String, dynamic>> trainInfoList;
  final List<dynamic> stations;
  final Color lineColor;

  const StationMarker({
    Key? key,
    required this.stationName,
    required this.isSelected,
    required this.trainInfoList,
    required this.stations,
    required this.lineColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // 선 그리기
              Container(
                width: 500,
                height: 8,
                color: lineColor,
              ),
              // 역 원 그리기
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? Colors.red : Colors.white,
                  border: Border.all(color: lineColor, width: 3),
                ),
              ),
            ],
          ),
          SizedBox(height: 4), // 고정된 간격 추가
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 80), // 최대 너비 제한
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              decoration: BoxDecoration(
                color: lineColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                stationName,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis, // 긴 텍스트는 ... 처리
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsScreens extends StatelessWidget {
  final Function(bool) toggleDarkMode;

  SettingsScreens({required this.toggleDarkMode});

  void _showInquiryDialog(BuildContext context) {
    final TextEditingController _inquiryController = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('구독'),
      ),
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSubscriptionOption(
              context: context,
              title: '1달 이용권',
              price: '      ₩900\n알림설정가능',
              color: Colors.blue.shade400,
              onTap: () => _showSubscriptionDialog(context, '1달 이용권'),
            ),
            SizedBox(width: 16),
            _buildSubscriptionOption(
              context: context,
              title: '1년 이용권',
              price: '    ₩9,900\n알림설정가능',
              color: Colors.green.shade400,
              onTap: () => _showSubscriptionDialog(context, '1년 이용권'),
              isBestValue: true,
            ),
            SizedBox(width: 16),
            _buildSubscriptionOption(
              context: context,
              title: '평생 이용권',
              price: '  ₩15,000\n알림설정가능',
              color: Colors.purple.shade400,
              onTap: () => _showSubscriptionDialog(context, '평생 이용권'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionOption({
    required BuildContext context,
    required String title,
    required String price,
    required Color color,
    required VoidCallback onTap,
    bool isBestValue = false,
  }) {
    return Stack(
      children: [
        Container(
          width: 115,
          height: 200,
          child: Card(
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            color: color,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      Text(
                        price,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: onTap,
                    child: Text('구매'),
                    style: ElevatedButton.styleFrom(
                      padding:
                      EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showSubscriptionDialog(BuildContext context, String subscriptionType) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('구독 확인'),
          content: Text('$subscriptionType을 선택하셨습니다. 구독하시겠습니까?'),
          actions: <Widget>[
            TextButton(
              child: Text('취소'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('확인'),
              onPressed: () {
                // TODO: 여기에 구독 처리 로직 추가
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$subscriptionType 구독이 완료되었습니다.')),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final Function(bool) toggleDarkMode;
  final bool isDarkMode;

  SettingsScreen({required this.toggleDarkMode, required this.isDarkMode});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}
class _SettingsScreenState extends State<SettingsScreen> {
  late bool _isDarkMode;
  late bool _isSystemMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    _isSystemMode = true;
    _loadSystemModePreference();
  }

  Future<void> _loadSystemModePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isSystemMode = prefs.getBool('isSystemMode') ?? false;
    });
  }

  void _toggleDarkMode(bool value) async {
    setState(() {
      if (value) {
        _isDarkMode = true;
        _isSystemMode = false;
      } else {
        _isDarkMode = false;
      }
    });
    widget.toggleDarkMode(_isDarkMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isSystemMode', _isSystemMode);
  }

  void _toggleSystemMode(bool value) async {
    setState(() {
      if (value) {
        _isSystemMode = true;
        _isDarkMode = false;
      } else {
        _isSystemMode = false;
      }
    });
    widget.toggleDarkMode(_isDarkMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isSystemMode', _isSystemMode);
  }

  // 카카오톡 채널 URL로 바로 이동하는 함수
  Future<void> _openKakaoChannel(BuildContext context) async {
    final Uri url = Uri.parse('http://pf.kakao.com/_fnqEn');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('카카오톡 채널을 열 수 없습니다.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('카카오톡 채널을 열 수 없습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final Color backgroundColor = isDarkMode ? Colors.grey[900]! : Colors.white;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('설정', style: TextStyle(color: textColor)),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.0),
        children: [
          SizedBox(
            width: 100,
            height: 120,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.yellow,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 2,
                      offset: Offset(4, 5),
                    ),
                  ],
                ),
                child: ListTile(
                  title: Text(
                    '카카오톡 1:1 채팅하기',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () => _openKakaoChannel(context),
                ),
              ),
            ),
          ),
          SwitchListTile(
            title: Text('시스템 모드', style: TextStyle(color: textColor)),
            value: _isSystemMode,
            onChanged: _toggleSystemMode,
            activeColor: Colors.blue,
          ),
          SwitchListTile(
            title: Text('다크 모드', style: TextStyle(color: textColor)),
            value: _isDarkMode,
            onChanged: _isSystemMode ? null : _toggleDarkMode,
            activeColor: Colors.blue,
          ),
        ],
      ),
    );
  }
}