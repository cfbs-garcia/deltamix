package com.example.deltamix

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Address
import android.location.Geocoder
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val channelName = "deltamix/location"
    private val bgChannelName = "deltamix/background"
    private val locationReqCode = 4091
    private var pendingLocationResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "getCurrentLocation") {
                    ensurePermissionAndFetchLocation(result)
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, bgChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startOrUpdate" -> {
                        val title = call.argument<String>("title")
                            ?: "Deltamix • Monitoramento OBD-II Ativo"
                        val body = call.argument<String>("body")
                            ?: "Registrando telemetria e Sprint em segundo plano."
                        startOrUpdateBackgroundService(title, body)
                        result.success(true)
                    }
                    "stop" -> {
                        stopBackgroundService()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startOrUpdateBackgroundService(title: String, body: String) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                if (ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.POST_NOTIFICATIONS
                    ) != PackageManager.PERMISSION_GRANTED
                ) {
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                        4092
                    )
                }
            }
            val intent = Intent(this, ObdBackgroundService::class.java).apply {
                putExtra(ObdBackgroundService.EXTRA_TITLE, title)
                putExtra(ObdBackgroundService.EXTRA_BODY, body)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                try {
                    startForegroundService(intent)
                } catch (_: Exception) {
                    startService(intent)
                }
            } else {
                startService(intent)
            }
        } catch (_: Exception) {}
    }

    private fun stopBackgroundService() {
        try {
            val intent = Intent(this, ObdBackgroundService::class.java)
            stopService(intent)
        } catch (_: Exception) {}
    }

    private fun hasLocationPermission(): Boolean {
        val fine = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        return fine || coarse
    }

    private fun ensurePermissionAndFetchLocation(result: MethodChannel.Result) {
        if (hasLocationPermission()) {
            fetchCurrentLocation(result)
            return
        }

        pendingLocationResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            ),
            locationReqCode
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == locationReqCode) {
            val res = pendingLocationResult
            pendingLocationResult = null
            if (res != null) {
                val granted = grantResults.any { it == PackageManager.PERMISSION_GRANTED }
                if (granted || hasLocationPermission()) {
                    fetchCurrentLocation(res)
                } else {
                    res.error(
                        "PERMISSION_DENIED",
                        "Permissão de localização não foi concedida.",
                        null
                    )
                }
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

            val now = System.currentTimeMillis()
            var bestCached: Location? = null

            for (provider in providers) {
                try {
                    val loc = locationManager.getLastKnownLocation(provider)
                    if (loc != null) {
                        if (bestCached == null || isBetterLocation(loc, bestCached!!)) {
                            bestCached = loc
                        }
                    }
                } catch (_: Exception) {}
            }

            // Se já temos uma localização recente (< 90s) e precisa (<= 65m), usa na hora
            if (bestCached != null &&
                (now - bestCached!!.time) < 90_000L &&
                bestCached!!.accuracy <= 65f
            ) {
                result.success(formatLocation(bestCached!!))
                return
            }

            // Solicita atualização em tempo real do GPS e da Rede simultaneamente
            val activeProviders = listOf(
                LocationManager.GPS_PROVIDER,
                LocationManager.NETWORK_PROVIDER
            ).filter {
                try {
                    locationManager.isProviderEnabled(it)
                } catch (_: Exception) {
                    false
                }
            }

            if (activeProviders.isEmpty()) {
                if (bestCached != null) {
                    result.success(formatLocation(bestCached!!))
                } else {
                    result.error("DISABLED", "GPS do aparelho está desativado.", null)
                }
                return
            }

            var replied = false
            val handler = Handler(Looper.getMainLooper())
            val listeners = mutableListOf<LocationListener>()

            fun finishWith(loc: Location) {
                if (replied) return
                replied = true
                for (l in listeners) {
                    try {
                        locationManager.removeUpdates(l)
                    } catch (_: Exception) {}
                }
                result.success(formatLocation(loc))
            }

            for (provider in activeProviders) {
                val listener = object : LocationListener {
                    override fun onLocationChanged(location: Location) {
                        if (bestCached == null || isBetterLocation(location, bestCached!!)) {
                            bestCached = location
                        }
                        // Se obteve boa precisão (<= 80m) ou veio do GPS, responde imediatamente
                        if (location.accuracy <= 80f || provider == LocationManager.GPS_PROVIDER) {
                            finishWith(location)
                        }
                    }

                    @Deprecated("Deprecated in Java")
                    override fun onStatusChanged(p: String?, status: Int, extras: Bundle?) {}
                    override fun onProviderEnabled(p: String) {}
                    override fun onProviderDisabled(p: String) {}
                }
                listeners.add(listener)
                try {
                    locationManager.requestLocationUpdates(
                        provider,
                        0L,
                        0f,
                        listener,
                        Looper.getMainLooper()
                    )
                } catch (_: Exception) {}
            }

            handler.postDelayed({
                if (!replied) {
                    if (bestCached != null) {
                        finishWith(bestCached!!)
                    } else {
                        replied = true
                        for (l in listeners) {
                            try {
                                locationManager.removeUpdates(l)
                            } catch (_: Exception) {}
                        }
                        result.error("TIMEOUT", "Tempo esgotado ao buscar sinal de GPS.", null)
                    }
                }
            }, 4500L)
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }

    private fun isBetterLocation(loc: Location, currentBest: Location): Boolean {
        val timeDelta = loc.time - currentBest.time
        val isSignificantlyNewer = timeDelta > 60_000L
        val isSignificantlyOlder = timeDelta < -60_000L
        if (isSignificantlyNewer) return true
        if (isSignificantlyOlder) return false
        return loc.accuracy <= currentBest.accuracy
    }

    private fun formatLocation(loc: Location): Map<String, Any> {
        var addressText = ""
        try {
            val geocoder = Geocoder(this, Locale("pt", "BR"))
            @Suppress("DEPRECATION")
            val addresses = geocoder.getFromLocation(loc.latitude, loc.longitude, 5)
            if (!addresses.isNullOrEmpty()) {
                val streetAddr: Address = addresses.firstOrNull {
                    !it.thoroughfare.isNullOrBlank()
                } ?: addresses[0]

                val street = streetAddr.thoroughfare?.trim() ?: ""
                val rawNumber = streetAddr.subThoroughfare?.trim()
                    ?: streetAddr.featureName?.trim()?.takeIf {
                        it.isNotEmpty() && it.first().isDigit() && it.length <= 8
                    }
                    ?: ""
                val neighborhood = addresses.firstNotNullOfOrNull {
                    it.subLocality?.trim()?.takeIf { sub ->
                        sub.isNotEmpty() && !sub.equals(street, ignoreCase = true)
                    }
                } ?: ""
                val rawCity = addresses.firstNotNullOfOrNull {
                    it.locality?.trim()?.takeIf { c -> c.isNotEmpty() }
                } ?: addresses.firstNotNullOfOrNull {
                    it.subAdminArea?.trim()
                        ?.replace("Região Metropolitana de ", "")
                        ?.replace("Região Geográfica Imediata de ", "")
                        ?.takeIf { c -> c.isNotEmpty() }
                } ?: ""

                if (street.isNotEmpty()) {
                    val streetAndNum =
                        if (rawNumber.isNotEmpty()) "$street, Nº $rawNumber" else street
                    val tailParts = mutableListOf<String>()
                    if (neighborhood.isNotEmpty()) {
                        tailParts.add(neighborhood)
                    }
                    if (rawCity.isNotEmpty()) {
                        tailParts.add(rawCity)
                    }
                    addressText = if (tailParts.isNotEmpty()) {
                        "$streetAndNum - ${tailParts.joinToString(", ")}"
                    } else {
                        streetAndNum
                    }
                }

                // Se faltou rua ou bairro, verifica se a linha completa do Google Geocoder é mais rica
                if (street.isEmpty() || neighborhood.isEmpty()) {
                    val fullLine = streetAddr.getAddressLine(0)?.trim() ?: ""
                    if (fullLine.contains(",") && !fullLine.startsWith("Região", ignoreCase = true)) {
                        val cleaned = fullLine
                            .replace(Regex(",?\\s*\\d{5}-?\\d{3}"), "")
                            .replace(Regex(",?\\s*Brasil$", RegexOption.IGNORE_CASE), "")
                            .trim()
                        if (addressText.isEmpty() || (neighborhood.isEmpty() && cleaned.contains(" - "))) {
                            addressText = cleaned
                        }
                    }
                }
            }
        } catch (_: Exception) {}

        return mapOf(
            "lat" to loc.latitude,
            "lon" to loc.longitude,
            "address" to addressText
        )
    }
}
