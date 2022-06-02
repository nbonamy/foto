#pragma once

#ifdef __cplusplus
extern "C" {
#endif

	// pass 0 in set_flag to get orientation value
	// pass valid exif orientation to set orientation value
	bool exif_orient(const char* file, unsigned char* orientation);
	
#ifdef __cplusplus
}
#endif
