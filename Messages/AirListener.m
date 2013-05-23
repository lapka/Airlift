//
//  Airlift/AirListener.h
//  Tailored at 2013 by Lapka, all rights reserved.
//

#import "AirListener.h"


@interface AirListener (private)
@end


@implementation AirListener


- (id)init {
	if ((self = [super init])) {
		
		self.airSignalProcessor = [AirSignalProcessor new];
		_airSignalProcessor.delegate = self;
	}
	return self;
}


- (void)dealloc {

	self.airSignalProcessor = nil;
}


#pragma mark -
#pragma mark Listen


- (void)startListen {
	
	if (_isListening) return;
	[_airSignalProcessor startProcessing];
	self.isListening = YES;
}


- (void)stopListen {

	if (!_isListening) return;
	[_airSignalProcessor stopProcessing];
	self.isListening = NO;
}


#pragma mark -
#pragma mark AirSignalProcessorDelegate


- (void)airSignalProcessor:(AirSignalProcessor *)airSignalProcessor didReceiveBit:(AirBit *)bit {
	
}


@end
