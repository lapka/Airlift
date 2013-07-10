//
//  Airlift/AirSignalProcessor.m
//  Tailored at 2013 by Lapka, all rights reserved.
//

#import "AirSignalProcessor.h"
#import <Accelerate/Accelerate.h>

#define defaultSampleRate		44100.0
#define defaultStepFrequency	187.5
#define defaultPacketLength		1024
#define defaultShiftSteps		4

#define zeroBitFrequency		18000.0
#define oneBitFrequency			18286.0


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
	AirBit *signalBit = signalProcessor->_signalBit;
	
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
					UInt32 globalIndex = stepDataBitRange.location + i;
					UInt32 bufferIndex = globalIndex - bufferBitRange.location;
					stepData[i] = buffer[bufferIndex];
				}
				
				// fft zero-frequency amplitude
				signalProcessor.fftAnalyzer.frequency = zeroBitFrequency;
				Float32 zeroFrequencyAmplitude = [signalProcessor.fftAnalyzer processFFTWithData:stepData];
				
				// fft one-frequency amplitude
				signalProcessor.fftAnalyzer.frequency = oneBitFrequency;
				Float32 oneFrequencyAmplitude = [signalProcessor.fftAnalyzer processFFTWithData:stepData];
				
				// calc & save shifted bit
				char shiftedBit = (oneFrequencyAmplitude > zeroFrequencyAmplitude) ? 1 : 0;
				[signalBit setBit:shiftedBit forShiftIndex:shiftStep];
				
				printf(".");
			}
			
			// report air signal bit
			[signalProcessor.delegate airSignalProcessor:signalProcessor didReceiveBit:signalBit];
			
			// buffer pop step-1
			int popLength = currentStepBitRange.location - bufferBitRange.location + currentStepBitRange.length - 1;
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


@implementation AirBit

- (id)init {
	if ((self = [super init])) {
		_shiftedBits = bit_array_create(defaultShiftSteps);
	}
	return self;
}

- (void)dealloc {
	bit_array_free(_shiftedBits);
}

- (void)setBit:(char)bit forShiftIndex:(int)shiftIndex {
	bit_array_assign(_shiftedBits, shiftIndex, bit);
}

- (char)bitWithShiftIndex:(int)shiftIndex {
	return bit_array_get(_shiftedBits, shiftIndex);
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
		NSLog(@"stepFrequency:   %g", _stepFrequency);
		NSLog(@"stepBitLength:     %u", (unsigned int)_stepBitLength);
		NSLog(@"stepDataBitLength: %u", (unsigned int)_stepDataBitLength);
		NSLog(@"bufferBitLength:  %u", (unsigned int)_bufferBitLength);
		NSLog(@"---");
		
		// create data processing queue
		_data_processing_queue = dispatch_queue_create("com.mylapka.air_signal_data_processing_queue", NULL);

		// alloc buffers
		_buffer = (Float32 *) malloc(_bufferBitLength * sizeof(Float32));
		_stepData = (Float32 *) malloc(_stepDataBitLength * sizeof(Float32));
		
		// create signal bit
		_signalBit = [AirBit new];
		
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
	_signalBit = nil;
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
	
	_fftAnalyzer = [[AirSignalFFTAnalyzer alloc] initWithNumberOfFrames:_stepDataBitLength];
	_fftAnalyzer.sampleRate = _sampleRate;
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
