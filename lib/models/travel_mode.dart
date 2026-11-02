/// Travel modes supported by `GET /directions`.
enum TravelMode {
  driving('driving', 'Drive'),
  walking('walking', 'Walk'),
  transit('transit', 'Transit'),
  bicycling('bicycling', 'Cycle');

  const TravelMode(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static TravelMode fromApi(Object? value) {
    return TravelMode.values.firstWhere(
      (mode) => mode.apiValue == value,
      orElse: () => TravelMode.driving,
    );
  }
}
