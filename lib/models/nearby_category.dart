/// Quick discovery categories shown above the Explore map.
///
/// `apiValue` is what the Laravel proxy receives on `GET /places/nearby`.
/// `demoCategories` maps the category onto the sample data set.
enum NearbyCategory {
  restaurant(
    'restaurant',
    'Restaurants',
    {'restaurant'},
  ),
  cafe(
    'cafe',
    'Cafes',
    {'cafe'},
  ),
  hotel(
    'hotel',
    'Hotels',
    {'hotel'},
  ),
  attraction(
    'attraction',
    'Attractions',
    {'landmark', 'temple', 'museum', 'stadium'},
  ),
  park(
    'park',
    'Parks',
    {'park'},
  ),
  market(
    'market',
    'Markets',
    {'market', 'mall'},
  );

  const NearbyCategory(this.apiValue, this.label, this.demoCategories);

  final String apiValue;
  final String label;
  final Set<String> demoCategories;

  static NearbyCategory? fromApi(Object? value) {
    for (final category in NearbyCategory.values) {
      if (category.apiValue == value) return category;
    }
    return null;
  }
}
