//
//  Airlift/AirListener.h
//  Tailored at 2013 by Lapka, all rights reserved.
//

#import "AirListener.h"

#define shortMessageLengthInFrames 1
#define longMessageLengthInFrames 6
#define airBufferLength longMessageLengthInFrames + 3
#define shortMessageMarkerIndex airBufferLength - 4
#define longMessageMarkerIndex 0
#define byteLength 8
#define word4Length 4
#define parallelBuffersCount 4




#pragma mark -


@implementation AirMessage

+ (AirMessage *)messageWithData:(BIT_ARRAY *)data isShort:(BOOL)isShort followedBySameMarker:(BOOL)followedBySameMarker {
	AirMessage *message = [[AirMessage alloc] initWithData:data isShort:isShort followedBySameMarker:followedBySameMarker];
	return message;
}

- (id)initWithData:(BIT_ARRAY *)data isShort:(BOOL)isShort followedBySameMarker:(BOOL)followedBySameMarker {
	if ((self = [super init])) {
		_isShort = isShort;
		_followedBySameMarker = followedBySameMarker;
		int bitArrayLength = isShort ? shortMessageLengthInFrames * word4Length : longMessageLengthInFrames * word4Length;
		_data = bit_array_create(bitArrayLength);
		bit_array_copy(_data, 0, data, 0, bitArrayLength);
	}
	return self;
}


- (void)dealloc {
	bit_array_free(_data);
}


- (BIT_ARRAY *)data {
	return _data;
}

@end




#pragma mark -


@implementation AirBuffer


- (id)init {
	if ((self = [super init])) {
		_parallelBuffer_one   = malloc(airBufferLength * sizeof(uint8_t));
		_parallelBuffer_two   = malloc(airBufferLength * sizeof(uint8_t));
		_parallelBuffer_three = malloc(airBufferLength * sizeof(uint8_t));
		_parallelBuffer_four  = malloc(airBufferLength * sizeof(uint8_t));
	}
	return self;
}


- (void)dealloc {
	free(_parallelBuffer_one);
	free(_parallelBuffer_two);
	free(_parallelBuffer_three);
	free(_parallelBuffer_four);
}


- (void)pushAirWord:(AirWord *)airWord {
	
	int lastWordIndex = airBufferLength - 1;
	
	// shift buffer
	for (int i = 0; i < lastWordIndex; i++) {
		_parallelBuffer_one[i]   = _parallelBuffer_one[i + 1];
		_parallelBuffer_two[i]   = _parallelBuffer_two[i + 1];
		_parallelBuffer_three[i] = _parallelBuffer_three[i + 1];
		_parallelBuffer_four[i]  = _parallelBuffer_four[i + 1];
	}
	
	_parallelBuffer_one[lastWordIndex]   = [airWord wordForShiftIndex:0];
	_parallelBuffer_two[lastWordIndex]   = [airWord wordForShiftIndex:1];
	_parallelBuffer_three[lastWordIndex] = [airWord wordForShiftIndex:2];
	_parallelBuffer_four[lastWordIndex]  = [airWord wordForShiftIndex:3];
}


- (uint8_t)wordAtIndex:(int)index parallelIndex:(int)parallelIndex; {
	
	uint8_t *buffer = [self parallelBufferAtIndex:parallelIndex];
	return buffer[index];
}


- (uint8_t *)parallelBufferAtIndex:(int)parallelIndex {
	
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
// this flag is used to avoid recognition of same message shifted to next step
@property BOOL shouldIgnoreMessageAtNextRecognitionStep;
@end


@implementation AirListener


- (id)init {
	if ((self = [super init])) {
		
		_buffer = [AirBuffer new];
		_airSignalProcessor = [AirSignalProcessor new];
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


- (void)airSignalProcessorDidReceiveWord:(AirWord *)word {
	
	[_buffer pushAirWord:word];
	
	if (_shouldIgnoreMessageAtNextRecognitionStep) {
		_shouldIgnoreMessageAtNextRecognitionStep = NO;
		return;
	}
		
	AirMessage *message = [self messageAtBuffer:_buffer];
	if (message == nil) return;
	
	_shouldIgnoreMessageAtNextRecognitionStep = YES;
				
	dispatch_async(dispatch_get_main_queue(), ^{
		[self.delegate airListenerDidReceiveMessage:message];
	});
}


#pragma mark Message recognition


- (AirMessage *)messageAtBuffer:(AirBuffer *)buffer {
	
	// on each parallel buffer
	for (int parallelIndex = 0; parallelIndex < parallelBuffersCount; parallelIndex++) {
		uint8_t *parallelBuffer = [buffer parallelBufferAtIndex:parallelIndex];
		uint8_t short_message_marker_pretendent = [buffer wordAtIndex:shortMessageMarkerIndex parallelIndex:parallelIndex];
		uint8_t long_message_marker_pretendent = [buffer wordAtIndex:longMessageMarkerIndex parallelIndex:parallelIndex];
		
		if ([self wordIsShortMessageMarker:short_message_marker_pretendent]) {
			BOOL bufferContainsIntegralMessage = [self bufferContainsShortIntegralMessage:parallelBuffer];
			if (bufferContainsIntegralMessage) {
				BOOL followedBySameMarker = [self bufferContainsShortMessageFollowedBySameMarker:parallelBuffer];
				BIT_ARRAY *messageData = [self bitArrayFromWordsArray:parallelBuffer withStartWordIndex:(shortMessageMarkerIndex + 1) wordsCount:shortMessageLengthInFrames];
				AirMessage *message = [AirMessage messageWithData:messageData isShort:YES followedBySameMarker:followedBySameMarker];
				message.markerID = short_message_marker_pretendent;
				message.time = [NSDate date];
				bit_array_free(messageData);
				return message;
			}
		}
		
		if ([self wordIsLongMessageMarker:long_message_marker_pretendent]) {
			BOOL bufferContainsIntegralMessage = [self bufferContainsLongIntegralMessage:parallelBuffer];
			if (bufferContainsIntegralMessage) {
				BIT_ARRAY *messageData = [self bitArrayFromWordsArray:parallelBuffer withStartWordIndex:(longMessageMarkerIndex + 1) wordsCount:longMessageLengthInFrames];
				AirMessage *message = [AirMessage messageWithData:messageData isShort:NO followedBySameMarker:NO];
				message.markerID = long_message_marker_pretendent;
				message.time = [NSDate date];
				bit_array_free(messageData);
				return message;
			}
		}
	}
	
	return nil;
}


- (BIT_ARRAY *)bitArrayFromWordsArray:(uint8_t *)wordsArray withStartWordIndex:(int)startWordIndex wordsCount:(int)wordsCount {
	
	BIT_ARRAY *bit_array = bit_array_create(word4Length * wordsCount);
	
	for (int index = startWordIndex; index < startWordIndex + wordsCount; index++) {
		uint8_t word = wordsArray[index];
		int startBitIndex = (wordsCount - (index - startWordIndex) - 1) * word4Length;
		bit_array_set_word4(bit_array, startBitIndex, word);
	}
	
	return bit_array;
}


- (BOOL)wordIsShortMessageMarker:(uint8_t)word {
	return (word == AirWordValue_Marker_1);
}


- (BOOL)wordIsLongMessageMarker:(uint8_t)word {
	return (word == AirWordValue_Marker_2) || (word == AirWordValue_Marker_3);
}


- (BOOL)bufferContainsShortIntegralMessage:(uint8_t *)buffer {
	
	uint8_t informative_word = buffer[shortMessageMarkerIndex + 1];
	uint8_t inverse_informative_word = 0xf - informative_word;
	uint8_t crc_word = buffer[shortMessageMarkerIndex + 2];
	
	BOOL bufferContainsShortIntegralMessage = (crc_word == inverse_informative_word);
	return bufferContainsShortIntegralMessage;
}


- (BOOL)bufferContainsShortMessageFollowedBySameMarker:(uint8_t *)buffer {
	
	uint8_t marker_word = buffer[shortMessageMarkerIndex];
	uint8_t followed_word = buffer[shortMessageMarkerIndex + 3];
	
	BOOL bufferContainsShortMessageFollowedBySameMarker = (marker_word == followed_word);
	return bufferContainsShortMessageFollowedBySameMarker;
}


- (BOOL)bufferContainsLongIntegralMessage:(uint8_t *)buffer {
	
	int calculated_crc_high = 0;
	int calculated_crc_low = 0;
	
	// odd buffer value goes to high crc part, even goes low
	for (int index = 1; index < (longMessageLengthInFrames + 1); index++) {
		if (index % 2) calculated_crc_high ^= buffer[index];
		else calculated_crc_low ^= buffer[index];
	}
	
	uint8_t given_crc_high = buffer[longMessageLengthInFrames + 1];
	uint8_t given_crc_low = buffer[longMessageLengthInFrames + 2];
	
	BOOL bufferContainsLongIntegralMessage = (given_crc_high == calculated_crc_high) && (given_crc_low == calculated_crc_low);
	return bufferContainsLongIntegralMessage;
}


@end
