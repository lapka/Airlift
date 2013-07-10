//
//  Airlift/AirListener.h
//  Tailored at 2013 by Lapka, all rights reserved.
//

#import <Foundation/Foundation.h>
#import "AirSignalProcessor.h"
#include "bit_array.h"


@interface AirMessage : NSObject {
	BIT_ARRAY *_data;
}
- (id)initWithData:(BIT_ARRAY *)data;
- (BOOL)checksum;
- (BIT_ARRAY *)data;
- (uint8_t)byteAtIndex:(int)index;
@end


@interface AirBuffer : NSObject {
	BIT_ARRAY *_parallelBuffer_one;
	BIT_ARRAY *_parallelBuffer_two;
	BIT_ARRAY *_parallelBuffer_three;
	BIT_ARRAY *_parallelBuffer_four;
}
- (void)pushAirBit:(AirBit *)airBit;
- (UInt32)bitAtIndex:(int)index parallelIndex:(int)parallelIndex;
- (BIT_ARRAY *)parallelBufferAtIndex:(int)parallelIndex;
@end


@class AirListener;

@protocol AirListenerDelegate <NSObject>
- (void)airListener:(AirListener *)airListener didReceiveMessage:(AirMessage *)message;
@end


@interface AirListener : NSObject <AirSignalProcessorDelegate> {
	dispatch_queue_t _message_recognition_queue;
}

@property (nonatomic, strong) AirSignalProcessor *airSignalProcessor;
@property (nonatomic, weak) NSObject <AirListenerDelegate> *delegate;
@property (nonatomic, strong) AirBuffer *buffer;
@property BOOL isListening;
@property uint16_t marker;

- (void)startListen;
- (void)stopListen;

@end
