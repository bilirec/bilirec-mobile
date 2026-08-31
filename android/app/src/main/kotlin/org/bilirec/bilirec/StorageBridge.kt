package org.bilirec.bilirec

import android.content.Context
import android.database.Cursor
import android.media.MediaScannerConnection
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

object StorageBridge {
    private const val TAG = "StorageBridge"
    private const val MIME_DIR = "vnd.android.document/directory"

    @Volatile
    private var appContext: Context? = null

    init {
        try {
            System.loadLibrary("bilirec")
            nativeRegister()
        } catch (e: UnsatisfiedLinkError) {
            Log.w(TAG, "libbilirec not loaded yet; JNI register will retry from Go", e)
        }
    }

    @JvmStatic
    private external fun nativeRegister()

    @JvmStatic
    fun install(context: Context) {
        appContext = context.applicationContext
    }

    // JNI: CallStaticObjectMethod(..., "listDir", "(Ljava/lang/String;)Ljava/lang/String;")
    @JvmStatic
    fun listDir(path: String): String {
        return try {
            val ctx = context() ?: return "[]"
            val dir = File(path).canonicalFile
            val items = LinkedHashMap<String, JSONObject>()
            queryByRelativePath(ctx, dir, items)
            queryByAbsolutePath(ctx, dir, items)
            val out = JSONArray()
            for (row in items.values) {
                out.put(row)
            }
            out.toString()
        } catch (e: Exception) {
            Log.w(TAG, "listDir failed for $path", e)
            "[]"
        }
    }

    // JNI: CallStaticVoidMethod(..., "notifyFileChanged", "(Ljava/lang/String;)V")
    @JvmStatic
    fun notifyFileChanged(path: String) {
        if (path.isEmpty()) return
        val ctx = context() ?: return
        try {
            MediaScannerConnection.scanFile(ctx, arrayOf(path), null, null)
        } catch (e: Exception) {
            Log.w(TAG, "notifyFileChanged failed for $path", e)
        }
    }

    private fun context(): Context? {
        appContext?.let { return it }
        return try {
            val at = Class.forName("android.app.ActivityThread")
            val app = at.getMethod("currentApplication").invoke(null) as? Context
            app?.applicationContext?.also { appContext = it }
        } catch (e: Exception) {
            Log.w(TAG, "failed to resolve Application context", e)
            null
        }
    }

    private fun queryByRelativePath(
        ctx: Context,
        dir: File,
        items: MutableMap<String, JSONObject>,
    ) {
        val relative = relativePathOf(dir) ?: return
        val uri = MediaStore.Files.getContentUri("external")
        val projection = listProjection()
        val selection = "${MediaStore.MediaColumns.RELATIVE_PATH}=?"
        ctx.contentResolver.query(uri, projection, selection, arrayOf(relative), null)?.use { cursor ->
            val nameIdx = cursor.getColumnIndex(MediaStore.MediaColumns.DISPLAY_NAME)
            val sizeIdx = cursor.getColumnIndex(MediaStore.MediaColumns.SIZE)
            val dataIdx = cursor.getColumnIndex(MediaStore.MediaColumns.DATA)
            val mimeIdx = cursor.getColumnIndex(MediaStore.MediaColumns.MIME_TYPE)
            while (cursor.moveToNext()) {
                val data = cursorString(cursor, dataIdx)
                if (!data.isNullOrEmpty() && !isDirectChild(dir, data)) {
                    continue
                }
                val name = entryName(cursorString(cursor, nameIdx), data) ?: continue
                addItem(items, name, isDirectoryMime(cursorString(cursor, mimeIdx)), cursorLong(cursor, sizeIdx))
            }
        }
    }

    private fun queryByAbsolutePath(
        ctx: Context,
        dir: File,
        items: MutableMap<String, JSONObject>,
    ) {
        val uri = MediaStore.Files.getContentUri("external")
        val projection = listProjection()
        val prefix = dir.path.trimEnd('/') + "/"
        val selection = "${MediaStore.MediaColumns.DATA} LIKE ? ESCAPE '\\'"
        val args = arrayOf(escapeLike(prefix) + "%")
        ctx.contentResolver.query(uri, projection, selection, args, null)?.use { cursor ->
            val nameIdx = cursor.getColumnIndex(MediaStore.MediaColumns.DISPLAY_NAME)
            val sizeIdx = cursor.getColumnIndex(MediaStore.MediaColumns.SIZE)
            val dataIdx = cursor.getColumnIndex(MediaStore.MediaColumns.DATA)
            val mimeIdx = cursor.getColumnIndex(MediaStore.MediaColumns.MIME_TYPE)
            while (cursor.moveToNext()) {
                val data = cursorString(cursor, dataIdx) ?: continue
                if (!isDirectChild(dir, data)) {
                    continue
                }
                val name = entryName(cursorString(cursor, nameIdx), data) ?: continue
                addItem(items, name, isDirectoryMime(cursorString(cursor, mimeIdx)), cursorLong(cursor, sizeIdx))
            }
        }
    }

    private fun listProjection(): Array<String> = arrayOf(
        MediaStore.MediaColumns.DISPLAY_NAME,
        MediaStore.MediaColumns.SIZE,
        MediaStore.MediaColumns.DATA,
        MediaStore.MediaColumns.RELATIVE_PATH,
        MediaStore.MediaColumns.MIME_TYPE,
    )

    private fun addItem(items: MutableMap<String, JSONObject>, name: String, isDir: Boolean, size: Long) {
        if (name.isEmpty() || name == "." || name == "..") return
        items.putIfAbsent(
            name,
            JSONObject().apply {
                put("name", name)
                put("isDir", isDir)
                put("size", size)
            },
        )
    }

    private fun isDirectChild(dir: File, data: String): Boolean {
        val parent = File(data).parentFile ?: return false
        return parent == dir || parent.canonicalFile == dir
    }

    private fun entryName(displayName: String?, data: String?): String? {
        if (!displayName.isNullOrEmpty()) return displayName
        if (data.isNullOrEmpty()) return null
        return File(data).name.ifEmpty { null }
    }

    private fun isDirectoryMime(mime: String?): Boolean {
        return mime == MIME_DIR || mime == "resource/folder"
    }

    private fun relativePathOf(dir: File): String? {
        val root = Environment.getExternalStorageDirectory().canonicalFile
        return try {
            val rel = dir.relativeTo(root).invariantSeparatorsPath.trim('/')
            if (rel.isEmpty()) "" else "$rel/"
        } catch (_: IllegalArgumentException) {
            null
        }
    }

    private fun escapeLike(value: String): String {
        return value
            .replace("\\", "\\\\")
            .replace("%", "\\%")
            .replace("_", "\\_")
    }

    private fun cursorString(cursor: Cursor, index: Int): String? {
        if (index < 0 || cursor.isNull(index)) return null
        return cursor.getString(index)
    }

    private fun cursorLong(cursor: Cursor, index: Int): Long {
        if (index < 0 || cursor.isNull(index)) return 0L
        return cursor.getLong(index)
    }
}
