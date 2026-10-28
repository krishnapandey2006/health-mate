import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../app/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/facility.dart';
import '../services/facility_service.dart';
import '../services/sos_service.dart';
import '../widgets/app_widgets.dart';

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  final FacilityService _facilityService = FacilityService();
  final TextEditingController _searchController = TextEditingController();

  double? _latitude;
  double? _longitude;
  String _locationLabel = '';
  List<Facility> _facilities = const [];
  bool _loading = false;
  bool _locating = false;
  bool _searchingPlaces = false;
  String? _error;
  String? _warning;
  String _source = 'OpenStreetMap';
  String _filter = 'all';
  double _radiusKm = 8;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _locating = false;
            _error = l10n.t('location_services_off');
          });
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _locating = false;
            _error = l10n.t('location_permission_denied');
          });
        }
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locating = false;
            _error = l10n.t('location_permission_forever');
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationLabel = l10n.t('current_location');
        _locating = false;
      });
      await _loadFacilities();
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _locating = false;
          _error = l10n.t('location_timeout');
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _locating = false;
          _error = l10n.t('location_unavailable');
        });
      }
    }
  }

  Future<void> _searchPlaces() async {
    final query = _searchController.text.trim();
    if (query.length < 2) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searchingPlaces = true;
      _error = null;
    });
    final places = await _facilityService.searchPlaces(query);
    if (!mounted) return;
    setState(() => _searchingPlaces = false);
    if (places.isEmpty) {
      showAppSnackBar(context, AppLocalizations.of(context).t('place_search_empty'), isError: true);
      return;
    }
    final selected = await showModalBottomSheet<PlaceResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: SizedBox(
              height: 440,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppLocalizations.of(context).t('select_area'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      itemCount: places.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final place = places[index];
                        return ListTile(
                          leading: const Icon(Icons.location_on_outlined, color: AppColors.teal),
                          title: Text(place.displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.of(context).pop(place),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    setState(() {
      _latitude = selected.latitude;
      _longitude = selected.longitude;
      _locationLabel = selected.displayName;
    });
    await _loadFacilities();
  }

  Future<void> _loadFacilities({double? radiusKm, String? filter}) async {
    final lat = _latitude;
    final lon = _longitude;
    if (lat == null || lon == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _warning = null;
      _radiusKm = radiusKm ?? _radiusKm;
      _filter = filter ?? _filter;
    });
    final result = await _facilityService.nearby(
      latitude: lat,
      longitude: lon,
      radiusKm: _radiusKm,
      type: _filter,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _facilities = result.facilities;
      _warning = result.warning;
      _source = result.source;
      _error = result.isError ? result.error?.message : null;
    });
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      showAppSnackBar(context, AppLocalizations.of(context).t('no_phone'), isError: true);
      return;
    }
    try {
      await SOSService.openDialer(phone);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, AppLocalizations.of(context).t('dialer_unavailable'), isError: true);
      }
    }
  }

  Future<void> _openDirections(Facility facility) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${facility.latitude},${facility.longitude}',
    );
    final opened = await openExternalUrl(context, uri.toString());
    if (!opened && mounted) {
      final osm = Uri.parse(
        'https://www.openstreetmap.org/?mlat=${facility.latitude}&mlon=${facility.longitude}#map=16/${facility.latitude}/${facility.longitude}',
      );
      await openExternalUrl(context, osm.toString());
    }
  }

  Future<void> _openAreaMap() async {
    final lat = _latitude;
    final lon = _longitude;
    if (lat == null || lon == null) {
      await openExternalUrl(context, 'https://www.openstreetmap.org/');
      return;
    }
    await openExternalUrl(
      context,
      'https://www.openstreetmap.org/#map=14/$lat/$lon',
    );
  }

  Future<void> _openLocationSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, AppLocalizations.of(context).t('settings_unavailable'), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasLocation = _latitude != null && _longitude != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('nearby')),
        actions: [
          if (hasLocation)
            IconButton(
              tooltip: l10n.t('open_map'),
              onPressed: _openAreaMap,
              icon: const Icon(Icons.map_outlined),
            ),
          if (hasLocation)
            IconButton(
              tooltip: l10n.t('refresh'),
              onPressed: () => _loadFacilities(),
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: hasLocation ? () => _loadFacilities() : () async {},
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: ResponsiveBody(
                maxWidth: 920,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppInfoBanner(
                      icon: Icons.near_me_outlined,
                      text: l10n.t('nearby_permission_explanation'),
                      color: AppColors.tealDark,
                      background: AppColors.tealSoft,
                    ),
                    const SizedBox(height: 14),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              hasLocation ? _locationLabel : l10n.t('choose_location'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (hasLocation)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  l10n.t('within_radius').replaceAll('{radius}', _radiusKm.toStringAsFixed(0)),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _locating ? null : _useMyLocation,
                                    icon: _locating
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.my_location_rounded),
                                    label: Text(l10n.t('use_my_location')),
                                  ),
                                ),
                                if (hasLocation) ...[
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    onPressed: _openAreaMap,
                                    child: Text(l10n.t('map')),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    textInputAction: TextInputAction.search,
                                    decoration: InputDecoration(
                                      hintText: l10n.t('search_city_or_area'),
                                      prefixIcon: const Icon(Icons.search_rounded),
                                      isDense: true,
                                    ),
                                    onSubmitted: (_) => _searchPlaces(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filledTonal(
                                  tooltip: l10n.t('search'),
                                  onPressed: _searchingPlaces ? null : _searchPlaces,
                                  icon: _searchingPlaces
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.arrow_forward_rounded),
                                ),
                              ],
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 10),
                              AppInfoBanner(
                                icon: Icons.error_outline_rounded,
                                text: _error!,
                                color: AppColors.danger,
                                background: AppColors.dangerSoft,
                                trailing: _error!.toLowerCase().contains('permission')
                                    ? TextButton(
                                        onPressed: _openLocationSettings,
                                        child: Text(l10n.t('settings')),
                                      )
                                    : null,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (hasLocation) ...[
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final filter in const [
                              ('all', 'filter_all'),
                              ('hospital', 'filter_hospitals'),
                              ('clinic', 'filter_clinics'),
                              ('pharmacy', 'filter_pharmacies'),
                            ]) ...[
                              ChoiceChip(
                                label: Text(l10n.t(filter.$2)),
                                selected: _filter == filter.$1,
                                onSelected: (_) => _loadFacilities(filter: filter.$1),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                      if (_warning != null) ...[
                        const SizedBox(height: 10),
                        AppInfoBanner(
                          icon: Icons.info_outline_rounded,
                          text: _warning!,
                          color: AppColors.warning,
                          background: AppColors.warningSoft,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            if (!hasLocation)
              SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState(
                  icon: Icons.location_searching_rounded,
                  title: l10n.t('choose_location'),
                  message: l10n.t('nearby_choose_body'),
                  actionLabel: l10n.t('use_my_location'),
                  onAction: _useMyLocation,
                ),
              )
            else if (_loading)
              const SliverToBoxAdapter(
                child: ResponsiveBody(
                  maxWidth: 920,
                  child: Column(
                    children: [
                      ArticleSkeleton(),
                      SizedBox(height: 10),
                      ArticleSkeleton(),
                      SizedBox(height: 10),
                      ArticleSkeleton(),
                    ],
                  ),
                ),
              )
            else if (_facilities.isEmpty && _error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: AppErrorState(
                  title: l10n.t('nearby_unavailable'),
                  message: _error!,
                  onRetry: () => _loadFacilities(),
                ),
              )
            else if (_facilities.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState(
                  icon: Icons.local_hospital_outlined,
                  title: l10n.t('no_facilities_title'),
                  message: l10n.t('no_facilities_body'),
                  actionLabel: l10n.t('search_wider_area'),
                  onAction: () => _loadFacilities(radiusKm: 20),
                ),
              )
            else
              SliverToBoxAdapter(
                child: ResponsiveBody(
                  maxWidth: 920,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.t('facilities_found').replaceAll('{count}', '${_facilities.length}'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          Text(
                            _source,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (var i = 0; i < _facilities.length; i++) ...[
                        _FacilityCard(
                          facility: _facilities[i],
                          onCall: () => _call(_facilities[i].phone),
                          onDirections: () => _openDirections(_facilities[i]),
                        ),
                        if (i != _facilities.length - 1) const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 16),
                      AppInfoBanner(
                        icon: Icons.info_outline_rounded,
                        text: l10n.t('facility_disclaimer'),
                        color: AppColors.slate,
                        background: const Color(0xFFF0F5F3),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _openAreaMap,
                        icon: const Icon(Icons.map_outlined),
                        label: Text(l10n.t('open_in_maps')),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FacilityCard extends StatelessWidget {
  final Facility facility;
  final VoidCallback onCall;
  final VoidCallback onDirections;

  const _FacilityCard({
    required this.facility,
    required this.onCall,
    required this.onDirections,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final distance = facility.distanceKm;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.tealSoft,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    facility.type == 'pharmacy'
                        ? Icons.local_pharmacy_outlined
                        : facility.type == 'clinic' || facility.type == 'doctors'
                            ? Icons.medical_services_outlined
                            : Icons.local_hospital_outlined,
                    color: AppColors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        facility.displayName,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        facility.typeLabel,
                        style: const TextStyle(
                          color: AppColors.tealDark,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (distance != null)
                  AppStatusChip(
                    label: '${distance.toStringAsFixed(distance < 10 ? 1 : 0)} km',
                    color: AppColors.slate,
                    background: const Color(0xFFF0F5F3),
                    icon: Icons.near_me_outlined,
                  ),
              ],
            ),
            if (facility.address.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: AppColors.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      facility.address,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
            if (facility.openingHours != null && facility.openingHours!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.schedule_outlined, size: 16, color: AppColors.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      facility.openingHours!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: facility.phone == null ? null : onCall,
                    icon: const Icon(Icons.call_outlined, size: 18),
                    label: Text(facility.phone == null ? l10n.t('no_phone') : l10n.t('call')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onDirections,
                    icon: const Icon(Icons.directions_outlined, size: 18),
                    label: Text(l10n.t('directions')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
