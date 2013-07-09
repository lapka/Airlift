//
//  Airlift/AirSignalProcessor.h
//  Tailored at 2013 by Lapka, all rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioToolbox.h>
#import "AirSignalFFTAnalyzer.h"
#include "bit_array.h"


@interface AirBit : NSObject {
	BIT_ARRAY *_shiftedBits;
}
- (void)setBit:(char)bit forShiftIndex:(int)shiftIndex;
- (char)bitWithShiftIndex:(int)shiftIndex;
@end


@class AirSignalProcessor;

@protocol AirSignalProcessorDelegate <NSObject>
- (void)airSignalProcessor:(AirSignalProcessor *)airSignalProcessor didReceiveBit:(AirBit *)bit;
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
	
	dispatch_queue_t data_processing_queue;
}

@property (nonatomic, weak) NSObject <AirSignalProcessorDelegate> *delegate;
@property (nonatomic, strong) AirSignalFFTAnalyzer *fftAnalyzer;

@property (nonatomic) Float32 sampleRate;
@property (nonatomic) double stepFrequency;

@property (nonatomic) BOOL isProcessing;

- (void)startProcessing;
- (void)stopProcessing;

// Utilities
- (NSRange)stepBitRangeWithStartTime:(Float64)startTime;
- (NSRange)stepDataBitRangeWithStartTime:(Float64)startTime;

@end
