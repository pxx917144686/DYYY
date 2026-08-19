//
//  DYYYAudioTap.h
//  DYYY
//
//  进程音频输出的只读旁路。用 fishhook 重绑定 AudioToolbox 的少数入口拿到
//  输出单元/队列句柄，再用公开的 AudioUnitAddRenderNotify 旁听已渲染的样本；
//  不替换抖音自己的 AURenderCallback，因此不进它出声的主链路。
//
//  这一层是后续音频可视化功能要复用的部分：取样机制与功能将要使用的完全一致。
//

#ifndef DYYYUtils_Audio_h
#define DYYYUtils_Audio_h

#import <AudioToolbox/AudioToolbox.h>
#import <Foundation/Foundation.h>

typedef NS_ENUM(uint32_t, DYYYAudioTapSourceKind) {
    DYYYAudioTapSourceKindAudioUnit = 1,
    DYYYAudioTapSourceKindAudioQueue = 2,
    DYYYAudioTapSourceKindMediaTap = 3,
};

/// 一路已录到的单声道 Float32 样本。samples 由 tap 持有，读取方不得释放。
typedef struct {
    uint32_t sourceID;
    uint32_t kind;
    const float *samples;
    uint64_t frameCount;
    double sampleRate;
    AudioStreamBasicDescription sourceFormat;
} DYYYAudioTapSlot;

#ifdef __cplusplus
extern "C" {
#endif

/// 安装符号包装。幂等；只有第一次真正执行 rebind。
void DYYYAudioTapInstall(void);

/// 关闭后所有包装器只透明转发，不再登记、不再取样。
void DYYYAudioTapSetEnabled(BOOL enabled);
BOOL DYYYAudioTapIsInstalled(void);

/// 开启采样窗口：先静置 warmupSeconds，再录 recordSeconds 的 PCM。
/// 失败返回 NO（未安装、已在采样、PCM 缓冲分配失败）。
BOOL DYYYAudioTapBeginCapture(double warmupSeconds, double recordSeconds);
void DYYYAudioTapEndCapture(void);
BOOL DYYYAudioTapIsCapturing(void);

/// 等待实时写入方全部离开缓冲区，之后读槽位才是安全的。
void DYYYAudioTapWaitForWriters(void);

uint64_t DYYYAudioTapCaptureStartTicks(void);
uint64_t DYYYAudioTapCaptureStopTicks(void);
double DYYYAudioTapSecondsFromTicks(uint64_t ticks);
double DYYYAudioTapSecondsRelativeTo(uint64_t ticks, uint64_t origin);
/// 相对本次采样起点的秒数；未开始采样时返回 -1。
double DYYYAudioTapCurrentCaptureSecond(void);

/// 采样结束后读取录到的各路 PCM。index < DYYYAudioTapSlotCount()。
uint32_t DYYYAudioTapSlotCount(void);
BOOL DYYYAudioTapReadSlot(uint32_t index, DYYYAudioTapSlot *out);

#pragma mark - 实时电平旁路

// 与上面那套五秒采集彼此独立：采集是"开一个窗口、录完就停"，这里是常开的滚动环，
// 供音频可视化逐帧取最近一段样本。两者共用同一次下混，互不影响对方的计数。

/// 常开电平旁路的开关。关闭时实时侧完全不碰环形缓冲。
void DYYYAudioTapSetLiveMeteringEnabled(BOOL enabled);
BOOL DYYYAudioTapIsLiveMeteringEnabled(void);

/// 拷出当前"最响的那一路"最近的 count 个单声道 Float32 样本（out[count-1] 为最新）。
/// 返回实际拷出的帧数；无活跃音源、或拷贝期间被实时侧覆盖时返回 0。
/// sampleRateOut 可为 NULL。只在主线程调用。
uint32_t DYYYAudioTapCopyLatestSamples(float *out, uint32_t count, double *sampleRateOut);

/// withinSeconds 内是否还有音源在送 buffer。用于决定可视化的显隐与帧率档位。
BOOL DYYYAudioTapHasRecentAudio(double withinSeconds);

/// 后端登记表：每个 unit / queue / tap 的身份、格式、启停与统计。
NSArray<NSDictionary *> *DYYYAudioTapBackendsJSON(void);
/// 每个被重绑定符号的覆盖情况与命中调用者。
NSArray<NSDictionary *> *DYYYAudioTapSymbolCoverageJSON(void);
/// 实时层事件行（含 ticks 键），供上层与 ObjC 事件合并后按时间排序。
NSArray<NSDictionary *> *DYYYAudioTapEventRows(void);
/// 溢出、丢帧、争用等计数器汇总。
NSDictionary *DYYYAudioTapCountersJSON(void);

NSArray<NSString *> *DYYYAudioTapCallerImageNames(void);
/// 指针命中已登记后端时返回 source-NN，否则 nil。
NSString *DYYYAudioTapSourceIDForPointer(uintptr_t pointer);

#ifdef __cplusplus
}
#endif

#endif /* DYYYUtils_Audio_h */

//
//  DYYYAudioSignal.h
//  DYYY
//
//  纯音频数据转换与离线信号分析；实时入口不分配内存。
//

#ifndef DYYYAudioSignal_h
#define DYYYAudioSignal_h

#import <AudioToolbox/AudioToolbox.h>
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/// 把线性 PCM 下混为单声道 Float32，返回实际写入帧数。
uint32_t DYYYAudioSignalDownmix(const AudioBufferList *bufferList,
                              const AudioStreamBasicDescription *format,
                              uint32_t frameCount,
                              float *output,
                              uint32_t outputCapacity,
                              uint64_t *unreadableFrames);

NSData *DYYYAudioSignalFloatWAV(const float *samples, uint64_t frameCount, double sampleRate);
NSDictionary *DYYYAudioSignalMetrics(const float *samples, uint64_t count);
NSArray<NSNumber *> *DYYYAudioSignalFrequencyBands(const float *samples,
                                                 uint64_t available,
                                                 double sampleRate);

/// Float32/Int16、交错/非交错、静音、频谱、WAV 与容量边界自检。
NSDictionary *DYYYAudioSignalSyntheticValidation(void);

/// 共用的 1024 点 DFT setup（进程内只建一次）。供 DYYYAudioLevels 逐帧复用，
/// 避免每帧新建/销毁。失败返回 NULL。
void *DYYYAudioSignalDFTSetup1024(void);

#ifdef __cplusplus
}
#endif

#endif /* DYYYAudioSignal_h */

//
//  DYYYAudioLevels.h
//  DYYY
//
//  主线程分析层：把 DYYYAudioTap 的实时样本变成 0…1 的分段电平，供音频可视化逐帧驱动。
//  逐帧零分配（scratch 全是 static），只在主线程调用。
//
//  与 DYYYAudioSignalFrequencyBands 的分工：那个是【导出的分析口径】，40 Hz–24 kHz 覆盖全频，
//  给离线看频谱用；这里是【可视化口径】，只保留素材真正有内容的那一段，见 .mm 里的说明。
//

#ifndef DYYYAudioLevels_h
#define DYYYAudioLevels_h

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/// 分段数。可视化的条数与它无关，由 DYYYAudioLevelsResample 插值得到。
uint32_t DYYYAudioLevelsBandCount(void);

/// 拉一次实时样本 → 加窗 → DFT → 分段 → 自适应增益 → 响应曲线，写入 bands[0…BandCount)。
/// bands[0] 是最低频。没有可用音频时把 bands 清零并返回 NO。
BOOL DYYYAudioLevelsSampleBands(float *bands, double deltaSeconds);

/// 把 BandCount 段插值成 count 个值。u[k] ∈ [0,1] 给出第 k 个输出取哪一段，
/// 由调用方按自己的几何在布局时算好（0 = 最低频）。
void DYYYAudioLevelsResample(const float *bands, const float *u, float *out, uint32_t count);

/// 3 抽空间平滑（0.25 / 0.5 / 0.25），让整条包络读起来是曲线而不是噪声。原地更新。
void DYYYAudioLevelsSpatialSmooth(float *values, uint32_t count);

/// 一阶跟随：上升用 attackTau、下降用 decayTau（秒）。levels 原地更新。
void DYYYAudioLevelsSmooth(float *levels, const float *targets, uint32_t count,
                         double deltaSeconds, double attackTau, double decayTau);

/// 复位自适应增益。功能重新开启时调用。
void DYYYAudioLevelsReset(void);

/// 分段映射、静音、1 kHz 定位与跟随收敛的合成自检。
NSDictionary *DYYYAudioLevelsSyntheticValidation(void);

#ifdef __cplusplus
}
#endif

#endif /* DYYYAudioLevels_h */
