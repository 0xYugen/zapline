import 'dart:convert';

import 'package:test/test.dart';
import 'package:zapline_core/zapline_core.dart';

void main() {
  test('get_vod_info with the usual panel quirks', () {
    final d = parseVodInfo(
      jsonDecode('''
      {"info": {"movie_image": "http://img.example/p.jpg",
                "backdrop_path": ["http://img.example/b.jpg"],
                "plot": "A plot.", "cast": "A, B", "director": "C",
                "genre": "Drama", "releasedate": "2019-05-01",
                "duration_secs": "6730", "rating": "7.4",
                "youtube_trailer": "abc123"},
       "movie_data": {"stream_id": 9, "container_extension": "mkv"}}
      '''),
    );
    expect(d.plot, 'A plot.');
    expect(d.cast, 'A, B');
    expect(d.duration, const Duration(seconds: 6730));
    expect(d.rating, 7.4);
    expect(d.posterUrl.toString(), 'http://img.example/p.jpg');
    expect(d.backdropUrl.toString(), 'http://img.example/b.jpg');
    expect(d.containerExtension, 'mkv');
    expect(d.trailer, 'abc123');

    // Empty values, "N/A" and an "hh:mm:ss" duration.
    final e = parseVodInfo({
      'info': {'plot': '', 'cast': 'N/A', 'duration': '01:52:10', 'rating': 0},
    });
    expect(e.plot, isNull);
    expect(e.cast, isNull);
    expect(e.rating, isNull);
    expect(e.duration, const Duration(hours: 1, minutes: 52, seconds: 10));
  });

  test('get_series_info with episodes as a map or a list', () {
    final asMap = parseSeriesInfo(
      jsonDecode('''
      {"seasons": [{"season_number": 1, "name": "Season 1"}],
       "info": {"name": "S", "plot": "P", "rating": "8.1",
                "cover": "http://img.example/c.jpg"},
       "episodes": {"2": [{"id": "21", "episode_num": 1, "season": 2,
                           "title": "Two one", "container_extension": "mp4",
                           "info": {"duration_secs": 2700}}],
                    "1": [{"id": "12", "episode_num": "2", "season": "1",
                           "title": "One two"},
                          {"id": "11", "episode_num": 1, "season": 1,
                           "title": "One one"}]}}
      '''),
    );
    expect(asMap.seasons, [1, 2]);
    expect(asMap.inSeason(1).map((e) => e.title), ['One one', 'One two']);
    expect(asMap.inSeason(2).single.duration, const Duration(minutes: 45));
    expect(asMap.seasonNames[1], 'Season 1');
    expect(asMap.rating, 8.1);

    final asList = parseSeriesInfo({
      'episodes': [
        {'id': '1', 'episode_num': 1, 'season': 1, 'title': 'Pilot'},
      ],
    });
    expect(asList.episodes.single.title, 'Pilot');
  });

  test('playlist entries: films, episodes and their names', () {
    M3uEntry entry(String url) =>
        M3uEntry(title: 'x', url: url, duration: -1, attributes: const {});
    expect(
      classifyM3uEntry(entry('http://p.example/movie/u/p/1.mkv')),
      M3uKind.movie,
    );
    expect(
      classifyM3uEntry(entry('http://p.example/series/u/p/7.mp4')),
      M3uKind.episode,
    );
    expect(
      classifyM3uEntry(entry('http://p.example/live/u/p/3.ts')),
      M3uKind.live,
    );
    expect(parseEpisodeName('La casa S02 E05'), (
      show: 'La casa',
      season: 2,
      episode: 5,
    ));
    expect(parseEpisodeName('Show.Name.S1E12.720p')?.show, 'Show Name');
    expect(parseEpisodeName('Serie - 3x07')?.season, 3);
    expect(parseEpisodeName('Just a film (2019)'), isNull);
    expect(
      const Movie(sourceId: 's', id: '1', name: 'Il film (2019)').year,
      2019,
    );
  });
}
