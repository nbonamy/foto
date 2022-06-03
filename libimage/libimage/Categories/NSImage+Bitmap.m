//
//  NSImage+Bitmap.m
//  nbImage
//
//  Created by Nicolas Bonamy on 22/08/13.
//  Copyright (c) 2013 Nicolas Bonamy. All rights reserved.
//

#import "NSImage+Bitmap.h"
#import "NSBitmapImageRep+Save.h"
#import "NSImage+Utils.h"

@implementation NSImage (Bitmap)

- (NSSize) maxSize {
	
	NSImageRep* imageRep = [self largestRepresentation];
	if (imageRep.pixelsWide >0 && imageRep.pixelsHigh > 0) {
		return NSMakeSize(imageRep.pixelsWide, imageRep.pixelsHigh);
	}
	return imageRep.size;
	
}

- (NSBitmapImageRep*) unscaledBitmapImageRep {
	
	int targetWidth = self.size.width;
	int targetHeight = self.size.height;
	
	for (NSImageRep* imageRep in self.representations) {
		if ([imageRep isKindOfClass:[NSBitmapImageRep class]]) {
			NSBitmapImageRep* bitmapRep = (NSBitmapImageRep*) imageRep;
			if (bitmapRep.pixelsWide == targetWidth && bitmapRep.pixelsHigh == targetHeight) {
				return bitmapRep;
			}
		}
	}
	
	NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
													 initWithBitmapDataPlanes:NULL
													 pixelsWide:self.size.width
													 pixelsHigh:self.size.height
													 bitsPerSample:8
													 samplesPerPixel:4
													 hasAlpha:YES
													 isPlanar:NO
													 colorSpaceName:NSDeviceRGBColorSpace
													 bytesPerRow:0
													 bitsPerPixel:0];
	rep.size = self.size;
	
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:
	[NSGraphicsContext graphicsContextWithBitmapImageRep:rep]];
	
	[self drawAtPoint:NSMakePoint(0, 0)
					 fromRect:NSZeroRect
					operation:NSCompositeSourceOver
					 fraction:1.0];
	
	[NSGraphicsContext restoreGraphicsState];
	return rep;
	
}

- (BOOL) saveAsJpeg:(NSString*) destination compressed:(float) compression {
	return [[self unscaledBitmapImageRep] saveAsJpeg:destination compressed:compression];
}

- (BOOL) saveAsPng:(NSString*) destination {
	return [[self unscaledBitmapImageRep] saveAsPng:destination];
}

- (BOOL) saveSameAs:(NSString*) path to:(NSString*) destination jpegCompression:(float) jpegCompression {
	return [[self unscaledBitmapImageRep] saveSameAs:path to:destination jpegCompression:jpegCompression];
}

@end
