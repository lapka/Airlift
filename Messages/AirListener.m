//
//  Airlift/AirListener.h
//  Tailored at 2013 by Lapka, all rights reserved.
//

#import "AirListener.h"

#define airMessageLength 56
#define gotcha_threshold 30


@implementation AirMessage

+ (AirMessage *)testMessage {
	
	UInt32 test_data[] = {0,0,0,1, 0,0,1,0,		// 0x12
						  0,0,1,1, 0,1,0,0,		// 0x34
						  0,1,0,1, 0,1,1,0,		// 0x56
						  0,1,1,1, 1,0,0,0,		// 0x78
						  1,0,0,1, 1,0,1,0,		// 0x9A
						  1,0,1,1, 1,1,0,0,		// 0xBC
						  1,1,0,1, 1,1,1,0};	// 0xDE
	
	AirMessage *testMessage = [[AirMessage alloc] initWithData:test_data];
	return testMessage;
}

- (id)initWithData:(UInt32 *)data {
	if ((self = [super init])) {
		_data = data;
	}
	return self;
}

- (void)dealloc {
}

- (UInt32 *)data {
	return _data;
}

@end


@implementation AirBuffer

- (id)init {
	if ((self = [super init])) {
		_parallelBuffer_one   = (UInt32 *) malloc(airMessageLength * sizeof(UInt32));
		_parallelBuffer_two   = (UInt32 *) malloc(airMessageLength * sizeof(UInt32));
		_parallelBuffer_three = (UInt32 *) malloc(airMessageLength * sizeof(UInt32));
		_parallelBuffer_four  = (UInt32 *) malloc(airMessageLength * sizeof(UInt32));
	}
	return self;
}

- (void)dealloc {
	free(_parallelBuffer_one);
	free(_parallelBuffer_two);
	free(_parallelBuffer_three);
	free(_parallelBuffer_four);
}

- (void)pushAirBit:(AirBit *)airBit {
	
	[self pushBit:[airBit bitWithShiftIndex:0] toBuffer:_parallelBuffer_one];
	[self pushBit:[airBit bitWithShiftIndex:1] toBuffer:_parallelBuffer_two];
	[self pushBit:[airBit bitWithShiftIndex:2] toBuffer:_parallelBuffer_three];
	[self pushBit:[airBit bitWithShiftIndex:3] toBuffer:_parallelBuffer_four];
}

- (AirBit *)airBitAtIndex:(int)index {
	
	AirBit *airBit = [AirBit new];
	[airBit setBit:_parallelBuffer_one[index]   forShiftIndex:0];
	[airBit setBit:_parallelBuffer_two[index]   forShiftIndex:1];
	[airBit setBit:_parallelBuffer_three[index] forShiftIndex:2];
	[airBit setBit:_parallelBuffer_four[index]  forShiftIndex:3];
	return airBit;
}

- (void)pushBit:(UInt32)bit toBuffer:(UInt32 *)buffer {
	
	// shift buffer
	int bufferLengthMinusOne = airMessageLength - 1;
	for (int i = 0; i < bufferLengthMinusOne; i++) {
		buffer[i] = buffer[i+1];
	}
	
	// add bit
	buffer[bufferLengthMinusOne] = bit;
}

@end


@interface AirListener (private)
@end


@implementation AirListener


- (id)init {
	if ((self = [super init])) {
		
		self.buffer = [AirBuffer new];
		self.airSignalProcessor = [AirSignalProcessor new];
		_airSignalProcessor.delegate = self;
		
		_testMessage = [AirMessage testMessage];
		
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
	
	[_buffer pushAirBit:bit];
	
	if ([self isBuffer:_buffer containsMessage:_testMessage]) {
		[self.delegate airListener:self didReceiveMessage:[AirMessage testMessage]];
	}
}


#pragma mark -
#pragma mark Message recognition


- (BOOL)isBuffer:(AirBuffer *)buffer containsMessage:(AirMessage *)message {
	
	BOOL isFirstBufferContain  = YES;
	BOOL isSecondBufferContain = YES;
	BOOL isThirdBufferContain  = YES;
	BOOL isFourthBufferContain = YES;
	
	int errors_0 = 0;
	int errors_1 = 0;
	int errors_2 = 0;
	int errors_3 = 0;
	
	UInt32 *messageData = [message data];
	
	for (int i = 1; i < airMessageLength; i++) {
		AirBit *bit = [buffer airBitAtIndex:i];
		
		if ([bit bitWithShiftIndex:0] != messageData[i]) {isFirstBufferContain  = NO; errors_0++;}
		if ([bit bitWithShiftIndex:1] != messageData[i]) {isSecondBufferContain = NO; errors_1++;}
		if ([bit bitWithShiftIndex:2] != messageData[i]) {isThirdBufferContain  = NO; errors_2++;}
		if ([bit bitWithShiftIndex:3] != messageData[i]) {isFourthBufferContain = NO; errors_3++;}
	}
	
	BOOL GOTCHA = (errors_0<gotcha_threshold || errors_1<gotcha_threshold || errors_2<gotcha_threshold || errors_3<gotcha_threshold);
	printf("message errors: %d, %d, %d, %d %s\n", errors_0, errors_1, errors_2, errors_3, GOTCHA?"GOTCHA":"");
	
	return (isFirstBufferContain || isSecondBufferContain || isThirdBufferContain || isFourthBufferContain);
}


@end
