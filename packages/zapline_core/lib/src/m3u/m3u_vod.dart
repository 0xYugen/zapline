import 'm3u_parser.dart';

/// What a playlist entry is. Xtream-style playlists put films under
/// `/movie/` and episodes under `/series/`; everything else is live TV.
enum M3uKind { live, movie, episode }

M3uKind classifyM3uEntry(M3uEntry e) {
  final path = Uri.tryParse(e.url)?.path.toLowerCase() ?? '';
  if (path.contains('/movie/')) return M3uKind.movie;
  if (path.contains('/series/')) return M3uKind.episode;
  return M3uKind.live;
}

/// "Show Name S02 E05", "Show.Name.S2E5 Title", "Show - 2x05": the show,
/// season and episode; `null` when the name has no episode marker.
({String show, int season, int episode})? parseEpisodeName(String name) {
  final m = RegExp(
    r'^(.*?)[\s._-]*(?:S(\d{1,2})[\s._-]*E(\d{1,3})|(\d{1,2})x(\d{1,3}))',
    caseSensitive: false,
  ).firstMatch(name);
  if (m == null) return null;
  final show = m.group(1)!.replaceAll(RegExp(r'[._]+'), ' ').trim();
  if (show.isEmpty) return null;
  return (
    show: show,
    season: int.parse(m.group(2) ?? m.group(4)!),
    episode: int.parse(m.group(3) ?? m.group(5)!),
  );
}
