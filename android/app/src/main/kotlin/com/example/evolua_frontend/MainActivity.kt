package com.example.evolua_frontend

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var store: PrivateStoreChannel? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (BuildConfig.EVP_PRIVATE_CORE_ENABLED) {
            store = PrivateStoreChannel(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        }
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        store?.detach()
        store = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
