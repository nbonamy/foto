//
//  ImageUtils.m
//  cam2mac
//
//  Created by Nicolas Bonamy on 25/12/12.
//  Copyright (c) 2013 nabocorp. All rights reserved.
//

#import "NSFileManager+Utils.h"
#import "NSImage+Transform.h"
#import "NSImage+Bitmap.h"
#import "ImageUtils.h"
#import "FileUtils.h"
#import "exif_utils.h"
#import "Exif.h"

@implementation ImageUtils

+ (BOOL) looksLikeJpeg:(NSString*) path {
	
	// first use basic system checking
	NSArray* extensions = [NSArray arrayWithObjects:@"jpg", @"jpeg", nil];
	if ([FileUtils isFile:path conformingTo:kUTTypeJPEG orHasExtensionIn:extensions] == TRUE) {
		return TRUE;
	}
	
	// check header
	NSFileHandle* fileH = [NSFileHandle fileHandleForReadingAtPath:path];
	NSData* dataChunk = [fileH readDataOfLength:3];
	const unsigned char* bytes = [dataChunk bytes];
	return ((bytes[0] == 0xff) && (bytes[1] == 0xd8) && (bytes[2] == 0xff));

}

+ (BOOL) looksLikePng:(NSString*) path {

	// first use basic system checking
	NSArray* extensions = [NSArray arrayWithObjects:@"png", nil];
	if ([FileUtils isFile:path conformingTo:kUTTypePNG orHasExtensionIn:extensions] == TRUE) {
		return TRUE;
	}
	
	// check header
	NSFileHandle* fileH = [NSFileHandle fileHandleForReadingAtPath:path];
	NSData* dataChunk = [fileH readDataOfLength:4];
	const unsigned char* bytes = [dataChunk bytes];
	return ((bytes[0] == 0x89) && (bytes[1] == 0x50) &&
					(bytes[2] == 0x4e) && (bytes[3] == 0x47));

}

+ (CGSize) getImageSize:(NSString*) path {
	
	// needed
	int width = 0;
	int height = 0;
	
	// open file
	NSURL *imageFileURL = [NSURL fileURLWithPath:path];
	CGImageSourceRef imageSource = CGImageSourceCreateWithURL(CFBridgingRetain(imageFileURL), NULL);
	if (imageSource != NULL) {
		
		// get width and height
		CFDictionaryRef imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, NULL);
		if (imageProperties != NULL) {
			
			// width
			CFNumberRef widthNum  = CFDictionaryGetValue(imageProperties, kCGImagePropertyPixelWidth);
			if (widthNum != NULL) {
				CFNumberGetValue(widthNum, kCFNumberIntType, &width);
			}
			
			// height
			CFNumberRef heightNum = CFDictionaryGetValue(imageProperties, kCGImagePropertyPixelHeight);
			if (heightNum != NULL) {
				CFNumberGetValue(heightNum, kCFNumberIntType, &height);
			}
			
			CFRelease(imageProperties);
		}
		
		// done
		CFRelease(imageSource);
	}
	
	// done
	return CGSizeMake(width, height);
}

+ (NSDate*) getCreationDateForImage:(NSString*) file {
	return [ImageUtils getCreationDateForImage:file atDate:[NSDate date]];
}

+ (NSDate*) getCreationDateForImage:(NSString*) file atDate:(NSDate*) now {

	// extract exif data
	Exif* exif = [[Exif alloc] initWithExifFile:file];
	NSDate* exifDate = [Exif parseExifDate:[exif getTagValue:EXIF_TAG_DATE_TIME_DIGITIZED]];
	if (exifDate != nil) {
		return exifDate;
		
	}

	// if no exif date, get date from file
	NSDate* fileDate = [FileUtils getCreationDateForFile:file];
	if (fileDate != nil) {
		return fileDate;
	}

	// not found
	return [now copy];
	
}

+ (NSImage*) getThumbnail:(NSString*) path {
	
	// depends on type
	NSImage* itemThumbnail = nil;
	if ([FileUtils isImageFile:path]) {
		itemThumbnail = [Exif getExifThumbnail:path];
	}
	
	// icon
	if (itemThumbnail == nil) {
		itemThumbnail = [FileUtils getIcon:path];
	}
	
	// done
	return itemThumbnail;
	
}

+ (BOOL) finalizeTransformOf:(NSString*) path
								 intoCString:(const char*) result
								copyExifData:(BOOL) copyExif
		andUpdateOrientationWith:(unsigned char) exifOrient {
	
	NSString* resultFile = [NSString stringWithCString:result encoding:NSUTF8StringEncoding];
	free((void*)result);
	return [ImageUtils finalizeTransformOf:path
																		into:resultFile
														copyExifData:copyExif
								andUpdateOrientationWith:exifOrient];
	
}

+ (BOOL) finalizeTransformOf:(NSString*) path
												into:(NSString*) resultFile
								copyExifData:(BOOL) copyExif
		andUpdateOrientationWith:(unsigned char) exifOrient {
	
	// save exif data
	if (copyExif) {
		[Exif copyExifDataFromPath:path toPath:resultFile];
	}
	
	// now update exif orientation
	if (exifOrient != 0) {
		exif_orient([resultFile cStringUsingEncoding:NSUTF8StringEncoding], &exifOrient);
	}
	
	// and finally update exif thumbnail
	[Exif updateExifThumbnail:resultFile];

	// save creation date
	NSDate* creationDate = [FileUtils getCreationDateForFile:path];
	
	// replace
	if ([FileUtils replaceFile:path
										withFile:resultFile]) {

		// set creation date
		[FileUtils setCreationDate:creationDate forFile:path];
		
		// done
		return TRUE;
		
	} else {
		
		// too bad
		return FALSE;
		
	}
	
}

+ (BOOL) transformImage:(NSString*) path
					withTransform:(ImageTransformation) transform
				jpegCompression:(float) jpegCompression {
	
	// try a lossless jpegTransform
	if ([ImageUtils looksLikeJpeg:path]) {
		
		// try it
		const char* cPath = [path cStringUsingEncoding:NSUTF8StringEncoding];
		JXFORM_CODE jTransform = imageTransformToJpegTransform(transform);
		const char* resultFile = jpegTransform(cPath, jTransform);
		if (resultFile != NULL) {
			
			return [ImageUtils finalizeTransformOf:path
																 intoCString:resultFile
																copyExifData:FALSE
										andUpdateOrientationWith:1];
			
		}
		
	}
	
	// we need to perform a normal transform
	NSImage* original = [[NSImage alloc] initWithContentsOfFile:path];
	NSImage* transformed = [original transform:transform];
	
	// now save it
	NSString* result = [NSFileManager temporaryFilename:path];
	if ([transformed saveSameAs:path
													 to:result
							jpegCompression:jpegCompression] == FALSE) {
		return FALSE;
	}
	
	// finalize
	return [ImageUtils finalizeTransformOf:path
																		into:result
														copyExifData:TRUE
								andUpdateOrientationWith:1];
	
}

+ (BOOL) autoLosslessRotateImage:(NSString*) path {
	
	// check this is a jpeg
	if ([ImageUtils looksLikeJpeg:path] == FALSE) {
		return FALSE;
	}
	
	// we will need this
	const char* cPath = [path cStringUsingEncoding:NSUTF8StringEncoding];
	
	// first get exif orientation
	unsigned char orientation = 0;
	if (exif_orient(cPath, &orientation) == false) {
		return FALSE;
	}
	
	// now get jpeg transform
	JXFORM_CODE transform = exifOrientToJpegTransform(orientation);
	if (transform == JXFORM_NONE) {
		return TRUE;
	}
	
	// now process transformation
	const char* resultFile = jpegTransform(cPath, transform);
	if (resultFile != NULL) {
		
		return [ImageUtils finalizeTransformOf:path
															 intoCString:resultFile
															copyExifData:FALSE
									andUpdateOrientationWith:1];
		
	} else {
		
		return FALSE;
	}
	
}

@end
