//
//  DYYYAudioTapPrivate.h
//  DYYY
//
//  DYYYAudioTap.mm 与 DYYYAudioReport.mm 共享的内部状态、结构与访问函数。
//  只允许这两个编译单元引用；对外 API 一律走 DYYYUtilsAudio.h。
//
//  实时层约束（同 DYYYAudioTap.mm 头部说明）：音频渲染线程路径不分配内存、
//  不加锁、不发 ObjC 消息。本头文件只声明，不引入任何运行时行为。
//

#ifndef DYYYAudioTapPrivate_h
#define DYYYAudioTapPrivate_h

#include <AudioToolbox/AudioToolbox.h>
#include <atomic>

// 上限常量
constexpr uint32_t kDYYYMaxSources = 32;
constexpr uint32_t kDYYYMaxEvents = 4096;
constexpr uint32_t kDYYYMaxFormatRecords = 8;

// 事件

enum DYYYEventKind : uint32_t {
    DYYYEventComponentNew = 1,
    DYYYEventComponentDispose,
    DYYYEventUnitInitialize,
    DYYYEventOutputStart,
    DYYYEventOutputStop,
    DYYYEventRenderNotifyInstall,
    DYYYEventQueueNew,
    DYYYEventQueueStart,
    DYYYEventQueueStop,
    DYYYEventQueueDispose,
    DYYYEventQueueEnqueue,
    DYYYEventMediaTapCreate,
};

struct DYYYEvent {
    std::atomic<uint32_t> ready;
    uint32_t kind;
    uint32_t sourceID;
    int32_t status;
    uint64_t ticks;
    uintptr_t caller;
    uint64_t value1;
    uint64_t value2;
};

// 被重绑定符号

enum DYYYSymbolIndex : uint32_t {
    DYYYSymbolComponentNew = 0,
    DYYYSymbolComponentDispose,
    DYYYSymbolUnitInitialize,
    DYYYSymbolOutputStart,
    DYYYSymbolOutputStop,
    DYYYSymbolQueueNewOutput,
    DYYYSymbolQueueNewOutputDispatch,
    DYYYSymbolQueueStart,
    DYYYSymbolQueueStop,
    DYYYSymbolQueueDispose,
    DYYYSymbolQueueEnqueue,
    DYYYSymbolTapCreate,
    DYYYSymbolCount,
};

struct DYYYSymbolCoverage {
    void *original;
    int rebindResult;
    std::atomic<uint64_t> hits;
    std::atomic<uint64_t> firstTicks;
    std::atomic<uint64_t> lastTicks;
    std::atomic<uintptr_t> firstCaller;
    std::atomic<uintptr_t> lastCaller;
    std::atomic<int32_t> lastStatus;
};

// 源

struct DYYYFormatRecord {
    std::atomic<uint32_t> version;
    uint32_t scope;
    uint64_t ticks;
    AudioStreamBasicDescription format;
};

struct DYYYSource {
    std::atomic<uintptr_t> handle;
    uint32_t sourceID;
    uint32_t kind;
    OSType componentType;
    OSType componentSubType;
    OSType componentManufacturer;
    // seqlock：实时侧只读，写在非实时侧。
    std::atomic<uint32_t> formatVersion;
    AudioStreamBasicDescription format;
    std::atomic<uint32_t> formatRecordCount;
    DYYYFormatRecord formatRecords[kDYYYMaxFormatRecords];
    std::atomic<int> active;
    std::atomic<int> disposed;
    std::atomic<int> notifyInstalled;
    std::atomic<int32_t> notifyStatus;
    std::atomic<uint64_t> hits;
    std::atomic<uint64_t> frames;
    std::atomic<uint64_t> firstCallbackTicks;
    std::atomic<uint64_t> previousCallbackTicks;
    std::atomic<uint64_t> callbackIntervalCount;
    std::atomic<uint64_t> callbackIntervalTicks;
    std::atomic<uint64_t> minCallbackIntervalTicks;
    std::atomic<uint64_t> maxCallbackIntervalTicks;
    std::atomic<uint64_t> estimatedDroppedFrames;
    std::atomic<uint64_t> lastTicks;
    std::atomic<int32_t> lastStatus;
    std::atomic<uint64_t> contentionDrops;
    std::atomic<uint64_t> unsupportedBuffers;
    std::atomic<uint64_t> unreadableFrames;
    std::atomic<uint64_t> captureSlotMisses;
    std::atomic<uint64_t> formatMismatchBuffers;
    std::atomic<uint64_t> pcmCapacityDroppedFrames;
    std::atomic<uint64_t> configurationOverflow;
    std::atomic<uint64_t> probeTicks;
    std::atomic<uint64_t> probeBlocks;
    std::atomic<uint64_t> maxProbeTicks;
    std::atomic<int> captureSlot;
    // ioData 的实测排布。缓存的 ASBD 描述的是客户端推进去的格式，与 PostRender 拿到的
    // buffer 排布允许不同（beta2 就在这里读错了），故把真实几何原样记下来。
    std::atomic<uint32_t> layoutNumberBuffers;
    std::atomic<uint32_t> layoutChannelsPerBuffer;
    std::atomic<uint32_t> layoutDataByteSize;
    std::atomic<uint32_t> layoutRenderFrames;
    // 实时电平旁路。liveRing 一旦认领就不再归还——源本身是只增不减的。
    std::atomic<int> liveRing;
    std::atomic<uint64_t> liveWrite;
    std::atomic<uint64_t> liveTicks;
    std::atomic<double> liveSampleRate;
    // 块 RMS 的指数滑动平均，选源用。float 的 atomic 在 arm64 上是无锁的。
    std::atomic<float> liveEnergy;
    std::atomic_flag captureGuard = ATOMIC_FLAG_INIT;
};

// 全局状态（定义在 DYYYAudioTap.mm）。
extern const char *const DYYYSymbolNames[DYYYSymbolCount];
extern DYYYSource DYYYSources[kDYYYMaxSources];
extern std::atomic<uint32_t> DYYYSourceCount;
extern std::atomic<uint64_t> DYYYSourceOverflow;
extern DYYYEvent DYYYEvents[kDYYYMaxEvents];
extern std::atomic<uint32_t> DYYYEventCount;
extern std::atomic<uint64_t> DYYYEventOverflow;
extern DYYYSymbolCoverage DYYYCoverage[DYYYSymbolCount];
extern std::atomic<int> DYYYActiveWriters;
extern std::atomic<uint64_t> DYYYPCMAllocationFailures;
extern std::atomic<uint64_t> DYYYCaptureStartTicks;
extern std::atomic<uint64_t> DYYYCaptureStopTicks;

// 供 DYYYAudioReport.mm 只读使用（定义在 DYYYAudioTap.mm）。
double DYYYTicksToSeconds(uint64_t ticks);
double DYYYRelativeSeconds(uint64_t ticks, uint64_t origin);
bool DYYYReadSourceFormat(DYYYSource *source, AudioStreamBasicDescription *format);

#endif /* DYYYAudioTapPrivate_h */
