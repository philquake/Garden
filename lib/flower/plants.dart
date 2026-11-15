import 'dart:ui' show Color;

enum PlantGroup {
  flowering('Flowering'),
  leafy('Leafy'),
  succulent('Succulents'),
  tall('Tall');

  const PlantGroup(this.label);
  final String label;
}

/// One plant a habit can grow. Its five growth stages are the images
/// `assets/plants/<id>_0.png` (seed) to `<id>_4.png` (full grown).
class Plant {
  const Plant(this.id, this.name, this.group, this.light, this.dark);

  final String id;
  final String name;
  final PlantGroup group;

  /// Chart accent in the light and dark themes.
  final Color light;
  final Color dark;
}

/// Picker order. The first is the default for a new habit.
const plants = [
  Plant(
    'tulip',
    'Tulip',
    PlantGroup.flowering,
    Color(0xFFD9577A),
    Color(0xFFF08FA8),
  ),
  Plant(
    'sunflower',
    'Sunflower',
    PlantGroup.flowering,
    Color(0xFFD99A0B),
    Color(0xFFF2C14E),
  ),
  Plant(
    'lavender',
    'Lavender',
    PlantGroup.flowering,
    Color(0xFF7B63C2),
    Color(0xFFB9A7E8),
  ),
  Plant(
    'daisy',
    'Daisy',
    PlantGroup.flowering,
    Color(0xFF2E9E6C),
    Color(0xFF5CCB98),
  ),
  Plant(
    'rose',
    'Rose',
    PlantGroup.flowering,
    Color(0xFFC62828),
    Color(0xFFFF7A6B),
  ),
  Plant(
    'poppy',
    'Poppy',
    PlantGroup.flowering,
    Color(0xFFD84315),
    Color(0xFFFF8A65),
  ),
  Plant(
    'foxglove',
    'Foxglove',
    PlantGroup.flowering,
    Color(0xFFAD1457),
    Color(0xFFF48FB1),
  ),
  Plant(
    'hydrangea',
    'Hydrangea',
    PlantGroup.flowering,
    Color(0xFF4F7FE0),
    Color(0xFF9CC2FF),
  ),
  Plant(
    'pothos',
    'Pothos',
    PlantGroup.leafy,
    Color(0xFF4CAF50),
    Color(0xFF81C784),
  ),
  Plant(
    'peace_lily',
    'Peace lily',
    PlantGroup.leafy,
    Color(0xFF2E8B57),
    Color(0xFF66D9A0),
  ),
  Plant(
    'snake_plant',
    'Snake plant',
    PlantGroup.leafy,
    Color(0xFF8D9A1B),
    Color(0xFFC5D86D),
  ),
  Plant(
    'spider_plant',
    'Spider plant',
    PlantGroup.leafy,
    Color(0xFF6AA84F),
    Color(0xFFA9D98F),
  ),
  Plant(
    'boston_fern',
    'Boston fern',
    PlantGroup.leafy,
    Color(0xFF3E7D32),
    Color(0xFF7CC47F),
  ),
  Plant(
    'prayer_plant',
    'Prayer plant',
    PlantGroup.leafy,
    Color(0xFFC0506A),
    Color(0xFFE88DA0),
  ),
  Plant(
    'chinese_money_plant',
    'Chinese money plant',
    PlantGroup.leafy,
    Color(0xFF7CB342),
    Color(0xFFB5E06B),
  ),
  Plant(
    'anthurium',
    'Anthurium',
    PlantGroup.leafy,
    Color(0xFFE53935),
    Color(0xFFFF8A80),
  ),
  Plant(
    'aloe_vera',
    'Aloe vera',
    PlantGroup.succulent,
    Color(0xFF3FA796),
    Color(0xFF7FD6C4),
  ),
  Plant(
    'echeveria',
    'Echeveria',
    PlantGroup.succulent,
    Color(0xFF8E6C9C),
    Color(0xFFC9A9D9),
  ),
  Plant(
    'jade_plant',
    'Jade plant',
    PlantGroup.succulent,
    Color(0xFF3F9F5F),
    Color(0xFF7FD698),
  ),
  Plant(
    'barrel_cactus',
    'Barrel cactus',
    PlantGroup.succulent,
    Color(0xFF4F9F5A),
    Color(0xFF8FD88F),
  ),
  Plant(
    'saguaro_cactus',
    'Saguaro',
    PlantGroup.succulent,
    Color(0xFF2E7D32),
    Color(0xFF66BB6A),
  ),
  Plant(
    'prickly_pear',
    'Prickly pear',
    PlantGroup.succulent,
    Color(0xFFB7413B),
    Color(0xFFFF8A80),
  ),
  Plant(
    'haworthia',
    'Haworthia',
    PlantGroup.succulent,
    Color(0xFF2E7D6B),
    Color(0xFF6CC4AE),
  ),
  Plant(
    'fiddle_leaf_fig',
    'Fiddle leaf fig',
    PlantGroup.tall,
    Color(0xFF7A9A2A),
    Color(0xFFB5D45A),
  ),
  Plant(
    'rubber_plant',
    'Rubber plant',
    PlantGroup.tall,
    Color(0xFF1F6A3A),
    Color(0xFF5FBF7A),
  ),
  Plant(
    'elephant_ear',
    'Elephant ear',
    PlantGroup.tall,
    Color(0xFF1F8A5B),
    Color(0xFF5FD3A0),
  ),
  Plant(
    'bird_of_paradise',
    'Bird of paradise',
    PlantGroup.tall,
    Color(0xFFEF6C00),
    Color(0xFFFFA040),
  ),
  Plant(
    'agave',
    'Agave',
    PlantGroup.tall,
    Color(0xFF4F8A8B),
    Color(0xFF8FC5C5),
  ),
  Plant(
    'pampas_grass',
    'Pampas grass',
    PlantGroup.tall,
    Color(0xFFB89B3A),
    Color(0xFFE3C96A),
  ),
  Plant(
    'papyrus',
    'Papyrus',
    PlantGroup.tall,
    Color(0xFF5FA02A),
    Color(0xFF9AD65A),
  ),
];

final _byId = {for (final p in plants) p.id: p};

/// The plant with this id, or null for an id this version does not know.
Plant? plantOf(String id) => _byId[id];
