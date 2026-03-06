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
    description:
        "NYC's go-to surf beach. South-facing beach break with shifting sandbars. Best on S-SE swells with N winds. Works across most tides but favors mid. Picks up less swell than open-ocean beaches due to the NY Bight angle. Winter nor'easters and hurricane swells produce the best waves. Jetties at each end can focus swell and create wedgy peaks.",
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
    description:
        "Consistent beach break on Long Island's south shore. Multiple peaks along the boardwalk with sandbar-dependent quality. Best on S-SE swell with N-NW winds. Slightly more swell exposure than Rockaway. Handles all tides but low-to-mid tends to be punchier. Winter produces the most consistent surf; summer gets occasional hurricane swell.",
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
    description:
        "Classic NJ beach break facing east into the Atlantic. Picks up E and NE swells well. Best with W-NW offshore winds. Sandbars shift seasonally — jetties and groins create defined peaks. Works across all tides. Fall and winter bring the most consistent surf from nor'easters and offshore storms.",
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
    description:
        "Reliable NJ beach break with multiple jetty-defined peaks. East-facing, picks up E and NE swells. Best on W-NW winds. The jetties help organize the sandbars and create more consistent peaks than open beach breaks. Works on all tides but incoming mid tide often shapes up best. One of NJ's most popular breaks.",
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
    description:
        'Surf City USA — one of the most consistent breaks in SoCal. SW-facing beach break that picks up S, SW, and W swells year-round. Best with NE-E Santa Ana winds. The pier creates a reliable peak on its south side. Works on all tides. Summer brings consistent S swells; winter NW swells wrap in. Afternoon onshore sea breeze is common — dawn patrol is usually cleanest.',
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
    breakType: 'point',
    swellWindowWidth: 50,
    description:
        "World-class point break (Steamer Lane area). South-facing into Monterey Bay, naturally sheltered from prevailing NW winds — often offshore when everywhere else is blown out. Needs SW-S swell to really light up; NW swells can miss the point. Best on low-to-mid incoming tide. Long peeling rights when conditions align. Handles bigger swell well — winter is prime season with powerful groundswells.",
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
    minWaveEnergy: 8.0,
    windExposure: 0.9,
    description:
        'Heavy, powerful beach break — one of the best and most dangerous in California. West-facing, fully exposed to Pacific swells. Needs solid W-NW groundswell to turn on properly — small days are often unsurfable closeouts. Best with E winds (rare) or calm/light conditions. Tidal currents from the Golden Gate shift the sandbars constantly. Low-to-mid tide is usually best; high tide can swamp the bars. Winter is prime with overhead+ surf. Not for beginners.',
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
    minWaveEnergy: 0.5,
    description:
        'Gulf Coast beach break — surf is rare but rideable during cold fronts and tropical systems. West-facing into the Gulf of Mexico which has limited fetch, so waves are typically small and short-period. Best on W-SW wind swell from passing cold fronts (fall-spring). E offshore winds clean it up. A longboard or foamie spot most days. When tropical storms pass through the Gulf, it can produce surprisingly fun waves.',
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
    minWaveEnergy: 1.0,
    description:
        "Florida's most famous surf spot — home of Kelly Slater. East-facing beach break on the Space Coast. Picks up E and NE swells from Atlantic storms. Best with W-NW offshore winds. Gentle sandbars make it beginner-friendly on small days. Works on all tides. Fall and winter bring the most consistent swells from nor'easters. Hurricane season (Aug-Oct) can produce epic conditions. Typically short-period wind swell but occasionally gets groundswell.",
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
    minWaveEnergy: 1.2,
    description:
        "Northeast Florida beach break — slightly more swell exposure than Central FL due to the coastline angle. East-facing, picks up E and NE swells well. Best with W-SW offshore winds. The pier and jetties at Mayport create defined peaks. Sandbars can produce surprisingly hollow waves when conditions align. Fall through spring is the prime season with nor'easters providing the most consistent surf.",
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
    minWaveEnergy: 1.0,
    description:
        "South Florida beach break — less consistent than Central/North FL due to the Bahamas blocking most Atlantic swell. SE-facing, needs N-NE swell to wrap around or strong E swell to push through. Best with W-SW offshore winds. Cold front passages and nor'easters in winter provide the most surfable days. Hurricane season can produce rare epic sessions. South Beach around 1st Street and Haulover are popular peaks.",
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
