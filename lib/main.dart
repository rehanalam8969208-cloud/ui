import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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

  // Load Saved Data (Playlist/Favorites)
  void _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteSongIds = prefs.getStringList('favorites') ?? [];
    });
  }

  // Check Permissions and Load Songs
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

  // Audio Listeners
  void _initAudioListeners() {
    _audioPlayer.positionStream.listen((p) { if (mounted) setState(() => _position = p); });
    _audioPlayer.durationStream.listen((d) { if (mounted) setState(() => _duration = d ?? Duration.zero); });
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) setState(() => _isPlaying = state.playing);
    });
  }

  // Play a Song
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

  // Show Playlist Dialog
  void _showAddToPlaylistDialog(SongModel song) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Add to Playlist", style: TextStyle(color: textDarkBlue, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.add_circle, color: buttonCyan),
                title: Text("Create New Playlist", style: TextStyle(color: textDarkBlue)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Playlist feature setup ready!")));
                },
              ),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            _buildHomeScreen(),
            if (_currentSong != null) _buildGlassMiniPlayer(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: buttonCyan,
        unselectedItemColor: Colors.grey,
        elevation: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
          BottomNavigationBarItem(icon: Icon(Icons.library_music), label: "Library"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }

  Widget _buildHomeScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Text("All Songs", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textDarkBlue)),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 100),
            itemCount: _allSongs.length,
            itemBuilder: (context, index) {
              SongModel song = _allSongs[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(realisticMusicIcon, width: 45, height: 45, fit: BoxFit.cover),
                  ),
                  title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textDarkBlue)),
                  subtitle: Text(song.artist ?? "Unknown", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  trailing: IconButton(
                    icon: Icon(Icons.playlist_add, color: buttonCyan),
                    onPressed: () => _showAddToPlaylistDialog(song),
                  ),
                  onTap: () => _playSong(song),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // REAL GLASSMORPHISM PLAYER
  Widget _buildGlassMiniPlayer() {
    return Positioned(
      bottom: 10, left: 16, right: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0), // शीशे जैसा धुंधलापन
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.4), // ट्रांसपेरेंट वाइट कलर
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12), 
                  child: Image.network(realisticMusicIcon, width: 44, height: 44, fit: BoxFit.cover)
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_currentSong!.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textDarkBlue)),
                      Text(_currentSong!.artist ?? "Unknown", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textDarkBlue.withOpacity(0.7), fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 38, color: buttonCyan), 
                  onPressed: () { _isPlaying ? _audioPlayer.pause() : _audioPlayer.play(); }
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
