import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons/lucide_icons.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Análisis de Movimiento'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tiempo en Zonas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildPieChart(),
            const SizedBox(height: 40),
            const Text('Actividad Semanal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildBarChart(),
            const SizedBox(height: 40),
            _buildSummaryCards(),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: [
            PieChartSectionData(value: 70, color: Colors.green, title: 'Seguro', radius: 60),
            PieChartSectionData(value: 20, color: Colors.orange, title: 'Fuera', radius: 50),
            PieChartSectionData(value: 10, color: Colors.red, title: 'Riesgo', radius: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          barGroups: [
            BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 8, color: Colors.indigo)]),
            BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 12, color: Colors.indigo)]),
            BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 5, color: Colors.indigo)]),
            BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: 15, color: Colors.indigo)]),
            BarChartGroupData(x: 5, barRods: [BarChartRodData(toY: 10, color: Colors.indigo)]),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      children: [
        _statCard("Distancia", "45 km", LucideIcons.map),
        _statCard("Alertas", "3", LucideIcons.alertTriangle),
        _statCard("Vel. Max", "65 km/h", LucideIcons.activity),
        _statCard("Uptime", "99.9%", LucideIcons.shield),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.indigo, size: 30),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
