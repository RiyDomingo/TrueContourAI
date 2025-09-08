#import <Foundation/Foundation.h>
#import <simd/simd.h>
#import <StandardCyborgFusion/SCPointCloud.h>

NS_ASSUME_NONNULL_BEGIN

/// Lightweight Objective-C++ bridge to run ICP between two point clouds
@interface RugbyICPBridge : NSObject

/// Estimates a rigid transform that aligns `source` to `target` using ICP.
/// Returns YES on success and writes a 4x4 simd transform into outTransform.
+ (BOOL)estimateTransformFrom:(SCPointCloud *)source
                       to:(SCPointCloud *)target
           maxIterations:(int)maxIterations
               tolerance:(float)tolerance
outlierDeviationsThreshold:(float)outlierDeviationsThreshold
                threadCount:(int)threadCount
                outTransform:(simd_float4x4 *_Nonnull)outTransform;

@end

NS_ASSUME_NONNULL_END

