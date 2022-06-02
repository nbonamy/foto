//
//  NSImage+Transform.m
//  cam2mac
//
//  Created by Nicolas Bonamy on 26/12/12.
//  Copyright (c) 2013 nabocorp. All rights reserved.
//

#import "NSImage+Transform.h"
#import "NSImage+Bitmap.h"

JXFORM_CODE imageTransformToJpegTransform(ImageTransformation transform) {
	
	switch (transform) {
		case ImageTransformationRotate90CW:
			return JXFORM_ROT_90;
			
		case ImageTransformationRotate90CCW:
			return JXFORM_ROT_270;
			
		case ImageTransformationRotate180:
			return JXFORM_ROT_180;
			
		case ImageTransformationFlipHorizontal:
			return JXFORM_FLIP_H;
			
		case ImageTransformationFlipVertical:
			return JXFORM_FLIP_V;
	}
}

@implementation NSImage (Transform)

//
// from https://raw.github.com/jerrykrinock/CategoriesObjC/master/NSImage+Transform.h
//

- (NSImage*)imageRotatedByDegrees:(CGFloat)degrees {
	
	// Calculate the bounds for the rotated image
	// We do this by affine-transforming the bounds rectangle
	NSRect imageBounds = {NSZeroPoint, self.maxSize};
	NSBezierPath* boundsPath = [NSBezierPath bezierPathWithRect:imageBounds];
	NSAffineTransform* transform = [NSAffineTransform transform];
	[transform rotateByDegrees:degrees];
	[boundsPath transformUsingAffineTransform:transform];
	NSRect rotatedBounds = {NSZeroPoint, [boundsPath bounds].size};
	NSImage* rotatedImage = [[NSImage alloc] initWithSize:rotatedBounds.size];
	
	// Center the image within the rotated bounds
	imageBounds.origin.x = NSMidX(rotatedBounds) - (NSWidth(imageBounds) / 2);
	imageBounds.origin.y = NSMidY(rotatedBounds) - (NSHeight(imageBounds) / 2);
	
	// Start a new transform, to transform the image
	transform = [NSAffineTransform transform];
	
	// Move coordinate system to the center
	// (since we want to rotate around the center)
	[transform translateXBy:+(NSWidth(rotatedBounds) / 2)
											yBy:+(NSHeight(rotatedBounds) / 2)];
	// Do the rotation
	[transform rotateByDegrees:degrees];
	// Move coordinate system back to normal (bottom, left)
	[transform translateXBy:-(NSWidth(rotatedBounds) / 2)
											yBy:-(NSHeight(rotatedBounds) / 2)];
	
	// Draw the original image, rotated, into the new image
	// Note: This "drawing" is done off-screen.
	[rotatedImage lockFocus];
	[transform concat];
	[self	 drawInRect:imageBounds
					 fromRect:NSZeroRect
					operation:NSCompositeCopy
					 fraction:1.0];
	[rotatedImage unlockFocus];
	
	// done
	return rotatedImage;
}

- (NSImage*)imageFlippedByX:(BOOL) flipX byY:(BOOL) flipY {
	
	// Calculate the bounds for the rotated image
	NSRect imageBounds = {NSZeroPoint, self.maxSize};
	NSImage* flippedImage = [[NSImage alloc] initWithSize:self.size];
	
	// Start a new transform, to transform the image
	NSAffineTransform* transform = [NSAffineTransform transform];

	// Move coordinate system to the center
	// (since we want to flip around the center)
	[transform translateXBy:+(NSWidth(imageBounds) / 2)
											yBy:+(NSHeight(imageBounds) / 2)];
	// Do the flip
	[transform scaleXBy:(flipX ? -1 : 1) yBy:(flipY ? -1 : 1)];
	// Move coordinate system back to normal (bottom, left)
	[transform translateXBy:-(NSWidth(imageBounds) / 2)
											yBy:-(NSHeight(imageBounds) / 2)];
	
	// Draw the original image, flipped, into the new image
	// Note: This "drawing" is done off-screen.
	[flippedImage lockFocus];
	[transform concat];
	[self	 drawInRect:imageBounds
					 fromRect:NSZeroRect
					operation:NSCompositeCopy
					 fraction:1.0];
	[flippedImage unlockFocus];
	
	// done
	return flippedImage;
}


- (NSImage*) transform:(ImageTransformation) transform {
	
	switch (transform) {
		case ImageTransformationRotate90CW:
			return [self imageRotatedByDegrees:270];
			
		case ImageTransformationRotate90CCW:
			return [self imageRotatedByDegrees:90];
			
		case ImageTransformationRotate180:
			return [self imageFlippedByX:TRUE byY:TRUE];
			
		case ImageTransformationFlipHorizontal:
			return [self imageFlippedByX:TRUE byY:FALSE];
			
		case ImageTransformationFlipVertical:
			return [self imageFlippedByX:FALSE byY:TRUE];
			
	}
	
	// too bad
	return self;
}

@end
