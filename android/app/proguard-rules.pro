-keep class com.antonkarpenko.ffmpegkit.** { *; }

# Called from libbilirec.so via JNI GetStaticMethodID / //export.
-keep class org.bilirec.bilirec.StorageBridge { *; }
-keep class org.bilirec.bilirec.LogBridge { *; }