#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RugbyMeshExporter : NSObject

+ (BOOL)exportOBJZipFromPLY:(NSString *)plyPath toPath:(NSString *)objZipPath;
+ (BOOL)exportGLBFromPLY:(NSString *)plyPath toPath:(NSString *)glbPath;

@end

NS_ASSUME_NONNULL_END

