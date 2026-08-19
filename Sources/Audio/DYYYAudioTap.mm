//
//  DYYYAudioTap.mm
//  DYYY
//
//  实时层。这个文件里凡是会被音频渲染线程执行到的代码（DYYYRenderNotify、
//  DYYYCaptureBuffer 及其调用链）必须遵守：不分配内存、不加锁、不发 ObjC 消息、
//  不做任何可能阻塞的系统调用。缓冲区在采样开始前于主线程一次性分配。
//
//  取样口是公开只读的 AudioUnitAddRenderNotify：抖音全二进制 0 引用该 API，
//  我们独占；回调里只读 ioData 并原样返回 noErr，不影响它的输出。
//  只读导出（JSON 报表、事件行、调用者镜像）拆在 DYYYAudioReport.mm，
//  下混与频谱分析拆在 DYYYAudioAnalysis.mm；共享结构见 DYYYAudioTapPrivate.h。
//

#import "DYYYUtilsAudio.h"
#import "DYYYAudioTapPrivate.h"
#import "DYYYFishhook.h"

#import <CoreMedia/CoreMedia.h>
#import <MediaToolbox/MediaToolbox.h>
#import <dlfcn.h>
#import <mach/mach_time.h>
#import <os/lock.h>
#import <unistd.h>
#if __has_feature(ptrauth_calls)
#import <ptrauth.h>
#endif

#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstring>

constexpr uint32_t kDYYYCaptureSlots = 8;
constexpr double kDYYYMaxSampleRate = 192000.0;
constexpr double kDYYYMaxPCMSeconds = 4.0;
constexpr uint64_t kDYYYMaxPCMFrames = (uint64_t)(kDYYYMaxSampleRate * kDYYYMaxPCMSeconds);

// 实时电平旁路的容量。全部是 BSS 里的定长数组：实时侧永远不分配，也没有生命周期问题。
// 4 路 × 4096 帧 × 4 字节 = 64 KB；4096 帧在 48 kHz 下是 85 ms，够 1024 点分析窗用还有余量。
constexpr uint32_t kDYYYLiveRings = 4;
constexpr uint32_t kDYYYLiveRingFrames = 4096;
constexpr uint32_t kDYYYLiveRingMask = kDYYYLiveRingFrames - 1;
static_assert((kDYYYLiveRingFrames & kDYYYLiveRingMask) == 0, "环长必须是 2 的幂");
// 单次回调最多下混这么多帧进环。抖音实测 1024，留一倍余量；栈上 8 KB。
constexpr uint32_t kDYYYLiveBlockFrames = 2048;

// MARK: - 事件

// MARK: - 符号

const char *const DYYYSymbolNames[DYYYSymbolCount] = {
    "AudioComponentInstanceNew",
    "AudioComponentInstanceDispose",
    "AudioUnitInitialize",
    "AudioOutputUnitStart",
    "AudioOutputUnitStop",
    "AudioQueueNewOutput",
    "AudioQueueNewOutputWithDispatchQueue",
    "AudioQueueStart",
    "AudioQueueStop",
    "AudioQueueDispose",
    "AudioQueueEnqueueBuffer",
    "MTAudioProcessingTapCreate",
};

// MARK: - 源

struct DYYYPCMSlot {
    float *samples;
    std::atomic<int> sourceID;
    std::atomic<uint64_t> frameCount;
    AudioStreamBasicDescription format;
};

// MARK: - 全局状态

DYYYSource DYYYSources[kDYYYMaxSources];
std::atomic<uint32_t> DYYYSourceCount { 0 };
std::atomic<uint64_t> DYYYSourceOverflow { 0 };
static os_unfair_lock DYYYSourceLock = OS_UNFAIR_LOCK_INIT;

DYYYEvent DYYYEvents[kDYYYMaxEvents];
std::atomic<uint32_t> DYYYEventCount { 0 };
std::atomic<uint64_t> DYYYEventOverflow { 0 };
DYYYSymbolCoverage DYYYCoverage[DYYYSymbolCount];

static DYYYPCMSlot DYYYPCMSlots[kDYYYCaptureSlots];
std::atomic<uint64_t> DYYYPCMAllocationFailures { 0 };
std::atomic<int> DYYYActiveWriters { 0 };

// 实时电平旁路：每路一个滚动环，单写者（该源自己的渲染线程）+ 单读者（主线程）。
static float DYYYLiveRing[kDYYYLiveRings][kDYYYLiveRingFrames];
static std::atomic<uint32_t> DYYYLiveRingsClaimed { 0 };
static std::atomic<bool> DYYYLiveEnabled { false };

static std::atomic<bool> DYYYTapEnabled { false };
static std::atomic<bool> DYYYTapInstalled { false };
static std::atomic<bool> DYYYCaptureActive { false };
static os_unfair_lock DYYYCaptureControlLock = OS_UNFAIR_LOCK_INIT;
std::atomic<uint64_t> DYYYCaptureStartTicks { 0 };
std::atomic<uint64_t> DYYYCaptureStopTicks { 0 };
static std::atomic<uint64_t> DYYYPCMStartTicks { 0 };
static std::atomic<uint64_t> DYYYPCMStopTicks { 0 };
static mach_timebase_info_data_t DYYYTimebase;

static __attribute__((always_inline)) inline uintptr_t DYYYStripCaller(void *address) {
#if __has_feature(ptrauth_calls)
    return (uintptr_t)ptrauth_strip(address, ptrauth_key_return_address);
#else
    return (uintptr_t)address;
#endif
}

#define DYYY_CALLER() DYYYStripCaller(__builtin_return_address(0))

static uint64_t DYYYNanosecondsToTicks(uint64_t ns) {
    if (DYYYTimebase.numer == 0) mach_timebase_info(&DYYYTimebase);
    return (uint64_t)((long double)ns * DYYYTimebase.denom / DYYYTimebase.numer);
}

double DYYYTicksToSeconds(uint64_t ticks) {
    if (DYYYTimebase.numer == 0) mach_timebase_info(&DYYYTimebase);
    return (double)((long double)ticks * DYYYTimebase.numer / DYYYTimebase.denom / 1000000000.0L);
}

double DYYYRelativeSeconds(uint64_t ticks, uint64_t origin) {
    if (ticks == 0 || origin == 0) return -1.0;
    return ticks >= origin ? DYYYTicksToSeconds(ticks - origin) : -DYYYTicksToSeconds(origin - ticks);
}

// MARK: - 格式读写（seqlock）

static void DYYYWriteSourceFormat(DYYYSource *source, const AudioStreamBasicDescription *format) {
    if (!source || !format) return;
    for (int attempt = 0; attempt < 4; attempt++) {
        uint32_t version = source->formatVersion.load(std::memory_order_acquire);
        if (version & 1) continue;
        if (!source->formatVersion.compare_exchange_weak(version, version + 1,
                                                         std::memory_order_acq_rel,
                                                         std::memory_order_relaxed)) continue;
        source->format = *format;
        source->formatVersion.store(version + 2, std::memory_order_release);
        return;
    }
    source->configurationOverflow.fetch_add(1, std::memory_order_relaxed);
}

bool DYYYReadSourceFormat(DYYYSource *source, AudioStreamBasicDescription *format) {
    if (!source || !format) return false;
    for (int attempt = 0; attempt < 4; attempt++) {
        uint32_t before = source->formatVersion.load(std::memory_order_acquire);
        if (before == 0 || (before & 1)) continue;
        AudioStreamBasicDescription copy = source->format;
        uint32_t after = source->formatVersion.load(std::memory_order_acquire);
        if (before == after && !(after & 1)) {
            *format = copy;
            return copy.mSampleRate > 0 && copy.mChannelsPerFrame > 0;
        }
    }
    return false;
}

static void DYYYAppendFormatRecord(DYYYSource *source, uint32_t scope,
                                 const AudioStreamBasicDescription *format) {
    if (!source || !format) return;
    uint32_t index = source->formatRecordCount.fetch_add(1, std::memory_order_relaxed);
    if (index >= kDYYYMaxFormatRecords) {
        source->configurationOverflow.fetch_add(1, std::memory_order_relaxed);
        return;
    }
    DYYYFormatRecord &record = source->formatRecords[index];
    record.version.store(1, std::memory_order_release);
    record.scope = scope;
    record.ticks = mach_continuous_time();
    record.format = *format;
    record.version.store(2, std::memory_order_release);
}

// MARK: - 源登记

static DYYYSource *DYYYFindSource(uintptr_t handle, uint32_t kind) {
    uint32_t count = DYYYSourceCount.load(std::memory_order_acquire);
    for (uint32_t offset = 0; offset < count; offset++) {
        uint32_t i = count - offset - 1;
        if (DYYYSources[i].kind == kind &&
            DYYYSources[i].disposed.load(std::memory_order_relaxed) == 0 &&
            DYYYSources[i].handle.load(std::memory_order_acquire) == handle) return &DYYYSources[i];
    }
    return nullptr;
}

static DYYYSource *DYYYCreateSource(uintptr_t handle, uint32_t kind,
                                const AudioStreamBasicDescription *format) {
    if (!handle) return nullptr;
    DYYYSource *existing = DYYYFindSource(handle, kind);
    if (existing) {
        if (format) {
            DYYYWriteSourceFormat(existing, format);
            DYYYAppendFormatRecord(existing, UINT32_MAX, format);
        }
        return existing;
    }

    os_unfair_lock_lock(&DYYYSourceLock);
    existing = DYYYFindSource(handle, kind);
    if (existing) {
        os_unfair_lock_unlock(&DYYYSourceLock);
        if (format) {
            DYYYWriteSourceFormat(existing, format);
            DYYYAppendFormatRecord(existing, UINT32_MAX, format);
        }
        return existing;
    }

    uint32_t index = DYYYSourceCount.load(std::memory_order_relaxed);
    if (index >= kDYYYMaxSources) {
        DYYYSourceOverflow.fetch_add(1, std::memory_order_relaxed);
        os_unfair_lock_unlock(&DYYYSourceLock);
        return nullptr;
    }

    DYYYSource *source = &DYYYSources[index];
    source->sourceID = index + 1;
    source->kind = kind;
    source->componentType = 0;
    source->componentSubType = 0;
    source->componentManufacturer = 0;
    source->formatVersion.store(0, std::memory_order_relaxed);
    source->formatRecordCount.store(0, std::memory_order_relaxed);
    for (uint32_t i = 0; i < kDYYYMaxFormatRecords; i++) {
        source->formatRecords[i].version.store(0, std::memory_order_relaxed);
    }
    source->active.store(0, std::memory_order_relaxed);
    source->disposed.store(0, std::memory_order_relaxed);
    source->notifyInstalled.store(0, std::memory_order_relaxed);
    source->notifyStatus.store(0, std::memory_order_relaxed);
    source->hits.store(0, std::memory_order_relaxed);
    source->frames.store(0, std::memory_order_relaxed);
    source->firstCallbackTicks.store(0, std::memory_order_relaxed);
    source->previousCallbackTicks.store(0, std::memory_order_relaxed);
    source->callbackIntervalCount.store(0, std::memory_order_relaxed);
    source->callbackIntervalTicks.store(0, std::memory_order_relaxed);
    source->minCallbackIntervalTicks.store(0, std::memory_order_relaxed);
    source->maxCallbackIntervalTicks.store(0, std::memory_order_relaxed);
    source->estimatedDroppedFrames.store(0, std::memory_order_relaxed);
    source->lastTicks.store(0, std::memory_order_relaxed);
    source->lastStatus.store(0, std::memory_order_relaxed);
    source->contentionDrops.store(0, std::memory_order_relaxed);
    source->unsupportedBuffers.store(0, std::memory_order_relaxed);
    source->unreadableFrames.store(0, std::memory_order_relaxed);
    source->captureSlotMisses.store(0, std::memory_order_relaxed);
    source->formatMismatchBuffers.store(0, std::memory_order_relaxed);
    source->pcmCapacityDroppedFrames.store(0, std::memory_order_relaxed);
    source->configurationOverflow.store(0, std::memory_order_relaxed);
    source->probeTicks.store(0, std::memory_order_relaxed);
    source->probeBlocks.store(0, std::memory_order_relaxed);
    source->maxProbeTicks.store(0, std::memory_order_relaxed);
    source->captureSlot.store(-1, std::memory_order_relaxed);
    source->layoutNumberBuffers.store(0, std::memory_order_relaxed);
    source->layoutChannelsPerBuffer.store(0, std::memory_order_relaxed);
    source->layoutDataByteSize.store(0, std::memory_order_relaxed);
    source->layoutRenderFrames.store(0, std::memory_order_relaxed);
    source->liveRing.store(-1, std::memory_order_relaxed);
    source->liveWrite.store(0, std::memory_order_relaxed);
    source->liveTicks.store(0, std::memory_order_relaxed);
    source->liveSampleRate.store(0, std::memory_order_relaxed);
    source->liveEnergy.store(0, std::memory_order_relaxed);
    source->captureGuard.clear(std::memory_order_relaxed);
    if (format) {
        DYYYWriteSourceFormat(source, format);
        DYYYAppendFormatRecord(source, UINT32_MAX, format);
    }
    source->handle.store(handle, std::memory_order_release);
    DYYYSourceCount.store(index + 1, std::memory_order_release);
    os_unfair_lock_unlock(&DYYYSourceLock);
    return source;
}

// MARK: - 统计

static void DYYYUpdateMax(std::atomic<uint64_t> &value, uint64_t candidate) {
    uint64_t current = value.load(std::memory_order_relaxed);
    while (candidate > current &&
           !value.compare_exchange_weak(current, candidate, std::memory_order_relaxed)) {}
}

static void DYYYUpdateMinNonZero(std::atomic<uint64_t> &value, uint64_t candidate) {
    uint64_t current = value.load(std::memory_order_relaxed);
    while ((current == 0 || candidate < current) &&
           !value.compare_exchange_weak(current, candidate, std::memory_order_relaxed)) {}
}

static void DYYYRecordProbeElapsed(DYYYSource *source, uint64_t begin) {
    if (!source || begin == 0) return;
    uint64_t elapsed = mach_continuous_time() - begin;
    source->probeTicks.fetch_add(elapsed, std::memory_order_relaxed);
    source->probeBlocks.fetch_add(1, std::memory_order_relaxed);
    DYYYUpdateMax(source->maxProbeTicks, elapsed);
}

static void DYYYRecordCallbackActivity(DYYYSource *source, uint32_t frames, OSStatus status) {
    if (!source || !DYYYTapEnabled.load(std::memory_order_relaxed)) return;
    uint64_t now = mach_continuous_time();
    source->hits.fetch_add(1, std::memory_order_relaxed);
    source->frames.fetch_add(frames, std::memory_order_relaxed);
    source->lastTicks.store(now, std::memory_order_relaxed);
    source->lastStatus.store(status, std::memory_order_relaxed);
    if (!DYYYCaptureActive.load(std::memory_order_relaxed)) return;

    uint64_t zero = 0;
    source->firstCallbackTicks.compare_exchange_strong(zero, now, std::memory_order_relaxed);
    uint64_t previous = source->previousCallbackTicks.exchange(now, std::memory_order_relaxed);
    if (previous == 0 || now <= previous) return;
    uint64_t interval = now - previous;
    source->callbackIntervalCount.fetch_add(1, std::memory_order_relaxed);
    source->callbackIntervalTicks.fetch_add(interval, std::memory_order_relaxed);
    DYYYUpdateMinNonZero(source->minCallbackIntervalTicks, interval);
    DYYYUpdateMax(source->maxCallbackIntervalTicks, interval);

    AudioStreamBasicDescription format = {};
    if (!DYYYReadSourceFormat(source, &format) || format.mSampleRate <= 0 || frames == 0) return;
    uint64_t expected = DYYYNanosecondsToTicks((uint64_t)llround((double)frames / format.mSampleRate * 1.0e9));
    if (expected == 0 || interval <= expected + expected / 2) return;
    uint64_t periods = interval / expected;
    if (periods > 1) {
        source->estimatedDroppedFrames.fetch_add((periods - 1) * frames, std::memory_order_relaxed);
    }
}

static void DYYYRecordEvent(uint32_t kind, DYYYSource *source, OSStatus status,
                          uintptr_t caller, uint64_t value1, uint64_t value2 = 0) {
    if (!DYYYTapEnabled.load(std::memory_order_relaxed)) return;
    uint32_t index = DYYYEventCount.fetch_add(1, std::memory_order_relaxed);
    if (index >= kDYYYMaxEvents) {
        DYYYEventOverflow.fetch_add(1, std::memory_order_relaxed);
        return;
    }
    DYYYEvent *event = &DYYYEvents[index];
    event->kind = kind;
    event->sourceID = source ? source->sourceID : 0;
    event->status = status;
    event->ticks = mach_continuous_time();
    event->caller = caller;
    event->value1 = value1;
    event->value2 = value2;
    event->ready.store(1, std::memory_order_release);
}

static void DYYYHitSymbol(DYYYSymbolIndex index, OSStatus status, uintptr_t caller) {
    if (!DYYYTapEnabled.load(std::memory_order_relaxed)) return;
    DYYYSymbolCoverage &coverage = DYYYCoverage[index];
    uint64_t now = mach_continuous_time();
    if (coverage.hits.fetch_add(1, std::memory_order_relaxed) == 0) {
        coverage.firstTicks.store(now, std::memory_order_relaxed);
        coverage.firstCaller.store(caller, std::memory_order_relaxed);
    }
    coverage.lastTicks.store(now, std::memory_order_relaxed);
    coverage.lastCaller.store(caller, std::memory_order_relaxed);
    coverage.lastStatus.store(status, std::memory_order_relaxed);
}

// MARK: - PCM 写入（实时路径）

static int DYYYClaimCaptureSlot(DYYYSource *source, const AudioStreamBasicDescription &format) {
    int existing = source->captureSlot.load(std::memory_order_acquire);
    if (existing >= 0) return existing;
    for (uint32_t i = 0; i < kDYYYCaptureSlots; i++) {
        int expected = 0;
        int reservation = -(int)source->sourceID;
        if (DYYYPCMSlots[i].sourceID.compare_exchange_strong(expected, reservation,
                                                           std::memory_order_acq_rel)) {
            DYYYPCMSlots[i].format = format;
            DYYYPCMSlots[i].sourceID.store((int)source->sourceID, std::memory_order_release);
            source->captureSlot.store((int)i, std::memory_order_release);
            return (int)i;
        }
        if (expected == (int)source->sourceID) {
            source->captureSlot.store((int)i, std::memory_order_release);
            return (int)i;
        }
    }
    return -1;
}

static bool DYYYFormatCanConvert(const AudioStreamBasicDescription &format) {
    if (format.mFormatID != kAudioFormatLinearPCM || format.mChannelsPerFrame == 0 ||
        format.mSampleRate <= 0 || format.mSampleRate > kDYYYMaxSampleRate ||
        (format.mFormatFlags & kAudioFormatFlagIsBigEndian) ||
        !(format.mFormatFlags & kAudioFormatFlagIsPacked)) return false;
    if ((format.mFormatFlags & kAudioFormatFlagIsFloat) &&
        (format.mBitsPerChannel == 32 || format.mBitsPerChannel == 64)) return true;
    if ((format.mFormatFlags & kAudioFormatFlagIsSignedInteger) &&
        (format.mBitsPerChannel == 16 || format.mBitsPerChannel == 32)) return true;
    return false;
}

static bool DYYYFormatsMatch(const AudioStreamBasicDescription &l,
                           const AudioStreamBasicDescription &r) {
    return fabs(l.mSampleRate - r.mSampleRate) < 0.001 && l.mFormatID == r.mFormatID &&
           l.mFormatFlags == r.mFormatFlags && l.mBytesPerFrame == r.mBytesPerFrame &&
           l.mChannelsPerFrame == r.mChannelsPerFrame && l.mBitsPerChannel == r.mBitsPerChannel;
}

static uint32_t DYYYCaptureBuffer(DYYYSource *source, const AudioBufferList *bufferList,
                                uint32_t frameCount) {
    if (!source || !bufferList || frameCount == 0 ||
        !DYYYCaptureActive.load(std::memory_order_relaxed)) return 0;

    uint64_t now = mach_continuous_time();
    if (now < DYYYPCMStartTicks.load(std::memory_order_relaxed) ||
        now >= DYYYPCMStopTicks.load(std::memory_order_relaxed)) return 0;
    uint64_t begin = now;

    AudioStreamBasicDescription format = {};
    if (!DYYYReadSourceFormat(source, &format) || !DYYYFormatCanConvert(format)) {
        source->unsupportedBuffers.fetch_add(1, std::memory_order_relaxed);
        DYYYRecordProbeElapsed(source, begin);
        return 0;
    }

    int slotIndex = DYYYClaimCaptureSlot(source, format);
    if (slotIndex < 0 || !DYYYPCMSlots[slotIndex].samples) {
        source->captureSlotMisses.fetch_add(1, std::memory_order_relaxed);
        DYYYRecordProbeElapsed(source, begin);
        return 0;
    }
    if (!DYYYFormatsMatch(DYYYPCMSlots[slotIndex].format, format)) {
        source->formatMismatchBuffers.fetch_add(1, std::memory_order_relaxed);
        DYYYRecordProbeElapsed(source, begin);
        return 0;
    }

    if (source->captureGuard.test_and_set(std::memory_order_acquire)) {
        source->contentionDrops.fetch_add(1, std::memory_order_relaxed);
        DYYYRecordProbeElapsed(source, begin);
        return 0;
    }
    DYYYActiveWriters.fetch_add(1, std::memory_order_relaxed);

    DYYYPCMSlot &slot = DYYYPCMSlots[slotIndex];
    uint64_t written = slot.frameCount.load(std::memory_order_relaxed);
    uint64_t available = written < kDYYYMaxPCMFrames ? kDYYYMaxPCMFrames - written : 0;
    uint32_t capacity = (uint32_t)std::min<uint64_t>(available, UINT32_MAX);
    if (capacity < frameCount) {
        source->pcmCapacityDroppedFrames.fetch_add(frameCount - capacity, std::memory_order_relaxed);
    }
    uint64_t unreadable = 0;
    uint32_t count = DYYYAudioSignalDownmix(bufferList, &format, frameCount,
                                          slot.samples + written, capacity, &unreadable);
    if (unreadable) source->unreadableFrames.fetch_add(unreadable, std::memory_order_relaxed);
    slot.frameCount.store(written + count, std::memory_order_release);

    DYYYRecordProbeElapsed(source, begin);
    DYYYActiveWriters.fetch_sub(1, std::memory_order_relaxed);
    source->captureGuard.clear(std::memory_order_release);
    return count;
}

// MARK: - 实时电平旁路

// 音频渲染线程执行。认领一个环槽位；抢不到（已满 4 路）就永久放弃，返回 -1。
static int DYYYClaimLiveRing(DYYYSource *source) {
    int ring = source->liveRing.load(std::memory_order_acquire);
    if (ring >= 0) return ring;
    if (ring < -1) return -1;                    // -2 表示试过且抢不到

    uint32_t claimed = DYYYLiveRingsClaimed.load(std::memory_order_relaxed);
    while (claimed < kDYYYLiveRings) {
        if (DYYYLiveRingsClaimed.compare_exchange_weak(claimed, claimed + 1,
                                                     std::memory_order_acq_rel,
                                                     std::memory_order_relaxed)) {
            source->liveWrite.store(0, std::memory_order_relaxed);
            source->liveRing.store((int)claimed, std::memory_order_release);
            return (int)claimed;
        }
    }
    source->liveRing.store(-2, std::memory_order_release);
    return -1;
}

// 音频渲染线程执行。下混一块进栈上缓冲，再拷进滚动环，顺手更新能量与时刻。
// 与 DYYYCaptureBuffer 各走各的：采集窗口开没开都不影响这里。
static void DYYYPublishLive(DYYYSource *source, const AudioBufferList *bufferList, uint32_t frameCount) {
    if (!source || !bufferList || frameCount == 0) return;
    if (!DYYYLiveEnabled.load(std::memory_order_relaxed)) return;

    AudioStreamBasicDescription format = {};
    if (!DYYYReadSourceFormat(source, &format) || !DYYYFormatCanConvert(format)) return;

    int ring = DYYYClaimLiveRing(source);
    if (ring < 0) return;

    float block[kDYYYLiveBlockFrames];
    uint32_t want = std::min(frameCount, kDYYYLiveBlockFrames);
    uint64_t unreadable = 0;
    uint32_t count = DYYYAudioSignalDownmix(bufferList, &format, want, block,
                                          kDYYYLiveBlockFrames, &unreadable);
    if (count == 0) return;

    uint64_t write = source->liveWrite.load(std::memory_order_relaxed);
    uint32_t head = (uint32_t)(write & kDYYYLiveRingMask);
    uint32_t first = std::min(count, kDYYYLiveRingFrames - head);
    memcpy(DYYYLiveRing[ring] + head, block, first * sizeof(float));
    if (count > first) memcpy(DYYYLiveRing[ring], block + first, (count - first) * sizeof(float));
    source->liveWrite.store(write + count, std::memory_order_release);

    double sum = 0.0;
    for (uint32_t i = 0; i < count; i++) sum += (double)block[i] * block[i];
    float rms = (float)sqrt(sum / count);
    // 选源用的能量：上升立刻跟上，下降留一点惯性，避免在块间抖动时来回换源。
    float previous = source->liveEnergy.load(std::memory_order_relaxed);
    source->liveEnergy.store(rms > previous ? rms : previous + (rms - previous) * 0.25f,
                             std::memory_order_relaxed);
    source->liveSampleRate.store(format.mSampleRate, std::memory_order_relaxed);
    source->liveTicks.store(mach_continuous_time(), std::memory_order_release);
}

// MARK: - 只读旁路

// 音频渲染线程执行。四条 relaxed store，记最近一次 ioData 的真实排布。
static void DYYYRecordBufferLayout(DYYYSource *source, const AudioBufferList *data, uint32_t frames) {
    if (!source || !data || data->mNumberBuffers == 0) return;
    const AudioBuffer &first = data->mBuffers[0];
    source->layoutNumberBuffers.store(data->mNumberBuffers, std::memory_order_relaxed);
    source->layoutChannelsPerBuffer.store(first.mNumberChannels, std::memory_order_relaxed);
    source->layoutDataByteSize.store(first.mDataByteSize, std::memory_order_relaxed);
    source->layoutRenderFrames.store(frames, std::memory_order_relaxed);
}

// 音频渲染线程执行。只在 PostRender 且无错误时读一次 ioData，然后原样返回。
static OSStatus DYYYRenderNotify(void *refCon,
                               AudioUnitRenderActionFlags *flags,
                               const AudioTimeStamp *timestamp,
                               UInt32 bus,
                               UInt32 frames,
                               AudioBufferList *data) {
    (void)timestamp;
    if (!flags || !(*flags & kAudioUnitRenderAction_PostRender)) return noErr;
    if (*flags & kAudioUnitRenderAction_PostRenderError) return noErr;
    if (bus != 0) return noErr;   // 输出单元的输出 element 固定为 0
    DYYYSource *source = (DYYYSource *)refCon;
    if (!source || !DYYYTapEnabled.load(std::memory_order_relaxed)) return noErr;
    DYYYRecordCallbackActivity(source, frames, noErr);
    if (data) {
        DYYYRecordBufferLayout(source, data, frames);
        DYYYPublishLive(source, data, frames);
        DYYYCaptureBuffer(source, data, frames);
    }
    return noErr;
}

// 输出单元送进 RemoteIO 的客户端格式在 Input scope element 0。必须在非实时线程读好。
static void DYYYCacheOutputUnitFormat(AudioUnit unit, DYYYSource *source) {
    if (!unit || !source) return;
    AudioStreamBasicDescription format = {};
    UInt32 size = sizeof(format);
    if (AudioUnitGetProperty(unit, kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input, 0, &format, &size) != noErr) return;
    if (format.mSampleRate <= 0 || format.mChannelsPerFrame == 0) return;
    AudioStreamBasicDescription current = {};
    if (DYYYReadSourceFormat(source, &current) && DYYYFormatsMatch(current, format)) return;
    DYYYWriteSourceFormat(source, &format);
    DYYYAppendFormatRecord(source, kAudioUnitScope_Input, &format);
}

static void DYYYInstallRenderNotify(AudioUnit unit, DYYYSource *source, uintptr_t caller) {
    if (!unit || !source) return;
    int expected = 0;
    if (!source->notifyInstalled.compare_exchange_strong(expected, 1, std::memory_order_acq_rel)) return;
    OSStatus status = AudioUnitAddRenderNotify(unit, DYYYRenderNotify, source);
    source->notifyStatus.store(status, std::memory_order_relaxed);
    if (status != noErr) source->notifyInstalled.store(0, std::memory_order_release);
    DYYYRecordEvent(DYYYEventRenderNotifyInstall, source, status, caller, (uintptr_t)unit);
}

static void DYYYRemoveRenderNotify(AudioUnit unit, DYYYSource *source) {
    if (!unit || !source) return;
    if (source->notifyInstalled.exchange(0, std::memory_order_acq_rel) == 0) return;
    AudioUnitRemoveRenderNotify(unit, DYYYRenderNotify, source);
}

// MARK: - 原始函数

static OSStatus (*DYYYOrigComponentNew)(AudioComponent, AudioComponentInstance *);
static OSStatus (*DYYYOrigComponentDispose)(AudioComponentInstance);
static OSStatus (*DYYYOrigUnitInitialize)(AudioUnit);
static OSStatus (*DYYYOrigOutputStart)(AudioUnit);
static OSStatus (*DYYYOrigOutputStop)(AudioUnit);
static OSStatus (*DYYYOrigQueueNewOutput)(const AudioStreamBasicDescription *, AudioQueueOutputCallback, void *, CFRunLoopRef, CFStringRef, UInt32, AudioQueueRef *);
static OSStatus (*DYYYOrigQueueNewOutputDispatch)(AudioQueueRef *, const AudioStreamBasicDescription *, UInt32, dispatch_queue_t, AudioQueueOutputCallbackBlock);
static OSStatus (*DYYYOrigQueueStart)(AudioQueueRef, const AudioTimeStamp *);
static OSStatus (*DYYYOrigQueueStop)(AudioQueueRef, Boolean);
static OSStatus (*DYYYOrigQueueDispose)(AudioQueueRef, Boolean);
static OSStatus (*DYYYOrigQueueEnqueue)(AudioQueueRef, AudioQueueBufferRef, UInt32, const AudioStreamPacketDescription *);
static OSStatus (*DYYYOrigTapCreate)(CFAllocatorRef, const MTAudioProcessingTapCallbacks *, MTAudioProcessingTapCreationFlags, MTAudioProcessingTapRef *);

// MARK: - 包装

static OSStatus DYYYHookComponentNew(AudioComponent component, AudioComponentInstance *instanceOut) {
    uintptr_t caller = DYYY_CALLER();
    OSStatus status = DYYYOrigComponentNew ? DYYYOrigComponentNew(component, instanceOut) : kAudio_ParamError;
    if (!DYYYTapEnabled.load(std::memory_order_relaxed)) return status;
    DYYYHitSymbol(DYYYSymbolComponentNew, status, caller);
    DYYYSource *source = nullptr;
    if (status == noErr && instanceOut && *instanceOut) {
        source = DYYYCreateSource((uintptr_t)*instanceOut, DYYYAudioTapSourceKindAudioUnit, nullptr);
        AudioComponentDescription description = {};
        if (source && component && AudioComponentGetDescription(component, &description) == noErr) {
            source->componentType = description.componentType;
            source->componentSubType = description.componentSubType;
            source->componentManufacturer = description.componentManufacturer;
        }
    }
    DYYYRecordEvent(DYYYEventComponentNew, source, status, caller,
                  instanceOut ? (uintptr_t)*instanceOut : 0);
    return status;
}

static OSStatus DYYYHookComponentDispose(AudioComponentInstance instance) {
    uintptr_t caller = DYYY_CALLER();
    DYYYSource *source = DYYYTapEnabled.load(std::memory_order_relaxed)
        ? DYYYFindSource((uintptr_t)instance, DYYYAudioTapSourceKindAudioUnit) : nullptr;
    // 必须在实例失效之前摘掉 notify，否则回调指针悬空。
    if (source) DYYYRemoveRenderNotify(instance, source);
    OSStatus status = DYYYOrigComponentDispose ? DYYYOrigComponentDispose(instance) : kAudio_ParamError;
    if (!DYYYTapEnabled.load(std::memory_order_relaxed)) return status;
    DYYYHitSymbol(DYYYSymbolComponentDispose, status, caller);
    if (source && status == noErr) {
        source->active.store(0, std::memory_order_relaxed);
        source->disposed.store(1, std::memory_order_relaxed);
    }
    DYYYRecordEvent(DYYYEventComponentDispose, source, status, caller, (uintptr_t)instance);
    return status;
}

static OSStatus DYYYHookUnitInitialize(AudioUnit unit) {
    OSStatus status = DYYYOrigUnitInitialize ? DYYYOrigUnitInitialize(unit) : kAudio_ParamError;
    if (!DYYYTapEnabled.load(std::memory_order_relaxed)) return status;
    uintptr_t caller = DYYY_CALLER();
    DYYYHitSymbol(DYYYSymbolUnitInitialize, status, caller);
    DYYYSource *source = DYYYFindSource((uintptr_t)unit, DYYYAudioTapSourceKindAudioUnit);
    if (source && status == noErr) DYYYCacheOutputUnitFormat(unit, source);
    DYYYRecordEvent(DYYYEventUnitInitialize, source, status, caller, (uintptr_t)unit);
    return status;
}

static OSStatus DYYYHookOutputStart(AudioUnit unit) {
    OSStatus status = DYYYOrigOutputStart ? DYYYOrigOutputStart(unit) : kAudio_ParamError;
    if (!DYYYTapEnabled.load(std::memory_order_relaxed)) return status;
    uintptr_t caller = DYYY_CALLER();
    DYYYHitSymbol(DYYYSymbolOutputStart, status, caller);
    // 只有被 AudioOutputUnitStart 启动过的实例才是输出单元，也只有它值得挂旁路。
    DYYYSource *source = DYYYCreateSource((uintptr_t)unit, DYYYAudioTapSourceKindAudioUnit, nullptr);
    if (source && status == noErr) {
        source->active.store(1, std::memory_order_relaxed);
        DYYYCacheOutputUnitFormat(unit, source);
        DYYYInstallRenderNotify(unit, source, caller);
    }
    if (source) source->lastStatus.store(status, std::memory_order_relaxed);
    DYYYRecordEvent(DYYYEventOutputStart, source, status, caller, (uintptr_t)unit);
    return status;
}

static OSStatus DYYYHookOutputStop(AudioUnit unit) {
    OSStatus status = DYYYOrigOutputStop ? DYYYOrigOutputStop(unit) : kAudio_ParamError;
    if (!DYYYTapEnabled.load(std::memory_order_relaxed)) return status;
    uintptr_t caller = DYYY_CALLER();
    DYYYHitSymbol(DYYYSymbolOutputStop, status, caller);
    DYYYSource *source = DYYYFindSource((uintptr_t)unit, DYYYAudioTapSourceKindAudioUnit);
    // notify 留着：同一只 unit 常被反复启停，重复装卸没有收益。
    if (source && status == noErr) source->active.store(0, std::memory_order_relaxed);
    DYYYRecordEvent(DYYYEventOutputStop, source, status, caller, (uintptr_t)unit);
    return status;
}

static OSStatus DYYYHookQueueNewOutput(const AudioStreamBasicDescription *format,
                                     AudioQueueOutputCallback callback,
                                     void *userData,
                                     CFRunLoopRef runLoop,
                                     CFStringRef mode,
                                     UInt32 flags,
                                     AudioQueueRef *queueOut) {
    uintptr_t caller = DYYY_CALLER();
    OSStatus status = DYYYOrigQueueNewOutput
        ? DYYYOrigQueueNewOutput(format, callback, userData, runLoop, mode, flags, queueOut)
        : kAudio_ParamError;
    if (!DYYYTapEnabled.load(std::memory_order_relaxed)) return status;
    DYYYHitSymbol(DYYYSymbolQueueNewOutput, status, caller);
    DYYYSource *source = status == noErr && queueOut && *queueOut
        ? DYYYCreateSource((uintptr_t)*queueOut, DYYYAudioTapSourceKindAudioQueue, format) : nullptr;
    DYYYRecordEvent(DYYYEventQueueNew, source, status, caller, queueOut ? (uintptr_t)*queueOut : 0, flags);
    return status;
}

static OSStatus DYYYHookQueueNewOutputDispatch(AudioQueueRef *queueOut,
                                             const AudioStreamBasicDescription *format,
                                             UInt32 flags,
                                             dispatch_queue_t queue,
                                             AudioQueueOutputCallbackBlock block) {
    uintptr_t caller = DYYY_CALLER();
    OSStatus status = DYYYOrigQueueNewOutputDispatch
        ? DYYYOrigQueueNewOutputDispatch(queueOut, format, flags, queue, block) : kAudio_ParamError;
    if (!DYYYTapEnabled.load(std::memory_order_relaxed)) return status;
    DYYYHitSymbol(DYYYSymbolQueueNewOutputDispatch, status, caller);
    DYYYSource *source = status == noErr && queueOut && *queueOut
        ? DYYYCreateSource((uintptr_t)*queueOut, DYYYAudioTapSourceKindAudioQueue, format) : nullptr;
    DYYYRecordEvent(DYYYEventQueueNew, source, status, caller, queueOut ? (uintptr_t)*queueOut : 0, flags);
    return status;
}

static OSStatus DYYYHookQueueStart(AudioQueueRef queue, const AudioTimeStamp *time) {
    OSStatus status = DYYYOrigQueueStart ? DYYYOrigQueueStart(queue, time) : kAudio_ParamError;
    if (!DYYYTapEnabled.load(std::memory_order_relaxed)) return status;
    uintptr_t caller = DYYY_CALLER();
    DYYYHitSymbol(DYYYSymbolQueueStart, status, caller);
    DYYYSource *source = DYYYFindSource((uintptr_t)queue, DYYYAudioTapSourceKindAudioQueue);
    if (source && status == noErr) source->active.store(1, std::memory_order_relaxed);
    DYYYRecordEvent(DYYYEventQueueStart, source, status, caller, (uintptr_t)queue);
    return status;
}

static OSStatus DYYYHookQueueStop(AudioQueueRef queue, Boolean immediate) {
    OSStatus status = DYYYOrigQueueStop ? DYYYOrigQueueStop(queue, immediate) : kAudio_ParamError;
    if (!DYYYTapEnabled.load(std::memory_order_relaxed)) return status;
    uintptr_t caller = DYYY_CALLER();
    DYYYHitSymbol(DYYYSymbolQueueStop, status, caller);
    DYYYSource *source = DYYYFindSource((uintptr_t)queue, DYYYAudioTapSourceKindAudioQueue);
    if (source && status == noErr) source->active.store(0, std::memory_order_relaxed);
    DYYYRecordEvent(DYYYEventQueueStop, source, status, caller, (uintptr_t)queue, immediate);
    return status;
}

static OSStatus DYYYHookQueueDispose(AudioQueueRef queue, Boolean immediate) {
    OSStatus status = DYYYOrigQueueDispose ? DYYYOrigQueueDispose(queue, immediate) : kAudio_ParamError;
    if (!DYYYTapEnabled.load(std::memory_order_relaxed)) return status;
    uintptr_t caller = DYYY_CALLER();
    DYYYHitSymbol(DYYYSymbolQueueDispose, status, caller);
    DYYYSource *source = DYYYFindSource((uintptr_t)queue, DYYYAudioTapSourceKindAudioQueue);
    if (source && status == noErr) {
        source->active.store(0, std::memory_order_relaxed);
        source->disposed.store(1, std::memory_order_relaxed);
    }
    DYYYRecordEvent(DYYYEventQueueDispose, source, status, caller, (uintptr_t)queue, immediate);
    return status;
}

// AudioQueue 走的是「入队即将播放的缓冲」，比 AudioUnit 旁路多一个缓冲的延迟，
// 但同样不改数据。这条是 AudioUnit 路径不成立时的兜底取样口。
static OSStatus DYYYHookQueueEnqueue(AudioQueueRef queue,
                                   AudioQueueBufferRef buffer,
                                   UInt32 packetCount,
                                   const AudioStreamPacketDescription *packets) {
    if (!DYYYTapEnabled.load(std::memory_order_relaxed)) {
        return DYYYOrigQueueEnqueue ? DYYYOrigQueueEnqueue(queue, buffer, packetCount, packets)
                                  : kAudio_ParamError;
    }
    uintptr_t caller = DYYY_CALLER();
    DYYYSource *source = DYYYFindSource((uintptr_t)queue, DYYYAudioTapSourceKindAudioQueue);
    uint32_t frames = 0;
    if (source && buffer && buffer->mAudioData && buffer->mAudioDataByteSize > 0) {
        AudioStreamBasicDescription format = {};
        if (DYYYReadSourceFormat(source, &format) && format.mBytesPerFrame > 0) {
            frames = buffer->mAudioDataByteSize / format.mBytesPerFrame;
            struct {
                UInt32 count;
                AudioBuffer buffer;
            } list = { 1, { format.mChannelsPerFrame, buffer->mAudioDataByteSize, buffer->mAudioData } };
            DYYYCaptureBuffer(source, (const AudioBufferList *)&list, frames);
        }
    }
    OSStatus status = DYYYOrigQueueEnqueue
        ? DYYYOrigQueueEnqueue(queue, buffer, packetCount, packets) : kAudio_ParamError;
    DYYYHitSymbol(DYYYSymbolQueueEnqueue, status, caller);
    if (source) DYYYRecordCallbackActivity(source, frames, status);
    if (DYYYCaptureActive.load(std::memory_order_relaxed)) {
        DYYYRecordEvent(DYYYEventQueueEnqueue, source, status, caller,
                      buffer ? buffer->mAudioDataByteSize : 0, packetCount);
    }
    return status;
}

// 只登记「有没有人用 AVPlayer 的音频 tap」，不接管它的 process 回调。
static OSStatus DYYYHookTapCreate(CFAllocatorRef allocator,
                                const MTAudioProcessingTapCallbacks *callbacks,
                                MTAudioProcessingTapCreationFlags flags,
                                MTAudioProcessingTapRef *tapOut) {
    uintptr_t caller = DYYY_CALLER();
    OSStatus status = DYYYOrigTapCreate ? DYYYOrigTapCreate(allocator, callbacks, flags, tapOut)
                                      : kAudio_ParamError;
    if (!DYYYTapEnabled.load(std::memory_order_relaxed)) return status;
    DYYYHitSymbol(DYYYSymbolTapCreate, status, caller);
    DYYYSource *source = status == noErr && tapOut && *tapOut
        ? DYYYCreateSource((uintptr_t)*tapOut, DYYYAudioTapSourceKindMediaTap, nullptr) : nullptr;
    DYYYRecordEvent(DYYYEventMediaTapCreate, source, status, caller,
                  tapOut ? (uintptr_t)*tapOut : 0, flags);
    return status;
}

static void DYYYInstallRebindings(void) {
    for (uint32_t i = 0; i < DYYYSymbolCount; i++) {
        DYYYCoverage[i].original = dlsym(RTLD_DEFAULT, DYYYSymbolNames[i]);
        DYYYCoverage[i].rebindResult = -1;
    }
#define DYYY_RESOLVE(VAR, INDEX) VAR = reinterpret_cast<decltype(VAR)>(DYYYCoverage[INDEX].original)
    DYYY_RESOLVE(DYYYOrigComponentNew, DYYYSymbolComponentNew);
    DYYY_RESOLVE(DYYYOrigComponentDispose, DYYYSymbolComponentDispose);
    DYYY_RESOLVE(DYYYOrigUnitInitialize, DYYYSymbolUnitInitialize);
    DYYY_RESOLVE(DYYYOrigOutputStart, DYYYSymbolOutputStart);
    DYYY_RESOLVE(DYYYOrigOutputStop, DYYYSymbolOutputStop);
    DYYY_RESOLVE(DYYYOrigQueueNewOutput, DYYYSymbolQueueNewOutput);
    DYYY_RESOLVE(DYYYOrigQueueNewOutputDispatch, DYYYSymbolQueueNewOutputDispatch);
    DYYY_RESOLVE(DYYYOrigQueueStart, DYYYSymbolQueueStart);
    DYYY_RESOLVE(DYYYOrigQueueStop, DYYYSymbolQueueStop);
    DYYY_RESOLVE(DYYYOrigQueueDispose, DYYYSymbolQueueDispose);
    DYYY_RESOLVE(DYYYOrigQueueEnqueue, DYYYSymbolQueueEnqueue);
    DYYY_RESOLVE(DYYYOrigTapCreate, DYYYSymbolTapCreate);
#undef DYYY_RESOLVE

    struct dyyy_rebinding bindings[DYYYSymbolCount] = {
        { DYYYSymbolNames[DYYYSymbolComponentNew], (void *)DYYYHookComponentNew, nullptr },
        { DYYYSymbolNames[DYYYSymbolComponentDispose], (void *)DYYYHookComponentDispose, nullptr },
        { DYYYSymbolNames[DYYYSymbolUnitInitialize], (void *)DYYYHookUnitInitialize, nullptr },
        { DYYYSymbolNames[DYYYSymbolOutputStart], (void *)DYYYHookOutputStart, nullptr },
        { DYYYSymbolNames[DYYYSymbolOutputStop], (void *)DYYYHookOutputStop, nullptr },
        { DYYYSymbolNames[DYYYSymbolQueueNewOutput], (void *)DYYYHookQueueNewOutput, nullptr },
        { DYYYSymbolNames[DYYYSymbolQueueNewOutputDispatch], (void *)DYYYHookQueueNewOutputDispatch, nullptr },
        { DYYYSymbolNames[DYYYSymbolQueueStart], (void *)DYYYHookQueueStart, nullptr },
        { DYYYSymbolNames[DYYYSymbolQueueStop], (void *)DYYYHookQueueStop, nullptr },
        { DYYYSymbolNames[DYYYSymbolQueueDispose], (void *)DYYYHookQueueDispose, nullptr },
        { DYYYSymbolNames[DYYYSymbolQueueEnqueue], (void *)DYYYHookQueueEnqueue, nullptr },
        { DYYYSymbolNames[DYYYSymbolTapCreate], (void *)DYYYHookTapCreate, nullptr },
    };
    int result = dyyy_rebind_symbols(bindings, DYYYSymbolCount);
    for (uint32_t i = 0; i < DYYYSymbolCount; i++) DYYYCoverage[i].rebindResult = result;
}

// MARK: - 对外接口

void DYYYAudioTapInstall(void) {
    bool expected = false;
    if (!DYYYTapInstalled.compare_exchange_strong(expected, true, std::memory_order_acq_rel)) return;
    mach_timebase_info(&DYYYTimebase);
    DYYYInstallRebindings();
}

void DYYYAudioTapSetEnabled(BOOL enabled) {
    DYYYTapEnabled.store(enabled, std::memory_order_release);
    if (!enabled) DYYYCaptureActive.store(false, std::memory_order_release);
}

// MARK: - 实时电平旁路（读侧，主线程）

void DYYYAudioTapSetLiveMeteringEnabled(BOOL enabled) {
    DYYYLiveEnabled.store(enabled, std::memory_order_release);
}

BOOL DYYYAudioTapIsLiveMeteringEnabled(void) {
    return DYYYLiveEnabled.load(std::memory_order_acquire);
}

// 挑当前最响、且还在活动的那一路。
//
// beta2 实测抖音同时跑两只 RemoteIO，其中一只全程恒零——取"第一路"会永远画不出东西，
// 必须按能量选。staleSeconds 之外的源不参选，否则一首歌停了还会锁在旧源上。
static DYYYSource *DYYYLoudestLiveSource(double staleSeconds, uint64_t now) {
    uint32_t count = DYYYSourceCount.load(std::memory_order_acquire);
    DYYYSource *best = nullptr;
    float bestEnergy = -1.0f;
    for (uint32_t i = 0; i < count; i++) {
        DYYYSource *source = &DYYYSources[i];
        if (source->liveRing.load(std::memory_order_acquire) < 0) continue;
        uint64_t ticks = source->liveTicks.load(std::memory_order_acquire);
        if (ticks == 0 || now < ticks) continue;
        if (DYYYTicksToSeconds(now - ticks) > staleSeconds) continue;
        float energy = source->liveEnergy.load(std::memory_order_relaxed);
        if (energy > bestEnergy) { bestEnergy = energy; best = source; }
    }
    return best;
}

uint32_t DYYYAudioTapCopyLatestSamples(float *out, uint32_t count, double *sampleRateOut) {
    if (!out || count == 0 || count > kDYYYLiveRingFrames) return 0;
    if (!DYYYLiveEnabled.load(std::memory_order_acquire)) return 0;

    DYYYSource *source = DYYYLoudestLiveSource(0.25, mach_continuous_time());
    if (!source) return 0;
    int ring = source->liveRing.load(std::memory_order_acquire);
    if (ring < 0 || ring >= (int)kDYYYLiveRings) return 0;

    uint64_t before = source->liveWrite.load(std::memory_order_acquire);
    if (before < count) return 0;                 // 环还没填满一个分析窗

    uint32_t start = (uint32_t)((before - count) & kDYYYLiveRingMask);
    uint32_t first = std::min(count, kDYYYLiveRingFrames - start);
    memcpy(out, DYYYLiveRing[ring] + start, first * sizeof(float));
    if (count > first) memcpy(out + first, DYYYLiveRing[ring], (count - first) * sizeof(float));

    // 拷贝期间实时侧可能已经绕回来盖掉了我们正在读的那一段。复读游标判定：
    // 写入前进超过"环长 − 窗长"就说明被追上了，这一帧直接丢（60 Hz 下看不出来）。
    uint64_t after = source->liveWrite.load(std::memory_order_acquire);
    if (after - before > kDYYYLiveRingFrames - count) return 0;

    if (sampleRateOut) {
        double rate = source->liveSampleRate.load(std::memory_order_relaxed);
        *sampleRateOut = rate > 0 ? rate : 48000.0;
    }
    return count;
}

BOOL DYYYAudioTapHasRecentAudio(double withinSeconds) {
    if (!DYYYLiveEnabled.load(std::memory_order_acquire)) return NO;
    return DYYYLoudestLiveSource(withinSeconds, mach_continuous_time()) != nullptr;
}

BOOL DYYYAudioTapIsInstalled(void) {
    return DYYYTapInstalled.load(std::memory_order_acquire);
}

BOOL DYYYAudioTapIsCapturing(void) {
    return DYYYCaptureActive.load(std::memory_order_acquire);
}

uint64_t DYYYAudioTapCaptureStartTicks(void) {
    return DYYYCaptureStartTicks.load(std::memory_order_acquire);
}

uint64_t DYYYAudioTapCaptureStopTicks(void) {
    return DYYYCaptureStopTicks.load(std::memory_order_acquire);
}

double DYYYAudioTapSecondsFromTicks(uint64_t ticks) {
    return DYYYTicksToSeconds(ticks);
}

double DYYYAudioTapSecondsRelativeTo(uint64_t ticks, uint64_t origin) {
    return DYYYRelativeSeconds(ticks, origin);
}

double DYYYAudioTapCurrentCaptureSecond(void) {
    uint64_t start = DYYYCaptureStartTicks.load(std::memory_order_acquire);
    return start ? DYYYRelativeSeconds(mach_continuous_time(), start) : -1.0;
}

BOOL DYYYAudioTapBeginCapture(double warmupSeconds, double recordSeconds) {
    if (!DYYYTapInstalled.load(std::memory_order_acquire) ||
        !DYYYTapEnabled.load(std::memory_order_acquire) ||
        warmupSeconds < 0 || recordSeconds <= 0 || recordSeconds > kDYYYMaxPCMSeconds) return NO;

    os_unfair_lock_lock(&DYYYCaptureControlLock);
    if (DYYYCaptureActive.load(std::memory_order_acquire)) {
        os_unfair_lock_unlock(&DYYYCaptureControlLock);
        return NO;
    }

    DYYYCaptureStartTicks.store(0, std::memory_order_release);
    DYYYCaptureStopTicks.store(0, std::memory_order_release);
    DYYYPCMAllocationFailures.store(0, std::memory_order_relaxed);
    BOOL anySlot = NO;
    for (uint32_t i = 0; i < kDYYYCaptureSlots; i++) {
        if (!DYYYPCMSlots[i].samples) DYYYPCMSlots[i].samples = (float *)calloc(kDYYYMaxPCMFrames, sizeof(float));
        if (DYYYPCMSlots[i].samples) anySlot = YES;
        else DYYYPCMAllocationFailures.fetch_add(1, std::memory_order_relaxed);
        DYYYPCMSlots[i].sourceID.store(0, std::memory_order_relaxed);
        DYYYPCMSlots[i].frameCount.store(0, std::memory_order_relaxed);
        DYYYPCMSlots[i].format = {};
    }
    if (!anySlot) {
        os_unfair_lock_unlock(&DYYYCaptureControlLock);
        return NO;
    }

    uint32_t sourceCount = DYYYSourceCount.load(std::memory_order_acquire);
    for (uint32_t i = 0; i < sourceCount; i++) {
        DYYYSource &source = DYYYSources[i];
        source.captureSlot.store(-1, std::memory_order_relaxed);
        source.firstCallbackTicks.store(0, std::memory_order_relaxed);
        source.previousCallbackTicks.store(0, std::memory_order_relaxed);
        source.callbackIntervalCount.store(0, std::memory_order_relaxed);
        source.callbackIntervalTicks.store(0, std::memory_order_relaxed);
        source.minCallbackIntervalTicks.store(0, std::memory_order_relaxed);
        source.maxCallbackIntervalTicks.store(0, std::memory_order_relaxed);
        source.estimatedDroppedFrames.store(0, std::memory_order_relaxed);
        source.contentionDrops.store(0, std::memory_order_relaxed);
        source.unsupportedBuffers.store(0, std::memory_order_relaxed);
        source.unreadableFrames.store(0, std::memory_order_relaxed);
        source.captureSlotMisses.store(0, std::memory_order_relaxed);
        source.formatMismatchBuffers.store(0, std::memory_order_relaxed);
        source.pcmCapacityDroppedFrames.store(0, std::memory_order_relaxed);
        source.probeTicks.store(0, std::memory_order_relaxed);
        source.probeBlocks.store(0, std::memory_order_relaxed);
        source.maxProbeTicks.store(0, std::memory_order_relaxed);
    }

    uint64_t start = mach_continuous_time();
    uint64_t pcmStart = start + DYYYNanosecondsToTicks((uint64_t)(warmupSeconds * 1.0e9));
    DYYYCaptureStartTicks.store(start, std::memory_order_release);
    DYYYPCMStartTicks.store(pcmStart, std::memory_order_release);
    DYYYPCMStopTicks.store(pcmStart + DYYYNanosecondsToTicks((uint64_t)(recordSeconds * 1.0e9)),
                         std::memory_order_release);
    DYYYCaptureActive.store(true, std::memory_order_release);
    os_unfair_lock_unlock(&DYYYCaptureControlLock);
    return YES;
}

void DYYYAudioTapEndCapture(void) {
    DYYYCaptureActive.store(false, std::memory_order_release);
    uint64_t zero = 0;
    DYYYCaptureStopTicks.compare_exchange_strong(zero, mach_continuous_time(),
                                               std::memory_order_release,
                                               std::memory_order_relaxed);
}

void DYYYAudioTapWaitForWriters(void) {
    for (int attempt = 0; attempt < 100 && DYYYActiveWriters.load(std::memory_order_acquire) > 0; attempt++) {
        usleep(1000);
    }
}

uint32_t DYYYAudioTapSlotCount(void) {
    return kDYYYCaptureSlots;
}

BOOL DYYYAudioTapReadSlot(uint32_t index, DYYYAudioTapSlot *out) {
    if (index >= kDYYYCaptureSlots || !out) return NO;
    int sourceID = DYYYPCMSlots[index].sourceID.load(std::memory_order_acquire);
    uint64_t frames = DYYYPCMSlots[index].frameCount.load(std::memory_order_acquire);
    if (sourceID <= 0 || frames == 0 || !DYYYPCMSlots[index].samples) return NO;
    out->sourceID = (uint32_t)sourceID;
    out->kind = (uint32_t)sourceID <= kDYYYMaxSources ? DYYYSources[sourceID - 1].kind : 0;
    out->samples = DYYYPCMSlots[index].samples;
    out->frameCount = frames;
    out->sampleRate = DYYYPCMSlots[index].format.mSampleRate;
    out->sourceFormat = DYYYPCMSlots[index].format;
    return YES;
}
