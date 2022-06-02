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

- (NSBitmapImageRep*) getBitmap {
	
	// check largest
	NSImageRep* largest = [self largestRepresentation];
	if ([largest isKindOfClass:[NSBitmapImageRep class]]) {
		return (NSBitmapImageRep*) largest;
	}
	
	// try to figure out what the best size is
	NSSize largestSize = largest.size;
	NSSize pixelsSize = NSMakeSize(largest.pixelsWide, largest.pixelsHigh);
	if (largest.size.width * largest.size.height > pixelsSize.width * pixelsSize.height) {
		pixelsSize = largestSize;
	}
	
	// draw it in a bitmap
	if (pixelsSize.width > 0 && pixelsSize.height > 0) {
		[self lockFocus];
		NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0.0, 0.0, pixelsSize.width, pixelsSize.height)];
		[self unlockFocus];
		return bitmapRep;
	}
	
	// we need to through the tiff representation
	NSData* data = [self TIFFRepresentation];
	return [NSBitmapImageRep imageRepWithData:data];
	
}

- (BOOL) saveAsJpeg:(NSString*) destination compressed:(float) compression {
	return [[self getBitmap] saveAsJpeg:destination compressed:compression];
}

- (BOOL) saveAsPng:(NSString*) destination {
	return [[self getBitmap] saveAsPng:destination];
}

- (BOOL) saveSameAs:(NSString*) path to:(NSString*) destination jpegCompression:(float) jpegCompression {
	return [[self getBitmap] saveSameAs:path to:destination jpegCompression:jpegCompression];
}

@end
