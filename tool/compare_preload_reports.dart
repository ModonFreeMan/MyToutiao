import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln(
      'Usage: dart run tool/compare_preload_reports.dart '
      '<baseline.json> <preload.json>',
    );
    exitCode = 64;
    return;
  }

  final baselineSource = _readReport(args[0]);
  final preloadSource = _readReport(args[1]);
  final baseline = baselineSource.report;
  final preload = preloadSource.report;

  final lines = <String>[
    '# Preload Comparison Report',
    '',
    'baseline: ${args[0]}',
    'preload only: ${args[1]}',
    '',
    '## Sample Quality',
    '',
    _row('visible_items', baseline, preload),
    _row('valid_first_frame_samples', baseline, preload),
    _row('valid_startup_samples', baseline, preload),
    _row('valid_initialize_samples', baseline, preload),
    _row('expired_sessions', baseline, preload),
    _row('incomplete_sessions', baseline, preload),
    _row('initialize_failed_sessions', baseline, preload),
    _row('ignored_late_events', baseline, preload),
    '',
    '## Startup',
    '',
    ..._percentileRows('startup_ms', baseline, preload),
    '',
    '## First Frame',
    '',
    ..._percentileRows('first_frame_ms', baseline, preload),
    '',
    '## Initialize',
    '',
    ..._percentileRows('initialize_ms', baseline, preload),
    '',
    '## Buffering',
    '',
    ..._percentileRows('startup_buffering_count', baseline, preload),
    '',
    ..._percentileRows('startup_buffering_total_ms', baseline, preload),
    '',
    '## Preload',
    '',
    'preload_visible_items: ${_value(preload, 'preload_visible_items')}',
    'preload_hits: ${_value(preload, 'preload_hits')}',
    'preload_misses: ${_value(preload, 'preload_misses')}',
    'preload_promoted_to_active: '
        '${_value(preload, 'preload_promoted_to_active')}',
    'preload_hit_rate_label: ${_value(preload, 'preload_hit_rate_label')}',
    '',
    '## Conclusion',
    '',
    ..._conclusion(baseline, preload),
  ];

  stdout.writeln(lines.join('\n'));
}

_ReportSource _readReport(String path) {
  final json = jsonDecode(File(path).readAsStringSync());
  if (json is! Map<String, Object?>) {
    throw FormatException('Root JSON must be an object: $path');
  }

  final report = json['report'];
  if (report is Map<String, Object?>) {
    return _ReportSource(json, report);
  }

  return _ReportSource(json, json);
}

String _row(
  String key,
  Map<String, Object?> baseline,
  Map<String, Object?> preload,
) {
  return '$key: baseline ${_value(baseline, key)} -> '
      'preload ${_value(preload, key)}';
}

List<String> _percentileRows(
  String key,
  Map<String, Object?> baseline,
  Map<String, Object?> preload,
) {
  return <String>[
    '$key:',
    for (final percentile in <String>['p50', 'p90', 'p95'])
      '  $percentile: ${_deltaText(_percentile(baseline, key, percentile), _percentile(preload, key, percentile))}',
  ];
}

List<String> _conclusion(
  Map<String, Object?> baseline,
  Map<String, Object?> preload,
) {
  final startupP90 = _delta(
    _percentile(baseline, 'startup_ms', 'p90'),
    _percentile(preload, 'startup_ms', 'p90'),
  );
  final startupP95 = _delta(
    _percentile(baseline, 'startup_ms', 'p95'),
    _percentile(preload, 'startup_ms', 'p95'),
  );
  final initP90 = _delta(
    _percentile(baseline, 'initialize_ms', 'p90'),
    _percentile(preload, 'initialize_ms', 'p90'),
  );
  final bufferingP90 = _delta(
    _percentile(baseline, 'startup_buffering_total_ms', 'p90'),
    _percentile(preload, 'startup_buffering_total_ms', 'p90'),
  );
  final hitRate = _value(preload, 'preload_hit_rate_label');
  final hits = _intValue(preload, 'preload_hits');
  final promoted = _intValue(preload, 'preload_promoted_to_active');
  final preloadInitSamples = _intValue(preload, 'valid_initialize_samples');

  return <String>[
    if (startupP90 != null && startupP90 <= 0 ||
        startupP95 != null && startupP95 <= 0)
      'startup_ms p90 / p95 shows improvement or no regression.'
    else
      'startup_ms p90 / p95 does not show improvement.',
    'preload hit rate is $hitRate, with $promoted promoted out of $hits hits.',
    if (hits != null && promoted != null && hits == promoted)
      'preload_promoted_to_active matches preload_hits.'
    else
      'preload_promoted_to_active does not match preload_hits; inspect missed promotion cases.',
    if (initP90 != null && initP90 > 0 && preloadInitSamples != null)
      'initialize_ms p90 increased by ${initP90}ms, but preload valid_initialize_samples is $preloadInitSamples.'
    else
      'initialize_ms p90 has no obvious increase.',
    if (bufferingP90 != null && bufferingP90 > 0)
      'startup buffering total p90 increased by ${bufferingP90}ms.'
    else
      'startup buffering total p90 has no obvious regression.',
  ];
}

Object? _value(Map<String, Object?> report, String key) => report[key];

int? _intValue(Map<String, Object?> report, String key) {
  final value = report[key];
  return value is num ? value.round() : null;
}

num? _percentile(Map<String, Object?> report, String key, String percentile) {
  final metric = report[key];
  if (metric is! Map<String, Object?>) {
    return null;
  }
  final value = metric[percentile];
  return value is num ? value : null;
}

num? _delta(num? baseline, num? preload) {
  if (baseline == null || preload == null) {
    return null;
  }
  return preload - baseline;
}

String _deltaText(num? baseline, num? preload) {
  if (baseline == null || preload == null) {
    return 'baseline ${baseline ?? 'N/A'} -> preload ${preload ?? 'N/A'}';
  }

  final delta = preload - baseline;
  final direction = delta < 0
      ? 'down'
      : delta > 0
      ? 'up'
      : 'same';
  return 'baseline ${_formatNumber(baseline)} -> '
      'preload ${_formatNumber(preload)}, '
      '$direction ${_formatNumber(delta.abs())}';
}

String _formatNumber(num value) {
  if (value is int || value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(2);
}

class _ReportSource {
  const _ReportSource(this.root, this.report);

  final Map<String, Object?> root;
  final Map<String, Object?> report;
}
