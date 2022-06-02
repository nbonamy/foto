//
//  Exif.m
//  cam2mac
//
//  Created by Nicolas Bonamy on 23/12/12.
//  Copyright (c) 2013 nabocorp. All rights reserved.
//

#import "Exif.h"
#import "FileUtils.h"
#import "ImageUtils.h"
#import "exif-entry.h"
#import "exif-loader.h"
#import "NSImage+Utils.h"
#import "NSImage+Bitmap.h"
#import "NSFileManager+Utils.h"
#import "NSImage+MGCropExtensions.h"
#import "cutils/libjpeg/jpeg-data.h"

#define EXIF_THUMBNAIL_JPEG_COMPRESSION 0.7

@implementation Exif

- (id) initWithExifFile:(NSString*) file {
	self = [super init];
	if (self != nil) {
		exifData = exif_data_new_from_file([file UTF8String]);
	}
	return self;
}

- (NSString*) getTagValue:(ExifTag) tag {
	
	// check
	if (exifData == nil) {
		return nil;
	}
	
	// lib exif formats everything nicely
	char value[1024];
	memset(value, 0, 1024);
	ExifEntry* entry = exif_data_get_entry(exifData, tag);
	if (exif_entry_get_value(entry, value, 1024) != NULL) {
		return [[NSString alloc] initWithCString:value encoding:NSUTF8StringEncoding];
	} else {
		return nil;
	}
	
}

+ (NSImage*) getExifThumbnail:(NSString*) file {

	// try with ImageIO
	CGImageRef ioThumbnail = nil;
	CGImageSourceRef isr = CGImageSourceCreateWithURL((CFURLRef)CFBridgingRetain([NSURL fileURLWithPath:file]), NULL);
	if (isr)
	{
		// create a thumbnail:
		// - specify max pixel size
		// - create the thumbnail with honoring the EXIF orientation flag (correct transform)
		ioThumbnail = CGImageSourceCreateThumbnailAtIndex (isr, 0, (CFDictionaryRef)CFBridgingRetain(
									  [NSDictionary dictionaryWithObjectsAndKeys:
										 [NSNumber numberWithInt: 256],  kCGImageSourceThumbnailMaxPixelSize,
										 (id) kCFBooleanTrue, kCGImageSourceCreateThumbnailWithTransform,
										 NULL]));
		CFRelease(isr);
	}
	
	// if we got one
	if (ioThumbnail != nil) {
		NSImage* thumbnail = [NSImage imageFromCGImageRef:ioThumbnail];
		CFRelease(ioThumbnail);
		return thumbnail;
	}
	
	//
	// it failed: now try with exif library
	//
	
	// the thumbnail
	NSImage* exifThumbnail = nil;
	
	// load exif from file
	ExifData* exifData = exif_data_new_from_file([file UTF8String]);
	if (exifData != nil) {

		// check thumbnail
		if (exifData->data && exifData->size) {
		
			// get it
			NSData* data = [NSData dataWithBytes:exifData->data length:exifData->size];
			exifThumbnail = [[NSImage alloc] initWithData:data];
			
			// rotate
			if (exifThumbnail != nil) {
				
				// check for orientation tag
				ExifEntry* exifOrientation = exif_data_get_entry(exifData, EXIF_TAG_ORIENTATION);
				if (exifOrientation != nil) {
					
					// get it
					ExifByteOrder exifByteOrder = exif_data_get_byte_order(exifData);
					int orientation = orientation = exif_get_short(exifOrientation->data, exifByteOrder);
					
					// rotate thumbnail
					//exifThumbnail = [Exif rotateImage:exifThumbnail forExifOrientation:orientation];
				}
				
				
			}
			
		}
		
		// free
		exif_data_unref(exifData);
	}
	
	// done
	return exifThumbnail;
}

+ (BOOL) updateExifThumbnail:(NSString*) file {
		
	ExifData* exifData = exif_data_new_from_file([file UTF8String]);
	if (exifData != nil) {
	
		// clear previous one
		if (exifData->data != NULL) {
			free(exifData->data);
			exifData->data = NULL;
		}
		exifData->size = 0;
		
		// get full image
		NSImage* image = [[NSImage alloc] initWithContentsOfFile:file];
		if (image == nil) {
			return FALSE;
		}
		
		// calc thumbnail size
		int thumbWidth, thumbHeight;
		NSSize imageSize = image.maxSize;
		if (imageSize.width == imageSize.height) {
			thumbWidth = thumbHeight = 140;
		} else if (imageSize.width > imageSize.height) {
			thumbWidth = 160;
			thumbHeight = 120;
		} else {
			thumbWidth = 120;
			thumbHeight = 160;
		}
		
		// now create thumbnail and save it to JPEG
		NSImage* thumbnail = [image imageScaledToFitSize:NSMakeSize(thumbWidth, thumbHeight)];
		
		// now save it
		NSString* tempFile = [NSFileManager temporaryFilename];
		[thumbnail saveAsJpeg:tempFile compressed:EXIF_THUMBNAIL_JPEG_COMPRESSION];
		
		// now read thumbnail
		FILE* f = fopen([tempFile UTF8String], "rb");
		if (f != NULL) {
			
			// set its data into exifData
			fseek(f, 0, SEEK_END);
			exifData->size = (unsigned int) ftell(f);
			exifData->data = malloc(sizeof(char) * exifData->size);
			fseek(f, 0, SEEK_SET);
			fread(exifData->data, sizeof(char), exifData->size, f);
			
			// done
			fclose(f);
		} else {
			return FALSE;
		}
		
		// erase
		[[NSFileManager defaultManager] removeItemAtPath:tempFile error:nil];
		
		// save file to JPEG
		JPEGData* jdata = jpeg_data_new();
		jpeg_data_load_file(jdata, [file UTF8String]);
		jpeg_data_set_exif_data(jdata, exifData);
		jpeg_data_save_file(jdata, [tempFile UTF8String]);
		jpeg_data_unref(jdata);

		// done
		exif_data_unref(exifData);
		
		// now we can replace file
		return [FileUtils replaceFile:file withFile:tempFile isTemporary:TRUE];
		
	}
	
	// too bad
	return FALSE;
}


+ (NSDate*) parseExifDate:(NSString*) dateTime {

	if (dateTime == nil) return nil;
	NSDateFormatter* exifFormat = [[NSDateFormatter alloc] init];
	[exifFormat setDateFormat:@"yyyy:MM:dd HH:mm:ss"];
	return [exifFormat dateFromString:dateTime];
	
}

+ (void) trimExifData:(NSString*) path {
	
	// this only works on jpeg file
	if ([ImageUtils looksLikeJpeg:path] == FALSE) {
		return;
	}
	
	// empty exif data
	ExifData* exifData  = exif_data_new();
	
	// we need a new temp file
	NSString* tempFile = [NSFileManager temporaryFilename:path];
	
	// save file to JPEG
	JPEGData* jdata = jpeg_data_new();
	jpeg_data_load_file(jdata, [path UTF8String]);
	jpeg_data_set_exif_data(jdata, exifData);
	jpeg_data_save_file(jdata, [tempFile UTF8String]);
	jpeg_data_unref(jdata);
	
	// done
	exif_data_unref(exifData);
	
	// swap
	if ([[NSFileManager defaultManager] removeItemAtPath:path error:nil] == TRUE) {
		[[NSFileManager defaultManager] moveItemAtPath:tempFile toPath:path error:nil];
	}

}

+ (void) copyExifDataFromPath:(NSString*) source toPath:(NSString*) destination {
	
	// this only works on jpeg file
	if ([ImageUtils looksLikeJpeg:destination] == FALSE) {
		return;
	}
	
	ExifData* exifData = exif_data_new_from_file([source UTF8String]);
	if (exifData != nil) {
		
		// we need a new temp file
		NSString* tempFile = [NSFileManager temporaryFilename:source];
		
		// save file to JPEG
		JPEGData* jdata = jpeg_data_new();
		jpeg_data_load_file(jdata, [destination UTF8String]);
		jpeg_data_set_exif_data(jdata, exifData);
		jpeg_data_save_file(jdata, [tempFile UTF8String]);
		jpeg_data_unref(jdata);
		
		// done
		exif_data_unref(exifData);
		
		// swap
		if ([[NSFileManager defaultManager] removeItemAtPath:destination error:nil] == TRUE) {
			[[NSFileManager defaultManager] moveItemAtPath:tempFile toPath:destination error:nil];
		}
		
	}

}

@end
