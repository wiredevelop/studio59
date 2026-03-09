package pt.studio59.app

import android.content.ContentValues
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.view.WindowManager
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity()
{
    private val channelName = "studio59/screen_record"
    private val galleryChannelName = "studio59/gallery"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        if (enabled) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, galleryChannelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "saveToGallery") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val path = call.argument<String>("path")
                val name = call.argument<String>("name") ?: "photo.jpg"
                if (path.isNullOrBlank()) {
                    result.error("bad_args", "path is required", null)
                    return@setMethodCallHandler
                }

                try {
                    val srcFile = File(path)
                    if (!srcFile.exists()) {
                        result.error("not_found", "file not found", null)
                        return@setMethodCallHandler
                    }

                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                        val cameraDir = File(
                            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM),
                            "Camera"
                        )
                        if (!cameraDir.exists()) cameraDir.mkdirs()
                        val destFile = File(cameraDir, name)
                        FileInputStream(srcFile).use { input ->
                            FileOutputStream(destFile).use { output ->
                                input.copyTo(output)
                            }
                        }
                        MediaScannerConnection.scanFile(
                            applicationContext,
                            arrayOf(destFile.absolutePath),
                            arrayOf("image/jpeg"),
                            null
                        )
                        result.success(true)
                        return@setMethodCallHandler
                    }

                    val resolver = applicationContext.contentResolver
                    val values = ContentValues().apply {
                        put(MediaStore.Images.Media.DISPLAY_NAME, name)
                        put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                        put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_DCIM + "/Camera")
                        put(MediaStore.Images.Media.IS_PENDING, 1)
                    }

                    val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                    if (uri == null) {
                        result.error("insert_failed", "could not create media store entry", null)
                        return@setMethodCallHandler
                    }

                    resolver.openOutputStream(uri).use { out ->
                        FileInputStream(srcFile).use { input ->
                            if (out != null) input.copyTo(out)
                        }
                    }

                    values.clear()
                    values.put(MediaStore.Images.Media.IS_PENDING, 0)
                    resolver.update(uri, values, null, null)

                    result.success(true)
                } catch (e: Exception) {
                    result.error("save_failed", e.message, null)
                }
            }
    }
}
