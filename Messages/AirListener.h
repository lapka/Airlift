//
//  Airlift/AirListener.h
//  Tailored at 2013 by Lapka, all rights reserved.
//

#import <Foundation/Foundation.h>
#import "AirSignalProcessor.h"


@interface AirMessage : NSObject {
	UInt32 *_data;
}
+ (AirMessage *)testMessage;
- (id)initWithData:(UInt32 *)data;
- (BOOL)checksum;
- (UInt32 *)data;
@end


@interface AirBuffer : NSObject {
	UInt32 *_parallelBuffer_one;
	UInt32 *_parallelBuffer_two;
	UInt32 *_parallelBuffer_three;
	UInt32 *_parallelBuffer_four;
	// refactor: add buffers**
}
- (void)pushAirBit:(AirBit *)airBit;
- (AirBit *)airBitAtIndex:(int)index;
- (UInt32)bitAtIndex:(int)index parallelIndex:(int)parallelIndex;
- (UInt32 *)parallelBufferAtIndex:(int)parallelIndex;
@end


@class AirListener;

@protocol AirListenerDelegate <NSObject>
- (void)airListener:(AirListener *)airListener didReceiveMessage:(AirMessage *)message;
@end


@interface AirListener : NSObject <AirSignalProcessorDelegate> {
	UInt32 *_marker;
}

@property (nonatomic, strong) AirSignalProcessor *airSignalProcessor;
@property (nonatomic, weak) NSObject <AirListenerDelegate> *delegate;
@property (nonatomic, strong) AirBuffer *buffer;
@property BOOL isListening;

- (void)startListen;
- (void)stopListen;

- (UInt32 *)marker;
- (void)setMarker:(UInt32 *)marker;

@end
