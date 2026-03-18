//
//  SCAssimilatedFrameMetadata_Private.h
//  StandardCyborgFusion
//
//  Created by Aaron Thompson on 12/20/18.
//

#import <StandardCyborgFusion/SCAssimilatedFrameMetadata.h>

#import "PBFAssimilatedFrameMetadata.hpp"
#import "EigenHelpers.hpp"

typedef struct {
    float poorTrackingQualityThreshold;
    NSInteger maxConsecutiveLostTrackingCount;
} SCTrackingClassificationConfiguration;

static SCAssimilatedFrameMetadata
SCAssimilatedFrameMetadataFromPBFAssimilatedFrameMetadata(PBFAssimilatedFrameMetadata pbfMetadata,
                                                          NSInteger consecutiveFailedFrameCount,
                                                          SCTrackingClassificationConfiguration config)
{
    SCAssimilatedFrameMetadata metadata;
    metadata.viewMatrix = toSimdFloat4x4(pbfMetadata.viewMatrix);

    metadata.projectionMatrix = toSimdFloat4x4(pbfMetadata.projectionMatrix);
    metadata.colorBuffer = NULL;
    metadata.depthBuffer = NULL;
    
    if (pbfMetadata.isMerged == false && consecutiveFailedFrameCount + 1 >= config.maxConsecutiveLostTrackingCount) {
        metadata.result = SCAssimilatedFrameResultFailed;
    } else if (pbfMetadata.isMerged == false) {
        metadata.result = SCAssimilatedFrameResultLostTracking;
    } else if (pbfMetadata.icpUnusedIterationFraction < config.poorTrackingQualityThreshold) {
        metadata.result = SCAssimilatedFrameResultPoorTracking;
    } else {
        metadata.result = SCAssimilatedFrameResultSucceeded;
    }
    
    return metadata;
}
