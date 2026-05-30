import 'dart:convert';

import 'package:app/src/core/api/client/dio/rest_client.dart';
import 'package:app/src/core/api/client/endpoints.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/service/location/i_location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LeaderboardAdminPage extends StatefulWidget {
  const LeaderboardAdminPage({super.key});

  @override
  State<LeaderboardAdminPage> createState() => _LeaderboardAdminPageState();
}

class _LeaderboardAdminPageState extends State<LeaderboardAdminPage> {
  late final RestClient _client;
  late final TextEditingController _userIdController;
  late final TextEditingController _regionController;
  late final TextEditingController _scoreController;

  String _scope = 'district';
  bool _loadingScopes = false;
  bool _submitting = false;
  bool _checking = false;
  bool _resolvingRegion = false;
  bool _loadingMe = false;
  List<_LeaderboardScopeInfo> _scopes = const [];
  String _output = '';

  @override
  void initState() {
    super.initState();
    _client = getIt<RestClient>(instanceName: 'DioClient');
    _userIdController = TextEditingController();
    _regionController = TextEditingController();
    _scoreController = TextEditingController(text: '15');
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _regionController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  Future<void> _loadScopes() async {
    setState(() {
      _loadingScopes = true;
      _output = 'Loading admin scopes...';
    });

    final result = await _client.get(EndPoints.adminLeaderboardScopes);
    if (!mounted) return;

    result.fold(
      (error) {
        setState(() {
          _loadingScopes = false;
          _output = 'Scopes failed: ${error.message}';
        });
      },
      (response) {
        final data = response.data;
        final rawScopes = data is Map ? data['scopes'] : null;
        final scopes = rawScopes is List
            ? rawScopes
                .whereType<Map>()
                .map((item) => _LeaderboardScopeInfo.fromJson(item))
                .toList(growable: false)
            : <_LeaderboardScopeInfo>[];

        setState(() {
          _loadingScopes = false;
          _scopes = scopes;
          _output = _pretty(data);
        });
      },
    );
  }

  Future<void> _addUser() async {
    final userId = _userIdController.text.trim();
    if (userId.isEmpty) {
      _showSnack('User ID is required');
      return;
    }

    final score = double.tryParse(_scoreController.text.trim()) ?? 15;
    final region = _regionController.text.trim();
    if (_scope != 'global' && region.isEmpty) {
      _showSnack('Region is required for $_scope');
      return;
    }

    final payload = <String, dynamic>{
      'user_id': userId,
      'scope': _scope,
      'score': score,
      if (_scope != 'global') 'region': region,
    };

    setState(() {
      _submitting = true;
      _output =
          'POST ${EndPoints.adminLeaderboardAddUser}\n${_pretty(payload)}';
    });

    final result = await _client.post(
      EndPoints.adminLeaderboardAddUser,
      data: payload,
    );
    if (!mounted) return;

    result.fold(
      (error) {
        setState(() {
          _submitting = false;
          _output = 'Add user failed: ${error.message}';
        });
      },
      (response) {
        setState(() {
          _submitting = false;
          _output = 'Add user OK:\n${_pretty(response.data)}';
        });
      },
    );
  }

  Future<void> _resolveCurrentUserRegion() async {
    setState(() {
      _resolvingRegion = true;
      _output = 'Resolving current device location...';
    });

    final location = await getIt<ILocationService>(
      instanceName: 'LocationServiceImpl',
    ).resolveCurrentLocation();

    if (!mounted) return;
    if (!location.isSuccess) {
      setState(() {
        _resolvingRegion = false;
        _output = location.message ?? 'Unable to resolve location.';
      });
      return;
    }

    final payload = <String, dynamic>{
      'latitude': location.latitude,
      'longitude': location.longitude,
      'participate_region': true,
      'location_opt_in': true,
    };

    setState(() {
      _output = 'POST ${EndPoints.mapRegion}\n${_pretty(payload)}';
    });

    final result = await _client.post(EndPoints.mapRegion, data: payload);
    if (!mounted) return;

    result.fold(
      (error) {
        setState(() {
          _resolvingRegion = false;
          _output = 'Resolve H3 failed: ${error.message}';
        });
      },
      (response) {
        final data = response.data;
        final map = data is Map ? data : const <dynamic, dynamic>{};
        final h3Res5 = map['h3_res5']?.toString() ?? '';
        final h3Res4 = map['h3_res4']?.toString() ?? '';
        final h3Res2 = map['h3_res2']?.toString() ?? '';
        final region = switch (_scope) {
          'district' => h3Res5,
          'city' => h3Res4,
          'country' => h3Res2,
          _ => '',
        };

        setState(() {
          _resolvingRegion = false;
          if (region.isNotEmpty) {
            _regionController.text = region;
          }
          _output = 'Current user H3:\n${_pretty(data)}';
        });
      },
    );
  }

  Future<void> _loadMyUserId() async {
    setState(() {
      _loadingMe = true;
      _output = 'GET ${EndPoints.profileMe}';
    });

    final result = await _client.get(EndPoints.profileMe);
    if (!mounted) return;

    result.fold(
      (error) {
        setState(() {
          _loadingMe = false;
          _output = 'Get my user id failed: ${error.message}';
        });
      },
      (response) {
        final data = response.data;
        final map = data is Map ? data : const <dynamic, dynamic>{};
        final userId = (map['user_id'] ?? map['id'] ?? '').toString();

        setState(() {
          _loadingMe = false;
          if (userId.isNotEmpty) {
            _userIdController.text = userId;
          }
          _output = 'My profile:\n${_pretty(data)}';
        });
      },
    );
  }

  Future<void> _checkLeaderboard(String scope) async {
    setState(() {
      _checking = true;
      _output = 'GET ${EndPoints.leaderboard}?scope=$scope&limit=50';
    });

    final result = await _client.get(
      EndPoints.leaderboard,
      queryParameters: <String, dynamic>{
        'scope': scope,
        'limit': 50,
      },
    );
    if (!mounted) return;

    result.fold(
      (error) {
        setState(() {
          _checking = false;
          _output = 'Check $scope failed: ${error.message}';
        });
      },
      (response) {
        setState(() {
          _checking = false;
          _output = 'Leaderboard $scope:\n${_pretty(response.data)}';
        });
      },
    );
  }

  void _useScope(_LeaderboardScopeInfo scope) {
    setState(() {
      _scope = scope.scope;
      _regionController.text = scope.region;
    });
  }

  void _copyOutput() {
    Clipboard.setData(ClipboardData(text: _output));
    _showSnack('Copied');
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  String _pretty(Object? value) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(value);
    } catch (_) {
      return value.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _loadingScopes ||
        _submitting ||
        _checking ||
        _resolvingRegion ||
        _loadingMe;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard Admin'),
        actions: [
          IconButton(
            tooltip: 'Copy output',
            onPressed: _output.isEmpty ? null : _copyOutput,
            icon: const Icon(Icons.copy),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: '1. Live Redis scopes',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: busy ? null : _loadScopes,
                  icon: _loadingScopes
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: const Text('Load /admin/leaderboard/scopes'),
                ),
                const SizedBox(height: 12),
                if (_scopes.isEmpty)
                  const Text('No scopes loaded yet.')
                else
                  ..._scopes.map(
                    (scope) => Card(
                      child: ListTile(
                        title: Text(scope.key),
                        subtitle: Text(
                          'scope=${scope.scope}  region=${scope.region.isEmpty ? '-' : scope.region}  card=${scope.card}',
                        ),
                        trailing: const Icon(Icons.input),
                        onTap: () => _useScope(scope),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _Section(
            title: '2. Add user to leaderboard',
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _scope,
                  decoration: const InputDecoration(
                    labelText: 'Scope',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'district', child: Text('district')),
                    DropdownMenuItem(value: 'city', child: Text('city')),
                    DropdownMenuItem(value: 'country', child: Text('country')),
                    DropdownMenuItem(value: 'global', child: Text('global')),
                  ],
                  onChanged: busy
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _scope = value;
                          });
                        },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: busy || _scope == 'global'
                        ? null
                        : _resolveCurrentUserRegion,
                    icon: _resolvingRegion
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(
                      _scope == 'global'
                          ? 'Global does not need H3'
                          : 'Get my H3 for selected scope',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _regionController,
                  enabled: !busy && _scope != 'global',
                  decoration: InputDecoration(
                    labelText: _scope == 'global'
                        ? 'Region is not needed for global'
                        : 'Region / H3',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : _loadMyUserId,
                    icon: _loadingMe
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.badge),
                    label: const Text('Get my user id'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _userIdController,
                  enabled: !busy,
                  decoration: const InputDecoration(
                    labelText: 'User ID to add',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _scoreController,
                  enabled: !busy,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Score',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: busy ? null : _addUser,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_add),
                    label: const Text('POST /admin/leaderboard/add-user'),
                  ),
                ),
              ],
            ),
          ),
          _Section(
            title: '3. Verify result',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final scope in const [
                  'district',
                  'city',
                  'country',
                  'global',
                ])
                  OutlinedButton(
                    onPressed: busy ? null : () => _checkLeaderboard(scope),
                    child: Text('GET $scope'),
                  ),
              ],
            ),
          ),
          _Section(
            title: 'Output',
            child: SelectableText(
              _output.isEmpty ? 'No output yet.' : _output,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _LeaderboardScopeInfo {
  const _LeaderboardScopeInfo({
    required this.scope,
    required this.region,
    required this.key,
    required this.card,
  });

  final String scope;
  final String region;
  final String key;
  final int card;

  factory _LeaderboardScopeInfo.fromJson(Map<dynamic, dynamic> json) {
    final key = json['key']?.toString() ?? '';
    return _LeaderboardScopeInfo(
      scope: json['scope']?.toString() ?? _scopeFromKey(key),
      region: json['region']?.toString() ?? _regionFromKey(key),
      key: key,
      card: (json['card'] as num?)?.toInt() ?? 0,
    );
  }

  static String _scopeFromKey(String key) {
    if (key.startsWith('leaderboard:arena:')) return 'district';
    if (key.startsWith('leaderboard:city:')) return 'city';
    if (key.startsWith('leaderboard:country:')) return 'country';
    return 'global';
  }

  static String _regionFromKey(String key) {
    final parts = key.split(':');
    if (parts.length < 5 || parts[0] != 'leaderboard') return '';
    if (parts[1] == 'global') return '';
    return parts[2];
  }
}
