//
//  NSBitmapImageRep+Save.m
//  nbImage
//
//  Created by Nicolas Bonamy on 22/08/13.
//  Copyright (c) 2013 Nicolas Bonamy. All rights reserved.
//

#import "NSBitmapImageRep+Save.h"
#import "ImageUtils.h"

@implementation NSBitmapImageRep (Save)

#pragma mark -
#pragma mark Saving

- (BOOL) saveTo:(NSString*) destination withFormat:(NSBitmapImageFileType) format andOptions:(NSDictionary*) options {
	
	// get the data
	NSData* data = [self representationUsingType:format properties:options];
	
	// check
	if (data == nil) {
		return FALSE;
	}
	
	// write to disk
	return [data writeToFile:destination atomically:YES];
	
}

- (BOOL) saveAsJpeg:(NSString*) destination compressed:(float) jpegCompression {
	
	// jpeg compression
	NSDictionary *imageProps = [NSDictionary dictionaryWithObjectsAndKeys:
															[NSNumber numberWithFloat:jpegCompression], NSImageCompressionFactor,
															nil];
	// save it
	return [self saveTo:destination
					 withFormat:NSJPEGFileType
					 andOptions:imageProps];
#if 0
	//
	// TODO: with libjpeg
	//
	// options (NSBitmapImageRep+JPEG takes a compression between 0 and 255 inverted)
	float jpegCompression = (1 - LOAD_PREF_FLOAT(PREF_JPEF_COMPRESSION) / 100) * 255;
	NSDictionary *imageProps = [NSDictionary dictionaryWithObjectsAndKeys:
															[NSNumber numberWithFloat:jpegCompression], NSImageCompressionFactor,
															nil];
	
	// convert
	NSData* data = [self _JPEGRepresentationWithProperties:imageProps errorMessage:nil];
	
	// check
	if (data == nil) {
		return FALSE;
	}
	
	// write to disk
	return [data writeToFile:destination atomically:YES];
#endif
	
}

- (BOOL) saveAsPng:(NSString*) destination {
	
	return [self saveTo:destination
					 withFormat:NSPNGFileType
					 andOptions:nil];
	
}

- (BOOL) saveSameAs:(NSString*) path to:(NSString*) destination jpegCompression:(float) jpegCompression {
	
	if ([ImageUtils looksLikeJpeg:path]) {
		return [self saveAsJpeg:destination compressed:jpegCompression];
	}
	if ([ImageUtils looksLikePng:path]) {
		return [self saveAsPng:destination];
	}
	return FALSE;
	
}

@end
