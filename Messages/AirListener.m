//
//  Airlift/AirListener.h
//  Tailored at 2013 by Lapka, all rights reserved.
//

#import "AirListener.h"

#define airMessageLength 48
#define markerLength 16
#define pressureLength 8
#define alcoLength 16
#define checksumLength 8
#define byteLength 8

#define messageContentLength (airMessageLength - markerLength - checksumLength)
#define markerBytesCount (markerLength / byteLength)
#define messageBytesCount (airMessageLength / byteLength)

#define parallelBuffersCount 4
#define gotcha_threshold 1
#define noMessageIndex -1




#pragma mark -


@implementation AirMessage


- (id)initWithData:(BIT_ARRAY *)data {
	if ((self = [super init])) {
		_data = bit_array_create(airMessageLength);
		bit_array_copy(_data, 0, data, 0, airMessageLength);
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
	
	// get 3 message bytes
	uint8_t byte1 = [self byteAtIndex:markerBytesCount + 0];
	uint8_t byte2 = [self byteAtIndex:markerBytesCount + 1];
	uint8_t byte3 = [self byteAtIndex:markerBytesCount + 2];
	printf("(bytes %02X, %02X, %02X)", byte1, byte2, byte3);
	
	// calc crc
	uint8_t b[3] = {byte1, byte2, byte3};
	uint8_t crc = [self crc8_withBuffer:b length:3];
	printf("(crc %02X)", crc);
	
	// compare calculated crc with last message byte
	uint8_t last_message_byte = [self byteAtIndex:messageBytesCount-1];
	BOOL crcIsEqual = (crc == last_message_byte);

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


@implementation AirListener


- (id)init {
	if ((self = [super init])) {
		
		// default marker
		_marker = 0xD391;
		
		self.buffer = [AirBuffer new];
		self.airSignalProcessor = [AirSignalProcessor new];
		_airSignalProcessor.delegate = self;
	}
	return self;
}


- (void)dealloc {

	self.airSignalProcessor = nil;
}


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


#pragma mark AirSignalProcessorDelegate


- (void)airSignalProcessor:(AirSignalProcessor *)airSignalProcessor didReceiveBit:(AirBit *)bit {
	
	[_buffer pushAirBit:bit];
	
	AirMessage *message = [self messageAtBuffer:_buffer withMarker:_marker];
	if (message == nil) return;
	
	
	// temporary get alco and pressure here
	
	BIT_ARRAY *data = [message data];
	int pressureStartIndex = airMessageLength - markerLength - byteLength;
	int alcoStartIndex = airMessageLength - markerLength - 3 * byteLength;
	
	uint8_t pressure = bit_array_get_word8(data, pressureStartIndex);
	uint16_t alco = bit_array_get_word16(data, alcoStartIndex);
	
	printf("[pressure: %d, alco: %d]\n", pressure, alco);
	
	[self.delegate airListener:self didReceiveMessage:message];
}


#pragma mark Message recognition


- (AirMessage *)messageAtBuffer:(AirBuffer *)buffer withMarker:(uint16_t)marker {
	
	int indexOfParallelBufferWithMessage = [self parallelBufferIndexAtBuffer:buffer withMarker:marker];
	if (indexOfParallelBufferWithMessage == noMessageIndex) return nil;
	
	BIT_ARRAY *parallelBufferWithMessage = [buffer parallelBufferAtIndex:indexOfParallelBufferWithMessage];
	AirMessage *message = [[AirMessage alloc] initWithData:parallelBufferWithMessage];
	
	BIT_ARRAY *data = [message data];
	
	uint16_t marker_word = bit_array_get_word16(data, airMessageLength - markerLength);
	printf("\n(marker %04X)", marker_word);
	
	if ([message checksum]) return message;
	
	printf(" X\n");
	return nil;
}


/*
 *	Return parallel buffer index if that buffer begins with marker
 *	Otherwise return -1
 *
 *	Assumed marker is 16 bits long
 */
- (int)parallelBufferIndexAtBuffer:(AirBuffer *)buffer withMarker:(uint16_t)marker {
	
	int startIndex = airMessageLength - markerLength;
	
	for (int parallelIndex = 0; parallelIndex < parallelBuffersCount; parallelIndex++) {
		BIT_ARRAY *parallelBuffer = [buffer parallelBufferAtIndex:parallelIndex];
		uint16_t first_two_bytes_word = bit_array_get_word16(parallelBuffer, startIndex);
		if (first_two_bytes_word == marker) return parallelIndex;
	}
	
	return noMessageIndex;
}


@end
