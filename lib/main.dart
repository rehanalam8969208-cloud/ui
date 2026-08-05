import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Background Notification Initialization
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ui.music.channel.audio',
    androidNotificationChannelName: 'UI Music Playback',
    androidNotificationOngoing: true,
  );
  
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
  final List<SongModel> _favoriteSongs = [];
  final List<SongModel> _recentlyPlayed = [];
  
  SongModel? _currentSong;
  bool _isPlaying = false;
  bool _isShuffle = false;
  LoopMode _loopMode = LoopMode.off;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Realistic Images (No cartoons)
  final String realisticMusicIcon = "https://images.unsplash.com/photo-1505740420928-5e560c06d30e?q=80&w=200&auto=format&fit=crop"; 
  final String realisticProfilePhoto = "https://images.unsplash.com/photo-1511367461989-f85a21fda167?q=80&w=200&auto=format&fit=crop";

  // Light Theme Colors
  final Color textDarkBlue = const Color(0xFF006B99);
  final Color buttonCyan = const Color(0xFF00BCD4);
  final Color bgLightBlueTop = const Color(0xFFD6EAF8);
  final Color bgLightBlueBottom = const Color(0xFFEBF5FB);
  final Color whiteCard = Colors.white;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndLoad();
    _initAudioListeners();
  }

  void _checkPermissionAndLoad() async {
    PermissionStatus statusAudio = await Permission.audio.request();
    PermissionStatus statusStorage = await Permission.storage.request();

    if (statusAudio.isGranted || statusStorage.isGranted) {
      _loadLocalSongs();
    }
  }

  void _loadLocalSongs() async {
    try {
      List<SongModel> songs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );
      
      if (mounted) {
        setState(() {
          // Filter out call recordings & whatsapp audio
          _allSongs = songs.where((s) {
            final path = s.data.toLowerCase();
            return s.isMusic == true && 
                   !path.contains('call') && 
                   !path.contains('record') &&
                   !path.contains('whatsapp');
          }).toList();
        });
      }
    } catch (e) {
      debugPrint("Error loading songs: $e");
    }
  }

  void _initAudioListeners() {
    _audioPlayer.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _audioPlayer.durationStream.listen((d) {
      if (mounted) setState(() => _duration = d ?? Duration.zero);
    });
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state.playing);
        if (state.processingState == ProcessingState.completed) _playNext();
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
          album: song.album ?? "Local Album",
          title: song.title,
          artist: song.artist ?? "Unknown Artist",
          artUri: Uri.parse(realisticMusicIcon),
        ),
      );
      
      await _audioPlayer.setAudioSource(audioSource);
      _audioPlayer.play();
      if (mounted) {
        setState(() {
          _currentSong = song;
          if (!_recentlyPlayed.any((s) => s.id == song.id)) {
            _recentlyPlayed.insert(0, song);
          }
        });
      }
    } catch (e) {
      debugPrint("Playback error: $e");
    }
  }

  void _playNext() {
    if (_allSongs.isEmpty || _currentSong == null) return;
    int idx = _allSongs.indexWhere((s) => s.id == _currentSong!.id);
    if (idx != -1 && idx < _allSongs.length - 1) _playSong(_allSongs[idx + 1]);
  }

  void _playPrevious() {
    if (_allSongs.isEmpty || _currentSong == null) return;
    int idx = _allSongs.indexWhere((s) => s.id == _currentSong!.id);
    if (idx > 0) _playSong(_allSongs[idx - 1]);
  }

  void _openFullPlayerModal() {
    if (_currentSong == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgLightBlueBottom,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.90,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [bgLightBlueTop, bgLightBlueBottom], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(icon: Icon(Icons.keyboard_arrow_down, size: 32, color: textDarkBlue), onPressed: () => Navigator.pop(context)),
                      Text("NOW PLAYING", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDarkBlue, letterSpacing: 1.5)),
                      IconButton(
                        icon: Icon(_favoriteSongs.any((s) => s.id == _currentSong!.id) ? Icons.favorite : Icons.favorite_border, color: Colors.redAccent),
                        onPressed: () {
                          setState(() {
                            if (_favoriteSongs.any((s) => s.id == _currentSong!.id)) {
                              _favoriteSongs.removeWhere((s) => s.id == _currentSong!.id);
                            } else {
                              _favoriteSongs.add(_currentSong!);
                            }
                          });
                          setModalState(() {});
                        },
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    width: 280, height: 280,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [BoxShadow(color: buttonCyan.withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 15))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: Image.network(realisticMusicIcon, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.white, child: Icon(Icons.music_note, size: 80, color: textDarkBlue))),
                    ),
                  ),
                  const Spacer(),
                  Text(_currentSong!.title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textDarkBlue)),
                  const SizedBox(height: 8),
                  Text(_currentSong!.artist ?? "Unknown Artist", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                  const SizedBox(height: 30),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(activeTrackColor: buttonCyan, thumbColor: buttonCyan, inactiveTrackColor: Colors.black12, trackHeight: 4),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}", style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                        Text("${_duration.inMinutes}:${(_duration.inSeconds % 60).toString().padLeft(2, '0')}", style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(icon: Icon(Icons.shuffle, color: _isShuffle ? buttonCyan : Colors.grey), onPressed: () { setState(() => _isShuffle = !_isShuffle); setModalState(() {}); }),
                      IconButton(icon: Icon(Icons.skip_previous, size: 36, color: textDarkBlue), onPressed: _playPrevious),
                      GestureDetector(
                        onTap: () {
                          _isPlaying ? _audioPlayer.pause() : _audioPlayer.play();
                          setModalState(() {});
                        },
                        child: Container(
                          width: 70, height: 70,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: buttonCyan, boxShadow: [BoxShadow(color: buttonCyan.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5))]),
                          child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 36, color: Colors.white),
                        ),
                      ),
                      IconButton(icon: Icon(Icons.skip_next, size: 36, color: textDarkBlue), onPressed: _playNext),
                      IconButton(icon: Icon(Icons.repeat, color: _loopMode != LoopMode.off ? buttonCyan : Colors.grey), onPressed: () { setState(() { _loopMode = _loopMode == LoopMode.off ? LoopMode.one : LoopMode.off; _audioPlayer.setLoopMode(_loopMode); }); setModalState(() {}); }),
                    ],
                  ),
                  const Spacer(),
                ],
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
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: [bgLightBlueTop, bgLightBlueBottom], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: SafeArea(
          child: Stack(
            children: [
              [_buildHomeScreen(), _buildSearchScreen(), _buildLibraryScreen(), _buildProfileScreen()][_currentIndex],
              if (_currentSong != null) _buildMiniPlayerBar(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, -5))],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: buttonCyan,
          unselectedItemColor: Colors.grey,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
            BottomNavigationBarItem(icon: Icon(Icons.library_music), label: "Library"),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          ],
        ),
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
          child: _allSongs.isEmpty
              ? Center(child: Text("No Music Found\nOr Permission Needed", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])))
              : ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 100),
                  itemCount: _allSongs.length,
                  itemBuilder: (context, index) {
                    SongModel song = _allSongs[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: whiteCard,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(realisticMusicIcon, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(width: 50, height: 50, color: bgLightBlueTop, child: Icon(Icons.music_note, color: textDarkBlue))),
                        ),
                        title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textDarkBlue)),
                        subtitle: Text(song.artist ?? "Unknown Artist", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        trailing: IconButton(icon: Icon(Icons.play_circle_fill, color: buttonCyan, size: 32), onPressed: () => _playSong(song)),
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
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: "Search songs...",
              prefixIcon: Icon(Icons.search, color: buttonCyan),
              filled: true,
              fillColor: whiteCard,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const Expanded(child: Center(child: Icon(Icons.search, size: 80, color: Colors.black12))),
        ],
      ),
    );
  }

  Widget _buildLibraryScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_music, size: 80, color: buttonCyan.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text("Your Playlists & Favorites", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDarkBlue)),
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
            width: 120, height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: buttonCyan, width: 3),
              boxShadow: [BoxShadow(color: buttonCyan.withOpacity(0.3), blurRadius: 20)],
            ),
            child: ClipOval(
              child: Image.network(realisticProfilePhoto, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.white, child: Icon(Icons.person, size: 60, color: textDarkBlue))),
            ),
          ),
          const SizedBox(height: 20),
          Text("Rehan Alam", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textDarkBlue)),
          const SizedBox(height: 8),
          Text("Premium Light Edition", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildMiniPlayerBar() {
    return Positioned(
      bottom: 10, left: 16, right: 16,
      child: GestureDetector(
        onTap: _openFullPlayerModal,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: textDarkBlue,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: textDarkBlue.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5))],
          ),
          child: Row(
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(realisticMusicIcon, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(width: 44, height: 44, color: Colors.white24, child: const Icon(Icons.music_note, color: Colors.white)))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_currentSong!.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                    Text(_currentSong!.artist ?? "Unknown", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
              IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 38, color: buttonCyan), onPressed: () { _isPlaying ? _audioPlayer.pause() : _audioPlayer.play(); }),
              const SizedBox(width: 8),
              IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.skip_next, size: 28, color: Colors.white), onPressed: _playNext),
            ],
          ),
        ),
      ),
    );
  }
}
