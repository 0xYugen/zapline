/// Countries and languages providers tag their groups with ("IT | Sport",
/// "UK: News", "[DE] Kino"), so groups can be shown by country.
library;

/// The country or language tag a group title starts with, as a key of
/// [countryNames]; `null` when it has none.
String? groupCountry(String title) {
  final t = title.trim();
  final lower = t.toLowerCase();
  if (lower.startsWith('italia') || lower.startsWith('italy')) return 'it';
  final m = _leadingTag.firstMatch(t);
  if (m == null) return null;
  final tag = m.group(1)!;
  // Only upper-case tags: "Rai" or "Sky" are not country codes.
  if (tag != tag.toUpperCase()) return null;
  final code = _aliases[tag.toLowerCase()] ?? tag.toLowerCase();
  return countryNames.containsKey(code) ? code : null;
}

final _leadingTag = RegExp(r'^\W*([A-Za-z]{2,3})(?![A-Za-z0-9])');

const _aliases = {
  'gb': 'uk',
  'ita': 'it',
  'ger': 'de',
  'deu': 'de',
  'fra': 'fr',
  'esp': 'es',
  'spa': 'es',
  'por': 'pt',
  'pol': 'pl',
  'tur': 'tr',
  'usa': 'us',
  'eng': 'en',
  'swe': 'se',
  'nor': 'no',
  'den': 'dk',
  'ned': 'nl',
  'alb': 'al',
  'rus': 'ru',
  'ara': 'ar',
  'bra': 'br',
  'can': 'ca',
  'mex': 'mx',
  'ind': 'in',
};

/// Tag → (Italian, English) name. "AR" stands for Arabic in IPTV lists far
/// more often than for Argentina.
const countryNames = {
  'it': ('Italia', 'Italy'),
  'uk': ('Regno Unito', 'United Kingdom'),
  'us': ('Stati Uniti', 'United States'),
  'en': ('Inglese', 'English'),
  'de': ('Germania', 'Germany'),
  'fr': ('Francia', 'France'),
  'es': ('Spagna', 'Spain'),
  'pt': ('Portogallo', 'Portugal'),
  'nl': ('Paesi Bassi', 'Netherlands'),
  'be': ('Belgio', 'Belgium'),
  'ch': ('Svizzera', 'Switzerland'),
  'at': ('Austria', 'Austria'),
  'pl': ('Polonia', 'Poland'),
  'ro': ('Romania', 'Romania'),
  'al': ('Albania', 'Albania'),
  'gr': ('Grecia', 'Greece'),
  'tr': ('Turchia', 'Turkey'),
  'se': ('Svezia', 'Sweden'),
  'no': ('Norvegia', 'Norway'),
  'dk': ('Danimarca', 'Denmark'),
  'fi': ('Finlandia', 'Finland'),
  'ie': ('Irlanda', 'Ireland'),
  'hr': ('Croazia', 'Croatia'),
  'rs': ('Serbia', 'Serbia'),
  'ba': ('Bosnia', 'Bosnia'),
  'si': ('Slovenia', 'Slovenia'),
  'mk': ('Macedonia del Nord', 'North Macedonia'),
  'me': ('Montenegro', 'Montenegro'),
  'bg': ('Bulgaria', 'Bulgaria'),
  'cz': ('Repubblica Ceca', 'Czechia'),
  'sk': ('Slovacchia', 'Slovakia'),
  'hu': ('Ungheria', 'Hungary'),
  'ru': ('Russia', 'Russia'),
  'ua': ('Ucraina', 'Ukraine'),
  'ca': ('Canada', 'Canada'),
  'mx': ('Messico', 'Mexico'),
  'br': ('Brasile', 'Brazil'),
  'ar': ('Arabo', 'Arabic'),
  'in': ('India', 'India'),
  'pk': ('Pakistan', 'Pakistan'),
  'af': ('Africa', 'Africa'),
  'jp': ('Giappone', 'Japan'),
  'kr': ('Corea', 'Korea'),
  'cn': ('Cina', 'China'),
  'il': ('Israele', 'Israel'),
  'ir': ('Iran', 'Iran'),
  'au': ('Australia', 'Australia'),
  'nz': ('Nuova Zelanda', 'New Zealand'),
  'lat': ('America Latina', 'Latin America'),
  'cy': ('Cipro', 'Cyprus'),
  'mt': ('Malta', 'Malta'),
  'lu': ('Lussemburgo', 'Luxembourg'),
};

String countryName(String code, String languageCode) {
  final names = countryNames[code];
  if (names == null) return code.toUpperCase();
  return languageCode == 'it' ? names.$1 : names.$2;
}
