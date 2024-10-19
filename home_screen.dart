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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(HomeScreen());
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isDarkMode = false;
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadDarkModePreference();
    _createBannerAd();
  }

  void _loadDarkModePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  void _toggleDarkMode(bool value) async {
    setState(() {
      _isDarkMode = value;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
  }

  void _createBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544~3347511713', /*ca-app-pub-2533926979702289/9989724678*/
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          print('Ad failed to load: $error');
        },
      ),
    );

    _bannerAd?.load();
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
        // 기타 라이트 모드 설정...
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blueGrey,
        scaffoldBackgroundColor: Color(0xff242323),  // 요청한 다크 모드 배경색
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blueGrey,
          foregroundColor: Colors.white,
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
        ),
        // 기타 다크 모드 설정...
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: CombinedScreen(
                  toggleDarkMode: _toggleDarkMode,
                  isDarkMode: _isDarkMode
              ),
            ),
            if (_isAdLoaded)
              Container(
                height: _bannerAd!.size.height.toDouble(),
                width: _bannerAd!.size.width.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
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
              offset: Offset(0, 1),
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
              offset: Offset(0, 1),
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
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (query) {
                        setModalState(() {
                          searchStations(query);
                        });
                      },
                      style: TextStyle(color: Colors.black), // Set input text color to black
                      decoration: InputDecoration(
                        labelText: '역 검색',
                        labelStyle: TextStyle(color: Colors.black),
                        suffixIcon: Icon(
                          Icons.search,
                          color: Colors.black,
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

                        return ListTile(
                          title: Text(
                            '$stationName - $lineNum',
                            style: TextStyle(color: Colors.black), // Keep the color black
                          ),
                          onTap: () {
                            if (forFavorites) {
                              addToFavorites(stationName, lineNum);
                              Navigator.pop(context);
                            } else {
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
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
              '열차위치',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 19,fontWeight: FontWeight.bold),
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
              height: 100.0,
              child: DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.blue,
                ),
                child: Center(
                  child: Text(
                    '메뉴',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
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
            /* ListTile(
              leading: Icon(Icons.add_card),
              title: Text('구독'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsScreens(
                      toggleDarkMode: widget.toggleDarkMode,
                    ),
                  ),
                );
              },
            ),*/
          ],
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          GestureDetector(
            onTap: _showSearchBottomSheet,
            child: Container(
              padding: EdgeInsets.all(8.0),
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
                    final Color borderColor = isDarkMode ? Color(0xFF4B4B4B) : Color(0xFF5D5D5D);

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
                )
            ),
          ),
          Expanded(
            child: Builder(
              builder: (BuildContext context) {
                final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
                final Color textColor = isDarkMode ? Colors.white : Colors.black;
                final Color backgroundColor = isDarkMode ? Colors.grey[800]! : Colors.white;
                final Color borderColor = isDarkMode ? Colors.grey[600]! : Colors.grey[300]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 15.0, top: 10.0, bottom: 5.0),
                      child: Text(
                        '즐겨찾기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          color: backgroundColor,
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
                        width: 390,
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
                    Padding(
                      padding: const EdgeInsets.only(left: 15.0, top: 15.0, bottom: 5.0),
                      child: Text(
                        '최근기록',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 0, horizontal: 12.0),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.5),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: Offset(7, 8),
                          ),
                        ],
                      ),
                      height: 400,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 15.0),
                        itemCount: searchHistory.length,
                        itemBuilder: (context, index) {
                          final item = searchHistory[index];
                          final Color lineColor = _getLineColor(item['lineNum']);
                          final displayLineNum = item['lineNum'].replaceFirst(RegExp(r'^0'), '');
                          return Container(
                            margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
                            decoration: BoxDecoration(
                              color: backgroundColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor, width: 1),
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                              title: Text(
                                item['stationName'],
                                style: TextStyle(
                                  color: textColor,
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
                                  displayLineNum,  // 여기서 수정된 호선 번호를 사용합니다
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              onTap: () {
                                final stationName = item['stationName'];
                                final lineNum = item['lineNum'];  // 원래의 lineNum을 사용합니다
                                addSearchHistory(stationName, lineNum);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => StationInfoScreen(
                                      stationName: stationName,
                                      lineNum: lineNum,  // 원래의 lineNum을 사용합니다
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
                    )
                  ],
                );
              },
            ),
          )
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
  bool isLoading = true;
  Timer? _timer;
  String? selectedTrainNo;
  Map<String, dynamic>? selectedTrain;
  bool showNotification = false;

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.stations
        .indexWhere((station) => station['station_nm'] == widget.stationName);
    _pageController = PageController(
      initialPage: selectedIndex,
      viewportFraction: 0.3,
    );
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await fetchStationInfo();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
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
    setState(() {
      isLoading = true;
    });

    String apiKey = '66614b6f41636e643530506a755858'; // 실제 API 키로 교체해야 합니다
    String formattedLineNum = widget.lineNum.replaceFirst(RegExp(r'^0'), '');
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

        setState(() {
          trainInfoList = newTrainInfoList;
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load train info: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error fetching station info: $e');
    }
  }

  String _findElementText(xml.XmlElement item, String elementName) {
    return item.findElements(elementName).firstOrNull?.text ?? '';
  }

  void _centerTrainIcon(String trainNo) {
    setState(() {
      selectedTrainNo = trainNo;
    });

    int trainStationIndex = widget.stations.indexWhere((station) {
      return trainInfoList.any((train) =>
      train['trainNo'] == trainNo &&
          train['statnNm'] == station['station_nm']);
    });

    if (trainStationIndex != -1) {
      _pageController.animateToPage(
        trainStationIndex,
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
    final station = widget.stations[index];
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
                  isRightStation: index < widget.stations.length - 1,
                  lineColor: _getLineColor(widget.lineNum),
                ),
              ),
              StationMarker(
                stationName: stationName,
                isSelected: stationName == widget.stationName,
                trainInfoList: trainInfoList,
                stations: widget.stations,
                lineColor: _getLineColor(widget.lineNum),
              ),
              if (upwardTrain.isNotEmpty) _buildTrainIcon(upwardTrain, true),
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

    return Positioned(
      top: baseTopMargin,
      child: GestureDetector(
        onTap: () => _selectTrain(train['trainNo'] ?? ''),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${train['statnTnm'] ?? ''}행',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 2),
            TrainIcon(
              lineColor: _getLineColor(widget.lineNum),
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

  Widget _buildSelectedTrainInfo() {
    return Card(
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
                      color: Colors.blue[700]),
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
                  _buildInfoRow(Icons.confirmation_number, '열차 번호',
                      selectedTrain!['trainNo'] ?? '정보 없음'),
                  _buildInfoRow(Icons.location_on, '현재 위치',
                      selectedTrain!['statnNm'] ?? '정보 없음'),
                  _buildInfoRow(Icons.flash_on, '급행 여부',
                      _getExpressStatus(selectedTrain!['directAt'] ?? '')),
                  _buildInfoRow(Icons.last_page, '막차 여부',
                      selectedTrain!['lstcarAt'] == '1' ? '막차' : '아님'),
                  _buildInfoRow(Icons.info_outline, '상태',
                      _getTrainStatus(selectedTrain!['trainSttus'])),
                  _buildInfoRow(
                      Icons.flag, '종착역', selectedTrain!['statnTnm'] ?? '정보 없음'),
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
                          Icon(Icons.notifications_active,
                              color: Colors.blue[700]),
                          SizedBox(width: 8),
                          Text(
                            '역을 선택하시면 됨니다!',
                            style: TextStyle(
                                color: Colors.blue[700],
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  /* ElevatedButton(
                  onPressed: handleNotificationClick,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    backgroundColor: Colors.deepPurple,
                  ),
                  child: Text(
                    '알림',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),*/
                ],
              ),
          ],
        ),
      ),
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
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('${widget.stationName} - ${widget.lineNum}'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          SizedBox(height: 20),
          Container(
            height: 250,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.stations.length,
              itemBuilder: _buildStationView,
            ),
          ),
          _buildSelectedTrainInfo(),
        ],
      ),
    );
  }
}

class TrainIcon extends StatelessWidget {
  final Color lineColor;
  final bool isExpress;
  final bool isUpward;
  final String trainNo;
  final String destination;
  final List<dynamic> stations;
  final bool isSelected;

  TrainIcon({
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
    return Container(
      width: 50,
      height: 50,
      child: Stack(
        children: [
          Center(
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(isUpward ? 0 : pi),
              child: Image.asset(
                isExpress ? 'assets/train.png' : 'assets/train.png',
                color: isSelected
                    ? Colors.yellow
                    : (isExpress ? Colors.red : lineColor),
                width: 50,
                height: 50,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Text(
                '$trainNo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  height: -1,
                  color: lineColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
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
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // 선 그리기
              Container(
                width: 500, // 선의 너비를 늘려 원이 완전히 포함되도록 함
                height: 8,
                color: lineColor,
              ),
              // 역 원 그리기
              Container(
                width: 20,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? Colors.red : Colors.white,
                  border: Border.all(color: lineColor, width: 3),
                ),
              ),
            ],
          ),
          Container(
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

class SettingsScreen extends StatelessWidget {
  final Function(bool) toggleDarkMode;
  final bool isDarkMode;

  SettingsScreen({required this.toggleDarkMode, required this.isDarkMode});

  void _showInquiryDialog(BuildContext context) {
    final TextEditingController _inquiryController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final Color textColor = isDarkMode ? Colors.white : Colors.black;
        final Color primaryColor = isDarkMode ? Colors.blue[300]! : Colors.blue[700]!;
        final Color backgroundColor = isDarkMode ? Colors.grey[800]! : Colors.white;
        final Color inputFillColor = isDarkMode ? Colors.grey[700]! : Colors.grey[200]!;
        final Color buttonColor = isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;

        return AlertDialog(
          backgroundColor: backgroundColor,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('문의하기',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: primaryColor)),
              Icon(Icons.help_outline, color: primaryColor, size: 28),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(thickness: 1.5, height: 24, color: primaryColor),
                  Text('문의 내용',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                  SizedBox(height: 10),
                  TextField(
                    controller: _inquiryController,
                    maxLines: 5,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: '문의 내용을 입력해주세요',
                      hintStyle: TextStyle(color: textColor.withOpacity(0.6)),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: inputFillColor,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text('문의 방법 선택',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                  SizedBox(height: 10),
                  _buildActionButton(
                    icon: Icons.email,
                    label: '이메일 앱으로 보내기',
                    onPressed: () => _sendEmail(_inquiryController.text, context),
                    buttonColor: buttonColor,
                    textColor: textColor,
                  ),
                  SizedBox(height: 10),
                  _buildActionButton(
                    icon: Icons.content_copy,
                    label: '이메일 주소 복사',
                    onPressed: () => _copyEmailAddress(context),
                    buttonColor: buttonColor,
                    textColor: textColor,
                  ),
                  SizedBox(height: 10,width: 100,),
                  _buildActionButton(
                    icon: Icons.note_add,
                    label: '문의 내용 복사',
                    onPressed: () => _copyInquiryContent(_inquiryController.text, context),
                    buttonColor: buttonColor,
                    textColor: textColor,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: Text('닫기', style: TextStyle(color: primaryColor)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color buttonColor,
    required Color textColor,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: textColor),
      label: Text(label, style: TextStyle(color: textColor)),
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
      onPressed: onPressed,
    );
  }

  void _sendEmail(String body, BuildContext context) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'cm0308cm@gmail.com',
      query: encodeQueryParameters(<String, String>{
        'subject': '앱 문의사항',
        'body': body,
      }),
    );

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    }
  }

  void _copyEmailAddress(BuildContext context) {
    Clipboard.setData(ClipboardData(text: 'cm0308cm@gmail.com'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('이메일 주소가 복사되었습니다.')),
    );
  }

  void _copyInquiryContent(String content, BuildContext context) {
    final String emailContent = '$content';
    Clipboard.setData(ClipboardData(text: emailContent));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('문의 내용이 복사되었습니다.')),
    );
  }

  String? encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) =>
    '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final Color backgroundColor = isDarkMode ? Colors.grey[900]! : Colors.white;
    final Color tileColor = isDarkMode ? Colors.grey[800]! : Colors.grey[100]!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('설정', style: TextStyle(color: textColor)),
        iconTheme: IconThemeData(color: textColor),
      ),
      backgroundColor: backgroundColor,
      body: ListView(
        children: [
          SwitchListTile(
            title: Text('다크 모드', style: TextStyle(color: textColor)),
            value: this.isDarkMode,
            onChanged: (value) {
              toggleDarkMode(value);
            },
            activeColor: Colors.blue,
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.shade300,
            tileColor: tileColor,
          ),
          ListTile(
            title: Text('문의하기', style: TextStyle(color: textColor)),
            trailing: Icon(Icons.arrow_forward_ios, color: textColor),
            onTap: () => _showInquiryDialog(context),
            tileColor: tileColor,
          ),
          // 여기에 다른 설정 항목들을 추가할 수 있습니다.
        ],
      ),
    );
  }
}