#import "RugbyMeshExporter.h"
#import <StandardCyborgFusion/SCMesh+FileIO.h>

@implementation RugbyMeshExporter

+ (BOOL)exportOBJZipFromPLY:(NSString *)plyPath toPath:(NSString *)objZipPath {
    SCMesh *mesh = [[SCMesh alloc] initWithPLYPath:plyPath JPEGPath:@""];
    if (!mesh) { return NO; }
    return [mesh writeToOBJZipAtPath:objZipPath];
}

+ (BOOL)exportGLBFromPLY:(NSString *)plyPath toPath:(NSString *)glbPath {
    SCMesh *mesh = [[SCMesh alloc] initWithPLYPath:plyPath JPEGPath:@""];
    if (!mesh) { return NO; }
    return [mesh writeToGLBAtPath:glbPath];
}

@end

