#include <jni.h>
#include <string>
#include <fstream>
#include <sstream>
#include <iomanip>
#include <map>
#include <android/log.h>
#include "libdxfrw/src/libdxfrw.h"
#include "libdxfrw/src/drw_interface.h"
#include "libdxfrw/dwg2dxf/dx_iface.h"
#include "libdxfrw/dwg2dxf/dx_data.h"

#define LOG_TAG "CadNative"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// ─────────────────────────────────────────────────────────────────────────────
// ACI → RGB
// ─────────────────────────────────────────────────────────────────────────────

static const uint32_t ACI[256] = {
        0xFFFFFF,0xFF0000,0xFFFF00,0x00FF00,0x00FFFF,0x0000FF,0xFF00FF,0xFFFFFF,
        0x808080,0xC0C0C0,
        // 10-109 (partial, rest white)
        0xFF0000,0xFF7F7F,0xBD0000,0xBD5E5E,0x810000,0x81413F,0xFF3F00,0xFF9F7F,0xBD2E00,0xBD7560,
        0xFF7F00,0xFFBF7F,0xBD5E00,0xBD8D5E,0xFFBF00,0xFFDF7F,0xBD8D00,0xBDA45E,0xFFFF00,0xFFFF7F,
        0xBDBD00,0xBDBD5E,0x7FFF00,0xBFFF7F,0x4FBD00,0x90BD5E,0x325F00,0x5E7F3E,0x007F00,0x4FBF4F,
        0x00BF00,0x4FDF4F,0x007F3F,0x00BF5E,0x003F1F,0x00813F,0x00FF7F,0x7FFFBF,0x00FF3F,0x7FFF9F,
        0x00BF2F,0x4FBF7F,0x007F1F,0x00814F,0x00FFFF,0x7FFFFF,0x00BFBF,0x4FBFBF,0x007F7F,0x3F8181,
        0x003F7F,0x3F6F9F,0x00007F,0x3F3F9F,0x00003F,0x27274F,0x0000FF,0x7F7FFF,0x003FFF,0x7F9FFF,
        0x001FBF,0x4F6FBF,0x00007F,0x3F3F7F,0x3F00FF,0x9F7FFF,0x1F00BF,0x6F4FBF,0x0F007F,0x4F3F7F,
        0x7F00FF,0xBF7FFF,0x5F00BF,0x8F4FBF,0x3F007F,0x6F3F7F,0xFF00FF,0xFF7FFF,0xBF00BF,0xBF4FBF,
        0x7F007F,0x7F3F7F,0xFF007F,0xFF7FBF,0xBF005E,0xBF4F8E,0x7F003E,0x7F3F5E,0xFF003F,0xFF7F9F,
        0xBF002E,0xBF4F6F,0x7F001E,0x7F3F4F,0xFF0000,0xFF7F7F,0xBF0000,0xBF4F4F,0x7F0000,0x7F3F3F,
        // 110-250: white
        0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,
        0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,
        0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,
        0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,
        0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,
        0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,
        0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,
        0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,
        0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,
        0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,
        0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,
        0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,
        0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,0xFFFFFF,
        // 250-255: greys
        0x333333,0x4C4C4C,0x666666,0x808080,0x999999,0xFFFFFF,
};

static std::string aciHex(int a) {
    if (a < 0 || a > 255) return "#FFFFFF";
    char b[8]; snprintf(b, sizeof(b), "#%06X", ACI[a]); return b;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

static std::string esc(const std::string& s) {
    std::string o; o.reserve(s.size()+4);
    for (unsigned char c : s) {
        if      (c=='"')  o+="\\\"";
        else if (c=='\\') o+="\\\\";
        else if (c=='\n') o+="\\n";
        else if (c=='\r') o+="\\r";
        else if (c=='\t') o+="\\t";
        else if (c<0x20){ char b[8]; snprintf(b,sizeof(b),"\\u%04x",c); o+=b; }
        else              o+=(char)c;
    }
    return o;
}

static std::string fd(double v) {
    std::ostringstream ss; ss<<std::fixed<<std::setprecision(4)<<v; return ss.str();
}

// ─────────────────────────────────────────────────────────────────────────────
// Pass 1: raccoglie solo i layer e i loro colori ACI
// ─────────────────────────────────────────────────────────────────────────────

class LayerCollector : public DRW_Interface {
public:
    std::map<std::string,int> colors; // layer name → ACI (positive=on, stored abs)

    virtual void addLayer(const DRW_Layer& l) override {
        int c = (l.color < 0) ? -l.color : l.color;
        colors[l.name] = c;
    }

    // ── all pure virtual no-op ───────────────────────────────────────────────
    virtual void addHeader(const DRW_Header*) override {}
    virtual void addLType(const DRW_LType&) override {}
    virtual void addDimStyle(const DRW_Dimstyle&) override {}
    virtual void addVport(const DRW_Vport&) override {}
    virtual void addTextStyle(const DRW_Textstyle&) override {}
    virtual void addAppId(const DRW_AppId&) override {}
    virtual void addBlock(const DRW_Block&) override {}
    virtual void setBlock(const int) override {}
    virtual void endBlock() override {}
    virtual void addPoint(const DRW_Point&) override {}
    virtual void addLine(const DRW_Line&) override {}
    virtual void addRay(const DRW_Ray&) override {}
    virtual void addXline(const DRW_Xline&) override {}
    virtual void addArc(const DRW_Arc&) override {}
    virtual void addCircle(const DRW_Circle&) override {}
    virtual void addEllipse(const DRW_Ellipse&) override {}
    virtual void addLWPolyline(const DRW_LWPolyline&) override {}
    virtual void addPolyline(const DRW_Polyline&) override {}
    virtual void addSpline(const DRW_Spline*) override {}
    virtual void addKnot(const DRW_Entity&) override {}
    virtual void addInsert(const DRW_Insert&) override {}
    virtual void addTrace(const DRW_Trace&) override {}
    virtual void add3dFace(const DRW_3Dface&) override {}
    virtual void addSolid(const DRW_Solid&) override {}
    virtual void addMText(const DRW_MText&) override {}
    virtual void addText(const DRW_Text&) override {}
    virtual void addDimAlign(const DRW_DimAligned*) override {}
    virtual void addDimLinear(const DRW_DimLinear*) override {}
    virtual void addDimRadial(const DRW_DimRadial*) override {}
    virtual void addDimDiametric(const DRW_DimDiametric*) override {}
    virtual void addDimAngular(const DRW_DimAngular*) override {}
    virtual void addDimAngular3P(const DRW_DimAngular3p*) override {}
    virtual void addDimOrdinate(const DRW_DimOrdinate*) override {}
    virtual void addLeader(const DRW_Leader*) override {}
    virtual void addHatch(const DRW_Hatch*) override {}
    virtual void addViewport(const DRW_Viewport&) override {}
    virtual void addImage(const DRW_Image*) override {}
    virtual void linkImage(const DRW_ImageDef*) override {}
    virtual void addComment(const char*) override {}
    virtual void addPlotSettings(const DRW_PlotSettings*) override {}
    virtual void writeHeader(DRW_Header&) override {}
    virtual void writeBlocks() override {}
    virtual void writeBlockRecords() override {}
    virtual void writeEntities() override {}
    virtual void writeLTypes() override {}
    virtual void writeLayers() override {}
    virtual void writeTextstyles() override {}
    virtual void writeVports() override {}
    virtual void writeDimstyles() override {}
    virtual void writeObjects() override {}
    virtual void writeAppId() override {}
};

// ─────────────────────────────────────────────────────────────────────────────
// Pass 2: scrive entità con colori risolti
// ─────────────────────────────────────────────────────────────────────────────

class EntityWriter : public DRW_Interface {
public:
    std::ofstream& out;
    bool first = true;
    const std::map<std::string,int>& layerColors;

    EntityWriter(std::ofstream& o, const std::map<std::string,int>& lc)
            : out(o), layerColors(lc) {}

    std::string resolveColor(int aci, const std::string& layer) {
        if (aci == 256 || aci == 0) {           // ByLayer / ByBlock
            auto it = layerColors.find(layer);
            return (it != layerColors.end()) ? aciHex(it->second) : "#FFFFFF";
        }
        return aciHex(aci);
    }

    void beg() { if (!first) out<<","; first=false; out<<"{"; }

    void com(const DRW_Entity& e) {
        out << "\"l\":\"" << esc(e.layer) << "\","
            << "\"c\":\"" << resolveColor(e.color, e.layer) << "\"";
    }

    virtual void addLine(const DRW_Line& e) override {
        beg();
        out<<"\"t\":\"L\","
           <<"\"x1\":"<<fd(e.basePoint.x)<<","
           <<"\"y1\":"<<fd(e.basePoint.y)<<","
           <<"\"x2\":"<<fd(e.secPoint.x) <<","
           <<"\"y2\":"<<fd(e.secPoint.y) <<",";
        com(e); out<<"}";
    }

    virtual void addCircle(const DRW_Circle& e) override {
        beg();
        out<<"\"t\":\"C\","
           <<"\"cx\":"<<fd(e.basePoint.x)<<","
           <<"\"cy\":"<<fd(e.basePoint.y)<<","
           <<"\"r\":"<<fd(e.radious)<<",";
        com(e); out<<"}";
    }

    virtual void addArc(const DRW_Arc& e) override {
        beg();
        out<<"\"t\":\"A\","
           <<"\"cx\":"<<fd(e.basePoint.x)<<","
           <<"\"cy\":"<<fd(e.basePoint.y)<<","
           <<"\"r\":"<<fd(e.radious)<<","
           <<"\"sa\":"<<fd(e.staangle)<<","
           <<"\"ea\":"<<fd(e.endangle)<<",";
        com(e); out<<"}";
    }

    virtual void addLWPolyline(const DRW_LWPolyline& e) override {
        if (e.vertlist.empty()) return;
        beg();
        out<<"\"t\":\"P\",\"cl\":"<<(e.flags&1?1:0)<<",\"p\":[";
        for (size_t i=0;i<e.vertlist.size();i++){
            if(i)out<<",";
            out<<"["<<fd(e.vertlist[i]->x)<<","<<fd(e.vertlist[i]->y)<<"]";
        }
        out<<"],"; com(e); out<<"}";
    }

    virtual void addPolyline(const DRW_Polyline& e) override {
        if (e.vertlist.empty()) return;
        beg();
        out<<"\"t\":\"P\",\"cl\":"<<(e.flags&1?1:0)<<",\"p\":[";
        for (size_t i=0;i<e.vertlist.size();i++){
            if(i)out<<",";
            out<<"["<<fd(e.vertlist[i]->basePoint.x)<<","<<fd(e.vertlist[i]->basePoint.y)<<"]";
        }
        out<<"],"; com(e); out<<"}";
    }

    virtual void addSpline(const DRW_Spline* e) override {
        if (!e||e->controllist.empty()) return;
        beg();
        out<<"\"t\":\"P\",\"cl\":0,\"p\":[";
        for (size_t i=0;i<e->controllist.size();i++){
            if(i)out<<",";
            out<<"["<<fd(e->controllist[i]->x)<<","<<fd(e->controllist[i]->y)<<"]";
        }
        out<<"],"; com(*e); out<<"}";
    }

    // ── no-op ─────────────────────────────────────────────────────────────────
    virtual void addHeader(const DRW_Header*) override {}
    virtual void addLType(const DRW_LType&) override {}
    virtual void addLayer(const DRW_Layer&) override {}
    virtual void addDimStyle(const DRW_Dimstyle&) override {}
    virtual void addVport(const DRW_Vport&) override {}
    virtual void addTextStyle(const DRW_Textstyle&) override {}
    virtual void addAppId(const DRW_AppId&) override {}
    virtual void addBlock(const DRW_Block&) override {}
    virtual void setBlock(const int) override {}
    virtual void endBlock() override {}
    virtual void addPoint(const DRW_Point&) override {}
    virtual void addRay(const DRW_Ray&) override {}
    virtual void addXline(const DRW_Xline&) override {}
    virtual void addEllipse(const DRW_Ellipse&) override {}
    virtual void addKnot(const DRW_Entity&) override {}
    virtual void addInsert(const DRW_Insert&) override {}
    virtual void addTrace(const DRW_Trace&) override {}
    virtual void add3dFace(const DRW_3Dface&) override {}
    virtual void addSolid(const DRW_Solid&) override {}
    virtual void addMText(const DRW_MText&) override {}
    virtual void addText(const DRW_Text&) override {}
    virtual void addDimAlign(const DRW_DimAligned*) override {}
    virtual void addDimLinear(const DRW_DimLinear*) override {}
    virtual void addDimRadial(const DRW_DimRadial*) override {}
    virtual void addDimDiametric(const DRW_DimDiametric*) override {}
    virtual void addDimAngular(const DRW_DimAngular*) override {}
    virtual void addDimAngular3P(const DRW_DimAngular3p*) override {}
    virtual void addDimOrdinate(const DRW_DimOrdinate*) override {}
    virtual void addLeader(const DRW_Leader*) override {}
    virtual void addHatch(const DRW_Hatch*) override {}
    virtual void addViewport(const DRW_Viewport&) override {}
    virtual void addImage(const DRW_Image*) override {}
    virtual void linkImage(const DRW_ImageDef*) override {}
    virtual void addComment(const char*) override {}
    virtual void addPlotSettings(const DRW_PlotSettings*) override {}
    virtual void writeHeader(DRW_Header&) override {}
    virtual void writeBlocks() override {}
    virtual void writeBlockRecords() override {}
    virtual void writeEntities() override {}
    virtual void writeLTypes() override {}
    virtual void writeLayers() override {}
    virtual void writeTextstyles() override {}
    virtual void writeVports() override {}
    virtual void writeDimstyles() override {}
    virtual void writeObjects() override {}
    virtual void writeAppId() override {}
};

// ─────────────────────────────────────────────────────────────────────────────
// JNI: convertDwgToDxf
// ─────────────────────────────────────────────────────────────────────────────

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_cad_1view_CadNative_convertDwgToDxf(
        JNIEnv* env, jobject,
        jstring inputPath, jstring outputPath) {
    const char* in  = env->GetStringUTFChars(inputPath,  nullptr);
    const char* out = env->GetStringUTFChars(outputPath, nullptr);
    LOGI("DWG->DXF: %s -> %s", in, out);
    FILE* f = fopen(in,"rb");
    if (!f) {
        env->ReleaseStringUTFChars(inputPath,in);
        env->ReleaseStringUTFChars(outputPath,out);
        return env->NewStringUTF("ERROR_FILE_NOT_FOUND");
    }
    char ver[7]={0}; fread(ver,1,6,f); fclose(f);
    LOGI("DWG version: %s", ver);
    dx_data data; dx_iface iface;
    if (!iface.fileImport(std::string(in),&data,false)){
        env->ReleaseStringUTFChars(inputPath,in);
        env->ReleaseStringUTFChars(outputPath,out);
        return env->NewStringUTF("ERROR_READ");
    }
    bool ok=iface.fileExport(std::string(out),DRW::AC1015,false,&data,false);
    env->ReleaseStringUTFChars(inputPath,in);
    env->ReleaseStringUTFChars(outputPath,out);
    return env->NewStringUTF(ok?"OK":"ERROR_WRITE");
}

// ─────────────────────────────────────────────────────────────────────────────
// JNI: parseDxfToFile  (due passate: layer colors → entità)
// ─────────────────────────────────────────────────────────────────────────────

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_cad_1view_CadNative_parseDxfToFile(
        JNIEnv* env, jobject,
        jstring dxfPath, jstring jsonPath) {
    const char* dxf  = env->GetStringUTFChars(dxfPath,  nullptr);
    const char* json = env->GetStringUTFChars(jsonPath, nullptr);
    LOGI("parseDxfToFile: %s", dxf);

    // ── Passata 1: raccoglie layer colors ─────────────────────────────────────
    LayerCollector lc;
    { dxfRW r1(dxf); r1.read(&lc, false); }
    LOGI("Layers found: %zu", lc.colors.size());

    // ── Passata 2: scrive entità sul file JSON ────────────────────────────────
    std::ofstream fs(json, std::ios::out | std::ios::trunc);
    if (!fs.is_open()) {
        env->ReleaseStringUTFChars(dxfPath,dxf);
        env->ReleaseStringUTFChars(jsonPath,json);
        return env->NewStringUTF("ERROR_OPEN_OUTPUT");
    }

    // Scrivi header layer nel JSON
    fs << "{\"layers\":{";
    bool firstL = true;
    for (auto& kv : lc.colors) {
        if (!firstL) fs << ",";
        firstL = false;
        fs << "\"" << esc(kv.first) << "\":"
           << "{\"color\":\"" << aciHex(kv.second) << "\"}";
    }
    fs << "},\"entities\":[";

    EntityWriter ew(fs, lc.colors);
    dxfRW r2(dxf);
    bool ok = r2.read(&ew, false);

    fs << "]}";
    fs.flush(); fs.close();

    env->ReleaseStringUTFChars(dxfPath,dxf);
    env->ReleaseStringUTFChars(jsonPath,json);

    if (!ok) { LOGE("parseDxfToFile: entity read failed"); return env->NewStringUTF("ERROR_READ"); }
    LOGI("parseDxfToFile: done");
    return env->NewStringUTF("OK");
}