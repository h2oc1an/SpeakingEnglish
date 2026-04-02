//
//  WhisperTranscriber.mm
//  WhisperWrapper
//
//  Objective-C++ implementation for whisper.cpp
//

#import "WhisperTranscriber.h"
#import <AVFoundation/AVFoundation.h>
#import <vector>
#import <string>

// Include whisper.h from the framework
#include <whisper/whisper.h>

@interface WhisperSegment ()
@property (nonatomic, readwrite) NSInteger index;
@property (nonatomic, readwrite) double startTime;
@property (nonatomic, readwrite) double endTime;
@property (nonatomic, readwrite) NSString *text;
@end

@implementation WhisperSegment

- (instancetype)initWithIndex:(NSInteger)index
                    startTime:(double)startTime
                      endTime:(double)endTime
                         text:(NSString *)text {
    self = [super init];
    if (self) {
        _index = index;
        _startTime = startTime;
        _endTime = endTime;
        _text = text;
    }
    return self;
}

@end

@interface WhisperTranscriber ()

@property (nonatomic, assign) struct whisper_context *context;
@property (nonatomic, strong) dispatch_queue_t transcriptionQueue;
@property (nonatomic, assign) BOOL isTranscribing;
@property (nonatomic, assign) BOOL isCancelled;

@end

@implementation WhisperTranscriber

+ (instancetype)shared {
    static WhisperTranscriber *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WhisperTranscriber alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _context = nullptr;
        _transcriptionQueue = dispatch_queue_create("com.speakingenglish.whisper", DISPATCH_QUEUE_SERIAL);
        _isTranscribing = NO;
        _isCancelled = NO;
    }
    return self;
}

- (void)dealloc {
    [self unloadModel];
}

- (BOOL)isModelLoaded {
    return _context != nullptr;
}

+ (nullable NSString *)pathForModelWithName:(NSString *)modelName {
    NSBundle *bundle = [NSBundle mainBundle];
    NSArray *extensions = @[@"bin", @"ggml", @"model"];

    for (NSString *ext in extensions) {
        NSString *path = [bundle pathForResource:modelName ofType:ext];
        if (path) {
            return path;
        }
    }
    return nil;
}

- (BOOL)loadModelWithName:(NSString *)modelName error:(NSError **)error {
    NSString *modelPath = [WhisperTranscriber pathForModelWithName:modelName];
    if (!modelPath) {
        if (error) {
            *error = [NSError errorWithDomain:@"WhisperTranscriber"
                                        code:1
                                    userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Model '%@' not found in bundle", modelName]}];
        }
        return NO;
    }
    return [self loadModelFromPath:modelPath error:error];
}

- (BOOL)loadModelFromPath:(NSString *)modelPath error:(NSError **)error {
    // Unload existing model
    [self unloadModel];

    // Check file exists
    if (![[NSFileManager defaultManager] fileExistsAtPath:modelPath]) {
        if (error) {
            *error = [NSError errorWithDomain:@"WhisperTranscriber"
                                        code:2
                                    userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Model file not found at path: %@", modelPath]}];
        }
        return NO;
    }

    // Initialize whisper context
    struct whisper_context_params cparams = whisper_context_default_params();
    cparams.use_gpu = true;  // Use GPU if available (Metal)

    _context = whisper_init_from_file_with_params([modelPath UTF8String], cparams);

    if (!_context) {
        if (error) {
            *error = [NSError errorWithDomain:@"WhisperTranscriber"
                                        code:3
                                    userInfo:@{NSLocalizedDescriptionKey: @"Failed to initialize whisper context"}];
        }
        return NO;
    }

    NSLog(@"Whisper model loaded successfully from: %@", modelPath);
    return YES;
}

- (void)unloadModel {
    if (_context) {
        whisper_free(_context);
        _context = nullptr;
    }
}

- (void)cancelTranscription {
    _isCancelled = YES;
}

- (void)transcribeAudioAtPath:(NSString *)audioPath
                     language:(NSString *)language
                     progress:(nullable WhisperProgressBlock)progress
                   completion:(WhisperCompletionBlock)completion {

    if (!_context) {
        NSError *error = [NSError errorWithDomain:@"WhisperTranscriber"
                                             code:4
                                         userInfo:@{NSLocalizedDescriptionKey: @"Model not loaded"}];
        completion(@[], error);
        return;
    }

    if (_isTranscribing) {
        NSError *error = [NSError errorWithDomain:@"WhisperTranscriber"
                                             code:5
                                         userInfo:@{NSLocalizedDescriptionKey: @"Transcription already in progress"}];
        completion(@[], error);
        return;
    }

    _isTranscribing = YES;
    _isCancelled = NO;

    dispatch_async(_transcriptionQueue, ^{
        // Load audio file
        NSURL *audioURL = [NSURL fileURLWithPath:audioPath];
        AVAudioFile *audioFile = nil;

        NSError *loadError = nil;
        audioFile = [[AVAudioFile alloc] initForReading:audioURL error:&loadError];

        if (!audioFile) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_isTranscribing = NO;
                completion(@[], loadError);
            });
            return;
        }

        // Get audio format
        AVAudioFormat *format = audioFile.processingFormat;
        double sampleRate = format.sampleRate;
        UInt64 frameCount = (UInt64)audioFile.length;

        // Convert to float samples
        Float32 *samples = (Float32 *)malloc(sizeof(Float32) * frameCount);
        if (!samples) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_isTranscribing = NO;
                NSError *error = [NSError errorWithDomain:@"WhisperTranscriber"
                                                     code:6
                                                 userInfo:@{NSLocalizedDescriptionKey: @"Failed to allocate memory"}];
                completion(@[], error);
            });
            return;
        }

        // Read audio data using AVAudioPCMBuffer
        AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:(AVAudioFrameCount)frameCount];
        buffer.frameLength = (AVAudioFrameCount)frameCount;

        NSError *readError = nil;
        if (![audioFile readIntoBuffer:buffer error:&readError]) {
            free(samples);
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_isTranscribing = NO;
                completion(@[], readError);
            });
            return;
        }

        // Copy data from buffer to samples array
        Float32 *bufferData = buffer.floatChannelData[0];
        memcpy(samples, bufferData, sizeof(Float32) * frameCount);

        // Resample to 16kHz if necessary
        float *resampledSamples = samples;
        int sampleCount = (int)frameCount;

        if (sampleRate != 16000) {
            double ratio = sampleRate / 16000.0;
            int newCount = (int)(frameCount / ratio);
            resampledSamples = (float *)malloc(sizeof(float) * newCount);
            if (resampledSamples) {
                // Simple linear interpolation resampling
                for (int i = 0; i < newCount; i++) {
                    double srcIndex = i * ratio;
                    int srcIndex0 = (int)srcIndex;
                    int srcIndex1 = srcIndex0 + 1;
                    if (srcIndex1 >= (int)frameCount) srcIndex1 = srcIndex0;
                    double frac = srcIndex - srcIndex0;
                    resampledSamples[i] = (float)(samples[srcIndex0] * (1 - frac) + samples[srcIndex1] * frac);
                }
                free(samples);
                sampleCount = newCount;
            } else {
                resampledSamples = samples;
            }
        }

        // Setup callback context
        struct whisper_context *ctx = self->_context;

        // Create context struct for progress callback
        struct ProgressCallbackContext {
            WhisperProgressBlock progressBlock;
        };
        ProgressCallbackContext *callbackCtx = new ProgressCallbackContext();
        callbackCtx->progressBlock = progress;

        // Setup whisper parameters
        struct whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
        params.language = language ? [language UTF8String] : "auto";
        params.n_threads = 4;
        params.print_progress = false;
        params.print_special = false;
        params.print_realtime = false;
        params.print_timestamps = false;

        // Progress callback
        params.progress_callback = [](struct whisper_context *whisperCtx, struct whisper_state *state, int progress, void *user_data) {
            ProgressCallbackContext *progressCtx = (ProgressCallbackContext *)user_data;
            if (progressCtx && progressCtx->progressBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    progressCtx->progressBlock(progress / 100.0, [NSString stringWithFormat:@"Transcribing... %d%%", progress]);
                });
            }
        };
        params.progress_callback_user_data = callbackCtx;

        // Run transcription
        int result = whisper_full(ctx, params, resampledSamples, sampleCount);

        NSMutableArray<WhisperSegment *> *segments = [NSMutableArray array];

        if (result == 0) {
            int nSegments = whisper_full_n_segments(ctx);
            for (int i = 0; i < nSegments; i++) {
                const char *text = whisper_full_get_segment_text(ctx, i);
                int64_t t0 = whisper_full_get_segment_t0(ctx, i);
                int64_t t1 = whisper_full_get_segment_t1(ctx, i);

                WhisperSegment *segment = [[WhisperSegment alloc] initWithIndex:i
                                                                    startTime:t0 / 100.0
                                                                      endTime:t1 / 100.0
                                                                         text:[NSString stringWithUTF8String:text]];
                [segments addObject:segment];
            }
        }

        // Cleanup
        free(resampledSamples);
        delete callbackCtx;

        dispatch_async(dispatch_get_main_queue(), ^{
            self->_isTranscribing = NO;

            if (self->_isCancelled) {
                NSError *cancelError = [NSError errorWithDomain:@"WhisperTranscriber"
                                                          code:7
                                                      userInfo:@{NSLocalizedDescriptionKey: @"Transcription cancelled"}];
                completion(@[], cancelError);
            } else if (result != 0) {
                NSError *transcribeError = [NSError errorWithDomain:@"WhisperTranscriber"
                                                              code:8
                                                          userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Transcription failed with code: %d", result]}];
                completion(@[], transcribeError);
            } else {
                completion(segments, nil);
            }
        });
    });
}

@end
