/// Nasconde i punti di interesse e i trasporti di Google sulle mappe
/// dell'app: devono mostrare solo i nostri marker brandizzati, non le
/// icone POI di terzi (monumenti, negozi, ecc.) che rompono l'aspetto
/// "custom" del design.
const mapStyleJson = '''
[
  {"featureType": "poi", "elementType": "labels", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi", "elementType": "geometry", "stylers": [{"visibility": "off"}]},
  {"featureType": "transit", "elementType": "labels.icon", "stylers": [{"visibility": "off"}]}
]
''';
