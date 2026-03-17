/// Periodic Table element data for Falcon Eye
class ChemElement {
  final int number;
  final String symbol;
  final String name;
  final double atomicWeight;
  final String category; // metal, nonmetal, metalloid, noble_gas, etc.
  final bool detectable; // can be detected via radio backscatter
  final double density; // g/cm3

  const ChemElement({
    required this.number,
    required this.symbol,
    required this.name,
    required this.atomicWeight,
    required this.category,
    this.detectable = false,
    this.density = 0,
  });
}

const kDetectableElements = <ChemElement>[
  ChemElement(number: 26, symbol: 'Fe', name: 'Iron', atomicWeight: 55.845, category: 'transition_metal', detectable: true, density: 7.874),
  ChemElement(number: 29, symbol: 'Cu', name: 'Copper', atomicWeight: 63.546, category: 'transition_metal', detectable: true, density: 8.96),
  ChemElement(number: 79, symbol: 'Au', name: 'Gold', atomicWeight: 196.967, category: 'transition_metal', detectable: true, density: 19.3),
  ChemElement(number: 47, symbol: 'Ag', name: 'Silver', atomicWeight: 107.868, category: 'transition_metal', detectable: true, density: 10.49),
  ChemElement(number: 13, symbol: 'Al', name: 'Aluminum', atomicWeight: 26.982, category: 'post_transition_metal', detectable: true, density: 2.7),
  ChemElement(number: 82, symbol: 'Pb', name: 'Lead', atomicWeight: 207.2, category: 'post_transition_metal', detectable: true, density: 11.34),
  ChemElement(number: 50, symbol: 'Sn', name: 'Tin', atomicWeight: 118.71, category: 'post_transition_metal', detectable: true, density: 7.265),
  ChemElement(number: 30, symbol: 'Zn', name: 'Zinc', atomicWeight: 65.38, category: 'transition_metal', detectable: true, density: 7.134),
  ChemElement(number: 28, symbol: 'Ni', name: 'Nickel', atomicWeight: 58.693, category: 'transition_metal', detectable: true, density: 8.908),
  ChemElement(number: 24, symbol: 'Cr', name: 'Chromium', atomicWeight: 51.996, category: 'transition_metal', detectable: true, density: 7.15),
  ChemElement(number: 74, symbol: 'W', name: 'Tungsten', atomicWeight: 183.84, category: 'transition_metal', detectable: true, density: 19.25),
  ChemElement(number: 78, symbol: 'Pt', name: 'Platinum', atomicWeight: 195.084, category: 'transition_metal', detectable: true, density: 21.45),
  ChemElement(number: 22, symbol: 'Ti', name: 'Titanium', atomicWeight: 47.867, category: 'transition_metal', detectable: true, density: 4.506),
  ChemElement(number: 92, symbol: 'U', name: 'Uranium', atomicWeight: 238.029, category: 'actinide', detectable: true, density: 19.1),
  ChemElement(number: 27, symbol: 'Co', name: 'Cobalt', atomicWeight: 58.933, category: 'transition_metal', detectable: true, density: 8.9),
];
