//
//  WhisperTranscriber.h
//  WhisperWrapper
//
//  Objective-C++ wrapper for whisper.cpp
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Represents a single subtitle segment
@interface WhisperSegment : NSObject

@property (nonatomic, readonly) NSInteger index;
@property (nonatomic, readonly) double startTime;  // in seconds
@property (nonatomic, readonly) double endTime;    // in seconds
@property (nonatomic, readonly) NSString *text;

- (instancetype)initWithIndex:(NSInteger)index
                    startTime:(double)startTime
                      endTime:(double)endTime
                         text:(NSString *)text;

@end

/// Progress callback block
typedef void (^WhisperProgressBlock)(double progress, NSString *status);

/// Completion callback block
typedef void (^WhisperCompletionBlock)(NSArray<WhisperSegment *> *segments, NSError * _Nullable error);

/// WhisperTranscriber - Swift-friendly wrapper for whisper.cpp
@interface WhisperTranscriber : NSObject

/// Singleton instance
+ (instancetype)shared;

/// Check if model is loaded
@property (nonatomic, readonly) BOOL isModelLoaded;

/// Load whisper model from bundle
/// @param modelName The name of the model file in the bundle (without extension)
/// @param error Error pointer
/// @return YES if successful
- (BOOL)loadModelWithName:(NSString *)modelName error:(NSError **)error;

/// Load whisper model from a specific path
/// @param modelPath Full path to the model file
/// @param error Error pointer
/// @return YES if successful
- (BOOL)loadModelFromPath:(NSString *)modelPath error:(NSError **)error;

/// Unload current model
- (void)unloadModel;

/// Transcribe audio file (async)
/// @param audioPath Path to the audio file (m4a, wav, etc.)
/// @param language Language code (e.g., "en", "zh", "auto")
/// @param progress Progress callback
/// @param completion Completion callback with segments or error
- (void)transcribeAudioAtPath:(NSString *)audioPath
                     language:(NSString *)language
                     progress:(nullable WhisperProgressBlock)progress
                   completion:(WhisperCompletionBlock)completion;

/// Cancel current transcription
- (void)cancelTranscription;

/// Get model path for a given model name (searches in bundle)
+ (nullable NSString *)pathForModelWithName:(NSString *)modelName;

@end

NS_ASSUME_NONNULL_END
