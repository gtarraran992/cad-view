#include <jni.h>
#include <string>
#include <android/log.h>

#define LOG_TAG "CadNative"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_cad_1view_CadNative_convertDwgToDxf(
        JNIEnv* env,
        jobject /* this */,
        jstring inputPath,
        jstring outputPath) {

    const char* input = env->GetStringUTFChars(inputPath, nullptr);
    const char* output = env->GetStringUTFChars(outputPath, nullptr);

    LOGI("Converting: %s -> %s", input, output);

    // Per ora ritorna OK — aggiungeremo libdxfrw dopo
    std::string result = "OK";

    env->ReleaseStringUTFChars(inputPath, input);
    env->ReleaseStringUTFChars(outputPath, output);

    return env->NewStringUTF(result.c_str());
}