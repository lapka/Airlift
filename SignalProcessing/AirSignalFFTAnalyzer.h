//
//  Airlift/AirSignalFFTAnalyzer.h
//  Tailored at 2013 by Lapka, all rights reserved.
//
//	(based on SenseFramework)
//

#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>


@interface AirSignalFFTAnalyzer : NSObject {
	
	COMPLEX_SPLIT   fft_complex_split;
    FFTSetup        fft_setup;
    uint32_t        log2n;
    uint32_t        n, nOver2;
    int32_t         stride;
    Float32        *obtainedReal;
	int32_t        *obtained_int;
    Float32         scale;
}

@property (nonatomic, assign) double frequency;
@property (nonatomic, assign) double sampleRate;

- (id)initWithNumberOfFrames:(UInt32)numberOfFrames;
- (Float32)processFFTWithData:(Float32 *)data;

@end