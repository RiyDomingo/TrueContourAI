//
//  SCReconstructionManagerParameters.h
//  StandardCyborgFusion
//
//

typedef NS_ENUM(NSInteger, SCReconstructionManagerDepthRangeMode) {
    /** Computes max depth once from the initial scan geometry and keeps it fixed unless manually overridden. */
    SCReconstructionManagerDepthRangeModeFixedInitial = 0,

    /** Conservatively widens max depth from later observations while still respecting manual overrides. */
    SCReconstructionManagerDepthRangeModeAdaptive = 1,
};

@protocol SCReconstructionManagerParameters

/** Default value is 2. Recommended value: # high-performance CPU cores on the current device. */
@property (nonatomic) int maxThreadCount;

/** The minimum depth, in meters, below which incoming depth buffer values are clipped before reconstruction. Default value is 0. */
@property (nonatomic) float minDepth;

/** The maximum depth, in meters, above which incoming depth buffer values are clipped before reconstruction. Default value is FLT_MAX. */
@property (nonatomic) float maxDepth;

/** Controls whether live reconstruction keeps the initial depth range or conservatively adapts it from later frames. Default value is SCReconstructionManagerDepthRangeModeFixedInitial. */
@property (nonatomic) SCReconstructionManagerDepthRangeMode depthRangeMode;

#pragma mark - Algorithm parameters, tune at your own risk

/** The fraction by which incoming depth data is downsampled for alignment with the existing model.
 Default value is 0.05. Recommended range: 0.04-0.12 */
@property (nonatomic, setter=setICPDownsampleFraction:) float icpDownsampleFraction;

/** The number of standard deviations outside of which a depth value being aligned is coinsidered an outlier.
 Defaults to 1. Recommended range: 0.8-3.0 */
@property (nonatomic, setter=setICPOutlierDeviationsThreshold:) float icpOutlierDeviationsThreshold;

/** The error tolerance for aligning incoming depth data. Default value is 2e-5. Recommended range: 1e-5 - 8e-5 */
@property (nonatomic, setter=setICPTolerance:) float icpTolerance;

/** The maximum number of iterations for aligning incoming depth buffers. Default value is 24. Recommended range: 16-50 */
@property (nonatomic) int maxICPIterations;

/** The ICP unused-iteration-fraction threshold below which a merged frame is classified as poor tracking. Default value is 0.1. */
@property (nonatomic) float poorTrackingQualityThreshold;

/** The number of consecutive lost-tracking frames tolerated before classification escalates to failed. Default value is 8. */
@property (nonatomic) NSInteger maxConsecutiveLostTrackingCount;

@end
