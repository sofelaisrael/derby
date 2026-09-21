/// Information about a Derbyshire council.
enum DerbyCouncil {
  derbyCity('Derby City Council', 'derby'),
  erewash('Erewash Borough Council', 'erewash'),
  amberValley('Amber Valley Borough Council', 'amber_valley'),
  highPeak('High Peak Borough Council', 'high_peak'),
  derbyshireDales('Derbyshire Dales District Council', 'derbyshire_dales'),
  bolsover('Bolsover District Council', 'bolsover'),
  chesterfield('Chesterfield Borough Council', 'chesterfield'),
  southDerbyshire('South Derbyshire District Council', 'south_derbyshire');

  final String displayName;
  final String id;

  const DerbyCouncil(this.displayName, this.id);

  /// Get council from ID string.
  static DerbyCouncil fromId(String id) {
    return DerbyCouncil.values.firstWhere(
      (c) => c.id == id,
      orElse: () => DerbyCouncil.derbyCity,
    );
  }
}
