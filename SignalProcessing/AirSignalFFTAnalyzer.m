//
//  Airlift/AirSignalFFTAnalyzer.h
//  Tailored at 2013 by Lapka, all rights reserved.
//

#import "AirSignalFFTAnalyzer.h"

@implementation AirSignalFFTAnalyzer


#pragma mark -
#pragma mark Lifecycle


- (id)initWithNumberOfFrames:(UInt32)numberOfFrames
				  sampleRate:(Float32)sampleRate
		 requiredFrequencies:(Float32 *)requiredFrequencies
	requiredFrequenciesCount:(int)requiredFrequenciesCount
{
	if ((self = [super init])) {
		
		// Set the size of FFT.
		_sampleRate = sampleRate;
		_n = numberOfFrames;
		_log2n = log2(_n);
		_stride = 1;
		_nOver2 = _n / 2;
		
		NSLog(@"---");
		NSLog(@"FFT Analyzer Init");
		NSLog(@"n: %d", _n);
		NSLog(@"log2n: %d", _log2n);
		NSLog(@"nOver2: %d", _nOver2);
		NSLog(@"---");
		
		// Allocate memory for the input operands and check its availability,
		// use the vector version to get 16-byte alignment.
		_fft_complex_split.realp = (Float32 *) malloc(_nOver2 * sizeof(Float32));
		_fft_complex_split.imagp = (Float32 *) malloc(_nOver2 * sizeof(Float32));
		_obtainedReal = (Float32 *) malloc(_n * sizeof(Float32));
		_obtained_int = (int32_t *) malloc(_n * sizeof(int32_t));
		
		if (_fft_complex_split.realp == NULL || _fft_complex_split.imagp == NULL) {
			printf("SSignalFFTAnalyzer: malloc failed to allocate memory for the real FFT section of the sample.\n");
		}
		
		// Set up the required memory for the FFT routines and check its availability.
		_fft_setup = vDSP_create_fftsetup(_log2n, FFT_RADIX2);
		if (_fft_setup == NULL) {
			printf("SSignalFFTAnalyzer: FFT_Setup failed to allocate enough memory for the real FFT.\n");
		}
		
		// Calculate required bins
		_required_bins_count = requiredFrequenciesCount;
		_required_bins = (uint32_t *) malloc(_required_bins_count * sizeof(uint32_t));
		for (int i = 0; i < _required_bins_count; i++) {
			_required_bins[i] = roundf(requiredFrequencies[i] * _n / _sampleRate);
		}
		
		// Create amplitudes array
		_amplitudes = (Float32 *) malloc(_required_bins_count * sizeof(Float32));
	}
	return self;
}

- (void)dealloc {
	
	/* Free the allocated memory. */
	
    vDSP_destroy_fftsetup(_fft_setup);
    free(_obtainedReal);
	free(_obtained_int);
    free(_fft_complex_split.realp);
    free(_fft_complex_split.imagp);
	free(_required_bins);
	free(_amplitudes);
}


#pragma mark -
#pragma mark Proccess FFT


- (Float32 *)processFFTWithData:(Float32 *)data {
	
	/* Look at the real signal as an interleaved complex vector by
     * casting it. Then call the transformation function vDSP_ctoz to
     * get a split complex vector, which for a real signal, divides into
     * an even-odd configuration. */
	
    vDSP_ctoz((COMPLEX *)data, 2, &_fft_complex_split, 1, _nOver2);
	
	/* Carry out a Forward FFT transform. */
	
    vDSP_fft_zrip(_fft_setup, &_fft_complex_split, _stride, _log2n, FFT_FORWARD);
	
	/* Verify correctness of the results, but first scale it by  2n. */
	
    _scale = (Float32) 1.0 / (2 * _n);
    vDSP_vsmul(_fft_complex_split.realp, 1, &_scale, _fft_complex_split.realp, 1, _nOver2);
    vDSP_vsmul(_fft_complex_split.imagp, 1, &_scale, _fft_complex_split.imagp, 1, _nOver2);
	
	/* The output signal is now in a split real form. Use the function
     * vDSP_ztoc to get a split real vector. */
	
    vDSP_ztoc(&_fft_complex_split, 1, (COMPLEX *)_obtainedReal, 2, _nOver2);
	
	/* Find amplitudes by required bins */
	
	for (int i = 0; i < _required_bins_count; i++) {
		uint32_t required_bin = _required_bins[i];
		double requiredReal = _fft_complex_split.realp[required_bin];
		double requiredImag = _fft_complex_split.imagp[required_bin];
		_amplitudes[i] = sqrtf(requiredReal * requiredReal + requiredImag * requiredImag);
	}

	return _amplitudes;
}

@end
