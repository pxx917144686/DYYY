//
//  DYYYAudioAnalysis.mm
//  DYYY
//
//  纯音频数据转换与离线信号分析（DYYYAudioSignal*）+ 主线程电平分析（DYYYAudioLevels*）。
//  实时侧入口 DYYYAudioSignalDownmix 只用栈上定长缓冲，无任何分配。
//

#import "DYYYUtilsAudio.h"

#import <Accelerate/Accelerate.h>

#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstring>
#include <vector>

#pragma mark - DYYYAudioSignal

static vDSP_DFT_Setup DYYYAudioDFTSetup(void) {
    static vDSP_DFT_Setup setup;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        setup = vDSP_DFT_zop_CreateSetup(nullptr, 1024, vDSP_DFT_FORWARD);
    });
    return setup;
}

void *DYYYAudioSignalDFTSetup1024(void) {
    return (void *)DYYYAudioDFTSetup();
}

// 一次下混里最多认多少个 buffer。7.1 非交错也只有 8 个；栈上定长，实时侧无分配。
static const uint32_t kDYYYMaxBuffersPerList = 8;

// 从 AudioBuffer 自身量出来的排布：起始地址、每帧跨距、该 buffer 内的交错度、真实帧数。
struct DYYYBufferPlane {
    const uint8_t *bytes;
    uint32_t stride;
    uint32_t channels;
    uint32_t frames;
};

static float DYYYAudioReadSample(const uint8_t *bytes, uint32_t bits, bool isFloat) {
    if (isFloat && bits == 32) {
        float value = 0;
        memcpy(&value, bytes, sizeof(value));
        return std::isfinite(value) ? value : 0.0f;
    }
    if (isFloat && bits == 64) {
        double value = 0;
        memcpy(&value, bytes, sizeof(value));
        return std::isfinite(value) ? (float)value : 0.0f;
    }
    if (bits == 16) {
        int16_t value = 0;
        memcpy(&value, bytes, sizeof(value));
        return (float)value / 32768.0f;
    }
    if (bits == 32) {
        int32_t value = 0;
        memcpy(&value, bytes, sizeof(value));
        return (float)((double)value / 2147483648.0);
    }
    return 0.0f;
}

uint32_t DYYYAudioSignalDownmix(const AudioBufferList *bufferList,
                              const AudioStreamBasicDescription *format,
                              uint32_t frameCount,
                              float *output,
                              uint32_t outputCapacity,
                              uint64_t *unreadableFrames) {
    if (!bufferList || !format || !output || frameCount == 0 || outputCapacity == 0) return 0;
    uint32_t count = std::min(frameCount, outputCapacity);
    bool isFloat = (format->mFormatFlags & kAudioFormatFlagIsFloat) != 0;
    uint32_t bytesPerSample = format->mBitsPerChannel / 8;
    if (bytesPerSample == 0) return 0;

    // 布局只信 AudioBufferList 自己，不看 ASBD 的 kAudioFormatFlagIsNonInterleaved。
    //
    // 0.5.2-beta2 实测：AudioUnitGetProperty(kAudioUnitScope_Input, 0) 读到的是【客户端推进去】
    // 的格式（交错、mBytesPerFrame=8），而 render notify 的 ioData 是 unit 填完之后的布局
    // （非交错，2 buffer × 4096 字节）。按 ASBD 的交错位跨 8 字节读 mBuffers[0]，第 512 帧起
    // 越过 4096 边界，导出的 141 个块后半段全部归零——数据错得很安静。
    //
    // mNumberChannels 才是该 buffer 自身的交错度，mDataByteSize 才是它真实的长度；
    // ASBD 此后只提供位宽与 float/int。非交错、交错、混合（2 buffer × 2ch）由同一段代码覆盖。
    uint32_t buffers = std::min<uint32_t>(bufferList->mNumberBuffers, kDYYYMaxBuffersPerList);
    DYYYBufferPlane planes[kDYYYMaxBuffersPerList];
    uint32_t planeCount = 0;
    for (uint32_t i = 0; i < buffers; i++) {
        const AudioBuffer &buffer = bufferList->mBuffers[i];
        if (!buffer.mData || buffer.mDataByteSize < bytesPerSample) continue;
        uint32_t channels = buffer.mNumberChannels > 0
            ? buffer.mNumberChannels : std::max<uint32_t>(1, format->mChannelsPerFrame);
        uint32_t stride = channels * bytesPerSample;
        // 带填充的交错格式：单 buffer 且长度正好等于 frameCount × mBytesPerFrame 时，
        // mBytesPerFrame 才是可信的跨距（含填充）。其余一律按紧凑排布算。
        if (buffers == 1 && format->mBytesPerFrame > stride &&
            (uint64_t)buffer.mDataByteSize == (uint64_t)frameCount * format->mBytesPerFrame) {
            stride = format->mBytesPerFrame;
        }
        planes[planeCount++] = { (const uint8_t *)buffer.mData, stride, channels,
                                 buffer.mDataByteSize / stride };
    }

    for (uint32_t frame = 0; frame < count; frame++) {
        double mixed = 0.0;
        uint32_t readableChannels = 0;
        for (uint32_t i = 0; i < planeCount; i++) {
            const DYYYBufferPlane &plane = planes[i];
            if (frame >= plane.frames) continue;
            const uint8_t *base = plane.bytes + (uint64_t)frame * plane.stride;
            for (uint32_t channel = 0; channel < plane.channels; channel++) {
                mixed += DYYYAudioReadSample(base + (uint64_t)channel * bytesPerSample,
                                           format->mBitsPerChannel, isFloat);
                readableChannels++;
            }
        }
        output[frame] = readableChannels ? (float)(mixed / readableChannels) : 0.0f;
        if (!readableChannels && unreadableFrames) (*unreadableFrames)++;
    }
    return count;
}

NSData *DYYYAudioSignalFloatWAV(const float *samples, uint64_t frameCount, double sampleRate) {
    if (!samples || frameCount == 0 || sampleRate <= 0) return NSData.data;
    const uint32_t maximumDataSize = (UINT32_MAX - 44U) & ~(uint32_t)(sizeof(float) - 1U);
    uint32_t dataSize = (uint32_t)std::min<uint64_t>(frameCount * sizeof(float), maximumDataSize);
    uint32_t riffSize = 36 + dataSize;
    uint16_t formatCode = 3, channels = 1, blockAlign = sizeof(float), bits = 32;
    uint32_t rate = (uint32_t)llround(sampleRate), byteRate = rate * blockAlign;
    NSMutableData *data = [NSMutableData dataWithCapacity:44 + dataSize];
    [data appendBytes:"RIFF" length:4];
    [data appendBytes:&riffSize length:4];
    [data appendBytes:"WAVEfmt " length:8];
    uint32_t fmtSize = 16;
    [data appendBytes:&fmtSize length:4];
    [data appendBytes:&formatCode length:2];
    [data appendBytes:&channels length:2];
    [data appendBytes:&rate length:4];
    [data appendBytes:&byteRate length:4];
    [data appendBytes:&blockAlign length:2];
    [data appendBytes:&bits length:2];
    [data appendBytes:"data" length:4];
    [data appendBytes:&dataSize length:4];
    [data appendBytes:samples length:dataSize];
    return data;
}

NSDictionary *DYYYAudioSignalMetrics(const float *samples, uint64_t count) {
    if (!samples || count == 0) return @{ @"rms": @0, @"peak": @0, @"dc": @0, @"zeroCrossingRate": @0 };
    float rms = 0, peak = 0, dc = 0;
    vDSP_rmsqv(samples, 1, &rms, (vDSP_Length)count);
    vDSP_maxmgv(samples, 1, &peak, (vDSP_Length)count);
    vDSP_meanv(samples, 1, &dc, (vDSP_Length)count);
    uint64_t crossings = 0;
    for (uint64_t i = 1; i < count; i++) {
        if ((samples[i - 1] < 0 && samples[i] >= 0) ||
            (samples[i - 1] >= 0 && samples[i] < 0)) crossings++;
    }
    return @{ @"rms": @(rms), @"peak": @(peak), @"dc": @(dc),
              @"zeroCrossingRate": @((double)crossings / std::max<uint64_t>(1, count - 1)) };
}

NSArray<NSNumber *> *DYYYAudioSignalFrequencyBands(const float *samples,
                                                 uint64_t available,
                                                 double sampleRate) {
    const vDSP_Length size = 1024;
    if (!samples || available == 0 || sampleRate <= 0) return @[];
    std::vector<float> real(size, 0), imag(size, 0), outReal(size, 0), outImag(size, 0), window(size, 0);
    uint64_t copyCount = std::min<uint64_t>(available, size);
    memcpy(real.data(), samples, copyCount * sizeof(float));
    vDSP_hann_window(window.data(), size, vDSP_HANN_NORM);
    vDSP_vmul(real.data(), 1, window.data(), 1, real.data(), 1, size);
    vDSP_DFT_Setup setup = DYYYAudioDFTSetup();
    if (!setup) return @[];
    vDSP_DFT_Execute(setup, real.data(), imag.data(), outReal.data(), outImag.data());

    NSMutableArray<NSNumber *> *bands = [NSMutableArray arrayWithCapacity:32];
    const double minHz = 40.0, maxHz = std::max(minHz, sampleRate / 2.0);
    for (int band = 0; band < 32; band++) {
        double lowHz = minHz * pow(maxHz / minHz, (double)band / 32.0);
        double highHz = minHz * pow(maxHz / minHz, (double)(band + 1) / 32.0);
        uint32_t lowBin = (uint32_t)std::max(1.0, floor(lowHz * size / sampleRate));
        uint32_t highBin = (uint32_t)std::min<double>(size / 2, ceil(highHz * size / sampleRate));
        double sum = 0;
        uint32_t bins = 0;
        for (uint32_t bin = lowBin; bin < highBin; bin++) {
            sum += hypot(outReal[bin], outImag[bin]) / size;
            bins++;
        }
        [bands addObject:@(bins ? sum / bins : 0)];
    }
    return bands;
}

static BOOL DYYYAudioNear(double left, double right, double tolerance) {
    return fabs(left - right) <= tolerance;
}

NSDictionary *DYYYAudioSignalSyntheticValidation(void) {
    NSMutableDictionary *checks = [NSMutableDictionary dictionary];
    AudioStreamBasicDescription floatInterleaved = { 48000, kAudioFormatLinearPCM,
        kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked, 8, 1, 8, 2, 32, 0 };
    float floatSamples[] = { 1.0f, -1.0f, 0.5f, 0.5f, -0.25f, 0.75f };
    struct { UInt32 count; AudioBuffer buffer; } floatList = {
        1, { 2, sizeof(floatSamples), floatSamples }
    };
    float output[8] = {};
    uint64_t unreadable = 0;
    uint32_t written = DYYYAudioSignalDownmix((AudioBufferList *)&floatList, &floatInterleaved,
                                             3, output, 8, &unreadable);
    checks[@"float32Interleaved"] = @(written == 3 && unreadable == 0 &&
        DYYYAudioNear(output[0], 0, 0.00001) && DYYYAudioNear(output[1], 0.5, 0.00001) &&
        DYYYAudioNear(output[2], 0.25, 0.00001));

    AudioStreamBasicDescription floatPlanar = floatInterleaved;
    floatPlanar.mFormatFlags |= kAudioFormatFlagIsNonInterleaved;
    floatPlanar.mBytesPerFrame = 4;
    floatPlanar.mBytesPerPacket = 4;
    float left[] = { 1.0f, 0.25f }, right[] = { -0.5f, 0.75f };
    struct { UInt32 count; AudioBuffer buffers[2]; } planarList = {
        2, { { 1, sizeof(left), left }, { 1, sizeof(right), right } }
    };
    memset(output, 0, sizeof(output));
    written = DYYYAudioSignalDownmix((AudioBufferList *)&planarList, &floatPlanar, 2, output, 8, &unreadable);
    checks[@"float32NonInterleaved"] = @(written == 2 && DYYYAudioNear(output[0], 0.25, 0.00001) &&
        DYYYAudioNear(output[1], 0.5, 0.00001));

    AudioStreamBasicDescription int16Interleaved = { 44100, kAudioFormatLinearPCM,
        kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked, 4, 1, 4, 2, 16, 0 };
    int16_t integerSamples[] = { 32767, -32768, 16384, 16384 };
    struct { UInt32 count; AudioBuffer buffer; } integerList = {
        1, { 2, sizeof(integerSamples), integerSamples }
    };
    memset(output, 0, sizeof(output));
    written = DYYYAudioSignalDownmix((AudioBufferList *)&integerList, &int16Interleaved, 2, output, 8, &unreadable);
    checks[@"int16Interleaved"] = @(written == 2 && fabs(output[0]) < 0.0001 &&
        DYYYAudioNear(output[1], 0.5, 0.0001));

    AudioStreamBasicDescription int16Planar = int16Interleaved;
    int16Planar.mFormatFlags |= kAudioFormatFlagIsNonInterleaved;
    int16Planar.mBytesPerFrame = 2;
    int16Planar.mBytesPerPacket = 2;
    int16_t intLeft[] = { 32767, 0 }, intRight[] = { 0, -32768 };
    struct { UInt32 count; AudioBuffer buffers[2]; } intPlanarList = {
        2, { { 1, sizeof(intLeft), intLeft }, { 1, sizeof(intRight), intRight } }
    };
    memset(output, 0, sizeof(output));
    written = DYYYAudioSignalDownmix((AudioBufferList *)&intPlanarList, &int16Planar, 2, output, 8, &unreadable);
    checks[@"int16NonInterleaved"] = @(written == 2 && DYYYAudioNear(output[0], 0.5, 0.0001) &&
        DYYYAudioNear(output[1], -0.5, 0.0001));

    // 0.5.2-beta2 的设备现场：ASBD 说交错（mBytesPerFrame=8、无 NonInterleaved 位），
    // 而 ioData 实际是 2 buffer × 1 声道。上面两例的 ASBD 与 ABL 都是自洽的，所以漏了这条。
    // 旧实现在这里会读 mBuffers[0] 的相邻两个样本当作一帧的左右声道，并在越过 mDataByteSize
    // 之后把余下的帧全判为不可读——正是导出里「每 1024 帧块后 512 帧恒为 0」的成因。
    float mismatchLeft[] = { 1.0f, 0.5f, -1.0f, 0.0f };
    float mismatchRight[] = { 0.0f, 0.5f, 1.0f, 1.0f };
    struct { UInt32 count; AudioBuffer buffers[2]; } mismatchList = {
        2, { { 1, sizeof(mismatchLeft), mismatchLeft }, { 1, sizeof(mismatchRight), mismatchRight } }
    };
    memset(output, 0, sizeof(output));
    unreadable = 0;
    written = DYYYAudioSignalDownmix((AudioBufferList *)&mismatchList, &floatInterleaved,
                                    4, output, 8, &unreadable);
    checks[@"nonInterleavedBufferListWithInterleavedASBD"] = @(written == 4 && unreadable == 0 &&
        DYYYAudioNear(output[0], 0.5, 0.00001) && DYYYAudioNear(output[1], 0.5, 0.00001) &&
        DYYYAudioNear(output[2], 0, 0.00001) && DYYYAudioNear(output[3], 0.5, 0.00001));

    // 反向的一条：单 buffer、每帧带 4 字节填充。此时 mBytesPerFrame 才是真跨距，
    // 按「声道数 × 位宽」紧凑推会算错，故保留那条例外分支。
    AudioStreamBasicDescription paddedInterleaved = floatInterleaved;
    paddedInterleaved.mBytesPerFrame = 12;
    paddedInterleaved.mBytesPerPacket = 12;
    float paddedSamples[] = { 1.0f, 0.0f, 0.0f, 0.5f, 0.5f, 0.0f, -1.0f, 1.0f, 0.0f };
    struct { UInt32 count; AudioBuffer buffer; } paddedList = {
        1, { 2, sizeof(paddedSamples), paddedSamples }
    };
    memset(output, 0, sizeof(output));
    unreadable = 0;
    written = DYYYAudioSignalDownmix((AudioBufferList *)&paddedList, &paddedInterleaved,
                                    3, output, 8, &unreadable);
    checks[@"paddedInterleavedStride"] = @(written == 3 && unreadable == 0 &&
        DYYYAudioNear(output[0], 0.5, 0.00001) && DYYYAudioNear(output[1], 0.5, 0.00001) &&
        DYYYAudioNear(output[2], 0, 0.00001));

    float metricSamples[] = { 1.0f, -1.0f, 1.0f, -1.0f };
    NSDictionary *metrics = DYYYAudioSignalMetrics(metricSamples, 4);
    checks[@"metrics"] = @(DYYYAudioNear([metrics[@"rms"] doubleValue], 1, 0.00001) &&
        DYYYAudioNear([metrics[@"peak"] doubleValue], 1, 0.00001) &&
        DYYYAudioNear([metrics[@"dc"] doubleValue], 0, 0.00001));
    float silence[1024] = {};
    NSDictionary *silenceMetrics = DYYYAudioSignalMetrics(silence, 1024);
    checks[@"silence"] = @([silenceMetrics[@"rms"] doubleValue] == 0 &&
        [silenceMetrics[@"peak"] doubleValue] == 0);

    float sine[1024] = {};
    for (NSUInteger i = 0; i < 1024; i++) sine[i] = sinf((float)(2.0 * M_PI * 1000.0 * i / 48000.0));
    NSArray<NSNumber *> *bands = DYYYAudioSignalFrequencyBands(sine, 1024, 48000);
    NSUInteger strongestBand = 0;
    for (NSUInteger i = 1; i < bands.count; i++) if (bands[i].doubleValue > bands[strongestBand].doubleValue) strongestBand = i;
    checks[@"fft32Bands"] = @(bands.count == 32 && strongestBand >= 16 && strongestBand <= 20);

    NSData *wav = DYYYAudioSignalFloatWAV(metricSamples, 4, 48000);
    uint32_t wavDataSize = 0;
    if (wav.length >= 44) memcpy(&wavDataSize, (const uint8_t *)wav.bytes + 40, sizeof(wavDataSize));
    double wavDuration = (double)wavDataSize / (48000.0 * sizeof(float));
    checks[@"wav"] = @(wav.length == 60 && wavDataSize == 16 &&
        DYYYAudioNear(wavDuration, 4.0 / 48000.0, 0.0000001));
    float threeSecondSamples[30] = {};
    NSData *threeSecondWAV = DYYYAudioSignalFloatWAV(threeSecondSamples, 30, 10);
    uint32_t threeSecondDataSize = 0;
    if (threeSecondWAV.length >= 44) {
        memcpy(&threeSecondDataSize, (const uint8_t *)threeSecondWAV.bytes + 40, sizeof(threeSecondDataSize));
    }
    checks[@"threeSecondWAVDuration"] = @(
        DYYYAudioNear((double)threeSecondDataSize / (10.0 * sizeof(float)), 3.0, 0.000001));

    memset(output, 0, sizeof(output));
    written = DYYYAudioSignalDownmix((AudioBufferList *)&floatList, &floatInterleaved, 3, output, 2, &unreadable);
    checks[@"pcmRingOverflow"] = @(written == 2 && 3 - written == 1);

    std::atomic<uint32_t> eventWriteIndex { 0 };
    std::atomic<uint32_t> eventOverflow { 0 };
    for (uint32_t i = 0; i < 6; i++) {
        uint32_t index = eventWriteIndex.fetch_add(1, std::memory_order_relaxed);
        if (index >= 4) eventOverflow.fetch_add(1, std::memory_order_relaxed);
    }
    checks[@"eventRingOverflow"] = @(eventWriteIndex.load(std::memory_order_relaxed) == 6 &&
                                      eventOverflow.load(std::memory_order_relaxed) == 2);

    BOOL passed = YES;
    for (NSNumber *value in checks.allValues) passed &= value.boolValue;
    return @{ @"passed": @(passed), @"checks": checks };
}

#pragma mark - DYYYAudioLevels

namespace {

constexpr uint32_t kWindow = 1024;          // 与 DYYYAudioSignalDFTSetup1024 一致
constexpr uint32_t kBands = 32;

// 可视化的频率范围只取 60 Hz – 12 kHz，不是全频。两头都有实测理由：
//
// 低端：1024 点 @ 48 kHz 的 bin 宽是 46.875 Hz，40 Hz 以下压根分辨不出来。导出那份
//       40 Hz 起的 32 段映射里，band 0–3 全部落进 bin 1（beta3 实测四段值一模一样），
//       画出来就是最左四根条完全同步地一起动，一眼假。
// 高端：抖音是重压缩 AAC，beta3 那份素材 13 kHz 以上是零；留到 24 kHz 只会让最后
//       三根条永远不动，还各自白白平均掉 63/77/93 个 bin。
constexpr double kMinHz = 60.0;
constexpr double kMaxHz = 12000.0;

// 自适应增益：跟得上突强、退得慢，安静段落也能有满幅动作。
constexpr double kGainAttackTau = 0.10;
constexpr double kGainDecayTau = 2.00;
constexpr float kGainFloor = 0.01f;         // 下限，避免静音时把底噪放大成满幅

// 响应曲线。线性幅度直接画出来低电平几乎贴地，0.45 次方把中下段抬起来。
constexpr float kCurve = 0.45f;

float gPeakEnv = kGainFloor;

// 逐帧复用的 scratch，全部 static：分析在主线程跑，60 Hz 下不能有堆分配。
float gSamples[kWindow];
float gWindowFn[kWindow];
float gReal[kWindow], gImag[kWindow], gOutReal[kWindow], gOutImag[kWindow];
float gMagnitude[kWindow / 2];
bool gWindowReady = false;

void EnsureWindow(void) {
    if (gWindowReady) return;
    vDSP_hann_window(gWindowFn, kWindow, vDSP_HANN_NORM);
    gWindowReady = true;
}

float BandEdgeHz(uint32_t index) {
    return (float)(kMinHz * pow(kMaxHz / kMinHz, (double)index / kBands));
}

// 把幅度谱折成 kBands 段。
//
// 段宽不足一个 bin 时【在段中心频率上线性插值】而不是对整数 bin 区间求平均——后者会让
// 相邻若干段退化成同一个 bin 的同一个值。段宽够时取区间【最大值】而不是均值：
// 可视化要的是"这一段里最响的成分"，均值会把瞬态抹平。
void FoldBands(const float *magnitude, double sampleRate, float *bands) {
    const double binsPerHz = (double)kWindow / sampleRate;
    for (uint32_t k = 0; k < kBands; k++) {
        double lo = BandEdgeHz(k) * binsPerHz;
        double hi = BandEdgeHz(k + 1) * binsPerHz;
        uint32_t first = (uint32_t)ceil(lo);
        uint32_t last = (uint32_t)floor(hi);
        float value;
        if (last <= first || last >= kWindow / 2) {
            double center = std::min((lo + hi) * 0.5, (double)(kWindow / 2 - 2));
            uint32_t bin = (uint32_t)center;
            float frac = (float)(center - bin);
            value = magnitude[bin] * (1.0f - frac) + magnitude[bin + 1] * frac;
        } else {
            value = 0.0f;
            for (uint32_t bin = first; bin <= last && bin < kWindow / 2; bin++) {
                value = std::max(value, magnitude[bin]);
            }
        }
        bands[k] = value;
    }
}

} // namespace

uint32_t DYYYAudioLevelsBandCount(void) {
    return kBands;
}

void DYYYAudioLevelsReset(void) {
    gPeakEnv = kGainFloor;
}

BOOL DYYYAudioLevelsSampleBands(float *bands, double deltaSeconds) {
    if (!bands) return NO;
    memset(bands, 0, kBands * sizeof(float));

    double sampleRate = 48000.0;
    if (DYYYAudioTapCopyLatestSamples(gSamples, kWindow, &sampleRate) != kWindow) return NO;

    vDSP_DFT_Setup setup = (vDSP_DFT_Setup)DYYYAudioSignalDFTSetup1024();
    if (!setup) return NO;

    EnsureWindow();
    vDSP_vmul(gSamples, 1, gWindowFn, 1, gReal, 1, kWindow);
    memset(gImag, 0, sizeof(gImag));
    vDSP_DFT_Execute(setup, gReal, gImag, gOutReal, gOutImag);

    DSPSplitComplex split = { gOutReal, gOutImag };
    vDSP_zvabs(&split, 1, gMagnitude, 1, kWindow / 2);
    float scale = 1.0f / kWindow;
    vDSP_vsmul(gMagnitude, 1, &scale, gMagnitude, 1, kWindow / 2);

    FoldBands(gMagnitude, sampleRate, bands);

    float peak = 0.0f;
    vDSP_maxv(bands, 1, &peak, kBands);
    double tau = peak > gPeakEnv ? kGainAttackTau : kGainDecayTau;
    float target = std::max(peak, kGainFloor);
    gPeakEnv += (target - gPeakEnv) * (float)(1.0 - exp(-std::max(0.0, deltaSeconds) / tau));
    if (gPeakEnv < kGainFloor) gPeakEnv = kGainFloor;

    for (uint32_t k = 0; k < kBands; k++) {
        float normalized = std::min(1.0f, std::max(0.0f, bands[k] / gPeakEnv));
        bands[k] = powf(normalized, kCurve);
    }
    return YES;
}

void DYYYAudioLevelsResample(const float *bands, const float *u, float *out, uint32_t count) {
    if (!bands || !u || !out || count == 0) return;
    for (uint32_t k = 0; k < count; k++) {
        float position = std::min(1.0f, std::max(0.0f, u[k])) * (kBands - 1);
        uint32_t index = (uint32_t)position;
        float frac = position - index;
        uint32_t next = std::min(index + 1, kBands - 1);
        out[k] = bands[index] * (1.0f - frac) + bands[next] * frac;
    }
}

void DYYYAudioLevelsSpatialSmooth(float *values, uint32_t count) {
    if (!values || count < 3) return;
    float previous = values[0];
    for (uint32_t k = 1; k + 1 < count; k++) {
        float current = values[k];
        values[k] = 0.25f * previous + 0.5f * current + 0.25f * values[k + 1];
        previous = current;
    }
}

void DYYYAudioLevelsSmooth(float *levels, const float *targets, uint32_t count,
                         double deltaSeconds, double attackTau, double decayTau) {
    if (!levels || !targets || count == 0) return;
    double dt = std::max(0.0, deltaSeconds);
    float up = (float)(1.0 - exp(-dt / std::max(0.001, attackTau)));
    float down = (float)(1.0 - exp(-dt / std::max(0.001, decayTau)));
    for (uint32_t k = 0; k < count; k++) {
        float target = targets[k];
        levels[k] += (target - levels[k]) * (target > levels[k] ? up : down);
    }
}

// MARK: - 自检

NSDictionary *DYYYAudioLevelsSyntheticValidation(void) {
    NSMutableDictionary *checks = [NSMutableDictionary dictionary];
    const double sampleRate = 48000.0;
    float magnitude[kWindow / 2] = {};
    float bands[kBands] = {};

    // 1 kHz 单音：折出来的峰值必须落在包含 1 kHz 的那一段。
    uint32_t oneKHzBin = (uint32_t)round(1000.0 * kWindow / sampleRate);
    magnitude[oneKHzBin] = 1.0f;
    FoldBands(magnitude, sampleRate, bands);
    uint32_t strongest = 0;
    for (uint32_t k = 1; k < kBands; k++) if (bands[k] > bands[strongest]) strongest = k;
    checks[@"bandPeakAt1kHz"] = @(BandEdgeHz(strongest) <= 1000.0f &&
                                  BandEdgeHz(strongest + 1) >= 1000.0f);

    // 分段塌陷回归：给一条平坦谱，相邻段不得出现完全相同的值。
    // 40 Hz–24 kHz 的旧口径下，最低四段会同时落进 bin 1，值一模一样。
    for (uint32_t bin = 0; bin < kWindow / 2; bin++) magnitude[bin] = 1.0f / (1.0f + bin);
    FoldBands(magnitude, sampleRate, bands);
    BOOL distinct = YES;
    for (uint32_t k = 1; k < kBands; k++) if (bands[k] == bands[k - 1]) distinct = NO;
    checks[@"bandsDistinct"] = @(distinct);

    // 静音输入折出来必须全零。
    memset(magnitude, 0, sizeof(magnitude));
    FoldBands(magnitude, sampleRate, bands);
    BOOL silent = YES;
    for (uint32_t k = 0; k < kBands; k++) if (bands[k] != 0.0f) silent = NO;
    checks[@"bandsSilence"] = @(silent);

    // 跟随：上升快、下降慢，且都收敛到目标。
    float levels[4] = { 0, 0, 0, 0 };
    float targets[4] = { 1, 1, 1, 1 };
    for (int i = 0; i < 30; i++) DYYYAudioLevelsSmooth(levels, targets, 4, 1.0 / 60.0, 0.035, 0.240);
    BOOL rose = levels[0] > 0.99f;
    float afterAttack = levels[0];
    memset(targets, 0, sizeof(targets));
    DYYYAudioLevelsSmooth(levels, targets, 4, 1.0 / 60.0, 0.035, 0.240);
    BOOL slowFall = levels[0] < afterAttack && levels[0] > 0.9f;   // 一帧只掉一点
    for (int i = 0; i < 120; i++) DYYYAudioLevelsSmooth(levels, targets, 4, 1.0 / 60.0, 0.035, 0.240);
    checks[@"smoothConverges"] = @(rose && slowFall && levels[0] < 0.01f);

    // 重采样：u 单调时输出必须在段值之间，端点严格对齐首末段。
    for (uint32_t k = 0; k < kBands; k++) bands[k] = (float)k / (kBands - 1);
    float u[5] = { 0.0f, 0.25f, 0.5f, 0.75f, 1.0f }, out[5] = {};
    DYYYAudioLevelsResample(bands, u, out, 5);
    checks[@"resampleEndpoints"] = @(fabsf(out[0] - 0.0f) < 1e-5f && fabsf(out[4] - 1.0f) < 1e-5f &&
                                     out[1] > out[0] && out[2] > out[1] && out[3] > out[2]);

    BOOL passed = YES;
    for (NSNumber *value in checks.allValues) passed &= value.boolValue;
    return @{ @"passed": @(passed), @"checks": checks };
}
