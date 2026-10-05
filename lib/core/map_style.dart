/// Stile delle mappe dell'app (redesign): fondo crema, verde tenue per i
/// parchi, acqua verde-azzurra, strade bianche con bordo sabbia.
///
/// Nasconde i punti di interesse e i trasporti di Google: sulla mappa
/// devono spiccare solo i nostri marker, non le icone di negozi o monumenti.
const mapStyleJson = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#F2EDE1"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#7A7466"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#FAF7F0"}, {"weight": 3}]},
  {"featureType": "landscape.man_made", "elementType": "geometry", "stylers": [{"color": "#EEE8DA"}]},
  {"featureType": "landscape.man_made", "elementType": "geometry.stroke", "stylers": [{"color": "#E8E1D2"}]},
  {"featureType": "landscape.natural", "elementType": "geometry", "stylers": [{"color": "#E9EEDC"}]},
  {"featureType": "poi", "elementType": "labels", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi", "elementType": "geometry", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"visibility": "on"}, {"color": "#DCEDD6"}]},
  {"featureType": "road", "elementType": "geometry.fill", "stylers": [{"color": "#FFFFFF"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#E2D9C6"}]},
  {"featureType": "road", "elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"featureType": "road.highway", "elementType": "geometry.fill", "stylers": [{"color": "#FFFFFF"}]},
  {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#D3C7AE"}]},
  {"featureType": "road.local", "elementType": "labels", "stylers": [{"visibility": "simplified"}]},
  {"featureType": "transit", "stylers": [{"visibility": "off"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#C4E4DF"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#4E8C84"}]},
  {"featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{"color": "#5E584B"}]}
]
''';
