import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ui.music.channel.audio',
    androidNotificationChannelName: 'Apple Style Music',
    androidNotificationOngoing: true,
  );
  
  runApp(const AppleMusicApp());
}

class AppleMusicApp extends StatelessWidget {
  const AppleMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rehan Music',
      theme: ThemeData(
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF2F4F8),
        primaryColor: const Color(0xFF007AFF), // Apple Blue Accent
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
  List<SongModel> _searchResults = [];
  List<String> _favoriteSongIds = [];
  
  SongModel? _currentSong;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Apple Music Clean Theme Colors
  final Color primaryDark = const Color(0xFF1C1C1E);
  final Color accentBlue = const Color(0xFF007AFF);
  final String defaultArt = "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?q=80&w=300&auto=format&fit=crop";

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndLoad();
    _initAudioEngine();
    _loadFavorites();
  }

  void _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteSongIds = prefs.getStringList('fav_songs') ?? [];
    });
  }

  void _requestPermissionsAndLoad() async {
    PermissionStatus storage = await Permission.storage.request();
    PermissionStatus audio = await Permission.audio.request();

    if (storage.isGranted || audio.isGranted) {
      try {
        List<SongModel> songs = await _audioQuery.querySongs(
          sortType: SongSortType.TITLE,
          orderType: OrderType.ASC_OR_SMALLER,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        );
        if (mounted) {
          setState(() {
            // Strict filter against call recordings & whatsapp junk
            _allSongs = songs.where((s) {
              final path = s.data.toLowerCase();
              return s.isMusic == true && 
                     !path.contains('call') && 
                     !path.contains('record') && 
                     !path.contains('whatsapp');
            }).toList();
            _searchResults = _allSongs;
          });
        }
      } catch (e) {
        debugPrint("Error loading local tracks: $e");
      }
    }
  }

  void _initAudioEngine() {
    _audioPlayer.positionStream.listen((p) { if (mounted) setState(() => _position = p); });
    _audioPlayer.durationStream.listen((d) { if (mounted) setState(() => _duration = d ?? Duration.zero); });
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state.playing);
        if (state.processingState == ProcessingState.completed) {
          _playNext();
        }
      }
    });
  }

  void _playSong(SongModel song) async {
    if (song.uri == null) return;
    try {
      final audioSource = AudioSource.uri(
        Uri.parse(song.uri!),
        tag: MediaItem(
          id: song.id.toString(),
          album: song.album ?? "Local Library",
          title: song.title,
          artist: song.artist ?? "Unknown Artist",
        ),
      );
      await _audioPlayer.setAudioSource(audioSource);
      _audioPlayer.play();
      if (mounted) setState(() => _currentSong = song);
    } catch (e) {
      debugPrint("Playback exception: $e");
    }
  }

  void _playNext() {
    if (_allSongs.isEmpty || _currentSong == null) return;
    int idx = _allSongs.indexWhere((s) => s.id == _currentSong!.id);
    if (idx != -1 && idx < _allSongs.length - 1) {
      _playSong(_allSongs[idx + 1]);
    }
  }

  void _playPrevious() {
    if (_allSongs.isEmpty || _currentSong == null) return;
    int idx = _allSongs.indexWhere((s) => s.id == _currentSong!.id);
    if (idx > 0) {
      _playSong(_allSongs[idx - 1]);
    }
  }

  void _filterSongs(String query) {
    setState(() {
      if (query.isEmpty) {
        _searchResults = _allSongs;
      } else {
        _searchResults = _allSongs.where((s) => 
          s.title.toLowerCase().contains(query.toLowerCase()) || 
          (s.artist != null && s.artist!.toLowerCase().contains(query.toLowerCase()))
        ).toList();
      }
    });
  }

  // APPLE STYLE FULL SCREEN PLAYER MODAL
  void _openFullPlayerModal() {
    if (_currentSong == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30.0, sigmaY: 30.0),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.92,
                  color: Colors.white.withOpacity(0.90),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                  child: Column(
                    children: [
                      // Handle bar
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(icon: const Icon(Icons.keyboard_arrow_down, size: 30), onPressed: () => Navigator.pop(context)),
                          const Text("APPLE MUSIC", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.grey)),
                          IconButton(
                            icon: Icon(
                              _favoriteSongIds.contains(_currentSong!.id.toString()) ? Icons.favorite : Icons.favorite_border,
                              color: Colors.red,
                            ),
                            onPressed: () async {
                              final prefs = await SharedPreferences.getInstance();
                              String idStr = _currentSong!.id.toString();
                              if (_favoriteSongIds.contains(idStr)) {
                                _favoriteSongIds.remove(idStr);
                              } else {
                                _favoriteSongIds.add(idStr);
                              }
                              await prefs.setStringList('fav_songs', _favoriteSongIds);
                              setModalState(() {});
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Big Album Artwork Card
                      Container(
                        width: 280, height: 280,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 15))],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.network(defaultArt, fit: BoxFit.cover),
                        ),
                      ),
                      const Spacer(),
                      Text(_currentSong!.title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryDark)),
                      const SizedBox(height: 6),
                      Text(_currentSong!.artist ?? "Unknown Artist", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, color: Colors.grey[600])),
                      const SizedBox(height: 25),
                      // Slider
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: primaryDark,
                          thumbColor: primaryDark,
                          inactiveTrackColor: Colors.black12,
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        ),
                        child: Slider(
                          value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0),
                          max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                          onChanged: (val) {
                            _audioPlayer.seek(Duration(seconds: val.toInt()));
                            setModalState(() {});
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            Text("${_duration.inMinutes}:${(_duration.inSeconds % 60).toString().padLeft(2, '0')}", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(icon: Icon(Icons.skip_previous, size: 40, color: primaryDark), onPressed: () { _playPrevious(); setModalState(() {}); }),
                          GestureDetector(
                            onTap: () {
                              _isPlaying ? _audioPlayer.pause() : _audioPlayer.play();
                              setModalState(() {});
                            },
                            child: Container(
                              width: 75, height: 75,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: primaryDark),
                              child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 40, color: Colors.white),
                            ),
                          ),
                          IconButton(icon: Icon(Icons.skip_next, size: 40, color: primaryDark), onPressed: () { _playNext(); setModalState(() {}); }),
                        ],
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            [_buildHomeScreen(), _buildSearchScreen(), _buildLibraryScreen(), _buildProfileScreen()][_currentIndex],
            if (_currentSong != null) _buildGlassMiniPlayer(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: accentBlue,
        unselectedItemColor: Colors.grey,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.play_circle_fill), label: "Listen Now"),
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
          child: Text("Listen Now", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: primaryDark)),
        ),
        Expanded(
          child: _allSongs.isEmpty
              ? Center(child: Text("No tracks found or loading...", style: TextStyle(color: Colors.grey[600])))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _allSongs.length,
                  itemBuilder: (context, index) {
                    SongModel song = _allSongs[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: ListTile(
                        leading: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(defaultArt, width: 50, height: 50, fit: BoxFit.cover)),
                        title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryDark)),
                        subtitle: Text(song.artist ?? "Unknown Artist", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        trailing: IconButton(icon: Icon(Icons.play_arrow_rounded, color: accentBlue, size: 28), onPressed: () => _playSong(song)),
                        onTap: () => _playSong(song),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchScreen() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Search", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: primaryDark)),
          const SizedBox(height: 16),
          TextField(
            onChanged: _filterSongs,
            decoration: InputDecoration(
              hintText: "Artists, Songs, and More",
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                SongModel song = _searchResults[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(defaultArt, width: 40, height: 40, fit: BoxFit.cover)),
                  title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, color: primaryDark)),
                  subtitle: Text(song.artist ?? "Unknown", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600])),
                  onTap: () => _playSong(song),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryScreen() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Library", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: primaryDark)),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: accentBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.favorite, color: Colors.red)),
                  title: const Text("Favorite Songs", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                ListTile(
                  leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: accentBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.playlist_play, color: accentBlue)),
                  title: const Text("Playlists", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110, height: 110,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: accentBlue, width: 2)),
            child: ClipOval(child: Image.network("https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=200&auto=format&fit=crop", fit: BoxFit.cover)),
          ),
          const SizedBox(height: 16),
          Text("Rehan Alam", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: primaryDark)),
          const SizedBox(height: 4),
          Text("Apple Music Edition", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ],
      ),
    );
  }

  // GLASSMORPHISM MINI PLAYER
  Widget _buildGlassMiniPlayer() {
    return Positioned(
      bottom: 12, left: 16, right: 16,
      child: GestureDetector(
        onTap: _openFullPlayerModal,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.55),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colo
