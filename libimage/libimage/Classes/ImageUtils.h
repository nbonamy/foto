//
//  ImageUtils.h
//  cam2mac
//
//  Created by Nicolas Bonamy on 25/12/12.
//  Copyright (c) 2013 nabocorp. All rights reserved.
//

#import "NSImage+Transform.h"

@interface ImageUtils : NSObject

+ (BOOL) looksLikeJpeg:(NSString*) path;
+ (BOOL) looksLikePng:(NSString*) path;

+ (CGSize) getImageSize:(NSString*) path;

+ (NSDate*) getCreationDateForImage:(NSString*) file;
+ (NSDate*) getCreationDateForImage:(NSString*) file atDate:(NSDate*) now;

+ (NSImage*) getThumbnail:(NSString*) path;

+ (BOOL) transformImage:(NSString*) path withTransform:(ImageTransformation) transform jpegCompression:(float) jpegCompression;
+ (BOOL) autoLosslessRotateImage:(NSString*) path;

@end
