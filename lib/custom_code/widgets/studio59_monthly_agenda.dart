// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/ff_builtin_enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart' hide RepeatMode;
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:convert';
import 'package:flutter/material.dart';

class Studio59MonthlyAgenda extends StatefulWidget {
  const Studio59MonthlyAgenda(
      {super.key, this.width, this.height, this.eventsJson});
  final double? width;
  final double? height;
  final String? eventsJson;

  @override
  State<Studio59MonthlyAgenda> createState() => _Studio59MonthlyAgendaState();
}

class _Studio59MonthlyAgendaState extends State<Studio59MonthlyAgenda> {
  late DateTime month;
  late DateTime selected;
  static const months = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro'
  ];
  static const weekdays = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];

  @override
  void initState() {
    super.initState();
    month = DateTime(DateTime.now().year, DateTime.now().month);
    selected = DateTime.now();
  }

  List<Map<String, dynamic>> get events {
    try {
      final raw = (widget.eventsJson ?? '').trim();
      if (raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is List)
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
    } catch (_) {}
    return [];
  }

  DateTime? eventDate(Map<String, dynamic> e) {
    final value = e['event_date'] ?? e['date'];
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  List<Map<String, dynamic>> eventsOn(DateTime date) => events.where((e) {
        final d = eventDate(e);
        return d != null &&
            d.year == date.year &&
            d.month == date.month &&
            d.day == date.day;
      }).toList();

  @override
  Widget build(BuildContext context) {
    final firstOffset = DateTime(month.year, month.month, 1).weekday - 1;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final cells = ((firstOffset + days + 6) ~/ 7) * 7;
    final selectedEvents = eventsOn(selected);
    return SizedBox(
      width: widget.width,
      height: widget.height ?? 610,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFECE7E3))),
        child: Column(children: [
          Row(children: [
            IconButton(
                onPressed: () => setState(() {
                      month = DateTime(month.year, month.month - 1);
                    }),
                icon: const Icon(Icons.chevron_left)),
            Expanded(
                child: Text(
                    '${months[month.month - 1][0].toUpperCase()}${months[month.month - 1].substring(1)} ${month.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF292624)))),
            IconButton(
                onPressed: () => setState(() {
                      month = DateTime(month.year, month.month + 1);
                    }),
                icon: const Icon(Icons.chevron_right)),
          ]),
          Row(
              children: weekdays
                  .map((d) => Expanded(
                      child: Center(
                          child: Text(d,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF817774),
                                  fontWeight: FontWeight.w600)))))
                  .toList()),
          const SizedBox(height: 8),
          SizedBox(
              height: 246,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cells,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4),
                itemBuilder: (context, index) {
                  final day = index - firstOffset + 1;
                  if (day < 1 || day > days) return const SizedBox.shrink();
                  final date = DateTime(month.year, month.month, day);
                  final count = eventsOn(date).length;
                  final active = date.year == selected.year &&
                      date.month == selected.month &&
                      date.day == selected.day;
                  return InkWell(
                      onTap: () => setState(() => selected = date),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                            color: active
                                ? const Color(0xFFB77F84)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12)),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('$day',
                                  style: TextStyle(
                                      color: active
                                          ? Colors.white
                                          : const Color(0xFF292624),
                                      fontWeight: active
                                          ? FontWeight.bold
                                          : FontWeight.normal)),
                              if (count > 0)
                                Container(
                                    width: 5,
                                    height: 5,
                                    margin: const EdgeInsets.only(top: 2),
                                    decoration: BoxDecoration(
                                        color: active
                                            ? Colors.white
                                            : const Color(0xFFB77F84),
                                        shape: BoxShape.circle)),
                            ]),
                      ));
                },
              )),
          const Divider(height: 20),
          Align(
              alignment: Alignment.centerLeft,
              child: Text('${selected.day} ${months[selected.month - 1]}',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF292624)))),
          const SizedBox(height: 8),
          Expanded(
              child: selectedEvents.isEmpty
                  ? const Align(
                      alignment: Alignment.topLeft,
                      child: Text('Sem serviços nesta data.',
                          style: TextStyle(color: Color(0xFF817774))))
                  : ListView.builder(
                      itemCount: selectedEvents.length,
                      itemBuilder: (context, i) {
                        final e = selectedEvents[i];
                        final time = (e['event_time'] ?? '').toString();
                        return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: const Color(0xFFFAF6F4),
                                borderRadius: BorderRadius.circular(12)),
                            child: Row(children: [
                              const Icon(Icons.event, color: Color(0xFFB77F84)),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text(
                                      (e['name'] ?? 'Serviço').toString(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Color(0xFF292624),
                                          fontWeight: FontWeight.w500))),
                              if (time.isNotEmpty)
                                Text(time,
                                    style: const TextStyle(
                                        color: Color(0xFF817774))),
                            ]));
                      })),
        ]),
      ),
    );
  }
}
