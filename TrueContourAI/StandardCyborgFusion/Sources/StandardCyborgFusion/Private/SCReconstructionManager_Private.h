//
//  SCReconstructionManager_Private.h
//  StandardCyborgFusion
//
//  Created by Ricky Reusser on 12/13/18.
//

#import <StandardCyborgFusion/SCReconstructionManager.h>

FOUNDATION_EXPORT SCReconstructionManagerStatistics
SCReconstructionManagerStatisticsByRecordingPendingFrameOverwrite(SCReconstructionManagerStatistics statistics,
                                                                  BOOL didOverwritePendingFrame);

FOUNDATION_EXPORT float
SCReconstructionManagerAdaptiveMaxDepth(float currentMaxDepth,
                                        float observedDepth,
                                        SCReconstructionManagerDepthRangeMode depthRangeMode,
                                        BOOL userSetMaxDepth);

@protocol SCReconstructionManagerDelegatePrivate <SCReconstructionManagerDelegate>

- (void)metalReconstructionManager:(SCReconstructionManager *)manager
didAssimilateFrameWithExtendedMetadata:(SCAssimilatedFrameMetadata)metadata
                reconstructedModel:(SCPointCloud *)model;

@end
