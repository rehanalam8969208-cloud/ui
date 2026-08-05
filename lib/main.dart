import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';

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
        fontFamily: 'Roboto', // Clean font matching the UI
        primaryColor: const Color(0xFF00B4D8),
      ),
      home: const MainHomeScreen(),
    );
  }
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<SongModel> _allSongs = [];
  SongModel? _currentSong;
  bool _isPlaying = false;
  
  // Design Colors extracted exactly from your image
  final Color textDarkBlue = const Color(0xFF006B99);
  final Color buttonCyan = const Color(0xFF00BCD4);
  final Color bgLightBlueTop = const Color(0xFFD6EAF8);
  final Color bgLightBlueBottom = const Color(0xFFEBF5FB);

  @override
  void initState() {
    super.initState();
    _checkPermissionAndLoad();
    
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) setState(() => _isPlaying = state.playing);
    });
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
          // PERFECT FILTER: Removes Call Recordings & WhatsApp Audio completely
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

  void _playSong(SongModel song) async {
    if (song.uri == null) return;
    try {
      await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(song.uri!)));
      _audioPlayer.play();
      if (mounted) setState(() => _currentSong = song);
    } catch (e) {
      debugPrint("Playback error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [bgLightBlueTop, bgLightBlueBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HEADER ROW
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text("💜 ", style: TextStyle(fontSize: 22)),
                              Text("REHAN & JANNAT", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDarkBlue, letterSpacing: 0.5)),
                            ],
                          ),
                          Row(
                            children: [
                              CircleAvatar(backgroundColor: Colors.white.withOpacity(0.6), radius: 20, child: const Icon(Icons.search, color: Colors.black54, size: 22)),
                              const SizedBox(width: 10),
                              CircleAvatar(backgroundColor: Colors.white.withOpacity(0.6), radius: 20, child: const Icon(Icons.access_time, color: Colors.black54, size: 22)),
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // WELCOME TEXT
                      Text("Welcome Rehan! 💙", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDarkBlue)),
                      const SizedBox(height: 16),

                      // LOCKER CARD
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.folder, color: Color(0xFFFFCA28), size: 36),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("REHAN'S LOCKER", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: textDarkBlue, letterSpacing: 0.5)),
                                  const SizedBox(height: 2),
                                  const Text("Tap to Open SD Card Files", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                            Text("Open ➔", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textDarkBlue)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // FEATURED ALBUM CARD
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("FEATURED ALBUM", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: textDarkBlue, letterSpacing: 1.2)),
                            const SizedBox(height: 8),
                            const Text("Zaalima", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1C2833))),
                            const SizedBox(height: 4),
                            Text("By Arijit Singh", style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: buttonCyan,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                              icon: const Icon(Icons.play_arrow, size: 20),
                              label: const Text("Play Now", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              onPressed: () {
                                if (_allSongs.isNotEmpty) _playSong(_allSongs.first);
                              },
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // TRENDING NOW SECTION
                      const Text("Trending Now", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1C2833))),
                      const SizedBox(height: 16),
                      
                      _allSongs.isEmpty 
                      ? const Padding(padding: EdgeInsets.all(20.0), child: Center(child: CircularProgressIndicator()))
                      : SizedBox(
                          height: 180,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _allSongs.length,
                            itemBuilder: (context, index) {
                              SongModel song = _allSongs[index];
                              return GestureDetector(
                                onTap: () => _playSong(song),
                                child: Container(
                                  width: 120,
                                  margin: const EdgeInsets.only(right: 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        height: 120,
                                        width: 120,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(20),
                                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(20),
                                          child: Image.network(
                                            "https://images.unsplash.com/photo-1511367461989-f85a21fda167?q=80&w=200&auto=format&fit=crop", 
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) => const Icon(Icons.music_note, color: Colors.grey, size: 40),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1C2833))),
                                      Text(song.artist ?? "Unknown Artist", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[700], fontSize: 11)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              // NEW CLEAN MINI PLAYER
              if (_currentSong != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: bgLightBlueTop, borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.music_note, color: textDarkBlue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_currentSong!.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textDarkBlue)),
                            Text(_currentSong!.artist ?? "Unknown", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          _isPlaying ? _audioPlayer.pause() : _audioPlayer.play();
                        },
                        child: CircleAvatar(
                          backgroundColor: buttonCyan,
                          radius: 22,
                          child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                        ),
                      )
                    ],
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }
}
