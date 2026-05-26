#include <jni.h>
#include <string>
#include <android/log.h>
#include "libdxfrw/src/libdxfrw.h"
#include "libdxfrw/dwg2dxf/dx_iface.h"
#include "libdxfrw/dwg2dxf/dx_data.h"

#define LOG_TAG "CadNative"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_cad_1view_CadNative_convertDwgToDxf(
        JNIEnv* env,
        jobject,
        jstring inputPath,
        jstring outputPath) {

    const char* input = env->GetStringUTFChars(inputPath, nullptr);
    const char* output = env->GetStringUTFChars(outputPath, nullptr);

    LOGI("Converting: %s -> %s", input, output);

    // Verifica file
    FILE* f = fopen(input, "rb");
    if (!f) {
        env->ReleaseStringUTFChars(inputPath, input);
        env->ReleaseStringUTFChars(outputPath, output);
        return env->NewStringUTF("ERROR_FILE_NOT_FOUND");
    }
    char version[7] = {0};
    fread(version, 1, 6, f);
    fclose(f);
    LOGI("Versione DWG: %s", version);

    // Conversione DWG -> DXF usando dx_iface
    dx_data data;
    dx_iface iface;

    bool readOk = iface.fileImport(std::string(input), &data, false);
    LOGI("Lettura: %s", readOk ? "OK" : "ERRORE");

    if (!readOk) {
        env->ReleaseStringUTFChars(inputPath, input);
        env->ReleaseStringUTFChars(outputPath, output);
        return env->NewStringUTF("ERROR_READ");
    }

    bool writeOk = iface.fileExport(std::string(output), DRW::AC1015, false, &data, false);
    LOGI("Scrittura: %s", writeOk ? "OK" : "ERRORE");

    env->ReleaseStringUTFChars(inputPath, input);
    env->ReleaseStringUTFChars(outputPath, output);

    return env->NewStringUTF(writeOk ? "OK" : "ERROR_WRITE");
}