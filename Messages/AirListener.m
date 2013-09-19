//
//  Airlift/AirListener.h
//  Tailored at 2013 by Lapka, all rights reserved.
//

#import "AirListener.h"

#define airMessageLength 48
#define markerLength 16
#define checksumLength 8
#define byteLength 8

#define messageContentLength (airMessageLength - markerLength - checksumLength)
#define markerBytesCount (markerLength / byteLength)
#define messageBytesCount (airMessageLength / byteLength)

#define doubledMessageTimeThreshold 0.05
#define parallelBuffersCount 4
#define gotcha_threshold 1




#pragma mark -


@implementation AirMessage


- (id)initWithData:(BIT_ARRAY *)data {
	if ((self = [super init])) {
		_data = bit_array_create(airMessageLength);
		bit_array_copy(_data, 0, data, 0, airMessageLength);
		
		// print marker
		uint16_t marker_word = bit_array_get_word16(_data, airMessageLength - markerLength);
		printf("\n(marker %04X)", marker_word);
		
		_isIntegral = [self checksum];
	}
	return self;
}


- (void)dealloc {
	bit_array_free(_data);
}


- (BIT_ARRAY *)data {
	return _data;
}


- (uint8_t)byteAtIndex:(int)index {
	
	int startIndex = airMessageLength - (index + 1) * byteLength;
	return bit_array_get_word8(_data, startIndex);
}


- (BOOL)checksum {
	
	// get 4 message bytes
	uint8_t byte1 = [self byteAtIndex:markerBytesCount + 0];
	uint8_t byte2 = [self byteAtIndex:markerBytesCount + 1];
	uint8_t byte3 = [self byteAtIndex:markerBytesCount + 2];
	uint8_t byte4 = [self byteAtIndex:markerBytesCount + 3];
	printf("(bytes %02X, %02X, %02X, %02X)", byte1, byte2, byte3, byte4);
	
	// calc crc
	uint8_t b[3] = {byte1, byte2, byte3};
	uint8_t crc = [self crc8_withBuffer:b length:3];
	printf("[crc %02X]", crc);
	
	// compare calculated crc with last message byte
	BOOL crcIsEqual = (crc == byte4);
	printf(" %s\n", crcIsEqual?"V":"X");
	
	return crcIsEqual;
}


- (uint8_t)crc8_withBuffer:(uint8_t *)buffer length:(uint8_t)length {
	
	uint8_t i;
	uint8_t crc = 0x00;
	
	while (length--) {
		crc ^= *buffer++;
		for (i = 0; i < 8; i++) {
			crc = crc & 0x01 ? (crc >> 1) ^ 0x8C : crc >> 1;
		}
	}
	return crc;
}

@end




#pragma mark -


@implementation AirBuffer


- (id)init {
	if ((self = [super init])) {
		_parallelBuffer_one   = bit_array_create(airMessageLength);
		_parallelBuffer_two   = bit_array_create(airMessageLength);
		_parallelBuffer_three = bit_array_create(airMessageLength);
		_parallelBuffer_four  = bit_array_create(airMessageLength);
	}
	return self;
}


- (void)dealloc {
	bit_array_free(_parallelBuffer_one);
	bit_array_free(_parallelBuffer_two);
	bit_array_free(_parallelBuffer_three);
	bit_array_free(_parallelBuffer_four);
}


- (void)pushAirBit:(AirBit *)airBit {
	
	bit_array_shift_left(_parallelBuffer_one,   1, [airBit bitWithShiftIndex:0]);
	bit_array_shift_left(_parallelBuffer_two,   1, [airBit bitWithShiftIndex:1]);
	bit_array_shift_left(_parallelBuffer_three, 1, [airBit bitWithShiftIndex:2]);
	bit_array_shift_left(_parallelBuffer_four,  1, [airBit bitWithShiftIndex:3]);
}


- (UInt32)bitAtIndex:(int)index parallelIndex:(int)parallelIndex {
	
	BIT_ARRAY *buffer = [self parallelBufferAtIndex:parallelIndex];
	return bit_array_get(buffer, index);
}


- (BIT_ARRAY *)parallelBufferAtIndex:(int)parallelIndex {
	
	if (parallelIndex == 0)		 return _parallelBuffer_one;
	else if (parallelIndex == 1) return _parallelBuffer_two;
	else if (parallelIndex == 2) return _parallelBuffer_three;
	else if (parallelIndex == 3) return _parallelBuffer_four;
	else {
		printf("Warning: parallelBufferAtIndex: got wrong parallelIndex %d\n", parallelIndex);
		return nil;
	}
}


@end




#pragma mark -




@interface AirListener ()
@property uint16_t inverseMarker;
@property uint16_t reverseMarker;
@end




@implementation AirListener


- (id)initWithMarker:(uint16_t)marker {
	if ((self = [super init])) {
		
		_marker = marker;
		_inverseMarker = [self inverseMarker:marker];
		_reverseMarker = [self reverseMarker:marker];
		
		_buffer = [AirBuffer new];
		_airSignalProcessor = [AirSignalProcessor new];
		_airSignalProcessor.delegate = self;
		
		_lastMessageTimestamp = [[NSDate date] timeIntervalSinceReferenceDate];
		
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


- (void)airSignalProcessor:(AirSignalProcessor *)airSignalProcessor didReceiveBit:(AirBit *)bit {
	
	[_buffer pushAirBit:bit];
	
	// run message recognition in separate queue
	dispatch_async(_message_recognition_queue, ^{
		
		AirMessage *message = [self messageAtBuffer:_buffer];
		if (message == nil) return;
		
		message.time = [NSDate new];
		
		// check time from last message
		NSTimeInterval currentTimestamp = [[NSDate date] timeIntervalSinceReferenceDate];
		NSTimeInterval timeSinceLastMessage = currentTimestamp - _lastMessageTimestamp;
		_lastMessageTimestamp = currentTimestamp;
		if (timeSinceLastMessage < doubledMessageTimeThreshold) {
			printf("[doubled]\n");
			return;
		}
					
		dispatch_async(dispatch_get_main_queue(), ^{
			[self.delegate airListener:self didReceiveMessage:message];
		});

	});
}


#pragma mark Message recognition


- (AirMessage *)messageAtBuffer:(AirBuffer *)buffer {
	
	int startIndex = airMessageLength - markerLength;
	
	// on each parallel buffer
	for (int parallelIndex = 0; parallelIndex < parallelBuffersCount; parallelIndex++) {
		BIT_ARRAY *parallelBuffer = [buffer parallelBufferAtIndex:parallelIndex];
		uint16_t first_two_bytes_word = bit_array_get_word16(parallelBuffer, startIndex);
		
		if (first_two_bytes_word == _marker) {
			AirMessage *message = [[AirMessage alloc] initWithData:parallelBuffer];
			if (message.isIntegral) return message;
		}
		
		if (first_two_bytes_word == _inverseMarker) {
			AirMessage *message = [[AirMessage alloc] initWithData:parallelBuffer];
			message.markerIsInverse = YES;
			if (message.isIntegral) return message;
		}
		
		if (first_two_bytes_word == _reverseMarker) {
			AirMessage *message = [[AirMessage alloc] initWithData:parallelBuffer];
			message.markerIsReverse = YES;
			if (message.isIntegral) return message;
		}
	}
	
	return nil;
}


#pragma mark - Marker math


- (uint16_t)reverseMarker:(uint16_t)marker {
	
	BIT_ARRAY *marker_array = bit_array_create(markerLength);
	bit_array_set_word16(marker_array, 0, marker);
	bit_array_reverse(marker_array);
	uint16_t reverseMarker = bit_array_get_word16(marker_array, 0);
	return reverseMarker;
}


- (uint16_t)inverseMarker:(uint16_t)marker {
	
	BIT_ARRAY *marker_array = bit_array_create(markerLength);
	bit_array_set_word16(marker_array, 0, marker);
	bit_array_toggle_all(marker_array);
	uint16_t inverseMarker = bit_array_get_word16(marker_array, 0);
	return inverseMarker;
}


@end
