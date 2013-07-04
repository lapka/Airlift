//
//  Airlift/AirListener.h
//  Tailored at 2013 by Lapka, all rights reserved.
//

#import "AirListener.h"

#define markerLength 16
#define checksumLength 8
#define byteLength 8
#define airMessageLength 48
#define parallelBuffersCount 4
#define gotcha_threshold 1
#define noMessageIndex -1


#pragma mark -


@implementation AirMessage

+ (AirMessage *)testMessage {
	
	UInt32 test_data[airMessageLength] = {0,0,0,1, 0,0,1,0,	// 0x12
										  0,0,1,1, 0,1,0,0,	// 0x34
										  0,1,0,1, 0,1,1,0,	// 0x56
										  0,1,1,1, 1,0,0,0,	// 0x78
										  1,0,0,1, 1,0,1,0,	// 0x9A
										  1,0,1,1, 1,1,0,0};// 0xBC
	
	AirMessage *testMessage = [[AirMessage alloc] initWithData:test_data];
	return testMessage;
}

- (id)initWithData:(UInt32 *)data {
	if ((self = [super init])) {
		_data = (UInt32 *) malloc(airMessageLength * sizeof(UInt32));
		for (int i=0; i<airMessageLength; i++) {
			_data[i] = data[i];
		}
	}
	return self;
}

- (void)dealloc {
	free(_data);
}

- (UInt32 *)data {
	return _data;
}

#pragma mark checksum

- (BOOL)checksum {
	
	// get 3 message bytes
	
	int startIndex = markerLength;
	int i;
	
	UInt32 *byte1_array = (UInt32 *) malloc(byteLength * sizeof(UInt32));
	UInt32 *byte2_array = (UInt32 *) malloc(byteLength * sizeof(UInt32));
	UInt32 *byte3_array = (UInt32 *) malloc(byteLength * sizeof(UInt32));
	
	for (i = 0; i < byteLength; i++) {
		byte1_array[i] = _data[startIndex + i];
		byte2_array[i] = _data[startIndex + byteLength + i];
		byte3_array[i] = _data[startIndex + 2*byteLength + i];
	}
	
	uint8_t byte1, byte2, byte3;
	byte1 = bit_array2uint(byte1_array);
	byte2 = bit_array2uint(byte2_array);
	byte3 = bit_array2uint(byte3_array);
	
	free(byte1_array);
	free(byte2_array);
	free(byte3_array);
	
	printf("\n(bytes %X, %X, %X)", byte1, byte2, byte3);
	
	
	// calc CRC
	
	uint8_t b[3] = {byte1, byte2, byte3};
//	uint8_t b[3] = {0x0A, 0x0B, 0x0C};
	uint8_t crc = [self crc8_withBuffer:b length:3];
	printf("(crc %02X)", crc);
	
	
	// convert crc to bit array
	
	UInt32 *crc_array = (UInt32 *) malloc(checksumLength * sizeof(UInt32));
	uint2bit_array(crc, crc_array);

	
	// or use test crc array
	
	UInt32 test_crc_array[checksumLength] = {1,0,1,1, 1,1,0,0}; // 0xBC
	
	
	// compare calculated crc with last message byte
	
	BOOL isCrcEqual = YES;
	int checksumStartIndex = airMessageLength-checksumLength;
	for (int i = 0; i < checksumLength; i++) {
		if (_data[checksumStartIndex + i] != test_crc_array[i]) isCrcEqual = NO;
//		if (_data[checksumStartIndex + i] != crc_array[i]) isCrcEqual = NO;
	}
	
	free(crc_array);
	
	return isCrcEqual;
}

#pragma mark crc8

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

#pragma mark uint <-> bit array

void uint2bit_array(uint8_t input, UInt32 *output) {
	
	output[0] = (input & 0x80) ? 1 : 0;
	output[1] = (input & 0x40) ? 1 : 0;
	output[2] = (input & 0x20) ? 1 : 0;
	output[3] = (input & 0x10) ? 1 : 0;
	output[4] = (input & 0x08) ? 1 : 0;
	output[5] = (input & 0x04) ? 1 : 0;
	output[6] = (input & 0x02) ? 1 : 0;
	output[7] = (input & 0x01) ? 1 : 0;
}

uint8_t bit_array2uint(UInt32 *array) {
	uint8_t val = 0;
	
	val =   array[0] << 7 |
	array[1] << 6 |
	array[2] << 5 |
	array[3] << 4 |
	array[4] << 3 |
	array[5] << 2 |
	array[6] << 1 |
	array[7];
	
	return val;
}

@end


#pragma mark -


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

- (UInt32)bitAtIndex:(int)index parallelIndex:(int)parallelIndex {
	
	UInt32 bit;
	
	if (parallelIndex == 0)
		bit = _parallelBuffer_one[index];
	else if (parallelIndex == 1)
		bit = _parallelBuffer_two[index];
	else if (parallelIndex == 2)
		bit = _parallelBuffer_three[index];
	else if (parallelIndex == 3)
		bit = _parallelBuffer_four[index];
	else {
		printf("Warning: bitAtIndex:parallelIndex: got wrong parallelIndex %d\n", parallelIndex);
		bit = 0;
	}
	
	return bit;
}

- (UInt32 *)parallelBufferAtIndex:(int)parallelIndex {
	
	if (parallelIndex == 0)
		return _parallelBuffer_one;
	else if (parallelIndex == 1)
		return _parallelBuffer_two;
	else if (parallelIndex == 2)
		return _parallelBuffer_three;
	else if (parallelIndex == 3)
		return _parallelBuffer_four;
	else {
		printf("Warning: parallelBufferAtIndex: got wrong parallelIndex %d\n", parallelIndex);
		return nil;
	}
}

@end


#pragma mark -


@interface AirListener (private)
@end


@implementation AirListener


- (id)init {
	if ((self = [super init])) {
		
		_marker = (UInt32 *) malloc(markerLength * sizeof(UInt32));
		
		// default marker
		UInt32 default_marker[markerLength] = {0,0,0,1, 0,0,1,0, 0,0,1,1, 0,1,0,0}; // 0x12 0x34
		[self setMarker:default_marker];
		
		self.buffer = [AirBuffer new];
		self.airSignalProcessor = [AirSignalProcessor new];
		_airSignalProcessor.delegate = self;
	}
	return self;
}


- (void)dealloc {

	self.airSignalProcessor = nil;
	free(_marker);
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
	
	printf(" M\n");
	[self.delegate airListener:self didReceiveMessage:message];
}


#pragma mark Message recognition


- (AirMessage *)messageAtBuffer:(AirBuffer *)buffer withMarker:(UInt32 *)marker {
	
	int indexOfParallelBufferWithMessage = [self parallelBufferIndexAtBuffer:buffer withMarker:marker];
	if (indexOfParallelBufferWithMessage == noMessageIndex) return nil;
	
	UInt32 *parallelBufferWithMessage = [buffer parallelBufferAtIndex:indexOfParallelBufferWithMessage];
	AirMessage *message = [[AirMessage alloc] initWithData:parallelBufferWithMessage];
	
	if ([message checksum]) return message;
	
	printf(" X\n");
	return nil;
}


/*
 *	Return parallel buffer index if that buffer begins with marker
 *	Otherwise return -1
 */
- (int)parallelBufferIndexAtBuffer:(AirBuffer *)buffer withMarker:(UInt32 *)marker {
	
	UInt32 parallelBufferBeginFlag[parallelBuffersCount] = {1, 1, 1, 1};
	BOOL lastBit = NO;
	int bitIndex;
	int parallelIndex;
	
	for (bitIndex = 0; bitIndex < markerLength; bitIndex++) {
		lastBit = (bitIndex + 1 == markerLength);
		for (parallelIndex = 0; parallelIndex < parallelBuffersCount; parallelIndex++) {
			if ([buffer bitAtIndex:bitIndex parallelIndex:parallelIndex] != marker[bitIndex]) {
				parallelBufferBeginFlag[parallelIndex] = 0;
			}
			if (lastBit && parallelBufferBeginFlag[parallelIndex] == 1) {
				return parallelIndex;
			}
		}
	}
	return noMessageIndex;
}


#pragma mark Marker


- (UInt32 *)marker {
	return _marker;
}


- (void)setMarker:(UInt32 *)marker {
	
	if (!marker) return;
	for (int i=0; i<markerLength; i++) {
		_marker[i] = marker[i];
	}
}


@end
