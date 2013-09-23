//
//  Airlift/AirSignalProcessor.m
//  Tailored at 2013 by Lapka, all rights reserved.
//

#import "AirSignalProcessor.h"
#import <Accelerate/Accelerate.h>

#define defaultSampleRate		44100.0
#define defaultStepFrequency	5.375
#define defaultPacketLength		1024
#define defaultShiftSteps		4

#define wordPowerThreshold		3.0

#define wordFrequenciesCount	17
#define word0Frequency			18222.47314
#define word1Frequency			18244.00635
#define word2Frequency			18265.53955
#define word3Frequency			18432.42188
#define word4Frequency			18453.95508
#define word5Frequency			18475.48828
#define word6Frequency			18497.02148
#define word7Frequency			18518.55469
#define word8Frequency			18540.08789
#define word9Frequency			18561.62109
#define word10Frequency			18583.1543
#define word11Frequency			18604.6875
#define word12Frequency			18626.2207
#define word13Frequency			18647.75391
#define word14Frequency			18669.28711
#define word15Frequency			18690.82031
#define word16Frequency			18120.19043

OSStatus RenderAudio(
					 void *inRefCon,
					 AudioUnitRenderActionFlags *ioActionFlags,
					 const AudioTimeStamp 		*inTimeStamp,
					 UInt32 					inBusNumber,
					 UInt32 					inNumberFrames,
					 AudioBufferList 			*ioData);


OSStatus RenderAudio(
					 void *inRefCon,
					 AudioUnitRenderActionFlags *ioActionFlags,
					 const AudioTimeStamp		*inTimeStamp,
					 UInt32 					inBusNumber,
					 UInt32 					inNumberFrames,
					 AudioBufferList 			*ioData)

{
	// Get signal processor
	AirSignalProcessor *signalProcessor = (__bridge AirSignalProcessor *)inRefCon;
	
	// Render Input
	OSStatus err = AudioUnitRender(signalProcessor->audioUnit, ioActionFlags, inTimeStamp, 1, inNumberFrames, ioData);
	if (err) { printf("RenderAudio: error %d\n", (int)err); return err; }
			
	printf("r");	
	 
	// Get buffers
	Float32 *buffer_left = (Float32 *)(ioData->mBuffers[0].mData);
	Float32 *buffer_right = (Float32 *)(ioData->mBuffers[1].mData);

	 
	// -----------------------------------------------
	// PROCESS SIGNAL
	
	// Get context
	Float32 *buffer = signalProcessor->_buffer;
	Float32 *stepData = signalProcessor->_stepData;
	Float32 sampleRate = signalProcessor.sampleRate;
	UInt32 currentStep = signalProcessor->_bitCounter;
	Float64 zeroTimestamp = signalProcessor->_zeroTimestamp;
	NSRange bufferBitRange = signalProcessor->_bufferBitRange;
	Float64 stepTimeDuration = signalProcessor->_stepTimeDuration;
	UInt32 stepBitLength = signalProcessor->_stepBitLength;
	UInt32 stepDataBitLength = signalProcessor->_stepDataBitLength;
	AirWord *signalWord = signalProcessor->_signalWord;
	
	// Set timestamp
	if (zeroTimestamp == 0) {
		Float64 sampleTime = inTimeStamp->mSampleTime / sampleRate;
		zeroTimestamp = sampleTime;
	}
	
	// Add input data to buffer
	for (UInt32 i=0; i<inNumberFrames; i++) {
		buffer[bufferBitRange.length+i] = buffer_left[i];
	}
	 
	// Update buffer range
	bufferBitRange.length += inNumberFrames;
	 
	// start loop
	BOOL isBufferFullEnoughForStep = YES;
	while (isBufferFullEnoughForStep) {
		
		// calc step time range
		Float64 currentStepStartTime = stepTimeDuration * currentStep;
		
		// calc step bit range
		Float64 oneBitTimeLength = 1.0 / defaultSampleRate;
		NSRange currentStepBitRange = NSMakeRange(floor(currentStepStartTime / oneBitTimeLength), stepBitLength);
		
		// if buffer range contains 2x step range
		NSRange doubleCurrentStepBitRange = NSMakeRange(currentStepBitRange.location, currentStepBitRange.length * 2);
		BOOL bufferBitRangeContainsDoubleStepBitRange = NSEqualRanges(NSIntersectionRange(bufferBitRange, doubleCurrentStepBitRange), doubleCurrentStepBitRange);
		isBufferFullEnoughForStep = bufferBitRangeContainsDoubleStepBitRange;
		 
		if (bufferBitRangeContainsDoubleStepBitRange) {
			
			// for all shift steps
			for (int shiftStep = 0; shiftStep<defaultShiftSteps; shiftStep++) {
				
				// get step data bit range
				Float64 shiftDuration = (stepTimeDuration / 4) * shiftStep;
				NSRange stepDataBitRange = NSMakeRange(floor((currentStepStartTime + shiftDuration) / oneBitTimeLength), stepDataBitLength);
				
				// obtain step data
				for (int i = 0; i < stepDataBitRange.length; i++) {
					long int globalIndex = stepDataBitRange.location + i;
					long int bufferIndex = globalIndex - bufferBitRange.location;
					stepData[i] = buffer[bufferIndex];
				}
				
				// process fft
				Float32 *amplitudes = [signalProcessor.fftAnalyzer processFFTWithData:stepData];
				
				// find first two maximums
				Float32 firstMaximum = 0;
				Float32 secondMaximum = 0;
				int firstMaximumIndex = 0;
				int secondMaximumIndex = 0;
				for (int i = 0; i < wordFrequenciesCount; i++) {
					Float32 amplitude = amplitudes[i];
					if (amplitude > firstMaximum) {
						firstMaximum = amplitude;
						firstMaximumIndex = i;
					}
				}
				for (int i = 0; i < wordFrequenciesCount; i++) {
					if (i == firstMaximumIndex) continue;
					Float32 amplitude = amplitudes[i];
					if (amplitude > secondMaximum) {
						secondMaximum = amplitude;
						secondMaximumIndex = i;
					}
				}
				
				// get the word
				uint8_t word = firstMaximumIndex;
				Float32 wordPower = firstMaximum / secondMaximum;
				
				[signalWord setWord:word withPower:wordPower forShiftIndex:shiftStep];
				
				printf(".");
			}
			
			[signalWord updateValue];
			
			if (signalWord.value != AirWordValue_NoValue)
				[signalProcessor.delegate airSignalProcessorDidReceiveWord:signalWord.value];
			
			// buffer pop step-1
			long int popLength = currentStepBitRange.location - bufferBitRange.location + currentStepBitRange.length - 1;
			bufferBitRange.location += popLength;
			bufferBitRange.length -= popLength;
			for (int i=0; i<bufferBitRange.length; i++) {
				buffer[i] = buffer[i + popLength];
			}
			 
			// inc current step
			currentStep++;	
		}
		
	}// end loop
	
	// Mute output
	for (UInt32 frame = 0; frame < inNumberFrames; frame++) {
		buffer_left[frame]  = 0.0;
		buffer_right[frame] = 0.0;
	}
	
	// Save context
	signalProcessor->_buffer = buffer;
	signalProcessor->_stepData = stepData;
	signalProcessor->_bitCounter = currentStep;
	signalProcessor->_zeroTimestamp = zeroTimestamp;
	signalProcessor->_bufferBitRange = bufferBitRange;
	
	return noErr;
}


@implementation AirWord

- (id)init {
	if ((self = [super init])) {
		_shiftedWords = (uint8_t *) malloc(defaultShiftSteps * sizeof(uint8_t));
		_shiftedWordPowers = (Float32 *) malloc(defaultShiftSteps * sizeof(Float32));
	}
	return self;
}

- (void)dealloc {
	free(_shiftedWords);
	free(_shiftedWordPowers);
}

- (void)setWord:(uint8_t)word withPower:(Float32)wordPower forShiftIndex:(int)shiftIndex {
	_shiftedWords[shiftIndex] = word;
	_shiftedWordPowers[shiftIndex] = wordPower;
}

- (void)updateValue {
	
	Float32 maxPower = 0;
	uint8_t maxPowerIndex = 0;
	
	for (int i=0; i < defaultShiftSteps; i++) {
		Float32 power = _shiftedWordPowers[i];
		if (power > maxPower) {
			maxPower = power;
			maxPowerIndex = i;
		}
	}
	
	_value = (maxPower > wordPowerThreshold) ? _shiftedWords[maxPowerIndex] : AirWordValue_NoValue;
}

@end


@interface AirSignalProcessor (private)
@end


@implementation AirSignalProcessor


- (id)init {
	if ((self = [super init])) {
		
		// default values
		[self setSampleRate:defaultSampleRate];
		[self setStepFrequency:defaultStepFrequency];
		
		NSLog(@"---");
		NSLog(@"Signal Processor Init");
		NSLog(@"sampleRate:      %g", _sampleRate);
		NSLog(@"stepFrequency:   %5.3f", _stepFrequency);
		NSLog(@"stepBitLength:     %u", (unsigned int)_stepBitLength);
		NSLog(@"stepDataBitLength: %u", (unsigned int)_stepDataBitLength);
		NSLog(@"bufferBitLength:  %u", (unsigned int)_bufferBitLength);
		NSLog(@"---");
		
		// create data processing queue
		_data_processing_queue = dispatch_queue_create("com.mylapka.air_signal_data_processing_queue", NULL);

		// alloc buffers
		_buffer = (Float32 *) malloc(_bufferBitLength * sizeof(Float32));
		_stepData = (Float32 *) malloc(_stepDataBitLength * sizeof(Float32));
		
		// create signal word
		_signalWord = [AirWord new];
		
		// reset counters
		_bufferBitRange.location = 0;
		_bufferBitRange.length = 0;
		_zeroTimestamp = 0;
		_bitCounter = 0;
	}
	return self;
}


- (void)dealloc {
	
	_data_processing_queue = nil;
	_signalWord = nil;
	self.fftAnalyzer = nil;
	[self removeAudioUnit];
	free(_buffer);
	free(_stepData);
}


#pragma mark -
#pragma mark Processing


- (void)startProcessing {
	
	if (_isProcessing) return;
	self.isProcessing = YES;
	NSLog(@"start air processing");
	
	[self startAudioUnit];
}


- (void)stopProcessing {
	
	if (!_isProcessing) return;
	self.isProcessing = NO;
	printf("\n\n");
	NSLog(@"stop air processing");
	
	[self stopAudioUnit];
}


#pragma mark -
#pragma mark Audio Unit


- (void)createAudioUnit {
	
	printf("\n");
	NSLog(@"create AudioUnit");
	
	// Configure the search parameters to find the default playback output unit
	// (called the kAudioUnitSubType_RemoteIO on iOS but
	// kAudioUnitSubType_DefaultOutput on Mac OS X)
	AudioComponentDescription defaultOutputDescription;
	defaultOutputDescription.componentType = kAudioUnitType_Output;
	defaultOutputDescription.componentSubType = kAudioUnitSubType_RemoteIO;
	defaultOutputDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
	defaultOutputDescription.componentFlags = 0;
	defaultOutputDescription.componentFlagsMask = 0;
	
	// Get the default playback output unit
	AudioComponent defaultOutput = AudioComponentFindNext(NULL, &defaultOutputDescription);
	NSAssert(defaultOutput, @"Can't find default output");
	
	// Create a new unit based on this that we'll use for output
	OSErr err = AudioComponentInstanceNew(defaultOutput, &audioUnit);
	NSAssert1(audioUnit, @"Error creating unit: %hd", err);
	
	// Enable input
	UInt32 one = 1;
	err = AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &one, sizeof(one));
	NSAssert1(err == noErr, @"couldn't enable input on the remote I/O unit", err);
	
	// Set our tone rendering function on the unit
	AURenderCallbackStruct input;
	input.inputProc = RenderAudio;
	input.inputProcRefCon = (__bridge void *)self;
	err = AudioUnitSetProperty(audioUnit,
							   kAudioUnitProperty_SetRenderCallback,
							   kAudioUnitScope_Input,
							   0,
							   &input,
							   sizeof(input));
	NSAssert1(err == noErr, @"Error setting callback: %hd", err);
	
	
	// Set the format to 32 bit, two channels, floating point, linear PCM
	const int four_bytes_per_float = 4;
	const int eight_bits_per_byte = 8;
	
	AudioStreamBasicDescription streamFormat;
	streamFormat.mSampleRate = _sampleRate;
	streamFormat.mFormatID = kAudioFormatLinearPCM;
	streamFormat.mFormatFlags = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
	streamFormat.mBytesPerPacket = four_bytes_per_float;
	streamFormat.mFramesPerPacket = 1;
	streamFormat.mBytesPerFrame = four_bytes_per_float;
	streamFormat.mChannelsPerFrame = 2;
	streamFormat.mBitsPerChannel = four_bytes_per_float * eight_bits_per_byte;
	err = AudioUnitSetProperty (audioUnit,
								kAudioUnitProperty_StreamFormat,
								kAudioUnitScope_Input,
								0,
								&streamFormat,
								sizeof(AudioStreamBasicDescription));
	NSAssert1(err == noErr, @"Error setting output stream format: %hd", err);
	err = AudioUnitSetProperty (audioUnit,
								kAudioUnitProperty_StreamFormat,
								kAudioUnitScope_Output,
								1,
								&streamFormat,
								sizeof(AudioStreamBasicDescription));
	NSAssert1(err == noErr, @"Error setting input stream format: %hd", err);
	
	// Initialize
	err = AudioUnitInitialize(audioUnit);
	NSAssert1(err == noErr, @"Error initializing unit: %hd", err);
}


- (void)removeAudioUnit {
	
	NSLog(@"remove AudioUnit");
	
	AudioUnitUninitialize(audioUnit);
	AudioComponentInstanceDispose(audioUnit);
	audioUnit = nil;
}


- (void)startAudioUnit {
	
	NSLog(@"start AudioUnit");
	printf("\n");
	
	OSErr err = AudioOutputUnitStart(audioUnit);
	NSAssert1(err == noErr, @"Error starting audio unit: %hd", err);
}


- (void)stopAudioUnit {
	
	NSLog(@"stop AudioUnit");
	
	OSErr err = AudioOutputUnitStop(audioUnit);
	NSAssert1(err == noErr, @"Error stopping audio unit: %hd", err);
	
	NSLog(@"stopped AudioUnit");
}


#pragma mark -
#pragma mark FFT


- (void)setupFFTAnalyzer {
	
	NSLog(@"setup FFT Analyzer");
	
	Float32 *wordFrequencies = (Float32 *)malloc(wordFrequenciesCount * sizeof(Float32));
	
	wordFrequencies[0] = word0Frequency;
	wordFrequencies[1] = word1Frequency;
	wordFrequencies[2] = word2Frequency;
	wordFrequencies[3] = word3Frequency;
	wordFrequencies[4] = word4Frequency;
	wordFrequencies[5] = word5Frequency;
	wordFrequencies[6] = word6Frequency;
	wordFrequencies[7] = word7Frequency;
	wordFrequencies[8] = word8Frequency;
	wordFrequencies[9] = word9Frequency;
	wordFrequencies[10] = word10Frequency;
	wordFrequencies[11] = word11Frequency;
	wordFrequencies[12] = word12Frequency;
	wordFrequencies[13] = word13Frequency;
	wordFrequencies[14] = word14Frequency;
	wordFrequencies[15] = word15Frequency;
	wordFrequencies[16] = word16Frequency;
	
	_fftAnalyzer = [[AirSignalFFTAnalyzer alloc] initWithNumberOfFrames:_stepDataBitLength sampleRate:_sampleRate requiredFrequencies:wordFrequencies requiredFrequenciesCount:wordFrequenciesCount];
	
	free(wordFrequencies);
}


- (void)unsetupFFTAnalyzer {
	
	NSLog(@"unsetup FFT Analyzer");
	
	self.fftAnalyzer = nil;
}


#pragma mark -
#pragma mark Getters & Setters


- (void)setSampleRate:(float)sampleRate {
	_sampleRate = sampleRate;
	_stepBitLength = [self stepBitLengthWithSampleRate:_sampleRate stepFrequency:_stepFrequency optimizedForFFT:NO];
	_stepDataBitLength = [self stepBitLengthWithSampleRate:_sampleRate stepFrequency:_stepFrequency optimizedForFFT:YES];
	_bufferBitLength = [self bufferLengthWithStepBitLength:_stepBitLength packetLength:defaultPacketLength];
}


- (void)setStepFrequency:(double)stepFrequency {
	_stepFrequency = stepFrequency;
	_stepTimeDuration = 1.0 / stepFrequency;
	_stepBitLength = [self stepBitLengthWithSampleRate:_sampleRate stepFrequency:_stepFrequency optimizedForFFT:NO];
	_stepDataBitLength = [self stepBitLengthWithSampleRate:_sampleRate stepFrequency:_stepFrequency optimizedForFFT:YES];
	_bufferBitLength = [self bufferLengthWithStepBitLength:_stepBitLength packetLength:defaultPacketLength];
}


#pragma mark -
#pragma mark Utilities


- (UInt32)stepBitLengthWithSampleRate:(double)sampleRate stepFrequency:(double)stepFrequency optimizedForFFT:(BOOL)optimizedForFFT {
	
	if (stepFrequency == 0) return 0;
	
	int stepBitLength = round(sampleRate / stepFrequency);
	
	if (optimizedForFFT) {
		int log2length = log2(stepBitLength);
		int twoInLog2lengthPower = pow(2.0, log2length);
		stepBitLength = twoInLog2lengthPower;
	}
	
	return stepBitLength;
}


- (UInt32)bufferLengthWithStepBitLength:(UInt32)stepBitLength packetLength:(UInt32)packetLength {
	
	int bufferExtraBits = 2;
	UInt32 bufferLength = 2 * stepBitLength + packetLength + bufferExtraBits;
	return bufferLength;
}


- (NSRange)stepBitRangeWithStartTime:(Float64)startTime {
	
	static Float64 oneBitTimeLength = 1.0 / defaultSampleRate;
	
	NSRange stepBitRange;
	stepBitRange.location = floor(startTime / oneBitTimeLength);
	stepBitRange.length = _stepBitLength;
	return stepBitRange;
}


- (NSRange)stepDataBitRangeWithStartTime:(Float64)startTime {
	
	static Float64 oneBitTimeLength = 1.0 / defaultSampleRate;
	
	NSRange stepDataBitRange;
	stepDataBitRange.location = floor(startTime / oneBitTimeLength);
	stepDataBitRange.length = _stepDataBitLength;
	return stepDataBitRange;
}


- (double)optimizeFrequency:(double)frequency withNumberOfFrames:(int)numberOfFrames {
	
	int frequency_bin = round(frequency * numberOfFrames / self.sampleRate);
	double optimizedFrequency = frequency_bin * self.sampleRate / numberOfFrames;
	
	return optimizedFrequency;
}


@end
