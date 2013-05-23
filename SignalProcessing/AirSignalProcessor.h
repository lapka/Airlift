//
//  Airlift/AirSignalProcessor.h
//  Tailored at 2013 by Lapka, all rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioToolbox.h>
#import "AirSignalFFTAnalyzer.h"


@interface AirBit : NSObject
@property (nonatomic, strong) NSMutableArray *shiftedBits;
- (void)setBit:(UInt32)bit forShiftIndex:(UInt32)shiftIndex;
- (UInt32)bitWithShiftIndex:(UInt32)shiftIndex;
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
	UInt32 _bufferBitLength;
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

@end
