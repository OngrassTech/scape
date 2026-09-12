package com.anoshione.scape

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            UPDATE_RELEASE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "openReleaseUrl") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val releaseUrl = call.argument<String>("url")?.trim()
            if (releaseUrl.isNullOrEmpty()) {
                result.success(false)
                return@setMethodCallHandler
            }

            result.success(openReleaseUrl(releaseUrl))
        }
    }

    private fun openReleaseUrl(releaseUrl: String): Boolean {
        return try {
            startActivity(
                Intent(Intent.ACTION_VIEW, Uri.parse(releaseUrl)).apply {
                    addCategory(Intent.CATEGORY_BROWSABLE)
                },
            )
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }

    companion object {
        private const val UPDATE_RELEASE_CHANNEL =
            "com.anoshione.scape/update_release"
    }
}
