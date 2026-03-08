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
    id: 'montauk',
    name: 'Ditch Plains, Montauk, NY',
    lat: 41.0370,
    lon: -71.8870,
    timezone: 'America/New_York',
    beachFacing: 180,
    offshoreMin: 315,
    offshoreMax: 45,
    onshoreMin: 135,
    onshoreMax: 225,
    noaaStation: '8510560',
    description:
        "Perhaps the most consistent spot on Long Island. South-facing boulder-studded beach break with reliable peaks that work across a wide range of swells. Best on S-SE swell with N winds. Works on all tides. Hurricane swells and nor'easters produce the best conditions. The boulders create wedgy, defined peaks unlike typical sand-bottom breaks. A Montauk institution and weekend magnet for NYC surfers.",
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
  Location(
    id: 'manasquan',
    name: 'Manasquan Inlet, NJ',
    lat: 40.1058,
    lon: -74.0326,
    timezone: 'America/New_York',
    beachFacing: 90,
    offshoreMin: 225,
    offshoreMax: 315,
    onshoreMin: 45,
    onshoreMax: 135,
    noaaStation: '8531680',
    tideSensitivity: 0.8,
    description:
        "Premier NJ inlet break with rock jetties creating powerful, hollow waves. East-facing, picks up E and NE swells. The south jetty creates a consistent peak on big swells. Very tide-sensitive — best on low-to-mid incoming tide when the sandbars align with the jetty. Best with W-NW offshore winds. Winter nor'easters produce the best conditions. One of the most respected waves on the entire East Coast.",
  ),
  // --- California ---
  Location(
    id: 'huntington',
    name: 'Huntington Pier, CA',
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
    name: 'Steamer Lane, Santa Cruz, CA',
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
  Location(
    id: 'malibu',
    name: 'Malibu (Surfrider), CA',
    lat: 34.0364,
    lon: -118.6800,
    timezone: 'America/Los_Angeles',
    beachFacing: 190,
    offshoreMin: 315,
    offshoreMax: 45,
    onshoreMin: 135,
    onshoreMax: 225,
    noaaStation: '9410580',
    breakType: 'point',
    swellWindowWidth: 45,
    description:
        'Perhaps the most iconic wave in California. A perfect right-hand point break at Surfrider Beach. Needs solid S-SW swell to connect all three points — First Point, Second Point, and Third Point. Best with light N-NE Santa Ana winds. Low-to-mid tide is optimal. Summer S swells produce the classic long walls. Can be extremely crowded but the wave quality is undeniable.',
  ),
  Location(
    id: 'trestles',
    name: 'Lower Trestles, CA',
    lat: 33.3822,
    lon: -117.5889,
    timezone: 'America/Los_Angeles',
    beachFacing: 230,
    offshoreMin: 0,
    offshoreMax: 90,
    onshoreMin: 180,
    onshoreMax: 270,
    noaaStation: '9410580',
    breakType: 'point',
    swellWindowWidth: 55,
    description:
        'World-class cobblestone point break — the most high-performance wave in Southern California. SW-facing, best on S-SW groundswell with light NE winds. Both left and right peaks offer steep, rippable walls. Works best on medium tide. The walk-in from the trailhead keeps crowds somewhat manageable. Year-round surf with prime season summer through fall on S swells. A WSL Championship Tour stop.',
  ),
  Location(
    id: 'rincon',
    name: 'Rincon Point, CA',
    lat: 34.3736,
    lon: -119.4768,
    timezone: 'America/Los_Angeles',
    beachFacing: 180,
    offshoreMin: 315,
    offshoreMax: 45,
    onshoreMin: 135,
    onshoreMax: 225,
    noaaStation: '9411340',
    breakType: 'point',
    swellWindowWidth: 45,
    description:
        'The Queen of the Coast — a world-famous right-hand point break on the Ventura-Santa Barbara county line. Needs strong W-NW winter swell to wrap around the point and connect all sections: Indicator, Rivermouth, and the Cove. Best with light N-NE winds. Low-to-mid tide is optimal. Prime season is winter (Nov-Mar) with large NW groundswells. Can produce 200+ yard rides on the best days.',
  ),
  Location(
    id: 'pleasurepoint',
    name: 'Pleasure Point, Santa Cruz, CA',
    lat: 36.9613,
    lon: -121.9732,
    timezone: 'America/Los_Angeles',
    beachFacing: 170,
    offshoreMin: 315,
    offshoreMax: 45,
    onshoreMin: 135,
    onshoreMax: 225,
    noaaStation: '9413745',
    breakType: 'point',
    swellWindowWidth: 60,
    description:
        'Series of reef and point breaks offering consistent, quality waves for all levels. SSE-facing, catches swell from more directions than nearby Steamer Lane — both NW and S swells work. Multiple peaks from 38th Ave to Sewer Peak provide options from mellow longboard waves to high-performance shortboard sections. Best on NW-N winds. Handles all tides. Year-round surf with winter producing the most power. A true everyday California surf spot.',
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
    id: 'newsmyrna',
    name: 'New Smyrna Beach, FL',
    lat: 29.0258,
    lon: -80.9270,
    timezone: 'America/New_York',
    beachFacing: 90,
    offshoreMin: 225,
    offshoreMax: 315,
    onshoreMin: 45,
    onshoreMax: 135,
    noaaStation: '8721120',
    minWaveEnergy: 1.0,
    description:
        "Florida's most consistent surf spot and the East Coast's wave magnet. East-facing beach and inlet breaks near Ponce Inlet. The jetties create wedgy, powerful peaks that transform ordinary swells into quality waves. Best with W-NW offshore winds. Works on all tides but incoming mid is optimal. Year-round surf — nor'easters in fall/winter, hurricane swells in summer/fall. Beginner-friendly on the open beach; the inlet peaks reward experienced surfers.",
  ),
  Location(
    id: 'sebastian',
    name: 'Sebastian Inlet, FL',
    lat: 27.8617,
    lon: -80.4484,
    timezone: 'America/New_York',
    beachFacing: 80,
    offshoreMin: 215,
    offshoreMax: 305,
    onshoreMin: 35,
    onshoreMax: 125,
    noaaStation: '8721604',
    minWaveEnergy: 1.5,
    tideSensitivity: 0.9,
    description:
        "The epicenter of East Coast competitive surfing. Jetty-enhanced inlet break producing the most powerful, hollow waves in Florida. The north jetty's First Peak and Monster Hole are legendary. ENE-facing, best on NE-E swells with W-NW winds. Extremely tide-sensitive — incoming tide is critical. Needs moderate swell to break properly. Winter nor'easters and hurricane swells produce world-class conditions.",
  ),
  Location(
    id: 'jacksonville',
    name: 'Jax Beach, FL',
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
    id: 'staugustine',
    name: 'St. Augustine Beach, FL',
    lat: 29.8564,
    lon: -81.2652,
    timezone: 'America/New_York',
    beachFacing: 90,
    offshoreMin: 225,
    offshoreMax: 315,
    onshoreMin: 45,
    onshoreMax: 135,
    noaaStation: '8720218',
    minWaveEnergy: 1.0,
    description:
        "Historic Northeast Florida beach break. East-facing, picks up E and NE swells. Multiple peaks along the coast — the pier creates defined breaks and the Blow Hole sandbar section can produce surprisingly hollow waves. Best with W-NW offshore winds. Works on all tides. Winter nor'easters and fall hurricane swells produce the best conditions. Slightly more sheltered than Jax Beach to the north.",
  ),
  Location(
    id: 'jupiter',
    name: 'Jupiter Inlet, FL',
    lat: 26.9445,
    lon: -80.0729,
    timezone: 'America/New_York',
    beachFacing: 90,
    offshoreMin: 225,
    offshoreMax: 315,
    onshoreMin: 45,
    onshoreMax: 135,
    noaaStation: '8722670',
    minWaveEnergy: 1.0,
    tideSensitivity: 0.7,
    description:
        "South Florida's best inlet break. East-facing with jetties creating a consistent peak at the inlet mouth. More swell exposure than South Beach thanks to the coastline angle and less Bahamas shadow. Best with W-NW offshore winds. Tide-sensitive — incoming mid tide shapes up best. Winter nor'easters and cold fronts produce the most consistent surf. Can handle overhead+ conditions when other South FL spots close out.",
  ),
  Location(
    id: 'miami',
    name: 'South Beach, Miami, FL',
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

/// Find all locations within a radius (km) of given coordinates, sorted by distance
List<({Location loc, double distance})> findLocationsWithinRadius(
    double lat, double lon,
    {double radiusKm = 80}) {
  final results = <({Location loc, double distance})>[];
  for (final loc in locations) {
    final d = haversine(lat, lon, loc.lat, loc.lon);
    if (d <= radiusKm) {
      results.add((loc: loc, distance: d));
    }
  }
  results.sort((a, b) => a.distance.compareTo(b.distance));
  return results;
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
