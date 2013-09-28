//
//  Airlift/AirSignalProcessor.h
//  Tailored at 2013 by Lapka, all rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioToolbox.h>
#import "AirSignalFFTAnalyzer.h"
#include "bit_array.h"


typedef enum {
	AirWordValue_NoValue = -1,
	AirWordValue_0 = 0,
	AirWordValue_1,
	AirWordValue_2,
	AirWordValue_3,
	AirWordValue_4,
	AirWordValue_5,
	AirWordValue_6,
	AirWordValue_7,
	AirWordValue_8,
	AirWordValue_9,
	AirWordValue_10,
	AirWordValue_11,
	AirWordValue_12,
	AirWordValue_13,
	AirWordValue_14,
	AirWordValue_15,
	AirWordValue_ControlSignal_1 = 16,
	AirWordValue_Sync = 17
} AirWordValue;


@interface AirWord : NSObject {
	uint8_t *_shiftedWords;
	Float32 *_shiftedWordPowers;
}
@property (nonatomic, readonly) int8_t value;
- (void)setWord:(uint8_t)word withPower:(Float32)wordPower forShiftIndex:(int)shiftIndex;
- (void)updateValueWithPhase:(int)phase;
@end


@interface AirPhaseFilter : NSObject {
	Float64 *_syncAmplitudes;
}
- (void)addSyncAmplitude:(Float64)syncAmplitude forShiftIndex:(int)shiftIndex;
- (int)currentPhase;
- (void)reset;
@end


@protocol AirSignalProcessorDelegate <NSObject>
- (void)airSignalProcessorDidReceiveWord:(AirWordValue)word;
@end


@interface AirSignalProcessor : NSObject {
	
@public
	AudioComponentInstance audioUnit;
	Float32 *_buffer;
	Float32 *_stepData;
	NSRange _bufferBitRange;
	NSTimeInterval _zeroTimestamp;
	UInt32 _bitCounter;
	
	Float64 _stepTimeDuration;
	
	UInt32 _stepBitLength;
	UInt32 _stepDataBitLength; // optimized for fft
	UInt32 _bufferBitLength;
	
	AirWord *_signalWord;
	AirPhaseFilter *_phaseFilter;
	
	dispatch_queue_t _data_processing_queue;
}

@property (nonatomic, weak) NSObject <AirSignalProcessorDelegate> *delegate;
@property (nonatomic, strong) AirSignalFFTAnalyzer *fftAnalyzer;
@property (nonatomic) Float32 sampleRate;
@property (nonatomic) double stepFrequency;
@property (nonatomic) BOOL isProcessing;

- (void)createAudioUnit;
- (void)removeAudioUnit;
- (void)startProcessing;
- (void)stopProcessing;
- (void)setupFFTAnalyzer;
- (void)unsetupFFTAnalyzer;

// Utilities
- (NSRange)stepBitRangeWithStartTime:(Float64)startTime;
- (NSRange)stepDataBitRangeWithStartTime:(Float64)startTime;

@end
