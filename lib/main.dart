import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UIMusicApp());
}

class UIMusicApp extends StatelessWidget {
  const UIMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UI Music',
      theme: ThemeData(
        fontFamily: 'Roboto',
        primaryColor: const Color(0xFF00BCD4),
        scaffoldBackgroundColor: const Color(0xFFEBF5FB),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<SongModel> _allSongs = [];
  List<String> _favoriteSongIds = [];
  
  SongModel? _currentSong;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  final Color textDarkBlue = const Color(0xFF006B99);
  final Color buttonCyan = const Color(0xFF00BCD4);
  final String realisticMusicIcon = "https://images.unsplash.com/photo-1505740420928-5e560c06d30e?q=80&w=200&auto=format&fit=crop"; 

  @override
  void initState() {
    super.initState();
    _checkPermissionAndLoad();
    _initAudioListeners();
    _loadSavedData();
  }

  // डेटा सेव करने और लोड करने का लॉजिक
  void _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteSongIds = prefs.getStringList('favorites') ?? [];
    });
  }

  void _saveFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    if (_favoriteSongIds.contains(id)) {
      _favoriteSongIds.remove(id);
    } else {
      _favoriteSongIds.add(id);
    }
    await prefs.setStringList('favorites', _favoriteSongIds);
    setState(() {});
  }

  void _checkPermissionAndLoad() async {
    PermissionStatus statusStorage = await Permission.storage.request();
    PermissionStatus statusAudio = await Permission.audio.request();

    if (statusStorage.isGranted || statusAudio.isGranted) {
      List<SongModel> songs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );
      if (mounted) {
        setState(() {
          _allSongs = songs.where((s) => s.isMusic == true && !s.data.toLowerCase().contains('call') && !s.data.toLowerCase().contains('whatsapp')).toList();
        });
      }
    }
  }

  void _initAudioListeners() {
    _audioPlayer.positionStream.listen((p) { if (mounted) setState(() => _position = p); });
    _audioPlayer.durationStream.listen((d) { if (mounted) setState(() => _duration = d ?? Duration.zero); });
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) setState(() => _isPlaying = state.playing);
    });
  }

  void _playSong(SongModel song) async {
    if (song.uri == null) return;
    try {
      await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(song.uri!)));
      _audioPlayer.play();
      if (mounted) setState(() => _currentSong = song);
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  void _showAddToPlaylistDialog(SongModel song) {
    Based on the image "30786.jpg" you shared, your CI/CD pipeline (which appears to be GitHub Actions) is failing at the **Build Debug APK** step. 

### The Issue
The visible log shows a generic `Gradle task assembleDebug failed with exit code 1`. However, this is just the final result of the failure, not the root cause. 

The actual error message or stack trace that explains *why* the build failed is located further up in the logs, before line 38. Gradle is simply telling you that a process crashed, but the details of that crash are hidden above.

### Recommended Next Steps

*   **Scroll Up the Logs:** Expand the `Build Debug APK` section and look for the specific error lines (usually highlighted in red or labeled `e: ` or `Error:`). Common culprits include:
    *   Incompatible dependencies or version mismatches.
    *   Java version conflicts (I see you have a step for Java 17, which is good, but some older plugins might require Java 11).
    *   Missing SDK licenses or build tools.
*   **Enable Verbose Logging:** If the error still isn't obvious, you can modify your workflow file to output more detailed logs. 
    *   If you are running a Flutter command, change it to: `flutter build apk --debug --verbose`
    *   If you are running Gradle directly, change it to: `./gradlew assembleDebug --stacktrace --info`

Could you scroll up in those logs and share the specific error lines that appear before the build failure message?
