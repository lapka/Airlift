//
//  Airlift/AirSignalFFTAnalyzer.h
//  Tailored at 2013 by Lapka, all rights reserved.
//
//	(based on SenseFramework)
//

#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>


@interface AirSignalFFTAnalyzer : NSObject {
	
	COMPLEX_SPLIT   _fft_complex_split;
    FFTSetup        _fft_setup;
    uint32_t        _log2n;
    uint32_t        _n, _nOver2;
    int32_t         _stride;
    Float32        *_obtainedReal;
	int32_t        *_obtained_int;
    Float32         _scale;
	Float32			_sampleRate;
	uint32_t	   *_required_bins;
	uint32_t		_required_bins_count;
	Float32		   *_amplitudes;
	uint32_t		_doplerCorrectionRange;
}

- (id)initWithNumberOfFrames:(UInt32)numberOfFrames sampleRate:(Float32)sampleRate requiredFrequencies:(Float32 *)requiredFrequencies requiredFrequenciesCount:(int)requiredFrequenciesCount doplerCorrectionRange:(int)doplerCorrectionRange;
- (Float32 *)processFFTWithData:(Float32 *)data;

@end