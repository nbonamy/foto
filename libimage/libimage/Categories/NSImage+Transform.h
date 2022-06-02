//
//  NSImage+Transform.h
//  cam2mac
//
//  Created by Nicolas Bonamy on 26/12/12.
//  Copyright (c) 2013 nabocorp. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "cutils/jpeg_utils.h"

typedef enum {
	ImageTransformationRotate90CW,
	ImageTransformationRotate90CCW,
	ImageTransformationRotate180,
	ImageTransformationFlipHorizontal,
	ImageTransformationFlipVertical
} ImageTransformation;

JXFORM_CODE imageTransformToJpegTransform(ImageTransformation transform);

@interface NSImage (Transform)

- (NSImage*) imageRotatedByDegrees:(CGFloat)degrees;

- (NSImage*) transform:(ImageTransformation) transform;

@end
