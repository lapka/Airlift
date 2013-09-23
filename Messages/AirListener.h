//
//  Airlift/AirListener.h
//  Tailored at 2013 by Lapka, all rights reserved.
//

#import <Foundation/Foundation.h>
#import "AirSignalProcessor.h"
#include "bit_array.h"


@interface AirMessage : NSObject

@property (strong) NSDate *time;
@property AirWordValue word;

+ (AirMessage *)messageWithWord:(AirWordValue)word;

@end


@protocol AirListenerDelegate <NSObject>
- (void)airListenerDidReceiveMessage:(AirMessage *)message;
@end


@interface AirListener : NSObject <AirSignalProcessorDelegate> {
	dispatch_queue_t _message_recognition_queue;
}

@property (nonatomic, strong) AirSignalProcessor *airSignalProcessor;
@property (nonatomic, weak) NSObject <AirListenerDelegate> *delegate;
@property BOOL isListening;

- (void)startListen;
- (void)stopListen;

@end
