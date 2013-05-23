//
//  Airlift/AirListener.h
//  Tailored at 2013 by Lapka, all rights reserved.
//

#import <Foundation/Foundation.h>
#import "AirSignalProcessor.h"


@interface AirMessage : NSObject
@end


@class AirListener;

@protocol AirListenerDelegate <NSObject>
- (void)airListener:(AirListener *)airListener didReceiveMessage:(AirMessage *)message;
@end


@interface AirListener : NSObject <AirSignalProcessorDelegate>

@property (nonatomic, strong) AirSignalProcessor *airSignalProcessor;
@property (nonatomic, weak) NSObject <AirListenerDelegate> *delegate;
@property BOOL isListening;

- (void)startListen;
- (void)stopListen;

@end
