/// Location definitions — direct port of utils/locations.js
import 'dart:math';
import '../models/location.dart';

const locations = <Location>[
  // --- New York / New Jersey ---
  Location(
    id: 'rockaway',
    name: 'Rockaway Beach, NY',
    lat: 40.5835,
    lon: -73.8155,
    timezone: 'America/New_York',
    beachFacing: 180,
    offshoreMin: 315,
    offshoreMax: 45,
    onshoreMin: 135,
    onshoreMax: 225,
    noaaStation: '8517137',
  ),
  Location(
    id: 'longbeach',
    name: 'Long Beach, NY',
    lat: 40.5883,
    lon: -73.6557,
    timezone: 'America/New_York',
    beachFacing: 180,
    offshoreMin: 315,
    offshoreMax: 45,
    onshoreMin: 135,
    onshoreMax: 225,
    noaaStation: '8516663',
  ),
  Location(
    id: 'asbury',
    name: 'Asbury Park, NJ',
    lat: 40.2168,
    lon: -73.9967,
    timezone: 'America/New_York',
    beachFacing: 90,
    offshoreMin: 225,
    offshoreMax: 315,
    onshoreMin: 45,
    onshoreMax: 135,
    noaaStation: '8531680',
  ),
  Location(
    id: 'belmar',
    name: 'Belmar, NJ',
    lat: 40.1776,
    lon: -74.0148,
    timezone: 'America/New_York',
    beachFacing: 90,
    offshoreMin: 225,
    offshoreMax: 315,
    onshoreMin: 45,
    onshoreMax: 135,
    noaaStation: '8531680',
  ),
  // --- California ---
  Location(
    id: 'huntington',
    name: 'Huntington Beach, CA',
    lat: 33.6553,
    lon: -117.9988,
    timezone: 'America/Los_Angeles',
    beachFacing: 225,
    offshoreMin: 0,
    offshoreMax: 90,
    onshoreMin: 180,
    onshoreMax: 270,
    noaaStation: '9410580',
  ),
  Location(
    id: 'santacruz',
    name: 'Santa Cruz, CA',
    lat: 36.9624,
    lon: -122.0235,
    timezone: 'America/Los_Angeles',
    beachFacing: 180,
    offshoreMin: 315,
    offshoreMax: 45,
    onshoreMin: 135,
    onshoreMax: 225,
    noaaStation: '9413745',
  ),
  Location(
    id: 'oceanbeach',
    name: 'Ocean Beach, SF, CA',
    lat: 37.7594,
    lon: -122.5107,
    timezone: 'America/Los_Angeles',
    beachFacing: 270,
    offshoreMin: 45,
    offshoreMax: 135,
    onshoreMin: 225,
    onshoreMax: 315,
    noaaStation: '9414290',
  ),
  // --- Florida ---
  Location(
    id: 'clearwater',
    name: 'Clearwater Beach, FL',
    lat: 27.9775,
    lon: -82.8271,
    timezone: 'America/New_York',
    beachFacing: 270,
    offshoreMin: 45,
    offshoreMax: 135,
    onshoreMin: 225,
    onshoreMax: 315,
    noaaStation: '8726724',
  ),
  Location(
    id: 'cocoa',
    name: 'Cocoa Beach, FL',
    lat: 28.3200,
    lon: -80.6076,
    timezone: 'America/New_York',
    beachFacing: 90,
    offshoreMin: 225,
    offshoreMax: 315,
    onshoreMin: 45,
    onshoreMax: 135,
    noaaStation: '8721604',
  ),
  Location(
    id: 'jacksonville',
    name: 'Jacksonville Beach, FL',
    lat: 30.2866,
    lon: -81.3930,
    timezone: 'America/New_York',
    beachFacing: 90,
    offshoreMin: 225,
    offshoreMax: 315,
    onshoreMin: 45,
    onshoreMax: 135,
    noaaStation: '8720218',
  ),
  Location(
    id: 'miami',
    name: 'Miami Beach, FL',
    lat: 25.7907,
    lon: -80.1300,
    timezone: 'America/New_York',
    beachFacing: 120,
    offshoreMin: 210,
    offshoreMax: 300,
    onshoreMin: 30,
    onshoreMax: 120,
    noaaStation: '8723214',
  ),
];

Location getLocationById(String id) {
  return locations.firstWhere(
    (l) => l.id == id,
    orElse: () => locations[0],
  );
}

Location getDefaultLocation() => locations[0];

/// Haversine distance in km between two lat/lon points
double haversine(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLon = (lon2 - lon1) * pi / 180;
  final a = pow(sin(dLat / 2), 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * pow(sin(dLon / 2), 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

/// Find the nearest location to given coordinates
Location findNearestLocation(double lat, double lon) {
  var nearest = locations[0];
  var minDist = double.infinity;
  for (final loc in locations) {
    final d = haversine(lat, lon, loc.lat, loc.lon);
    if (d < minDist) {
      minDist = d;
      nearest = loc;
    }
  }
  return nearest;
}
