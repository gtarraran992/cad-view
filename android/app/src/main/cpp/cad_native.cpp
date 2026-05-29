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
// ACI palette (256 entries)
// ─────────────────────────────────────────────────────────────────────────────
static const uint32_t ACI[256] = {
        0xFFFFFF,0xFF0000,0xFFFF00,0x00FF00,0x00FFFF,0x0000FF,0xFF00FF,0xFFFFFF,
        0x808080,0xC0C0C0,
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
        // 110-249: white
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
static std::string aciHex(int a){
    if(a<0||a>255)return"#FFFFFF";
    char b[8];snprintf(b,sizeof(b),"#%06X",ACI[a]);return b;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
static std::string esc(const std::string& s){
    std::string o;o.reserve(s.size()+4);
    for(unsigned char c:s){
        if(c=='"')o+="\\\"";
        else if(c=='\\')o+="\\\\";
        else if(c=='\n')o+="\\n";
        else if(c=='\r')o+="\\r";
        else if(c=='\t')o+="\\t";
        else if(c<0x20){char b[8];snprintf(b,sizeof(b),"\\u%04x",c);o+=b;}
        else o+=(char)c;
    }
    return o;
}
static std::string fd(double v){
    std::ostringstream ss;ss<<std::fixed<<std::setprecision(4)<<v;return ss.str();
}

// Rimuove i codici RTF dall'MTEXT ({\fArial;...}, \P, \~, ecc.)
static std::string stripMTextCodes(const std::string& s){
    std::string o;
    bool inBrace=false;
    size_t i=0;
    while(i<s.size()){
        char c=s[i];
        if(c=='{'){
            // salta il gruppo di formattazione se inizia con backslash
            if(i+1<s.size()&&s[i+1]=='\\'){inBrace=true;i++;continue;}
            i++;continue;
        }
        if(c=='}'){inBrace=false;i++;continue;}
        if(c=='\\'){
            i++;
            if(i>=s.size())break;
            char next=s[i];
            if(next=='P'||next=='p'){o+='\n';i++;continue;} // paragrafo
            if(next=='~'){o+=' ';i++;continue;}             // spazio nb
            if(next=='{'||next=='}'){o+=next;i++;continue;}
            // altri codici: salta fino a ';' o spazio
            while(i<s.size()&&s[i]!=';'&&s[i]!=' ')i++;
            if(i<s.size()&&s[i]==';')i++;
            continue;
        }
        if(!inBrace)o+=c;
        i++;
    }
    return o;
}

// ─────────────────────────────────────────────────────────────────────────────
// Pass 1: LayerCollector
// ─────────────────────────────────────────────────────────────────────────────
class LayerCollector : public DRW_Interface {
public:
    std::map<std::string,int> colors;
    virtual void addLayer(const DRW_Layer& l) override {
        colors[l.name]=(l.color<0)?-l.color:l.color;
    }
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
// Pass 2: EntityWriter
// ─────────────────────────────────────────────────────────────────────────────
class EntityWriter : public DRW_Interface {
public:
    std::ofstream& out;
    bool first=true;
    const std::map<std::string,int>& lc;

    EntityWriter(std::ofstream& o,const std::map<std::string,int>& l):out(o),lc(l){}

    std::string col(int aci,const std::string& layer){
        if(aci==256||aci==0){auto it=lc.find(layer);return(it!=lc.end())?aciHex(it->second):"#FFFFFF";}
        return aciHex(aci);
    }
    void beg(){if(!first)out<<",";first=false;out<<"{";}
    void com(const DRW_Entity& e){
        out<<"\"l\":\""<<esc(e.layer)<<"\","
           <<"\"c\":\""<<col(e.color,e.layer)<<"\"";
    }

    // ── Geometria ─────────────────────────────────────────────────────────────

    virtual void addLine(const DRW_Line& e) override {
        beg();
        out<<"\"t\":\"L\","
           <<"\"x1\":"<<fd(e.basePoint.x)<<","
           <<"\"y1\":"<<fd(e.basePoint.y)<<","
           <<"\"x2\":"<<fd(e.secPoint.x)<<","
           <<"\"y2\":"<<fd(e.secPoint.y)<<",";
        com(e);out<<"}";
    }
    virtual void addCircle(const DRW_Circle& e) override {
        beg();
        out<<"\"t\":\"C\","
           <<"\"cx\":"<<fd(e.basePoint.x)<<","
           <<"\"cy\":"<<fd(e.basePoint.y)<<","
           <<"\"r\":"<<fd(e.radious)<<",";
        com(e);out<<"}";
    }
    virtual void addArc(const DRW_Arc& e) override {
        beg();
        out<<"\"t\":\"A\","
           <<"\"cx\":"<<fd(e.basePoint.x)<<","
           <<"\"cy\":"<<fd(e.basePoint.y)<<","
           <<"\"r\":"<<fd(e.radious)<<","
           <<"\"sa\":"<<fd(e.staangle)<<","
           <<"\"ea\":"<<fd(e.endangle)<<",";
        com(e);out<<"}";
    }
    virtual void addLWPolyline(const DRW_LWPolyline& e) override {
        if(e.vertlist.empty())return;
        beg();
        out<<"\"t\":\"P\",\"cl\":"<<(e.flags&1?1:0)<<",\"p\":[";
        for(size_t i=0;i<e.vertlist.size();i++){
            if(i)out<<",";
            out<<"["<<fd(e.vertlist[i]->x)<<","<<fd(e.vertlist[i]->y)<<"]";
        }
        out<<"],";com(e);out<<"}";
    }
    virtual void addPolyline(const DRW_Polyline& e) override {
        if(e.vertlist.empty())return;
        beg();
        out<<"\"t\":\"P\",\"cl\":"<<(e.flags&1?1:0)<<",\"p\":[";
        for(size_t i=0;i<e.vertlist.size();i++){
            if(i)out<<",";
            out<<"["<<fd(e.vertlist[i]->basePoint.x)<<","<<fd(e.vertlist[i]->basePoint.y)<<"]";
        }
        out<<"],";com(e);out<<"}";
    }
    virtual void addSpline(const DRW_Spline* e) override {
        if(!e||e->controllist.empty())return;
        beg();
        out<<"\"t\":\"P\",\"cl\":0,\"p\":[";
        for(size_t i=0;i<e->controllist.size();i++){
            if(i)out<<",";
            out<<"["<<fd(e->controllist[i]->x)<<","<<fd(e->controllist[i]->y)<<"]";
        }
        out<<"],";com(*e);out<<"}";
    }

    // ── Testo ─────────────────────────────────────────────────────────────────

    void writeText(const DRW_Text& e, bool isMText) {
        std::string raw = e.text;
        std::string txt = isMText ? stripMTextCodes(raw) : raw;
        if(txt.empty())return;

        // Punto di inserimento: usa secPoint se alignH/alignV != default
        double px = e.basePoint.x, py = e.basePoint.y;
        if(e.alignH != DRW_Text::HLeft || e.alignV != DRW_Text::VBaseLine){
            if(e.secPoint.x != 0 || e.secPoint.y != 0){
                px = e.secPoint.x; py = e.secPoint.y;
            }
        }

        beg();
        out<<"\"t\":\""<<(isMText?"M":"T")<<"\","
           <<"\"x\":"<<fd(px)<<","
           <<"\"y\":"<<fd(py)<<","
           <<"\"h\":"<<fd(e.height)<<","
           <<"\"a\":"<<fd(e.angle)<<","    // rotazione gradi
           <<"\"ah\":"<<(int)e.alignH<<","  // 0=L,1=C,2=R,3=Aligned,4=Middle,5=Fit
           <<"\"av\":"<<(int)e.alignV<<","  // 0=Baseline,1=Bottom,2=Middle,3=Top
           <<"\"s\":\""<<esc(txt)<<"\",";
        com(e);out<<"}";
    }

    virtual void addText(const DRW_Text& e) override  { writeText(e, false); }
    virtual void addMText(const DRW_MText& e) override { writeText(e, true);  }

    // ── Quote ─────────────────────────────────────────────────────────────────

    void writeDim(const DRW_Dimension* e) {
        if(!e)return;
        std::string txt = e->getText();
        bool autoText = (txt.empty() || txt=="<>");

        // Posizione testo
        DRW_Coord tp = e->getTextPoint();
        // Se textPoint è (0,0) usa defPoint
        if(tp.x == 0 && tp.y == 0) tp = e->getDefPoint();

        // Angolo: disponibile solo su DRW_DimLinear
        double ang = 0.0;
        if(const DRW_DimLinear* dl = dynamic_cast<const DRW_DimLinear*>(e)){
            ang = dl->getAngle();
        }

        // Valore misurato (code 42) — usato se testo è "<>" o vuoto
        double measured = e->getMeasureValue();
        std::string display;
        if(autoText && measured != 0){
            std::ostringstream ss;
            ss << std::fixed << std::setprecision(2) << measured;
            display = ss.str();
        } else {
            display = autoText ? "" : txt;
        }
        if(display.empty())return;

        beg();
        out<<"\"t\":\"D\","
           <<"\"tx\":"<<fd(tp.x)<<","
           <<"\"ty\":"<<fd(tp.y)<<","
           <<"\"a\":"<<fd(ang)<<","
           <<"\"s\":\""<<esc(display)<<"\",";
        com(*e);out<<"}";
    }

    virtual void addDimAlign(const DRW_DimAligned* e) override     { writeDim(e); }
    virtual void addDimLinear(const DRW_DimLinear* e) override     { writeDim(e); }
    virtual void addDimRadial(const DRW_DimRadial* e) override     { writeDim(e); }
    virtual void addDimDiametric(const DRW_DimDiametric* e) override { writeDim(e); }
    virtual void addDimAngular(const DRW_DimAngular* e) override   { writeDim(e); }
    virtual void addDimAngular3P(const DRW_DimAngular3p* e) override { writeDim(e); }
    virtual void addDimOrdinate(const DRW_DimOrdinate* e) override { writeDim(e); }

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
        JNIEnv* env,jobject,jstring inputPath,jstring outputPath){
    const char* in =env->GetStringUTFChars(inputPath, nullptr);
    const char* out=env->GetStringUTFChars(outputPath,nullptr);
    LOGI("DWG->DXF: %s -> %s",in,out);
    FILE* f=fopen(in,"rb");
    if(!f){
        env->ReleaseStringUTFChars(inputPath,in);
        env->ReleaseStringUTFChars(outputPath,out);
        return env->NewStringUTF("ERROR_FILE_NOT_FOUND");
    }
    char ver[7]={0};fread(ver,1,6,f);fclose(f);
    LOGI("DWG ver: %s",ver);
    dx_data data;dx_iface iface;
    if(!iface.fileImport(std::string(in),&data,false)){
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
// JNI: parseDxfToFile
// ─────────────────────────────────────────────────────────────────────────────
extern "C" JNIEXPORT jstring JNICALL
Java_com_example_cad_1view_CadNative_parseDxfToFile(
        JNIEnv* env,jobject,jstring dxfPath,jstring jsonPath){
    const char* dxf =env->GetStringUTFChars(dxfPath, nullptr);
    const char* json=env->GetStringUTFChars(jsonPath,nullptr);
    LOGI("parseDxfToFile: %s",dxf);

    // Passata 1: layer colors
    LayerCollector lc;
    {dxfRW r1(dxf);r1.read(&lc,false);}
    LOGI("Layers: %zu",lc.colors.size());

    // Passata 2: entità → JSON
    std::ofstream fs(json,std::ios::out|std::ios::trunc);
    if(!fs.is_open()){
        env->ReleaseStringUTFChars(dxfPath,dxf);
        env->ReleaseStringUTFChars(jsonPath,json);
        return env->NewStringUTF("ERROR_OPEN_OUTPUT");
    }

    // Header layers
    fs<<"{\"layers\":{";
    bool firstL=true;
    for(auto& kv:lc.colors){
        if(!firstL)fs<<",";firstL=false;
        fs<<"\""<<esc(kv.first)<<"\":{\"color\":\""<<aciHex(kv.second)<<"\"}";
    }
    fs<<"},\"entities\":[";

    EntityWriter ew(fs,lc.colors);
    dxfRW r2(dxf);
    bool ok=r2.read(&ew,false);

    fs<<"]}";
    fs.flush();fs.close();

    env->ReleaseStringUTFChars(dxfPath,dxf);
    env->ReleaseStringUTFChars(jsonPath,json);

    if(!ok){LOGE("parseDxfToFile failed");return env->NewStringUTF("ERROR_READ");}
    LOGI("parseDxfToFile: done");
    return env->NewStringUTF("OK");
}