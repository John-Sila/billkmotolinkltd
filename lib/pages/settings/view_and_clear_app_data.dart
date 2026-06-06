import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ViewAndClearAppData extends StatefulWidget {
  const ViewAndClearAppData({super.key});

  @override
  State<ViewAndClearAppData> createState() => _ViewAndClearAppDataState();
}

class _ViewAndClearAppDataState extends State<ViewAndClearAppData> {
  Map<String, dynamic> _storageInfo = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStorageInfo();
  }

  Future<void> _loadStorageInfo() async {
    setState(() => _isLoading = true);
    
    try {
      final info = await _getStorageDetails();
      if (mounted) {
        setState(() {
          _storageInfo = info;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _storageInfo = {'error': e.toString()};
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _getStorageDetails() async {
    // SharedPreferences size
    final prefs = await SharedPreferences.getInstance();
    final prefsKeys = prefs.getKeys();
    final prefsSize = prefsKeys.length;

    // Cache size
    final cacheDir = await getTemporaryDirectory();
    final cacheSize = await _getDirectorySize(cacheDir);

    // App documents size
    final appDir = await getApplicationDocumentsDirectory();
    final appSize = await _getDirectorySize(appDir);

    // ✅ FIXED: Proper Flutter image cache size
    final paintingCacheSize = PaintingBinding.instance.imageCache
        .currentSizeBytes;

    return {
      'sharedPrefs': prefsSize,
      'cacheSize': cacheSize,
      'appDataSize': appSize,
      'imageCacheSize': paintingCacheSize,
      'totalSize': cacheSize + appSize + paintingCacheSize,
    };
  }

  Future<int> _getDirectorySize(Directory dir) async {
    try {
      final files = dir.listSync(recursive: true);
      int total = 0;
      for (final file in files) {
        if (file is File) {
          total += await file.length();
        }
      }
      return total;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _clearSharedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _showSuccess('Shared Preferences cleared');
  }

  Future<void> _clearCache() async {
    final cacheDir = await getTemporaryDirectory();
    await cacheDir.delete(recursive: true);
    await DefaultCacheManager().emptyCache();
    _showSuccess('Cache cleared');
  }

  Future<void> _clearAppData() async {
    final appDir = await getApplicationDocumentsDirectory();
    await appDir.delete(recursive: true);
    _showSuccess('App Data cleared');
  }

  Future<void> _clearAll() async {
    await _clearSharedPrefs();
    await _clearCache();
    await _clearAppData();
    _loadStorageInfo();
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text(message),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadStorageInfo();
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Storage Manager', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStorageInfo,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primary.withValues(alpha: 0.1),
                                theme.colorScheme.primaryContainer,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.storage, size: 48, color: theme.colorScheme.primary),
                              const SizedBox(height: 16),
                              Text(
                                'App Storage',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              Text(
                                _formatBytes(_storageInfo['totalSize'] ?? 0),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Storage Cards
                        ...[
                          {
                            'title': 'Shared Preferences',
                            'size': _storageInfo['sharedPrefs'] ?? 0,
                            'unit': 'keys',
                            'icon': Icons.settings,
                            'color': theme.colorScheme.primary,
                            'onClear': _clearSharedPrefs,
                          },
                          {
                            'title': 'Cache Files',
                            'size': _storageInfo['cacheSize'] ?? 0,
                            'unit': 'bytes',
                            'icon': Icons.folder,
                            'color': theme.colorScheme.secondary,
                            'onClear': _clearCache,
                          },
                          {
                            'title': 'App Documents',
                            'size': _storageInfo['appDataSize'] ?? 0,
                            'unit': 'bytes',
                            'icon': Icons.description,
                            'color': theme.colorScheme.tertiary,
                            'onClear': _clearAppData,
                          },
                          {
                            'title': 'Image Cache',
                            'size': _storageInfo['imageCacheSize'] ?? 0,
                            'unit': 'bytes',
                            'icon': Icons.image,
                            'color': theme.colorScheme.error,
                            'onClear': _clearCache,
                          },
                        ].map((stat) => _buildStorageCard(theme, stat)),
                        const SizedBox(height: 32),

                        // Clear All Button
                        _buildClearAllButton(theme),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStorageCard(ThemeData theme, Map<String, dynamic> stat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.surfaceTint.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: stat['onClear'],
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [stat['color'].withValues(alpha: 0.2), stat['color'].withValues(alpha: 0.1)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(stat['icon'], color: stat['color'], size: 24),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stat['title'],
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatBytes(stat['size'])} (${stat['size']} ${stat['unit']})',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.delete_outline, color: theme.colorScheme.error),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClearAllButton(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.error, theme.colorScheme.errorContainer],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.error.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.warning, color: theme.colorScheme.error),
                  const SizedBox(width: 12),
                  Text('Clear All Data?', style: theme.textTheme.titleLarge),
                ],
              ),
              content: Text(
                'This will permanently delete all app data including cache, preferences, and stored files. This action cannot be undone.',
                style: theme.textTheme.bodyMedium,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurface)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _clearAll();
                  },
                  child: const Text('Clear All'),
                ),
              ],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.clear_all, color: Colors.white),
              const SizedBox(width: 12),
              const Text(
                'Clear All Storage',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
