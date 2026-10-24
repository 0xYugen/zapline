import 'dart:ui';

/// Free, public EPG (XMLTV) guides by country, offered with one tap when a
/// source's own guide is missing or thin. Zapline only points to them; they
/// are run by third parties for legal use with any player.
///
/// iptv-epg.org publishes one guide per country under the same address
/// pattern. Italy also gets epgshare01 and two open-epg.com files (checked
/// 2026-10-24: about 370 Italian channels, 59 of 60 common provider names
/// matched).
class FreeEpg {
  const FreeEpg(this.code, this.name);

  /// ISO 3166 country code, lower case.
  final String code;
  final String name;

  List<String> get urls => [
    'https://iptv-epg.org/files/epg-$code.xml.gz',
    ...?_extra[code],
  ];

  static const _extra = {
    'it': [
      'https://epgshare01.online/epgshare01/epg_ripper_IT1.xml.gz',
      // Small guides that add ~25 channels the others lack (Tgcom24,
      // Rai 4K, Top Calcio 24, music and regional channels).
      'https://www.open-epg.com/files/italy2.xml.gz',
      'https://www.open-epg.com/files/italy3.xml.gz',
    ],
  };

  /// The country whose free EPG [url] belongs to, if any.
  static FreeEpg? ofUrl(String url) {
    for (final c in countries) {
      if (c.urls.contains(url)) return c;
    }
    return null;
  }

  /// The user's country from the device language settings, when listed.
  static FreeEpg? forLocale(Locale locale) {
    final cc = locale.countryCode?.toLowerCase();
    final byCountry = countries.where((c) => c.code == cc).firstOrNull;
    if (byCountry != null) return byCountry;
    // Language only ("it"): its main country.
    final lang = locale.languageCode.toLowerCase();
    return countries.where((c) => c.code == _langCountry[lang]).firstOrNull;
  }

  static const _langCountry = {
    'it': 'it',
    'de': 'de',
    'fr': 'fr',
    'es': 'es',
    'pt': 'pt',
    'nl': 'nl',
    'pl': 'pl',
    'en': 'gb',
    'el': 'gr',
    'ro': 'ro',
    'tr': 'tr',
    'sv': 'se',
    'da': 'dk',
    'fi': 'fi',
    'cs': 'cz',
    'hr': 'hr',
    'sq': 'al',
  };

  static const countries = [
    FreeEpg('al', 'Albania'),
    FreeEpg('ar', 'Argentina'),
    FreeEpg('am', 'Armenia'),
    FreeEpg('au', 'Australia'),
    FreeEpg('at', 'Austria'),
    FreeEpg('bs', 'Bahamas'),
    FreeEpg('by', 'Belarus'),
    FreeEpg('be', 'Belgium'),
    FreeEpg('bo', 'Bolivia'),
    FreeEpg('ba', 'Bosnia and Herzegovina'),
    FreeEpg('br', 'Brazil'),
    FreeEpg('bg', 'Bulgaria'),
    FreeEpg('ca', 'Canada'),
    FreeEpg('cl', 'Chile'),
    FreeEpg('co', 'Colombia'),
    FreeEpg('cr', 'Costa Rica'),
    FreeEpg('hr', 'Croatia'),
    FreeEpg('cw', 'Curaçao'),
    FreeEpg('cz', 'Czechia'),
    FreeEpg('dk', 'Denmark'),
    FreeEpg('do', 'Dominican Republic'),
    FreeEpg('ec', 'Ecuador'),
    FreeEpg('sv', 'El Salvador'),
    FreeEpg('fi', 'Finland'),
    FreeEpg('fr', 'France'),
    FreeEpg('ge', 'Georgia'),
    FreeEpg('de', 'Germany'),
    FreeEpg('gh', 'Ghana'),
    FreeEpg('gr', 'Greece'),
    FreeEpg('gt', 'Guatemala'),
    FreeEpg('hn', 'Honduras'),
    FreeEpg('hk', 'Hong Kong'),
    FreeEpg('is', 'Iceland'),
    FreeEpg('in', 'India'),
    FreeEpg('id', 'Indonesia'),
    FreeEpg('il', 'Israel'),
    FreeEpg('it', 'Italy'),
    FreeEpg('jm', 'Jamaica'),
    FreeEpg('jp', 'Japan'),
    FreeEpg('lv', 'Latvia'),
    FreeEpg('lt', 'Lithuania'),
    FreeEpg('lu', 'Luxembourg'),
    FreeEpg('my', 'Malaysia'),
    FreeEpg('mt', 'Malta'),
    FreeEpg('mx', 'Mexico'),
    FreeEpg('me', 'Montenegro'),
    FreeEpg('nl', 'Netherlands'),
    FreeEpg('nz', 'New Zealand'),
    FreeEpg('ni', 'Nicaragua'),
    FreeEpg('ng', 'Nigeria'),
    FreeEpg('no', 'Norway'),
    FreeEpg('pa', 'Panama'),
    FreeEpg('py', 'Paraguay'),
    FreeEpg('pe', 'Peru'),
    FreeEpg('pl', 'Poland'),
    FreeEpg('pt', 'Portugal'),
    FreeEpg('ro', 'Romania'),
    FreeEpg('ru', 'Russia'),
    FreeEpg('rs', 'Serbia'),
    FreeEpg('sg', 'Singapore'),
    FreeEpg('za', 'South Africa'),
    FreeEpg('kr', 'South Korea'),
    FreeEpg('es', 'Spain'),
    FreeEpg('se', 'Sweden'),
    FreeEpg('ch', 'Switzerland'),
    FreeEpg('tw', 'Taiwan'),
    FreeEpg('th', 'Thailand'),
    FreeEpg('tt', 'Trinidad and Tobago'),
    FreeEpg('tr', 'Turkey'),
    FreeEpg('ug', 'Uganda'),
    FreeEpg('ua', 'Ukraine'),
    FreeEpg('gb', 'United Kingdom'),
    FreeEpg('us', 'United States'),
    FreeEpg('uy', 'Uruguay'),
    FreeEpg('ve', 'Venezuela'),
    FreeEpg('zw', 'Zimbabwe'),
  ];
}
