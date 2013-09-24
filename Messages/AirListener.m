//
//  Airlift/AirListener.h
//  Tailored at 2013 by Lapka, all rights reserved.
//

#import "AirListener.h"

#define byteLength 8




#pragma mark -


@implementation AirMessage

+ (AirMessage *)messageWithValue:(AirWordValue)value {
	AirMessage *message = [[AirMessage alloc] init];
	message.value = value;
	return message;
}

@end




#pragma mark -


@implementation AirListener


- (id)init {
	if ((self = [super init])) {
		
		_airSignalProcessor = [AirSignalProcessor new];
		_airSignalProcessor.delegate = self;
		
		// create data processing queue
		_message_recognition_queue = dispatch_queue_create("com.mylapka.air_signal_message_recognition_queue", NULL);
	}
	return self;
}


- (void)dealloc {

	self.airSignalProcessor = nil;
	_message_recognition_queue = nil;
}




#pragma mark Listen


- (void)startListen {
	
	if (_isListening) return;
	[_airSignalProcessor createAudioUnit];
	[_airSignalProcessor setupFFTAnalyzer];
	[_airSignalProcessor startProcessing];
	
	self.isListening = YES;
}


- (void)stopListen {

	if (!_isListening) return;
	[_airSignalProcessor stopProcessing];
	[_airSignalProcessor removeAudioUnit];
	[_airSignalProcessor unsetupFFTAnalyzer];
	self.isListening = NO;
}




#pragma mark AirSignalProcessorDelegate


- (void)airSignalProcessorDidReceiveWord:(AirWordValue)word {
	
	dispatch_async(_message_recognition_queue, ^{
		
		AirMessage *message = [AirMessage messageWithValue:word];
		message.time = [NSDate date];
					
		dispatch_async(dispatch_get_main_queue(), ^{
			
			if (message.value == AirWordValue_ControlSignal_1)
				[self.delegate airListenerDidReceiveControlSignal:message];
			
			else
				[self.delegate airListenerDidReceiveMessage:message];
		});

	});
}


@end
