class TeamsDataService {
  // --- National Teams Data ---
  static List<Map<String, String>> getNationalTeams() {
    return [
      {'name': 'Afghanistan', 'code': 'AFG', 'flag': 'af'},
      {'name': 'Albania', 'code': 'ALB', 'flag': 'al'},
      {'name': 'Algeria', 'code': 'ALG', 'flag': 'dz'},
      {'name': 'Argentina', 'code': 'ARG', 'flag': 'ar'},
      {'name': 'Armenia', 'code': 'ARM', 'flag': 'am'},
      {'name': 'Australia', 'code': 'AUS', 'flag': 'au'},
      {'name': 'Austria', 'code': 'AUT', 'flag': 'at'},
      {'name': 'Azerbaijan', 'code': 'AZE', 'flag': 'az'},
      {'name': 'Bahrain', 'code': 'BHR', 'flag': 'bh'},
      {'name': 'Bangladesh', 'code': 'BAN', 'flag': 'bd'},
      {'name': 'Belgium', 'code': 'BEL', 'flag': 'be'},
      {'name': 'Bolivia', 'code': 'BOL', 'flag': 'bo'},
      {'name': 'Bosnia & Herzegovina', 'code': 'BIH', 'flag': 'ba'},
      {'name': 'Brazil', 'code': 'BRA', 'flag': 'br'},
      {'name': 'Bulgaria', 'code': 'BUL', 'flag': 'bg'},
      {'name': 'Cameroon', 'code': 'CMR', 'flag': 'cm'},
      {'name': 'Canada', 'code': 'CAN', 'flag': 'ca'},
      {'name': 'Chile', 'code': 'CHI', 'flag': 'cl'},
      {'name': 'China PR', 'code': 'CHN', 'flag': 'cn'},
      {'name': 'Colombia', 'code': 'COL', 'flag': 'co'},
      {'name': 'Costa Rica', 'code': 'CRC', 'flag': 'cr'},
      {'name': 'Croatia', 'code': 'CRO', 'flag': 'hr'},
      {'name': 'Cyprus', 'code': 'CYP', 'flag': 'cy'},
      {'name': 'Czech Republic', 'code': 'CZE', 'flag': 'cz'},
      {'name': 'Denmark', 'code': 'DEN', 'flag': 'dk'},
      {'name': 'Ecuador', 'code': 'ECU', 'flag': 'ec'},
      {'name': 'Egypt', 'code': 'EGY', 'flag': 'eg'},
      {'name': 'England', 'code': 'ENG', 'flag': 'gb-eng'},
      {'name': 'Estonia', 'code': 'EST', 'flag': 'ee'},
      {'name': 'Finland', 'code': 'FIN', 'flag': 'fi'},
      {'name': 'France', 'code': 'FRA', 'flag': 'fr'},
      {'name': 'Georgia', 'code': 'GEO', 'flag': 'ge'},
      {'name': 'Germany', 'code': 'GER', 'flag': 'de'},
      {'name': 'Ghana', 'code': 'GHA', 'flag': 'gh'},
      {'name': 'Greece', 'code': 'GRE', 'flag': 'gr'},
      {'name': 'Hungary', 'code': 'HUN', 'flag': 'hu'},
      {'name': 'Iceland', 'code': 'ISL', 'flag': 'is'},
      {'name': 'India', 'code': 'IND', 'flag': 'in'},
      {'name': 'Indonesia', 'code': 'IDN', 'flag': 'id'},
      {'name': 'Iran', 'code': 'IRN', 'flag': 'ir'},
      {'name': 'Iraq', 'code': 'IRQ', 'flag': 'iq'},
      {'name': 'Ireland', 'code': 'IRL', 'flag': 'ie'},
      {'name': 'Israel', 'code': 'ISR', 'flag': 'il'},
      {'name': 'Italy', 'code': 'ITA', 'flag': 'it'},
      {'name': 'Ivory Coast', 'code': 'CIV', 'flag': 'ci'},
      {'name': 'Jamaica', 'code': 'JAM', 'flag': 'jm'},
      {'name': 'Japan', 'code': 'JPN', 'flag': 'jp'},
      {'name': 'Jordan', 'code': 'JOR', 'flag': 'jo'},
      {'name': 'Kazakhstan', 'code': 'KAZ', 'flag': 'kz'},
      {'name': 'Kenya', 'code': 'KEN', 'flag': 'ke'},
      {'name': 'Kuwait', 'code': 'KUW', 'flag': 'kw'},
      {'name': 'Latvia', 'code': 'LVA', 'flag': 'lv'},
      {'name': 'Lebanon', 'code': 'LBN', 'flag': 'lb'},
      {'name': 'Lithuania', 'code': 'LTU', 'flag': 'lt'},
      {'name': 'Luxembourg', 'code': 'LUX', 'flag': 'lu'},
      {'name': 'Malaysia', 'code': 'MAS', 'flag': 'my'},
      {'name': 'Malta', 'code': 'MLT', 'flag': 'mt'},
      {'name': 'Mexico', 'code': 'MEX', 'flag': 'mx'},
      {'name': 'Moldova', 'code': 'MDA', 'flag': 'md'},
      {'name': 'Montenegro', 'code': 'MNE', 'flag': 'me'},
      {'name': 'Morocco', 'code': 'MAR', 'flag': 'ma'},
      {'name': 'Netherlands', 'code': 'NED', 'flag': 'nl'},
      {'name': 'New Zealand', 'code': 'NZL', 'flag': 'nz'},
      {'name': 'Nigeria', 'code': 'NGA', 'flag': 'ng'},
      {'name': 'North Macedonia', 'code': 'MKD', 'flag': 'mk'},
      {'name': 'Northern Ireland', 'code': 'NIR', 'flag': 'gb-nir'},
      {'name': 'Norway', 'code': 'NOR', 'flag': 'no'},
      {'name': 'Oman', 'code': 'OMA', 'flag': 'om'},
      {'name': 'Pakistan', 'code': 'PAK', 'flag': 'pk'},
      {'name': 'Palestine', 'code': 'PLE', 'flag': 'ps'},
      {'name': 'Paraguay', 'code': 'PAR', 'flag': 'py'},
      {'name': 'Peru', 'code': 'PER', 'flag': 'pe'},
      {'name': 'Philippines', 'code': 'PHI', 'flag': 'ph'},
      {'name': 'Poland', 'code': 'POL', 'flag': 'pl'},
      {'name': 'Portugal', 'code': 'POR', 'flag': 'pt'},
      {'name': 'Qatar', 'code': 'QAT', 'flag': 'qa'},
      {'name': 'Romania', 'code': 'ROU', 'flag': 'ro'},
      {'name': 'Russia', 'code': 'RUS', 'flag': 'ru'},
      {'name': 'Saudi Arabia', 'code': 'KSA', 'flag': 'sa'},
      {'name': 'Scotland', 'code': 'SCO', 'flag': 'gb-sct'},
      {'name': 'Senegal', 'code': 'SEN', 'flag': 'sn'},
      {'name': 'Serbia', 'code': 'SRB', 'flag': 'rs'},
      {'name': 'Singapore', 'code': 'SGP', 'flag': 'sg'},
      {'name': 'Slovakia', 'code': 'SVK', 'flag': 'sk'},
      {'name': 'Slovenia', 'code': 'SVN', 'flag': 'si'},
      {'name': 'South Africa', 'code': 'RSA', 'flag': 'za'},
      {'name': 'South Korea', 'code': 'KOR', 'flag': 'kr'},
      {'name': 'Spain', 'code': 'ESP', 'flag': 'es'},
      {'name': 'Sweden', 'code': 'SWE', 'flag': 'se'},
      {'name': 'Switzerland', 'code': 'SUI', 'flag': 'ch'},
      {'name': 'Syria', 'code': 'SYR', 'flag': 'sy'},
      {'name': 'Thailand', 'code': 'THA', 'flag': 'th'},
      {'name': 'Tunisia', 'code': 'TUN', 'flag': 'tn'},
      {'name': 'Turkey', 'code': 'TUR', 'flag': 'tr'},
      {'name': 'Ukraine', 'code': 'UKR', 'flag': 'ua'},
      {'name': 'United Arab Emirates', 'code': 'UAE', 'flag': 'ae'},
      {'name': 'United States', 'code': 'USA', 'flag': 'us'},
      {'name': 'Uruguay', 'code': 'URU', 'flag': 'uy'},
      {'name': 'Uzbekistan', 'code': 'UZB', 'flag': 'uz'},
      {'name': 'Venezuela', 'code': 'VEN', 'flag': 've'},
      {'name': 'Vietnam', 'code': 'VIE', 'flag': 'vn'},
      {'name': 'Wales', 'code': 'WAL', 'flag': 'gb-wls'},
    ]..sort((a, b) => a['name']!.compareTo(b['name']!));
  }

  // --- Leagues Data ---
  static List<Map<String, String>> getLeagues() {
    return [
      {'id': 'pl', 'name': 'Premier League', 'country': 'England'},
      {'id': 'laliga', 'name': 'La Liga', 'country': 'Spain'},
      {'id': 'bundesliga', 'name': 'Bundesliga', 'country': 'Germany'},
      {'id': 'seriea', 'name': 'Serie A', 'country': 'Italy'},
      {'id': 'ligue1', 'name': 'Ligue 1', 'country': 'France'},
    ];
  }

  // --- Club Teams Data ---
  static List<Map<String, String>> getClubTeams(String leagueId) {
    switch (leagueId) {
      case 'pl':
        return [
          {
            'name': 'Arsenal',
            'code': 'ARS',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/5/53/Arsenal_FC.svg/330px-Arsenal_FC.svg.png',
          },
          {
            'name': 'Aston Villa',
            'code': 'AVL',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/9/9a/Aston_Villa_FC_new_crest.svg/330px-Aston_Villa_FC_new_crest.svg.png',
          },
          {
            'name': 'Bournemouth',
            'code': 'BOU',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/e/e5/AFC_Bournemouth_%282013%29.svg/330px-AFC_Bournemouth_%282013%29.svg.png',
          },
          {
            'name': 'Brentford',
            'code': 'BRE',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/2/2a/Brentford_FC_crest.svg/330px-Brentford_FC_crest.svg.png',
          },
          {
            'name': 'Brighton',
            'code': 'BHA',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/d/d0/Brighton_and_Hove_Albion_FC_crest.svg/330px-Brighton_and_Hove_Albion_FC_crest.svg.png',
          },
          {
            'name': 'Chelsea',
            'code': 'CHE',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/c/cc/Chelsea_FC.svg/330px-Chelsea_FC.svg.png',
          },
          {
            'name': 'Crystal Palace',
            'code': 'CRY',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/a/a2/Crystal_Palace_FC_logo_%282022%29.svg/330px-Crystal_Palace_FC_logo_%282022%29.svg.png',
          },
          {
            'name': 'Everton',
            'code': 'EVE',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/7/7c/Everton_FC_logo.svg/330px-Everton_FC_logo.svg.png',
          },
          {
            'name': 'Fulham',
            'code': 'FUL',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/e/eb/Fulham_FC_%28shield%29.svg/330px-Fulham_FC_%28shield%29.svg.png',
          },
          {
            'name': 'Ipswich Town',
            'code': 'IPS',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/4/43/Ipswich_Town.svg/330px-Ipswich_Town.svg.png',
          },
          {
            'name': 'Leicester City',
            'code': 'LEI',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/2/2d/Leicester_City_crest.svg/330px-Leicester_City_crest.svg.png',
          },
          {
            'name': 'Liverpool',
            'code': 'LIV',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/0/0c/Liverpool_FC.svg/330px-Liverpool_FC.svg.png',
          },
          {
            'name': 'Man City',
            'code': 'MCI',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/e/eb/Manchester_City_FC_badge.svg/330px-Manchester_City_FC_badge.svg.png',
          },
          {
            'name': 'Man Utd',
            'code': 'MUN',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/7/7a/Manchester_United_FC_crest.svg/330px-Manchester_United_FC_crest.svg.png',
          },
          {
            'name': 'Newcastle',
            'code': 'NEW',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/5/56/Newcastle_United_Logo.svg/330px-Newcastle_United_Logo.svg.png',
          },
          {
            'name': 'Nottm Forest',
            'code': 'NFO',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/e/e5/Nottingham_Forest_F.C._logo.svg/330px-Nottingham_Forest_F.C._logo.svg.png',
          },
          {
            'name': 'Southampton',
            'code': 'SOU',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/c/c9/FC_Southampton.svg/330px-FC_Southampton.svg.png',
          },
          {
            'name': 'Tottenham',
            'code': 'TOT',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/b/b4/Tottenham_Hotspur.svg/330px-Tottenham_Hotspur.svg.png',
          },
          {
            'name': 'West Ham',
            'code': 'WHU',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/c/c2/West_Ham_United_FC_logo.svg/330px-West_Ham_United_FC_logo.svg.png',
          },
          {
            'name': 'Wolves',
            'code': 'WOL',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/c/c9/Wolverhampton_Wanderers_FC_crest.svg/330px-Wolverhampton_Wanderers_FC_crest.svg.png',
          },
          {
            'name': 'Sunderland',
            'code': 'SUN',
            'logo': 'https://crests.football-data.org/71.svg',
          },
          {
            'name': 'Leeds United',
            'code': 'LEE',
            'logo': 'https://crests.football-data.org/341.svg',
          },
          {
            'name': 'Burnley',
            'code': 'BUR',
            'logo': 'https://crests.football-data.org/328.svg',
          },
        ];
      case 'laliga':
        return [
          {
            'name': 'Alavés',
            'code': 'ALA',
            'logo': 'https://crests.football-data.org/263.svg',
          },
          {
            'name': 'Athletic Club',
            'code': 'ATH',
            'logo': 'https://crests.football-data.org/77.svg',
          },
          {
            'name': 'Atlético Madrid',
            'code': 'ATM',
            'logo': 'https://crests.football-data.org/78.svg',
          },
          {
            'name': 'Barcelona',
            'code': 'BAR',
            'logo': 'https://crests.football-data.org/81.svg',
          },
          {
            'name': 'Celta Vigo',
            'code': 'CEL',
            'logo': 'https://crests.football-data.org/558.svg',
          },
          {
            'name': 'Espanyol',
            'code': 'ESP',
            'logo': 'https://crests.football-data.org/88.svg',
          },
          {
            'name': 'Getafe',
            'code': 'GET',
            'logo': 'https://crests.football-data.org/82.svg',
          },
          {
            'name': 'Girona',
            'code': 'GIR',
            'logo': 'https://crests.football-data.org/298.svg',
          },
          {
            'name': 'Las Palmas',
            'code': 'LAS',
            'logo': 'https://crests.football-data.org/275.svg',
          },
          {
            'name': 'Leganés',
            'code': 'LEG',
            'logo': 'https://crests.football-data.org/745.svg',
          },
          {
            'name': 'Mallorca',
            'code': 'MAL',
            'logo': 'https://crests.football-data.org/89.svg',
          },
          {
            'name': 'Osasuna',
            'code': 'OSA',
            'logo': 'https://crests.football-data.org/79.svg',
          },
          {
            'name': 'Rayo Vallecano',
            'code': 'RAY',
            'logo': 'https://crests.football-data.org/87.svg',
          },
          {
            'name': 'Real Betis',
            'code': 'BET',
            'logo': 'https://crests.football-data.org/90.svg',
          },
          {
            'name': 'Real Madrid',
            'code': 'RMA',
            'logo': 'https://crests.football-data.org/86.svg',
          },
          {
            'name': 'Real Sociedad',
            'code': 'RSO',
            'logo': 'https://crests.football-data.org/92.svg',
          },
          {
            'name': 'Sevilla',
            'code': 'SEV',
            'logo': 'https://crests.football-data.org/559.svg',
          },
          {
            'name': 'Valencia',
            'code': 'VAL',
            'logo': 'https://crests.football-data.org/95.svg',
          },
          {
            'name': 'Valladolid',
            'code': 'VAD',
            'logo': 'https://crests.football-data.org/264.svg',
          },
          {
            'name': 'Villarreal',
            'code': 'VIL',
            'logo': 'https://crests.football-data.org/94.svg',
          },
        ];
      case 'bundesliga':
        return [
          {
            'name': 'Augsburg',
            'code': 'AUG',
            'logo': 'https://crests.football-data.org/16.svg',
          },
          {
            'name': 'Bayern Munich',
            'code': 'BAY',
            'logo': 'https://crests.football-data.org/5.svg',
          },
          {
            'name': 'Bochum',
            'code': 'BOC',
            'logo': 'https://crests.football-data.org/36.svg',
          },
          {
            'name': 'Dortmund',
            'code': 'DOR',
            'logo': 'https://crests.football-data.org/4.svg',
          },
          {
            'name': 'Eintracht Frankfurt',
            'code': 'SGE',
            'logo': 'https://crests.football-data.org/19.svg',
          },
          {
            'name': 'Freiburg',
            'code': 'SCF',
            'logo': 'https://crests.football-data.org/17.svg',
          },
          {
            'name': 'Heidenheim',
            'code': 'HDH',
            'logo': 'https://crests.football-data.org/44.svg',
          },
          {
            'name': 'Hoffenheim',
            'code': 'TSG',
            'logo': 'https://crests.football-data.org/2.svg',
          },
          {
            'name': 'Holstein Kiel',
            'code': 'KIE',
            'logo': 'https://crests.football-data.org/31.svg',
          },
          {
            'name': 'Leverkusen',
            'code': 'B04',
            'logo': 'https://crests.football-data.org/3.svg',
          },
          {
            'name': 'Mainz 05',
            'code': 'M05',
            'logo': 'https://crests.football-data.org/15.svg',
          },
          {
            'name': 'Mönchengladbach',
            'code': 'BMG',
            'logo': 'https://crests.football-data.org/18.svg',
          },
          {
            'name': 'RB Leipzig',
            'code': 'RBL',
            'logo': 'https://crests.football-data.org/721.svg',
          },
          {
            'name': 'St. Pauli',
            'code': 'STP',
            'logo': 'https://crests.football-data.org/20.svg',
          },
          {
            'name': 'Stuttgart',
            'code': 'VFB',
            'logo': 'https://crests.football-data.org/10.svg',
          },
          {
            'name': 'Union Berlin',
            'code': 'FCU',
            'logo': 'https://crests.football-data.org/28.svg',
          },
          {
            'name': 'Werder Bremen',
            'code': 'SVW',
            'logo': 'https://crests.football-data.org/12.svg',
          },
          {
            'name': 'Wolfsburg',
            'code': 'WOB',
            'logo': 'https://crests.football-data.org/11.svg',
          },
        ];
      case 'seriea':
        return [
          {
            'name': 'Atalanta',
            'code': 'ATA',
            'logo': 'https://crests.football-data.org/102.svg',
          },
          {
            'name': 'Bologna',
            'code': 'BOL',
            'logo': 'https://crests.football-data.org/103.svg',
          },
          {
            'name': 'Cagliari',
            'code': 'CAG',
            'logo': 'https://crests.football-data.org/104.svg',
          },
          {
            'name': 'Como',
            'code': 'COM',
            'logo': 'https://crests.football-data.org/105.svg',
          },
          {
            'name': 'Empoli',
            'code': 'EMP',
            'logo': 'https://crests.football-data.org/445.svg',
          },
          {
            'name': 'Fiorentina',
            'code': 'FIO',
            'logo': 'https://crests.football-data.org/99.svg',
          },
          {
            'name': 'Genoa',
            'code': 'GEN',
            'logo': 'https://crests.football-data.org/107.svg',
          },
          {
            'name': 'Inter Milan',
            'code': 'INT',
            'logo': 'https://crests.football-data.org/108.svg',
          },
          {
            'name': 'Juventus',
            'code': 'JUV',
            'logo': 'https://crests.football-data.org/109.svg',
          },
          {
            'name': 'Lazio',
            'code': 'LAZ',
            'logo': 'https://crests.football-data.org/110.svg',
          },
          {
            'name': 'Lecce',
            'code': 'LEC',
            'logo': 'https://crests.football-data.org/5890.svg',
          },
          {
            'name': 'AC Milan',
            'code': 'MIL',
            'logo': 'https://crests.football-data.org/98.svg',
          },
          {
            'name': 'Monza',
            'code': 'MON',
            'logo': 'https://crests.football-data.org/5911.svg',
          },
          {
            'name': 'Napoli',
            'code': 'NAP',
            'logo': 'https://crests.football-data.org/113.svg',
          },
          {
            'name': 'Parma',
            'code': 'PAR',
            'logo': 'https://crests.football-data.org/112.svg',
          },
          {
            'name': 'Roma',
            'code': 'ROM',
            'logo': 'https://crests.football-data.org/100.svg',
          },
          {
            'name': 'Torino',
            'code': 'TOR',
            'logo': 'https://crests.football-data.org/586.svg',
          },
          {
            'name': 'Udinese',
            'code': 'UDI',
            'logo': 'https://crests.football-data.org/115.svg',
          },
          {
            'name': 'Venezia',
            'code': 'VEN',
            'logo': 'https://crests.football-data.org/454.svg',
          },
          {
            'name': 'Verona',
            'code': 'VER',
            'logo': 'https://crests.football-data.org/450.svg',
          },
        ];
      case 'ligue1':
        return [
          {
            'name': 'Angers',
            'code': 'ANG',
            'logo': 'https://crests.football-data.org/532.svg',
          },
          {
            'name': 'Auxerre',
            'code': 'AJA',
            'logo': 'https://crests.football-data.org/519.svg',
          },
          {
            'name': 'Brest',
            'code': 'SB29',
            'logo': 'https://crests.football-data.org/512.svg',
          },
          {
            'name': 'Le Havre',
            'code': 'HAC',
            'logo': 'https://crests.football-data.org/531.svg',
          },
          {
            'name': 'Lens',
            'code': 'RCL',
            'logo': 'https://crests.football-data.org/546.svg',
          },
          {
            'name': 'Lille',
            'code': 'LOSC',
            'logo': 'https://crests.football-data.org/521.svg',
          },
          {
            'name': 'Lyon',
            'code': 'OL',
            'logo': 'https://crests.football-data.org/523.svg',
          },
          {
            'name': 'Marseille',
            'code': 'OM',
            'logo': 'https://crests.football-data.org/516.svg',
          },
          {
            'name': 'Monaco',
            'code': 'ASM',
            'logo': 'https://crests.football-data.org/548.svg',
          },
          {
            'name': 'Montpellier',
            'code': 'MHSC',
            'logo': 'https://crests.football-data.org/515.svg',
          },
          {
            'name': 'Nantes',
            'code': 'FCN',
            'logo': 'https://crests.football-data.org/543.svg',
          },
          {
            'name': 'Nice',
            'code': 'OGCN',
            'logo': 'https://crests.football-data.org/522.svg',
          },
          {
            'name': 'PSG',
            'code': 'PSG',
            'logo': 'https://crests.football-data.org/524.svg',
          },
          {
            'name': 'Reims',
            'code': 'SDR',
            'logo': 'https://crests.football-data.org/511.svg',
          },
          {
            'name': 'Rennes',
            'code': 'SRFC',
            'logo': 'https://crests.football-data.org/529.svg',
          },
          {
            'name': 'Saint-Étienne',
            'code': 'ASSE',
            'logo': 'https://crests.football-data.org/527.svg',
          },
          {
            'name': 'Strasbourg',
            'code': 'RCSA',
            'logo': 'https://crests.football-data.org/576.svg',
          },
          {
            'name': 'Toulouse',
            'code': 'TFC',
            'logo': 'https://crests.football-data.org/518.svg',
          },
        ];
      case 'ucl':
        return [
          // English
          {
            'name': 'Man City',
            'code': 'MCI',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/e/eb/Manchester_City_FC_badge.svg/200px-Manchester_City_FC_badge.svg.png',
          },
          {
            'name': 'Arsenal',
            'code': 'ARS',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/5/53/Arsenal_FC.svg/200px-Arsenal_FC.svg.png',
          },
          {
            'name': 'Liverpool',
            'code': 'LIV',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/0/0c/Liverpool_FC.svg/200px-Liverpool_FC.svg.png',
          },
          {
            'name': 'Aston Villa',
            'code': 'AVL',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/9/9a/Aston_Villa_FC_new_crest.svg/200px-Aston_Villa_FC_new_crest.svg.png',
          },
          // Spanish
          {
            'name': 'Real Madrid',
            'code': 'RMA',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/5/56/Real_Madrid_CF.svg/200px-Real_Madrid_CF.svg.png',
          },
          {
            'name': 'Barcelona',
            'code': 'BAR',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/4/47/FC_Barcelona_%28crest%29.svg/200px-FC_Barcelona_%28crest%29.svg.png',
          },
          {
            'name': 'Atlético Madrid',
            'code': 'ATM',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/f/f4/Atletico_Madrid_2017_logo.svg/200px-Atletico_Madrid_2017_logo.svg.png',
          },
          {
            'name': 'Girona',
            'code': 'GIR',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/9/90/Girona_FC_Logo.svg/200px-Girona_FC_Logo.svg.png',
          },
          // German
          {
            'name': 'Leverkusen',
            'code': 'B04',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/5/59/Bayer_04_Leverkusen_logo.svg/200px-Bayer_04_Leverkusen_logo.svg.png',
          },
          {
            'name': 'Bayern Munich',
            'code': 'BAY',
            'logo':
                'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1b/FC_Bayern_M%C3%BCnchen_logo_%282017%29.svg/200px-FC_Bayern_M%C3%BCnchen_logo_%282017%29.svg.png',
          },
          {
            'name': 'Dortmund',
            'code': 'DOR',
            'logo':
                'https://upload.wikimedia.org/wikipedia/commons/thumb/6/67/Borussia_Dortmund_logo.svg/200px-Borussia_Dortmund_logo.svg.png',
          },
          {
            'name': 'RB Leipzig',
            'code': 'RBL',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/0/04/RB_Leipzig_2014_logo.svg/200px-RB_Leipzig_2014_logo.svg.png',
          },
          {
            'name': 'Stuttgart',
            'code': 'VFB',
            'logo':
                'https://upload.wikimedia.org/wikipedia/commons/thumb/e/eb/VfB_Stuttgart_1893_Logo.svg/200px-VfB_Stuttgart_1893_Logo.svg.png',
          },
          // Italian
          {
            'name': 'Inter Milan',
            'code': 'INT',
            'logo':
                'https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/FC_Internazionale_Milano_2021.svg/200px-FC_Internazionale_Milano_2021.svg.png',
          },
          {
            'name': 'AC Milan',
            'code': 'MIL',
            'logo':
                'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d0/Logo_of_AC_Milan.svg/200px-Logo_of_AC_Milan.svg.png',
          },
          {
            'name': 'Juventus',
            'code': 'JUV',
            'logo':
                'https://upload.wikimedia.org/wikipedia/commons/thumb/b/bc/Juventus_FC_2017_icon_%28black%29.svg/200px-Juventus_FC_2017_icon_%28black%29.svg.png',
          },
          {
            'name': 'Atalanta',
            'code': 'ATA',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/6/66/AtalantaBC.svg/200px-AtalantaBC.svg.png',
          },
          {
            'name': 'Bologna',
            'code': 'BOL',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/5/5b/Bologna_F.C._1909_logo.svg/200px-Bologna_F.C._1909_logo.svg.png',
          },
          // French
          {
            'name': 'PSG',
            'code': 'PSG',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/a/a7/Paris_Saint-Germain_F.C..svg/200px-Paris_Saint-Germain_F.C..svg.png',
          },
          {
            'name': 'Monaco',
            'code': 'ASM',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/4/43/AS_Monaco_FC.svg/200px-AS_Monaco_FC.svg.png',
          },
          {
            'name': 'Brest',
            'code': 'SB29',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/0/05/Stade_Brestois_29_logo.svg/200px-Stade_Brestois_29_logo.svg.png',
          },
          {
            'name': 'Lille',
            'code': 'LOSC',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/6/6f/LOSC_Lille_Logo.svg/200px-LOSC_Lille_Logo.svg.png',
          },
          // Portuguese
          {
            'name': 'Sporting CP',
            'code': 'SCP',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/3/3e/Sporting_Clube_de_Portugal.svg/200px-Sporting_Clube_de_Portugal.svg.png',
          },
          {
            'name': 'Benfica',
            'code': 'SLB',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/a/a2/SL_Benfica_logo.svg/200px-SL_Benfica_logo.svg.png',
          },
          // Dutch
          {
            'name': 'PSV',
            'code': 'PSV',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/0/05/PSV_Eindhoven.svg/200px-PSV_Eindhoven.svg.png',
          },
          {
            'name': 'Feyenoord',
            'code': 'FEY',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/e/e3/Feyenoord_logo.svg/200px-Feyenoord_logo.svg.png',
          },
          // Others
          {
            'name': 'Club Brugge',
            'code': 'CLU',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/d/d0/Club_Brugge_KV_logo.svg/200px-Club_Brugge_KV_logo.svg.png',
          },
          {
            'name': 'Celtic',
            'code': 'CEL',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/3/35/Celtic_FC.svg/200px-Celtic_FC.svg.png',
          },
          {
            'name': 'Sturm Graz',
            'code': 'STU',
            'logo':
                'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4a/SK_Sturm_Graz.svg/200px-SK_Sturm_Graz.svg.png',
          },
          {
            'name': 'Salzburg',
            'code': 'RBS',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/3/30/FC_Red_Bull_Salzburg_logo.svg/200px-FC_Red_Bull_Salzburg_logo.svg.png',
          },
          {
            'name': 'Young Boys',
            'code': 'YBO',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/6/6b/BSC_Young_Boys_logo.svg/200px-BSC_Young_Boys_logo.svg.png',
          },
          {
            'name': 'Sparta Prague',
            'code': 'SPA',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/3/39/AC_Sparta_Praha_logo.svg/200px-AC_Sparta_Praha_logo.svg.png',
          },
          {
            'name': 'Slovan Bratislava',
            'code': 'SLO',
            'logo':
                'https://upload.wikimedia.org/wikipedia/commons/thumb/9/90/SK_Slovan_Bratislava_logo.svg/200px-SK_Slovan_Bratislava_logo.svg.png',
          },
          {
            'name': 'Shakhtar',
            'code': 'SHA',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/a/a1/FC_Shakhtar_Donetsk.svg/200px-FC_Shakhtar_Donetsk.svg.png',
          },
          {
            'name': 'Dinamo Zagreb',
            'code': 'DIN',
            'logo':
                'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2b/Logo_GNK_Dinamo_Zagreb_%282019%29.svg/200px-Logo_GNK_Dinamo_Zagreb_%282019%29.svg.png',
          },
          {
            'name': 'Red Star Belgrade',
            'code': 'RSB',
            'logo':
                'https://upload.wikimedia.org/wikipedia/commons/thumb/2/28/Red_Star_Belgrade_crest.svg/200px-Red_Star_Belgrade_crest.svg.png',
          },
          // Missing Teams Added Below
          {
            'name': 'Union SG',
            'code': 'USG',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/c/c6/Royale_Union_Saint-Gilloise_Logo.svg/200px-Royale_Union_Saint-Gilloise_Logo.svg.png',
          },
          {
            'name': 'Athletic Club',
            'code': 'ATH',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/9/98/Club_Athletic_Bilbao_logo.svg/200px-Club_Athletic_Bilbao_logo.svg.png',
          },
          {
            'name': 'Marseille',
            'code': 'OM',
            'logo':
                'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d8/Olympique_Marseille_logo.svg/200px-Olympique_Marseille_logo.svg.png',
          },
          {
            'name': 'Qarabag',
            'code': 'QAR',
            'logo':
                'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8c/Logo_Qaraba%C4%9F_FK_2024.svg/200px-Logo_Qaraba%C4%9F_FK_2024.svg.png',
          },
          {
            'name': 'Tottenham',
            'code': 'TOT',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/b/b4/Tottenham_Hotspur.svg/200px-Tottenham_Hotspur.svg.png',
          },
          {
            'name': 'Villarreal',
            'code': 'VIL',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/7/70/Villarreal_CF_logo.svg/200px-Villarreal_CF_logo.svg.png',
          },
          {
            'name': 'Olympiacos',
            'code': 'OLY',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/f/f1/Olympiacos_FC_logo.svg/200px-Olympiacos_FC_logo.svg.png',
          },
          {
            'name': 'Pafos',
            'code': 'PAF',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/0/07/Pafos_FC_logo_2018.svg/200px-Pafos_FC_logo_2018.svg.png',
          },
          {
            'name': 'Slavia Praha',
            'code': 'SLP',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/e/ee/SK_Slavia_Praha_logo.svg/200px-SK_Slavia_Praha_logo.svg.png',
          },
          {
            'name': 'Bodø/Glimt',
            'code': 'BOD',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/f/f3/FK_Bodo_Glimt_logo.svg/200px-FK_Bodo_Glimt_logo.svg.png',
          },
          {
            'name': 'Ajax',
            'code': 'AJX',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/7/79/Ajax_Amsterdam.svg/200px-Ajax_Amsterdam.svg.png',
          },
          {
            'name': 'Copenhagen',
            'code': 'FCK',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/9/93/FC_K%C3%B8benhavn.svg/200px-FC_K%C3%B8benhavn.svg.png',
          },
          {
            'name': 'Napoli',
            'code': 'NAP',
            'logo':
                'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2d/SSC_Neapel.svg/200px-SSC_Neapel.svg.png',
          },
          {
            'name': 'Frankfurt',
            'code': 'SGE',
            'logo':
                'https://upload.wikimedia.org/wikipedia/commons/thumb/0/04/Eintracht_Frankfurt_Logo.svg/200px-Eintracht_Frankfurt_Logo.svg.png',
          },
          {
            'name': 'Galatasaray',
            'code': 'GAL',
            'logo':
                'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f6/Galatasaray_Sports_Club_Logo.svg/200px-Galatasaray_Sports_Club_Logo.svg.png',
          },
          {
            'name': 'Kairat Almaty',
            'code': 'KRT',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/f/f6/FC_Kairat_Almaty_Logo.svg/200px-FC_Kairat_Almaty_Logo.svg.png',
          },
          {
            'name': 'Newcastle',
            'code': 'NEW',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/5/56/Newcastle_United_Logo.svg/200px-Newcastle_United_Logo.svg.png',
          },
          {
            'name': 'Chelsea',
            'code': 'CHE',
            'logo':
                'https://upload.wikimedia.org/wikipedia/en/thumb/c/cc/Chelsea_FC.svg/200px-Chelsea_FC.svg.png',
          },
        ];
      default:
        return [];
    }
  }

  // --- Cricket Teams Data ---
  static List<Map<String, String>> getCricketTeams(String leagueId) {
    switch (leagueId) {
      case 'ipl':
        return [
          {
            'name': 'Chennai Super Kings',
            'code': 'CSK',
            'logo':
                'https://documents.iplt20.com/ipl/CSK/logos/Logooutline/CSKoutline.png',
          },
          {
            'name': 'Delhi Capitals',
            'code': 'DC',
            'logo':
                'https://documents.iplt20.com/ipl/DC/Logos/LogoOutline/DCoutline.png',
          },
          {
            'name': 'Gujarat Titans',
            'code': 'GT',
            'logo':
                'https://documents.iplt20.com/ipl/GT/Logos/Logooutline/GToutline.png',
          },
          {
            'name': 'Kolkata Knight Riders',
            'code': 'KKR',
            'logo':
                'https://documents.iplt20.com/ipl/KKR/Logos/Logooutline/KKRoutline.png',
          },
          {
            'name': 'Lucknow Super Giants',
            'code': 'LSG',
            'logo':
                'https://documents.iplt20.com/ipl/LSG/Logos/Logooutline/LSGoutline.png',
          },
          {
            'name': 'Mumbai Indians',
            'code': 'MI',
            'logo':
                'https://documents.iplt20.com/ipl/MI/Logos/Logooutline/MIoutline.png',
          },
          {
            'name': 'Punjab Kings',
            'code': 'PBKS',
            'logo':
                'https://documents.iplt20.com/ipl/PBKS/Logos/Logooutline/PBKSoutline.png',
          },
          {
            'name': 'Rajasthan Royals',
            'code': 'RR',
            'logo':
                'https://documents.iplt20.com/ipl/RR/Logos/Logooutline/RRoutline.png',
          },
          {
            'name': 'Royal Challengers Bengaluru',
            'code': 'RCB',
            'logo':
                'https://documents.iplt20.com/ipl/RCB/Logos/Logooutline/RCBoutline.png',
          },
          {
            'name': 'Sunrisers Hyderabad',
            'code': 'SRH',
            'logo':
                'https://documents.iplt20.com/ipl/SRH/Logos/Logooutline/SRHoutline.png',
          },
        ];
      case 'asiacup':
        return [
          {
            'name': 'India',
            'code': 'IND',
            'logo': 'https://flagcdn.com/w320/in.png',
          },
          {
            'name': 'Pakistan',
            'code': 'PAK',
            'logo': 'https://flagcdn.com/w320/pk.png',
          },
          {
            'name': 'Sri Lanka',
            'code': 'SRI',
            'logo': 'https://flagcdn.com/w320/lk.png',
          },
          {
            'name': 'Bangladesh',
            'code': 'BAN',
            'logo': 'https://flagcdn.com/w320/bd.png',
          },
          {
            'name': 'Afghanistan',
            'code': 'AFG',
            'logo': 'https://flagcdn.com/w320/af.png',
          },
          {
            'name': 'Nepal',
            'code': 'NEP',
            'logo': 'https://flagcdn.com/w320/np.png',
          },
        ];
      case 'isl':
        return [
          {
            'name': 'Mohun Bagan SG',
            'code': 'MBSG',
            'logo': 'https://crests.football-data.org/758.svg',
          },
          {
            'name': 'East Bengal FC',
            'code': 'EBFC',
            'logo': 'https://crests.football-data.org/758.svg',
          },
          {
            'name': 'Mumbai City FC',
            'code': 'MCFC',
            'logo': 'https://crests.football-data.org/758.svg',
          },
          {
            'name': 'FC Goa',
            'code': 'FCG',
            'logo': 'https://crests.football-data.org/758.svg',
          },
          {
            'name': 'Kerala Blasters FC',
            'code': 'KBFC',
            'logo': 'https://crests.football-data.org/758.svg',
          },
          {
            'name': 'Bengaluru FC',
            'code': 'BFC',
            'logo': 'https://crests.football-data.org/758.svg',
          },
          {
            'name': 'Odisha FC',
            'code': 'OFC',
            'logo': 'https://crests.football-data.org/758.svg',
          },
          {
            'name': 'Chennaiyin FC',
            'code': 'CFC',
            'logo': 'https://crests.football-data.org/758.svg',
          },
          {
            'name': 'Jamshedpur FC',
            'code': 'JFC',
            'logo': 'https://crests.football-data.org/758.svg',
          },
          {
            'name': 'NorthEast United FC',
            'code': 'NEUFC',
            'logo': 'https://crests.football-data.org/758.svg',
          },
          {
            'name': 'Hyderabad FC',
            'code': 'HFC',
            'logo': 'https://crests.football-data.org/758.svg',
          },
          {
            'name': 'Punjab FC',
            'code': 'PFC',
            'logo': 'https://crests.football-data.org/758.svg',
          },
          {
            'name': 'Mohammedan SC',
            'code': 'MSC',
            'logo': 'https://crests.football-data.org/758.svg',
          },
        ];
      default:
        return [];
    }
  }

  static String getFlagUrl(String countryCode) {
    return 'https://flagcdn.com/w320/$countryCode.png';
  }

  // --- Team Name Mapping ---
  static final Map<String, Map<String, String>> _teamNameMappings = {
    'pl': {
      'Ipswich': 'Ipswich Town',
      'Ipswich Town FC': 'Ipswich Town',
      'Leicester': 'Leicester City',
      'Leicester City FC': 'Leicester City',
      "Nott'm Forest": 'Nottm Forest',
      'Nottingham Forest': 'Nottm Forest',
      'Nottingham Forest FC': 'Nottm Forest',
      'Spurs': 'Tottenham',
      'Tottenham Hotspur': 'Tottenham',
      'Tottenham Hotspur FC': 'Tottenham',
      'Man City': 'Man City',
      'Manchester City': 'Man City',
      'Manchester City FC': 'Man City',
      'Man Utd': 'Man Utd',
      'Manchester United': 'Man Utd',
      'Manchester United FC': 'Man Utd',
      'Arsenal FC': 'Arsenal',
      'Aston Villa FC': 'Aston Villa',
      'AFC Bournemouth': 'Bournemouth',
      'Bournemouth': 'Bournemouth', // Added simple Bournemouth
      'Brentford FC': 'Brentford',
      'Brighton & Hove Albion': 'Brighton',
      'Brighton & Hove Albion FC': 'Brighton',
      'Chelsea FC': 'Chelsea',
      'Crystal Palace FC': 'Crystal Palace',
      'Everton FC': 'Everton',
      'Fulham FC': 'Fulham',
      'Liverpool FC': 'Liverpool',
      'Newcastle United': 'Newcastle',
      'Newcastle United FC': 'Newcastle',
      'Southampton FC': 'Southampton',
      'West Ham United': 'West Ham',
      'West Ham United FC': 'West Ham',
      'Wolverhampton Wanderers': 'Wolves',
      'Wolverhampton Wanderers FC': 'Wolves',
      'Sunderland AFC': 'Sunderland',
      'Sunderland': 'Sunderland',
      'Leeds': 'Leeds United',
      'Leeds United FC': 'Leeds United',
      'Burnley': 'Burnley',
      'Burnley FC': 'Burnley',
    },
    'laliga': {
      'Atlético de Madrid': 'Atlético Madrid',
      'CA Osasuna': 'Osasuna',
      'CD Leganés': 'Leganés',
      'Deportivo Alavés': 'Alavés',
      'FC Barcelona': 'Barcelona',
      'Getafe CF': 'Getafe',
      'Girona FC': 'Girona',
      'RC Celta': 'Celta Vigo',
      'RCD Espanyol de Barcelona': 'Espanyol',
      'RCD Mallorca': 'Mallorca',
      'Real Valladolid CF': 'Valladolid',
      'Sevilla FC': 'Sevilla',
      'UD Las Palmas': 'Las Palmas',
      'Valencia CF': 'Valencia',
      'Villarreal CF': 'Villarreal',
      'Real Betis Balompié': 'Real Betis',
      'Rayo Vallecano de Madrid': 'Rayo Vallecano',
      'Real Sociedad de Fútbol': 'Real Sociedad',
    },
    'bundesliga': {
      '1. FC Heidenheim 1846': 'Heidenheim',
      '1. FC Union Berlin': 'Union Berlin',
      '1. FSV Mainz 05': 'Mainz 05',
      'Bayer 04 Leverkusen': 'Leverkusen',
      'Borussia Dortmund': 'Dortmund',
      'Borussia Mönchengladbach': 'Mönchengladbach',
      'FC Augsburg': 'Augsburg',
      'FC Bayern München': 'Bayern Munich',
      'FC St. Pauli': 'St. Pauli',
      'SC Freiburg': 'Freiburg',
      'SV Werder Bremen': 'Werder Bremen',
      'TSG Hoffenheim': 'Hoffenheim',
      'VfB Stuttgart': 'Stuttgart',
      'VfL Bochum 1848': 'Bochum',
      'VfL Wolfsburg': 'Wolfsburg',
    },
    'ucl': {
      'B. Dortmund': 'Dortmund',
      'Paris': 'PSG',
      'Bayern München': 'Bayern Munich',
      'Atleti': 'Atlético Madrid',
      'Inter': 'Inter Milan',
      'Stuttgart': 'Stuttgart', // Explicitly keep as Stuttgart
      'PSV': 'PSV',
      'Sporting CP': 'Sporting CP',
    },
    'seriea': {
      'Hellas Verona': 'Verona',
      'Inter': 'Inter Milan',
      'Milan': 'AC Milan',
    },
    'ligue1': {
      'AJ Auxerre': 'Auxerre',
      'AS Monaco': 'Monaco',
      'AS Saint-Étienne': 'Saint-Étienne',
      'Angers SCO': 'Angers',
      'FC Nantes': 'Nantes',
      'Havre Athletic Club': 'Le Havre',
      'LOSC Lille': 'Lille',
      'Montpellier Hérault SC': 'Montpellier',
      'OGC Nice': 'Nice',
      'Olympique Lyonnais': 'Lyon',
      'Olympique de Marseille': 'Marseille',
      'Paris Saint-Germain': 'PSG',
      'RC Lens': 'Lens',
      'RC Strasbourg Alsace': 'Strasbourg',
      'Stade Brestois 29': 'Brest',
      'Stade DE Reims': 'Reims',
      'Stade Rennais FC': 'Rennes',
      'Toulouse FC': 'Toulouse',
    },
    'wc2026': {
      'Korea Republic': 'South Korea',
      'USA': 'United States',
      'IR Iran': 'Iran',
      'Côte d\'Ivoire': 'Ivory Coast',
      'Czech Republic': 'Czech Republic', // Already matches but just in case
      'Korea DPR': 'North Korea',
    },
  };

  static String resolveTeamName(String leagueId, String feedTeamName) {
    if (_teamNameMappings.containsKey(leagueId)) {
      final leagueMappings = _teamNameMappings[leagueId]!;
      if (leagueMappings.containsKey(feedTeamName)) {
        return leagueMappings[feedTeamName]!;
      }
    }
    return feedTeamName;
  }

  static String? getTeamAsset(String name, {String? leagueId}) {
    // 1. Check National Teams (Flags)
    final nationalTeams = getNationalTeams();
    for (var t in nationalTeams) {
      if (t['name'] == name) {
        final flag = t['flag']!;
        // Standard flagcdn URL
        return 'https://flagcdn.com/w160/$flag.png';
      }
    }

    // 2. Check Club Teams (Logos)
    // If leagueId is provided, check that specifically first
    if (leagueId != null) {
      final clubTeams = getClubTeams(leagueId);
      for (var t in clubTeams) {
        if (t['name'] == name) return t['logo'];
      }
    }

    // 3. Global Club Search (fallback)
    final leagues = ['pl', 'laliga', 'bundesliga', 'seriea', 'ligue1', 'ucl'];
    for (var l in leagues) {
      if (l == leagueId) continue; // Already checked
      final clubTeams = getClubTeams(l);
      for (var t in clubTeams) {
        if (t['name'] == name) return t['logo'];
      }
    }

    return null;
  }
}
