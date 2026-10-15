package com.example.prjct

import android.content.Context
import android.hardware.display.DisplayManager
import android.media.MediaRouter
import android.view.Display
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "salamlearn/cast")
            .setMethodCallHandler { call, result ->
                if (call.method == "isCasting") result.success(isCasting())
                else result.notImplemented()
            }
    }

    /// True while the screen is mirrored to a TV/projector: the mirror shows
    /// up as a second display, or as the selected live-video media route.
    private fun isCasting(): Boolean {
        val displays = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        if (displays.displays.any { it.displayId != Display.DEFAULT_DISPLAY }) return true
        val router = getSystemService(Context.MEDIA_ROUTER_SERVICE) as MediaRouter
        val route = router.getSelectedRoute(MediaRouter.ROUTE_TYPE_LIVE_VIDEO)
        return route != null && route != router.defaultRoute && route.presentationDisplay != null
    }
}
