//
//  Exif.h
//  cam2mac
//
//  Created by Nicolas Bonamy on 23/12/12.
//  Copyright (c) 2013 nabocorp. All rights reserved.
//

#import "exif-data.h"
#import "exif-tag.h"

@interface Exif : NSObject {
	ExifData* exifData;
}

- (id) initWithExifFile:(NSString*) file;

- (NSString*) getTagValue:(ExifTag) tag;

+ (NSImage*) getExifThumbnail:(NSString*) file;
+ (BOOL) updateExifThumbnail:(NSString*) file;

+ (NSDate*) parseExifDate:(NSString*) dateTime;

+ (void) trimExifData:(NSString*) path;
+ (void) copyExifDataFromPath:(NSString*) source toPath:(NSString*) destination;

@end
