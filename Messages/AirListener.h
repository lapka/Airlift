//
//  Airlift/AirListener.h
//  Tailored at 2013 by Lapka, all rights reserved.
//

#import <Foundation/Foundation.h>
#import "AirSignalProcessor.h"


@interface AirMessage : NSObject {
	int *_data;
}
+ (AirMessage *)testMessage;
- (id)initWithData:(int *)data;
- (int *)data;
@end


@interface AirBuffer : NSObject {
	UInt32 *_parallelBuffer_one;
	UInt32 *_parallelBuffer_two;
	UInt32 *_parallelBuffer_three;
	UInt32 *_parallelBuffer_four;
}
- (void)pushAirBit:(AirBit *)airBit;
- (AirBit *)airBitAtIndex:(int)index;
@end


@class AirListener;

@protocol AirListenerDelegate <NSObject>
- (void)airListener:(AirListener *)airListener didReceiveMessage:(AirMessage *)message;
@end


@interface AirListener : NSObject <AirSignalProcessorDelegate> {
	AirMessage *_testMessage;
}

@property (nonatomic, strong) AirSignalProcessor *airSignalProcessor;
@property (nonatomic, weak) NSObject <AirListenerDelegate> *delegate;
@property (nonatomic, strong) AirBuffer *buffer;
@property BOOL isListening;

- (void)startListen;
- (void)stopListen;

@end
