package com.example.deltamix

import android.annotation.SuppressLint
import android.content.Context
import android.location.Geocoder
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val channelName = "deltamix/location"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "getCurrentLocation") {
                    fetchCurrentLocation(result)
                } else {
                    result.notImplemented()
                }
            }
    }

    @SuppressLint("MissingPermission")
    private fun fetchCurrentLocation(result: MethodChannel.Result) {
        try {
            val locationManager =
                getSystemService(Context.LOCATION_SERVICE) as LocationManager
            val providers = listOf(
                LocationManager.GPS_PROVIDER,
                LocationManager.NETWORK_PROVIDER,
                LocationManager.PASSIVE_PROVIDER
            )

            var bestLocation: Location? = null
            for (provider in providers) {
                try {
                    if (locationManager.isProviderEnabled(provider)) {
                        val loc = locationManager.getLastKnownLocation(provider)
                        if (loc != null) {
                            if (bestLocation == null || loc.accuracy < bestLocation!!.accuracy) {
                                bestLocation = loc
                            }
                        }
                    }
                } catch (_: Exception) {}
            }

            if (bestLocation != null) {
                result.success(formatLocation(bestLocation!!))
                return
            }

            // Se não houver última localização em cache, solicita uma atualização rápida
            val activeProvider = providers.firstOrNull {
                try {
                    locationManager.isProviderEnabled(it)
                } catch (_: Exception) {
                    false
                }
            }

            if (activeProvider == null) {
                result.error("DISABLED", "GPS do aparelho está desativado.", null)
                return
            }

            var replied = false
            val handler = Handler(Looper.getMainLooper())
            val listener = object : LocationListener {
                override fun onLocationChanged(location: Location) {
                    if (!replied) {
                        replied = true
                        locationManager.removeUpdates(this)
                        result.success(formatLocation(location))
                    }
                }

                @Deprecated("Deprecated in Java")
                override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
                override fun onProviderEnabled(provider: String) {}
                override fun onProviderDisabled(provider: String) {}
            }

            locationManager.requestLocationUpdates(
                activeProvider,
                0L,
                0f,
                listener,
                Looper.getMainLooper()
            )

            handler.postDelayed({
                if (!replied) {
                    replied = true
                    locationManager.removeUpdates(listener)
                    result.error("TIMEOUT", "Tempo esgotado ao buscar sinal de GPS.", null)
                }
            }, 6000L)
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }

    private fun formatLocation(loc: Location): Map<String, Any> {
        var addressText = ""
        try {
            val geocoder = Geocoder(this, Locale("pt", "BR"))
            @Suppress("DEPRECATION")
            val addresses = geocoder.getFromLocation(loc.latitude, loc.longitude, 1)
            if (!addresses.isNullOrEmpty()) {
                val a = addresses[0]
                val street = a.thoroughfare ?: a.subLocality ?: ""
                val number = a.subThoroughfare ?: ""
                val neighborhood = a.subLocality ?: ""
                val city = a.locality ?: a.subAdminArea ?: ""
                val parts = mutableListOf<String>()
                if (street.isNotEmpty()) {
                    parts.add(if (number.isNotEmpty()) "$street, $number" else street)
                }
                if (neighborhood.isNotEmpty() && neighborhood != street) {
                    parts.add(neighborhood)
                }
                if (city.isNotEmpty()) {
                    parts.add(city)
                }
                addressText = parts.joinToString(" • ")
            }
        } catch (_: Exception) {}

        return mapOf(
            "lat" to loc.latitude,
            "lon" to loc.longitude,
            "address" to addressText
        )
    }
}
