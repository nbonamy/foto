//
//  BitmapImage.m
//  cam2mac
//
//  Created by Nicolas Bonamy on 16/01/13.
//  Copyright (c) 2013 nabocorp. All rights reserved.
//

#import "BitmapImage.h"
#import "ImageUtils.h"

@implementation BitmapImage

- (id) initWithBitmapImage:(NSBitmapImageRep*) image {
	
	self = [super initWithData:[image TIFFRepresentation]];
	if (self != nil) {
	}
	return self;

}

- (id) initLikeBitmapImage:(NSBitmapImageRep*) image {
	
	self = [super initWithBitmapDataPlanes:nil
															pixelsWide:image.pixelsWide
															pixelsHigh:image.pixelsHigh
													 bitsPerSample:image.bitsPerSample
												 samplesPerPixel:image.samplesPerPixel
																hasAlpha:image.hasAlpha
																isPlanar:image.isPlanar
													colorSpaceName:image.colorSpaceName
														bitmapFormat:image.bitmapFormat
														 bytesPerRow:image.bytesPerRow
														bitsPerPixel:image.bitsPerPixel];
	if (self != nil) {
	}
	return self;
}

- (id) initLikeBitmapImage:(NSBitmapImageRep*) image width:(NSUInteger) width height:(NSUInteger) height {
	
	self = [super initWithBitmapDataPlanes:nil
															pixelsWide:width
															pixelsHigh:height
													 bitsPerSample:image.bitsPerSample
												 samplesPerPixel:image.samplesPerPixel
																hasAlpha:image.hasAlpha
																isPlanar:image.isPlanar
													colorSpaceName:image.colorSpaceName
														bitmapFormat:image.bitmapFormat
														 bytesPerRow:0
														bitsPerPixel:image.bitsPerPixel];
	if (self != nil) {
	}
	return self;
}

- (id) initWithContentsOfFile:(NSString*) path {
	NSData* data = [[NSData alloc] initWithContentsOfFile:path];
	self = [super initWithData:data];
	if (self != nil) {
	}
	return self;
}

+ (BitmapImage*) loadImageFromFile:(NSString*) path {
	return [[BitmapImage alloc] initWithContentsOfFile:path];
}

#pragma mark -
#pragma mark Information

- (NSSize) size {
	return NSMakeSize(self.width, self.height);
}

- (NSRect) bounds {
	return NSMakeRect(0, 0, self.width, self.height);
}

- (NSUInteger) width {
	return self.pixelsWide;
}

- (NSUInteger) height {
	return self.pixelsHigh;
}

- (NSUInteger) bytesPerPixel {
	return self.bitsPerPixel / 8;
}

- (unsigned char*) dataAtX:(NSInteger) x atY:(NSInteger) y {
	return self.bitmapData + y * self.bytesPerRow + x * self.bytesPerPixel;
	
}

#pragma mark -
#pragma mark Processing

- (BitmapImage*) scaleTo:(NSSize) size {
	
	// result
	BitmapImage* result = [[BitmapImage alloc] initLikeBitmapImage:self width:size.width height:size.height];
	
	// set offscreen context
	NSGraphicsContext *g = [NSGraphicsContext graphicsContextWithBitmapImageRep:result];
	[g setImageInterpolation:NSImageInterpolationHigh];
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:g];
	
	// draw original image
	[self drawInRect:result.bounds
					fromRect:NSZeroRect
				 operation:NSCompositeSourceOver
					fraction:1.0
		respectFlipped:TRUE
						 hints:nil];
	
	// done drawing, so set the current context back to what it was
	[NSGraphicsContext restoreGraphicsState];

	// done
	return result;
}

- (BitmapImage*) transform:(ImageTransformation) transform {
	
	// image dimension
	NSUInteger width = self.width;
	NSUInteger height = self.height;
	if (transform == ImageTransformationRotate90CW ||
			transform == ImageTransformationRotate90CCW) {
		width = self.height;
		height = self.width;
	}
	
	// now allocate target image
	BitmapImage* transformed = [[BitmapImage alloc] initLikeBitmapImage:self
																																width:width
																															 height:height];
	
	// try to build the graphics context now as it may fails
	NSGraphicsContext* context = [NSGraphicsContext graphicsContextWithBitmapImageRep:transformed];
	if (context != nil) {
		
		// center the image within the rotated bounds
		NSRect imageBounds = self.bounds;
		NSRect transformedBounds = transformed.bounds;
		imageBounds.origin.x = NSMidX(transformedBounds) - (NSWidth(imageBounds) / 2);
		imageBounds.origin.y = NSMidY(transformedBounds) - (NSHeight(imageBounds) / 2);
		
		// build a transform centered in the image
		NSAffineTransform* affTransform = [NSAffineTransform transform];
		[affTransform translateXBy:+(NSWidth(transformedBounds) / 2)
													 yBy:+(NSHeight(transformedBounds) / 2)];
		
		// now do the real rotation
		switch (transform) {
			case ImageTransformationRotate90CW:
				[affTransform rotateByDegrees:270];
				break;
				
			case ImageTransformationRotate90CCW:
				[affTransform rotateByDegrees:90];
				break;
				
			case ImageTransformationRotate180:
				[affTransform scaleXBy:-1 yBy:-1];
				break;
				
			case ImageTransformationFlipHorizontal:
				[affTransform scaleXBy:-1 yBy:1];
				break;
				
			case ImageTransformationFlipVertical:
				[affTransform scaleXBy:1 yBy:-1];
				break;
		}
		
		// move coordinate system back to normal (bottom, left)
		[affTransform translateXBy:-(NSWidth(transformedBounds) / 2)
													 yBy:-(NSHeight(transformedBounds) / 2)];
		
		// switch graphics context
		[NSGraphicsContext saveGraphicsState];
		[NSGraphicsContext setCurrentContext:context];
		
		// now draw current image
		[affTransform concat];
		[self drawInRect:imageBounds
						fromRect:NSZeroRect
					 operation:NSCompositeCopy
						fraction:1.0
			respectFlipped:YES
							 hints:nil];
		
		// done
		[NSGraphicsContext restoreGraphicsState];
		
	} else {
		
		// now get pixels
		for (NSInteger j=0; j<transformed.height; j++) {
			
			// target
			unsigned char* pxTransformed = [transformed dataAtX:0 atY:j];
			
			for (NSInteger i=0; i<transformed.width; i++) {
				
				// original image coordinates
				NSInteger _i = i;
				NSInteger _j = j;
				switch (transform)
				{
					case ImageTransformationRotate90CW:
						_i = j;
						_j = width - i - 1;
						break;
						
					case ImageTransformationRotate90CCW:
						_i = height - j - 1;
						_j = i;
						break;
						
					case ImageTransformationRotate180:
						_i = width - i - 1;
						_j = height - j - 1;
						break;
						
					case ImageTransformationFlipHorizontal:
						_i = width - i - 1;
						break;
						
					case ImageTransformationFlipVertical:
						_j = height - j - 1;
						break;
				}
				
				// copy
				memcpy(pxTransformed, [self dataAtX:_i atY:_j], self.bytesPerPixel);
				pxTransformed += transformed.bytesPerPixel;
				
			}
		}
	}
	
	// done
	return transformed;
}

@end
