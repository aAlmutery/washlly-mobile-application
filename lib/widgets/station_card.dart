import 'package:flutter/material.dart';
import '../models/station.dart';

class StationCard extends StatelessWidget {
  final Station station;
  final VoidCallback onTap;

  const StationCard({super.key, required this.station, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(station.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(station.address, style: const TextStyle(fontSize: 14)),
              if (station.detailedAddress != null) ...[
                const SizedBox(height: 6),
                Text(station.detailedAddress!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
