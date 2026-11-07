import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../art/art_pack.dart';

final artPackProvider = Provider<ArtPack>((ref) => ArtPack.placeholder());
