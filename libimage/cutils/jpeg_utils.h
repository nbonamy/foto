
#pragma once

#ifdef __cplusplus
extern "C" {
#endif
	
	#include "jpeglib.h"
	#include "transupp.h"
	#include "jhead/jhead.h"

	const char* jpegTransform(const char* file, JXFORM_CODE trans);
	JXFORM_CODE exifOrientToJpegTransform(unsigned char orientation);
	
#ifdef __cplusplus
}
#endif
