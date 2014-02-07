//
//  Airlift/AirListener.h
//  Tailored at 2013 by Lapka, all rights reserved.
//

#import <Foundation/Foundation.h>
#import "AirSignalProcessor.h"
#include "bit_array.h"


#define longMessageLengthInFrames 6


@interface AirMessage : NSObject {
	BIT_ARRAY *_data;
}
@property BOOL isShort;
@property int markerID;
@property BOOL followedBySameMarker;
@property (strong) NSDate *time;
- (id)initWithData:(BIT_ARRAY *)data isShort:(BOOL)isShort followedBySameMarker:(BOOL)followedBySameMarker;
- (BIT_ARRAY *)data;

+ (AirMessage *)messageWithData:(BIT_ARRAY *)data isShort:(BOOL)isShort followedBySameMarker:(BOOL)followedBySameMarker;

@end


@interface AirBuffer : NSObject {
	uint8_t *_parallelBuffer_one;
	uint8_t *_parallelBuffer_two;
	uint8_t *_parallelBuffer_three;
	uint8_t *_parallelBuffer_four;
}
- (void)pushAirWord:(AirWord *)airWord;
- (uint8_t)wordAtIndex:(int)index parallelIndex:(int)parallelIndex;
- (uint8_t *)parallelBufferAtIndex:(int)parallelIndex;
@end


@protocol AirListenerDelegate <NSObject>
- (void)airListenerDidReceiveMessage:(AirMessage *)message;
@optional;
- (void)airListenerDidProcessWord;
@end


@interface AirListener : NSObject <AirSignalProcessorDelegate>

@property (nonatomic, strong) AirSignalProcessor *airSignalProcessor;
@property (nonatomic, weak) NSObject <AirListenerDelegate> *delegate;
@property (nonatomic, strong) AirBuffer *buffer;
@property BOOL isListening;

- (void)startListen;
- (void)stopListen;

@end
