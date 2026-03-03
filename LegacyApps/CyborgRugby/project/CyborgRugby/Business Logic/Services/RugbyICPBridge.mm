#import "RugbyICPBridge.h"

#ifdef __cplusplus
// Suppress offsetof warnings from SC SDK packed types when compiling this TU
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#import <StandardCyborgFusion/ICP.hpp>
#import <StandardCyborgFusion/SCPointCloud+Geometry.h>
#import <StandardCyborgFusion/GeometryHelpers.hpp>
// Restore diagnostics
#pragma clang diagnostic pop
using namespace standard_cyborg;
#endif

@implementation RugbyICPBridge

+ (BOOL)estimateTransformFrom:(SCPointCloud *)source
                           to:(SCPointCloud *)target
                   maxIterations:(int)maxIterations
                       tolerance:(float)tolerance
    outlierDeviationsThreshold:(float)outlierDeviationsThreshold
                      threadCount:(int)threadCount
                      outTransform:(simd_float4x4 *_Nonnull)outTransform
{
#ifndef __cplusplus
    return NO;
#else
    sc3d::Geometry sourceGeo;
    sc3d::Geometry targetGeo;
    [source toGeometry:sourceGeo];
    [target toGeometry:targetGeo];

    ICPConfiguration cfg;
    cfg.maxIterations = maxIterations;
    cfg.tolerance = tolerance;
    cfg.outlierDeviationsThreshold = outlierDeviationsThreshold;
    cfg.threadCount = threadCount > 0 ? threadCount : 1;

    ICPResult result = ICP::run(cfg, sourceGeo, targetGeo, nullptr);
    if (!result.succeeded) {
        return NO;
    }
    *outTransform = toSimdFloat4x4(result.sourceTransform);
    return YES;
#endif
}

@end
