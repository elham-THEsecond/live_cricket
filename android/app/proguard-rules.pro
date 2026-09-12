# WorkManager uses Room-generated database classes via reflection.
# R8 strips their constructors unless told to keep them.
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }
