package com.minimallabs.vsync

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "vsync/launcher_icon"

    // Launcher icon variants, backed by activity-alias enable states in the
    // manifest (exactly one alias enabled at a time).
    private val aliasSuffixes = linkedMapOf(
        "default" to "MainActivityDefault",
        "classy" to "MainActivityClassy",
        "glassy" to "MainActivityGlassy",
        "rainbow" to "MainActivityRainbow",
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getIcon" -> result.success(currentIcon())
                    "setIcon" -> {
                        val name = call.argument<String>("name")
                        if (name == null || !aliasSuffixes.containsKey(name)) {
                            result.error("bad_icon", "Unknown icon variant: $name", null)
                        } else {
                            setIcon(name)
                            result.success(name)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun currentIcon(): String {
        for ((name, suffix) in aliasSuffixes) {
            val component = ComponentName(this, "$packageName.$suffix")
            val state = packageManager.getComponentEnabledSetting(component)
            val isEnabled = when (state) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
                // Manifest default = only the "default" alias is enabled.
                PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> name == "default"
                else -> false
            }
            if (isEnabled) return name
        }
        return "default"
    }

    private fun setIcon(name: String) {
        for ((key, suffix) in aliasSuffixes) {
            val component = ComponentName(this, "$packageName.$suffix")
            val newState =
                if (key == name) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                else PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            packageManager.setComponentEnabledSetting(
                component,
                newState,
                PackageManager.DONT_KILL_APP,
            )
        }
    }
}
