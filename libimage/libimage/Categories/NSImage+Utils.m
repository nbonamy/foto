//
//  NSImage+Utils.m
//  cam2mac
//
//  Created by Nicolas Bonamy on 26/12/12.
//  Copyright (c) 2013 nabocorp. All rights reserved.
//

#import "NSImage+Utils.h"

@implementation NSImage (Utils)

+ (NSImage*) imageFromCGImageRef:(CGImageRef)image {

	// check image
	if (image == nil) {
		return nil;
	}
	
	NSSize imageSize = NSMakeSize(CGImageGetWidth(image), CGImageGetHeight(image));
	return [[NSImage alloc] initWithCGImage:image size:imageSize];
}

- (NSImageRep*) largestRepresentation {
	
	// first find it
	NSImageRep* bestRepresentation = nil;
	for (NSImageRep* imageRep in self.representations) {
		if (bestRepresentation == nil ||
				imageRep.pixelsWide*imageRep.pixelsHigh > bestRepresentation.pixelsWide*bestRepresentation.pixelsHigh) {
			bestRepresentation = imageRep;
		}
	}
	
	// done
	return bestRepresentation;
	
}

- (void) selectLargestRepresentation {
	
	// get it and check
	NSImageRep* bestRepresentation = [self largestRepresentation];
	if (bestRepresentation == nil) {
		return;
	}

	// now remove all other
	for (NSImageRep* imageRep in self.representations) {
		if (imageRep != bestRepresentation) {
			[self removeRepresentation:imageRep];
		}
	}
	
	// now set size
	NSSize size = NSMakeSize(bestRepresentation.pixelsWide, bestRepresentation.pixelsHigh);
	[bestRepresentation setSize:size];
	[self setSize:size];
	
}


@end
