import 'package:material_ui/material_ui.dart';

import '../../core/archive_format.dart';
import '../../core/theme.dart';

/// Square file-type badge (`ZIP`, `RAR`, `7Z`, ...).
class FormatBadge extends StatelessWidget {
  const FormatBadge(this.format, {super.key, this.size = 44});

  final ArchiveFormat format;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = ZipFastColors.forFormat(format);
    final label = format.label.split('.').last; // TAR.GZ -> GZ
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.3,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
