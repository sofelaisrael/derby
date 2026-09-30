package uk.co.derbybins.derby_bins

import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "openBatterySettings" -> {
                        try {
                            startActivity(
                                Intent(
                                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                    Uri.parse("package:$packageName")
                                )
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            openBatterySettingsFallback(result, e)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun openBatterySettingsFallback(
        result: MethodChannel.Result,
        firstError: Exception
    ) {
        val errors = StringBuilder(firstError.message)
        val fallbacks = listOf(
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName")
            ),
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
        )
        for (intent in fallbacks) {
            try {
                startActivity(intent)
                result.success(true)
                return
            } catch (e: Exception) {
                errors.append("; ").append(e.message)
            }
        }
        result.error("battery_settings_failed", errors.toString(), null)
    }

    companion object {
        private const val CHANNEL = "derbybins/battery"
    }
}
