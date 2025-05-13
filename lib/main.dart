import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';

void main() => runApp(CustodianSelectorApp());

class CustodianSelectorApp extends StatelessWidget {
  const CustodianSelectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Source Selector',
      home: CustodianSelectorPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class CustodianSelectorPage extends StatefulWidget {
  const CustodianSelectorPage({super.key});

  @override
  _CustodianSelectorPageState createState() => _CustodianSelectorPageState();
}

class _CustodianSelectorPageState extends State<CustodianSelectorPage> {
  List<String> availableCustodians = [
    'Fidelity', 'Pershing', 'LPL', 'Charles Schwab', 'TD Ameritrade', 'Raymond James',
  ];
  List<String> selectedCustodians = [];
  bool isClientSelected = false;
  String? selectedLinkageType;
  final probabilityController = TextEditingController();
  List<TextEditingController> blockingRuleControllers = [];
  List<TextEditingController> arraysControllers = [];
  List<TextEditingController> trainingControllers = [];
  List<TextEditingController> comparisonControllers = [];
  List<TextEditingController> deterministicRuleControllers = [];

  void _selectCustodian(String custodian) {
    setState(() {
      availableCustodians.remove(custodian);
      selectedCustodians.add(custodian);
    });
  }

  void _removeCustodian(String custodian) {
    setState(() {
      selectedCustodians.remove(custodian);
      availableCustodians.add(custodian);
    });
  }

  void _downloadJson() {
    final Map<String, dynamic> jsonOutput = {
      'source_client': {
        'source': {
          'app_types': selectedCustodians.map((c) => 'source-${c.toLowerCase().replaceAll(' ', '-')}.connector').toList(),
        },
      },
      'match_merging_dbt_client': {
        'source': {
          'app_types': selectedCustodians.map((c) => 'source-${c.toLowerCase().replaceAll(' ', '-')}.connector').toList(),
        },
      },
    };

    if (isClientSelected && selectedLinkageType == 'probabilistic') {
      jsonOutput['entities'] = {
        'client': {
          'linkage': {
            'type': 'probabilistic',
            'conf': {
              'unique_id_column_name': 'dv_hashkey_hub_client',
              'threshold_match_probability': double.tryParse(probabilityController.text) ?? 0.0,
              'blocking': List.generate(blockingRuleControllers.length, (i) => {
                'blocking_rule': blockingRuleControllers[i].text,
                'arrays_to_explode': arraysControllers[i].text.split(',').map((e) => e.trim()).toList(),
              }),
              'training': [
                {
                  'expectation_maximization': trainingControllers.map((c) => {
                    'block_on': c.text.split(',').map((e) => e.trim()).toList(),
                  }).toList(),
                }
              ],
              'comparisons': comparisonControllers.map((c) => {
                'template': 'name_comparison',
                'args': {'col_name': c.text},
              }).toList(),
            }
          }
        }
      };
    } else if (isClientSelected && selectedLinkageType == 'deterministic') {
      jsonOutput['entities'] = {
        'client': {
          'linkage': {
            'type': 'deterministic',
            'conf': {
              'rules': deterministicRuleControllers.map((c) => c.text).join(', '),
            }
          }
        }
      };
    }

    final prettyJson = JsonEncoder.withIndent('  ').convert(jsonOutput);
    final blob = html.Blob([utf8.encode(prettyJson)]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "output.json")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Source Selector')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildPanel('Available Custodians', availableCustodians, _selectCustodian, Icons.arrow_forward)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildPanel('Selected Custodians', selectedCustodians, _removeCustodian, Icons.arrow_back)),
                ],
              ),
            ),
            Divider(thickness: 2),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 100),
                  child: _buildEntitiesSection(),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _downloadJson,
        label: Text('Download JSON'),
        icon: Icon(Icons.download),
      ),
    );
  }

  Widget _buildPanel(String title, List<String> items, Function(String) onTap, IconData icon) {
    return Column(
      children: [
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Expanded(
          child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
            child: ListView(
              children: items.map((item) => ListTile(
                title: Text(item),
                trailing: Icon(icon),
                onTap: () => onTap(item),
              )).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEntitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Entities', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        CheckboxListTile(
          title: Text('Client'),
          value: isClientSelected,
          onChanged: (val) => setState(() => isClientSelected = val ?? false),
        ),
        if (isClientSelected) ...[
          Text('Linkage Type:'),
          DropdownButton<String>(
            value: selectedLinkageType,
            hint: Text('Select Linkage Type'),
            items: ['probabilistic', 'deterministic'].map((type) => DropdownMenuItem(
              value: type,
              child: Text(type),
            )).toList(),
            onChanged: (val) => setState(() => selectedLinkageType = val),
          ),
        ],
        if (isClientSelected && selectedLinkageType == 'probabilistic') ...[
          TextField(
            controller: probabilityController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Probability Threshold (e.g., 0.97)'),
          ),
          Divider(),
          Text('Blocking', style: TextStyle(fontWeight: FontWeight.bold)),
          ...blockingRuleControllers.asMap().entries.map((entry) {
            int i = entry.key;
            return Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      TextField(controller: blockingRuleControllers[i], decoration: InputDecoration(labelText: 'Blocking Rule')),
                      TextField(controller: arraysControllers[i], decoration: InputDecoration(labelText: 'Arrays to Explode (comma-separated)')),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => setState(() {
                    blockingRuleControllers.removeAt(i);
                    arraysControllers.removeAt(i);
                  }),
                ),
              ],
            );
          }),
          ElevatedButton(
            onPressed: () => setState(() {
              blockingRuleControllers.add(TextEditingController());
              arraysControllers.add(TextEditingController());
            }),
            child: Text('Add Blocking Rule'),
          ),
          Divider(),
          Text('Training', style: TextStyle(fontWeight: FontWeight.bold)),
          ...trainingControllers.asMap().entries.map((entry) {
            int i = entry.key;
            return Row(
              children: [
                Expanded(child: TextField(controller: entry.value, decoration: InputDecoration(labelText: 'Block On (comma-separated)'))),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => setState(() {
                    trainingControllers.removeAt(i);
                  }),
                ),
              ],
            );
          }),
          ElevatedButton(
            onPressed: () => setState(() => trainingControllers.add(TextEditingController())),
            child: Text('Add Training Block'),
          ),
          Divider(),
          Text('Comparisons', style: TextStyle(fontWeight: FontWeight.bold)),
          ...comparisonControllers.asMap().entries.map((entry) {
            int i = entry.key;
            return Row(
              children: [
                Expanded(child: TextField(controller: entry.value, decoration: InputDecoration(labelText: 'Comparison Column Name'))),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => setState(() {
                    comparisonControllers.removeAt(i);
                  }),
                ),
              ],
            );
          }),
          ElevatedButton(
            onPressed: () => setState(() => comparisonControllers.add(TextEditingController())),
            child: Text('Add Comparison'),
          ),
        ],
        if (isClientSelected && selectedLinkageType == 'deterministic') ...[
          Divider(),
          Text('Deterministic Rules', style: TextStyle(fontWeight: FontWeight.bold)),
          ...deterministicRuleControllers.asMap().entries.map((entry) {
            int i = entry.key;
            return Row(
              children: [
                Expanded(child: TextField(controller: entry.value, decoration: InputDecoration(labelText: 'Rule'))),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => setState(() {
                    deterministicRuleControllers.removeAt(i);
                  }),
                ),
              ],
            );
          }),
          ElevatedButton(
            onPressed: () => setState(() => deterministicRuleControllers.add(TextEditingController())),
            child: Text('Add Rule'),
          ),
        ],
      ],
    );
  }
}
