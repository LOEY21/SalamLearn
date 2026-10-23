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
                when (call.method) {
                    "isCasting" -> result.success(isCasting())
                    "stopCasting" -> {
                        stopCasting()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// Selecting the phone's own route drops a Miracast/Smart View mirror
    /// (Android lets any app disconnect a wifi display). Chromecast mirroring
    /// can't be stopped by another app; the Dart side falls back to the picker.
    private fun stopCasting() {
        val router = getSystemService(Context.MEDIA_ROUTER_SERVICE) as MediaRouter
        router.selectRoute(MediaRouter.ROUTE_TYPE_LIVE_VIDEO, router.defaultRoute)
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
