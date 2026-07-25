# R8 keep rules for the release build.
#
# flutter_gemma's MediaPipe/LiteRT layer references optional classes that are
# not on the classpath, which makes R8 abort. These -dontwarn lines (the exact
# ones R8 generated in missing_rules.txt) tell it to ignore the absent
# references, and the -keep lines protect the MediaPipe/LiteRT classes the
# native code reaches by reflection.

# --- exact missing references reported by R8 ---
-dontwarn com.google.auto.value.extension.memoized.Memoized
-dontwarn com.google.mediapipe.proto.CalculatorProfileProto$CalculatorProfile
-dontwarn com.google.mediapipe.proto.GraphTemplateProto$CalculatorGraphTemplate

# --- keep the on-device inference stack intact ---
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

# --- Vosk live-caption STT (vosk_flutter_2) reaches native via JNA reflection ---
# Without these, R8 would strip the JNA glue and Vosk would crash at runtime in
# the release build (only when the liveCaption flag is on).
-keep class com.sun.jna.** { *; }
-dontwarn com.sun.jna.**
-keep class org.vosk.** { *; }
-dontwarn org.vosk.**
