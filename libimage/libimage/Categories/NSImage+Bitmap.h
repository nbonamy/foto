//
//  NSImage+Bitmap.h
//  nbImage
//
//  Created by Nicolas Bonamy on 22/08/13.
//  Copyright (c) 2013 Nicolas Bonamy. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSImage (Bitmap)

- (NSSize) maxSize;

- (NSBitmapImageRep*) getBitmap;

- (BOOL) saveAsJpeg:(NSString*) destination compressed:(float) compression;
- (BOOL) saveAsPng:(NSString*) destination;
- (BOOL) saveSameAs:(NSString*) path to:(NSString*) destination jpegCompression:(float) jpegCompression;

@end
